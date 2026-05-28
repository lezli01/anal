// Companion file demonstrating the `dart:mirrors` exemption of the
// `unused_function` rule.
//
// This library imports `dart:mirrors`, so under the mirrors assumption
// any class member declared here might legitimately be invoked by
// name at runtime. The rule therefore skips member and constructor
// candidates declared in this unit even when no AST reference exists.
//
// The file is imported from `lib/unused_function_sample.dart` so the
// `unused_source_file` rule does not flag it as orphaned.
//
// ignore_for_file: unused_element, unused_import, depend_on_referenced_packages
library;

import 'dart:mirrors';

// (N11) Public class whose unreferenced members would normally trigger
// `unused_function` — `mirrorReachableMethod`, `mirrorReachableGetter`,
// and the default constructor are never referenced from anywhere in the
// analyzed set. Because the enclosing library imports `dart:mirrors`,
// the rule's dispatch site skips every member and constructor candidate
// in this unit, so none of them are flagged.
class MirrorsHostedService {
  MirrorsHostedService();
  void mirrorReachableMethod() {}
  int get mirrorReachableGetter => 0;
  set mirrorReachableSetter(int value) {}
  MirrorsHostedService operator +(MirrorsHostedService other) => this;
}
