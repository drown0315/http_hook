import 'package:http/http.dart' as http;
import 'package:http_hook/http_hook.dart';
import 'package:test/test.dart';

void main() {
  group('MockHttp', () {
    test('mock http', () async {
      /// Arrange.
      mockHttp('http://www.baidu.com', method: HttpHookMethod.get, reply: 'hi');

      /// Act.
      final resp = await http.get(Uri.parse('http://www.baidu.com'));

      /// Assert.
      expect(resp.statusCode, 200);
      expect(resp.body, 'hi');
    });

    test('test MockHttp tearDown', () async {
      /// Act.
      final resp = await http.get(Uri.parse('http://www.baidu.com'));

      /// Assert.
      expect(resp.statusCode, 200);
      expect(resp.body, isNot(equals('hi')));
    });
  });
}
