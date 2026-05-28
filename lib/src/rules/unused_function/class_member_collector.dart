part of '../unused_function_rule.dart';

/// Collector for instance- and static-member methods, operators, getters,
/// and setters declared on classes, mixins, enums, and extension types.
///
/// Every [MethodDeclaration] member of a [ClassDeclaration],
/// [MixinDeclaration], [EnumDeclaration], or [ExtensionTypeDeclaration]
/// is a candidate. The [_Candidate.kindLabel] is picked from the
/// declaration's shape:
///
/// * `setter` when [MethodDeclaration.isSetter] is `true`.
/// * `getter` when [MethodDeclaration.isGetter] is `true`.
/// * `operator` when [MethodDeclaration.operatorKeyword] is non-null.
/// * `static method` when [MethodDeclaration.isStatic] is `true`.
/// * `method` otherwise.
///
/// A member is exempt when it is `external` or carries
/// `@pragma('vm:entry-point')`. The collector additionally skips every
/// member of a class, mixin, enum, or extension type when the
/// enclosing declaration — or any class / mixin / interface reached
/// through `extends`, `with`, `implements`, or mixin `on` clauses —
/// declares its own `noSuchMethod`, because such a type can intercept
/// any otherwise-missing call by name and the rule cannot tell whether
/// a member is unused or routed through `noSuchMethod`. The walk also
/// recognises mocktail's `Fake` and `Mock` base classes by simple
/// name, since the analyzed sources typically do not pull in
/// `package:mocktail` as a resolved dependency. See
/// [_enclosingDeclaresNoSuchMethod].
///
/// To avoid duplicate noise with `unused_class`, the rule's dispatch
/// site additionally skips a candidate when its enclosing type is a
/// private declaration whose element is itself absent from the global
/// reference index — `unused_class` already flags that type, and
/// re-flagging every member of it would just repeat the report.
///
/// An `@override` member is additionally skipped when its inherited
/// supertype member is either declared outside the analyzed unit set
/// or is itself reachable; see [_overridesReachableSupertypeMember]
/// for the exact rules. This catches framework callback overrides
/// (`State.build`, `Object.toString`, etc.) as well as in-repo
/// abstract-base / concrete-subtype dispatch.
///
/// The diagnostic anchor is the member's name [Token].
class _ClassMemberCollector implements _UnusedFunctionCandidateCollector {
  const _ClassMemberCollector();

  @override
  Iterable<_Candidate> collect(
    ResolvedUnitResult unit,
    _CollectorContext context,
  ) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ClassDeclaration) {
        yield* _candidatesFor(
          // `body` is the analyzer 10.x replacement but is gated on the
          // default-off `useDeclaringConstructorsAst` experiment, so the
          // always-available `members` accessor is used. Mirrors the
          // pattern in `constructor_collector.dart`.
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
        );
      } else if (declaration is MixinDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
        );
      } else if (declaration is EnumDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
        );
      } else if (declaration is ExtensionTypeDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
        );
      }
    }
  }

  Iterable<_Candidate> _candidatesFor(
    Iterable<ClassMember> members,
    InterfaceElement? enclosing,
    _CollectorContext context,
  ) sync* {
    if (enclosing != null && _enclosingDeclaresNoSuchMethod(enclosing)) return;
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      final candidate = _candidateFor(member, context);
      if (candidate != null) yield candidate;
    }
  }

  _Candidate? _candidateFor(
    MethodDeclaration declaration,
    _CollectorContext context,
  ) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
    if (_overridesReachableSupertypeMember(declaration, context)) return null;
    final element = declaration.declaredFragment?.element;
    if (element == null) return null;
    return _Candidate(
      nameToken: declaration.name,
      element: element,
      kindLabel: _kindLabelFor(declaration),
    );
  }

  String _kindLabelFor(MethodDeclaration declaration) {
    if (declaration.isSetter) return 'setter';
    if (declaration.isGetter) return 'getter';
    if (declaration.operatorKeyword != null) return 'operator';
    if (declaration.isStatic) return 'static method';
    return 'method';
  }
}
