part of '../unused_function_rule.dart';

/// Internal seam shared by candidate collectors that need to skip
/// declarations participating in an override relationship.
///
/// For an executable that is declared inside an [InterfaceElement] (a
/// class or mixin), this returns `true` when at least one supertype,
/// mixin, interface, or `on`-clause constraint already declares a
/// member that the executable would override or implement. Such members
/// are part of an API surface dictated by the supertype, so the rule
/// should never flag them as "declared but never used".
///
/// Resolution uses [InterfaceElement.getOverridden], which understands
/// the analyzer's distinction between getter and setter [Name]s — a
/// getter and a same-named setter resolve as separate inheritance
/// lookups.
bool _overridesSupertypeMember(ExecutableElement element) {
  final enclosing = element.enclosingElement;
  if (enclosing is! InterfaceElement) return false;
  final lookupName = Name.forElement(element);
  if (lookupName == null) return false;
  final overridden = enclosing.getOverridden(lookupName);
  return overridden != null && overridden.isNotEmpty;
}
