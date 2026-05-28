// Sample file exercising the `unused_function` rule.
//
// The expected diagnostics for this file are documented in this sample's
// README. Each kind covered by the rule appears here as both a positive
// (MUST be flagged) and a negative (MUST NOT be flagged) case, so the
// sample reads as a self-contained map of the rule's behavior. The
// public-top-level case lives in `lib/src/internals.dart` because the
// rule only treats public top-level functions as candidates when the
// file sits under `lib/src/`.
//
// The SDK's built-in `unused_element` lint is disabled for this file
// because it would fire on the very declarations the sample is built to
// demonstrate; those declarations are still flagged by the `anal`
// runner under the `unused_function` rule, which is the point of the
// sample.
// ignore_for_file: unused_element
library;

import 'src/internals.dart';
import 'src/mirrors_user.dart';

// === POSITIVE CASES (MUST trigger unused_function) ===

// (P1) Unused private top-level function. The library has no part files
// and no reference to `_unusedPrivateTopLevel` exists, so the rule
// flags it.
void _unusedPrivateTopLevel() {}

// (P2) Unused private top-level getter — never read.
int get _unusedTopLevelGetter => 0;

// (P3) Unused private top-level setter — never written.
set _unusedTopLevelSetter(int value) {}

// === NEGATIVE TOP-LEVEL CASES (MUST NOT trigger unused_function) ===

// (N1) Public top-level function in a file directly under `lib/`. The
// rule treats files under `lib/` (outside `lib/src/`) as part of the
// package's public surface and skips public top-level declarations
// there.
void publicTopLevel() {}

// (N3) Private top-level function referenced from `main` as both a
// direct call and a tear-off.
void _usedPrivate() {}

// Used private accessor twins — referenced from `main`.
int get _usedTopLevelGetter => 0;
set _usedTopLevelSetter(int value) {}

// (N4) External private top-level function — exempt by `external`.
external void _externalPrivate();

// (N5) `@pragma('vm:entry-point')` annotated private function — exempt
// by the metadata exemption.
@pragma('vm:entry-point')
void _entryPointPrivate() {}

// (N2) The library entry point — exempt by name `main`.
void main() {
  // Reference the used twins so their elements land in the global
  // reference set.
  _usedPrivate();
  final tearOff = _usedPrivate;
  tearOff();

  // ignore: unused_local_variable
  final readGetter = _usedTopLevelGetter;
  _usedTopLevelSetter = 1;

  usedPublicTopLevel();

  final service = Service();
  service.usedMethod();
  Service.usedStaticMethod();
  // ignore: unused_local_variable
  final getterValue = service.usedGetter;
  service.usedSetter = 1;
  // ignore: unused_local_variable
  final combined = service + service;
  // ignore: unused_local_variable
  final extended = 'foo'.usedExtension();

  // (N6) Object-pattern destructuring counts as a use of `objectPatternGetter`.
  // The `visitPatternField` hook records the resolved getter element on
  // the pattern field, so the rule must NOT flag the getter.
  final Service(:objectPatternGetter) = service;
  // ignore: unused_local_variable
  final destructured = objectPatternGetter;

  // (N7) Record literal + record-pattern destructuring counts as a use
  // of `recordGetter`. The getter is read while constructing the record,
  // and the record is then destructured with a record pattern; the rule
  // descends into both forms via the new `visitRecordLiteral` and
  // `visitRecordPattern` hooks.
  final record = (service.recordGetter,);
  final (recordGetterValue,) = record;
  // ignore: unused_local_variable
  final recordRead = recordGetterValue;

  // (N8) Cascade method call lands on `Service.cascadedMethod`. Cascade
  // sections flow through the existing visitor; the new
  // `visitCascadeExpression` hook documents the coverage at the visitor
  // level.
  service..cascadedMethod();

  // (N9) Callable-object `instance()` invocation resolves to `Service.call`
  // via the implicit `.call` tear-off / invocation; the new
  // `visitFunctionExpressionInvocation` hook records the `call` element
  // as a use.
  service();

  // (N10) `NoSuchMethodHolder` declares `noSuchMethod`, so every member of
  // the class is exempt from the rule even though none are referenced.
  NoSuchMethodHolder();
}

class Service {
  // (P4) Unused private method.
  void _unusedPrivateMethod() {}

  // (P5) Unused static method.
  static void unusedStaticMethod() {}

  // (P6) Unused getter.
  int get unusedGetter => 0;

  // (P7) Unused setter.
  set unusedSetter(int value) {}

  // (P8) Unused operator.
  Service operator -(Service other) => this;

  // Used method twin — referenced from `main`. Also home to the local
  // function cases so the negative side of the local-function path is
  // exercised here.
  void usedMethod() {
    // (P9) Unused local function inside a method body — flagged.
    void unusedLocal() {}

    void usedLocal() {}
    usedLocal();
  }

  static void usedStaticMethod() {}
  int get usedGetter => 0;
  set usedSetter(int value) {}
  Service operator +(Service other) => this;

  // Used only via an object-pattern destructure in `main` (N6). Without
  // the rule's new `visitPatternField` hook, this getter would be
  // flagged as unused.
  int get objectPatternGetter => 0;

  // Used only inside a record literal that is then destructured by a
  // record pattern in `main` (N7). Exercises both `visitRecordLiteral`
  // and `visitRecordPattern` while documenting that destructured reads
  // count as uses.
  int get recordGetter => 0;

  // Used only via a cascade method call in `main` (N8). Cascades flow
  // through the existing visitor; the negative case here makes the
  // coverage explicit.
  void cascadedMethod() {}

  // Used only via the implicit `.call` invocation `service()` in `main`
  // (N9). Without the new `visitFunctionExpressionInvocation` hook, the
  // `call` declaration would be flagged.
  void call() {}
}

// (N10) Public class declaring `noSuchMethod`. Every member of this
// class would otherwise be flagged by the rule — the class is never
// referenced beyond a single constructor call so the declared
// `forwardedMethod`, `forwardedGetter`, `forwardedSetter`, and even
// the `noSuchMethod` override have no AST references. Because the
// class declares its own `noSuchMethod`, every member is exempt: any
// missing call could legitimately be intercepted at runtime.
class NoSuchMethodHolder {
  NoSuchMethodHolder();
  void forwardedMethod() {}
  int get forwardedGetter => 0;
  set forwardedSetter(int value) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// (P10) Unused method on a public extension. The extension itself has a
// used twin so the negative side of the extension-member path is also
// exercised.
extension StringX on String {
  String unusedExtension() => this;
  String usedExtension() => this;
}
