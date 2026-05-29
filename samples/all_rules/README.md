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
    dev_tool.g.dart                  # excluded via `--exclude '*.g.dart'`; parsed
                                     # but NOT reportable. Its `import` of
                                     # `lib/src/kept_alive_by_excluded.dart`
                                     # contributes the ONLY reachability edge
                                     # keeping that file alive
  lib/
    all_rules_sample.dart            # lib/<package>.dart entry point
    unused_function_demo.dart        # positive + negative cases for unused_function
    unused_class_demo.dart           # positive + negative cases for unused_class
    src/
      internals.dart                 # public-top-level positive for unused_function
                                     # (`lib/src/` is the package's internal surface);
                                     # also declares `keptAliveByExcludedRef`, the
                                     # function referenced from the excluded
                                     # `refs.g.dart` (N20)
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
                                     # platform (both branches are walked). As
                                     # the non-selected branch on the VM, its
                                     # public function/class members are also
                                     # exempt from unused_function as
                                     # conditional-export branch targets (N21)
      framework_overrides.dart       # `LifecycleHost.toString` overrides an
                                     # out-of-set (`dart:core`) supertype member
                                     # WITHOUT an `@override` annotation — exempt
                                     # from unused_function by the
                                     # annotation-free override rule (N22)
      conditional_hub.dart           # imported by the entry; hosts conditional and
                                     # deferred imports
      _io_impl.dart                  # reached via `if (dart.library.io)` configuration
      _web_impl.dart                 # reached via `if (dart.library.html)` configuration
      deferred_target.dart           # reached via `import ... deferred as ...`
      refs.g.dart                    # excluded via `--exclude '*.g.dart'`; parsed
                                     # but NOT reportable. Calls
                                     # `keptAliveByExcludedRef` so the cross-file
                                     # rule's global reference set still sees that
                                     # use (unused_function N20)
      kept_alive_by_excluded.dart    # reached ONLY through the excluded
                                     # `bin/dev_tool.g.dart` importer (unused_source_file)
      orphan.dart                    # never imported — UNREACHABLE. Also
                                     # declares a private function and class
                                     # that are SUPPRESSED (not flagged by
                                     # unused_function / unused_class) because
                                     # the whole file is already reported (N25)
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/all_rules
fvm dart run anal --exclude '*.g.dart' samples/all_rules
```

The runner analyses both `lib/` and `bin/` so that the `bin/main.dart`
entry-point negative for `unused_source_file` is exercised alongside the
`lib/` cases.

The `--exclude '*.g.dart'` flag filters `lib/src/refs.g.dart` and
`bin/dev_tool.g.dart` out of the *reportable* set so their own
declarations are never flagged, while the frame still parses them so
their references — the call to `keptAliveByExcludedRef` from
`refs.g.dart` and the `import` of `lib/src/kept_alive_by_excluded.dart`
from `dev_tool.g.dart` — flow into the cross-file rules' global
reference and reachability graphs. See `unused_function` N20 and the
`unused_source_file` table below.

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
samples/all_rules/lib/unused_function_demo.dart:218:8 • [warning] unused_function: The method "_unusedPrivateMethod" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:221:15 • [warning] unused_function: The static method "unusedStaticMethod" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:224:11 • [warning] unused_function: The getter "unusedGetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:227:7 • [warning] unused_function: The setter "unusedSetter" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:230:20 • [warning] unused_function: The operator "-" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:237:10 • [warning] unused_function: The local function "unusedLocal" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:291:10 • [warning] unused_function: The extension method "unusedExtension" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:347:8 • [warning] unused_function: The method "overrideButUnreachable" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:368:7 • [warning] unused_function: The method "foo" is declared but never used.
```

(Diagnostic ordering depends on the runner's file iteration; the set of
`(file, ruleId)` pairs above is what's deterministic.)

The `unused_function` `N21`–`N24` negative cases (conditional-export
branch targets in `lib/src/web_impl.dart`, the annotation-free override
exemption in `lib/src/framework_overrides.dart`, public members of a
public type declared outside `lib/src/` in `lib/unused_function_demo.dart`,
and freezed-annotated constructors in `lib/src/internals.dart`)
contribute **no** diagnostics — that is the point of each: every
declaration they introduce is exempt.

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
| `N20`| `keptAliveByExcludedRef` in `lib/src/internals.dart` is referenced only from the excluded `lib/src/refs.g.dart` (the runner is invoked with `--exclude '*.g.dart'`) | Excluded files are filtered out of the *reportable* set but still parsed by the frame, so their references flow into the cross-file rule's global reference set. The call in `refs.g.dart` keeps `keptAliveByExcludedRef` alive — without the excluded-files-as-references behavior, this public top-level function in `lib/src/` would be a P11-shaped positive. The excluded file's own private members (e.g. `_refUsage`) are likewise not flagged because the file is not in `reportableFilePaths`. |
| `N21`| `platformLabelFn` / `WebPlatformService` members in `lib/src/web_impl.dart` — the non-selected (`dart.library.html`) branch of the conditional export in `lib/all_rules_sample.dart` | A conditional export resolves to exactly one branch at analysis time (mobile on the VM), so members of the non-selected branch are reached only through the wrapper's export surface and look unreferenced. The rule collects every `if (...)` configuration branch URI across the analyzed set and skips every candidate declared in such a file. `web_impl.dart` sits under `lib/src/`, so the public-members-outside-`lib/src/` exemption does NOT apply; the conditional-export branch-target exemption is what keeps its members unflagged. |
| `N22`| `LifecycleHost.toString` in `lib/src/framework_overrides.dart` | Overrides `Object.toString` — a supertype member declared in `dart:core`, outside the analyzed unit set — WITHOUT an `@override` annotation. A declaration that shadows a supertype member is an override whether or not it is annotated, and framework callbacks (Flutter's `State.createState`, lifecycle hooks) are routinely written without the annotation. When the inherited member is declared outside the analyzed set the rule cannot see its reference sites, so it conservatively treats the override as a use. The class is under `lib/src/`, isolating the override exemption as the sole reason the method survives. |
| `N23`| every public member of `PublicSurface` and the public getter on `PublicChannel` (both declared in `lib/unused_function_demo.dart`, directly under `lib/`) | Public instance/static methods, getters, setters, and operators on a public class — and public members of a public enum — declared OUTSIDE a `lib/src/` directory form the package's consumable, test-exercised API surface. "No references found in the analyzed set" cannot prove such a member unused, so the rule skips a candidate when both the member name and its enclosing type name are public and the declaring file is not under `lib/src/`, mirroring the existing public-top-level exemption. Private members, and members of private types, remain flagged. |
| `N24`| Every constructor of `FreezedSample` (`@freezed` bare-identifier form) in `lib/src/internals.dart` | `package:freezed`'s code generator emits boilerplate constructors — a private generative `Foo._()`, an unnamed factory forwarding to a generated `_$Foo`, and one named factory per union case — that are only invoked from generated `*.freezed.dart` part files. Consumers of `anal` typically run the rule before code generation has happened, so the source AST shows those constructors as unreferenced. The rule recognises `@freezed`, `@Freezed(...)`, `@unfreezed`, `@Unfreezed(...)`, and `@FreezedUnion(...)` annotations on the enclosing class and skips every constructor candidate. The sample declares a stub `freezed` identifier locally so it does not need to pull in `package:freezed_annotation` (and `build_runner`); the constructor-invocation form (`@Freezed()`) is covered by the rule's unit tests rather than here. |

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
| `bin/dev_tool.g.dart`             | not flagged — excluded via `--exclude '*.g.dart'`, so the file is not in the *reportable* set. The frame still parses it, so its `import` of `lib/src/kept_alive_by_excluded.dart` contributes a reachability edge that keeps that file alive. |
| `lib/all_rules_sample.dart`       | sits directly under `lib/`, so the rule treats it as an entry point.                   |
| `lib/unused_function_demo.dart`   | sits directly under `lib/` — entry point.                                              |
| `lib/unused_class_demo.dart`      | sits directly under `lib/` — entry point.                                              |
| `lib/src/internals.dart`          | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/mirrors_user.dart`       | imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
| `lib/src/framework_overrides.dart`| imported by `lib/unused_function_demo.dart` (a `lib/` direct-child entry point).       |
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
| `lib/src/kept_alive_by_excluded.dart` | not flagged — reachable ONLY through the excluded `bin/dev_tool.g.dart` importer. Excluded files are still parsed by the frame, so the import edge keeps this file alive even though the importer itself is not in the reportable set. |

### Cross-rule nesting suppression

| Tag  | Where                                  | Why the inner findings are silent                                                     |
| ---- | -------------------------------------- | ------------------------------------------------------------------------------------- |
| `N25`| the private function `_unusedOrphanHelper` and private class `_UnusedOrphanHelper` in `lib/src/orphan.dart` | `orphan.dart` is itself flagged by `unused_source_file` (it is unreachable). The three "unused" rules form a containment hierarchy — `unused_source_file` (whole file) ▸ `unused_class` (whole type) ▸ `unused_function` (member) — and when an outer finding fires, the levels nested inside it are suppressed. So although a reachable file with the same declarations would emit one `unused_function` and one `unused_class` diagnostic, here the dead file is reported once and the two nested findings are dropped. |
