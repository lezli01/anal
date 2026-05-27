# unused_source_file sample

A small Dart package that exists solely to exercise the
[`unused_source_file`](../../lib/src/rules/unused_source_file_rule.dart)
multi-file rule shipped by the [`anal`](../../) package.

## Layout

```
samples/unused_source_file/
  bin/
    main.dart              # bin/ entry point — always reachable
  lib/
    unused_source_file_sample.dart  # lib/<package>.dart — entry point
    src/
      used.dart            # imported by the entry point (reachable)
      used_via_part.dart   # part of used.dart (reachable transitively)
      orphan.dart          # never imported (UNREACHABLE — must trigger)
  pubspec.yaml             # path-dependent on ../.. (the root anal package)
```

| File                              | Expected `unused_source_file` |
| --------------------------------- | ----------------------------- |
| `bin/main.dart`                   | not flagged (bin entry point) |
| `lib/unused_source_file_sample.dart` | not flagged (lib entry point) |
| `lib/src/used.dart`               | not flagged (imported)        |
| `lib/src/used_via_part.dart`      | not flagged (`part` of used)  |
| `lib/src/orphan.dart`             | **flagged**                   |

## Running

From the repository root:

```sh
fvm flutter pub get -C samples/unused_source_file
fvm dart run anal samples/unused_source_file
```

The expected output is a single `unused_source_file` diagnostic pointing at
`samples/unused_source_file/lib/src/orphan.dart`.
