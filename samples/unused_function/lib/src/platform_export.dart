// (N22) Conditional-export wrapper.
//
// This file is the public export surface for a platform-specific
// implementation. The conditional export below names `platform_io.dart`
// and `platform_web.dart` in its `if (...)` configurations. The analyzer
// resolves the directive to exactly ONE branch for the current build
// target (on the VM that is `platform_io.dart`), so declarations and
// members in the *non-selected* branch — `platform_web.dart` here — are
// reached only through this wrapper's export surface and look
// unreferenced.
//
// The `unused_function` rule collects the file path of every
// configuration branch URI of an export/import directive across the
// analyzed unit set and skips every candidate declared in such a file:
// the whole branch file is treated as part of the platform export
// surface. Both `platform_io.dart` and `platform_web.dart` are listed as
// `if (...)` configurations, so members of neither file are flagged.
//
// The wrapper itself declares nothing, so it contributes no candidates;
// it is imported from the sample's entry point purely so the
// `unused_source_file` rule sees it (and the branch files it points at)
// as reachable.
export 'platform_io.dart'
    if (dart.library.io) 'platform_io.dart'
    if (dart.library.html) 'platform_web.dart';
