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

    test('passThrough should allow real HTTP request', () async {
      /// Arrange.
      HttpHook.on(
        'http://httpbin.org/status/200',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.passThrough(),
      );

      /// Act.
      final response =
          await http.get(Uri.parse('http://httpbin.org/status/200'));

      /// Assert.
      expect(response.statusCode, 200); // Real response from qq.com
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

    test('template with conditional passThrough', () async {
      /// Arrange.
      HttpHook.onTemplate(
        'http://httpbin.org',
        template: '/get/:action',
        method: HttpHookMethod.get,
        respond: (req, match) {
          final action = match.params!['action'];
          if (action == 'mock') {
            return HttpHookResponse.json({'action': action, 'type': 'mock'});
          } else {
            return HttpHookResponse.passThrough();
          }
        },
      );

      /// Act & Assert - Mock response
      final mockResponse =
          await http.get(Uri.parse('http://httpbin.org/get/mock'));
      final mockData = jsonDecode(mockResponse.body);
      expect(mockData['type'], 'mock');
      expect(mockData['action'], 'mock');

      /// Act & Assert - Real response (will likely 404 but should not be mocked)
      final realResponse =
          await http.get(Uri.parse('http://httpbin.org/get/real'));
      expect(realResponse.statusCode, isNot(200)); // Not a mock response
    });

    test('onTemplate with null defaultUrl should match any host', () async {
      /// Arrange.
      HttpHook.onTemplate(
        null, // Wildcard - matches any host
        template: '/wildcard/user/:id',
        method: HttpHookMethod.get,
        respond: (req, match) {
          final id = match.params!['id'];
          return HttpHookResponse.json(
              {'id': id, 'host': req.url.host, 'type': 'wildcard'});
        },
      );

      /// Act & Assert - Test with different hosts
      final hosts = [
        'http://api.example.com/wildcard/user/123',
        'http://test.domain.org/wildcard/user/456',
        'http://another.test.com/wildcard/user/789'
      ];

      for (final url in hosts) {
        final response = await http.get(Uri.parse(url));
        final data = jsonDecode(response.body);
        final expectedHost = Uri.parse(url).host;

        expect(response.statusCode, 200);
        expect(data['type'], 'wildcard');
        expect(data['host'], expectedHost);
      }
    });

    test('`wildcard` and `host-specific` rules should work independently',
        () async {
      /// Arrange.
      // Add wildcard rule for one template
      HttpHook.onTemplate(
        null,
        template: '/wildcard-only/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.json({'type': 'wildcard'}),
      );

      // Add host-specific rule for different template
      HttpHook.onTemplate(
        'http://specific.example.com',
        template: '/specific-only/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.json({'type': 'specific'}),
      );

      /// Act & Assert - Wildcard rule should work for any host
      final wildcardResponse =
          await http.get(Uri.parse('http://any.example.com/wildcard-only/123'));
      final wildcardData = jsonDecode(wildcardResponse.body);
      expect(wildcardData['type'], 'wildcard');

      /// Act & Assert - Host-specific rule should work for specific host
      final specificResponse = await http
          .get(Uri.parse('http://specific.example.com/specific-only/456'));
      final specificData = jsonDecode(specificResponse.body);
      expect(specificData['type'], 'specific');

      /// Act & Assert - Non-matching host for specific rule should fail (network error expected)
      try {
        final nonMatchResponse = await http
            .get(Uri.parse('http://other.example.com/specific-only/789'));
        // If we get here, it means the request went through without interception
        expect(nonMatchResponse.statusCode, isNot(200));
      } catch (e) {
        // Network error is expected since the rule doesn't match and tries real request
        expect(e, isA<Exception>());
      }
    });

    test('offTemplate with null defaultUrl should remove rules correctly',
        () async {
      /// Arrange.
      HttpHook.onTemplate(
        null,
        template: '/remove/wildcard/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('wildcard'),
      );

      // Verify rule works
      final response1 =
          await http.get(Uri.parse('http://test.com/remove/wildcard/123'));
      expect(response1.body, 'wildcard');

      /// Act.
      HttpHook.offTemplate(null, template: '/remove/wildcard/:id');

      /// Assert.
      final response2 =
          await http.get(Uri.parse('http://test.com/remove/wildcard/123'));
      expect(response2.statusCode, isNot(200)); // Should not be intercepted
    });

    test('mixed wildcard and host-specific rules removal', () async {
      /// Arrange.
      // Add wildcard rule for one template
      HttpHook.onTemplate(
        null,
        template: '/wildcard-remove/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('wildcard'),
      );

      // Add host-specific rule for same template
      HttpHook.onTemplate(
        'http://specific.com',
        template: '/specific-remove/:id',
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('specific'),
      );

      // Verify both rules work initially
      final wildcardInitial =
          await http.get(Uri.parse('http://any.com/wildcard-remove/123'));
      expect(wildcardInitial.body, 'wildcard');

      final specificInitial =
          await http.get(Uri.parse('http://specific.com/specific-remove/123'));
      expect(specificInitial.body, 'specific');

      /// Act - Remove only wildcard rule
      HttpHook.offTemplate(null, template: '/wildcard-remove/:id');

      /// Assert - Wildcard should be removed, specific should remain
      try {
        final wildcardAfter =
            await http.get(Uri.parse('http://any.com/wildcard-remove/123'));
        // If we get a response, it should not be our mock response
        expect(wildcardAfter.body, isNot('wildcard'));
        expect(wildcardAfter.statusCode, isNot(200));
      } catch (e) {
        // Network error is expected since the rule is removed and tries real request
        expect(e, isA<Exception>());
      }

      final specificAfter =
          await http.get(Uri.parse('http://specific.com/specific-remove/123'));
      expect(specificAfter.body, 'specific'); // Specific still works
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

    test('conditional passThrough with regex', () async {
      /// Arrange.
      HttpHook.onRegex(
        'http://httpbin.org',
        regex: RegExp(r'^/status/(.+)$'),
        method: HttpHookMethod.get,
        respond: (req, match) {
          final status = match.regexMatch!.group(1);
          if (status == 'mock') {
            return HttpHookResponse.json({'type': 'mock', 'status': status});
          } else {
            return HttpHookResponse.passThrough(); // Let real request through
          }
        },
      );

      /// Act & Assert - Mock response
      final mockResponse =
          await http.get(Uri.parse('http://httpbin.org/status/mock'));
      final mockData = jsonDecode(mockResponse.body);
      expect(mockData['type'], 'mock');
      expect(mockData['status'], 'mock');

      /// Act & Assert - Real response
      final realResponse =
          await http.get(Uri.parse('http://httpbin.org/status/200'));
      expect(realResponse.statusCode, 200); // Real httpbin.org response
    });

    test('onRegex with null defaultUrl should match any host', () async {
      /// Arrange.
      HttpHook.onRegex(
        null, // Wildcard - matches any host
        regex: RegExp(r'^/api/v1/(.+)$'),
        method: HttpHookMethod.get,
        respond: (req, match) {
          final endpoint = match.regexMatch!.group(1);
          return HttpHookResponse.json({
            'endpoint': endpoint,
            'host': req.url.host,
            'type': 'wildcard_regex'
          });
        },
      );

      /// Act & Assert - Test with different hosts
      final urls = [
        'http://service1.com/api/v1/users',
        'http://backend.app.io/api/v1/posts',
        'http://api.test.local/api/v1/auth'
      ];

      for (final url in urls) {
        final response = await http.get(Uri.parse(url));
        final data = jsonDecode(response.body);
        final expectedHost = Uri.parse(url).host;

        expect(response.statusCode, 200);
        expect(data['type'], 'wildcard_regex');
        expect(data['host'], expectedHost);
      }
    });

    test('offRegex with null defaultUrl should remove wildcard rules',
        () async {
      /// Arrange.
      final regex = RegExp(r'^/remove/regex/(.+)$');
      HttpHook.onRegex(
        null,
        regex: regex,
        method: HttpHookMethod.get,
        respond: (req, match) => HttpHookResponse.ok('wildcard_regex'),
      );

      // Verify rule works
      final response1 =
          await http.get(Uri.parse('http://test.com/remove/regex/test'));
      expect(response1.body, 'wildcard_regex');

      /// Act.
      HttpHook.offRegex(null, regex: regex);

      /// Assert.
      final response2 =
          await http.get(Uri.parse('http://test.com/remove/regex/test'));
      expect(response2.statusCode, isNot(200)); // Should not be intercepted
      expect(
          response2.body, isNot('wildcard_regex')); // Should not be intercepted
    });
  });
}
