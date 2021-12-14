# CHANGES

## [1.2.0] - 2021-12-14

* Updated packages and migration to flutter 2.8.0

## [1.1.0] - 2021-09-11

* Migrated from the deprecated connectivity plugin to connectivity_plus.
* Added method `stop` to cancel uploads abruptly, Issue #2.

## [1.0.0] - 2021-03-29

* Null safety migration
* [Breaking Changes]: All callback event parameters are now _positional_ instead of _named_ to simplify client code

## [0.1.5] - 2020-11-18

* Restart was not being executed when called, flag marking the failed upload was missing

## [0.1.4] - 2020-11-09

* Added documentation
* Added example

## [0.1.3] - 2020-11-04

* Fix on `onProgress` callback, method `_sendChunks` was reporting inaccurate value (slightly less than real).

## [0.1.2] - 2020-11-04

* Updated readme file with the correct import directive

## [0.1.1] - 2020-11-04

* Tested on live project and ready for use
* Making ConnectionStatusSingleton private
* Changing file structure

## [0.1.0] - 2020-11-04

* Initial release, not yet tested on a project
