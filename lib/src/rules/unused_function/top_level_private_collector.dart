part of '../unused_function_rule.dart';

/// Collector for top-level private function declarations.
///
/// A declaration is a candidate when its name begins with `_`, it is not
/// the library entry point `main`, it is not `external`, and it is not
/// annotated with `@pragma('vm:entry-point')`. Override-awareness is not
/// applicable to top-level functions, so the slot is left `null`.
class _TopLevelPrivateCollector implements _UnusedFunctionCandidateCollector {
  const _TopLevelPrivateCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is! FunctionDeclaration) continue;
      if (!_isCandidate(declaration)) continue;
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: declaration.name,
        element: element,
        kindLabel: 'top-level',
      );
    }
  }

  bool _isCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (!name.startsWith('_')) return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }
}
