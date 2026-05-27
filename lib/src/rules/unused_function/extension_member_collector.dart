part of '../unused_function_rule.dart';

/// Collector for members declared inside an `ExtensionDeclaration` or
/// `ExtensionTypeDeclaration`.
///
/// Each [MethodDeclaration] in the container's `members` list — covering
/// methods, getters, setters, and operators — becomes a candidate, unless
/// it is `external` or annotated with `@pragma('vm:entry-point')`. The
/// kind label embedded in the diagnostic mirrors the declaration kind so
/// reports read naturally: "extension method", "extension getter",
/// "extension setter", "extension operator", "extension type method",
/// and so on.
///
/// Extension-member calls (`value.extMethod()`) bind their member name to
/// the extension's executable element via `SimpleIdentifier.element`, so
/// the shared reference index built by `UnusedFunctionRule` already
/// observes those uses with no additional plumbing in the collector.
///
/// Primary constructors and representation fields of extension types are
/// out of scope: the collector only inspects `MethodDeclaration` nodes,
/// so the implicitly-declared representation slot is untouched.
class _ExtensionMemberCollector implements _UnusedFunctionCandidateCollector {
  const _ExtensionMemberCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ExtensionDeclaration) {
        yield* _candidatesFrom(declaration.body.members, 'extension');
      } else if (declaration is ExtensionTypeDeclaration) {
        final body = declaration.body;
        if (body is BlockClassBody) {
          yield* _candidatesFrom(body.members, 'extension type');
        }
      }
    }
  }

  Iterable<_Candidate> _candidatesFrom(
    NodeList<ClassMember> members,
    String containerLabel,
  ) sync* {
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      if (member.externalKeyword != null) continue;
      if (_hasVmEntryPointPragma(member.metadata)) continue;
      final element = member.declaredFragment?.element;
      if (element == null) continue;
      yield _Candidate(
        nameToken: member.name,
        element: element,
        kindLabel: '$containerLabel ${_memberKind(member)}',
      );
    }
  }

  String _memberKind(MethodDeclaration member) {
    if (member.isGetter) return 'getter';
    if (member.isSetter) return 'setter';
    if (member.isOperator) return 'operator';
    return 'method';
  }
}
