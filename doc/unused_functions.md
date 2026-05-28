## `unused_function` — false positives on momminess

A categorised audit of every diagnostic the `unused_function` rule
emits when run against the `momminess` Flutter app, with each
false-positive bucket mapped to the LANGUAGE.md / CLAUDE.md language
feature the rule is failing to model. The follow-up `fix:` commits
listed in section 5 use this categorisation as their work plan.

## 1. Run summary

Commands (executed from the `anal` repo root):

```sh
fvm dart run anal --rules unused_function /home/lezli/projects/momminess > /tmp/anal-momminess.txt 2>&1 || true
fvm dart run anal /home/lezli/projects/momminess > /tmp/anal-momminess-default.txt 2>&1 || true
```

- `anal` version under test: `0.3.4` (from
  [bin/anal.dart](../bin/anal.dart) `_version`).
- `momminess` commit: `bae65a74e0f923aa30875d8891073b54df480a11`
  (HEAD at investigation time).
- Total diagnostics emitted by the rule-only run: **4618**
  `unused_function` warnings.
- Control (default-config) run: **4618** `unused_function` warnings
  plus 1 `unused_class` and 7 `unused_source_file` — i.e. the
  `unused_function` count is unchanged when other bundled rules are
  enabled, so the noise is genuinely attributable to this rule.
- Concentration: 2871 of the 4618 findings (≈62 %) live in three
  generated localization files (`lib/core/l10n/l10n.dart`,
  `l10n_en.dart`, `l10n_hu.dart`). The remaining 1747 are spread
  across 410 source and test files.

True-positive vs false-positive estimate (based on the sampling in
section 3): roughly **5 – 8 % true positives, 92 – 95 % false
positives**. The estimate is conservative — every category in
section 3 represents reachable code by construction, and the bulk
buckets (l10n, framework-callback overrides, mocktail-Fake test
doubles, abstract-base override dispatch) are each demonstrably
reachable. Some genuinely dead helpers do exist (section 4) but they
are a small share of the noise.

## 2. Methodology

- Both runs were executed with the bare `momminess` working tree at
  the commit above. No `build_runner` was invoked; the only generated
  artefacts considered are those already on disk
  (`*.g.dart`, `*.freezed.dart`, `lib/core/l10n/l10n*.dart`).
- The raw rule-only output was bucketed by containing file (`grep |
  sort | uniq -c`) and by flagged identifier
  (`The (method|getter|setter) "<name>"`) to locate concentration
  points. Each concentration was opened in source and inspected:
  - whether the flagged declaration is reached via a documented Dart
    language feature the rule does not currently model;
  - whether reachability can be proved by a literal grep in the
    momminess tree (e.g. `grep -rn '\.foo(' lib/ test/`);
  - which collector under
    [lib/src/rules/unused_function/](../lib/src/rules/unused_function/)
    or which helper in
    [lib/src/rules/unused_function_rule.dart](../lib/src/rules/unused_function_rule.dart)
    is responsible.
- "False positive" here means: the declaration is reachable in a real
  build of momminess on at least one platform, but the rule reports
  it as unused. Truly dead helpers that no caller in `lib/` or
  `test/` references are counted as true positives (section 4).
- Caveats:
  - Counts are approximate; only concentration points were sampled
    exhaustively. Long-tail single-file findings (one or two per
    file) are not categorised individually.
  - The investigation does **not** consider build-time codegen
    (`build_runner` was not run); generated files that ship in the
    tree are in scope, ungenerated ones are not.
  - The investigation does **not** verify against multiple Flutter
    platform targets (mobile / web / desktop). Conditional-import
    branches are assessed structurally only.

## 3. False-positive categories

### 3.1 Generated `flutter gen-l10n` localization output

- **Language feature link:** LANGUAGE.md §3 Generated Code; CLAUDE.md
  *"Mirrors / reflection / entry-point annotations (build-time
  codegen annotations)"* (closest existing bullet — Flutter's
  `gen_l10n` is a build-time codegen pipeline whose output is
  reachable through its public class hierarchy).
- **Symptom:** ~2871 warnings clustered in
  `lib/core/l10n/l10n.dart`, `lib/core/l10n/l10n_en.dart`, and
  `lib/core/l10n/l10n_hu.dart`. Each flagged declaration is either an
  abstract getter on the synthetic `L` class or a concrete getter on
  the per-locale subclass `LEn` / `LHu`.
- **Why it's wrong:** these three files are generated end-to-end by
  Flutter's `gen_l10n` tool driven by `l10n.yaml` plus the
  `arb-dir`-side `.arb` resources. Users do not own them, cannot
  hand-edit them, and the unflagged subset is regenerated on every
  build. The "unused" getters are intentional — they are the
  translation surface keyed off the ARB files. The tool stamps the
  file with `// ignore_for_file: type=lint` to mark its generated
  status.
- **Evidence:**

  `lib/core/l10n/l10n.dart`
  ```dart
  // ignore_for_file: type=lint

  /// Callers can lookup localized strings with an instance of L
  /// returned by `L.of(context)`.
  ```

  `lib/core/l10n/l10n_en.dart:31`
  ```dart
  @override
  String get admin_author_json => 'Author JSON';
  ```

  `lib/core/l10n/l10n_hu.dart:31`
  ```dart
  @override
  String get admin_author_json => 'Szerző JSON';
  ```
- **Estimated count / share:** ~2871 of 4618 (~62 %).
- **Suspected fix locus:** the dispatch site in
  [unused_function_rule.dart](../lib/src/rules/unused_function_rule.dart)
  `analyze` (lines 127–183). The rule currently has no exemption for
  generated files. Either honour a generated-code marker (a
  per-package list of glob patterns, or the de-facto Dart marker
  `// ignore_for_file: type=lint` at the top of the file), or add a
  dedicated `gen_l10n` exemption keyed on the `arb-dir` /
  `output-localization-file` declared in `l10n.yaml`. Mirrors the
  build-time-codegen exemption already promised by LANGUAGE.md §3 but
  not yet implemented by `unused_function`.

### 3.2 Framework lifecycle methods overridden by widget / notifier subclasses

- **Language feature link:** CLAUDE.md *"Dynamic dispatch
  (dynamic/Object? receivers)"* + LANGUAGE.md §6 Dynamic Dispatch
  (the Flutter element tree holds widgets as their base type and
  invokes the override through virtual dispatch).
- **Symptom:** 551 warnings of the form
  `The method "build" is declared but never used.` (340) plus
  `createState` (141), `initState` (40), `dispose` (21),
  `didUpdateWidget` (9) — typically with the offending declaration
  being `@override`-annotated on a `StatelessWidget`,
  `StatefulWidget`, `ConsumerWidget`, `State`, or `Notifier`
  subclass.
- **Why it's wrong:** Flutter never names `MyWidget.build` directly —
  it holds the widget as `StatelessWidget` / `Widget` and dispatches
  through `Element` machinery. Same for `State.initState` /
  `dispose` / `didUpdateWidget` (called by the framework on the
  state) and `Notifier.build` (called by Riverpod on the resolved
  provider). The override only ever flows through virtual dispatch
  on the framework-held supertype reference, and the static
  reference set never contains the subclass's member.
- **Evidence:**

  `lib/ui/core/theme/responsive.dart:27`
  ```dart
  abstract class ResponsiveStatelessWidget extends StatelessWidget {
    const ResponsiveStatelessWidget({super.key});

    @override
    Widget build(BuildContext context) {
      // … dispatches to buildDesktop/buildMobile/buildTablet
    }
  }
  ```

  `test/ui/wiki/wiki_recommends/wiki_recommendations_expansion_view_test.dart:35`
  ```dart
  class _TestAuthStateNotifier extends AuthStateNotifier {
    @override
    Future<AuthState> build() async => const AuthState();
  }
  ```
- **Estimated count / share:** ~551 of 4618 (~12 %), or ≈31 % of the
  non-l10n noise.
- **Suspected fix locus:**
  [class_member_collector.dart](../lib/src/rules/unused_function/class_member_collector.dart)
  `_candidateFor`. Add an exemption for declarations carrying an
  `@override` annotation **whose overridden member is reachable**: if
  the supertype member is in `globalReferences` (or is declared in a
  package outside the analysed set, i.e. dart:* / package:flutter
  framework code), the override is reachable via virtual dispatch and
  must not be flagged. Equivalent reasoning extends to operator and
  getter overrides (§3.6).

### 3.3 Abstract-base virtual dispatch (subclass overrides of in-repo abstract members)

- **Language feature link:** LANGUAGE.md §6 Dynamic Dispatch (same
  root cause as 3.2, restricted to in-repo base classes); also
  partial overlap with LANGUAGE.md §10 Mixins for `with`-clause
  members.
- **Symptom:** large counts on identifiers that name abstract members
  of in-repo base classes — `buildWithViewModel` (78),
  `viewModelProvider` (79), `migrations` (44), `currentVersion`
  (43), `migrate` (31), `initWithViewModel` (36), `buildTablet`
  (25), `buildDesktop` (22), `buildMobile`, `createDefault`,
  `assertModel`, `setOnboarded`, `signOut`, `invalidate`,
  `getRecommendations`, etc. Each is an `abstract` (or `@override`)
  member on a class that extends one of the project's framework
  scaffolds (`ModelConsumerWidget`, `ToolViewModel`,
  `ModelMigrator`, `AuthStateNotifier`, `ResponsiveStatelessWidget`,
  …) where the base class only invokes them through `this`.
- **Why it's wrong:** the base class names `viewModelProvider()` and
  `buildWithViewModel(...)` only as `this.viewModelProvider()` etc.
  Those calls resolve to the *abstract* base member, which is the
  one that lands in `globalReferences`. The subclasses' concrete
  overrides are reached purely through virtual dispatch and are
  never the resolved element of any `MethodInvocation` /
  `PropertyAccess` / `SimpleIdentifier` in the source.
- **Evidence:**

  `lib/ui/core/model_consumer.dart:28`
  ```dart
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var provider = viewModelProvider();
    // …
    return buildWithViewModel(context, ref.watch(provider.provider));
  }

  Widget buildWithViewModel(BuildContext context, TViewModel viewModel);
  ViewModelProvider<TViewModel> viewModelProvider();
  ```

  `lib/data/models/model_migrator.dart:11`
  ```dart
  abstract class ModelMigrator<T extends Model> {
    int get currentVersion;
    Map<int, ModelMigration<T>> get migrations;

    Map<String, dynamic> migrate(Map<String, dynamic> data) {
      if (currentVersion != migrations.length + 1) { … }
    }
  }
  ```

  `lib/ui/tools/core/tool_view_model.dart:13`
  ```dart
  T createDefault(String id, String userId);
  ```
- **Estimated count / share:** ~500 – 700 of 4618 (≈11 – 15 %)
  across the abstract-base override surface — a hard count is
  difficult because the same identifiers appear in many subclasses.
- **Suspected fix locus:** same as 3.2 —
  [class_member_collector.dart](../lib/src/rules/unused_function/class_member_collector.dart).
  An "override-of-referenced-supertype-member is a use" rule covers
  both 3.2 and 3.3. Implementation can read the supertype member via
  the analyzer's `inheritance` manager and check membership in
  `globalReferences`.

### 3.4 Members of `Mock` / `Fake` test doubles (transitive `noSuchMethod`)

- **Language feature link:** CLAUDE.md *"noSuchMethod"* / LANGUAGE.md
  §7 noSuchMethod.
- **Symptom:** ~550 warnings under `test/`, the bulk of them on
  declarations inside `class _FakeX extends Fake implements Y { … }`
  bodies — methods on the fake are flagged as unused even though the
  fake's whole purpose is to satisfy the production-side static
  surface.
- **Why it's wrong:** the rule already exempts members of a class
  that *itself* declares `noSuchMethod`
  ([unused_function_rule.dart:269 `_membersDeclareNoSuchMethod`](../lib/src/rules/unused_function_rule.dart#L269)),
  but it only inspects the **own members** of the class
  declaration — not its supertypes. `mocktail`'s `Fake` and `Mock`
  base classes are the canonical providers of `noSuchMethod`, and
  test doubles always extend them rather than declaring
  `noSuchMethod` themselves. The exemption therefore misses every
  realistic mocktail-style test double.
- **Evidence:**

  `test/ui/settings/settings_view_test.dart:51`
  ```dart
  class _FakeSettingsViewModel extends Fake implements SettingsViewModel {
    @override
    UserSettingsModel getSettings() => _settings;
  }
  ```

  `test/ui/tools/tools_view_test.dart` (typical body)
  ```dart
  class _FakeToolsViewModel extends Fake implements ToolsViewModel {
    @override
    List<ToolMeta> relevantPregnancyTools() => …;
  }
  ```
- **Estimated count / share:** large share of the 550 `test/`
  findings — sampled files (`settings_view_test.dart` 17,
  `main_view_test.dart` 17, `subscription_view_test.dart` 16,
  `profile_view_test.dart` 14, `tools_view_test.dart` 8) all hit
  this pattern. Rough estimate: ~300 – 400 of 4618 (≈7 – 9 %).
- **Suspected fix locus:** the `_membersDeclareNoSuchMethod` helper
  in [unused_function_rule.dart:269](../lib/src/rules/unused_function_rule.dart#L269)
  and the two callers in
  [class_member_collector.dart](../lib/src/rules/unused_function/class_member_collector.dart)
  / [constructor_collector.dart](../lib/src/rules/unused_function/constructor_collector.dart).
  Walk the supertype chain (`extends` + `with` + `implements`) and
  return `true` if **any** reachable ancestor declares
  `noSuchMethod`. Practically, recognising `package:mocktail`'s
  `Fake`/`Mock` (and `dart:core`'s implicit `noSuchMethod`
  override-marker via abstract API) by name is a sufficient first
  iteration.

### 3.5 Implicit super-constructor invocation (`super.x` forwarding)

- **Language feature link:** *Unclassified — needs LANGUAGE.md
  entry.* The closest existing match is LANGUAGE.md §18 Factory
  Constructors (constructor flow), but super-parameter forwarding
  (Dart 2.17+) is structurally distinct and is not currently called
  out in either LANGUAGE.md or CLAUDE.md.
- **Symptom:** ~157 `unused_function: The constructor "X"` warnings,
  many of them on abstract base widget classes whose only call sites
  are subclass constructors that use `super.key` (no explicit
  `super(...)` call). Examples:
  `ResponsiveStatelessWidget` (responsive.dart:23),
  `ResponsiveConsumerWidget` (responsive.dart:68),
  `ResponsiveModelConsumerWidget` (responsive.dart:113),
  `ModelConsumerWidget` (model_consumer.dart:24).
- **Why it's wrong:** when a subclass writes `const SubPromoView({…,
  super.key});` the constructor body still implicitly invokes the
  super constructor — that's how a Dart instance gets initialised.
  But the AST has no `SuperConstructorInvocation` node for it (the
  forwarding is expressed only through `super.x` parameters), so
  [`_GlobalReferenceCollector.visitSuperConstructorInvocation`](../lib/src/rules/unused_function_rule.dart#L379)
  never fires for these subclasses and the base constructor's
  element is never added to the reference set.
- **Evidence:**

  `lib/ui/core/theme/responsive.dart:23`
  ```dart
  abstract class ResponsiveStatelessWidget extends StatelessWidget {
    const ResponsiveStatelessWidget({super.key});
  }
  ```

  `lib/ui/core/ui/sub_promo_view.dart:15`
  ```dart
  class SubPromoView extends ResponsiveStatelessWidget {
    const SubPromoView({
      required this.title,
      // …
      super.key,
    });
  }
  ```
- **Estimated count / share:** subset of the 157 constructor
  warnings; on sampled files most constructor false positives trace
  back to either this category or 3.6. Conservative estimate:
  ~80 – 120 of 4618 (~2 – 3 %).
- **Suspected fix locus:** the `_GlobalReferenceCollector` in
  [unused_function_rule.dart:337](../lib/src/rules/unused_function_rule.dart#L337).
  Add a hook that, for each `ConstructorDeclaration` AST node
  visited, also records the *implicit* super-constructor target
  (read it off the analyzer-resolved fragment when the body has no
  explicit `super` invocation). Should also handle the
  no-`super`-call case for default subclass constructors that have
  no source body of their own (e.g. mixin compositions).

### 3.6 Enum constructors invoked by enum-value declarations

- **Language feature link:** LANGUAGE.md §18 Factory Constructors
  (closest match — enum constants are constructor-form constants);
  CLAUDE.md *"Const evaluation"* (each enum value is a const
  invocation of the enum's constructor).
- **Symptom:** constructor-declaration warnings on enums that take
  arguments. The enum's own `const Foo(this.x)` constructor is
  flagged even though every enum value (`bar('/bar')`,
  `baz('/baz')`, …) invokes it.
- **Why it's wrong:** in the analyzer AST, enum values are
  `EnumConstantDeclaration` nodes carrying their own
  `EnumConstantArguments`. They are not represented as
  `InstanceCreationExpression` / `ConstructorName`, so the rule's
  visitors don't fire on them and the enum's constructor element is
  never added to `globalReferences`. The enum's constructor is, in
  practice, always called — by every constant the enum declares.
- **Evidence:**

  `lib/core/router/routes.dart:46`
  ```dart
  enum CRoute {
    action('/action'),
    iosInstall('/ios_install'),
    // …
    const CRoute(this.path);
  }
  ```
- **Estimated count / share:** small absolute count (a handful of
  enums in lib/`), but every project-defined parameterised enum
  triggers it. ~5 – 15 of 4618.
- **Suspected fix locus:** the `_GlobalReferenceCollector` in
  [unused_function_rule.dart:337](../lib/src/rules/unused_function_rule.dart#L337).
  Add `visitEnumConstantDeclaration` (or `visitEnumConstantArguments`)
  that records the resolved constructor element. Alternative locus:
  [constructor_collector.dart](../lib/src/rules/unused_function/constructor_collector.dart)
  could skip constructor candidates whose enclosing element is an
  `EnumElement` with at least one constant declaration — slightly
  less precise but simpler.

### 3.7 Generic-class member identity (substituted vs declared element)

- **Language feature link:** CLAUDE.md *"Generic covariance and
  inference"* (verbatim: *"inferred type arguments still resolve to
  declared members. Follow the *declared* member on the *static*
  type — do not require explicit type arguments to consider a
  generic member referenced."*); LANGUAGE.md §6 Dynamic Dispatch
  (overlaps when the receiver is a generic subclass).
- **Symptom:** members declared on generic classes — e.g. methods on
  `Repository<T extends FirestoreModel>` such as `create`,
  `createOrUpdate`, `queryWhere`, `read`, `update`, … — are flagged
  even though the project has many subclasses
  (`UserRepository extends Repository<UserModel>`, etc.) whose
  callers do `userRepository.create(model)`. Same shape for the
  freezed-generated factory constructors on generic sealed
  classes — `ViewModelProvider.async`, `ViewModelProvider.sync`,
  `ViewModelProvider.direct` are flagged at
  `lib/ui/core/model_consumer.dart:12` / `:16` / `:20` despite
  having many call sites elsewhere in `lib/`.
- **Why it's wrong:** when the analyzer resolves a member on a
  generic type with substituted type arguments, the resolved
  `Element` can be a "member view" wrapper around the declared
  element rather than the declared element itself. The rule's
  candidate set uses `declaration.declaredFragment?.element` (the
  declared one); the reference set ends up holding the
  member-view. `Set<Element>.contains` does not consider the two
  equal, so the call-site reference fails to count.
- **Evidence:**

  `lib/data/repositories/repository.dart:55`
  ```dart
  class Repository<T extends FirestoreModel> {
    Future<bool> create(T model) async { … }
    Future<bool> createOrUpdate(T model) async { … }
    // … all flagged unused
  }
  ```

  `lib/ui/core/model_consumer.dart:13`
  ```dart
  const factory ViewModelProvider.async({
    required ProviderBase<AsyncValue<TViewModel>> provider,
  }) = AsyncProvider;
  ```
  …with call sites such as
  `lib/ui/share_pregnancy/share_pregnancy_view.dart:559`:
  ```dart
  return ViewModelProvider.async(provider: sharePregnancyViewModelProvider);
  ```
- **Estimated count / share:** hard to bound precisely — many of the
  `Repository` / `tool_view_model.dart` / `ViewModelProvider` /
  generic notifier findings flow through this. Rough estimate:
  ~150 – 300 of 4618 (~3 – 7 %).
- **Suspected fix locus:** the `_add` helper in
  [unused_function_rule.dart:342](../lib/src/rules/unused_function_rule.dart#L342)
  (and matching candidate construction in the per-collector files).
  Normalise to the declared element before insertion / lookup —
  e.g. `sink.add(element.baseElement ?? element)` and likewise when
  building the candidate. Equivalent: store candidates keyed by the
  `nonGenericElement` / `declaration` projection. Whichever
  direction is chosen, both sides must use the same projection.

### 3.8 Long-tail / unclassified

A residual ~50 – 100 findings scattered one or two per file did not
fit any of 3.1 – 3.7 cleanly on quick inspection. Likely subcategories
to investigate in a follow-up pass:

- Operators (`==`, `<`, `>`, etc.) declared as `@override` of
  framework supertypes such as `Object.==`. Same shape as 3.2 / 3.3
  but on operator tokens — covered once the override-of-supertype
  fix lands.
- `_FakeContext` and similar internal `_`-prefixed test scaffolds
  whose only use is as a runtime instance held by mocktail-style
  helpers (also touches 3.4).
- Members of public classes in public-surface files
  (`lib/<not src>/…`) where the rule has no reachability signal —
  see also section 4.

## 4. True-positive sample

Three findings that look like genuinely dead code and should remain
flagged once the fixes in section 5 land. Listed so a regression
audit can re-run after each fix and confirm signal isn't lost.

- `lib/core/utils/wiki_glob_builder.dart:59` — `WikiGlob.childAge1to3`
  getter (and siblings `infertility`, `interested` at :61 / :63):
  every grep for `\.childAge1to3` / `\.infertility` /
  `\.interested` in `lib/` and `test/` outside this file resolves to
  `Category.childAge1to3` (a different enum), never to the
  `WikiGlob` getter. The builder surface declares more methods than
  the app actually consults.
- `lib/core/brevo_client.dart:6` — `sendPreSignUpEmail` static
  method. The whole file is also flagged by `unused_source_file` in
  the default-config run (no other file imports it), corroborating
  that the helper is genuinely dead.
- `lib/core/analytics.dart:64` — `signUpVerified` static method on
  the analytics helper. No call site exists in `lib/` or `test/`;
  paired with the related l10n key `sign_up_verified` (also flagged
  in §3.1, but for the unrelated localization-getter reason) this
  appears to be a stale analytics hook for a flow that was removed.

## 5. Prioritised follow-up work

Ordered so that the highest-impact, smallest-surface fix lands first.
Each entry names the category resolved, the rough impact, and the
sample-side test cases that must accompany the fix per
[CLAUDE.md](../CLAUDE.md) "Sample Projects" rule.

1. **`fix: exempt `flutter gen-l10n` generated localization output`**
   - Category: 3.1
   - Impact: removes ~2871 of 4618 findings (~62 %).
   - Sample updates required:
     - new negative case under
       `samples/unused_function/lib/` that adds a minimal
       `// ignore_for_file: type=lint`-marked
       `output-localization-file`-style file (one abstract `L`
       class, two locale subclasses, one unreferenced getter on each)
       and a sibling `l10n.yaml`-style cue if the chosen detection
       heuristic needs one;
     - mirror the same file into
       `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart) to
       assert the new file emits zero diagnostics.

2. **`fix: treat overrides of reachable supertype members as uses`**
   - Categories: 3.2 + 3.3 + the operator slice of 3.8.
   - Impact: removes ~550 (framework lifecycle) + ~500 – 700
     (in-repo abstract-base virtual dispatch) ≈ **~1050 – 1250** of
     4618 (~23 – 27 %).
   - Sample updates required:
     - negative case: a `MyWidget extends StatelessWidget` whose
       `@override Widget build(...)` must not be flagged because
       `StatelessWidget.build` is reachable from
       package:flutter;
     - negative case: an in-repo `abstract class Base { void hook();
       void run() { hook(); } }` plus `class Sub extends Base { void
       hook() { … } }` where `Sub.hook` must not be flagged;
     - positive case: an `@override` of a supertype member that is
       **itself** unused (so the override stays flagged) —
       guarantees the fix does not silently widen the exemption to
       all overrides;
     - copy the three cases into `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart).

3. **`fix: walk supertype chain for `noSuchMethod` exemption`**
   - Category: 3.4.
   - Impact: removes ~300 – 400 of 4618 (~7 – 9 %), almost entirely
     under `test/`.
   - Sample updates required:
     - negative case: `class _Fake extends Fake implements Service
       { … }` (where a project-local stand-in for `mocktail.Fake`
       declares its own `noSuchMethod`) — every member of `_Fake`
       must not be flagged;
     - same scenario via `implements`-only and via a two-hop
       extension chain to lock the supertype walk;
     - copy into `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart).

4. **`fix: normalise generic member identity in reference tracking`**
   - Category: 3.7.
   - Impact: removes ~150 – 300 of 4618 (~3 – 7 %), critically
     including the `Repository<T>` and freezed-generic-factory
     buckets.
   - Sample updates required:
     - negative case: `class Box<T> { void put(T v) {} } class
       IntBox extends Box<int> { … }` plus a top-level call
       `IntBox().put(0)` — `Box.put` must not be flagged;
     - negative case: a freezed-style generic sealed class with
       redirecting factory constructors and a generic call site;
     - copy into `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart).

5. **`fix: record implicit super-constructor invocation as a use`**
   - Category: 3.5.
   - Impact: removes ~80 – 120 of 4618 (~2 – 3 %).
   - Sample updates required:
     - negative case: `abstract class A { A({this.x = 0}); final int
       x; } class B extends A { B({super.x}); }` plus `B(x: 1)` at
       a call site — `A`'s constructor must not be flagged;
     - copy into `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart);
     - also fold this into LANGUAGE.md as a new "Super-parameter
       forwarding" section (the current document does not list it).

6. **`fix: treat enum-value declarations as uses of the enum
   constructor`**
   - Category: 3.6.
   - Impact: removes ~5 – 15 of 4618 (~0.2 %).
   - Sample updates required:
     - negative case: `enum E { a('a'), b('b'); const E(this.v);
       final String v; }` — `E` constructor must not be flagged;
     - copy into `samples/all_rules/`;
     - update [test/samples_test.dart](../test/samples_test.dart).

7. **`fix: re-audit residual long-tail (`==` overrides etc.)`**
   - Category: 3.8.
   - Impact: small (~50 – 100), but the residue should be
     re-bucketed once 1 – 6 land to expose any further missed
     language feature.
   - No sample changes until categorisation is complete.

## 6. Out of scope

- **Modifying the rule, its samples, or
  [test/samples_test.dart](../test/samples_test.dart) in this
  commit.** This run is the design input for the `fix:` commits in
  section 5; the actual changes ship as separate commits per the
  story's scope discipline.
- **Re-running `build_runner` in momminess.** The investigation
  reads only generated artefacts already on disk; any false
  positives flowing through ungenerated codegen (e.g. a fresh
  `freezed` regeneration that would emit different class shapes)
  are not assessed.
- **Platform-target sensitivity.** Conditional imports
  (LANGUAGE.md §1) were not investigated end-to-end on the multiple
  Flutter targets. The rule's existing single-branch handling is
  assumed sufficient for this report.
- **`unused_class` and `unused_source_file` findings on momminess.**
  The default-config run surfaced 1 + 7 of those, which are
  potentially related but belong to those rules' own
  investigations.
- **Performance of the rule on a project this size.** Both runs
  complete in well under a minute; no perf gate was applied.
- **Momminess-side cleanups.** Any genuinely dead code surfaced in
  section 4 is for the momminess maintainers to act on, not for
  `anal`.
