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
- New default-on `unused_class` rule. It flags file-local declarations
  that are never referenced within the same compilation unit, covering
  `class`, `mixin`, `enum`, and `extension type` declarations whose names
  begin with `_`. The rule only runs against libraries that have no
  `part` files and skips declarations annotated with
  `@pragma('vm:entry-point')`. Diagnostics are emitted at
  `Severity.warning`. The rule is registered by the built-in CLI and
  enabled automatically. Running `dart run anal` against a project that
  previously produced no diagnostics may now surface new warnings from
  this rule.
- Open-source project guidance, issue templates, pull request checklist,
  security policy, code of conduct, and Dependabot configuration.
- Coverage artifact upload to CI.
- `.pubignore` to keep automation and assistant-only files out of the published
  package archive.
- `.gitattributes` for predictable text file line endings.

### Changed

- Updated CI and release automation to target the repository default branch.
- Tightened package metadata for pub.dev discovery.
- Widened the analyzer dependency to `>=9.0.0 <13.0.0` so projects using
  `freezed >=3.2.5` can add `anal` without a version-solver conflict.

### Fixed

- Fixed directory include discovery on Windows.
- `anal` is now installable alongside `freezed ^3.2.5`.

### Changed

- Default exclude patterns now include `*.g.dart` and `*.freezed.dart`.
  Pass an empty `excludePaths` (or `--no-default-excludes` on the CLI)
  to opt out.
- `--exclude` now layers on top of the default excludes instead of
  replacing them. Patterns you pass are added to the built-in defaults;
  use `--no-default-excludes` if you need to suppress the defaults.

## [0.2.0](https://github.com/lezli01/anal/compare/v0.1.0...v0.2.0) (2026-05-27)


### ⚠ BREAKING CHANGES

* **api:** Calculator is removed from the public API.

### Features

* add Severity, SourceLocation, Diagnostic value types ([0b965cd](https://github.com/lezli01/anal/commit/0b965cdc42f24f356aec89bc32f0ad3f91c08c46))
* **api:** re-export public surface from lib/anal.dart ([4cef459](https://github.com/lezli01/anal/commit/4cef4595278018e6990da490b7b568ab720c686e))
* **cli:** add bin/anal.dart CLI entry point ([ae0fa3b](https://github.com/lezli01/anal/commit/ae0fa3b5939055b3352b5f846ce05e06f94bc29e))
* frame basics ([44c400e](https://github.com/lezli01/anal/commit/44c400e1b08acefa6be90fbb1cf888358f6c5030))
* **options:** add AnalOptions value class ([2c0cb6c](https://github.com/lezli01/anal/commit/2c0cb6c0f80198800620a68d803095829b6a3c4d))
* **reporter:** add Reporter abstraction and ConsoleReporter ([85e556d](https://github.com/lezli01/anal/commit/85e556d7aec029d4e9b4c45095b3a02e2a2bc664))
* **rules:** add AnalyzerRule contract, AnalysisContext, RuleRegistry ([0e45827](https://github.com/lezli01/anal/commit/0e458273cb04a7d653ab3579d0f6aa01d6d1303d))
* **rules:** add unused_class rule ([4adcd8e](https://github.com/lezli01/anal/commit/4adcd8ee761094d837c49a31d08b067548c11677))
* **rules:** add unused_function rule ([84e9528](https://github.com/lezli01/anal/commit/84e95287cb5b408bf849fdbaf1c79836bcbc568f))
* **rules:** register unused_function rule in CLI ([2ea76c1](https://github.com/lezli01/anal/commit/2ea76c1950a1bb388ab4fe9ec35287479998d83f))
* **runner:** add AnalysisRunner orchestrator and smoke test ([b721079](https://github.com/lezli01/anal/commit/b721079ef8157570d3efc260013be8d20aa75e85))

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
