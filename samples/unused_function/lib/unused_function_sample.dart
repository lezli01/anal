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
}

// (P10) Unused method on a public extension. The extension itself has a
// used twin so the negative side of the extension-member path is also
// exercised.
extension StringX on String {
  String unusedExtension() => this;
  String usedExtension() => this;
}
