part of '../unused_function_rule.dart';

/// Collector for public top-level function declarations in non-entry-point
/// compilation units.
///
/// Files directly under `lib/` (i.e. `lib/<name>.dart`), files under
/// `bin/**`, files under `test/**`, and files declaring a top-level
/// `main` are entry points: public top-level functions inside them form
/// the package's public surface and MUST NOT be flagged. In every other
/// unit (typically `lib/src/**`), every public top-level
/// [FunctionDeclaration] is a candidate, and is flagged when no file in
/// the analyzed set references it.
///
/// The `main` entry point, `external` functions, and any function
/// annotated with `@pragma('vm:entry-point')` are excluded regardless of
/// where they sit. Override-awareness does not apply to top-level
/// functions.
class _PublicTopLevelCollector implements _UnusedFunctionCandidateCollector {
  const _PublicTopLevelCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    if (isEntryPointByPath(unit.path)) return;
    if (hasTopLevelMain(unit.unit)) return;
    for (final declaration in unit.unit.declarations) {
      if (declaration is! FunctionDeclaration) continue;
      if (!_isCandidate(declaration)) continue;
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: declaration.name,
        element: element,
        kindLabel: 'public top-level',
      );
    }
  }

  bool _isCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (name.startsWith('_')) return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }
}
