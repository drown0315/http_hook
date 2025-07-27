# 📦 HttpHook

[English](README.md) | [中文](README_ZH.md)

A lightweight and flexible Dart HTTP request interception and mocking library for testing and debugging. Supports precise URL matching, path template matching, regex matching, and dynamic response generation.



## ✨ Features

- **Multiple Matching Strategies**: Exact URL, path templates (`/user/:id`), and regex patterns
- **Dynamic Response Generation**: Create responses based on request data
- **Error & Delay Simulation**: Mock network errors and delayed responses
- **Easy Testing Integration**: Convenient `mockHttp()` function for quick testing
- **Lifecycle Management**: Start/stop interception as needed

## 🚀 Quick Start

### Simple Mocking with `mockHttp()`

For quick testing scenarios, use the convenient `mockHttp()` function:

```dart
import 'package:http_hook/http_hook.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('mock HTTP GET request', () async {
    mockHttp(
      'http://api.example.com/user/1',
      method: HttpHookMethod.get,
      reply: jsonEncode({'id': 1, 'name': 'Alice'}),
    );

    final response = await http.get(Uri.parse('http://api.example.com/user/1'));
    expect(jsonDecode(response.body)['name'], 'Alice');
  });
}
```

- Automatically starts `HttpHook`
- Automatically registers `tearDown()` cleanup
- Simple JSON response handling

## 🧠 Advanced Usage

For more complex scenarios requiring multiple matching strategies, dynamic responses, and error simulation, use the `HttpHook` class directly.

### Starting and Stopping

```dart
void main() {
  setUp(() => HttpHook.start());
  tearDown(() => HttpHook.destroy());
  
  // Your tests here
}
```

### 1. Exact URL Matching

```dart
HttpHook.on(
  'http://api.example.com/user/1',
  method: HttpHookMethod.get,
  respond: (req, match) => HttpHookResponse.json({
    'id': 1,
    'name': 'Alice',
    'email': 'alice@example.com',
  }),
);
```

### 2. Path Template Matching

Extract parameters from URL paths:

```dart
HttpHook.onTemplate(
  defaultUrl: 'http://api.example.com', 
  template: '/user/:id',
  method: HttpHookMethod.get,
  respond: (req, match) {
    final id = match.params!['id'];
    return HttpHookResponse.json({
      'id': id,
      'name': 'User $id',
    });
  },
);

// Match ANY host with the template
HttpHook.onTemplate(
  template: '/user/:id',
  method: HttpHookMethod.get,
  respond: (req, match) {
    final id = match.params!['id'];
    return HttpHookResponse.json({
      'id': id,
      'name': 'User $id',
      'host': req.url.host,  // Shows which host was matched
    });
  },
);
```

### 3. Regular Expression Matching

Use regex for complex URL patterns:

```dart
// Match specific host
HttpHook.onRegex(
  defaultUrl: 'http://api.example.com',
  regex: RegExp(r'^/search/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final keyword = match.regexMatch!.group(1);
    return HttpHookResponse.json({
      'keyword': keyword,
      'results': ['Result 1', 'Result 2'],
    });
  },
);

// Match ANY host with the regex pattern (wildcard)
HttpHook.onRegex(
  regex: RegExp(r'^/api/v1/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final endpoint = match.regexMatch!.group(1);
    return HttpHookResponse.json({
      'endpoint': endpoint,
      'host': req.url.host,
      'message': 'Universal API interceptor!',
    });
  },
);
```

### 4. HTTP Methods

Support for all HTTP methods:

```dart
// POST request
HttpHook.on(
  'http://api.example.com/login',
  method: HttpHookMethod.post,
  respond: (req, match) => HttpHookResponse.json({
    'token': 'abc123',
    'success': true,
  }),
);

// PUT request
HttpHook.on(
  'http://api.example.com/user/1',
  method: HttpHookMethod.put,
  respond: (req, match) => HttpHookResponse.json({
    'message': 'User updated',
  }),
);

// DELETE request
HttpHook.on(
  'http://api.example.com/user/1',
  method: HttpHookMethod.delete,
  respond: (req, match) => HttpHookResponse.json({
    'message': 'User deleted',
  }),
);
```

## 🔧 Response Types

### JSON Responses

```dart
HttpHookResponse.json({'key': 'value'})
```

### Plain Text Responses

```dart
HttpHookResponse.ok('Plain text response')
```

### Binary Responses

```dart
// Binary data
HttpHookResponse.binary(
  [0x89, 0x50, 0x4E, 0x47], // PNG header
  contentType: 'image/png',
);

// Or use the general constructor
HttpHookResponse(
  statusCode: 200,
  body: [0x48, 0x65, 0x6C, 0x6C, 0x6F], // "Hello" in bytes
  headers: {'content-type': 'application/octet-stream'},
);
```

### Streaming Responses

```dart
// Stream data chunks
HttpHookResponse.stream(
  Stream.fromIterable([
    utf8.encode('Hello'),
    utf8.encode(' '),
    utf8.encode('World'),
  ]),
  contentType: 'text/plain',
);
```

### Async Handler Responses

```dart
// Async handler with string response
HttpHook.on(
  'http://api.example.com/async',
  method: HttpHookMethod.get,
  respond: (req, match) async {
    final data = await someAsyncOperation();
    return HttpHookResponse.ok(data);
  },
);

// Async handler with stream response
HttpHook.on(
  'http://api.example.com/stream',
  method: HttpHookMethod.get,
  respond: (req, match) async {
    final stream = await getDataStream();
    return HttpHookResponse.stream(stream);
  },
);
```

### Error Responses

```dart
HttpHookResponse(statusCode: 404, body: 'Not Found')
```

### Custom Responses

```dart
HttpHookResponse(
  statusCode: 201,
  headers: {'custom-header': 'value'},
  body: 'Custom response body',
  reasonPhrase: 'Created',
)
```

### Pass-Through Response

```dart
HttpHookResponse.passThrough()  // Allows real HTTP request to proceed
```

## 🕰 Advanced Features

### Simulating Delays

```dart
HttpHook.on(
  'http://api.example.com/slow',
  method: HttpHookMethod.get,
  respond: (req, match) async {
    await Future.delayed(Duration(seconds: 2));
    return HttpHookResponse.ok('Delayed response');
  },
);
```

### Simulating Network Errors

```dart
HttpHook.on(
  'http://api.example.com/error',
  method: HttpHookMethod.get,
  respond: (req, match) {
    throw SocketException('Network connection failed');
  },
);
```

### Dynamic Responses

```dart
HttpHook.on(
  'http://api.example.com/dynamic',
  method: HttpHookMethod.get,
  respond: (req, match) {
    final userAgent = req.headers['user-agent'];
    return HttpHookResponse.json({
      'timestamp': DateTime.now().toIso8601String(),
      'userAgent': userAgent,
      'url': req.url.toString(),
    });
  },
);
```

### Pass-Through for Real Requests

Sometimes you may want to conditionally mock responses or allow real HTTP requests to proceed. Use `HttpHookResponse.passThrough()` to let the request continue to the real server:

```dart
HttpHook.onRegex(
  defaultUrl: 'http://api.example.com',
  regex: RegExp(r'^/user/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final userId = match.regexMatch!.group(1);
    
    if (userId == 'real') {
      // Let this request go to the real server
      return HttpHookResponse.passThrough();
    } else if (userId == 'mock') {
      // Return mock data
      return HttpHookResponse.json({
        'id': userId,
        'name': 'Mocked User',
        'type': 'mock'
      });
    } else {
      // Default mock response
      return HttpHookResponse.json({
        'id': userId,
        'name': 'Default User',
        'type': 'default'
      });
    }
  },
);

// This will make a real HTTP request
final realResponse = await http.get(Uri.parse('http://api.example.com/user/real'));

// This will return mock data
final mockResponse = await http.get(Uri.parse('http://api.example.com/user/mock'));

// This will return default mock data  
final defaultResponse = await http.get(Uri.parse('http://api.example.com/user/123'));
```

## 🧪 Testing Best Practices

### Test Structure

```dart
void main() {
  group('API Tests', () {
    setUp(() => HttpHook.start());
    tearDown(() => HttpHook.destroy());

    test('GET /user/:id', () async {
      HttpHook.onTemplate(
        defaultUrl: 'http://api.example.com',
        template: '/user/:id',
        method: HttpHookMethod.get,
        respond: (req, match) {
          return HttpHookResponse.json({'id': match.params!['id']});
        },
      );

      final response = await http.get(
        Uri.parse('http://api.example.com/user/123')
      );
      expect(jsonDecode(response.body)['id'], '123');
    });
  });
}
```

### Using mockHttp for Simple Cases

```dart
test('simple API call', () async {
  mockHttp(
    'http://api.example.com/data',
    method: HttpHookMethod.get,
    reply: jsonEncode({'data': 'test'}),
  );
  
  // Test your code that makes the HTTP call
});
```

## ⚠️ Known Limitations

- **Request Body Access**: The `HttpHookRequest` object does not include request body data.

## 📖 API Reference

### HttpHookMethod

Enum for HTTP methods:

```dart
enum HttpHookMethod {
  get, post, put, delete, patch, head, options
}
```

### HttpHookRequest

Request object passed to handlers:

```dart
class HttpHookRequest {
  final Uri url;
  final HttpHookMethod method;
  final Map<String, String> headers;
}
```

### MatchResult

Match information for template and regex patterns:

```dart
class MatchResult {
  final Map<String, String>? params;     // Template parameters
  final RegExpMatch? regexMatch;         // Regex match groups
}
```

### HttpHookResponse

Response factory methods for creating mock responses:

```dart
// Success responses
HttpHookResponse.ok('Success!')                    // 200 OK
HttpHookResponse.json({'key': 'value'})            // 200 OK with JSON
HttpHookResponse.binary([0x48, 0x65, 0x6C, 0x6C]) // 200 OK with binary data
HttpHookResponse.stream(stream)                     // 200 OK with streaming data

// Error responses
HttpHookResponse.notFound('Resource not found')           // 404 Not Found
HttpHookResponse.internalServerError('Server error')      // 500 Internal Server Error
HttpHookResponse.badRequest('Invalid parameters')         // 400 Bad Request
HttpHookResponse.unauthorized('Invalid credentials')      // 401 Unauthorized
HttpHookResponse.forbidden('Access denied')              // 403 Forbidden

// Pass-through (let real request proceed)
HttpHookResponse.passThrough()
```

### Removing Hooks

```dart
// Remove exact URL hook
HttpHook.off('http://api.example.com/user/1');

// Remove template hook for specific host
HttpHook.offTemplate(
  defaultUrl: 'http://api.example.com',
  template: '/user/:id',
);

// Remove template hook for all hosts (wildcard)
HttpHook.offTemplate(
  template: '/user/:id',
);

// Remove regex hook for specific host
HttpHook.offRegex(
  defaultUrl: 'http://api.example.com',
  regex: RegExp(r'^/search/(.+)$'),
);

// Remove regex hook for all hosts (wildcard)
HttpHook.offRegex(
  regex: RegExp(r'^/api/v1/(.+)$'),
);

// Remove all hooks
HttpHook.destroy();
```

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dev_dependencies:
  http_hook: ^0.0.4
```

## 💡 Use Cases

- **Unit & Integration Testing**: Mock external APIs without running servers (HTTP & HTTPS)
- **Development & Debugging**: Test different API responses and error conditions
- **Network Simulation**: Simulate slow connections, timeouts, and failures
- **API Prototyping**: Create mock responses before backend implementation

## 🔗 Examples

Check out the `/example` directory for complete working examples demonstrating all features.

## 🧑‍💻 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 