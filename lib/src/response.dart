import 'dart:convert';
import 'dart:async';

/// Represents a mock HTTP response.
///
/// You can construct it manually, or use one of the convenience
/// factories like [HttpHookResponse.ok], [HttpHookResponse.json],
/// or [HttpHookResponse.error].
class HttpHookResponse {
  const HttpHookResponse({
    required this.statusCode,
    this.headers = const {},
    this.body = '',
    this.reasonPhrase,
    this.isPassThrough = false,
  });

  const HttpHookResponse._passThrough()
      : statusCode = 0,
        headers = const {},
        body = '',
        reasonPhrase = null,
        isPassThrough = true;

  /// The HTTP status code to return (e.g. 200, 404, 500).
  final int statusCode;

  /// The response headers to include.
  ///
  /// Example:
  /// ```dart
  /// {'content-type': 'application/json'}
  /// ```
  final Map<String, String> headers;

  /// The response body, which can be:
  /// - String: Plain text or JSON string
  /// - List<int>: Raw bytes (e.g., for binary data)
  /// - Stream<List<int>>: Streaming response
  ///
  /// Examples:
  /// ```dart
  /// // String response
  /// HttpHookResponse(body: 'Hello World');
  ///
  /// // Binary response
  /// HttpHookResponse(body: [0x89, 0x50, 0x4E, 0x47]); // PNG header
  ///
  /// // Streaming response
  /// HttpHookResponse(body: Stream.fromIterable([
  ///   utf8.encode('Hello'),
  ///   utf8.encode(' '),
  ///   utf8.encode('World'),
  /// ]));
  /// ```
  final dynamic body;

  /// An optional human-readable reason phrase.
  ///
  /// For example: `"OK"`, `"Not Found"`, `"Internal Server Error"`.
  final String? reasonPhrase;

  /// Whether this response should pass through to make a real HTTP request.
  ///
  /// When true, the HttpHook will not intercept this request and will
  /// allow it to proceed to make a real network call.
  final bool isPassThrough;

  /// Creates a pass-through response that allows the request to proceed
  /// to make a real HTTP call instead of being mocked.
  ///
  /// Example:
  /// ```dart
  /// HttpHook.onRegex(
  ///   'http://api.example.com',
  ///   regex: RegExp(r'^/user/(.+)$'),
  ///   method: HttpHookMethod.get,
  ///   respond: (req, match) {
  ///     final userId = match.regexMatch!.group(1);
  ///     if (userId == 'real') {
  ///       return HttpHookResponse.passThrough(); // Make real request
  ///     }
  ///     return HttpHookResponse.json({'mock': 'data'});
  ///   },
  /// );
  /// ```
  factory HttpHookResponse.passThrough() {
    return const HttpHookResponse._passThrough();
  }

  /// Creates a simple 200 OK response.
  ///
  /// [body] Optional response body. Can be String, List<int>, or Stream<List<int>>.
  /// Defaults to empty string.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.ok('pong');
  /// HttpHookResponse.ok([0x48, 0x65, 0x6C, 0x6C, 0x6F]); // "Hello" in bytes
  /// ```
  factory HttpHookResponse.ok([dynamic body = '']) {
    return HttpHookResponse(
      statusCode: 200,
      body: body,
    );
  }

  /// Creates a JSON response with the given data serialized as JSON.
  ///
  /// [data] The object to serialize to JSON in the response body.
  ///
  /// [statusCode] The HTTP status code to return. Defaults to 200.
  ///
  /// [headers] Optional additional headers to include.
  /// The `content-type` header will be set to
  /// `'application/json; charset=utf-8'` automatically and
  /// merged with any headers you provide.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.json({'id': 1, 'name': 'Alice'});
  /// ```
  factory HttpHookResponse.json(
    Object data, {
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final jsonHeaders = <String, String>{
      'content-type': 'application/json; charset=utf-8',
      ...?headers,
    };

    return HttpHookResponse(
      statusCode: statusCode,
      headers: jsonHeaders,
      body: jsonEncode(data),
    );
  }

  /// Creates a 404 Not Found response.
  ///
  /// [body] Optional response body. Defaults to 'Not Found'.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.notFound();
  /// HttpHookResponse.notFound('Resource not found');
  /// ```
  factory HttpHookResponse.notFound([String body = 'Not Found']) {
    return HttpHookResponse(
      statusCode: 404,
      body: body,
      reasonPhrase: 'Not Found',
      headers: const {},
    );
  }

  /// Creates a 500 Internal Server Error response.
  ///
  /// [body] Optional response body. Defaults to 'Internal Server Error'.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.internalServerError();
  /// HttpHookResponse.internalServerError('Database connection failed');
  /// ```
  factory HttpHookResponse.internalServerError(
      [String body = 'Internal Server Error']) {
    return HttpHookResponse(
      statusCode: 500,
      body: body,
      reasonPhrase: 'Internal Server Error',
      headers: const {},
    );
  }

  /// Creates a 400 Bad Request response.
  ///
  /// [body] Optional response body. Defaults to 'Bad Request'.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.badRequest();
  /// HttpHookResponse.badRequest('Invalid parameters');
  /// ```
  factory HttpHookResponse.badRequest([String body = 'Bad Request']) {
    return HttpHookResponse(
      statusCode: 400,
      body: body,
      reasonPhrase: 'Bad Request',
      headers: const {},
    );
  }

  /// Creates a 401 Unauthorized response.
  ///
  /// [body] Optional response body. Defaults to 'Unauthorized'.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.unauthorized();
  /// HttpHookResponse.unauthorized('Invalid credentials');
  /// ```
  factory HttpHookResponse.unauthorized([String body = 'Unauthorized']) {
    return HttpHookResponse(
      statusCode: 401,
      body: body,
      reasonPhrase: 'Unauthorized',
      headers: const {},
    );
  }

  /// Creates a 403 Forbidden response.
  ///
  /// [body] Optional response body. Defaults to 'Forbidden'.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.forbidden();
  /// HttpHookResponse.forbidden('Access denied');
  /// ```
  factory HttpHookResponse.forbidden([String body = 'Forbidden']) {
    return HttpHookResponse(
      statusCode: 403,
      body: body,
      reasonPhrase: 'Forbidden',
      headers: const {},
    );
  }

  /// Creates a response with binary data.
  ///
  /// [data] The binary data as List<int>.
  ///
  /// [contentType] The content type header. Defaults to 'application/octet-stream'.
  ///
  /// [statusCode] The HTTP status code. Defaults to 200.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.binary(
  ///   [0x89, 0x50, 0x4E, 0x47], // PNG header
  ///   contentType: 'image/png',
  /// );
  /// ```
  factory HttpHookResponse.binary(
    List<int> data, {
    String contentType = 'application/octet-stream',
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final binaryHeaders = <String, String>{
      'content-type': contentType,
      ...?headers,
    };

    return HttpHookResponse(
      statusCode: statusCode,
      headers: binaryHeaders,
      body: data,
    );
  }

  /// Creates a streaming response.
  ///
  /// [stream] The stream of data chunks.
  ///
  /// [contentType] The content type header. Defaults to 'text/plain'.
  ///
  /// [statusCode] The HTTP status code. Defaults to 200.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.stream(
  ///   Stream.fromIterable([
  ///     utf8.encode('Hello'),
  ///     utf8.encode(' '),
  ///     utf8.encode('World'),
  ///   ]),
  ///   contentType: 'text/plain',
  /// );
  /// ```
  factory HttpHookResponse.stream(
    Stream<List<int>> stream, {
    String contentType = 'text/plain',
    int statusCode = 200,
    Map<String, String>? headers,
  }) {
    final streamHeaders = <String, String>{
      'content-type': contentType,
      ...?headers,
    };

    return HttpHookResponse(
      statusCode: statusCode,
      headers: streamHeaders,
      body: stream,
    );
  }

  @override
  String toString() {
    final bodyType = body.runtimeType.toString();
    final bodyLength = body is String
        ? body.length
        : body is List<int>
            ? body.length
            : body is Stream<List<int>>
                ? 'stream'
                : 'future';
    return 'HttpHookResponse(statusCode: $statusCode, body: $bodyType($bodyLength))';
  }
}
