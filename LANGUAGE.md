# Dart Static Analysis Knowledge Base

Version: 1.0
Purpose: Persistent engineering context for AI agents developing or maintaining Dart static analysis tooling.

---

# Goal

This document defines Dart language constructs, compiler behaviors, and ecosystem patterns that significantly affect static analysis.

Agents MUST consult and update this document when implementing:

* parsers
* AST transforms
* symbol resolution
* dependency graphs
* call graph analysis
* code indexing
* tree shaking
* dead code detection
* refactoring tools
* lint engines
* code intelligence systems
* AI-assisted code understanding

This document is intended to evolve incrementally over time.

---

# Core Principle

Dart is NOT a purely file-based language.

Correct analysis frequently requires:

* whole-library analysis
* whole-package analysis
* build-time context
* platform-aware resolution
* generated code awareness
* flow-sensitive typing
* environment evaluation

Agents MUST avoid assumptions common in simpler languages.

---

# Analysis Risk Levels

| Risk    | Meaning                                  |
| ------- | ---------------------------------------- |
| LOW     | Mostly local/static                      |
| MEDIUM  | Requires type/context resolution         |
| HIGH    | Requires whole-program analysis          |
| EXTREME | Runtime behavior breaks static certainty |

---

# 1. Conditional Imports and Exports

Risk: HIGH

## Syntax

```dart
import 'stub.dart'
    if (dart.library.io) 'io.dart';

export 'mobile.dart'
    if (dart.library.html) 'web.dart';
```

## Why This Matters

The actual imported/exported implementation depends on compile target.

The same source tree may produce different symbol graphs on:

* Flutter mobile
* Flutter web
* Dart VM
* WASM
* tests

## Analyzer Requirements

MUST:

* evaluate environment conditions
* support platform-specific graphs
* resolve conditional branches

MUST NOT:

* assume a single canonical import graph

## Common Conditions

```dart
dart.library.io
dart.library.html
dart.library.js_interop
dart.library.ffi
```

---

# 2. Library Parts (`part` / `part of`)

Risk: HIGH

## Syntax

```dart
library my_lib;

part 'a.dart';
part 'b.dart';
```

```dart
part of my_lib;
```

## Why This Matters

Files become a single merged compilation unit.

Implications:

* private members shared across parts
* symbols exist without imports
* file-level analysis becomes invalid

## Analyzer Requirements

MUST:

* merge all parts before semantic analysis
* build library-level symbol tables

MUST NOT:

* treat part files as independent modules

---

# 3. Generated Code

Risk: HIGH

## Common Patterns

```dart
part 'model.g.dart';
```

Generators:

* json_serializable
* freezed
* retrofit
* injectable
* drift
* hive
* riverpod_generator

## Why This Matters

Generated files may define:

* APIs
* serialization
* routing
* dependency injection
* equality
* copy methods
* state systems

Source analysis is incomplete without generated artifacts.

## Analyzer Requirements

MUST:

* include generated files in indexing
* support incremental regeneration
* track generator dependencies

MUST NOT:

* ignore `.g.dart` or `.freezed.dart`

---

# 4. Extension Methods

Risk: HIGH

## Syntax

```dart
extension FancyString on String {
  int get doubledLength => length * 2;
}
```

## Why This Matters

Methods appear attached to foreign types.

Resolution depends on:

* imports
* visibility
* type inference
* extension precedence

## Analyzer Requirements

MUST:

* resolve extensions during method lookup
* support competing extensions
* apply type-aware dispatch

---

# 5. Extension Types (Dart 3)

Risk: HIGH

## Syntax

```dart
extension type UserId(int value) {}
```

## Why This Matters

Extension types are compiler-backed wrappers.

Representation type differs from semantic type.

## Analyzer Requirements

MUST:

* distinguish representation type vs exposed type
* support lowering semantics

---

# 6. Dynamic Dispatch (`dynamic`)

Risk: EXTREME

## Syntax

```dart
dynamic x = something();
x.foo();
```

## Why This Matters

Method targets become unknowable statically.

## Analyzer Requirements

MUST:

* model uncertainty conservatively
* mark incomplete call graph regions

MUST NOT:

* assume statically known target

---

# 7. `noSuchMethod`

Risk: EXTREME

## Syntax

```dart
class Proxy {
  @override
  dynamic noSuchMethod(Invocation invocation) {}
}
```

## Why This Matters

Objects may respond to methods that do not exist statically.

Common in:

* proxies
* mocks
* RPC wrappers
* dynamic adapters

## Analyzer Requirements

MUST:

* detect overrides
* treat unresolved calls carefully

---

# 8. Reflection (`dart:mirrors`)

Risk: EXTREME

## Why This Matters

Runtime reflection invalidates many static assumptions.

Can dynamically:

* inspect types
* invoke methods
* discover classes

## Analyzer Requirements

MUST:

* switch to conservative reachability mode

MUST NOT:

* aggressively tree-shake reflective code

---

# 9. Deferred Imports

Risk: HIGH

## Syntax

```dart
import 'big.dart' deferred as big;

await big.loadLibrary();
```

## Why This Matters

Code loading becomes runtime-dependent.

## Analyzer Requirements

MUST:

* model lazy module boundaries
* track deferred reachability

---

# 10. Mixins

Risk: MEDIUM

## Syntax

```dart
mixin Logger {
  void log() {}
}
```

## Why This Matters

Members are injected into classes.

Resolution order matters.

## Analyzer Requirements

MUST:

* apply mixin linearization
* synthesize effective members

---

# 11. Pattern Matching (Dart 3)

Risk: MEDIUM

## Syntax

```dart
switch (value) {
  case [int a, int b]:
}
```

## Why This Matters

Patterns introduce:

* structural matching
* destructuring
* flow typing

## Analyzer Requirements

MUST:

* support pattern ASTs
* perform exhaustiveness checks
* track promoted types

---

# 12. Records

Risk: MEDIUM

## Syntax

```dart
(int, String) pair = (1, 'x');
```

## Why This Matters

Records are structural anonymous types.

## Analyzer Requirements

MUST:

* track record shapes
* support positional/named fields

---

# 13. Flow-Sensitive Typing

Risk: HIGH

## Syntax

```dart
if (x is String) {
  print(x.length);
}
```

## Why This Matters

Types change across control flow.

## Analyzer Requirements

MUST:

* support promoted types
* build flow-aware type state

---

# 14. Async / Await

Risk: MEDIUM

## Syntax

```dart
await fetch();
```

## Why This Matters

Compiler rewrites async functions into state machines.

## Analyzer Requirements

MUST:

* understand async lowering
* preserve async call edges

---

# 15. Cascades

Risk: MEDIUM

## Syntax

```dart
obj
  ..foo()
  ..bar();
```

## Why This Matters

Multiple mutations occur in one expression.

## Analyzer Requirements

MUST:

* desugar cascades correctly

---

# 16. Callable Objects

Risk: MEDIUM

## Syntax

```dart
class A {
  void call() {}
}
```

## Why This Matters

Objects become invocable functions.

## Analyzer Requirements

MUST:

* resolve implicit `call()` dispatch

---

# 17. Tear-Offs

Risk: MEDIUM

## Syntax

```dart
var fn = obj.method;
```

## Why This Matters

Functions become first-class values.

## Analyzer Requirements

MUST:

* track function references separately from invocations

---

# 18. Factory Constructors

Risk: MEDIUM

## Syntax

```dart
factory A() => CachedA();
```

## Why This Matters

Constructors may return different runtime types.

## Analyzer Requirements

MUST:

* model possible subtype substitution

---

# 19. Environment Constants

Risk: HIGH

## Syntax

```dart
const bool.fromEnvironment('dart.vm.product');
```

## Why This Matters

Build flags affect reachable code.

## Analyzer Requirements

MUST:

* evaluate build environments
* support configuration-aware analysis

---

# 20. Macros (Future Risk)

Risk: EXTREME

## Why This Matters

Macros may rewrite or synthesize ASTs at compile time.

## Analyzer Requirements

Future analyzers MUST:

* support expansion phases
* separate source AST vs generated AST

---

# Flutter-Specific Notes

Flutter heavily amplifies analysis complexity through:

* generated code
* widget generics
* declarative builders
* extension-heavy APIs
* conditional imports
* async state systems

## Important Ecosystem Tools

Agents SHOULD understand:

* build_runner
* analyzer package
* source_gen
* freezed
* riverpod
* json_serializable

---

# Analyzer Design Principles

## Principle 1

Never trust file-level analysis alone.

---

## Principle 2

Generated code is part of the program.

---

## Principle 3

Type inference is mandatory for correctness.

---

## Principle 4

Platform conditions alter symbol graphs.

---

## Principle 5

Dynamic features require conservative assumptions.

---

# Recommended Analysis Pipeline

## Phase 1 — Parse

* parse all sources
* collect directives
* detect generated artifacts

## Phase 2 — Library Resolution

* merge parts
* resolve imports
* evaluate conditional imports

## Phase 3 — Type Graph

* resolve generics
* build inheritance graph
* apply extensions
* apply mixins

## Phase 4 — Semantic Resolution

* flow typing
* pattern resolution
* async lowering
* callable resolution

## Phase 5 — Reachability

* build call graph
* apply deferred loading
* model dynamic uncertainty

## Phase 6 — Output

* diagnostics
* indexes
* dependency graphs
* code intelligence artifacts

---

# Known Dangerous Assumptions

Agents MUST NOT assume:

* one file == one module
* imports are unconditional
* constructors return declared type
* methods exist only in classes
* source code is complete without generators
* static type == runtime type
* unresolved call == invalid call

---

# Future Extension Areas

Future versions SHOULD include:

* FFI analysis
* JS interop
* WASM semantics
* macro system details
* isolate behavior
* analyzer package internals
* package_config semantics
* kernel IR notes
* build_runner graph modeling

---

# Maintenance Rules

When extending this document:

1. Add risk classification
2. Add syntax example
3. Explain analysis impact
4. Define analyzer requirements
5. Prefer actionable engineering guidance
6. Avoid tutorial-style explanations
7. Keep language implementation-focused

---

# End of Document
