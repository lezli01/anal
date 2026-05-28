import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;

import '../diagnostic.dart';
import '../multi_file_analysis_context.dart';
import '../multi_file_analyzer_rule.dart';
import '../severity.dart';
import '../source_location.dart';

part 'unused_function/class_member_collector.dart';
part 'unused_function/constructor_collector.dart';
part 'unused_function/extension_member_collector.dart';
part 'unused_function/local_function_collector.dart';
part 'unused_function/top_level_accessor_collector.dart';
part 'unused_function/top_level_function_collector.dart';

/// Flags function-shaped declarations that are never referenced across
/// the analyzed file set.
///
/// The rule is a [MultiFileAnalyzerRule]: it is dispatched once per
/// analysis run with every resolved compilation unit in scope, so it
/// can resolve references that cross file boundaries. The following
/// kinds of declarations are inspected, each by a dedicated collector:
///
/// * **Top-level functions** — private declarations (identifier begins
///   with `_`) unconditionally, and public declarations only when the
///   unit lives under a package's `lib/src/` directory. In both cases
///   the enclosing library must have no `part` files, because
///   otherwise a sibling part could legitimately reference the
///   function. See [_TopLevelFunctionCollector].
/// * **Top-level getters and setters** — same privacy + `lib/src/` and
///   no-`part`-files rule as top-level functions. See
///   [_TopLevelAccessorCollector].
/// * **Local function declarations** — functions declared inside
///   another function or method body. See [_LocalFunctionCollector].
/// * **Constructor declarations** on classes and enums (generative,
///   named, factory, and redirecting forms). See
///   [_ConstructorCollector].
/// * **Class, mixin, enum, and extension-type members** — instance
///   methods, `static` methods, operators, getters, and setters. See
///   [_ClassMemberCollector].
/// * **Extension members** declared inside `extension Foo on T {}`
///   blocks — methods, `static` methods, operators, getters, and
///   setters. See [_ExtensionMemberCollector].
///
/// A declaration is considered "used" if its [Element] appears in the
/// global reference set built by [_GlobalReferenceCollector], which
/// walks every unit in the [MultiFileAnalysisContext] and registers
/// the resolved element of every reference-bearing AST node — including
/// tear-offs, named-type references, constructor invocations and
/// redirects, operator and index expressions, explicit member accesses,
/// and setter writes.
///
/// The rule deliberately ignores the library's `main` entry point,
/// public top-level functions / getters / setters declared outside
/// `lib/src/`, `external` declarations of any shape, declarations
/// annotated with `@pragma('vm:entry-point')`, and (for top-level
/// function and accessor candidates) any declaration in a library that
/// has `part` files.
///
/// To avoid duplicate noise with the `unused_class` rule, a member
/// candidate is also skipped when its enclosing class, mixin, enum,
/// extension type, or extension is itself a private, unreferenced
/// declaration: `unused_class` already flags that enclosing
/// declaration, and re-flagging every member of it would just repeat
/// the report.
///
/// Additional dispatch-site exemptions cover language features that
/// can reach members through reflection or dynamic dispatch:
///
/// * **`noSuchMethod`-declaring classes/mixins.** When the enclosing
///   class or mixin declares its own `noSuchMethod`, every undefined
///   call lands in `noSuchMethod` rather than a "no such method"
///   error, so any member name might legitimately be invoked
///   dynamically. The rule skips member and constructor candidates of
///   such enclosing declarations to avoid false positives.
/// * **Libraries that import `dart:mirrors`.** The `dart:mirrors`
///   library can invoke arbitrary methods by name at runtime, so any
///   member of an analyzed library that imports `dart:mirrors` is
///   treated as potentially used. The rule skips member and
///   constructor candidates declared in such libraries.
///
/// **Features that flow through existing visitors with no extra
/// handling.** The following language features do not need
/// rule-specific support — the existing reference visitors already
/// pick up the references they generate:
///
/// * **Deferred imports** (`import '…' deferred as p;`) — references
///   through the prefix still resolve to the same library elements
///   that a normal import would, and land via [PrefixedIdentifier] /
///   [PropertyAccess] visits.
/// * **Conditional imports** (`if (…) '…'`) — only one branch is
///   chosen by the analyzer; references through the resolved branch
///   land via the standard visitors.
/// * **`sealed`, `base`, `interface`, and `final` class modifiers** —
///   these change subtyping rules but produce ordinary
///   [ClassDeclaration] nodes whose members and uses look the same to
///   the visitor as a plain `class`.
/// * **Mixins (`mixin`, `mixin class`)** — declared via
///   [MixinDeclaration] / [ClassDeclaration] and processed by the
///   existing class-member collector. `with` clauses are visited as
///   [NamedType]s and pick up the references through that path.
/// * **`const` constructors** — declared via [ConstructorDeclaration]
///   like any other constructor and used through
///   [InstanceCreationExpression] / [ConstructorName] visits.
class UnusedFunctionRule implements MultiFileAnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedFunctionRule();

  @override
  String get id => 'unused_function';

  @override
  String get description =>
      'Flags function declarations that are never referenced across the '
      'analyzed file set.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    final globalReferences = <Element>{};
    for (final unit in context.units) {
      unit.unit.accept(_GlobalReferenceCollector(globalReferences));
    }

    const collectors = <_UnusedFunctionCandidateCollector>[
      _TopLevelFunctionCollector(),
      _TopLevelAccessorCollector(),
      _LocalFunctionCollector(),
      _ConstructorCollector(),
      _ExtensionMemberCollector(),
      _ClassMemberCollector(),
    ];
    const memberCollectors = <Type>{
      _ConstructorCollector,
      _ExtensionMemberCollector,
      _ClassMemberCollector,
    };

    final diagnostics = <Diagnostic>[];
    for (final unit in context.units) {
      final skipMemberCandidates = _unitImportsDartMirrors(unit.unit);
      for (final collector in collectors) {
        if (skipMemberCandidates &&
            memberCollectors.contains(collector.runtimeType)) {
          continue;
        }
        for (final candidate in collector.collect(unit)) {
          if (globalReferences.contains(candidate.element)) continue;
          if (_enclosingClassIsUnflaggedUnreferencedPrivate(
            candidate.element,
            globalReferences,
          )) {
            continue;
          }
          diagnostics.add(
            _buildDiagnostic(
              candidate: candidate,
              filePath: unit.path,
              lineInfo: unit.lineInfo,
            ),
          );
        }
      }
    }

    diagnostics.sort((a, b) {
      final byPath = a.location.filePath.compareTo(b.location.filePath);
      if (byPath != 0) return byPath;
      final byLine = a.location.line.compareTo(b.location.line);
      if (byLine != 0) return byLine;
      return a.location.column.compareTo(b.location.column);
    });

    return diagnostics;
  }

  bool _enclosingClassIsUnflaggedUnreferencedPrivate(
    Element element,
    Set<Element> globalReferences,
  ) {
    final enclosing = element.enclosingElement;
    final String? name;
    if (enclosing is InterfaceElement) {
      name = enclosing.name;
    } else if (enclosing is ExtensionElement) {
      name = enclosing.name;
    } else {
      return false;
    }
    if (name == null || !name.startsWith('_')) return false;
    return !globalReferences.contains(enclosing);
  }

  Diagnostic _buildDiagnostic({
    required _Candidate candidate,
    required String filePath,
    required LineInfo lineInfo,
  }) {
    final nameToken = candidate.nameToken;
    final name = nameToken.lexeme;
    final offset = nameToken.offset;
    final length = nameToken.length;
    final location = lineInfo.getLocation(offset);
    return Diagnostic(
      ruleId: 'unused_function',
      message: 'The ${candidate.kindLabel} "$name" is declared but never used.',
      severity: Severity.warning,
      location: SourceLocation(
        filePath: filePath,
        offset: offset,
        length: length,
        line: location.lineNumber,
        column: location.columnNumber,
      ),
      correction: 'Remove "$name" or reference it.',
    );
  }
}

/// Whether a top-level declaration named [name] declared in [filePath]
/// is eligible to be flagged by the rule based on its name's privacy and
/// the file's location within a package layout.
///
/// Private names (identifier begins with `_`) are always eligible.
/// Public names are only eligible when the file lives under a package's
/// `lib/src/` directory — files outside `lib/src/` form a package's
/// public surface and consumers reference them externally, so the rule
/// can never be sure a public top-level declaration is truly unused.
bool _isTopLevelCandidateName(String name, String filePath) {
  if (name.startsWith('_')) return true;
  final segments = p.split(filePath);
  for (var i = 0; i + 1 < segments.length; i++) {
    if (segments[i] == 'lib' && segments[i + 1] == 'src') return true;
  }
  return false;
}

/// Whether [unit] contains an `import 'dart:mirrors';` directive.
///
/// `dart:mirrors` lets a program look up and invoke arbitrary members
/// by name at runtime, so under the mirrors assumption any declared
/// member of the importing library might legitimately be referenced
/// without that reference appearing in the AST. The dispatch site uses
/// this signal to skip class, mixin, enum, extension type, extension,
/// and constructor candidates declared in such libraries.
bool _unitImportsDartMirrors(CompilationUnit unit) {
  for (final directive in unit.directives) {
    if (directive is! ImportDirective) continue;
    if (directive.uri.stringValue == 'dart:mirrors') return true;
  }
  return false;
}

/// Whether [members] contains a `noSuchMethod` method declaration.
///
/// A class or mixin that overrides `noSuchMethod` can intercept any
/// call that would otherwise be a "no such method" error, so the rule
/// cannot tell whether a member is truly unused or routed through
/// `noSuchMethod`. Member and constructor collectors use this to skip
/// candidates declared on such enclosing types.
bool _membersDeclareNoSuchMethod(Iterable<ClassMember> members) {
  for (final member in members) {
    if (member is MethodDeclaration && member.name.lexeme == 'noSuchMethod') {
      return true;
    }
  }
  return false;
}

bool _hasVmEntryPointPragma(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    final identifier = annotation.name;
    final simpleName = identifier is SimpleIdentifier
        ? identifier.name
        : identifier is PrefixedIdentifier
        ? identifier.identifier.name
        : '';
    if (simpleName != 'pragma') continue;
    final arguments = annotation.arguments;
    if (arguments == null || arguments.arguments.isEmpty) continue;
    final first = arguments.arguments.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}

/// Collector contract for the candidate-discovery half of
/// [UnusedFunctionRule].
///
/// Each implementation owns a single declaration kind (top-level
/// functions, local functions, constructors, ...) and yields a
/// [_Candidate] per declaration that the rule's dispatch site should
/// then test against the global reference set.
abstract class _UnusedFunctionCandidateCollector {
  /// Yields the candidates the implementation discovered in [unit].
  Iterable<_Candidate> collect(ResolvedUnitResult unit);
}

/// A declaration the rule may flag if its [element] is not referenced.
///
/// [nameToken] is the source [Token] used as the diagnostic anchor (the
/// declaration's identifier; for unnamed default constructors, the
/// class name token). [kindLabel] is the human-readable kind that
/// appears in the diagnostic message (e.g. `top-level function`,
/// `local function`, `constructor`).
class _Candidate {
  final Token nameToken;
  final Element element;
  final String kindLabel;

  const _Candidate({
    required this.nameToken,
    required this.element,
    required this.kindLabel,
  });
}

/// Walks an entire [MultiFileAnalysisContext] and records every element
/// reached through a reference-bearing AST node.
///
/// Compared with the previous single-unit `_ReferenceCollector`, this
/// visitor inspects the AST node kinds that resolve to executable
/// elements outside of plain [SimpleIdentifier] usage — operator and
/// index expressions, constructor invocations and redirects, named
/// types, and explicit member accesses — so that cross-unit references
/// land in the same global set the dispatch site queries.
class _GlobalReferenceCollector extends RecursiveAstVisitor<void> {
  final Set<Element> sink;

  _GlobalReferenceCollector(this.sink);

  void _add(Element? element) {
    if (element != null) sink.add(element);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _add(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _add(node.element);
    super.visitNamedType(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    _add(node.element);
    super.visitConstructorName(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _add(node.constructorName.element);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitRedirectingConstructorInvocation(
    RedirectingConstructorInvocation node,
  ) {
    _add(node.element);
    super.visitRedirectingConstructorInvocation(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    _add(node.element);
    super.visitSuperConstructorInvocation(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _add(node.redirectedConstructor?.element);
    // Skip the class-name anchor (`typeName`) — declaring a constructor
    // is not a "use" of its enclosing class, and counting it would make
    // every class with at least one declared constructor look
    // referenced by itself. Visit the remaining children manually.
    node.metadata.accept(this);
    node.parameters.accept(this);
    node.initializers.accept(this);
    node.redirectedConstructor?.accept(this);
    node.body.accept(this);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _add(node.element);
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _add(node.element);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _add(node.element);
    super.visitPostfixExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _add(node.element);
    super.visitIndexExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _add(node.propertyName.element);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _add(node.element);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    // In a write context (`foo = …` or compound `foo += …`), the LHS
    // identifier's resolved element is the read element if any. The
    // setter is only reachable via the assignment's own [writeElement].
    // Without this hook a cross-file setter write would never land in
    // the global reference set, and a top-level setter declaration
    // would be flagged as unused even when written to from elsewhere.
    _add(node.writeElement);
    _add(node.readElement);
    super.visitAssignmentExpression(node);
  }

  @override
  void visitPatternField(PatternField node) {
    // Object-pattern fields resolve `effectiveName` to a getter on the
    // matched type — e.g. in `Point(x: var px)`, `x` is the `Point.x`
    // getter. Without this hook the getter declaration would look
    // unreferenced even though the pattern destructures through it.
    // Record-pattern fields always have a `null` element and fall
    // through harmlessly.
    _add(node.element);
    super.visitPatternField(node);
  }

  @override
  void visitObjectPattern(ObjectPattern node) {
    // The pattern's `type` is a [NamedType] and the fields are
    // [PatternField]s — both pick up their references through the
    // dedicated visitors. This hook exists to make that flow explicit
    // and to give the rule an obvious extension point.
    super.visitObjectPattern(node);
  }

  @override
  void visitRecordPattern(RecordPattern node) {
    // Record-pattern fields' patterns are themselves visited, so any
    // sub-pattern (declared variable, constant, nested object pattern,
    // etc.) contributes its references through the standard visitor
    // dispatch.
    super.visitRecordPattern(node);
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    // The pattern's optional [TypeAnnotation] flows through children
    // and lands in [visitNamedType] — exactly what is needed to count
    // type references inside patterns as uses.
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitConstantPattern(ConstantPattern node) {
    // The wrapped constant [Expression] (e.g. `const Foo()`,
    // `MyEnum.x`) is visited as a child, so references reach the
    // standard hooks.
    super.visitConstantPattern(node);
  }

  @override
  void visitDotShorthandConstructorInvocation(
    DotShorthandConstructorInvocation node,
  ) {
    // `.named(args)` resolves to a constructor element on the context
    // type. Record it directly because the dot-shorthand's only child
    // identifier (`constructorName`) does not carry the resolved
    // constructor element on its own.
    _add(node.element);
    super.visitDotShorthandConstructorInvocation(node);
  }

  @override
  void visitDotShorthandPropertyAccess(DotShorthandPropertyAccess node) {
    // `.foo` resolves to a getter on the context type. The `propertyName`
    // SimpleIdentifier carries the resolved element, so descending into
    // children via the recursive visitor is enough — visiting the
    // identifier records the getter element via [visitSimpleIdentifier].
    super.visitDotShorthandPropertyAccess(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    // `obj()` on a callable object resolves to the object's `call`
    // method (an implicit `.call` tear-off / invocation). Without this
    // hook, declaring a `call` method on a class and invoking it via
    // `instance()` would not register a use of `call`, and the method
    // would be flagged as unused.
    _add(node.element);
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitCascadeExpression(CascadeExpression node) {
    // Cascade sections (`target..foo()..bar = 1`) are visited as
    // children just like top-level method calls and assignments, so
    // their references land via the standard visitors. This hook is
    // declared explicitly so the coverage is documented at the
    // visitor level.
    super.visitCascadeExpression(node);
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    // Record-literal fields are arbitrary [Expression]s and are
    // visited through the recursive walk, so references inside a
    // record literal — including method invocations and tear-offs —
    // land via the standard visitors.
    super.visitRecordLiteral(node);
  }
}
