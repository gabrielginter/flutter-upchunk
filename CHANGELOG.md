# CHANGES

## [1.0.0-dev.1] - 2021-03-09

* Updated example and readme file

## [1.0.0-dev.0] - 2021-03-09

* Null safety migration
* [Breaking Changes]: All callback event parameters are now _positional_ instead of _named_ to simplify client code

## [0.1.5] - 2020-11-18

* Restart was not being exectuted when called, flag marking the failed upload was missing

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
