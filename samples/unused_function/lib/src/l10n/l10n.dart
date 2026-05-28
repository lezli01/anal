// ignore_for_file: type=lint

// Mock of the output that Flutter's `gen_l10n` tool stamps into the
// `output-localization-file` (typically `lib/<…>/l10n.dart`) for every
// Flutter project that defines an `l10n.yaml`. Real `gen_l10n` output
// declares the synthetic abstract `L` base class with one abstract
// getter per ARB message, and a sibling per-locale subclass per
// supported locale. Both are end-to-end generated, regenerated on
// every build, and consumers neither own them nor reference every
// declared key — flagging their declarations as "unused" is always
// noise, never signal.
//
// The first non-empty line of the file is the de-facto Dart marker
// `// ignore_for_file: type=lint` that `gen_l10n` and other build-time
// codegen tools stamp on the top of every emitted file. The
// `unused_function` rule treats that marker as a "this unit is
// generated; do not flag anything in it" signal and skips every
// candidate collector for the unit. Without the exemption, every
// abstract getter on `L` and every concrete `@override` getter on a
// subclass below would be reported as unused — the false-positive
// pattern catalogued in `doc/unused_functions.md` §3.1.

/// Synthetic, generated localization base class. Real `gen_l10n`
/// output adds one abstract getter per ARB message.
abstract class L {
  /// (N12) Abstract getter on the synthetic `L` class. Without the
  /// `type=lint` exemption, the `unused_function` rule's class-member
  /// collector would flag every abstract getter declared here as
  /// unused, because no caller in the analyzed set ever names them.
  /// The marker at the top of the file makes the rule skip every
  /// candidate in the unit, so none of these are flagged.
  String get adminAuthorJson;

  /// (N12) Second abstract getter on `L`. Same reasoning as above —
  /// exempted by the unit-level marker.
  String get adminAuthorTitle;
}
