// ignore_for_file: type=lint

// Per-locale subclass of the synthetic `L` base class, mirroring what
// Flutter's `gen_l10n` emits for every locale listed in `l10n.yaml`.
// The `// ignore_for_file: type=lint` marker at the top of the file
// flags this unit as generated; the `unused_function` rule skips
// every candidate collector for the unit and so does not flag the
// concrete `@override` getters below.

import 'l10n.dart';

/// English-locale subclass. Real `gen_l10n` output extends the
/// synthetic `L` base with per-locale concrete getters that return
/// the localized string for each ARB message.
class LEn extends L {
  /// (N12) Concrete `@override` getter on a per-locale subclass.
  /// Without the `type=lint` exemption, the `unused_function` rule
  /// would flag this declaration because no caller in the analyzed
  /// set ever names `LEn().adminAuthorJson` — `gen_l10n`'s callers
  /// always go through `L.of(context)` on the abstract base. The
  /// marker at the top of the file exempts every candidate in the
  /// unit.
  @override
  String get adminAuthorJson => 'Author JSON';

  /// (N12) Second concrete `@override` getter — exempted by the
  /// unit-level marker for the same reason.
  @override
  String get adminAuthorTitle => 'Author';
}
