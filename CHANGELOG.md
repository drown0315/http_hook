# Changelog

## [0.0.4]

### Features
* **Flexible Response Body Types**: Support for String, List<int>, and Stream<List<int>>
* **Binary Response Support**: Added `HttpHookResponse.binary()` factory for binary data
* **Streaming Response Support**: Added `HttpHookResponse.stream()` factory for streaming data
* **Common HTTP Status Responses**: Added convenient factories for common HTTP status codes
  - `HttpHookResponse.notFound()` - 404 Not Found
  - `HttpHookResponse.internalServerError()` - 500 Internal Server Error
  - `HttpHookResponse.badRequest()` - 400 Bad Request
  - `HttpHookResponse.unauthorized()` - 401 Unauthorized
  - `HttpHookResponse.forbidden()` - 403 Forbidden

### Improvements
* **Enhanced Response Flexibility**: HttpHookResponse.body now accepts String, List<int>, and Stream<List<int>>
* **Better Binary Data Handling**: Native support for binary responses without string conversion
* **Streaming Capabilities**: Direct support for streaming responses for large data scenarios
* **Simplified Async Handling**: Async operations are handled in the response handler, not in the response body
* **Removed Redundant API**: Removed `HttpHookResponse.error()` as it was functionally equivalent to the constructor

### Documentation
* **Added Examples**: New examples for binary, streaming, and async responses

## [0.0.3]

### Documentation
* **Updated Documentation**: Removed outdated HTTPS limitation notices

## [0.0.2]

### Features
* **Pass-through functionality**: Added `HttpHookResponse.passThrough()` for conditional real HTTP requests
* **Wildcard host matching**: `onTemplate` and `onRegex` without `defaultUrl` parameter match any host

### Breaking Changes
* `defaultUrl` parameter in `onTemplate`/`onRegex` is now optional with default empty string for wildcard support

## [0.0.1]

* initial release.