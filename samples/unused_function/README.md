# `unused_function` sample

A self-contained Dart/Flutter package that exercises the
[`unused_function`](../../lib/src/rules/unused_function_rule.dart) rule
shipped by the [`anal`](../..) package.

The sample exists so consumers (and the rule's own contributors) can see
exactly which declarations the rule flags and which it deliberately ignores,
running against a real `pub get`-resolved project.

## Layout

```
samples/unused_function/
  pubspec.yaml                       # path-dependent on the root `anal` package
  lib/unused_function_sample.dart    # entry point; covers every flagged kind
                                     # except the public top-level function case
  lib/src/internals.dart             # public-but-unreferenced top-level function
                                     # (`lib/src/` is the package's internal
                                     # surface, so public declarations there
                                     # are candidates)
  lib/src/mirrors_user.dart          # negative case for the `dart:mirrors`
                                     # exemption — every member of every class
                                     # in a library that imports `dart:mirrors`
                                     # is exempt from the rule
  lib/src/l10n/l10n.dart             # negative case for the
  lib/src/l10n/l10n_en.dart          # `// ignore_for_file: type=lint`
                                     # exemption — mocks the synthetic
                                     # `L` base class and per-locale
                                     # subclass that `flutter gen-l10n`
                                     # emits under
                                     # `output-localization-file`; every
                                     # candidate in either unit is
                                     # skipped because of the generated-
                                     # code marker at the top of the file
  lib/src/refs.g.dart                # excluded via `--exclude '*.g.dart'`;
                                     # parsed but never reportable. Calls
                                     # `keptAliveByExcludedRef` so the
                                     # cross-file rule's global reference
                                     # set still sees that use (N21)
  lib/src/platform_export.dart       # conditional-export wrapper imported
                                     # by the entry point; names
                                     # `platform_io.dart` and
                                     # `platform_web.dart` in `if (...)`
                                     # configurations (N22)
  lib/src/platform_io.dart           # IO branch of the conditional export
  lib/src/platform_web.dart          # `dart.library.html` branch — the
                                     # NON-selected branch on the VM; its
                                     # members are exempt as conditional-
                                     # export branch targets (N22)
  lib/src/framework_overrides.dart   # `LifecycleHost.toString` overrides
                                     # an out-of-set (`dart:core`)
                                     # supertype member WITHOUT an
                                     # `@override` annotation — exempt by
                                     # the annotation-free override rule
                                     # (N23)
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run anal --exclude '*.g.dart' samples/unused_function/lib
```

The `--exclude '*.g.dart'` flag filters `lib/src/refs.g.dart` out of the
*reportable* set so its own private members (e.g. `_refUsage`) are not
flagged, while the frame still parses the file so its references — like
the call to `keptAliveByExcludedRef` — flow into the cross-file rule's
global reference set. See `N21` below.

## Expected output

Thirteen `unused_function` diagnostics — and nothing else:

```
samples/unused_function/lib/src/internals.dart:15:6 • [warning] unused_function: The top-level function "unusedPublicTopLevel" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:29:6 • [warning] unused_function: The top-level function "_unusedPrivateTopLevel" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:32:9 • [warning] unused_function: The top-level getter "_unusedTopLevelGetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:35:5 • [warning] unused_function: The top-level setter "_unusedTopLevelSetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:216:8 • [warning] unused_function: The method "_unusedPrivateMethod" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:219:15 • [warning] unused_function: The static method "unusedStaticMethod" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:222:11 • [warning] unused_function: The getter "unusedGetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:225:7 • [warning] unused_function: The setter "unusedSetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:228:20 • [warning] unused_function: The operator "-" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:235:10 • [warning] unused_function: The local function "unusedLocal" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:289:10 • [warning] unused_function: The extension method "unusedExtension" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:345:8 • [warning] unused_function: The method "overrideButUnreachable" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:366:7 • [warning] unused_function: The method "foo" is declared but never used.
```

(Line / column numbers refer to the file named in each line.)

The `N22`–`N25` negative cases (conditional-export branch targets, the
annotation-free override exemption, public members of a public type
declared outside `lib/src/`, and freezed-annotated constructors)
contribute **no** diagnostics — that is the point of each: every
declaration they introduce is exempt.

### Positive cases (MUST be flagged)

| Tag   | Where                                       | Why it triggers                                                                       |
| ----- | ------------------------------------------- | ------------------------------------------------------------------------------------- |
| `P1`  | top-level `_unusedPrivateTopLevel`          | Private top-level function with no reference in the analyzed set.                     |
| `P2`  | top-level getter `_unusedTopLevelGetter`    | Private top-level getter that is never read. (See note above re: the duplicate label.) |
| `P3`  | top-level setter `_unusedTopLevelSetter`    | Private top-level setter that is never written. (See note above re: the duplicate label.) |
| `P4`  | `Service._unusedPrivateMethod`              | Private instance method with no reference anywhere.                                   |
| `P5`  | `Service.unusedStaticMethod`                | Static method with no reference anywhere.                                             |
| `P6`  | `Service.unusedGetter`                      | Instance getter that is never read.                                                   |
| `P7`  | `Service.unusedSetter`                      | Instance setter that is never written.                                                |
| `P8`  | `Service.operator -`                        | Operator that is never invoked.                                                       |
| `P9`  | local `unusedLocal` inside `Service.usedMethod` | Local function with no reference in its enclosing body.                           |
| `P10` | `StringX.unusedExtension`                   | Method on a public extension that is never invoked.                                   |
| `P11` | `unusedPublicTopLevel` in `lib/src/internals.dart` | Public top-level function in `lib/src/`. Files under `lib/src/` are the package's internal surface, so public top-level declarations there are candidates. |
| `P12` | `IsolatedSub.overrideButUnreachable`         | `@override` whose inherited supertype member is in the analyzed set but itself unreferenced — the override-of-reachable exemption does not apply, so the method is still flagged. |
| `P13` | `NoSuchMethodTarget.foo`                     | Concrete method on a class whose supertype chain does NOT declare `noSuchMethod` — the supertype-walking exemption does not apply, so the unused member is still flagged. Acts as the positive control for the `noSuchMethod` walk. |

### Negative cases (MUST NOT be flagged)

| Tag   | Where                                                      | Why the rule skips it                                                                 |
| ----- | ---------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `N1`  | `publicTopLevel`                                           | Public top-level function in a file directly under `lib/` — part of the package's public surface, reachable from outside the analyzed set. |
| `N2`  | `main`                                                     | The `main` entry point is exempt by name.                                             |
| `N3`  | `_usedPrivate`                                             | Referenced as both a direct call and a tear-off in `main`.                            |
| `N4`  | `external _externalPrivate`                                | `external` top-level functions are exempt regardless of name.                         |
| `N5`  | `@pragma('vm:entry-point')` private                        | `@pragma('vm:entry-point')` annotated declarations are exempt regardless of name.     |
| `N6`  | `Service.objectPatternGetter`                              | Used only via an object-pattern destructure — the new `visitPatternField` hook counts the resolved getter element as a reference. |
| `N7`  | `Service.recordGetter`                                     | Used inside a record literal that is destructured by a record pattern — `visitRecordLiteral` and `visitRecordPattern` descend through both forms. |
| `N8`  | `Service.cascadedMethod`                                   | Invoked from `main` via a cascade (`service..cascadedMethod()`) — cascade sections flow through the recursive visitor. |
| `N9`  | `Service.call`                                             | Invoked from `main` via the implicit `.call` (`service()`); `visitFunctionExpressionInvocation` records the `call` element as a use. |
| `N10` | every member of `NoSuchMethodHolder`                       | The class declares its own `noSuchMethod`, which can intercept any call by name at runtime — the rule skips every member and the constructor. |
| `N11` | every member of `MirrorsHostedService` in `lib/src/mirrors_user.dart` | The library imports `dart:mirrors`, which can invoke arbitrary members by name — the rule skips every member and constructor declared in the unit. |
| `N12` | every abstract getter on `L` in `lib/src/l10n/l10n.dart` and every concrete `@override` getter on `LEn` in `lib/src/l10n/l10n_en.dart` | Each file is stamped with the de-facto Dart "this is generated" marker `// ignore_for_file: type=lint` at the top, which `flutter gen-l10n` writes into every file it emits — the rule treats the marker as a unit-level exemption and skips every candidate collector for the unit. |
| `N13` | `Greeter.build` extending `StatelessWidgetStub` | `@override` of an in-repo abstract supertype member that is itself referenced through `this` from the base class (`render()` calls `build()`) — the supertype member is in the global reference set, so the override is treated as a use. |
| `N14` | `Sub.hook` extending `Base`                  | `@override` of an in-repo abstract supertype member that is invoked from the base class (`Base.run` calls `hook()` through implicit `this`) — same override-of-reachable exemption as N13. |
| `N15` | `_FakeService.foo` extending `_Fake` implementing `NoSuchMethodTarget` | `_Fake` declares its own `noSuchMethod`; the supertype-walking exemption inspects `_FakeService.allSupertypes`, finds `_Fake.noSuchMethod`, and skips every member of `_FakeService`. Mocktail's `Fake` / `Mock` simple names are recognised the same way even when the base library is not part of the analyzed set. |
| `N16` | `_C.foo` extending `_B extends _A` (two-hop) | `_A` declares `noSuchMethod`, `_B extends _A` forwards the override implicitly, `_C extends _B implements NoSuchMethodTarget`. The walk transitively finds `_A.noSuchMethod` through `_B`, so `_C.foo` is exempt despite neither `_B` nor `_C` declaring `noSuchMethod` directly. |
| `N17` | `Box<T>.put` and `Box<T>.peek` called through `IntBox` | Generic-class members invoked through a non-generic subtype resolve to a substituted "member view" of the declared element. Both the candidate set and the global reference set are projected through `Element.baseElement` so the declared member matches the call site. Without normalisation `Box.put` and `Box.peek` would be flagged. |
| `N18` | `Holder<int>.value(0)`                       | Factory constructor on a generic sealed class invoked with an explicit type argument resolves to a substituted view of the declared constructor; the same `baseElement` projection lets the declared factory match the call site. |
| `N19` | `A.new` reached through `B`'s `super.x` forwarding (`class B extends A { const B({super.x}); }` plus `const B(x: 1)`) | Super-parameter forwarding (Dart 2.17+) produces no `SuperConstructorInvocation` AST node — the forwarding is expressed only through the `super.x` parameter. The rule reads the implicit super-constructor target off the constructor element and records it as a use, so `A`'s constructor must NOT be flagged. Also covers classes that declare no constructor of their own: the synthetic default constructor implicitly invokes super, and the `visitClassDeclaration` hook records that super target. |
| `N20` | `Route`'s `const Route(this.path)` constructor on a parameterised enum (`enum Route { home('/'), settings('/settings'); const Route(this.path); final String path; }` plus `Route.home.path`) | Each enum-value declaration invokes the enum's constructor at const-evaluation time, but the AST does NOT model that as an `InstanceCreationExpression` / `ConstructorName` — the call is implicit in the `EnumConstantDeclaration` node and only reachable via `node.constructorElement`. The new `visitEnumConstantDeclaration` hook records that target, so the constructor must NOT be flagged. |
| `N21` | `keptAliveByExcludedRef` in `lib/src/internals.dart` is referenced only from the excluded `lib/src/refs.g.dart` (the runner is invoked with `--exclude '*.g.dart'`) | Excluded files are filtered out of the *reportable* set but still parsed by the frame, so their references flow into the cross-file rule's global reference set. The call in `refs.g.dart` keeps `keptAliveByExcludedRef` alive — without the excluded-files-as-references behavior, this public top-level function in `lib/src/` would be a P11-shaped positive. The excluded file's own private members (e.g. `_refUsage`) are likewise not flagged because the file is not in `reportableFilePaths`. |
| `N22` | `platformLabel` / `PlatformService` members in `lib/src/platform_web.dart` (and `lib/src/platform_io.dart`), reached through the conditional-export wrapper `lib/src/platform_export.dart` | A conditional export (`export 'platform_io.dart' if (dart.library.io) 'platform_io.dart' if (dart.library.html) 'platform_web.dart';`) resolves to exactly one branch at analysis time, so members of the non-selected branch are reached only through the wrapper's export surface and look unreferenced. The rule collects every `if (...)` configuration branch URI across the analyzed set and skips every candidate declared in such a file — the whole branch file is treated as part of the platform export surface. Both branch files sit under `lib/src/`, so the public-members-outside-`lib/src/` exemption does NOT apply; the conditional-export branch-target exemption is what keeps their members unflagged. |
| `N23` | `LifecycleHost.toString` in `lib/src/framework_overrides.dart` | Overrides `Object.toString` — a supertype member declared in `dart:core`, outside the analyzed unit set — WITHOUT an `@override` annotation. A declaration that shadows a supertype member is an override whether or not it is annotated, and framework callbacks (Flutter's `State.createState`, lifecycle hooks) are routinely written without the annotation. When the inherited member is declared outside the analyzed set the rule cannot see its reference sites, so it conservatively treats the override as a use. The class is under `lib/src/`, isolating the override exemption as the sole reason the method survives. |
| `N24` | every public member of `PublicSurface` and the public getter on `PublicChannel` (both declared in `lib/unused_function_sample.dart`, directly under `lib/`) | Public instance/static methods, getters, setters, and operators on a public class — and public members of a public enum — declared OUTSIDE a `lib/src/` directory form the package's consumable, test-exercised API surface. "No references found in the analyzed set" cannot prove such a member unused, so the rule skips a candidate when both the member name and its enclosing type name are public and the declaring file is not under `lib/src/`, mirroring the existing public-top-level exemption. Private members, and members of private types, remain flagged. |
| `N25` | Every constructor of `FreezedSample` (`@freezed` bare-identifier form) in `lib/src/internals.dart` | `package:freezed`'s code generator emits boilerplate constructors — a private generative `Foo._()`, an unnamed factory forwarding to a generated `_$Foo`, and one named factory per union case — that are only invoked from generated `*.freezed.dart` part files. Consumers of `anal` typically run the rule before code generation has happened, so the source AST shows those constructors as unreferenced even though they will be reached from generated output. The rule recognises `@freezed`, `@Freezed(...)`, `@unfreezed`, `@Unfreezed(...)`, and `@FreezedUnion(...)` annotations on the enclosing class and skips every constructor candidate of such a class. The sample declares a stub `freezed` identifier locally so it does not need to pull in `package:freezed_annotation` (and `build_runner`); the constructor-invocation form (`@Freezed()`) is covered by the rule's unit tests rather than here. |

Each positive case has a used twin that exercises the rule's negative
path for the same kind:

- `_usedPrivate` (top-level function) — called and torn off from `main`.
- `_usedTopLevelGetter` / `_usedTopLevelSetter` — read / written from `main`.
- `Service.usedMethod`, `Service.usedStaticMethod`, `Service.usedGetter`,
  `Service.usedSetter`, and `Service.operator +` — all referenced from
  `main`.
- `usedLocal` inside `Service.usedMethod` — invoked in its enclosing
  body.
- `StringX.usedExtension` — invoked from `main`.
- `usedPublicTopLevel` in `lib/src/internals.dart` — invoked from `main`.
