import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:dio/dio.dart';
import 'package:mime/mime.dart';

import 'connection_status_singleton.dart';

class UpChunkOptions {
  String endPoint;
  Future<String> endPointResolver;
  File file;
  Map<String, String> headers;
  int chunkSize;
  int attempts;
  int delayBeforeAttempt;

  void Function() onOnline;
  void Function() onOffline;
  void Function({ @required int chunkNumber, @required int chunkSize }) onAttempt;
  void Function({ @required String message, @required int chunkNumber, @required int attemptsLeft }) onAttemptFailure;
  void Function({ @required String message, @required int chunk, @required int attempts }) onError;
  void Function() onSuccess;
  void Function({ @required double progress }) onProgress;
}

class UpChunk {
  final successfulChunkUploadCodes = const [200, 201, 202, 204, 308];
  final temporaryErrorCodes = const [408, 502, 503, 504]; // These error codes imply a chunk may be retried

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

  void Function() _onOnline;
  void Function() _onOffline;
  void Function({ @required int chunkNumber, @required int chunkSize }) _onAttempt;
  void Function({ @required String message, @required int chunkNumber, @required int attemptsLeft }) _onAttemptFailure;
  void Function({ @required String message, @required int chunk, @required int attempts }) _onError;
  void Function() _onSuccess;
  void Function({ @required double progress }) _onProgress;

  static UpChunk createUpload(UpChunkOptions options) => UpChunk._internal(options);

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

  pause() => _paused = true;

  resume() {
    if (!_paused) return;

    _paused = false;
    _sendChunks();
  }

  _getMimeType() async {
    try {
      _fileMimeType = lookupMimeType(file.path);
    } catch (_) {
      _fileMimeType = null;
    }
  }

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

  Future<Uri> _getEndpoint() async {
    if (endPoint != null) {
      _endpointValue = Uri.parse(endPoint);
      return _endpointValue;
    }

    endPoint = await endPointResolver;
    _endpointValue = Uri.parse(endPoint);
    return _endpointValue;
  }

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

  // Send chunk of the file with appropriate headers and add post parameters if it's last chunk
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

    // returns future with http response
    if (_onAttempt != null)
      _onAttempt(chunkNumber: _chunkCount, chunkSize: _chunkLength,);

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
          final percentProgress = (bytesSent + sent) * 100 / _fileSize;

          if (percentProgress != 100)
            _onProgress(progress: percentProgress);
        }
      },
    );
  }

  // Get portion of the file of x bytes corresponding to chunkSize
  _getChunk() {
    // Since we start with 0-chunkSize for the range, we need to subtract 1.
    final length = _totalChunks == 1 ? _fileSize : _chunkByteSize;
    final start = length * _chunkCount;

    _chunk = file.openRead(start, start + length);
    if (start + length <= _fileSize)
      _chunkLength = length;
    else
      _chunkLength = _fileSize - start;
  }

  // Called on net failure. If retry counter !== 0, retry after delayBeforeAttempt
  _manageRetries() {
    if (_attemptCount < attempts) {
      _attemptCount = _attemptCount + 1;
      Timer(Duration(milliseconds: 1000), () => _sendChunks());

      if (_onAttemptFailure != null)
        _onAttemptFailure(
          message:'An error occurred uploading chunk $_chunkCount. ${attempts - _attemptCount} retries left.',
          chunkNumber: _chunkCount,
          attemptsLeft: attempts - _attemptCount,
        );

      return;
    }

    if (_onError != null)
      _onError(
        message: 'An error occurred uploading chunk $_chunkCount. No more retries, stopping upload',
        chunk: _chunkCount,
        attempts: _attemptCount,
      );
  }

  // Manage the whole upload by calling getChunk & sendChunk
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
            final percentProgress = (100 / _totalChunks) * _chunkCount;
            _onProgress(progress: percentProgress);
          }
        } else if (temporaryErrorCodes.contains(res.statusCode)) {
          if (_paused || _offline)
            return;

          _manageRetries();
        } else {
          if (_paused || _offline)
            return;

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

  restart() {
    _chunkCount = 0;
    _chunkByteSize = chunkSize * 1024;
    _attemptCount = 0;
    _offline = false;
    _paused = false;

    _sendChunks();
  }
}
