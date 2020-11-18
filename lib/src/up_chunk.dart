import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'package:flutter_upchunk/src/connection_status_singleton.dart';
import 'package:flutter_upchunk/src/up_chunk_options.dart';

class UpChunk {
  /// HTTP response codes implying the PUT method has been successful
  final successfulChunkUploadCodes = const [200, 201, 202, 204, 308];

  /// HTTP response codes implying a chunk may be retried
  final temporaryErrorCodes = const [408, 502, 503, 504];

  String endPoint;
  Future<String> endPointResolver;
  File file;
  Map<String, String> headers;
  int chunkSize;
  int attempts;
  int delayBeforeAttempt;

  Stream<List<int>> _chunk;
  int _chunkLength;
  int _fileSize;
  int _chunkCount;
  int _chunkByteSize;
  String _fileMimeType;
  Uri _endpointValue;
  int _totalChunks;
  int _attemptCount;
  bool _offline;
  bool _paused;

  bool _uploadFailed = false;

  void Function() _onOnline;
  void Function() _onOffline;
  void Function({ @required int chunkNumber, @required int chunkSize }) _onAttempt;
  void Function({ @required String message, @required int chunkNumber, @required int attemptsLeft }) _onAttemptFailure;
  void Function({ @required String message, @required int chunk, @required int attempts }) _onError;
  void Function() _onSuccess;
  void Function({ @required double progress }) _onProgress;

  static UpChunk createUpload(UpChunkOptions options) => UpChunk._internal(options);

  /// Internal constructor used by [createUpload]
  UpChunk._internal(UpChunkOptions options) {
    endPoint = options.endPoint;
    endPointResolver = options.endPointResolver;
    file = options.file;
    headers = options.headers ?? Map<String, String>();
    chunkSize = options.chunkSize ?? 5120;
    attempts = options.attempts ?? 5;
    delayBeforeAttempt = options.delayBeforeAttempt ?? 1;

    _validateOptions();

    _chunkCount = 0;
    _chunkByteSize = chunkSize * 1024;
    _attemptCount = 0;
    _offline = false;
    _paused = false;
    _onOnline = options.onOnline;
    _onOffline = options.onOffline;
    _onAttempt = options.onAttempt;
    _onAttemptFailure = options.onAttemptFailure;
    _onError = options.onError;
    _onSuccess = options.onSuccess;
    _onProgress = options.onProgress;

    _getEndpoint()
      .then((value) async {
        _fileSize = await options.file.length();
        _totalChunks =  (_fileSize / _chunkByteSize).ceil();

        await _getMimeType();
      })
      .then((_) => _sendChunks());

    // restart sync when back online
    // trigger events when offline/back online
    ConnectionStatusSingleton connectionStatus = ConnectionStatusSingleton.getInstance();
    connectionStatus.connectionChange.listen(_connectionChanged);
  }

  /// It pauses the upload, the [_chunk] currently being uploaded will finish first before pausing the next [_chunk]
  pause() => _paused = true;

  /// It resumes the upload for the next [_chunk]
  resume() {
    if (!_paused) return;

    _paused = false;
    _sendChunks();
  }

  /// It gets [file]'s mime type, if possible
  _getMimeType() async {
    try {
      _fileMimeType = lookupMimeType(file.path);
    } catch (_) {
      _fileMimeType = null;
    }
  }

  /// It validates the passed options
  _validateOptions() {
    if (endPoint == null && endPointResolver == null)
      throw new Exception('either endPoint or endPointResolver must be defined');

    if (file == null)
      throw new Exception('file can''t be null');

    if (chunkSize != null && (chunkSize <= 0 || chunkSize % 64 != 0))
      throw new Exception('chunkSize must be a positive number in multiples of 64');

    if (attempts != null && attempts <= 0)
      throw new Exception('retries must be a positive number');

    if (delayBeforeAttempt != null && delayBeforeAttempt < 0)
      throw new Exception('delayBeforeAttempt must be a positive number');
  }

  /// Gets a value for [_endpointValue]
  ///
  /// If [endPoint] is provided it converts it to a Uri and returns the value,
  /// otherwise it uses [endPointResolver] to resolve the Uri value to return
  Future<Uri> _getEndpoint() async {
    if (endPoint != null) {
      _endpointValue = Uri.parse(endPoint);
      return _endpointValue;
    }

    endPoint = await endPointResolver;
    _endpointValue = Uri.parse(endPoint);
    return _endpointValue;
  }

  /// Callback for [ConnectionStatusSingleton] to notify connection changes
  ///
  /// if the connection drops [_offline] is marked as true and upload us paused,
  /// if connection is restore [_offline] is marked as false and resumes the upload
  _connectionChanged(dynamic hasConnection) {
    if (hasConnection) {
      if (!_offline)
        return;

      _offline = false;

      if (_onOnline != null) _onOnline();

      _sendChunks();
    }

    if (!hasConnection) {
      _offline = true;

      if (_onOffline != null) _onOffline();
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
      putHeaders.putIfAbsent(Headers.contentTypeHeader, () => _fileMimeType);
    }
    headers.forEach((key, value) => putHeaders.putIfAbsent(key, () => value));

    if (_onAttempt != null)
      _onAttempt(chunkNumber: _chunkCount, chunkSize: _chunkLength,);

    // returns future with http response
    return Dio().putUri(
      _endpointValue,
      options: Options(
        headers: putHeaders,
        followRedirects: false,
        validateStatus: (status) {
          return true;
        }
      ),
      data: _chunk,
      onSendProgress: (int sent, int total) {
        if (_onProgress != null) {
          final bytesSent = _chunkCount * _chunkByteSize;
          final percentProgress = (bytesSent + sent) * 100.0 / _fileSize;

          if (percentProgress < 100.0)
            _onProgress(progress: percentProgress);
        }
      },
    );
  }

  /// Gets [_chunk] and [_chunkLength] for the portion of the file of x bytes corresponding to [_chunkByteSize]
  _getChunk() {
    final length = _totalChunks == 1 ? _fileSize : _chunkByteSize;
    final start = length * _chunkCount;

    _chunk = file.openRead(start, start + length);
    if (start + length <= _fileSize)
      _chunkLength = length;
    else
      _chunkLength = _fileSize - start;
  }

  /// Called on net failure. If retry [_attemptCount] < [attempts], retry after [delayBeforeAttempt]
  _manageRetries() {
    if (_attemptCount < attempts) {
      _attemptCount = _attemptCount + 1;
      Timer(Duration(seconds: delayBeforeAttempt), () => _sendChunks());

      if (_onAttemptFailure != null)
        _onAttemptFailure(
          message:'An error occurred uploading chunk $_chunkCount. ${attempts - _attemptCount} retries left.',
          chunkNumber: _chunkCount,
          attemptsLeft: attempts - _attemptCount,
        );

      return;
    }

    _uploadFailed = true;

    if (_onError != null)
      _onError(
        message: 'An error occurred uploading chunk $_chunkCount. No more retries, stopping upload',
        chunk: _chunkCount,
        attempts: _attemptCount,
      );
  }

  /// Manages the whole upload by calling [_getChunk] and [_sendChunk]
  _sendChunks() {
    if (_paused || _offline)
      return;

    _getChunk();
    _sendChunk().then((res) {
        if (successfulChunkUploadCodes.contains(res.statusCode)) {
          _chunkCount++;
          if (_chunkCount < _totalChunks) {
            _sendChunks();
          } else {
            if (_onSuccess != null) _onSuccess();
          }

          if (_onProgress != null) {
            double percentProgress = 100.0;
            if (_chunkCount < _totalChunks) {
              final bytesSent = _chunkCount * _chunkByteSize;
              percentProgress = bytesSent * 100.0 / _fileSize;
            }
            _onProgress(progress: percentProgress);
          }
        } else if (temporaryErrorCodes.contains(res.statusCode)) {
          if (_paused || _offline)
            return;

          _manageRetries();
        } else {
          if (_paused || _offline)
            return;

          _uploadFailed = true;

          if (_onError != null)
            _onError(
              message: 'Server responded with ${res.statusCode}. Stopping upload.',
              chunk: _chunkCount,
              attempts: _attemptCount,
            );
        }
      },
      onError: (err) {
        if (_paused || _offline)
          return;

        // this type of error can happen after network disconnection on CORS setup
        _manageRetries();
      }
    );
  }

  /// Restarts the upload after if the upload failed and came to a complete stop
  restart() {
    if (!_uploadFailed)
      throw Exception('Upload hasn\'t yet failed, please use restart only after all retries have failed.');

    _chunkCount = 0;
    _chunkByteSize = chunkSize * 1024;
    _attemptCount = 0;
    _offline = false;
    _paused = false;
    _uploadFailed = false;

    _sendChunks();
  }
}
