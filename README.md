# anal

[![CI](https://github.com/lezli01/anal/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/lezli01/anal/actions/workflows/ci.yml)
[![Release Please](https://github.com/lezli01/anal/actions/workflows/release-please.yml/badge.svg?branch=master)](https://github.com/lezli01/anal/actions/workflows/release-please.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`anal` is a pluggable static analysis framework for Dart and Flutter projects.
It provides the contracts, registry, runner, built-in rules, and CLI that
custom analyzer rules plug into, so teams can implement project-specific checks
as plain Dart classes without writing a full analyzer plugin.

This release ships the framework plus the first built-in rule:
`unused_function`. Additional built-in rules, including broader unused
declaration detection and `const` suggestions, are planned for future releases.

## Status

`anal` is pre-1.0.0. Public APIs may change between minor versions while the
framework matures. Pin a specific version in your `pubspec.yaml` if you need
repeatable behavior.

## Installation

Add `anal` as a development dependency:

```sh
flutter pub add --dev anal
```

Or edit `pubspec.yaml` directly:

```yaml
dev_dependencies:
  anal: <version>
```

## CLI Usage

Run the analyzer against the current project:

```sh
dart run anal [options] [paths...]
```

When no paths are provided, `anal` inspects `lib/`, `bin/`, and `test/`.

Options:

- `--help`, `-h`: print usage and exit.
- `--version`: print the package version and exit.
- `--rules <id,id,...>`: run only the listed rule ids.
- `--exclude <glob>`: exclude matching paths. Repeat for multiple patterns.
  Custom excludes are added on top of the built-in defaults.
- `--no-default-excludes`: disable the built-in default exclude patterns.
  Use `--exclude` to list any patterns you still want excluded.

By default, `anal` excludes generated files matching `*.g.dart` and
`*.freezed.dart`. Exclude patterns are matched against the file's basename,
its path relative to the current working directory, and its absolute path;
any match excludes the file. To opt out of the defaults entirely:

```sh
dart run anal --no-default-excludes
```

Exit codes:

- `0`: no diagnostics with `Severity.error`.
- `1`: at least one error diagnostic was emitted.
- `64`: command-line usage error.

## Built-In Rules

`anal` ships with the following rules enabled by default. To turn one off, pass
`--rules` with a list that omits it.

### `unused_function`

- **Id:** `unused_function`
- **Default severity:** `warning`
- **Dispatch:** multi-file (registered via `registerMultiFile`); the rule sees
  every resolved compilation unit in the analyzed set on a single invocation
  and resolves references across files.

Flags function-shaped declarations that are never referenced anywhere in the
analyzed file set:

- top-level functions — private (name begins with `_`) unconditionally, and
  public when the file lives under a package's `lib/src/` directory and is
  never referenced from outside it;
- top-level getters and setters, with the same privacy + `lib/src/` rule as
  top-level functions;
- local function declarations inside another function or method body;
- constructors on classes and enums (generative, named, factory, and
  redirecting forms);
- instance and `static` methods on classes, mixins, enums, and extension
  types;
- getters, setters, and operators declared on classes, mixins, enums, and
  extension types;
- methods, `static` methods, getters, setters, and operators declared inside
  `extension Foo on T {}` blocks.

Direct calls, tear-offs, named-type references, constructor invocations and
redirects, operator and index expressions, explicit member accesses, and
setter writes all count as a use. The rule is feature-aware: it also
follows Dart 3 object-pattern destructures (`final Foo(:getter) = …`),
record literals and record patterns (`(obj.getter,)` / `final (g,) = …`),
cascade sections (`obj..foo()`), and the implicit `.call` invocation on
callable objects (`instance()` resolves to `instance.call()`), so members
reached only through any of those forms are correctly counted as used.

Deliberately not flagged:

- the library's `main` function;
- public top-level functions, getters, and setters declared outside
  `lib/src/` (i.e. the package's public surface);
- `external` declarations of any shape;
- declarations annotated with `@pragma('vm:entry-point')`;
- top-level functions, getters, and setters declared in a library that has
  `part` files (a sibling part could legitimately reference them, and the
  rule does not currently traverse part libraries);
- every member and constructor of a class that declares its own
  `noSuchMethod` — that override can service any selector at runtime, so
  members reached only through it have no static reference;
- every member and constructor declared in a library that imports
  `dart:mirrors` — reflection can invoke arbitrary members by name, so the
  rule conservatively skips the whole unit;
- members of a private, unreferenced class, mixin, enum, extension type, or
  extension — `unused_class` already flags the enclosing declaration, so
  re-flagging every member would just repeat the report.

### `unused_class`

- **Id:** `unused_class`
- **Default severity:** `warning`

Flags file-local declarations whose names begin with `_` that are never
referenced within the same compilation unit:

- `class` declarations (including `abstract`, `base`, `final`, `sealed`,
  and `interface` modifiers);
- `mixin` declarations;
- `enum` declarations;
- `extension type` declarations.

Any reference to the declaration counts as a use, including type
annotations, constructor invocations, `extends`/`implements`/`with`/`on`
clauses, `is`/`as` checks, static-member access, enum-value access, and
constructor or static tear-offs. The rule is Dart 3 feature-aware: it
also follows Dart 3 object patterns (`case _Foo()` in a `switch`),
record type annotations (`(_Foo, int)`), and exhaustive `switch` on a
`sealed` supertype — so a private type referenced only through its
subtypes' pattern arms is correctly treated as used.

Deliberately not flagged in this release:

- public top-level classes, mixins, enums, and extension types;
- `class _Foo = A with B;` typedef-style class declarations
  (`ClassTypeAlias`);
- `extension` declarations (the non-type `extension _Ext on T {}` form);
- declarations annotated with `@pragma('vm:entry-point')`;
- any private candidate declared in a library that imports
  `dart:mirrors` — reflection can name arbitrary types at runtime, so
  the rule conservatively skips the whole unit;
- files belonging to libraries that have `part` files.

### `unused_source_file`

- **Id:** `unused_source_file`
- **Default severity:** `warning`

A cross-file rule that flags Dart source files in the analyzed set that
are never reached from any entry point. Reachability is computed by
walking `import`, `export`, and `part` directives whose resolved URI
lands inside the analyzed set; URIs that resolve to `dart:` libraries,
package dependencies, or files excluded from the run are ignored. For
conditional imports (`import 'x' if (dart.library.io) 'y'`), every
`if (...)` configuration contributes a reachability edge regardless of
the active platform — both alternatives stay reachable in a single
analysis run. Deferred imports (`import 'x' deferred as p`) are
followed identically to ordinary imports.

Entry points (always considered "reached") are:

- files under `bin/`;
- files under `test/`;
- files that declare a top-level `main` function;
- `lib/<package>.dart` and any other file sitting directly under `lib/`
  (i.e. not nested inside a subdirectory such as `lib/src/`), which
  together form the package's public surface.

A non-entry-point file counts as "used" if it is reachable, directly or
transitively, from an entry point via an `import`, `export`, or `part`
directive — including every configuration of a conditional import and
the target of a deferred import.

Deliberately not flagged in this release:

- entry-point files themselves (files under `bin/` or `test/`, files
  with a top-level `main`, and `lib/*.dart` files outside `lib/src/`);
- any file reached, directly or transitively, by an `import`, `export`,
  or `part` directive from an entry point — including every
  configuration of a conditional import and the target of a deferred
  import;
- generated-file basenames such as `*.g.dart` and `*.freezed.dart`,
  which are skipped defensively even if the runner's default excludes
  are turned off.

## Custom Rules

Implement `AnalyzerRule`, register it with a `RuleRegistry`, and pass the
registry to `AnalysisRunner`:

```dart
import 'package:anal/anal.dart';

class MyRule extends AnalyzerRule {
  @override
  String get id => 'my_rule';

  @override
  String get description => 'Flags a project-specific pattern.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) sync* {
    // Inspect context.unit and yield Diagnostic instances.
  }
}

Future<void> main() async {
  final registry = RuleRegistry()..register(MyRule());
  const options = AnalOptions.defaults();
  final runner = AnalysisRunner(registry: registry, options: options);

  final diagnostics = await runner.run();
  for (final diagnostic in diagnostics) {
    print(diagnostic);
  }
}
```

`AnalyzerRule` is dispatched once per file and remains the right contract
for file-local checks: implementations see a single resolved compilation
unit at a time and cannot observe sibling files.

For checks that must reason across files, implement `MultiFileAnalyzerRule`
instead. A multi-file rule is invoked once per run with the full set of
resolved compilation units, so it can build cross-file structures such as
import graphs or symbol indices. Register multi-file rules with the same
`RuleRegistry` used for `AnalyzerRule` implementations; the built-in
`unused_source_file` rule is implemented this way. Existing `AnalyzerRule`
implementations continue to work unchanged.

## Sample Projects

The [`samples/`](samples/) directory contains live, executable
documentation of each built-in rule: one self-contained Dart/Flutter
package per rule, plus an `all_rules` sample that exercises every
built-in rule together. Each sample path-depends on this package and
ships a `README.md` listing the exact positive (MUST be flagged) and
negative (MUST NOT be flagged) cases for the rule it covers.

| Sample                                                                 | Exercises                                  |
| ---------------------------------------------------------------------- | ------------------------------------------ |
| [`samples/unused_function/`](samples/unused_function/)                 | the `unused_function` rule                 |
| [`samples/unused_class/`](samples/unused_class/)                       | the `unused_class` rule                    |
| [`samples/unused_source_file/`](samples/unused_source_file/)           | the `unused_source_file` multi-file rule   |
| [`samples/all_rules/`](samples/all_rules/)                             | every built-in rule together               |

Run any sample from the repository root, for example:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run anal samples/unused_function/lib
```

## Development

This repository uses FVM to pin Flutter. Install the configured SDK before
working locally:

```sh
fvm install
fvm flutter pub get
```

Before opening a pull request, run the same checks as CI:

```sh
fvm dart format .
fvm dart analyze --fatal-infos --fatal-warnings
fvm flutter test --coverage
fvm dart pub publish --dry-run
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution workflow details and
[SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

`anal` is available under the [MIT License](LICENSE).
