# Changelog

## Unreleased

### Added

- New `--no-default-excludes` CLI flag that opts out of the built-in
  default exclude patterns. Pair it with explicit `--exclude` flags when
  you want full control over which paths are skipped.
- New `AnalOptions.defaultExcludePaths` constant exposing the list of
  glob patterns excluded by `AnalOptions.defaults()`. Useful when
  composing custom `AnalOptions` instances programmatically.
- New default-on `unused_function` rule. It flags file-local function
  declarations that are never referenced, specifically private top-level
  functions in libraries that have no `part` files and local function
  declarations inside another function or method body. Diagnostics are emitted
  at `Severity.warning`. The rule is registered by the built-in CLI and enabled
  automatically. Running `dart run anal` against a project that previously
  produced no diagnostics may now surface new warnings from this rule.
- Open-source project guidance, issue templates, pull request checklist,
  security policy, code of conduct, and Dependabot configuration.
- Coverage artifact upload to CI.
- `.pubignore` to keep automation and assistant-only files out of the published
  package archive.
- `.gitattributes` for predictable text file line endings.

### Changed

- Updated CI and release automation to target the repository default branch.
- Tightened package metadata for pub.dev discovery.

### Fixed

- Fixed directory include discovery on Windows.

### Changed

- Default exclude patterns now include `*.g.dart` and `*.freezed.dart`.
  Pass an empty `excludePaths` (or `--no-default-excludes` on the CLI)
  to opt out.
- `--exclude` now layers on top of the default excludes instead of
  replacing them. Patterns you pass are added to the built-in defaults;
  use `--no-default-excludes` if you need to suppress the defaults.

## 0.1.0

- Added a pluggable static-analysis framework for Dart and Flutter projects:
  - `AnalyzerRule`: abstract plugin contract for custom rules.
  - `Diagnostic`, `Severity`, `SourceLocation`: value types describing
    analysis findings.
  - `AnalysisContext`: carrier passed into each rule invocation, exposing the
    resolved compilation unit.
  - `RuleRegistry`: in-memory registration and lookup of rules, with
    duplicate-id rejection.
  - `AnalysisRunner`: orchestrator that resolves target files, dispatches
    rules, and collects diagnostics.
  - `AnalOptions`: value class describing include/exclude paths and enabled
    rule ids.
  - `Reporter` / `ConsoleReporter`: pluggable diagnostic output, with a stdout
    implementation.
  - CLI executable `anal` (`dart run anal`) with `--help`, `--version`,
    `--rules`, and `--exclude` flags.

### BREAKING CHANGE

- Removed the `Calculator` stub that shipped in `0.0.1`. Consumers that
  depended on it must remove the import; it was a generator placeholder and
  not part of any intended public API.

## 0.0.1

- Initial package scaffold.
