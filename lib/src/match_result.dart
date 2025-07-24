/// Represents the result of a URL match.
///
/// Returned when an incoming HTTP request URL matches a route pattern.
/// It supports both path parameter extraction (e.g. `/users/:id`)
/// and raw regular expression matching.
class MatchResult {
  const MatchResult({
    this.params,
    this.regexMatch,
  });

  /// Captured path parameters, if the pattern includes placeholders.
  ///
  /// For example, given the pattern `/users/:id` and input `/users/42`,
  /// this would contain `{ "id": "42" }`.
  final Map<String, String>? params;

  /// The raw [RegExpMatch] result if the route was matched via regular expression.
  ///
  /// This allows access to `.group(n)` for advanced regex-based matching.
  final RegExpMatch? regexMatch;

  /// A shared empty result instance representing no match.
  static const empty = MatchResult();

  @override
  String toString() {
    return 'MatchResult(params: $params, regexMatch: $regexMatch)';
  }
}
