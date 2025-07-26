import 'dart:io';
import 'dart:convert';
import 'dart:async';

import 'request.dart';
import 'response.dart';
import 'http_method.dart';
import 'match_result.dart';

/// Signature for HTTP hook handler functions.
///
/// Takes the intercepted [HttpHookRequest] and the [MatchResult]
/// of the URL matching, and returns a [HttpHookResponse] or a Future thereof.
typedef HttpHookHandler = FutureOr<HttpHookResponse> Function(
  HttpHookRequest request,
  MatchResult match,
);

/// Internal representation of a single HTTP hook rule.
class _HttpHookRule {
  const _HttpHookRule({
    required this.pattern,
    required this.method,
    required this.handler,
    required this.type,
  });

  /// The pattern used for matching request URLs.
  ///
  /// This may be a full URL, a path template, or a regex pattern,
  /// depending on [type].
  final String pattern;

  /// Optional HTTP method to restrict matching (e.g., HttpHookMethod.get, HttpHookMethod.post).
  ///
  /// If null, matches any method.
  final HttpHookMethod method;

  /// The handler function invoked when a request matches this rule.
  final HttpHookHandler handler;

  /// The type of matching this rule uses.
  final HttpHookRuleType type;
}

/// Enum describing the types of URL matching for hook rules.
enum HttpHookRuleType {
  /// Exact string match on URL.
  exact,

  /// Template match with named parameters, e.g. `/users/:id`.
  template,

  /// Regular expression match on URL path.
  regex,
}

/// Main class for managing HTTP hook rules and intercepting requests.
class HttpHook {
  HttpHook._();

  static final Map<String, _HttpHookRule> _rules = {};
  static _HttpOverridesImpl? _httpOverrides;
  static bool _isStarted = false;

  /// Starts intercepting all HTTP requests by installing
  /// a global [HttpOverrides] with hook support.
  static void start() {
    if (_isStarted) return;

    _httpOverrides = _HttpOverridesImpl();
    HttpOverrides.global = _httpOverrides;
    _isStarted = true;
  }

  /// Stops intercepting HTTP requests and clears all registered hook rules.
  static void destroy() {
    if (!_isStarted) return;

    _rules.clear();
    HttpOverrides.global = null;
    _httpOverrides = null;
    _isStarted = false;
  }

  /// Returns whether the HTTP hook is currently active.
  static bool get isStarted => _isStarted;

  /// Registers a hook rule that matches the exact URL.
  ///
  /// If [method] is provided, only requests with the matching HTTP method
  /// will be intercepted.
  ///
  /// The [respond] callback is invoked with the intercepted request
  /// and should return a [HttpHookResponse].
  static void on(
    String url, {
    HttpHookMethod method = HttpHookMethod.get,
    required HttpHookHandler respond,
  }) {
    _rules[url] = _HttpHookRule(
      pattern: url,
      method: method,
      handler: respond,
      type: HttpHookRuleType.exact,
    );
  }

  /// Registers a hook rule using a path template with named parameters.
  ///
  /// [template] is the path template, e.g. `/users/:id`.
  /// [defaultUrl] must be specified to match requests to a particular host.
  ///
  /// [method] optionally restricts by HTTP method.
  ///
  /// [respond] handles matching requests.）
  static void onTemplate(
    String defaultUrl, {
    required String template,
    required HttpHookMethod method,
    required HttpHookHandler respond,
  }) {
    final uri = Uri.parse(defaultUrl);
    final host = uri.host;
    _rules['$host$template'] = _HttpHookRule(
      pattern: '$host$template',
      method: method,
      handler: respond,
      type: HttpHookRuleType.template,
    );
  }

  /// Registers a hook rule with a regular expression to match URL paths.
  ///
  /// [regex] defines the pattern to match against the request path.
  /// [defaultUrl] must be specified to restrict matches to a specific host.
  ///
  /// [method] optionally restricts by HTTP method.
  ///
  /// [respond] handles matching requests.
  static void onRegex(
    String defaultUrl, {
    required RegExp regex,
    required HttpHookMethod method,
    required HttpHookHandler respond,
  }) {
    final uri = Uri.parse(defaultUrl);
    final host = uri.host;
    _rules['$host|||${regex.pattern}'] = _HttpHookRule(
      pattern: '$host|||${regex.pattern}',
      method: method,
      handler: respond,
      type: HttpHookRuleType.regex,
    );
  }

  /// Removes the exact match hook rule for the given [url].
  static void off(String url) {
    _rules.remove(url);
  }

  /// Removes path template hook rules for the given [template] and [defaultUrl].
  static void offTemplate(
    String defaultUrl, {
    required String template,
  }) {
    final uri = Uri.parse(defaultUrl);
    final host = uri.host;
    _rules.removeWhere((key, value) => key.startsWith('$host$template'));
  }

  /// Removes regex hook rules matching the given [regex] pattern and [defaultUrl].
  static void offRegex(
    String defaultUrl, {
    required RegExp regex,
  }) {
    final uri = Uri.parse(defaultUrl);
    final host = uri.host;
    _rules.removeWhere(
        (key, value) => key.startsWith('$host|||${regex.pattern}'));
  }

  // Internal method to match the incoming request against all registered hook rules.
  //
  // Returns a [HttpHookResponse] if a matching handler responds,
  // or null if no match was found.
  static Future<HttpHookResponse?> _matchRequest(
    HttpHookRequest request,
  ) async {
    for (final rule in _rules.values) {
      if (rule.method != request.method) {
        continue;
      }

      final match = _matchRule(rule, request.url);
      if (match != null) {
        try {
          final response = await rule.handler(request, match);
          // If response is passThrough, continue to next rule or return null
          // to allow real HTTP request
          if (response.isPassThrough) {
            continue;
          }
          return response;
        } catch (e) {
          rethrow;
        }
      }
    }

    return null;
  }

  /// Matches the given [rule] against the request [url].
  ///
  /// Returns a [MatchResult] if matched, or null otherwise.
  static MatchResult? _matchRule(_HttpHookRule rule, Uri url) {
    switch (rule.type) {
      case HttpHookRuleType.exact:
        return _matchExact(rule.pattern, url);
      case HttpHookRuleType.template:
        return _matchTemplate(rule.pattern, url);
      case HttpHookRuleType.regex:
        return _matchRegex(rule.pattern, url);
    }
  }

  /// Performs exact match on the full URL.
  ///
  /// Compares scheme, host, port, and path.
  static MatchResult? _matchExact(String pattern, Uri url) {
    final patternUri = Uri.parse(pattern);

    if (patternUri.scheme.isNotEmpty && patternUri.scheme != url.scheme) {
      return null;
    }
    if (patternUri.host.isNotEmpty && patternUri.host != url.host) {
      return null;
    }
    if (patternUri.hasPort && patternUri.port != url.port) {
      return null;
    }
    if (patternUri.path != url.path) {
      return null;
    }

    return MatchResult.empty;
  }

  /// Matches the request URL against a path template with named parameters.
  ///
  /// The [pattern] is in the format `host/template` (e.g., `example.com/user/:id`).
  /// Returns extracted parameters if matched.
  static MatchResult? _matchTemplate(String pattern, Uri url) {
    final hostEndIndex = pattern.indexOf('/');
    if (hostEndIndex == -1) {
      return null; // Invalid pattern
    }

    final expectedHost = pattern.substring(0, hostEndIndex);
    final template = pattern.substring(hostEndIndex);

    if (url.host != expectedHost) {
      return null;
    }

    final templateParts = template.split('/');
    final urlParts = url.path.split('/');

    if (templateParts.length != urlParts.length) {
      return null;
    }

    final params = <String, String>{};

    for (int i = 0; i < templateParts.length; i++) {
      final templatePart = templateParts[i];
      final urlPart = urlParts[i];

      if (templatePart.startsWith(':')) {
        final paramName = templatePart.substring(1);
        params[paramName] = urlPart;
      } else if (templatePart != urlPart) {
        return null;
      }
    }

    return MatchResult(params: params);
  }

  /// Matches the request URL path against a regular expression pattern.
  ///
  /// The [pattern] string is formatted as `host|||regexPattern`.
  /// Returns a [MatchResult] with regex groups if matched.
  static MatchResult? _matchRegex(String pattern, Uri url) {
    // separate host and regex: "example.com|||^/search/(.+)$"
    final separatorIndex = pattern.indexOf('|||');
    if (separatorIndex == -1) {
      return null; // Invalid pattern
    }

    final expectedHost = pattern.substring(0, separatorIndex);
    final regexPattern = pattern.substring(separatorIndex + 3);
    if (url.host != expectedHost) {
      return null;
    }

    final regex = RegExp(regexPattern);
    final match = regex.firstMatch(url.path);

    if (match != null) {
      return MatchResult(regexMatch: match);
    }

    return null;
  }
}

class _HttpOverridesImpl extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return _HttpClientWrapper(client);
  }
}

/// Wrapper around the real [HttpClient] to intercept requests and
/// delegate them to hook handlers when applicable.
class _HttpClientWrapper implements HttpClient {
  _HttpClientWrapper(this._inner);

  final HttpClient _inner;

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async {
    final request = await _inner.open(method, host, port, path);
    return _HttpClientRequestWrapper(request);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return _HttpClientRequestWrapper(request);
  }

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )? f,
  ) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) =>
      _inner.badCertificateCallback = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )? f,
  ) =>
      _inner.connectionFactory = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;
}

/// HttpClientRequest 包装类
class _HttpClientRequestWrapper implements HttpClientRequest {
  _HttpClientRequestWrapper(this._inner);

  final HttpClientRequest _inner;

  @override
  Future<HttpClientResponse> close() async {
    // Convert the real request into an HttpHookRequest wrapper
    final request = await HttpHookRequest.fromHttpClientRequest(_inner);

    // Check if any hook matches this request
    final hookResponse = await HttpHook._matchRequest(request);

    if (hookResponse != null) {
      // Return a mocked response if matched
      return _MockHttpClientResponse(hookResponse);
    }

    return _inner.close();
  }

// Delegate all other members to _inner HttpClient instance
  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  Future<void> flush() => _inner.flush();

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);

  @override
  Future<HttpClientResponse> get done => _inner.done;

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;
}

/// Mock HttpClientResponse
class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _MockHttpClientResponse(this._response) {
    // set response headers.
    _response.headers.forEach((key, value) {
      headers.set(key, value);
    });

    final data = _response.body.isNotEmpty
        ? [utf8.encode(_response.body)]
        : <List<int>>[];
    _stream = Stream.fromIterable(data);
  }

  final HttpHookResponse _response;
  final HttpHeaders headers = _HttpHeadersImpl();
  late final Stream<List<int>> _stream;

  @override
  int get statusCode => _response.statusCode;

  @override
  String get reasonPhrase =>
      _response.reasonPhrase ?? _getDefaultReasonPhrase(_response.statusCode);

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  Future<bool> any(bool Function(List<int>) test) => _stream.any(test);

  @override
  Stream<List<int>> asBroadcastStream({
    void Function(StreamSubscription<List<int>>)? onListen,
    void Function(StreamSubscription<List<int>>)? onCancel,
  }) =>
      _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);

  @override
  Stream<R> asyncExpand<R>(Stream<R>? Function(List<int>) convert) =>
      _stream.asyncExpand(convert);

  @override
  Stream<R> asyncMap<R>(FutureOr<R> Function(List<int>) convert) =>
      _stream.asyncMap(convert);

  @override
  Stream<R> cast<R>() => _stream.cast<R>();

  @override
  Future<bool> contains(Object? needle) => _stream.contains(needle);

  @override
  Stream<List<int>> distinct([bool Function(List<int>, List<int>)? equals]) =>
      _stream.distinct(equals);

  @override
  Future<E> drain<E>([E? futureValue]) => _stream.drain(futureValue);

  @override
  Future<List<int>> elementAt(int index) => _stream.elementAt(index);

  @override
  Future<bool> every(bool Function(List<int>) test) => _stream.every(test);

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int>) convert) =>
      _stream.expand(convert);

  @override
  Future<List<int>> get first => _stream.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int>) test,
          {List<int> Function()? orElse}) =>
      _stream.firstWhere(test, orElse: orElse);

  @override
  Future<S> fold<S>(S initialValue, S Function(S, List<int>) combine) =>
      _stream.fold(initialValue, combine);

  @override
  Future<void> forEach(void Function(List<int>) action) =>
      _stream.forEach(action);

  @override
  Stream<List<int>> handleError(Function onError,
          {bool Function(dynamic)? test}) =>
      _stream.handleError(onError, test: test);

  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _stream.isEmpty;

  @override
  Future<String> join([String separator = '']) => _stream.join(separator);

  @override
  Future<List<int>> get last => _stream.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int>) test,
          {List<int> Function()? orElse}) =>
      _stream.lastWhere(test, orElse: orElse);

  @override
  Future<int> get length => _stream.length;

  @override
  Stream<S> map<S>(S Function(List<int>) convert) => _stream.map(convert);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) =>
      _stream.pipe(streamConsumer);

  @override
  Future<List<int>> reduce(List<int> Function(List<int>, List<int>) combine) =>
      _stream.reduce(combine);

  @override
  Future<List<int>> get single => _stream.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int>) test,
          {List<int> Function()? orElse}) =>
      _stream.singleWhere(test, orElse: orElse);

  @override
  Stream<List<int>> skip(int count) => _stream.skip(count);

  @override
  Stream<List<int>> skipWhile(bool Function(List<int>) test) =>
      _stream.skipWhile(test);

  @override
  Stream<List<int>> take(int count) => _stream.take(count);

  @override
  Stream<List<int>> takeWhile(bool Function(List<int>) test) =>
      _stream.takeWhile(test);

  @override
  Stream<List<int>> timeout(Duration timeLimit,
          {void Function(EventSink<List<int>>)? onTimeout}) =>
      _stream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<List<int>>> toList() => _stream.toList();

  @override
  Future<Set<List<int>>> toSet() => _stream.toSet();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      _stream.transform(streamTransformer);

  @override
  Stream<List<int>> where(bool Function(List<int>) test) => _stream.where(test);

  String _getDefaultReasonPhrase(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Internal Server Error';
      default:
        return 'Unknown';
    }
  }

  // todo
  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => _response.body.length;

  @override
  List<Cookie> get cookies => [];

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    throw UnsupportedError('Redirect not supported in mock response');
  }

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('DetachSocket not supported in mock response');
  }

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
}

class _HttpHeadersImpl implements HttpHeaders {
  final Map<String, List<String>> _headers = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = preserveHeaderCase ? name : name.toLowerCase();
    _headers.putIfAbsent(key, () => []).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    final key = preserveHeaderCase ? name : name.toLowerCase();
    _headers[key] = [value.toString()];
  }

  @override
  String? value(String name) {
    final values = _headers[name.toLowerCase()];
    return values?.isNotEmpty == true ? values!.first : null;
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  void remove(String name, Object value) {
    _headers[name.toLowerCase()]?.remove(value.toString());
  }

  @override
  void removeAll(String name) {
    _headers.remove(name.toLowerCase());
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  void clear() => _headers.clear();

  @override
  bool get chunkedTransferEncoding => false;

  @override
  set chunkedTransferEncoding(bool value) {}

  @override
  int get contentLength => -1;

  @override
  set contentLength(int value) {}

  @override
  ContentType? get contentType => null;

  @override
  set contentType(ContentType? value) {}

  @override
  DateTime? get date => null;

  @override
  set date(DateTime? value) {}

  @override
  DateTime? get expires => null;

  @override
  set expires(DateTime? value) {}

  @override
  String? get host => null;

  @override
  set host(String? value) {}

  @override
  DateTime? get ifModifiedSince => null;

  @override
  set ifModifiedSince(DateTime? value) {}

  @override
  bool get persistentConnection => false;

  @override
  set persistentConnection(bool value) {}

  @override
  int? get port => null;

  @override
  set port(int? value) {}

  @override
  void noFolding(String name) {}
}
