# native/ — the libgit2 C bridge

This is the flat C ABI wrapper around libgit2 described in the implementation
plan's Appendix A/C. It's the one canonical copy of the bridge source; both
the Android build (`packages/git2_bridge/android/`, via
`native/CMakeLists.txt`) and the iOS build
(`packages/git2_bridge/ios/git2_bridge.podspec`) compile these same files
rather than forking a copy per platform.

- `include/git_bridge.h` — the public C API. This is also the ffigen
  entry point (`packages/git2_bridge/ffigen.yaml`) that generates the Dart
  FFI bindings.
- `src/git_bridge.c` — the implementation.
- `test/smoke_test.c` — a standalone C program exercising every function
  (clone/status/stage/commit/push/pull/tree/head-info/unpushed-count) against
  a real `file://` git remote. No mocking — this is real libgit2, real
  on-disk repos.

## Running the tests

Two layers, both runnable on a plain Linux/macOS dev machine — neither needs
a phone, emulator, or mobile SDK:

```sh
# Pure C: compiles git_bridge.c against the host's libgit2 and runs
# native/test/smoke_test.c. Validates the bridge logic itself.
../scripts/native_smoke_test.sh

# Dart FFI: additionally exercises dart:ffi struct marshaling,
# Isolate.run, and the NativeCallable.listener progress-callback path —
# bugs in *that* plumbing (there was a real one — see git history around
# gb_free_progress) don't show up in the C-only test above.
../scripts/dart_ffi_smoke_test.sh
```

Both require `libgit2-dev` (`apt install libgit2-dev` on Debian/Ubuntu,
`brew install libgit2` on macOS).

## Building for Android / iOS

Neither is exercised by the scripts above — both need vendoring libgit2 +
mbedTLS for the target platform, which needs a real Android NDK or Xcode:

- Android: `packages/git2_bridge/android/build.gradle` points its
  `externalNativeBuild` at `native/CMakeLists.txt`, which `FetchContent`s and
  builds libgit2 + mbedTLS itself. Building the app (`flutter build apk`)
  with the Android NDK installed builds this automatically — no manual step.
- iOS: run `packages/git2_bridge/ios/Scripts/build_libgit2_xcframework.sh`
  once on a Mac with Xcode to produce
  `packages/git2_bridge/ios/Frameworks/{libgit2,mbedtls}.xcframework`, which
  `git2_bridge.podspec` then vendors. `pod install` fails with a clear error
  until this has been run once.

## Ownership / memory rules a caller must follow

- `char*` output params (`gb_get_status`, `gb_get_file_tree`,
  `gb_get_head_info`) — free with `gb_free_string`.
- `gb_progress*` passed to a `gb_progress_cb` — free with
  `gb_free_progress`. This one is heap-allocated *per call* (not reused)
  specifically because delivery across the Dart FFI boundary
  (`NativeCallable.listener`) is asynchronous: the native thread doesn't
  block waiting for Dart to read it, so a stack-local or reused struct would
  be a use-after-scope race. (This was a real bug caught by
  `dart_ffi_smoke_test.sh`, not a hypothetical one.)
