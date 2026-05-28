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
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/unused_function
fvm dart run anal samples/unused_function/lib
```

## Expected output

Eleven `unused_function` diagnostics — and nothing else:

```
samples/unused_function/lib/src/internals.dart:15:6 • [warning] unused_function: The top-level function "unusedPublicTopLevel" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:27:6 • [warning] unused_function: The top-level function "_unusedPrivateTopLevel" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:30:9 • [warning] unused_function: The top-level getter "_unusedTopLevelGetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:33:5 • [warning] unused_function: The top-level setter "_unusedTopLevelSetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:120:8 • [warning] unused_function: The method "_unusedPrivateMethod" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:123:15 • [warning] unused_function: The static method "unusedStaticMethod" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:126:11 • [warning] unused_function: The getter "unusedGetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:129:7 • [warning] unused_function: The setter "unusedSetter" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:132:20 • [warning] unused_function: The operator "-" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:139:10 • [warning] unused_function: The local function "unusedLocal" is declared but never used.
samples/unused_function/lib/unused_function_sample.dart:193:10 • [warning] unused_function: The extension method "unusedExtension" is declared but never used.
```

(Line / column numbers refer to the file named in each line.)

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
