## 2.1.0

**Breaking**

* `onSuccess` now receives the HTTP `Response` of the final chunk: `onSuccess: (response) { ... }`. Migration: add the parameter to your callback (and use it, or ignore it).

**Fixes**

* Uploads no longer stall silently mid-way ([#8](https://github.com/gabrielginter/flutter-upchunk/issues/8), [#12](https://github.com/gabrielginter/flutter-upchunk/issues/12)). The internet-connection watchdog probed the upload endpoint's origin and treated any non-200 reply as *offline* — hosts such as the GCS origin behind Mux direct-upload URLs answer plain probes with 400, so seconds into an upload the check flagged the connection as lost and paused the upload with no error and no way to resume.
* No more concurrent chunk uploads corrupting each other's state ([#12](https://github.com/gabrielginter/flutter-upchunk/issues/12)): the send loop is re-entrancy guarded and stale chunk completions (from a `stop()`/`restart()` while a request was in flight) are discarded, so `content-range` headers can no longer be computed from clobbered state.
* Errors while preparing the upload (e.g. an unreadable file) are now surfaced through `onError` and `done` instead of failing silently ([#11](https://github.com/gabrielginter/flutter-upchunk/issues/11)).
* `stop()` no longer throws when called before the first chunk request is issued, and no callbacks fire after it.

**Changes**

* **Removed the internet-connection watchdog** and the `internet_connection_checker_plus` dependency ([#11](https://github.com/gabrielginter/flutter-upchunk/issues/11)). Connection drops are handled by the retry logic (`attempts` × `delayBeforeAttempt`) ending in `onError`. `connectionCheckEndpoint`, `onOnline` and `onOffline` are now deprecated no-ops.
* A single HTTP client is reused for the whole upload instead of creating one per chunk.

**Additions**

* `Future<Response> done` — await the whole upload; completes with the final chunk's response, or with an error on failure or `stop()` ([#10](https://github.com/gabrielginter/flutter-upchunk/issues/10)).

The `onSuccess` signature change also resolves [#9](https://github.com/gabrielginter/flutter-upchunk/issues/9) (final response exposed to the success callback).

## 2.0.3

* Updated all packages and bumped dart/flutter versions

## 2.0.2

* [**Issue #4**](https://github.com/gabrielginter/flutter-upchunk/issues/4): Ability to clarify the chunk in which to start the upload using `chunkStart` in the constructor.

## 2.0.1

* Internet checkup based on endpoint
* Added comments to constructor properties
* Updated README.md

## 2.0.0

* Added web support and replaced connectivity_plus with [internet_connection_checker_plus](https://pub.dev/packages/internet_connection_checker_plus)

## 1.6.1

* Updated README.md

## 1.6.0

**Updates**

* Updated all packages


**Breaking Changes**

* Remove UpChunkOptions, use UpChunk constructor instead
* Migrated from File to XFile
* Removed endpoint resolver, provide an endpoint string instead

## 1.5.0

* Updated packages

## 1.4.0

* Updated packages

## 1.3.1

* Updated packages

## 1.3.0

* Updated packages and migration to flutter 2.10.1

## 1.2.0

* Updated packages and migration to flutter 2.8.0

## 1.1.0

* Migrated from the deprecated connectivity plugin to connectivity_plus.
* Added method `stop` to cancel uploads abruptly, [**Issue #2**](https://github.com/gabrielginter/flutter-upchunk/issues/2).

## 1.0.0

* Null safety migration
* [Breaking Changes]: All callback event parameters are now _positional_ instead of _named_ to simplify client code

## 0.1.5

* Restart was not being executed when called, flag marking the failed upload was missing

## 0.1.4

* Added documentation
* Added example

## 0.1.3

* Fix on `onProgress` callback, method `_sendChunks` was reporting inaccurate value (slightly less than real).

## 0.1.2

* Updated readme file with the correct import directive

## 0.1.1

* Tested on live project and ready for use
* Making ConnectionStatusSingleton private
* Changing file structure

## 0.1.0

* Initial release, not yet tested on a project
