/// HTTP Method
enum HttpHookMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE'),
  patch('PATCH'),
  head('HEAD'),
  options('OPTIONS');

  const HttpHookMethod(this.value);

  final String value;

  /// Create HttpHookMethod from String object.
  ///
  /// Example:
  /// ```dart
  /// HttpHookMethod.fromString('GET');  // result: HttpHookMethod.get
  /// ```
  static HttpHookMethod fromString(String method) {
    for (final m in HttpHookMethod.values) {
      if (m.value == method.toUpperCase()) {
        return m;
      }
    }
    throw ArgumentError('Unknown HTTP method: $method');
  }
}
