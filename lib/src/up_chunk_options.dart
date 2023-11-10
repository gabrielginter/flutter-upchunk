import 'dart:io';

/// Defines the options to be passed to [UpChunk]'s [createUpload] method
class UpChunkOptions {
  /// Upload url as [String], required if [endPointResolver] == null
  String? endPoint;

  /// Future that returns the upload url as [String], required if [endPoint] == null
  Future<String>? endPointResolver;

  /// [File] to upload, required
  File? file;

  /// A Map with any headers you'd like included with the PUT request for each chunk.
  Map<String, String> headers = Map<String, String>();

  /// The size in kb of the chunks to split the file into,
  /// with the exception of the final chunk which may be smaller.
  /// This parameter should be in multiples of 64
  int chunkSize = 5120;

  /// The size in kb of the chunks to split the file into,
  /// with the exception of the final chunk which may be smaller.
  /// This parameter should be in multiples of 64
  int? startChunk = 0;

  /// The number of times to retry any given chunk.
  int attempts = 5;

  /// Sets the start chunk of the uploader
  int delayBeforeAttempt = 1;

  /// Fired when the client has gone online.
  void Function()? onOnline;

  /// Fired when the client has gone offline.
  void Function()? onOffline;

  /// Fired immediately before a chunk upload is attempted.
  ///
  /// [chunkNumber] is the number of the current chunk being attempted,
  /// and [chunkSize] is the size (in bytes) of that chunk.
  void Function(int chunkNumber, int chunkSize)? onAttempt;

  /// Fired when an attempt to upload a chunk fails.
  ///
  /// [message] is the error message
  /// [chunkNumber] is the number of the current chunk being attempted,
  /// and [attemptsLeft] is the number of attempts left before stopping the upload
  void Function(String message, int chunkNumber, int attemptsLeft)?
      onAttemptFailure;

  /// Fired when a chunk has reached the max number of retries or the response code is fatal and implies that retries should not be attempted.
  void Function(String message, int chunk, int attempts)? onError;

  /// Fired when the upload is finished successfully.
  void Function()? onSuccess;

  /// Fired continuously with incremental upload progress. This returns the current percentage of the file that's been uploaded.
  ///
  /// [progress] a number from 0 to 100 representing the percentage of the file uploaded
  void Function(double progress, int chunk)? onProgress;
}
