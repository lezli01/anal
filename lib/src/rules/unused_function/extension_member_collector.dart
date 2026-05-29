part of '../unused_function_rule.dart';

/// Collector for method declarations on `extension Foo on T {}` blocks.
///
/// Iterates every [MethodDeclaration] member of an [ExtensionDeclaration]
/// (the non-type form — extension types are separate `ExtensionTypeDeclaration`
/// nodes and are intentionally not handled here). Each candidate is
/// reported with a [_Candidate.kindLabel] that disambiguates the member's
/// flavour: `extension method`, `extension static method`,
/// `extension operator`, `extension getter`, or `extension setter`.
///
/// A member is exempt when it is `external` or carries
/// `@pragma('vm:entry-point')`.
///
/// The diagnostic anchor is the member's own name [Token]. Unnamed
/// extensions have no name [Token], so when the extension itself has no
/// name and would otherwise need to be referred to, the `on`-type's
/// begin [Token] is used as a fallback.
///
/// To stay consistent with `unused_class`, the rule's dispatch site
/// additionally skips a member candidate when its enclosing extension
/// element is itself a private declaration absent from the global
/// reference index — re-flagging every member of an unused private
/// extension would just repeat the report.
class _ExtensionMemberCollector implements _UnusedFunctionCandidateCollector {
  const _ExtensionMemberCollector();

  @override
  Iterable<_Candidate> collect(
    ResolvedUnitResult unit,
    _CollectorContext context,
  ) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is! ExtensionDeclaration) continue;
      // `ExtensionDeclaration.name` is `Token?` — unnamed extensions
      // have no name token. Fall back to the `on`-type's begin token so
      // members of unnamed extensions still have a valid source anchor
      // available if the member itself lacks one.
      // ignore: deprecated_member_use
      final extensionNameToken = declaration.name;
      final onTypeToken = declaration.onClause?.extendedType.beginToken;
      final fallbackToken = extensionNameToken ?? onTypeToken;
      // Unnamed extensions have no name token; an empty name is treated
      // as non-private (it does not begin with `_`) so the public-API
      // exemption still applies to public members of an unnamed
      // extension declared outside `lib/src/`.
      final enclosingTypeName = extensionNameToken?.lexeme ?? '';
      // `members` is deprecated in favor of `body` (analyzer 10.x), but
      // `body` returns a `ClassBody` whose members getter is only
      // available after a downcast to `BlockClassBody`. Sticking with
      // the always-available `members` keeps the collector portable
      // across the supported analyzer range.
      // ignore: deprecated_member_use
      for (final member in declaration.members) {
        if (member is! MethodDeclaration) continue;
        final candidate = _candidateFor(
          member,
          fallbackToken,
          enclosingTypeName: enclosingTypeName,
          filePath: unit.path,
        );
        if (candidate != null) yield candidate;
      }
    }
  }

  _Candidate? _candidateFor(
    MethodDeclaration declaration,
    Token? fallbackToken, {
    required String enclosingTypeName,
    required String filePath,
  }) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
    if (_isPublicMemberOfPublicTypeOutsideLibSrc(
      declaration.name.lexeme,
      enclosingTypeName,
      filePath,
    )) {
      return null;
    }
    final element = declaration.declaredFragment?.element;
    if (element == null) return null;
    final nameToken = declaration.name;
    final anchor = nameToken.lexeme.isEmpty
        ? (fallbackToken ?? nameToken)
        : nameToken;
    return _Candidate(
      nameToken: anchor,
      element: _declaredElement(element),
      kindLabel: _kindLabel(declaration),
    );
  }

  String _kindLabel(MethodDeclaration declaration) {
    if (declaration.isOperator) return 'extension operator';
    if (declaration.isGetter) return 'extension getter';
    if (declaration.isSetter) return 'extension setter';
    if (declaration.isStatic) return 'extension static method';
    return 'extension method';
  }
}
