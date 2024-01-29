import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'package:flutter_upchunk/src/connection_status_singleton.dart';

class UpChunk {
  /// HTTP response codes implying the PUT method has been successful
  final successfulChunkUploadCodes = const [200, 201, 202, 204, 308];

  /// HTTP response codes implying a chunk may be retried
  final temporaryErrorCodes = const [408, 502, 503, 504];

  final String endPoint;
  final XFile file;
  final Map<String, String> headers;
  final int chunkSize;
  final int attempts;
  final int delayBeforeAttempt;

  Stream<List<int>> _chunk = Stream.empty();
  int _chunkLength = 0;
  int _fileSize = 0;
  int _chunkCount = 0;
  int _chunkByteSize = 0;
  String? _fileMimeType;
  int _totalChunks = 0;
  int _attemptCount = 0;
  bool _offline = false;
  bool _paused = false;
  bool _stopped = false;

  CancelToken? _currentCancelToken;

  bool _uploadFailed = false;

  final void Function()? onOnline;
  final void Function()? onOffline;
  final void Function(int chunkNumber, int chunkSize)? onAttempt;
  final void Function(String message, int chunkNumber, int attemptsLeft)? onAttemptFailure;
  final void Function(String message, int chunk, int attempts)? onError;
  final void Function()? onSuccess;
  final void Function(double progress )? onProgress;

  /// Internal constructor used by [createUpload]
  UpChunk({
    required this.endPoint,
    required this.file,
    this.headers = const {},
    this.chunkSize = 5120,
    this.attempts = 5,
    this.delayBeforeAttempt = 1,
    this.onOnline,
    this.onOffline,
    this.onAttempt,
    this.onAttemptFailure,
    this.onError,
    this.onSuccess,
    this.onProgress,
  }) {
    _validateOptions();

    _chunkByteSize = chunkSize * 1024;

    // restart sync when back online
    // trigger events when offline/back online
    ConnectionStatusSingleton connectionStatus = ConnectionStatusSingleton.getInstance();
    connectionStatus.connectionChange.listen(_connectionChanged);

    _initialize();
  }

  Future<void> _initialize() async {
    _fileSize = await file.length();
    _totalChunks =  (_fileSize / _chunkByteSize).ceil();

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
    _stopped = true;
    _uploadFailed = true;
    _currentCancelToken!.cancel(Exception('Upload cancelled by the user'));

    if (onError != null)
      onError!(
        'Upload cancelled by the user.',
        _chunkCount,
        _attemptCount,
      );
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

  /// Callback for [ConnectionStatusSingleton] to notify connection changes
  ///
  /// if the connection drops [_offline] is marked as true and upload us paused,
  /// if connection is restore [_offline] is marked as false and resumes the upload
  void _connectionChanged(dynamic hasConnection) {
    if (hasConnection) {
      if (!_offline)
        return;

      _offline = false;

      if (onOnline != null) onOnline!();

      _sendChunks();
    }

    if (!hasConnection) {
      _offline = true;

      if (onOffline != null) onOffline!();
    }
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
    if (_fileMimeType != null){
      putHeaders.putIfAbsent(Headers.contentTypeHeader, () => _fileMimeType!);
    }
    headers.forEach((key, value) => putHeaders.putIfAbsent(key, () => value));

    if (onAttempt != null)
      onAttempt!(_chunkCount, _chunkLength,);

    _currentCancelToken = CancelToken();

    // returns future with http response
    return Dio().putUri(
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
      Timer(Duration(seconds: delayBeforeAttempt), () => _sendChunks());

      if (onAttemptFailure != null)
        onAttemptFailure!(
          'An error occurred uploading chunk $_chunkCount. ${attempts - _attemptCount} retries left.',
          _chunkCount,
          attempts - _attemptCount,
        );

      return;
    }

    _uploadFailed = true;

    if (onError != null)
      onError!(
        'An error occurred uploading chunk $_chunkCount. No more retries, stopping upload',
        _chunkCount,
        _attemptCount,
      );
  }

  /// Manages the whole upload by calling [_getChunk] and [_sendChunk]
  void _sendChunks() {
    if (_paused || _offline || _stopped)
      return;

    _getChunk();
    _sendChunk().then((res) {
        if (successfulChunkUploadCodes.contains(res.statusCode)) {
          _chunkCount++;
          if (_chunkCount < _totalChunks) {
            _attemptCount = 0;
            _sendChunks();
          } else {
            if (onSuccess != null) onSuccess!();
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
          if (_paused || _offline || _stopped)
            return;

          _manageRetries();
        } else {
          if (_paused || _offline || _stopped)
            return;

          _uploadFailed = true;

          if (onError != null)
            onError!(
              'Server responded with ${res.statusCode}. Stopping upload.',
              _chunkCount,
              _attemptCount,
            );
        }
      },
      onError: (err) {
        if (_paused || _offline || _stopped)
          return;

        // this type of error can happen after network disconnection on CORS setup
        _manageRetries();
      }
    );
  }

  /// Restarts the upload after if the upload failed and came to a complete stop
  void restart() {
    if (!_uploadFailed)
      throw Exception('Upload hasn\'t yet failed, use restart only after all retries have failed.');

    _chunkCount = 0;
    _chunkByteSize = chunkSize * 1024;
    _attemptCount = 0;
    _currentCancelToken = null;

    _offline = false;
    _paused = false;
    _stopped = false;
    _uploadFailed = false;

    _sendChunks();
  }
}
