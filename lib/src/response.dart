import 'dart:convert';

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
  });

  /// The HTTP status code to return (e.g. 200, 404, 500).
  final int statusCode;

  /// The response headers to include.
  ///
  /// Example:
  /// ```dart
  /// {'content-type': 'application/json'}
  /// ```
  final Map<String, String> headers;

  /// The response body, as a plain string.
  ///
  /// If you're returning JSON, consider using [HttpHookResponse.json].
  final String body;

  /// An optional human-readable reason phrase.
  ///
  /// For example: `"OK"`, `"Not Found"`, `"Internal Server Error"`.
  final String? reasonPhrase;

  /// Creates a simple 200 OK response.
  ///
  /// [body] Optional response body as string. Defaults to empty string.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.ok('pong');
  /// ```
  factory HttpHookResponse.ok([String body = '']) {
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

  /// Creates an error response with a given status code and optional body,
  /// reason phrase, and headers.
  ///
  /// [statusCode] The HTTP status code representing the error.
  ///
  /// [body] Optional response body as string. Defaults to empty.
  ///
  /// [reasonPhrase] Optional human-readable status message.
  ///
  /// [headers] Optional additional response headers.
  ///
  /// Example:
  /// ```dart
  /// HttpHookResponse.error(404, body: 'Not Found');
  /// ```
  factory HttpHookResponse.error(
    int statusCode, {
    String? body,
    String? reasonPhrase,
    Map<String, String>? headers,
  }) {
    return HttpHookResponse(
      statusCode: statusCode,
      body: body ?? '',
      reasonPhrase: reasonPhrase,
      headers: headers ?? const {},
    );
  }

  @override
  String toString() {
    return 'HttpHookResponse(statusCode: $statusCode, body: ${body.length} chars)';
  }
}
