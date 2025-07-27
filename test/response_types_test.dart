import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http_hook/http_hook.dart';
import 'package:test/test.dart';

void main() {
  group('HttpHookResponse Body Types', () {
    setUp(() => HttpHook.start());
    tearDown(() => HttpHook.destroy());

    test('String body', () async {
      /// Arrange.
      HttpHook.on(
        'http://example.com/string',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('Hello World'),
      );

      /// Act.
      final response = await http.get(Uri.parse('http://example.com/string'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.body, 'Hello World');
    });

    test('Binary body (List<int>)', () async {
      /// Arrange.
      final pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      HttpHook.on(
        'http://example.com/image',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.binary(
          pngHeader,
          contentType: 'image/png',
        ),
      );

      /// Act.
      final response = await http.get(Uri.parse('http://example.com/image'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      expect(response.bodyBytes, pngHeader);
    });

    test('Stream body', () async {
      /// Arrange.
      final stream = Stream.fromIterable([
        utf8.encode('Hello'),
        utf8.encode(' '),
        utf8.encode('World'),
      ]);
      HttpHook.on(
        'http://example.com/stream',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.stream(
          stream,
          contentType: 'text/plain',
        ),
      );

      /// Act.
      final response = await http.get(Uri.parse('http://example.com/stream'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'text/plain');
      expect(response.body, 'Hello World');
    });

    test('Async handler with Stream response', () async {
      /// Arrange.
      HttpHook.on(
        'http://example.com/async-handler',
        method: HttpHookMethod.get,
        respond: (req, match) async {
          return HttpHookResponse.stream(
            Stream.fromIterable([
              utf8.encode('Async'),
              utf8.encode(' '),
              utf8.encode('Handler'),
            ]),
            contentType: 'text/plain',
          );
        },
      );

      /// Act.
      final response =
          await http.get(Uri.parse('http://example.com/async-handler'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.body, 'Async Handler');
    });

    test('JSON response with binary data', () async {
      /// Arrange.
      final jsonData = {
        'message': 'Hello',
        'bytes': [1, 2, 3, 4]
      };
      HttpHook.on(
        'http://example.com/json-binary',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.json(jsonData),
      );

      /// Act.
      final response =
          await http.get(Uri.parse('http://example.com/json-binary'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(
          response.headers['content-type'], 'application/json; charset=utf-8');
      final data = jsonDecode(response.body);
      expect(data['message'], 'Hello');
      expect(data['bytes'], [1, 2, 3, 4]);
    });

    test('Error response with binary body', () async {
      /// Arrange.
      final errorBytes = utf8.encode('Binary Error Message');
      HttpHook.on(
        'http://example.com/error-binary',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.internalServerError(
          String.fromCharCodes(errorBytes),
        ),
      );

      /// Act.
      final response =
          await http.get(Uri.parse('http://example.com/error-binary'));

      /// Assert.
      expect(response.statusCode, 500);
      expect(response.body, 'Binary Error Message');
    });

    test('Empty body handling', () async {
      /// Arrange.
      HttpHook.on(
        'http://example.com/empty',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok(''),
      );

      /// Act.
      final response = await http.get(Uri.parse('http://example.com/empty'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.body, '');
    });

    test('Large binary data', () async {
      /// Arrange.
      final largeData = List.generate(10000, (i) => i % 256);
      HttpHook.on(
        'http://example.com/large-binary',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.binary(
          largeData,
          contentType: 'application/octet-stream',
        ),
      );

      /// Act.
      final response =
          await http.get(Uri.parse('http://example.com/large-binary'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.bodyBytes.length, 10000);
      expect(response.bodyBytes.first, 0);
      expect(response.bodyBytes.last, 15); // 9999 % 256 = 15
    });
  });
}
