part of '../unused_function_rule.dart';

/// Collector for top-level function declarations.
///
/// Two kinds of declarations are emitted as candidates:
///
/// * **Private declarations** (identifier begins with `_`) — only when the
///   enclosing library has no `part` files, because otherwise a sibling
///   part could legitimately reference the function and the rule would
///   have to be cross-library aware to know that.
/// * **Public declarations** — only when the unit lives under `lib/src/`
///   and the enclosing library has no `part` files. Files directly under
///   `lib/`, under `bin/`, under `test/`, or declaring a top-level
///   `main` are treated as the package's public surface and skipped: a
///   public name in those locations is reachable from outside the
///   analyzed set, so "no references found here" is not strong enough
///   evidence to flag it.
///
/// A declaration is exempt when its name is `main` (the library entry
/// point), when it is declared `external`, or when it carries
/// `@pragma('vm:entry-point')`.
///
/// The diagnostic anchor is the declaration's name [Token].
class _TopLevelFunctionCollector implements _UnusedFunctionCandidateCollector {
  const _TopLevelFunctionCollector();

  @override
  Iterable<_Candidate> collect(
    ResolvedUnitResult unit,
    _CollectorContext context,
  ) sync* {
    if (unit.libraryElement.fragments.length > 1) return;
    final fileDeclaresMain = _unitDeclaresMain(unit.unit);
    for (final declaration in unit.unit.declarations) {
      if (declaration is! FunctionDeclaration) continue;
      if (declaration.isGetter || declaration.isSetter) continue;
      if (!_isTopLevelCandidate(
        declaration,
        unit.path,
        fileDeclaresMain: fileDeclaresMain,
      )) {
        continue;
      }
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: declaration.name,
        element: element,
        kindLabel: 'top-level function',
      );
    }
  }

  bool _isTopLevelCandidate(
    FunctionDeclaration declaration,
    String filePath, {
    required bool fileDeclaresMain,
  }) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    final isPrivate = name.startsWith('_');
    if (!isPrivate && fileDeclaresMain) return false;
    if (!_isTopLevelCandidateName(name, filePath)) return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }

  bool _unitDeclaresMain(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == 'main') {
        return true;
      }
    }
    return false;
  }
}
