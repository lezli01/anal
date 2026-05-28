# Changelog

## [0.3.6](https://github.com/lezli01/anal/compare/v0.3.5...v0.3.6) (2026-05-28)


### Features

* function analysis enhanced ([#26](https://github.com/lezli01/anal/issues/26)) ([b0538b9](https://github.com/lezli01/anal/commit/b0538b963ddc65d4e5eb565d578e4673fa369957))
* **unused_function:** normalise generic member identity in reference tracking ([c19c502](https://github.com/lezli01/anal/commit/c19c5024ed8a87e5cda64859d751f78b2df7e2f6))
* **unused_function:** record enum-value declarations as uses of the enum constructor ([b592b78](https://github.com/lezli01/anal/commit/b592b78e4a2816b381c86d88c828b516e57a7bfa))
* **unused_function:** record implicit super-constructor invocation as a use ([ee2a5c1](https://github.com/lezli01/anal/commit/ee2a5c16d6a760f9c3b8a68d77063f55a8701d22))
* **unused_function:** treat overrides of reachable supertype members as uses ([c9f3c0e](https://github.com/lezli01/anal/commit/c9f3c0eabc2e20b35cfc9f5e44fcf0b3b32179e2))
* **unused_function:** walk supertype chain for noSuchMethod exemption ([a85e7e2](https://github.com/lezli01/anal/commit/a85e7e22e79a5ab0e0c9216ba14bacbe7b262c36))


### Bug Fixes

* **unused_function:** exempt flutter gen-l10n generated localization output ([0c06c1f](https://github.com/lezli01/anal/commit/0c06c1f3b1b1d5af5b21d3cb10465ec16477c710))

## [0.3.5](https://github.com/lezli01/anal/compare/v0.3.4...v0.3.5) (2026-05-28)


### Features

* dart awareness ([#24](https://github.com/lezli01/anal/issues/24)) ([a966836](https://github.com/lezli01/anal/commit/a966836093fb7cb22c79a3edb9b083c699183a01))
* **unused_class:** make rule Dart 3 feature-aware ([bc6c086](https://github.com/lezli01/anal/commit/bc6c0862b6ef457aba822b8a8fa79b3674e899dc))
* **unused_function:** make rule feature-aware ([0ac7537](https://github.com/lezli01/anal/commit/0ac75377812a95d691ff0c49583ec6ebd3f44b0e))
* **unused_source_file:** follow conditional and deferred import edges ([7e1bc72](https://github.com/lezli01/anal/commit/7e1bc72cdf70f03baed0a8c84b23419310a5970f))
* updated sample ([#21](https://github.com/lezli01/anal/issues/21)) ([9d3e5b2](https://github.com/lezli01/anal/commit/9d3e5b26d4bf66992e410ce73b778d0b3ac44f59))


### Bug Fixes

* **unused_source_file:** follow conditional-URI branches when computing reachability ([f7c1bb1](https://github.com/lezli01/anal/commit/f7c1bb1aed0ace91c991677cdc1694e1d4f4bcd9))
* **unused_source_file:** follow conditional-URI branches when computing reachability ([#23](https://github.com/lezli01/anal/issues/23)) ([ff720f2](https://github.com/lezli01/anal/commit/ff720f2fe262986b816d8e5b0363afde05a8114e))

## [0.3.4](https://github.com/lezli01/anal/compare/v0.3.3...v0.3.4) (2026-05-27)


### Features

* sample projects ([#17](https://github.com/lezli01/anal/issues/17)) ([f120a92](https://github.com/lezli01/anal/commit/f120a9202eaff9ba57670cf5011560a27f71844d))
* **samples:** add unused_source_file sample project ([af01ba7](https://github.com/lezli01/anal/commit/af01ba7b58df7aeb4a8158ff2b4d79f5d35effee))
* unused functions ([#20](https://github.com/lezli01/anal/issues/20)) ([9f79e99](https://github.com/lezli01/anal/commit/9f79e99d63d30dd66eb2c153ba803d4a98d2a781))
* **unused_function:** add collector for class, mixin, enum, and extension-type members ([c5574f2](https://github.com/lezli01/anal/commit/c5574f2cc28a19de806deb0285987667fd5ba974))
* **unused_function:** add collector for extension declaration members ([ffa728a](https://github.com/lezli01/anal/commit/ffa728a11b4060ddad51278d9e5c4a532a56827f))
* **unused_function:** add collector for top-level getters and setters ([3d4d3e7](https://github.com/lezli01/anal/commit/3d4d3e7684c7f1836694213d3baddd6c751e8679))
* **unused_function:** flag unreferenced public top-level functions in lib/src/ ([07703ce](https://github.com/lezli01/anal/commit/07703ce73bc72073b9c0440e2b0f8934ff5748f9))


### Bug Fixes

* analysis ([ff4cf8c](https://github.com/lezli01/anal/commit/ff4cf8c83bd4078e4e5d5d56d1278f32e206ff55))

## [0.3.3](https://github.com/lezli01/anal/compare/v0.3.2...v0.3.3) (2026-05-27)


### Bug Fixes

* added nuances ([35937b3](https://github.com/lezli01/anal/commit/35937b36ea4f90c7f05157e9af2cfcd69ce65dd3))
* **rules:** avoid UnsupportedError on namePart in unused_class ([7c8acc8](https://github.com/lezli01/anal/commit/7c8acc84078e19dd41b893fec836766a93283a46))

## [0.3.2](https://github.com/lezli01/anal/compare/v0.3.1...v0.3.2) (2026-05-27)


### Bug Fixes

* removed invalid version ([67cdcac](https://github.com/lezli01/anal/commit/67cdcac96f426a118632a60e8698a54d414e557a))

## [0.3.1](https://github.com/lezli01/anal/compare/v0.3.0...v0.3.1) (2026-05-27)


### Continuous Integration

* **release:** wire bin/anal.dart into release-please and trigger 0.3.1 ([e544060](https://github.com/lezli01/anal/commit/e5440600d4531b193e30faa28c85c681d8b98c04))

## [0.3.0](https://github.com/lezli01/anal/compare/v0.2.0...v0.3.0) (2026-05-27)

### Added

- New default-on `unused_source_file` rule. It flags Dart source files in
  the analyzed set that are never reached from any entry point via an
  `import`, `export`, or `part` directive. Entry points are files under
  `bin/` or `test/`, files that declare a top-level `main`, and
  `lib/<package>.dart` plus any other file sitting directly under
  `lib/` (i.e. not nested inside `lib/src/`). Generated-file basenames
  such as `*.g.dart` and `*.freezed.dart` are skipped defensively even
  when the runner's default excludes are turned off. Diagnostics are
  emitted at `Severity.warning`. The rule is registered by the built-in
  CLI and enabled automatically. Running `dart run anal` against a
  project that previously produced no diagnostics may now surface new
  warnings from this rule.
- New `MultiFileAnalyzerRule` extension point for custom rules that need
  to reason across multiple files in a single invocation (for example to
  build an import graph or a cross-file symbol index). Multi-file rules
  are registered with the same `RuleRegistry` as `AnalyzerRule`
  implementations and are dispatched once per run with the full set of
  resolved compilation units. Existing `AnalyzerRule` implementations
  continue to be dispatched once per file and do not need any changes.
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
- Default exclude patterns now include `*.g.dart` and `*.freezed.dart`.
  Pass an empty `excludePaths` (or `--no-default-excludes` on the CLI)
  to opt out.
- `--exclude` now layers on top of the default excludes instead of
  replacing them. Patterns you pass are added to the built-in defaults;
  use `--no-default-excludes` if you need to suppress the defaults.

### Fixed

- Fixed directory include discovery on Windows.
- `anal` is now installable alongside `freezed ^3.2.5`.
- `dart run anal --version` now prints the correct package version
  instead of the stale hardcoded `0.1.0`.
- Restored analyzer 9.0.0 compatibility for the `unused_class` rule.
  The rule previously reached into `ExtensionTypeDeclaration.primaryConstructor`,
  which only exists in analyzer 10+, causing a build break for consumers
  pinned to analyzer 9.0.0 (`'primaryConstructor' isn't defined for the type
  'ExtensionTypeDeclaration'`). The rule now uses the cross-version
  `ExtensionTypeDeclaration.name` accessor.
- `unused_class` no longer crashes on analyzer 9.x/10.x. The rule
  previously read `ClassDeclaration.namePart` and
  `EnumDeclaration.namePart`, which require the default-off experimental
  flag `useDeclaringConstructorsAst = true` and otherwise throw
  `UnsupportedError`, surfacing as
  `Rule unused_class threw during analysis: ...`. The rule now uses the
  always-available `name` token on both nodes.

### Commits

* feat: fixing version handling ([3460776](https://github.com/lezli01/anal/commit/34607762c6cdf11b87522b85a40f3884d060c13d))
* fix: fixed ci ([30aa5b6](https://github.com/lezli01/anal/commit/30aa5b67a1f33fc18d3a0918d9fef6203fdd1497))
* fix: refreshed readme ([391d527](https://github.com/lezli01/anal/commit/391d527d6a51af8f97630b32a09a5342da82e2a4))

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
