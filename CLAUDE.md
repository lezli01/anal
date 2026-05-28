# CLAUDE.md

Guidance for Claude Code (and other AI assistants) when working in this repository.

Check @LANGUAGE.md for Dart specific knowledge.

## Project Overview

`anal` is an **open-source Dart / Flutter package** providing **static code analysis** tooling. It is intended to be consumed by other Dart and Flutter projects (typically as a `dev_dependency`) to enforce code quality, lint rules, and analyzer configuration.

- **Language:** Dart (Flutter package)
- **Package name:** `anal`
- **Entry point:** [lib/anal.dart](lib/anal.dart)
- **Tests:** [test/anal_test.dart](test/anal_test.dart)
- **License:** See [LICENSE](LICENSE) (open source)
- **Changelog:** [CHANGELOG.md](CHANGELOG.md)

Because this package is about *static analysis*, special care must be taken so that the package itself is exemplary: it must lint cleanly, follow Effective Dart, and never ship analyzer rules it does not itself pass.

## Toolchain

This project uses **[FVM](https://fvm.app/) (Flutter Version Management)** to pin the Flutter / Dart SDK. Always run Flutter and Dart commands through `fvm` so the version matches what CI and other contributors use.

- Install / sync the pinned SDK: `fvm install` then `fvm use`
- Pinned version is recorded in `.fvmrc` / `.fvm/` (do not commit unrelated changes there).
- The Dart SDK constraint is declared in [pubspec.yaml](pubspec.yaml) (`environment.sdk`).

### Common commands

Always prefix with `fvm`:

```sh
fvm flutter pub get          # install dependencies
fvm dart analyze             # run the analyzer (must be clean)
fvm dart format .            # format code (must be a no-op in CI)
fvm flutter test             # run the test suite
fvm dart pub publish --dry-run   # validate before publishing
```

Do **not** invoke bare `flutter` / `dart` in instructions or scripts unless explicitly intended to use the system SDK.

## Repository Layout

```
lib/          Public API of the package. Anything exported here is part of the
              package's stable surface.
test/         Unit tests. Mirror the structure of lib/.
analysis_options.yaml   Analyzer + lint configuration this package uses on itself.
pubspec.yaml  Package metadata, SDK constraints, dependencies.
CHANGELOG.md  Human-readable change history (keep in sync with versions).
README.md     User-facing documentation.
```

## Coding Conventions

- Follow **[Effective Dart](https://dart.dev/effective-dart)** (style, documentation, usage, design).
- Public APIs (anything in `lib/` not under `lib/src/`) **must have dartdoc comments** (`///`).
- Keep implementation details under `lib/src/` and only re-export the intended public surface from `lib/anal.dart`.
- Code must pass `fvm dart analyze` with **zero warnings, hints, or infos**. Treat analyzer output as errors.
- Code must be formatted with `fvm dart format .` (88-col default).
- Prefer `final` and `const` wherever possible. Avoid mutable top-level / static state.
- Avoid adding runtime dependencies unless strictly necessary; this is an analysis-focused package.
- When adding or changing lint rules in [analysis_options.yaml](analysis_options.yaml), update the README and CHANGELOG, and ensure the package's own sources still pass.

## Testing

- Tests live in `test/` and use `package:flutter_test` / `package:test`.
- **Always write unit tests for new code.** No new function, class, or branch should land without accompanying tests. If code is genuinely untestable, refactor it until it is.
- Every bug fix **must** add a regression test that fails without the fix and passes with it.
- Every new public API needs at minimum:
  - a happy-path test,
  - tests for each documented edge case and error condition,
  - tests for boundary values (empty, null where allowed, min/max, unicode, etc.).
- **Aim for the highest practical coverage of real use cases**, not just line coverage. Prefer tests that exercise observable behavior and invariants over tests that mirror the implementation.
- Cover both positive and negative paths: invalid input, thrown exceptions, async failures, and cancellation where applicable.
- Mirror the structure of `lib/` inside `test/` (e.g. `lib/src/foo.dart` → `test/src/foo_test.dart`) and group related cases with `group(...)`.
- Keep tests deterministic and hermetic — no network, no real filesystem outside `Directory.systemTemp`, no reliance on wall-clock time. Use fakes/mocks for I/O.
- Run the full suite with `fvm flutter test` before committing. A PR with failing or missing tests should not be merged.
- When practical, also run `fvm flutter test --coverage` and inspect `coverage/lcov.info` to confirm new code is exercised; do not lower overall coverage.

## Sample Projects

The [samples/](samples/) directory contains **one self-contained sample
project per built-in rule shipped under [lib/src/rules/](lib/src/rules/),
plus an `all_rules` sample** that exercises every built-in rule together.
Each sample is a real `pub get`-resolved Dart/Flutter package that
path-depends on the root `anal` package and whose `README.md` documents
the exact positive (MUST be flagged) and negative (MUST NOT be flagged)
cases for the rule it covers.

Current samples (one per rule + the combined sample):

- [samples/unused_function/](samples/unused_function/) — exercises `unused_function`.
- [samples/unused_class/](samples/unused_class/) — exercises `unused_class`.
- [samples/unused_source_file/](samples/unused_source_file/) — exercises `unused_source_file`.
- [samples/all_rules/](samples/all_rules/) — exercises every built-in rule together.

**This set is a HARD MAINTENANCE REQUIREMENT.** Whenever a built-in rule
under [lib/src/rules/](lib/src/rules/) is added, removed, or renamed, in
the **same commit**:

- A matching `samples/<rule_id>/` project MUST be added, removed, or
  renamed so the per-rule sample tracks the rule.
- The combined [samples/all_rules/](samples/all_rules/) sample MUST be
  updated — add, remove, or re-tag positive/negative cases — so it
  continues to exercise every shipped rule.
- [test/samples_test.dart](test/samples_test.dart) MUST be updated to
  reflect the new expected diagnostics, so the samples remain
  executable documentation verified by the test suite.
- Each affected sample's `README.md` (positive/negative tables and
  "expected output" block) MUST be brought back in sync with the
  rule's actual behavior.

A rule change that does not update its sample, the `all_rules` sample,
and `test/samples_test.dart` is incomplete and must not land.

## Commits — Conventional Commits

This repository uses **[Conventional Commits](https://www.conventionalcommits.org/)**. Every commit message must follow:

```
<type>(<optional scope>): <short summary>

<optional body>

<optional footer(s)>
```

Allowed `type` values (use the lowercase form):

- `feat` — a new feature (bumps MINOR)
- `fix` — a bug fix (bumps PATCH)
- `docs` — documentation only
- `style` — formatting, missing semicolons, etc.; no code change
- `refactor` — code change that neither fixes a bug nor adds a feature
- `perf` — performance improvement
- `test` — adding or fixing tests
- `build` — build system or external dependency changes (e.g. `pubspec.yaml`)
- `ci` — CI configuration changes
- `chore` — other changes that don't modify `lib/` or `test/`
- `revert` — reverts a previous commit

Rules:

- **Breaking changes:** append `!` after the type/scope (`feat!: …`) **and** include a `BREAKING CHANGE:` footer describing the migration. Pre-1.0.0, breaking changes still bump MINOR per Dart pub conventions, but must be clearly called out in the CHANGELOG.
- Summary line: imperative mood, no trailing period, ≤ 72 chars.
- Reference issues in the footer: `Refs: #123`, `Closes: #123`.
- One logical change per commit. Do not mix refactors with feature work.

### Example

```
feat(lints): add prefer_const_constructors_in_immutables rule

Enables the rule in the bundled analysis_options.yaml and documents
it in the README.

Closes: #42
```

## README

- **Always keep [README.md](README.md) up to date** with the current behavior of the package. The README is the primary entry point for consumers on pub.dev and GitHub; outdated docs are a bug.
- Update the README in the **same commit** as the code change that affects it — never as a separate "update docs" commit.
- Update the README whenever you:
  - add, remove, or rename a public API,
  - add, remove, or change a bundled lint rule in [analysis_options.yaml](analysis_options.yaml),
  - change installation, setup, or usage instructions,
  - change supported SDK / Flutter versions,
  - change the package's stated scope, goals, or recommended configuration.
- Keep examples runnable and accurate: code snippets must compile against the current public API and reflect the recommended usage.
- Keep the feature list, rule list, and any tables in sync with what the package actually ships — do not advertise rules or APIs that are not present.
- Cross-check the README against [CHANGELOG.md](CHANGELOG.md) when releasing: every user-visible change since the last release should be reflected in both.
- Purely internal changes (refactors, CI tweaks, test-only changes) do not require a README update.

## Changelog

[CHANGELOG.md](CHANGELOG.md) is generated and maintained by **release-please** ([.github/workflows/release-please.yml](.github/workflows/release-please.yml)) from Conventional Commit messages. **Do not hand-edit the changelog for in-flight work.**

- The commit message *is* the changelog entry. Write it from the consumer's perspective — describe what changed for users of the package, not the internal implementation.
- Only `feat:` and `fix:` (and `!`/`BREAKING CHANGE:` footers) produce changelog entries by default. Other types (`docs`, `chore`, `ci`, `refactor`, `test`, `build`, `style`, `perf`, `revert`) are intentionally excluded.
- A "release PR" opened by release-please collects the pending entries into the next `## [X.Y.Z]` section, bumps `version:` in [pubspec.yaml](pubspec.yaml), and bumps the `_version` marker in [bin/anal.dart](bin/anal.dart) via the `x-release-please-version` comment. Merging that PR cuts the release.
- Hand-editing past `## [X.Y.Z]` sections is fine for prose / typo fixes, but never re-version, re-date, or remove a published entry — correct mistakes by adding a follow-up entry in a later release.
- Do **not** add a manual `## [Unreleased]` section. Past content is folded into the most recent release; new content arrives via the next release PR.

## Versioning & Releases

- Follows **[Semantic Versioning](https://semver.org/)** as adapted by `pub.dev`. Version bumps are driven by release-please: `feat:` → MINOR (pre-1.0 per `bump-minor-pre-major`), `fix:` → PATCH (pre-1.0 per `bump-patch-for-minor-pre-major`), `!` / `BREAKING CHANGE:` → MINOR pre-1.0 / MAJOR post-1.0.
- Releases are fully automated end-to-end:
  1. Push a Conventional Commit to `master`.
  2. release-please opens or updates the release PR — review CHANGELOG + version bumps there.
  3. Merging the release PR creates the GitHub release and `vX.Y.Z` tag.
  4. The release-please workflow dispatches [publish.yml](.github/workflows/publish.yml) against the new tag, which publishes to pub.dev via OIDC.
- Do **not** manually bump `version:` in [pubspec.yaml](pubspec.yaml) or `_version` in [bin/anal.dart](bin/anal.dart) — the release PR does it. The `// x-release-please-version` comment in `bin/anal.dart` and the `extra-files` block in [release-please-config.json](release-please-config.json) keep them in sync.
- Validate locally with `fvm dart pub publish --dry-run` before merging the release PR if you want a final check.
- Tag releases as `vX.Y.Z` matching the pubspec version.

## Things to Watch Out For

1. **Don't ship lint rules the package itself fails.** After editing `analysis_options.yaml`, always re-run `fvm dart analyze` on this repo.
2. **Don't add Flutter-only dependencies if the feature could be pure Dart.** Keep the consumer surface minimal.
3. **Don't bypass FVM** — using a different SDK can produce analyzer output that disagrees with CI.
4. **Don't commit generated files** unless explicitly part of the package contract.
5. **Don't break the public API** without a `!` commit + CHANGELOG `BREAKING CHANGE` entry.
6. **Don't edit `CHANGELOG.md` retroactively** for already-published versions; add a new entry instead.
7. **Don't add license headers per file** unless the project policy changes — the root [LICENSE](LICENSE) covers the package.
8. **Be mindful of `pubspec.yaml` fields** required by pub.dev for scoring: `description` (60–180 chars), `homepage`/`repository`, `version`, `environment`. The current `description` is a placeholder and should be improved before publishing.
9. **Keep the CLI `_version` constant in sync with `pubspec.yaml`.** [bin/anal.dart](bin/anal.dart) hardcodes a `_version` string used by `dart run anal --version`. Whenever `version:` in [pubspec.yaml](pubspec.yaml) changes (release commits, release-please PRs), update `_version` in the same commit, or `--version` will report a stale value.

## Dart Language Features Rules Must Be Aware Of

Any rule that touches **references**, **reachability**, or **exemptions** — today that is
[`unused_function`](lib/src/rules/unused_function_rule.dart),
[`unused_class`](lib/src/rules/unused_class_rule.dart), and
[`unused_source_file`](lib/src/rules/unused_source_file_rule.dart) — must
correctly account for the following Dart language features. Each entry
notes the trap and the expected handling. When adding a new reachability
rule, walk this list before opening a PR.

- **Conditional imports/exports** (`import 'x.dart' if (dart.library.io) 'x_io.dart';`):
  every branch is a real reference. Treat *all* candidate URIs as
  reachable; do not pick one and call the others unused.
- **`part` / `part of`**: a `part` file is not standalone — its top-level
  members belong to the parent library. Never flag a `part` file via
  `unused_source_file`, and resolve references through the parent
  library, not the part file in isolation.
- **Extension methods** (`extension Foo on Bar { … }`): calls look like
  member access on `Bar`. A reference to the extended member keeps the
  *extension declaration* alive even when the extension itself is never
  named; treat the extension as reachable whenever any of its members
  is invoked or torn off.
- **Extension types** (`extension type Id(int v) { … }`): a zero-cost
  wrapper that introduces a new static type. Constructor calls and
  member access count as references to the extension type; do not
  collapse them into references to the representation type.
- **Dynamic dispatch** (`dynamic`/`Object?` receivers): the static
  analyzer cannot prove which member is invoked. Be conservative:
  unresolved dynamic invocations must not be assumed dead, and rules
  should err toward keeping plausibly-targeted members reachable rather
  than reporting false positives.
- **`noSuchMethod`**: a class overriding `noSuchMethod` can service any
  selector at runtime. Members reached only through such a class may
  have no static references; do not flag members of a type whose
  supertype overrides `noSuchMethod`, and treat the override itself as
  a reachability sink.
- **Mirrors / reflection / entry-point annotations** (`dart:mirrors`,
  `@pragma('vm:entry-point')`, `@JS`, `@Native`, build-time codegen
  annotations): these keep symbols alive without any static reference.
  Exempt symbols carrying such annotations from `unused_function` /
  `unused_class`, and document the exemption set in the rule.
- **Tearoffs and callable objects** (`list.map(parse)`, `Foo.new`,
  classes with a `call` method): a bare identifier or `Type.new` *is* a
  reference to the function/constructor. Count tearoffs as uses, and
  treat invocation of an instance with a `call` method as a use of that
  method.
- **Pattern matching** (`switch` expressions, object/record patterns,
  destructuring `var (a, b) = …;`): object patterns reference
  constructors and getters by name, and record patterns reference
  positional/named fields. Each named element in a pattern is a use of
  the corresponding declaration.
- **Class modifiers** (`sealed`, `base`, `interface`, `final`, `mixin
  class`): subtypes of a `sealed` supertype are reachable via
  exhaustiveness in `switch`, even if no code names them directly. Do
  not flag subtypes of a sealed type as unused solely because they
  lack explicit references; check for an exhaustive switch on the
  supertype.
- **Generic covariance and inference**: inferred type arguments still
  resolve to declared members. Follow the *declared* member on the
  *static* type — do not require explicit type arguments to consider a
  generic member referenced.
- **Deferred imports** (`import 'x.dart' deferred as x; await
  x.loadLibrary();`): deferred symbols are still referenced, just
  lazily loaded. Treat `loadLibrary()` calls and prefixed accesses as
  ordinary uses; do not mark deferred libraries as unused.
- **Const evaluation**: `const` constructor invocations, `const`
  collection literals with named types, and constants embedded in
  annotations all count as references. Walk into annotation arguments
  and const-context expressions when collecting references.
- **Environment declarations** (`bool.fromEnvironment`,
  `int.fromEnvironment`, `String.fromEnvironment`,
  `bool.hasEnvironment`): values are supplied at build time via
  `--define`. Rules cannot statically evaluate the result; do not prune
  branches gated on `fromEnvironment` as unreachable.
- **Mixins** (`with Foo, Bar`): a `with` clause references the mixin
  declaration *and* keeps its members reachable on the mixing type.
  Track `with` as a use of the mixin and, when computing member
  reachability, include mixed-in members in the surface of each
  applying class.
- **Operator overloading** (`operator +`, `operator []`, `operator
  ==`, …): infix/prefix/index syntax dispatches to a named member.
  Map operator tokens back to their canonical member name (`+`, `[]`,
  `==`, `unary-`, etc.) when recording references.
- **Cascade operator** (`obj..foo()..bar`): each section is a normal
  invocation or member access on the receiver. Recurse into cascade
  sections exactly as you would into chained member accesses.
- **Records and destructuring** (`(int, String) pair = (1, 'a'); var
  (n, s) = pair; pair.$1; pair.name`): positional fields (`$1`, `$2`,
  …) and named fields are real members of the record's structural
  type. Record patterns destructure them by position or name; count
  each destructured component as a use of the corresponding field, and
  do not flag records or their fields as unused based on syntactic
  search alone.

## Open Source Hygiene

- Be welcoming in issues and PRs.
- Never commit secrets, tokens, or personal paths.
- Attribute third-party code and respect their licenses.
- Keep documentation accurate — outdated docs are a bug.

## Post-Implementation Verification

After any implementation — rule changes, new rules, sample updates, or analysis runner changes — run the `anal-probe` skill to confirm all sample projects still emit exactly the expected diagnostics and nothing broke:

```
/anal-probe
```

This runs `anal` directly on every sample under `samples/` and compares findings against the fixture in `test/samples_test.dart`. It catches unexpected extra findings, missing expected findings, and `_internal` errors that indicate rule bugs.

## Quick Pre-Commit Checklist

- [ ] `fvm dart format .` — clean
- [ ] `fvm dart analyze` — zero issues
- [ ] `fvm flutter test` — all green
- [ ] `/anal-probe` — all samples pass
- [ ] CHANGELOG updated (if user-visible)
- [ ] README updated (if behavior, API, or bundled rules changed)
- [ ] `samples/` and `test/samples_test.dart` updated for any rule changes
- [ ] Commit message follows Conventional Commits
