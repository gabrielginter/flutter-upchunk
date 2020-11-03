# Flutter UpChunk

Flutter UpChunk is a simple port of the JS library https://github.com/muxinc/upchunk done by MUX inc.

## Installation

For the code to work, these 2 packages need to be added to the `dependencies` section in `pubspec.yaml`:
 - `connectivity: ^2.0.0` (or latest)
 - `dio: ^3.0.10` (or latest)

You can find these packages here:
 * https://pub.dev/packages/connectivity
 * https://pub.dev/packages/dio

Create your Flutter project and add these 2 files to your project in the right folder:
 - `up_chunk.dart` contains the UpChunk class to use directly in your code.
 - `connection_status_singleton.dart` a helper class used by `up_chunk.dart` to detect offline/online status changes during upload lifespan.

## Usage

Add the following import to the `Widget` that will use **UpChunk**

`import 'package:{your_app_name}/{your_folder_path}/up_chunk.dart';` (replace 'your_app_name' with your app package name and 'your_folder_path' with the folder path containing `up_chunk.dart`)

### Example

```dart
Future<String> _getUploadUrl() {
  String uploadUrl;
  // Perform call either to your API or directly to MUX to retrieve the upload URL
  // ...
  //
  
  return uploadUrl;
}

// Chunk upload
var uploadOptions = UpChunkOptions()
  ..endPointResolver = _getUploadUrl()
  ..file = File(_filePath)
  ..onProgress = ({ @required double progress }) {
    print('Upload progress: ${progress.ceil()}%');
  }
  ..onError = ({ @required String message, @required int chunk, @required int attempts }) {
    print('UpChunk error 💥 🙀:');
    print(' - Message: $message');
    print(' - Chunk: $chunk');
    print(' - Attempts: $attempts');
  }
  ..onSuccess = () {
    print('Upload complete! 👋');
  };
var upChunkUpload = UpChunk.createUpload(uploadOptions);
```

## API

Although the API is a port of the original JS library, some options and properties differ slightly.

### `createUpload(UpChunkOptions options)`

Returns an instance of `UpChunk` and begins uploading the specified `File`.

#### `UpChunkOptions` parameters:

##### Upload options

- `endPoint` <small>type: `string` (required if `endPointResolver` is `null`)</small>

  URL to upload the file to.

- `endPointResolver` <small>type: `Future<String>` (required if `endPoint` is `null`)</small>

   A `Future` that returns the URL as a `String`.

- `file` <small>type: [`File`](https://api.dart.dev/stable/2.10.3/dart-io/File-class.html) (required)</small>

  The file you'd like to upload. For example, you might just want to use the file from an input with a type of "file".

- `headers` <small>type: `Map<String, String>`</small>

  A `Map` with any headers you'd like included with the `PUT` request for each chunk.

- `chunkSize` <small>type: `integer`, default:`5120`</small>

  The size in kb of the chunks to split the file into, with the exception of the final chunk which may be smaller. This parameter should be in multiples of 64.

- `attempts` <small>type: `integer`, default: `5`</small>

  The number of times to retry any given chunk.

- `delayBeforeRetry` <small>type: `integer`, default: `1`</small>

  The time in seconds to wait before attempting to upload a chunk again.

##### Event options

- `onAttempt` <small>`{ chunkNumber: Integer, chunkSize: Integer }`</small>

  Fired immediately before a chunk upload is attempted. `chunkNumber` is the number of the current chunk being attempted, and `chunkSize` is the size (in bytes) of that chunk.

- `onAttemptFailure` <small>`{ message: String, chunkNumber: Integer, attemptsLeft: Integer }`</small>

  Fired when an attempt to upload a chunk fails.

- `onError` <small>`{ message: String, chunk: Integer, attempts: Integer }`</small>

  Fired when a chunk has reached the max number of retries or the response code is fatal and implies that retries should not be attempted.

- `onOffline`

  Fired when the client has gone offline.

- `onOnline`

  Fired when the client has gone online.

- `onProgress` <small>`progress double [0..100]`</small>

  Fired continuously with incremental upload progress. This returns the current percentage of the file that's been uploaded.

- `onSuccess`

  Fired when the upload is finished successfully.

### UpChunk Instance Methods

- `pause()`

  Pauses an upload after the current in-flight chunk is finished uploading.

- `resume()`

  Resumes an upload that was previously paused.

- `restart()`

  Restarts the upload from chunk `0`, **use only if and after `onError` was fired**.

## Credit

Original code by MUX, Inc. and ported to Dart 🎯 with ❤ by a Flutter developer. 
