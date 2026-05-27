// Sample file exercising the `unused_class` rule.
//
// The expected diagnostics for this file are documented in this sample's
// README. Four declarations in this file MUST be flagged; everything else
// MUST be silent.
library;

// === POSITIVE CASES (MUST trigger unused_class) ===

// (P1) Unused private class. No reference exists anywhere in the file, the
// name starts with `_`, and the library has no part files, so the rule
// flags it.
class _Foo {}

// (P2) Unused private mixin.
mixin _Bar {}

// (P3) Unused private enum.
enum _Baz { a, b }

// (P4) Unused private extension type.
extension type _Qux(int value) {}

// === NEGATIVE CASES (MUST NOT trigger unused_class) ===

// (N1) Public class — only private declarations are inspected.
class PublicClass {}

// (N2) Private class referenced as a type annotation.
class _UsedAsType {}

void useAsType(_UsedAsType v) {}

// (N3) Private class referenced via `extends`.
class _UsedAsExtends {}

class DerivedFromExtends extends _UsedAsExtends {}

// (N4) Private class referenced via `implements`.
class _UsedAsImplements {}

class DerivedFromImplements implements _UsedAsImplements {}

// (N5) Private class referenced via an `is` check.
class _UsedAsIs {}

bool checkIs(Object o) => o is _UsedAsIs;

// (N6) Private class referenced via an `as` cast.
class _UsedAsAs {}

_UsedAsAs castAs(Object o) => o as _UsedAsAs;

// (N7) Private class referenced via static-member access.
class _UsedStatic {
  static const int value = 0;
}

int readStatic() => _UsedStatic.value;

// (N8) `class _X = A with B;` mixin-application class — explicitly out of
// scope for the rule. Both `_AliasBase` and `_AliasMixin` are referenced by
// the alias, so they are also exempt.
class _AliasBase {}

mixin _AliasMixin {}
class _Alias = _AliasBase with _AliasMixin;

// (N9) `extension _Ext on T {}` declaration — explicitly out of scope for
// the rule (only extension *types* are inspected).
extension _Ext on int {
  int get doubled => this * 2;
}

// (N10) `@pragma('vm:entry-point')` annotated private class — exempted by
// the metadata exemption.
@pragma('vm:entry-point')
class _EntryClass {}
