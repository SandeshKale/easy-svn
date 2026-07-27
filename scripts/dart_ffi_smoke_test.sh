#!/usr/bin/env bash
# End-to-end check of the Dart side of the bridge: compiles
# native/src/git_bridge.c against the host's libgit2 into a
# libgit_bridge.so, then runs packages/git2_bridge/test/manual_ffi_smoke.dart
# against it via plain `dart run` (no Android/iOS toolchain needed).
#
# This exercises the whole path scripts/native_smoke_test.sh does NOT:
# dart:ffi struct marshaling, Isolate.run, and the NativeCallable.listener
# progress-callback bridge across isolates — real bugs in that plumbing
# (e.g. use-after-scope on the progress struct) only show up here, not
# in the pure-C test.
set -euo pipefail
cd "$(dirname "$0")/.."

LIBDIR=$(mktemp -d)
trap 'rm -rf "$LIBDIR"' EXIT

gcc -shared -fPIC -O2 \
  -I native/include \
  native/src/git_bridge.c \
  -o "$LIBDIR/libgit_bridge.so" \
  $(pkg-config --cflags --libs libgit2)

cd packages/git2_bridge
dart pub get >/dev/null
LD_LIBRARY_PATH="$LIBDIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  dart run test/manual_ffi_smoke.dart
