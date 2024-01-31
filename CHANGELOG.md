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
