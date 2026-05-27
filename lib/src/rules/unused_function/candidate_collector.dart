part of '../unused_function_rule.dart';

/// Internal seam used by `UnusedFunctionRule` to discover per-unit
/// declarations that are candidates for the "declared but never
/// referenced" check.
///
/// Implementations are stateless and invoked once per
/// [ResolvedUnitResult]. They MUST NOT consult any shared state outside
/// the supplied unit; the rule supplies the global reference index at
/// the dispatch site, after every collector has been run on every unit.
///
/// Each yielded [_Candidate] carries the declaration's name [Token], the
/// declared [Element], and a human-readable kind label embedded into
/// the diagnostic message. Override-awareness is deferred to per-kind
/// collectors — they may decline to yield a candidate that participates
/// in an override relationship — so the candidate carrier intentionally
/// does not surface override metadata to the rule. The kinds shipped
/// today (top-level private functions, local functions) cannot
/// participate in override relationships, so this is a no-op for now.
abstract class _UnusedFunctionCandidateCollector {
  /// Yields the candidates discovered in [unit]. Implementations must
  /// not emit candidates whose declared element is `null`.
  Iterable<_Candidate> collect(ResolvedUnitResult unit);
}

class _Candidate {
  final Token nameToken;
  final Element element;
  final String kindLabel;

  const _Candidate({
    required this.nameToken,
    required this.element,
    required this.kindLabel,
  });
}

bool _hasVmEntryPointPragma(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    final identifier = annotation.name;
    final simpleName = identifier is SimpleIdentifier
        ? identifier.name
        : identifier is PrefixedIdentifier
        ? identifier.identifier.name
        : '';
    if (simpleName != 'pragma') continue;
    final arguments = annotation.arguments;
    if (arguments == null || arguments.arguments.isEmpty) continue;
    final first = arguments.arguments.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}
