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
      mobile_impl.dart     # default branch of a conditional export (reachable)
      web_impl.dart        # `dart.library.html` branch of the same conditional
                           # export (reachable on every platform — both
                           # branches are walked)
      conditional_hub.dart # imported by the entry point; hosts conditional
                           # and deferred imports
      _io_impl.dart        # reached via `if (dart.library.io)` configuration
      _web_impl.dart       # reached via `if (dart.library.html)` configuration
      deferred_target.dart # reached via `import ... deferred as ...`
      orphan.dart          # never imported (UNREACHABLE — must trigger)
  pubspec.yaml             # path-dependent on ../.. (the root anal package)
```

| File                                       | Expected `unused_source_file`                                       |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `bin/main.dart`                            | not flagged (bin entry point)                                       |
| `lib/unused_source_file_sample.dart`       | not flagged (lib entry point)                                       |
| `lib/src/used.dart`                        | not flagged (imported)                                              |
| `lib/src/used_via_part.dart`               | not flagged (`part` of used)                                        |
| `lib/src/mobile_impl.dart`                 | not flagged (default branch of the conditional export)              |
| `lib/src/web_impl.dart`                    | not flagged (`dart.library.html` branch of the conditional export)  |
| `lib/src/conditional_hub.dart`             | not flagged (imported by the entry point)                           |
| `lib/src/_io_impl.dart`                    | not flagged (reached via `if (dart.library.io)` configuration)      |
| `lib/src/_web_impl.dart`                   | not flagged (reached via `if (dart.library.html)` configuration)    |
| `lib/src/deferred_target.dart`             | not flagged (reached via deferred import)                           |
| `lib/src/orphan.dart`                      | **flagged**                                                         |

The `_io_impl.dart` and `_web_impl.dart` cases pin the rule's behavior for
conditional imports: every `if (...)` configuration on an `ImportDirective`
or `ExportDirective` contributes a reachability edge regardless of the
active platform, so both alternatives stay reachable in a single analysis
run. `deferred_target.dart` pins the same for deferred imports — they are
followed identically to ordinary imports. `mobile_impl.dart` and
`web_impl.dart` exercise the same conditional-URI logic via an
`ExportDirective`.

## Running

From the repository root:

```sh
fvm flutter pub get -C samples/unused_source_file
fvm dart run anal samples/unused_source_file
```

The expected output is a single `unused_source_file` diagnostic pointing at
`samples/unused_source_file/lib/src/orphan.dart`.
