import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

class UpChunk {
  /// HTTP response codes implying the PUT method has been successful
  final successfulChunkUploadCodes = const [200, 201, 202, 204, 308];

  /// HTTP response codes implying a chunk may be retried
  final temporaryErrorCodes = const [408, 502, 503, 504];

  /// Upload url as [String], required
  final String endPoint;

  /// [XFile] to upload, required
  final XFile file;

  /// A Map with any headers you'd like included with the PUT request for each chunk.
  final Map<String, String> headers;

  /// The size in kb of the chunks to split the file into,
  /// with the exception of the final chunk which may be smaller.
  /// This parameter should be in multiples of 64
  final int chunkSize;

  /// The number of times to retry any given chunk.
  final int attempts;

  /// Number of seconds to wait before a retry is fired
  final int delayBeforeAttempt;

  /// Fired immediately before a chunk upload is attempted.
  ///
  /// [chunkNumber] is the number of the current chunk being attempted,
  /// and [chunkSize] is the size (in bytes) of that chunk.
  final void Function(int chunkNumber, int chunkSize)? onAttempt;

  /// Fired when an attempt to upload a chunk fails.
  ///
  /// [message] is the error message
  /// [chunkNumber] is the number of the current chunk being attempted,
  /// and [attemptsLeft] is the number of attempts left before stopping the upload
  final void Function(String message, int chunkNumber, int attemptsLeft)? onAttemptFailure;

  /// Fired when a chunk has reached the max number of retries or the response code is fatal and implies that retries should not be attempted.
  final void Function(String message, int chunk, int attempts)? onError;

  /// Fired when the upload is finished successfully, with the HTTP [Response]
  /// of the final chunk.
  final void Function(Response response)? onSuccess;

  /// Fired continuously with incremental upload progress. This returns the current percentage of the file that's been uploaded.
  ///
  /// [progress] a number from 0 to 100 representing the percentage of the file uploaded
  final void Function(double progress)? onProgress;

  Stream<List<int>> _chunk = Stream.empty();
  int _chunkLength = 0;
  int _fileSize = 0;
  int _chunkCount = 0;
  int _chunkByteSize = 0;
  String? _fileMimeType;
  int _totalChunks = 0;
  int _attemptCount = 0;
  bool _paused = false;
  bool _stopped = false;

  /// Guards against concurrent chunk uploads: [_sendChunks] is a no-op while
  /// a chunk request is already in flight.
  bool _sending = false;

  /// Bumped by [stop] and [restart]; completions belonging to a previous
  /// epoch are discarded so they cannot clobber the current upload's state.
  int _epoch = 0;

  CancelToken? _currentCancelToken;

  bool _uploadFailed = false;

  final Dio _dio = Dio();

  Completer<Response> _doneCompleter = Completer<Response>();

  /// Completes with the HTTP [Response] of the final chunk when the upload
  /// finishes successfully, or with an error when the upload fails fatally or
  /// is stopped with [stop].
  ///
  /// After [restart], reflects the new upload attempt.
  Future<Response> get done => _doneCompleter.future;

  /// Internal constructor used by [createUpload]
  UpChunk({
    required this.endPoint,
    required this.file,
    this.headers = const {},
    this.chunkSize = 5120,
    this.attempts = 5,
    this.delayBeforeAttempt = 1,
    this.onAttempt,
    this.onAttemptFailure,
    this.onError,
    this.onSuccess,
    this.onProgress,
    int? chunkStart,
  }) {
    _validateOptions();

    // Errors are also delivered through [onError]; never awaiting [done] must
    // not surface an unhandled asynchronous error.
    _doneCompleter.future.ignore();

    _chunkByteSize = chunkSize * 1024;
    if (chunkStart != null) {
      _chunkCount = chunkStart;
    }

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _fileSize = await file.length();
      _totalChunks = (_fileSize / _chunkByteSize).ceil();
      if (_chunkCount > _totalChunks) {
        throw Exception('The total number of chunks is $_totalChunks, but [chunkStart] is $_chunkCount');
      }
    } catch (exc) {
      _fail('Failed to prepare upload: $exc');
      return;
    }

    await _getMimeType();
    _sendChunks();
  }

  /// It pauses the upload, the [_chunk] currently being uploaded will finish first before pausing the next [_chunk]
  void pause() => _paused = true;

  /// It resumes the upload for the next [_chunk]
  void resume() {
    if (!_paused) return;

    _paused = false;
    _sendChunks();
  }

  void stop() {
    if (_stopped) return;

    _stopped = true;
    _uploadFailed = true;
    _epoch++;
    _sending = false;
    _currentCancelToken?.cancel(Exception('Upload cancelled by the user'));

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.completeError(Exception('Upload cancelled by the user.'));
    }

    if (onError != null) {
      onError!(
        'Upload cancelled by the user.',
        _chunkCount,
        _attemptCount,
      );
    }
  }

  /// It gets [file]'s mime type, if possible
  Future<void> _getMimeType() async {
    try {
      _fileMimeType = lookupMimeType(file.path);
    } catch (_) {
      _fileMimeType = null;
    }
  }

  /// It validates the passed options
  void _validateOptions() {
    if (chunkSize <= 0 || chunkSize % 64 != 0)
      throw new Exception('chunkSize must be a positive number in multiples of 64');

    if (attempts <= 0)
      throw new Exception('retries must be a positive number');

    if (delayBeforeAttempt < 0)
      throw new Exception('delayBeforeAttempt must be a positive number');
  }

  /// Gets [Uri] from [endPoint]
  Uri get _endPointUri => Uri.parse(endPoint);

  /// Routes a fatal failure to [onError] and [done].
  void _fail(String message) {
    _uploadFailed = true;

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.completeError(Exception(message));
    }

    if (onError != null)
      onError!(
        message,
        _chunkCount,
        _attemptCount,
      );
  }

  /// Sends [_chunk] of the file with appropriate headers
  Future<Response> _sendChunk() async {
    // add chunk request headers
    var rangeStart = _chunkCount * _chunkByteSize;
    var rangeEnd = rangeStart + _chunkLength - 1;

    var putHeaders = {
      'content-range': 'bytes $rangeStart-$rangeEnd/$_fileSize',
      Headers.contentLengthHeader: _chunkLength
    };
    if (_fileMimeType != null) {
      putHeaders.putIfAbsent(Headers.contentTypeHeader, () => _fileMimeType!);
    }
    headers.forEach((key, value) => putHeaders.putIfAbsent(key, () => value));

    if (onAttempt != null)
      onAttempt!(_chunkCount, _chunkLength,);

    _currentCancelToken = CancelToken();
    final epoch = _epoch;

    // returns future with http response
    return _dio.putUri(
      _endPointUri,
      options: Options(
        headers: putHeaders,
        followRedirects: false,
        validateStatus: (status) {
          return true;
        }
      ),
      data: _chunk,
      onSendProgress: (int sent, int total) {
        if (epoch != _epoch || _stopped) return;

        if (onProgress != null) {
          final bytesSent = _chunkCount * _chunkByteSize;
          final percentProgress = (bytesSent + sent) * 100.0 / _fileSize;

          if (percentProgress < 100.0)
            onProgress!(percentProgress);
        }
      },
      cancelToken: _currentCancelToken,
    );
  }

  /// Gets [_chunk] and [_chunkLength] for the portion of the file of x bytes corresponding to [_chunkByteSize]
  void _getChunk() {
    final length = _totalChunks == 1 ? _fileSize : _chunkByteSize;
    final start = length * _chunkCount;

    _chunk = file.openRead(start, start + length);
    if (start + length <= _fileSize)
      _chunkLength = length;
    else
      _chunkLength = _fileSize - start;
  }

  /// Called on net failure. If retry [_attemptCount] < [attempts], retry after [delayBeforeAttempt]
  void _manageRetries() {
    if (_attemptCount < attempts) {
      _attemptCount = _attemptCount + 1;
      final epoch = _epoch;
      Timer(Duration(seconds: delayBeforeAttempt), () {
        if (epoch != _epoch || _stopped) return;

        _sendChunks();
      });

      if (onAttemptFailure != null)
        onAttemptFailure!(
          'An error occurred uploading chunk $_chunkCount. ${attempts - _attemptCount} retries left.',
          _chunkCount,
          attempts - _attemptCount,
        );

      return;
    }

    _fail('An error occurred uploading chunk $_chunkCount. No more retries, stopping upload');
  }

  /// Manages the whole upload by calling [_getChunk] and [_sendChunk]
  void _sendChunks() {
    if (_paused || _stopped || _sending) return;

    _sending = true;
    final epoch = _epoch;

    _getChunk();
    _sendChunk().then((res) {
        // A stale completion (the upload was stopped or restarted while this
        // chunk was in flight) must not touch the current upload's state.
        if (epoch != _epoch) return;
        _sending = false;
        if (_paused || _stopped) return;

        if (successfulChunkUploadCodes.contains(res.statusCode)) {
          _chunkCount++;
          if (_chunkCount < _totalChunks) {
            _attemptCount = 0;
            _sendChunks();
          } else {
            if (onSuccess != null) onSuccess!(res);
            if (!_doneCompleter.isCompleted) _doneCompleter.complete(res);
          }

          if (onProgress != null) {
            double percentProgress = 100.0;
            if (_chunkCount < _totalChunks) {
              final bytesSent = _chunkCount * _chunkByteSize;
              percentProgress = bytesSent * 100.0 / _fileSize;
            }
            onProgress!(percentProgress);
          }
        } else if (temporaryErrorCodes.contains(res.statusCode)) {
          _manageRetries();
        } else {
          _fail('Server responded with ${res.statusCode}. Stopping upload.');
        }
      },
      onError: (err) {
        if (epoch != _epoch) return;
        _sending = false;
        if (_paused || _stopped) return;

        // Network errors: retry until [attempts] is exhausted.
        _manageRetries();
      }
    );
  }

  /// Restarts the upload after if the upload failed and came to a complete stop
  void restart() {
    if (!_uploadFailed)
      throw Exception('Upload has not yet failed, use restart only after all retries have failed.');

    _epoch++;
    _chunkCount = 0;
    _chunkByteSize = chunkSize * 1024;
    _attemptCount = 0;
    _currentCancelToken = null;

    _paused = false;
    _stopped = false;
    _sending = false;
    _uploadFailed = false;

    if (_doneCompleter.isCompleted) {
      _doneCompleter = Completer<Response>();
      _doneCompleter.future.ignore();
    }

    _sendChunks();
  }
}
