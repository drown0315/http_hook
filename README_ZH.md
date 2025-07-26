# 📦 HttpHook

[English](README.md) | [中文](README_ZH.md)

一个轻量、灵活的 Dart HTTP 请求拦截与模拟库，适用于测试和调试。支持精准 URL 匹配、路径模板匹配、正则匹配和动态响应生成。


## ✨ 特性

- **多种匹配策略**: 精确 URL、路径模板（`/user/:id`）和正则表达式模式
- **动态响应生成**: 基于请求数据创建响应
- **错误和延迟模拟**: 模拟网络错误和延迟响应
- **简易测试集成**: 提供便捷的 `mockHttp()` 函数用于快速测试
- **生命周期管理**: 按需启动/停止拦截

## 🚀 快速开始

### 使用 `mockHttp()` 进行简单模拟

对于快速测试场景，使用便捷的 `mockHttp()` 函数：

```dart
import 'package:http_hook/http_hook.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('模拟 HTTP GET 请求', () async {
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

- 自动启动 `HttpHook`
- 自动注册 `tearDown()` 清理
- 简单的 JSON 响应处理

## 🧠 高级用法

对于需要多种匹配策略、动态响应和错误模拟的复杂场景，直接使用 `HttpHook` 类。

### 启动和停止

```dart
void main() {
  setUp(() => HttpHook.start());
  tearDown(() => HttpHook.destroy());
  
  // 你的测试代码
}
```

### 1. 精确 URL 匹配

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

### 2. 路径模板匹配

从 URL 路径中提取参数：

```dart
// 匹配特定URL
HttpHook.onTemplate(
  defaultUrl: 'http://api.example.com',  // 包含协议和主机的默认 URL
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

// 匹配任何主机的模板（通配符）
HttpHook.onTemplate(
  template: '/user/:id',
  method: HttpHookMethod.get,
  respond: (req, match) {
    final id = match.params!['id'];
    return HttpHookResponse.json({
      'id': id,
      'name': 'User $id',
      'host': req.url.host,  // 显示匹配到的主机
    });
  },
);
```

### 3. 正则表达式匹配

使用正则表达式进行复杂的 URL 模式匹配：

```dart
// 匹配特定主机
HttpHook.onRegex(
  defaultUrl: 'http://api.example.com',
  regex: RegExp(r'^/search/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final keyword = match.regexMatch!.group(1);
    return HttpHookResponse.json({
      'keyword': keyword,
      'results': ['结果 1', '结果 2'],
    });
  },
);

// 匹配任何主机的正则模式（通配符）
HttpHook.onRegex(
  regex: RegExp(r'^/api/v1/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final endpoint = match.regexMatch!.group(1);
    return HttpHookResponse.json({
      'endpoint': endpoint,
      'host': req.url.host,
      'message': '通用 API 拦截器！',
    });
  },
);
```

### 4. HTTP 方法

支持所有 HTTP 方法：

```dart
// POST 请求
HttpHook.on(
  'http://api.example.com/login',
  method: HttpHookMethod.post,
  respond: (req, match) => HttpHookResponse.json({
    'token': 'abc123',
    'success': true,
  }),
);

// PUT 请求
HttpHook.on(
  'http://api.example.com/user/1',
  method: HttpHookMethod.put,
  respond: (req, match) => HttpHookResponse.json({
    'message': '用户更新成功',
  }),
);

// DELETE 请求
HttpHook.on(
  'http://api.example.com/user/1',
  method: HttpHookMethod.delete,
  respond: (req, match) => HttpHookResponse.json({
    'message': '用户删除成功',
  }),
);
```

## 🔧 响应类型

### JSON 响应

```dart
HttpHookResponse.json({'key': 'value'})
```

### 纯文本响应

```dart
HttpHookResponse.ok('纯文本响应')
```

### 错误响应

```dart
HttpHookResponse.error(404, body: '未找到')
```

### 自定义响应

```dart
HttpHookResponse(
  statusCode: 201,
  headers: {'custom-header': 'value'},
  body: '自定义响应体',
  reasonPhrase: '已创建',
)
```

### 透传响应

```dart
HttpHookResponse.passThrough()  // 允许真实HTTP请求继续进行
```

## 🕰 高级特性

### 模拟延迟

```dart
HttpHook.on(
  'http://api.example.com/slow',
  method: HttpHookMethod.get,
  respond: (req, match) async {
    await Future.delayed(Duration(seconds: 2));
    return HttpHookResponse.ok('延迟响应');
  },
);
```

### 模拟网络错误

```dart
HttpHook.on(
  'http://api.example.com/error',
  method: HttpHookMethod.get,
  respond: (req, match) {
    throw SocketException('网络连接失败');
  },
);
```

### 动态响应

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

### 透传真实请求

有时您可能希望有条件地模拟响应或允许真实的HTTP请求继续进行。使用 `HttpHookResponse.passThrough()` 让请求继续到真实服务器：

```dart
HttpHook.onRegex(
  'http://api.example.com',
  regex: RegExp(r'^/user/(.+)$'),
  method: HttpHookMethod.get,
  respond: (req, match) {
    final userId = match.regexMatch!.group(1);
    
    if (userId == 'real') {
      // 让这个请求继续到真实服务器
      return HttpHookResponse.passThrough();
    } else if (userId == 'mock') {
      // 返回模拟数据
      return HttpHookResponse.json({
        'id': userId,
        'name': '模拟用户',
        'type': 'mock'
      });
    } else {
      // 默认模拟响应
      return HttpHookResponse.json({
        'id': userId,
        'name': '默认用户',
        'type': 'default'
      });
    }
  },
);

// 这将进行真实的HTTP请求
final realResponse = await http.get(Uri.parse('http://api.example.com/user/real'));

// 这将返回模拟数据
final mockResponse = await http.get(Uri.parse('http://api.example.com/user/mock'));

// 这将返回默认模拟数据
final defaultResponse = await http.get(Uri.parse('http://api.example.com/user/123'));
```

## 🧪 测试最佳实践

### 测试结构

```dart
void main() {
  group('API 测试', () {
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

### 在简单场景中使用 mockHttp

```dart
test('简单 API 调用', () async {
  mockHttp(
    'http://api.example.com/data',
    method: HttpHookMethod.get,
    reply: jsonEncode({'data': 'test'}),
  );
  
  // 测试你的 HTTP 调用代码
});
```

## ⚠️ 已知限制

- **请求体访问限制**: `HttpHookRequest` 对象不包含请求体数据。

## 📖 API 参考

### HttpHookMethod

HTTP 方法枚举：

```dart
enum HttpHookMethod {
  get, post, put, delete, patch, head, options
}
```

### HttpHookRequest

传递给处理器的请求对象：

```dart
class HttpHookRequest {
  final Uri url;
  final HttpHookMethod method;
  final Map<String, String> headers;
}
```

### MatchResult

模板和正则模式的匹配信息：

```dart
class MatchResult {
  final Map<String, String>? params;     // 模板参数
  final RegExpMatch? regexMatch;         // 正则匹配组
}
```

### 移除 Hook

```dart
// 移除精确 URL hook
HttpHook.off('http://api.example.com/user/1');

// 移除特定主机的模板 hook
HttpHook.offTemplate(
  defaultUrl: 'http://api.example.com',
  template: '/user/:id',
);

// 移除所有主机的模板 hook（通配符）
HttpHook.offTemplate(
  template: '/user/:id',
);

// 移除特定主机的正则 hook
HttpHook.offRegex(
  defaultUrl: 'http://api.example.com',
  regex: RegExp(r'^/search/(.+)$'),
);

// 移除所有主机的正则 hook（通配符）
HttpHook.offRegex(
  regex: RegExp(r'^/api/v1/(.+)$'),
);

// 移除所有 hook
HttpHook.destroy();
```

## 📦 安装

添加到你的 `pubspec.yaml`：

```yaml
dev_dependencies:
  http_hook: ^0.0.3
```

## 💡 使用场景

- **单元测试和集成测试**: 无需运行服务器即可模拟外部 API（HTTP 和 HTTPS）
- **开发和调试**: 测试不同的 API 响应和错误条件
- **网络模拟**: 模拟慢连接、超时和失败
- **API 原型设计**: 在后端实现之前创建模拟响应

## 🔗 示例

查看 `/example` 目录获取展示所有功能的完整工作示例。

## 🧑‍💻 贡献

欢迎贡献！请随时提交 issue 和 pull request。

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。 