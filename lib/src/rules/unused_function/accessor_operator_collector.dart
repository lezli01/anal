part of '../unused_function_rule.dart';

/// Collector for getter, setter, and operator declarations on classes
/// and mixins.
///
/// Every [MethodDeclaration] inside a [ClassDeclaration] or
/// [MixinDeclaration] whose `isGetter`, `isSetter`, or `isOperator`
/// returns `true` is a candidate, subject to the standard exemptions:
/// `external` accessors/operators and any declaration annotated with
/// `@pragma('vm:entry-point')` are skipped. Accessors and operators
/// that override or implement a supertype member are also skipped —
/// flagging them would amount to telling the author "remove this
/// override", which is never correct because the supertype dictates
/// the API surface.
///
/// Getters, setters, and operators each resolve to distinct
/// [Element]s in the analyzer's model, so the collector emits one
/// candidate per kind and the rule applies the global reference check
/// independently to each. A class that declares `get x` and a separate
/// `set x` therefore produces two candidates; one can be flagged
/// without the other being touched.
class _AccessorOperatorCollector implements _UnusedFunctionCandidateCollector {
  const _AccessorOperatorCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) sync* {
    for (final declaration in unit.unit.declarations) {
      if (declaration is ClassDeclaration) {
        // `ClassDeclaration.body.members` requires the experimental
        // `useDeclaringConstructorsAst` flag (default-off in analyzer
        // 9.x/10.x); accessing the body otherwise throws
        // `UnsupportedError`. The deprecated `members` accessor is the
        // portable fallback.
        // ignore: deprecated_member_use
        yield* _candidatesIn(declaration.members);
      } else if (declaration is MixinDeclaration) {
        // ignore: deprecated_member_use
        yield* _candidatesIn(declaration.members);
      }
    }
  }

  Iterable<_Candidate> _candidatesIn(NodeList<ClassMember> members) sync* {
    for (final member in members) {
      if (member is! MethodDeclaration) continue;
      if (!member.isGetter && !member.isSetter && !member.isOperator) {
        continue;
      }
      if (member.externalKeyword != null) continue;
      if (_hasVmEntryPointPragma(member.metadata)) continue;
      final element = member.declaredFragment?.element;
      if (element is! ExecutableElement) continue;
      if (_overridesSupertypeMember(element)) continue;
      final String kindLabel;
      if (member.isGetter) {
        kindLabel = 'getter';
      } else if (member.isSetter) {
        kindLabel = 'setter';
      } else {
        kindLabel = 'operator';
      }
      yield _Candidate(
        nameToken: member.name,
        element: element,
        kindLabel: kindLabel,
      );
    }
  }
}
