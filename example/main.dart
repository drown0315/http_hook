import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_hook/http_hook.dart';

Future<void> main() async {
  print('=== HTTP Hook Examples ===\n');

  // Start HTTP Hook
  HttpHook.start();

  // Example 1: Exact URL matching
  print('1. Exact URL matching');
  HttpHook.on(
    'http://api.example.com/user/1',
    method: HttpHookMethod.get,
    respond: (req, match) => HttpHookResponse.json({
      'id': 1,
      'name': 'Alice',
      'email': 'alice@example.com',
    }),
  );

  final response1 = await http.get(Uri.parse('http://api.example.com/user/1'));
  print('Response: ${response1.body}\n');

  // Example 2: Path template matching
  print('2. Path template matching');
  HttpHook.onTemplate(
    'http://httpbin.org',
    template: '/user/:id',
    method: HttpHookMethod.get,
    respond: (req, match) {
      final id = match.params!['id'];
      return HttpHookResponse.json({
        'id': id,
        'name': 'User $id',
        'profile': 'Profile for user $id',
      });
    },
  );

  final response2 = await http.get(Uri.parse('http://httpbin.org/user/123'));
  print('Response: ${response2.body}\n');

  // Example 3: Regular expression matching
  print('3. Regular expression matching');
  HttpHook.onRegex(
    'http://httpbin.org',
    regex: RegExp(r'^/search/(.+)$'),
    method: HttpHookMethod.get,
    respond: (req, match) {
      final keyword = match.regexMatch!.group(1);
      return HttpHookResponse.json({
        'keyword': keyword,
        'results': [
          {
            'title': '$keyword related result 1',
            'url': 'https://example.com/1'
          },
          {
            'title': '$keyword related result 2',
            'url': 'https://example.com/2'
          },
        ],
      });
    },
  );

  final response3 =
      await http.get(Uri.parse('http://httpbin.org/search/flutter'));
  print('Response: ${response3.body}\n');

  // Example 4: POST request handling
  print('4. POST request handling');
  HttpHook.on(
    'http://httpbin.org/login',
    method: HttpHookMethod.post,
    respond: (req, match) {
      print('Request headers: ${req.headers}');

      // Note: HttpHookRequest doesn't include body data
      // For this example, we'll simulate login logic
      return HttpHookResponse.json({
        'success': true,
        'token': 'mock_jwt_token_12345',
        'message': 'Login successful',
      });
    },
  );

  final response4 = await http.post(
    Uri.parse('http://httpbin.org/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'username': 'admin', 'password': '123456'}),
  );
  print('Response: ${response4.body}\n');

  // Example 5: Simulating delay and errors
  print('5. Simulating delayed response');
  HttpHook.on(
    'http://httpbin.org/slow',
    method: HttpHookMethod.get,
    respond: (req, match) async {
      print('Processing slow request...');
      await Future.delayed(const Duration(seconds: 1));
      print('Slow request completed');
      return HttpHookResponse.json({'message': 'This is a slow response'});
    },
  );

  final stopwatch = Stopwatch()..start();
  final response5 = await http.get(Uri.parse('http://httpbin.org/slow'));
  stopwatch.stop();
  print('Response time: ${stopwatch.elapsedMilliseconds}ms');
  print('Response: ${response5.body}\n');

  // Example 6: Simulating network error
  print('6. Simulating network error');
  HttpHook.on(
    'http://httpbin.org/error',
    method: HttpHookMethod.get,
    respond: (req, match) {
      throw SocketException('Simulated network connection failure');
    },
  );

  try {
    await http.get(Uri.parse('http://httpbin.org/error'));
  } catch (e) {
    print('Caught exception: $e\n');
  }

  // Example 7: Different HTTP methods
  print('7. Different HTTP methods');

  // PUT request
  HttpHook.on(
    'http://api.example.com/user/1',
    method: HttpHookMethod.put,
    respond: (req, match) => HttpHookResponse.json({
      'message': 'User updated successfully',
      'url': req.url.toString(),
    }),
  );

  final putResponse = await http.put(
    Uri.parse('http://api.example.com/user/1'),
    body: jsonEncode({'name': 'Bob'}),
  );
  print('PUT Response: ${putResponse.body}');

  // DELETE request
  HttpHook.on(
    'http://api.example.com/user/1',
    method: HttpHookMethod.delete,
    respond: (req, match) => HttpHookResponse.json({
      'message': 'User deleted successfully',
    }),
  );

  final deleteResponse =
      await http.delete(Uri.parse('http://api.example.com/user/1'));
  print('DELETE Response: ${deleteResponse.body}\n');

  // Cleanup and stop Hook
  print('Cleaning up HTTP Hook');
  HttpHook.destroy();
  print('HTTP Hook stopped');
}
