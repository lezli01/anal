# anal — `unused_class` sample

This is a self-contained Dart/Flutter sample project that exercises the
[`unused_class`](../../lib/src/rules/unused_class_rule.dart) rule shipped by
the root [`anal`](../..) package. It is **not** published to pub.dev
(`publish_to: 'none'`) and depends on `anal` via a relative path.

The sample is structured so that every positive case is annotated with `(P*)`
and every negative case with `(N*)`, matching the comments in
[`lib/unused_class_sample.dart`](lib/unused_class_sample.dart).

## Layout

```
samples/unused_class/
├── pubspec.yaml                       # path-deps on ../.. (the root anal package)
├── README.md                          # this file
└── lib/
    ├── unused_class_sample.dart       # positive + negative cases for unused_class
    └── mirrors_unit_sample.dart       # `dart:mirrors` exemption (N14)
```

## Running the rule

From the **repository root**:

```sh
fvm flutter pub get -C samples/unused_class
fvm dart run anal samples/unused_class/lib
```

To restrict the run to just this rule (useful when comparing output against
the table below):

```sh
fvm dart run anal --rules=unused_class samples/unused_class/lib
```

## Expected diagnostics

Exactly **four** `unused_class` diagnostics are expected, one per positive
case, all in `lib/unused_class_sample.dart`:

| Case | Declaration                              | Kind             |
| ---- | ---------------------------------------- | ---------------- |
| P1   | `class _Foo {}`                          | `class`          |
| P2   | `mixin _Bar {}`                          | `mixin`          |
| P3   | `enum _Baz { a, b }`                     | `enum`           |
| P4   | `extension type _Qux(int value) {}`      | `extension type` |

Each diagnostic carries the message
`The <kind> "<name>" is declared but never used.`

## Negative cases (must NOT be flagged)

| Case | Why it is silent                                                                   |
| ---- | ---------------------------------------------------------------------------------- |
| N1   | `PublicClass` — only private (`_`-prefixed) declarations are inspected.            |
| N2   | `_UsedAsType` is referenced as a parameter type annotation.                        |
| N3   | `_UsedAsExtends` is referenced in an `extends` clause.                             |
| N4   | `_UsedAsImplements` is referenced in an `implements` clause.                       |
| N5   | `_UsedAsIs` is referenced in an `is` check.                                        |
| N6   | `_UsedAsAs` is referenced in an `as` cast (and as a return type).                  |
| N7   | `_UsedStatic` is referenced via static-member access (`_UsedStatic.value`).        |
| N8   | `class _Alias = _AliasBase with _AliasMixin;` — `ClassTypeAlias` is out of scope.  |
| N9   | `extension _Ext on int {}` — non-type `extension` declarations are out of scope.   |
| N10  | `@pragma('vm:entry-point')` annotated `_EntryClass` is exempted by the rule.       |
| N11  | `_UsedInObjectPattern` is referenced only through a Dart 3 `case _UsedInObjectPattern()` object pattern. |
| N12  | `_UsedInRecord` is referenced only inside the record type annotation `(_UsedInRecord, int)`. |
| N13  | `_SealedParent` is referenced only through `extends` in its subtypes, which are themselves only referenced through object patterns in a `switch`. |
| N14  | `_ReflectivelyReachable` lives in `lib/mirrors_unit_sample.dart`, which imports `dart:mirrors`; the rule exempts every candidate in such a unit. |
