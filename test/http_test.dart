import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_hook/http_hook.dart';
import 'package:test/test.dart';

String _defaultUrl = 'http://wwww.bing.com';

void main() {
  group('HttpHook start', () {
    test('destroy', () async {
      /// Arrange.
      HttpHook.start();
      HttpHook.on('$_defaultUrl/on_destroy', method: HttpHookMethod.get,
          respond: (_, __) {
        return HttpHookResponse.ok('hi');
      });

      /// Act.
      HttpHook.destroy();
      final resp = await http.get(Uri.parse('$_defaultUrl/on_destroy'));

      /// Assert.
      expect(resp.body, isNot(equals('hi')));
    });
  });

  group('HttpHook `on` method', () {
    setUp(() {
      HttpHook.start();
    });

    tearDown(() {
      HttpHook.destroy();
    });

    test('override get method', () async {
      /// Arrange.
      HttpHook.on(
        '$_defaultUrl/on/1',
        method: HttpHookMethod.get,
        respond: (req, match) =>
            HttpHookResponse.json({'id': 1, 'name': 'Alice'}),
      );

      /// Act.
      final response = await http.get(Uri.parse('$_defaultUrl/on/1'));
      final data = jsonDecode(response.body);

      /// Assert.
      expect(response.statusCode, 200);
      expect(data['name'], 'Alice');
      expect(data['id'], 1);
    });

    test('override a get method should not response post method', () async {
      /// Arrange.
      HttpHook.on('$_defaultUrl/on',
          method: HttpHookMethod.get,
          respond: (req, match) => HttpHookResponse.ok('hello'));

      /// Act.
      final response = await http.post(Uri.parse('$_defaultUrl/on'));

      /// Assert.
      expect(response.body, isNot(equals('hello')));
    });

    test('remove the override request, http request should not be intercepted',
        () async {
      /// Arrange.
      HttpHook.on(
        '$_defaultUrl/on/1',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('hi'),
      );
      HttpHook.off('$_defaultUrl/on/1');

      /// Act.
      final response = await http.get(Uri.parse('$_defaultUrl/on/1'));

      /// Assert.
      expect(response.statusCode, 404);
      expect(response.body, isNot(equals('hi')));
    });
  });

  group('HttpHook `onTemplate` method', () {
    setUp(() {
      HttpHook.start();
    });

    tearDown(() {
      HttpHook.destroy();
    });

    test('override a get method', () async {
      /// Arrange.
      HttpHook.onTemplate(
        _defaultUrl,
        template: '/on_template/user/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('hi'),
      );

      /// Act.
      final response =
          await http.get(Uri.parse('$_defaultUrl/on_template/user/1'));

      /// Assert.
      expect(response.statusCode, 200);
      expect(response.body, equals('hi'));
    });

    test('remove the override request, http request should not be intercepted',
        () async {
      /// Arrange.
      HttpHook.onTemplate(
        _defaultUrl,
        template: '/on_template/user/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('hi'),
      );

      /// Act.
      HttpHook.offTemplate(_defaultUrl, template: '/on_template/user/:id');
      final response =
          await http.get(Uri.parse('$_defaultUrl/on_template/user/1'));

      /// Assert.
      expect(response.statusCode, 404);
    });
  });

  group('HttpHook `onRegex` method', () {
    setUp(() {
      HttpHook.start();
    });

    tearDown(() {
      HttpHook.destroy();
    });

    test('override a get method', () async {
      /// Arrange.
      HttpHook.onRegex(_defaultUrl,
          regex: RegExp(r'^/search/(.+)$'),
          method: HttpHookMethod.get, respond: (req, match) {
        final keyword = match.regexMatch!.group(1);
        return HttpHookResponse.json({'keyword': keyword, 'results': []});
      });

      /// Act.
      final response = await http.get(Uri.parse('$_defaultUrl/search/flutter'));

      /// Assert.
      expect(response.statusCode, 200);
      final data = jsonDecode(response.body);
      expect(data['keyword'], 'flutter');
      expect(data['results'], []);
    });

    test('remove the override request, http request should not be intercepted',
        () async {
      /// Arrange.
      HttpHook.onRegex(_defaultUrl,
          regex: RegExp(r'/on_regex/user/(\d+)'),
          method: HttpHookMethod.get,
          respond: (req, match) => HttpHookResponse.ok('hi'));

      /// Act.
      HttpHook.offRegex(
        _defaultUrl,
        regex: RegExp(r'/on_regex/user/(\d+)'),
      );
      final response =
          await http.get(Uri.parse('$_defaultUrl/on_regex/user/1'));

      /// Assert.
      expect(response.statusCode, 404);
    });
  });
}
