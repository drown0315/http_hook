# Changelog

## [0.0.2]

### Features
* **Pass-through functionality**: Added `HttpHookResponse.passThrough()` for conditional real HTTP requests
* **Wildcard host matching**: Support null `defaultUrl` in `onTemplate` and `onRegex` to match any host  
* **Enhanced API**: Made `method` parameter required across all hook methods for better type safety

### Breaking Changes
* `defaultUrl` parameter in `onTemplate`/`onRegex` is now nullable for wildcard support

## [0.0.1]

* initial release.