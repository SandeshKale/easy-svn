import 'dart:ffi';
import 'dart:io';

import 'git2_bridge_bindings_generated.dart';

/// Loads the compiled bridge library for the current platform and
/// returns generated bindings over it.
///
/// - Android: `libgit_bridge.so`, bundled as a jniLib by the Android
///   Gradle plugin from `android/CMakeLists.txt`.
/// - iOS: statically linked into the app binary by CocoaPods (see
///   `ios/git2_bridge.podspec`), so symbols are resolved against the
///   process image rather than a dynamically loaded file.
/// - Linux (desktop / this repo's smoke tests): `libgit_bridge.so`
///   next to the executable, or the system search path.
Git2BridgeBindings loadGit2Bridge() {
  final lib = _open();
  final bindings = Git2BridgeBindings(lib);
  // git_libgit2_init() is ref-counted process-wide, so calling this on
  // every isolate that loads the library (each Isolate.run spins up a
  // fresh one — see git2_bridge.dart) is safe and cheap; libgit2
  // requires it before any other gb_* call.
  bindings.gb_global_init();
  return bindings;
}

DynamicLibrary _open() {
  if (Platform.isIOS || Platform.isMacOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libgit_bridge.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('git_bridge.dll');
  }
  throw UnsupportedError(
    'git2_bridge has no native library mapping for ${Platform.operatingSystem}',
  );
}
