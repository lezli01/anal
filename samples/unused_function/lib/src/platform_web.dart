// (N22) Web branch of the conditional export declared in
// `platform_export.dart`. On the VM the analyzer resolves the export to
// `platform_io.dart`, so this NON-selected branch is never imported
// directly — its members are reached only through the wrapper's export
// surface and look unreferenced.
//
// Because this file is named in an `if (dart.library.html)`
// configuration of the export, the `unused_function` rule treats the
// whole file as a conditional-export branch target and skips every
// candidate. The public top-level function and the public class members
// below live under `lib/src/`, so they are NOT covered by the
// public-members-outside-`lib/src/` exemption — the conditional-export
// branch-target exemption is the only reason they are not flagged.
//
// ignore_for_file: unused_element
library;

/// Platform label reported by the web implementation.
String platformLabel() => 'web';

/// Platform service exposed through the conditional export surface.
class PlatformService {
  /// Starts the platform service.
  void start() {}

  /// Disposes the platform service.
  void dispose() {}
}
