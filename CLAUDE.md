# CLAUDE.md

Guidance for Claude Code (and other AI assistants) when working in this repository.

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

## Open Source Hygiene

- Be welcoming in issues and PRs.
- Never commit secrets, tokens, or personal paths.
- Attribute third-party code and respect their licenses.
- Keep documentation accurate — outdated docs are a bug.

## Quick Pre-Commit Checklist

- [ ] `fvm dart format .` — clean
- [ ] `fvm dart analyze` — zero issues
- [ ] `fvm flutter test` — all green
- [ ] CHANGELOG updated (if user-visible)
- [ ] README updated (if behavior, API, or bundled rules changed)
- [ ] Commit message follows Conventional Commits
