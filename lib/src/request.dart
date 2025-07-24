import 'dart:io';

import 'package:http_hook/http_hook.dart';

/// Represents an intercepted HTTP request.
///
/// This object contains all essential metadata for a request,
/// including method, URL, headers, and optionally the body.
///
/// Note: Does **not** read the request body.
class HttpHookRequest {
  const HttpHookRequest({
    required this.url,
    required this.method,
    required this.headers,
  });

  /// The full request URL.
  final Uri url;

  /// The HTTP method (e.g., GET, POST, PUT).
  final HttpHookMethod method;

  /// The request headers as a flat key-value map.
  final Map<String, String> headers;

  /// Creates an [HttpHookRequest] from a [HttpClientRequest].
  static Future<HttpHookRequest> fromHttpClientRequest(
    HttpClientRequest request,
  ) async {
    final headers = <String, String>{};
    request.headers.forEach((name, values) {
      headers[name] = values.join(', ');
    });

    final HttpHookMethod method = HttpHookMethod.fromString(request.method);

    return HttpHookRequest(
      url: request.uri,
      method: method,
      headers: headers,
    );
  }

  @override
  String toString() {
    return 'HttpHookRequest{url: $url, method: $method, headers: $headers}';
  }
}
