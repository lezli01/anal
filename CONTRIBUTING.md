# Contributing

Thanks for taking the time to improve `anal`.

## Development Setup

This repository uses FVM so local checks match CI.

```sh
fvm install
fvm flutter pub get
```

## Quality Checks

Run these before opening a pull request:

```sh
fvm dart format .
fvm dart analyze --fatal-infos --fatal-warnings
fvm flutter test --coverage
fvm dart pub publish --dry-run
```

The package should lint cleanly with zero warnings, hints, or infos.

## Pull Requests

- Keep changes focused on one behavior or documentation improvement.
- Add or update tests for behavior changes.
- Update `README.md` and `CHANGELOG.md` for user-visible changes.
- Use Conventional Commit style for commit messages, such as
  `fix(cli): handle empty rule list`.

## Public API Changes

Anything exported from `lib/anal.dart` is public API. New public APIs need
dartdoc comments and tests. Breaking changes require a clear changelog note
and should be avoided while a smaller compatible change can solve the problem.
