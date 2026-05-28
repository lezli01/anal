// Companion file to the unused_function sample's main entry point.
//
// Living under `lib/src/`, this file is treated by the rule as part of
// the package's *internal* surface — public top-level declarations
// here are candidates for `unused_function` and become positives when
// they go unreferenced. Files directly under `lib/` are skipped by
// contrast because they form the package's *public* surface.
//
// ignore_for_file: unused_element
library;

// (P11) Unused public top-level function in `lib/src/`. The rule treats
// `lib/src/` as the package's internal surface, so a public top-level
// function with no reference anywhere in the analyzed set is flagged.
void unusedPublicTopLevel() {}

// Used public top-level function — referenced from `main` in the
// sample's entry point, so the rule does not flag it.
void usedPublicTopLevel() {}

// (N21) Public top-level function whose ONLY reference lives in the
// excluded `lib/src/refs.g.dart` file. The runner is invoked with
// `--exclude '*.g.dart'`, so `refs.g.dart` is filtered out of the
// *reportable* set and never has its own candidates flagged. The frame
// still parses excluded files and feeds them into the cross-file rule's
// global reference set, so the call below keeps `keptAliveByExcludedRef`
// alive — without that behavior, this would be a P11-shaped positive.
void keptAliveByExcludedRef() {}

// (N22) Constructors of a `@freezed`-annotated class. `package:freezed`'s
// code generator emits boilerplate constructors — a private generative
// `Foo._()`, an unnamed factory forwarding to a generated `_$Foo`, and one
// named factory per union case — that are only invoked from generated
// `*.freezed.dart` part files. Consumers of `anal` typically run the
// rule before code generation has happened, so the AST shows those
// constructors as unreferenced. The rule recognises freezed-related
// annotations on the enclosing class and skips every constructor
// candidate of such a class.
//
// The sample declares a stub `freezed` identifier locally instead of
// depending on `package:freezed_annotation`: the exemption matches the
// annotation by simple name and the rule does not inspect the
// annotation's resolved element, so pulling in the real package (and
// its `build_runner` transitive dependency) would be pure overhead.
// The constructor-invocation form (`@Freezed()`) is covered by the
// rule's unit tests rather than here so the sample's stub does not need
// to declare a `Freezed` class whose constructor would itself become a
// constructor candidate.
const freezed = Object();

@freezed
class FreezedSample {
  FreezedSample._();
  factory FreezedSample() => throw UnimplementedError();
  factory FreezedSample.named() => throw UnimplementedError();
}
