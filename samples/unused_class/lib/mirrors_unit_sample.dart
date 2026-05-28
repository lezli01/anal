// Sample file exercising the `dart:mirrors` exemption of the
// `unused_class` rule. The single private class declared here would
// normally be flagged as unused, but the rule exempts every candidate in
// any compilation unit that imports `dart:mirrors`: a class may be
// resolved reflectively by name at runtime without ever being named
// statically, so flagging would produce false positives.
//
// This file therefore MUST NOT contribute any `unused_class` diagnostic
// when the sample is analyzed.
//
// ignore_for_file: depend_on_referenced_packages, unused_import
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:mirrors';

// (N14) Private class declared in a unit that imports `dart:mirrors`.
// Exempted by the rule's reflection-aware bail-out — would otherwise
// match the same shape as P1.
class _ReflectivelyReachable {}
