#!/usr/bin/env bash
# Compiles native/src/git_bridge.c against the host's libgit2 (apt
# install libgit2-dev on Debian/Ubuntu) and runs native/test/smoke_test.c
# against it. This does NOT exercise the Android/iOS cross-compiled
# builds — it's a fast host-side correctness check for the bridge logic
# itself (clone/status/stage/commit/push/pull) without needing a device,
# emulator, or mobile toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

gcc -Wall -Wextra -Wno-unused-parameter \
  -I native/include \
  native/test/smoke_test.c native/src/git_bridge.c \
  -o "$OUT/gb_smoke" \
  $(pkg-config --cflags --libs libgit2)

"$OUT/gb_smoke"
