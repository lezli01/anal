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
/// member of a class or mixin that declares its own `noSuchMethod`,
/// because such a type can intercept any otherwise-missing call by
/// name and the rule cannot tell whether a member is unused or routed
/// through `noSuchMethod`.
///
/// To avoid duplicate noise with `unused_class`, the rule's dispatch
/// site additionally skips a candidate when its enclosing type is a
/// private declaration whose element is itself absent from the global
/// reference index — `unused_class` already flags that type, and
/// re-flagging every member of it would just repeat the report.
///
/// The diagnostic anchor is the member's name [Token].
class _ClassMemberCollector implements _UnusedFunctionCandidateCollector {
  const _ClassMemberCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ClassDeclaration) {
        // `body` is the analyzer 10.x replacement but is gated on the
        // default-off `useDeclaringConstructorsAst` experiment, so the
        // always-available `members` accessor is used. Mirrors the
        // pattern in `constructor_collector.dart`.
        // ignore: deprecated_member_use
        yield* _candidatesFor(declaration.members);
      } else if (declaration is MixinDeclaration) {
        // ignore: deprecated_member_use
        yield* _candidatesFor(declaration.members);
      } else if (declaration is EnumDeclaration) {
        // ignore: deprecated_member_use
        yield* _candidatesFor(declaration.members);
      } else if (declaration is ExtensionTypeDeclaration) {
        // ignore: deprecated_member_use
        yield* _candidatesFor(declaration.members);
      }
    }
  }

  Iterable<_Candidate> _candidatesFor(Iterable<ClassMember> members) sync* {
    if (_membersDeclareNoSuchMethod(members)) return;
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      final candidate = _candidateFor(member);
      if (candidate != null) yield candidate;
    }
  }

  _Candidate? _candidateFor(MethodDeclaration declaration) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
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
