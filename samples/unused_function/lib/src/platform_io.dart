// (N22) IO branch of the conditional export declared in
// `platform_export.dart`. On the VM the analyzer resolves the export to
// this file, but it is also named in an `if (dart.library.io)`
// configuration, so the `unused_function` rule treats the whole file as
// a conditional-export branch target and skips every candidate declared
// here.
//
// The public top-level function and the public class members below sit
// under `lib/src/`, so they are NOT covered by the public-members-
// outside-`lib/src/` exemption — the ONLY reason they are not flagged is
// the conditional-export branch-target exemption. Without it, every
// member here would be a candidate with no reference in the analyzed
// set.
//
// ignore_for_file: unused_element
library;

/// Platform label reported by the IO implementation.
String platformLabel() => 'io';

/// Platform service exposed through the conditional export surface.
class PlatformService {
  /// Starts the platform service.
  void start() {}

  /// Disposes the platform service.
  void dispose() {}
}
