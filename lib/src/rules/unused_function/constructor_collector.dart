part of '../unused_function_rule.dart';

/// Collector for constructor declarations on classes and enums.
///
/// Every [ConstructorDeclaration] member of a [ClassDeclaration] or
/// [EnumDeclaration] is a candidate, covering generative, named, factory,
/// and redirecting forms. The synthetic unnamed constructor the analyzer
/// inserts when a class declares no constructors is intentionally not
/// considered: this collector only iterates AST nodes, and that
/// constructor has no [ConstructorDeclaration] in the source.
///
/// A constructor is exempt when it is `external` or carries
/// `@pragma('vm:entry-point')`. The collector additionally skips every
/// constructor on a class that declares its own `noSuchMethod`,
/// because such a class can intercept any otherwise-missing call by
/// name and the rule cannot tell whether a constructor is truly unused
/// or invoked through reflection / dynamic dispatch on its enclosing
/// type.
///
/// To avoid duplicate noise with `unused_class`, the rule's dispatch
/// site additionally skips a constructor candidate when its enclosing
/// class element is itself absent from the global reference index —
/// `unused_class` already flags that class, and re-flagging every
/// constructor of it would just repeat the report.
///
/// The diagnostic anchor is the constructor's name [Token] for named
/// constructors (e.g. `named` in `MyClass.named()`), and the class name
/// [Token] for the unnamed default constructor (e.g. `MyClass` in
/// `MyClass();`).
class _ConstructorCollector implements _UnusedFunctionCandidateCollector {
  const _ConstructorCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ClassDeclaration) {
        // `ClassDeclaration.namePart` requires the experimental
        // `useDeclaringConstructorsAst` flag (default-off in analyzer
        // 9.x/10.x) and throws `UnsupportedError` otherwise. The
        // always-available `name` token is used instead.
        // ignore: deprecated_member_use
        final classNameToken = declaration.name;
        // `members` is deprecated in favor of `body` (analyzer 10.x), but
        // `body` returns a `ClassBody` whose members getter is only
        // available after a downcast to `BlockClassBody`. Sticking with
        // the always-available `members` keeps the collector portable
        // across the supported analyzer range.
        // ignore: deprecated_member_use
        final members = declaration.members;
        if (_membersDeclareNoSuchMethod(members)) continue;
        for (final member in members) {
          if (member is! ConstructorDeclaration) continue;
          final candidate = _candidateFor(member, classNameToken);
          if (candidate != null) yield candidate;
        }
      } else if (declaration is EnumDeclaration) {
        // See the `ClassDeclaration` branch above: `namePart` is gated on
        // the same default-off experiment, so `name` is the portable
        // accessor.
        // ignore: deprecated_member_use
        final enumNameToken = declaration.name;
        // See the `ClassDeclaration` branch above for why `members` is
        // preferred over the deprecation's suggested `body` accessor.
        // ignore: deprecated_member_use
        final members = declaration.members;
        if (_membersDeclareNoSuchMethod(members)) continue;
        for (final member in members) {
          if (member is! ConstructorDeclaration) continue;
          final candidate = _candidateFor(member, enumNameToken);
          if (candidate != null) yield candidate;
        }
      }
    }
  }

  _Candidate? _candidateFor(
    ConstructorDeclaration declaration,
    Token classNameToken,
  ) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
    final element = declaration.declaredFragment?.element;
    if (element == null) return null;
    final nameToken = declaration.name ?? classNameToken;
    return _Candidate(
      nameToken: nameToken,
      element: element,
      kindLabel: 'constructor',
    );
  }
}
