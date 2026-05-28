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
import 'src/l10n/l10n.dart';
import 'src/l10n/l10n_en.dart';
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

  // (N13) `Greeter.build` is reached through `StatelessWidgetStub.render`,
  // which calls `build()` through an implicit `this`. The supertype's
  // abstract `build` lands in the global reference set via that call
  // site, so the `@override` on the concrete subclass is exempt and
  // must NOT be flagged.
  // ignore: unused_local_variable
  final greeted = Greeter().render();

  // (N14) `Sub.hook` is reached through `Base.run`, which calls
  // `hook()` through an implicit `this`. The supertype's abstract
  // `hook` lands in the global reference set via that call site, so
  // the `@override` on the concrete subclass is exempt.
  Sub().run();

  // (P12) `IsolatedSub` is instantiated so it is not flagged by
  // `unused_class`; its `@override` of `IsolatedBase.overrideButUnreachable`
  // is never called, and the supertype member is itself unreferenced,
  // so the override below stays flagged.
  // ignore: unused_local_variable
  final isolated = IsolatedSub();

  // (N15) `_FakeService` extends `_Fake` (which declares its own
  // `noSuchMethod`) and implements `NoSuchMethodTarget`. The constructor
  // call below is the only static reference to the class — every
  // member declared on `_FakeService` reaches dispatch only through
  // `_Fake.noSuchMethod`, so the supertype-walking exemption skips them
  // all. Without instantiating here, `unused_class` would flag the
  // private class itself; the instantiation is unrelated to the
  // `unused_function` exemption being tested.
  // ignore: unused_local_variable
  final fakeService = _FakeService();

  // (N16) Two-hop chain — `_A` declares `noSuchMethod`, `_B` extends `_A`
  // (forwarding the override), and `_C` extends `_B` while implementing
  // `NoSuchMethodTarget`. The walk transitively finds `_A.noSuchMethod`
  // through `_B`, so `_C.foo` is exempt despite `_C` itself declaring
  // no `noSuchMethod` override. Again instantiated only so
  // `unused_class` does not flag `_C`.
  // ignore: unused_local_variable
  final twoHop = _C();

  // (N17) Calls on a non-generic subtype of a generic base dispatch to
  // the substituted member view (`Box<int>.put`, `Box<int>.peek`). The
  // resolved element is a "member view" wrapper around the declared
  // `Box.put` / `Box.peek`; the candidate uses the declared form. Both
  // sides are projected through `Element.baseElement` so the global
  // reference set matches the candidate and neither member is flagged.
  IntBox().put(0);
  // ignore: unused_local_variable
  final peeked = IntBox().peek;

  // (N18) Factory constructor on a generic sealed class invoked with an
  // explicit type argument. The call site resolves to the substituted
  // member view of `Holder.value`; without normalisation it would never
  // match the declared candidate and the factory would be flagged.
  // ignore: unused_local_variable
  final holder = Holder<int>.value(0);

  // (N19) Super-parameter forwarding (Dart 2.17+). `B`'s constructor
  // declares `super.x` rather than writing an explicit `super(x: x)`
  // initializer, so the AST carries no `SuperConstructorInvocation` for
  // `A.new`. The implicit super-constructor target is read off the
  // constructor element and recorded as a use, so `A`'s constructor
  // must NOT be flagged.
  // ignore: unused_local_variable
  final b = const B(x: 1);

  // Parameterised enum constructor reference — each enum-value
  // declaration on `Route` invokes the enum's `const Route(this.path)`
  // constructor through `EnumConstantDeclaration.constructorElement`,
  // so the constructor stays referenced even though the read below
  // produces no `InstanceCreationExpression` AST node.
  // ignore: unused_local_variable
  final routePath = Route.home.path;

  // (N20) `keptAliveByExcludedRef` in `lib/src/internals.dart` is
  // referenced ONLY from the excluded `lib/src/refs.g.dart` file. The
  // sample is run with `--exclude '*.g.dart'`, which filters
  // `refs.g.dart` out of the *reportable* set but still parses it so
  // cross-file references flow into the global reference set. The call
  // site inside `refs.g.dart` therefore keeps `keptAliveByExcludedRef`
  // alive — without the excluded-files-as-references behavior, this
  // would be a P11-shaped positive. No code lives here for N20; the
  // exercise is the cross-library reference from the excluded file.

  // (N22) `FreezedSample` (declared in `lib/src/internals.dart`) carries
  // a `@freezed` annotation. `package:freezed`'s code generator stamps
  // such classes with boilerplate constructors — a private generative
  // `Foo._()`, an unnamed factory forwarding to a generated `_$Foo`, and
  // named factories per union case — that are only invoked from
  // generated `*.freezed.dart` part files. Those parts are usually
  // absent when the rule runs, so the source AST shows the constructors
  // as unreferenced. The rule recognises the freezed-related annotations
  // and skips every constructor candidate of the annotated class; no
  // code lives here for N22.
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

// === Override-of-reachable supertype member ===
//
// These cases exercise the "@override of a reachable supertype member
// is a use" exemption. The exemption fires when the inherited supertype
// member is either declared outside the analyzed unit set (dart:*,
// package:flutter, etc.) or itself present in the global reference set.

// (N13) An in-repo abstract base that references its own abstract
// member through implicit `this`. `StatelessWidgetStub.build` lands in
// the global reference set via the unqualified `build()` call inside
// `render()`, so the concrete `Greeter.build` override is treated as a
// use and must NOT be flagged.
abstract class StatelessWidgetStub {
  String build();
  String render() => 'wrapped(${build()})';
}

class Greeter extends StatelessWidgetStub {
  @override
  String build() => 'hello';
}

// (N14) Abstract base / concrete subtype dispatch on an in-repo type.
// `Base.hook` is invoked from `Base.run` through implicit `this`, so
// the supertype's abstract `hook` lands in the global reference set;
// `Sub.hook` therefore must NOT be flagged.
abstract class Base {
  void hook();
  void run() {
    hook();
  }
}

class Sub extends Base {
  @override
  void hook() {}
}

// (P12) `@override` targets an in-repo supertype member that is itself
// unreferenced — so the override stays flagged. The supertype member
// is declared `external` so the rule does not flag the supertype
// (which would otherwise also be reported); the override below
// remains a candidate and is flagged because its inherited element is
// in the analyzed set but not in the global reference set. This
// positive case guarantees the override-of-reachable exemption does
// not silently widen to all `@override` members.
class IsolatedBase {
  external void overrideButUnreachable();
}

class IsolatedSub extends IsolatedBase {
  @override
  void overrideButUnreachable() {}
}

// === noSuchMethod walks supertype chain ===
//
// These cases exercise the supertype-chain walk for the
// `noSuchMethod` exemption: when the enclosing class — or any class /
// mixin / interface reachable through `extends`, `with`, or
// `implements` — declares its own `noSuchMethod`, every member of the
// enclosing declaration is skipped. The walk also recognises mocktail's
// `Fake` and `Mock` base classes by simple name.

// Acts as the supertype surface that the `noSuchMethod`-walk samples
// declare an `@override` for.
class NoSuchMethodTarget {
  // (P13) Concrete method that is never invoked. The supertype-walking
  // exemption only fires on subclasses whose chain includes a
  // `noSuchMethod` declaration — `NoSuchMethodTarget` itself has no
  // such supertype, so its own unused member is still flagged. Acts as
  // the positive control that proves the walk does not silently spill
  // into every public class.
  int foo() => 0;
}

// Declares its own `noSuchMethod`, the canonical signal that any
// otherwise-missing call can be intercepted at runtime.
class _Fake {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

// (N15) `_FakeService.foo` is exempt because the supertype `_Fake`
// declares `noSuchMethod`. The walk inspects `_FakeService`'s own
// methods first, then `allSupertypes` — finding `_Fake.noSuchMethod` —
// and skips every member of `_FakeService`. The override never lands
// in the global reference set, so without the supertype walk this
// method would be flagged.
class _FakeService extends _Fake implements NoSuchMethodTarget {
  @override
  int foo() => 0;
}

// (N16) Two-hop chain. `_A` declares `noSuchMethod`, `_B extends _A`
// (forwarding the override implicitly), and `_C extends _B implements
// NoSuchMethodTarget`. The walk transitively finds `_A.noSuchMethod`
// through `_B` in `_C.allSupertypes`, so `_C.foo` is exempt despite
// neither `_B` nor `_C` declaring `noSuchMethod` directly.
class _A {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _B extends _A {}

class _C extends _B implements NoSuchMethodTarget {
  @override
  int foo() => 0;
}

// === Generic-class member identity ===
//
// These cases exercise the "declared element" normalisation applied to
// both sides of the reference set: a member resolved through a
// substituted generic type produces a member-view wrapper that does
// not equal the declared element. Both candidates and references are
// projected through `Element.baseElement` so generic call sites match
// the declared members.

// (N17) Methods and getters declared on a generic base class, called
// through a non-generic subtype. Without the normalisation, `Box.put`
// and `Box.peek` would be flagged as unused.
class Box<T> {
  void put(T v) {}
  T? get peek => null;
}

class IntBox extends Box<int> {}

// (N18) Factory constructor on a generic sealed class. `Holder<int>.value(0)`
// in `main` resolves to a substituted view of the declared factory
// constructor; without normalisation the declared constructor would
// never match.
sealed class Holder<T> {
  const factory Holder.value(T v) = _ValueHolder;
}

class _ValueHolder<T> implements Holder<T> {
  const _ValueHolder(this.v);
  final T v;
}

// === Super-parameter forwarding (Dart 2.17+) ===
//
// `B`'s constructor uses `super.x` to forward `x` to `A`'s constructor.
// The AST has no `SuperConstructorInvocation` node for this — the
// forwarding is expressed only through the `super.x` formal parameter.
// The rule reads the implicit super-constructor target off the
// constructor element so `A`'s constructor counts as referenced.

abstract class A {
  const A({this.x = 0});
  final int x;
}

class B extends A {
  const B({super.x});
}

// === Parameterised enum constructor invoked by enum-value declarations ===
//
// (N20) Each enum-value declaration on a parameterised enum implicitly
// invokes the enum's constructor at const-evaluation time, but the AST
// does NOT model that as an [InstanceCreationExpression] /
// [ConstructorName] — the call is implicit in the
// [EnumConstantDeclaration] node and only reachable via
// `node.constructorElement`. The rule's `visitEnumConstantDeclaration`
// hook records that target, so `Route`'s `const Route(this.path)`
// constructor must NOT be flagged.

enum Route {
  home('/'),
  settings('/settings');

  const Route(this.path);

  final String path;
}
