# Flutter UpChunk

Flutter UpChunk is a simple port of the JS library https://github.com/muxinc/upchunk done by MUX, Inc.

## Installation

Add the package to the `dependencies` section in `pubspec.yaml`:
 - `flutter_upchunk: ^2.1.0` (or latest release)

## Usage

Add the following import to the `.dart` file that will use **UpChunk**

`import 'package:flutter_upchunk/flutter_upchunk.dart';`

### Example

```dart
final uploadUrl = '';
final filePath = '';

// Chunk upload
var upChunkUpload = UpChunk(
  endPoint: uploadUrl,
  file: XFile(filePath),
  onProgress: (progress) {
    print('Upload progress: ${progress.ceil()}%');
  },
  onError: (String message, int chunk, int attempts) {
    print('UpChunk error 💥 🙀:');
    print(' - Message: $message');
    print(' - Chunk: $chunk');
    print(' - Attempts: $attempts');
  },
  onSuccess: (response) {
    print('Upload complete! 👋 (status: ${response.statusCode})');
  },
);
```

Or `await` the upload instead of using callbacks:

```dart
final upChunk = UpChunk(
  endPoint: uploadUrl,
  file: XFile(filePath),
  onProgress: (progress) => print('Upload progress: ${progress.ceil()}%'),
);

final response = await upChunk.done; // throws on failure or stop()
print('Upload complete! 👋 (status: ${response.statusCode})');
```

## API

Although the API is a port of the original JS library, some options and properties differ slightly.

#### `UpChunk` constructor:

##### Upload options

- `endPoint` <small>type: `string` (required)</small>

  URL to upload the file to.

- `file` <small>type: [`XFile`](https://pub.dev/documentation/cross_file/latest/cross_file/XFile-class.html) (required)</small>

  The file you'd like to upload.

- `headers` <small>type: `Map<String, String>`</small>

  A `Map` with any headers you'd like included with the `PUT` request for each chunk.

- `chunkSize` <small>type: `integer`, default:`5120`</small>

  The size in kb of the chunks to split the file into, with the exception of the final chunk which may be smaller. This parameter should be in multiples of 64.

- `attempts` <small>type: `integer`, default: `5`</small>

  The number of times to retry any given chunk.

- `delayBeforeRetry` <small>type: `integer`, default: `1`</small>

  The time in seconds to wait before attempting to upload a chunk again.

- `chunkStart` <small>type: `integer`, default: `null`</small>

  The chunk number to start the upload from, useful in case the uploads fails in `x` chunk and the instance to the object is lost, UpChunk can pick up the upload from there.

##### Event options

- `onAttempt` <small>`{ chunkNumber: Integer, chunkSize: Integer }`</small>

  Fired immediately before a chunk upload is attempted. `chunkNumber` is the number of the current chunk being attempted, and `chunkSize` is the size (in bytes) of that chunk.

- `onAttemptFailure` <small>`{ message: String, chunkNumber: Integer, attemptsLeft: Integer }`</small>

  Fired when an attempt to upload a chunk fails.

- `onError` <small>`{ message: String, chunk: Integer, attempts: Integer }`</small>

  Fired when a chunk has reached the max number of retries or the response code is fatal and implies that retries should not be attempted.

- `onProgress` <small>`progress double [0..100]`</small>

  Fired continuously with incremental upload progress. This returns the current percentage of the file that's been uploaded.

- `onSuccess` <small>`{ response: Response }`</small>

  Fired when the upload is finished successfully, with the HTTP response of the final chunk.

### UpChunk Instance Methods

- `pause()`

  Pauses an upload after the current in-flight chunk is finished uploading.

- `resume()`

  Resumes an upload that was previously paused.

- `restart()`

  Restarts the upload from chunk `0`, **use only if and after `onError` was fired**.

- `stop()`

  Cancels the upload abruptly. `restart()` can be used to start the upload from chunk `0`.

### UpChunk Instance Properties

- `done`

  A `Future<Response>` that completes with the final chunk's HTTP response when the upload finishes, or completes with an error when the upload fails or `stop()` is called. After `restart()` it reflects the new attempt.

> **Note:** connection drops are handled by the retry logic (`attempts` retries, `delayBeforeRetry` seconds apart) and end in `onError` — there is no internet-connection watchdog anymore.

## Credit

Original code by MUX, Inc. and ported to Dart 🎯 with ❤ by a Flutter developer.
