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
/// A member that overrides a supertype member is additionally skipped
/// when that inherited member is either declared outside the analyzed
/// unit set or is itself reachable; see
/// [_overridesReachableSupertypeMember] for the exact rules. No explicit
/// `@override` annotation is required. This catches framework callback
/// overrides (`State.createState`, `Object.toString`, etc.) as well as
/// in-repo abstract-base / concrete-subtype dispatch.
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
          filePath: unit.path,
        );
      } else if (declaration is MixinDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
          filePath: unit.path,
        );
      } else if (declaration is EnumDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
          filePath: unit.path,
        );
      } else if (declaration is ExtensionTypeDeclaration) {
        yield* _candidatesFor(
          // ignore: deprecated_member_use
          declaration.members,
          declaration.declaredFragment?.element,
          context,
          filePath: unit.path,
        );
      }
    }
  }

  Iterable<_Candidate> _candidatesFor(
    Iterable<ClassMember> members,
    InterfaceElement? enclosing,
    _CollectorContext context, {
    required String filePath,
  }) sync* {
    if (enclosing != null && _enclosingDeclaresNoSuchMethod(enclosing)) return;
    final enclosingTypeName = enclosing?.name ?? '';
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      final candidate = _candidateFor(
        member,
        context,
        enclosingTypeName: enclosingTypeName,
        filePath: filePath,
      );
      if (candidate != null) yield candidate;
    }
  }

  _Candidate? _candidateFor(
    MethodDeclaration declaration,
    _CollectorContext context, {
    required String enclosingTypeName,
    required String filePath,
  }) {
    if (declaration.externalKeyword != null) return null;
    if (_hasVmEntryPointPragma(declaration.metadata)) return null;
    if (_overridesReachableSupertypeMember(declaration, context)) return null;
    if (_isPublicMemberOfPublicTypeOutsideLibSrc(
      declaration.name.lexeme,
      enclosingTypeName,
      filePath,
    )) {
      return null;
    }
    final element = declaration.declaredFragment?.element;
    if (element == null) return null;
    return _Candidate(
      nameToken: declaration.name,
      element: _declaredElement(element),
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

/// Whether a member named [memberName] declared on a type named
/// [enclosingTypeName] in [filePath] forms part of the package's
/// consumable public API surface and therefore cannot be proven unused.
///
/// A member is exempt when both the member name and its enclosing type
/// name are public (neither begins with `_`) and the declaring file is
/// NOT under a package's `lib/src/` directory. Such members live on the
/// package's public surface — they are reachable by external consumers
/// and exercised by tests — so "no references found in the analyzed set"
/// is not strong enough evidence to flag them, mirroring the existing
/// public-top-level exemption.
///
/// Private members, and members of private types, remain eligible to be
/// flagged. The `lib/src/` test reuses [_isTopLevelCandidateName]: for a
/// public [memberName] it returns `true` only when [filePath] lives
/// under `lib/src/`, so its negation isolates the
/// outside-`lib/src/` case.
bool _isPublicMemberOfPublicTypeOutsideLibSrc(
  String memberName,
  String enclosingTypeName,
  String filePath,
) {
  if (memberName.startsWith('_')) return false;
  if (enclosingTypeName.startsWith('_')) return false;
  return !_isTopLevelCandidateName(memberName, filePath);
}
