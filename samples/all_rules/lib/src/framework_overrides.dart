// (N22) Override of a supertype member declared OUTSIDE the analyzed
// set, written WITHOUT an `@override` annotation.
//
// Framework callbacks reached only through a supertype that lives in
// another package — notably Flutter's `State.createState` and other
// lifecycle hooks — are frequently written without the `@override`
// annotation. The rule's override-of-reachable-supertype exemption no
// longer requires the annotation: a declaration that shadows an
// inherited supertype member is an override whether or not it is
// annotated, and when the inherited member is declared outside the
// analyzed unit set the rule cannot see its reference sites, so it must
// conservatively treat the override as a use.
//
// `LifecycleHost.toString` overrides `Object.toString`, which is
// declared in `dart:core` — always outside the analyzed unit set. In a
// self-contained sample `dart:core` is the only supertype source that is
// guaranteed to resolve while staying out of the analyzed set, so it
// stands in for the framework base class here. The method carries no
// `@override` annotation and is never referenced; the ONLY reason it is
// not flagged is the annotation-free override exemption.
//
// The enclosing class lives under `lib/src/`, so the public-members-
// outside-`lib/src/` exemption does NOT apply — this isolates the
// override exemption as the sole reason the method survives.
//
// ignore_for_file: annotate_overrides, unused_element
library;

/// Stands in for a framework widget whose callbacks override members
/// declared in another package.
class LifecycleHost {
  // Overrides `Object.toString` without an `@override` annotation, the
  // shape of a framework lifecycle callback. Out-of-set supertype member
  // ⇒ exempt.
  String toString() => 'LifecycleHost';
}
