# anal

`anal` is a pluggable static-analysis frame for Dart and Flutter projects. It
provides the contracts, registry, runner, and CLI that custom analyzer rules
plug into — so you can implement project-specific checks as plain Dart classes
without writing an analyzer plugin from scratch.

This release ships the frame **plus the first built-in rule, `unused_function`**.
Additional built-in rules (broader unused-declaration detection, `const`
suggestions, and friends) will land in future versions.

## Status / Stability

Pre-1.0.0. The public API may change between MINOR versions while the frame
matures. Pin a specific version in your `pubspec.yaml` if you need stability.

## Installation

Add `anal` as a `dev_dependency` in your project's `pubspec.yaml`:

```yaml
dev_dependencies:
  anal: ^0.1.0
```

Then fetch packages:

```sh
fvm flutter pub get
```

Or, without FVM:

```sh
dart pub get
```

## Usage / Running

Run the CLI against your project:

```sh
dart run anal [options] [paths...]
```

Or, under FVM:

```sh
fvm dart run anal [options] [paths...]
```

If no paths are given, `anal` analyzes `lib/`, `bin/`, and `test/` by default.

Flags:

- `--help`, `-h` — print usage and exit.
- `--version` — print the package version and exit.
- `--rules <id,id,...>` — restrict the run to the given rule ids.
- `--exclude <glob>` — exclude paths matching `<glob>`. Repeatable.

Exit codes:

- `0` — no diagnostics with `Severity.error`.
- `1` — at least one `Severity.error` diagnostic was emitted.
- `64` — usage error (bad flags).

### Built-in rules

`anal` ships with the following rules enabled by default. To turn one off,
pass `--rules` with a list that omits it (for example, once other rules
exist, `--rules other_rule` will run everything except `unused_function`).

#### `unused_function`

- **Id:** `unused_function`
- **Default severity:** `warning`

Flags file-local function declarations that are never referenced:

- top-level **private** functions (names beginning with `_`) in libraries
  that have no `part` files, and
- **local function declarations** (functions declared inside another
  function or method body)

that are never referenced in the same file. Both direct calls (`_foo()`)
and tear-offs (`_foo`) count as a use.

Deliberately **not** flagged in this release:

- public top-level functions (cannot be judged without cross-file analysis),
- the library's `main` function,
- methods, constructors, getters, setters, and operators,
- `external` functions,
- functions annotated with `@pragma('vm:entry-point')`,
- files belonging to libraries that have `part` files.

## Extending with custom rules (advanced / programmatic API)

Implement `AnalyzerRule`, register it with a `RuleRegistry`, and hand the
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
  for (final d in diagnostics) {
    print(d);
  }
}
```

Rules are dispatched once per file. Cross-file analyses are not supported by
the frame today.

## Roadmap

- Unused class detection.
- `var` → `const` suggestions where applicable.
- More rules coming.

## License

See [LICENSE](LICENSE).
