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
  anal: ^0.1.0
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
its path relative to the current working directory, and its absolute path
and any match excludes the file. To opt out of the defaults entirely:

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

Flags file-local function declarations that are never referenced:

- top-level private functions, whose names begin with `_`, in libraries that
  have no `part` files;
- local function declarations inside another function or method body.

Both direct calls, such as `_foo()`, and tear-offs, such as `_foo`, count as a
use.

Deliberately not flagged in this release:

- public top-level functions;
- the library's `main` function;
- methods, constructors, getters, setters, and operators;
- `external` functions;
- functions annotated with `@pragma('vm:entry-point')`;
- files belonging to libraries that have `part` files.

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

Rules are dispatched once per file. Cross-file analysis is intentionally out
of scope for the current rule API.

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
