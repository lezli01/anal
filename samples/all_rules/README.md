# `all_rules` sample

A self-contained Dart/Flutter package that exercises **every** built-in rule
shipped by the [`anal`](../..) package in a single project, with the same
breadth of positive and negative cases that each per-rule sample covers.

The sample exists so consumers (and the rules' own contributors) can see all
three rules co-firing on a real `pub get`-resolved tree, and so the reporter's
output for a mixed run is easy to eyeball.

## Layout

```
samples/all_rules/
  pubspec.yaml                       # path-dependent on the root `anal` package
  bin/
    main.dart                        # bin/ entry point — always reachable
  lib/
    all_rules_sample.dart            # lib/<package>.dart entry point
    unused_function_demo.dart        # positive + negative cases for unused_function
    unused_class_demo.dart           # positive + negative cases for unused_class
    src/
      internals.dart                 # public-top-level positive for unused_function
                                     # (`lib/src/` is the package's internal surface)
      mirrors_user.dart              # `dart:mirrors`-importing companion — every
                                     # member declared here is exempt from
                                     # unused_function under the mirrors assumption
      l10n/
        l10n.dart                    # synthetic `flutter gen-l10n` output — every
        l10n_en.dart                 # candidate in either unit is exempt from
                                     # unused_function because the top of each
                                     # file carries the `// ignore_for_file:
                                     # type=lint` generated-code marker
      used.dart                      # library that declares `part 'used_via_part.dart';`
                                     # and is imported by the entry — reachable
      used_via_part.dart             # `part of 'used.dart';` — reachable transitively
      mobile_impl.dart               # default branch of a conditional export from
                                     # the entry — reachable
      web_impl.dart                  # `dart.library.html` branch of the same
                                     # conditional export — reachable on every
                                     # platform (both branches are walked)
      conditional_hub.dart           # imported by the entry; hosts conditional and
                                     # deferred imports
      _io_impl.dart                  # reached via `if (dart.library.io)` configuration
      _web_impl.dart                 # reached via `if (dart.library.html)` configuration
      deferred_target.dart           # reached via `import ... deferred as ...`
      orphan.dart                    # never imported — UNREACHABLE
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/all_rules
fvm dart run anal samples/all_rules
```

The runner analyses both `lib/` and `bin/` so that the `bin/main.dart`
entry-point negative for `unused_source_file` is exercised alongside the
`lib/` cases.

## Expected output

Exactly **18** diagnostics — 13 `unused_function`, 4 `unused_class`, and 1
`unused_source_file` — and nothing else:

```
samples/all_rules/lib/src/internals.dart:15:6 • [warning] unused_function: The top-level function "unusedPublicTopLevel" is declared but never used.
samples/all_rules/lib/src/orphan.dart:1:1 • [warning] unused_source_file: The source file "samples/all_rules/lib/src/orphan.dart" is never imported, exported, or used as a part.
samples/all_rules/lib/unused_class_demo.dart:15:7 • [warning] unused_class: The class "_Foo" is declared but never used.
samples/all_rules/lib/unused_class_demo.dart:18:7 • [warning] unused_class: The mixin "_Bar" is declared but never used.
samples/all_rules/lib/unused_class_demo.dart:21:6 • [warning] unused_class: The enum "_Baz" is declared but never used.
samples/all_rules/lib/unused_class_demo.dart:24:16 • [warning] unused_class: The extension type "_Qux" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:29:6 • [warning] unused_function: The top-level function "_unusedPrivateTopLevel" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:32:9 • [warning] unused_function: The top-level getter "_unusedTopLevelGetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:35:5 • [warning] unused_function: The top-level setter "_unusedTopLevelSetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:189:8 • [warning] unused_function: The method "_unusedPrivateMethod" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:192:15 • [warning] unused_function: The static method "unusedStaticMethod" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:195:11 • [warning] unused_function: The getter "unusedGetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:198:7 • [warning] unused_function: The setter "unusedSetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:201:20 • [warning] unused_function: The operator "-" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:208:10 • [warning] unused_function: The local function "unusedLocal" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:262:10 • [warning] unused_function: The extension method "unusedExtension" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:318:8 • [warning] unused_function: The method "overrideButUnreachable" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:339:7 • [warning] unused_function: The method "foo" is declared but never used.
```

(Diagnostic ordering depends on the runner's file iteration; the set of
`(file, ruleId)` pairs above is what's deterministic.)

### Positive cases (MUST be flagged)

| Tag  | File                              | Rule                 | Subject                                                                                |
| ---- | --------------------------------- | -------------------- | -------------------------------------------------------------------------------------- |
| `P1` | `lib/unused_function_demo.dart`   | `unused_function`    | `_unusedPrivateTopLevel` — private top-level function with no reference in the unit.   |
| `P2` | `lib/unused_function_demo.dart`   | `unused_function`    | `_unusedTopLevelGetter` — private top-level getter that is never read.                 |
| `P3` | `lib/unused_function_demo.dart`   | `unused_function`    | `_unusedTopLevelSetter` — private top-level setter that is never written.              |
| `P4` | `lib/unused_function_demo.dart`   | `unused_function`    | `Service._unusedPrivateMethod` — private instance method with no reference anywhere.   |
| `P5` | `lib/unused_function_demo.dart`   | `unused_function`    | `Service.unusedStaticMethod` — static method with no reference anywhere.               |
| `P6` | `lib/unused_function_demo.dart`   | `unused_function`    | `Service.unusedGetter` — instance getter that is never read.                           |
| `P7` | `lib/unused_function_demo.dart`   | `unused_function`    | `Service.unusedSetter` — instance setter that is never written.                        |
| `P8` | `lib/unused_function_demo.dart`   | `unused_function`    | `Service.operator -` — operator that is never invoked.                                 |
| `P9` | `lib/unused_function_demo.dart`   | `unused_function`    | local `unusedLocal` inside `Service.usedMethod` — local function with no reference in its enclosing body. |
| `P10`| `lib/unused_function_demo.dart`   | `unused_function`    | `StringX.unusedExtension` — method on a public extension that is never invoked.        |
| `P11`| `lib/src/internals.dart`          | `unused_function`    | `unusedPublicTopLevel` — public top-level function in `lib/src/` (the package's internal surface) with no reference. |
| `P12`| `lib/unused_function_demo.dart`   | `unused_function`    | `IsolatedSub.overrideButUnreachable` — `@override` whose inherited supertype member is in the analyzed set but itself unreferenced, so the override-of-reachable exemption does not apply. |
| `P13`| `lib/unused_function_demo.dart`   | `unused_function`    | `NoSuchMethodTarget.foo` — concrete method on a class whose supertype chain does NOT declare `noSuchMethod`. Positive control for the `noSuchMethod` supertype walk. |
| `P1` | `lib/unused_class_demo.dart`      | `unused_class`       | `class _Foo {}` — unused private class.                                                |
| `P2` | `lib/unused_class_demo.dart`      | `unused_class`       | `mixin _Bar {}` — unused private mixin.                                                |
| `P3` | `lib/unused_class_demo.dart`      | `unused_class`       | `enum _Baz { a, b }` — unused private enum.                                            |
| `P4` | `lib/unused_class_demo.dart`      | `unused_class`       | `extension type _Qux(int value) {}` — unused private extension type.                   |
| `P1` | `lib/src/orphan.dart`             | `unused_source_file` | the file itself — never imported, exported, or used as a `part` from any entry point.  |

### Negative cases (MUST NOT be flagged)

`unused_function`:

| Tag  | Where                                       | Why the rule skips it                                                                 |
| ---- | ------------------------------------------- | ------------------------------------------------------------------------------------- |
| `N1` | `publicTopLevel`                            | Public top-level function in a file directly under `lib/` — part of the package's public surface, reachable from outside the analyzed set. |
| `N2` | `main`                                      | The `main` entry point is exempt by name.                                             |
| `N3` | `_usedPrivate`                              | Referenced as both a direct call and a tear-off in `main`.                            |
| `N4` | `external _externalPrivate`                 | `external` top-level functions are exempt regardless of name.                         |
| `N5` | `@pragma('vm:entry-point')` private         | `@pragma('vm:entry-point')` annotated declarations are exempt regardless of name.     |
| `N6` | `Service.objectPatternGetter`               | Used only via an object-pattern destructure — `visitPatternField` counts the resolved getter as a reference. |
| `N7` | `Service.recordGetter`                      | Used inside a record literal that is destructured by a record pattern — `visitRecordLiteral` and `visitRecordPattern` descend through both forms. |
| `N8` | `Service.cascadedMethod`                    | Invoked from `main` via a cascade (`service..cascadedMethod()`) — cascade sections flow through the recursive visitor. |
| `N9` | `Service.call`                              | Invoked from `main` via the implicit `.call` (`service()`); `visitFunctionExpressionInvocation` records the `call` element as a use. |
| `N10`| every member of `NoSuchMethodHolder`        | The class declares its own `noSuchMethod`, which can intercept any call by name at runtime — the rule skips every member and the constructor. |
| `N11`| every member of `MirrorsHostedService` in `lib/src/mirrors_user.dart` | The library imports `dart:mirrors`, which can invoke arbitrary members by name — the rule skips every member and constructor declared in the unit. |
| `N12`| every abstract getter on `L` in `lib/src/l10n/l10n.dart` and every concrete `@override` getter on `LEn` in `lib/src/l10n/l10n_en.dart` | Each file is stamped with the de-facto Dart "this is generated" marker `// ignore_for_file: type=lint` at the top, which `flutter gen-l10n` writes into every file it emits — the rule treats the marker as a unit-level exemption and skips every candidate collector for the unit. |
| `N13`| `Greeter.build` extending `StatelessWidgetStub` | `@override` of an in-repo abstract supertype member that is itself referenced through `this` from the base class (`render()` calls `build()`) — the supertype member is in the global reference set, so the override is treated as a use. |
| `N14`| `Sub.hook` extending `Base`                  | `@override` of an in-repo abstract supertype member that is invoked from the base class (`Base.run` calls `hook()` through implicit `this`) — same override-of-reachable exemption as N13. |
| `N15`| `_FakeService.foo` extending `_Fake` implementing `NoSuchMethodTarget` | `_Fake` declares its own `noSuchMethod`; the supertype-walking exemption inspects `_FakeService.allSupertypes`, finds `_Fake.noSuchMethod`, and skips every member of `_FakeService`. Mocktail's `Fake` / `Mock` simple names are recognised the same way even when the base library is not part of the analyzed set. |
| `N16`| `_C.foo` extending `_B extends _A` (two-hop) | `_A` declares `noSuchMethod`, `_B extends _A` forwards the override implicitly, `_C extends _B implements NoSuchMethodTarget`. The walk transitively finds `_A.noSuchMethod` through `_B`, so `_C.foo` is exempt despite neither `_B` nor `_C` declaring `noSuchMethod` directly. |
| `N17`| `Box<T>.put` and `Box<T>.peek` called through `IntBox` | Generic-class members invoked through a non-generic subtype resolve to a substituted "member view" of the declared element. Both the candidate set and the global reference set are projected through `Element.baseElement` so the declared member matches the call site. |
| `N18`| `Holder<int>.value(0)`                       | Factory constructor on a generic sealed class invoked with an explicit type argument resolves to a substituted view of the declared constructor; the same `baseElement` projection lets the declared factory match the call site. |
| `N19`| `A.new` reached through `B`'s `super.x` forwarding (`class B extends A { const B({super.x}); }` plus `const B(x: 1)`) | Super-parameter forwarding (Dart 2.17+) produces no `SuperConstructorInvocation` AST node — the forwarding is expressed only through the `super.x` parameter. The rule reads the implicit super-constructor target off the constructor element and records it as a use, so `A`'s constructor must NOT be flagged. The same hook covers `class X extends Y {}` with a synthetic default constructor that implicitly invokes `Y.new`. |

Each positive case has a used twin that exercises the negative path for the
same kind:

- `_usedPrivate` (top-level function) — called and torn off from `main`.
- `_usedTopLevelGetter` / `_usedTopLevelSetter` — read / written from `main`.
- `Service.usedMethod`, `Service.usedStaticMethod`, `Service.usedGetter`,
  `Service.usedSetter`, and `Service.operator +` — all referenced from
  `main`.
- `usedLocal` inside `Service.usedMethod` — invoked in its enclosing body.
- `StringX.usedExtension` — invoked from `main`.
- `usedPublicTopLevel` in `lib/src/internals.dart` — invoked from `main`.

`unused_class`:

| Tag  | Why it is silent                                                                   |
| ---- | ---------------------------------------------------------------------------------- |
| `N1` | `PublicClass` — only private (`_`-prefixed) declarations are inspected.            |
| `N2` | `_UsedAsType` is referenced as a parameter type annotation.                        |
| `N3` | `_UsedAsExtends` is referenced in an `extends` clause.                             |
| `N4` | `_UsedAsImplements` is referenced in an `implements` clause.                       |
| `N5` | `_UsedAsIs` is referenced in an `is` check.                                        |
| `N6` | `_UsedAsAs` is referenced in an `as` cast (and as a return type).                  |
| `N7` | `_UsedStatic` is referenced via static-member access (`_UsedStatic.value`).        |
| `N8` | `class _Alias = _AliasBase with _AliasMixin;` — `ClassTypeAlias` is out of scope.  |
| `N9` | `extension _Ext on int {}` — non-type `extension` declarations are out of scope.   |
| `N10`| `@pragma('vm:entry-point')` annotated `_EntryClass` is exempted by the rule.       |
| `N11`| `_UsedInObjectPattern` is referenced only through a Dart 3 `case _UsedInObjectPattern()` object pattern. |
| `N12`| `_UsedInRecord` is referenced only inside the record type annotation `(_UsedInRecord, int)`. |
| `N13`| `_SealedParent` is referenced only through `extends` in its subtypes, which are themselves only referenced through object patterns in a `switch`. |

`unused_source_file`:

| File                              | Why the rule skips it                                                                  |
| --------------------------------- | -------------------------------------------------------------------------------------- |
| `bin/main.dart`                   | `bin/` entry point — always reachable.                                                 |
| `lib/all_rules_sample.dart`       | sits directly under `lib/`, so the rule treats it as an entry point.                   |
| `lib/unused_function_demo.dart`   | sits directly under `lib/` — entry point.                                              |
| `lib/unused_class_demo.dart`      | sits directly under `lib/` — entry point.                                              |
| `lib/src/internals.dart`          | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/mirrors_user.dart`       | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/l10n/l10n.dart`          | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/l10n/l10n_en.dart`       | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/used.dart`               | imported by `lib/all_rules_sample.dart` (a `lib/` direct-child entry point).           |
| `lib/src/used_via_part.dart`      | `part of 'used.dart';` — reachable transitively via the entry-point → `used.dart` → `used_via_part.dart` chain. |
| `lib/src/mobile_impl.dart`        | default branch of the conditional `export` in `lib/all_rules_sample.dart` — reachable. |
| `lib/src/web_impl.dart`           | `dart.library.html` branch of the same conditional `export` — both branches of every conditional URI are walked, so this file is reachable on every platform. |
| `lib/src/conditional_hub.dart`    | imported by `lib/all_rules_sample.dart` (a `lib/` direct-child entry point).           |
| `lib/src/_io_impl.dart`           | reached from `conditional_hub.dart` via the `if (dart.library.io)` configuration of a conditional import — every `if (...)` configuration contributes a reachability edge regardless of the active platform. |
| `lib/src/_web_impl.dart`          | reached from `conditional_hub.dart` via the `if (dart.library.html)` configuration of the same conditional import. |
| `lib/src/deferred_target.dart`    | reached from `conditional_hub.dart` via `import ... deferred as ...`; deferred imports contribute the same reachability edge as ordinary imports. |
