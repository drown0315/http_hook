import 'package:http_hook/http_hook.dart';
import 'package:test/test.dart';

/// Convenient HTTP mocking function for tests.
///
/// Automatically starts [HttpHook] if it is not started yet.
/// It is recommended to use this function together with `tearDown`
/// to clean up the mocked hooks after each test.
///
/// Parameters:
/// - [url]: The URL string to intercept and mock. The hook will trigger on requests matching this URL.
/// - [method]: The HTTP method to match for the hook (e.g., GET, POST). Defaults to [HttpHookMethod.get].
/// - [reply]: The optional response body to return. If provided, the response will be JSON serialized.
/// - [statusCode]: The HTTP status code to return with the mock response. Defaults to 200.
/// - [headers]: Optional HTTP headers to include in the response.
/// - [autoTearDown]: Whether to automatically register a `tearDown` callback to
/// remove the hook after the test. Defaults to true.
///
/// Example usage:
/// ```dart
/// test('mock HTTP GET request', () async {
///   mockHttp(
///     'https://api.example.com/data',
///     method: HttpHookMethod.get,
///     reply: {'message': 'success'},
///     statusCode: 200,
///   );
///
///   final response = await http.get(Uri.parse('https://api.example.com/data'));
///   expect(response.statusCode, 200);
///   expect(response.body, contains('success'));
/// });
void mockHttp(
  String url, {
  HttpHookMethod method = HttpHookMethod.get,
  String? reply,
  int statusCode = 200,
  Map<String, String>? headers,
  bool autoTearDown = true,
}) {
  if (!HttpHook.isStarted) {
    HttpHook.start();
  }

  if (autoTearDown) {
    addTearDown(() {
      HttpHook.off(url);
    });
  }

  HttpHook.on(
    url,
    method: method,
    respond: (request, match) {
      if (reply != null) {
        return HttpHookResponse(
            statusCode: statusCode, headers: headers ?? const {}, body: reply);
      } else {
        return HttpHookResponse(
          statusCode: statusCode,
          headers: headers ?? const {},
        );
      }
    },
  );
}
