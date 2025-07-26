# Changelog

## [0.0.2]

### Features
* **Pass-through functionality**: Added `HttpHookResponse.passThrough()` for conditional real HTTP requests
* **Wildcard host matching**: `onTemplate` and `onRegex` without `defaultUrl` parameter match any host  

### Breaking Changes
* `defaultUrl` parameter in `onTemplate`/`onRegex` is now optional with default empty string for wildcard support

## [0.0.1]

* initial release.