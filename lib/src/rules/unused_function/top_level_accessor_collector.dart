part of '../unused_function_rule.dart';

/// Collector for top-level getter and setter declarations.
///
/// Iterates [FunctionDeclaration] nodes at the top level whose
/// [FunctionDeclaration.isGetter] or [FunctionDeclaration.isSetter] is
/// true. Private accessors (identifier begins with `_`) are candidates
/// unconditionally; public accessors are only candidates when the file
/// lives under a package's `lib/src/` directory — the same heuristic
/// applied by [_TopLevelFunctionCollector] for its own public-mode
/// flagging, shared via [_isTopLevelCandidateName].
///
/// A declaration is exempt when its name is `main`, when it is declared
/// `external`, when it carries `@pragma('vm:entry-point')`, or when the
/// enclosing library has any `part` files — otherwise a sibling part
/// could legitimately reference the accessor and the rule would have to
/// be cross-library aware to know that.
///
/// The diagnostic anchor is the declaration's name [Token]; the
/// `kindLabel` is `top-level getter` or `top-level setter` depending on
/// the form.
class _TopLevelAccessorCollector implements _UnusedFunctionCandidateCollector {
  const _TopLevelAccessorCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    if (unit.libraryElement.fragments.length > 1) return;
    for (final declaration in unit.unit.declarations) {
      if (declaration is! FunctionDeclaration) continue;
      if (!declaration.isGetter && !declaration.isSetter) continue;
      if (!_isAccessorCandidate(declaration, unit.path)) continue;
      final element = declaration.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: declaration.name,
        element: element,
        kindLabel: declaration.isGetter
            ? 'top-level getter'
            : 'top-level setter',
      );
    }
  }

  bool _isAccessorCandidate(FunctionDeclaration declaration, String filePath) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    if (!_isTopLevelCandidateName(name, filePath)) return false;
    return true;
  }
}
