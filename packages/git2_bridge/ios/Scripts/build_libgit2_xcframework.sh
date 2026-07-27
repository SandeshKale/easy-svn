#!/usr/bin/env bash
# Builds libgit2.xcframework and mbedtls.xcframework for iOS (device
# arm64 + simulator arm64/x86_64) and drops them in ../Frameworks/,
# where git2_bridge.podspec expects to find them.
#
# MUST be run on macOS with Xcode + the Command Line Tools installed —
# there is no way to produce an iOS build artifact anywhere else.
# This is the Week 1 deliverable from the implementation plan (§4:
# "Compile libgit2 for iOS (arm64 + simulator) as .xcframework").
#
# Usage: ./build_libgit2_xcframework.sh
set -euo pipefail

if [[ "$(uname)" != "Darwin" ]]; then
  echo "error: this script must run on macOS with Xcode installed." >&2
  exit 1
fi
if ! xcode-select -p >/dev/null 2>&1; then
  echo "error: Xcode Command Line Tools not found (run xcode-select --install)." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IOS_DIR="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="$IOS_DIR/Frameworks"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

LIBGIT2_TAG="v1.7.2"
MBEDTLS_TAG="v3.6.2"
# github.com/leetal/ios-cmake — the standard CMake toolchain file for
# cross-compiling to iOS device/simulator, used here instead of
# hand-rolling CMAKE_OSX_* flags.
IOS_CMAKE_TAG="4.5.0"

mkdir -p "$FRAMEWORKS_DIR"

echo "==> Fetching ios-cmake toolchain ($IOS_CMAKE_TAG)"
curl -fsSL "https://github.com/leetal/ios-cmake/archive/refs/tags/${IOS_CMAKE_TAG}.tar.gz" \
  | tar xz -C "$WORK_DIR"
TOOLCHAIN="$WORK_DIR/ios-cmake-${IOS_CMAKE_TAG#v}/ios.toolchain.cmake"

echo "==> Fetching mbedTLS ($MBEDTLS_TAG)"
git clone --depth 1 --branch "$MBEDTLS_TAG" https://github.com/Mbed-TLS/mbedtls.git "$WORK_DIR/mbedtls"

echo "==> Fetching libgit2 ($LIBGIT2_TAG)"
git clone --depth 1 --branch "$LIBGIT2_TAG" https://github.com/libgit2/libgit2.git "$WORK_DIR/libgit2"

# Builds one (library, platform) pair as a static lib and echoes its
# output path. PLATFORM is an ios.toolchain.cmake PLATFORM value:
# OS64 (device arm64), SIMULATORARM64, SIMULATOR64 (Intel simulator).
build_one() {
  local name="$1" src_dir="$2" platform="$3" extra_args="$4"
  local build_dir="$WORK_DIR/build-$name-$platform"
  cmake -S "$src_dir" -B "$build_dir" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DPLATFORM="$platform" \
    -DDEPLOYMENT_TARGET=14.0 \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    $extra_args
  cmake --build "$build_dir" --config Release
}

echo "==> Building mbedTLS (device)"
build_one mbedtls "$WORK_DIR/mbedtls" OS64 "-DENABLE_TESTING=OFF -DENABLE_PROGRAMS=OFF"
echo "==> Building mbedTLS (simulator arm64)"
build_one mbedtls "$WORK_DIR/mbedtls" SIMULATORARM64 "-DENABLE_TESTING=OFF -DENABLE_PROGRAMS=OFF"
echo "==> Building mbedTLS (simulator x86_64)"
build_one mbedtls "$WORK_DIR/mbedtls" SIMULATOR64 "-DENABLE_TESTING=OFF -DENABLE_PROGRAMS=OFF"

LIBGIT2_ARGS="-DUSE_SSH=OFF -DUSE_HTTPS=mbedTLS -DUSE_BUNDLED_ZLIB=ON -DREGEX_BACKEND=builtin -DTHREADSAFE=ON -DBUILD_CLI=OFF -DBUILD_TESTS=OFF -DENABLE_PROGRAMS=OFF -DENABLE_TESTING=OFF"
echo "==> Building libgit2 (device)"
build_one libgit2 "$WORK_DIR/libgit2" OS64 "$LIBGIT2_ARGS -Dmbedtls_DIR=$WORK_DIR/build-mbedtls-OS64"
echo "==> Building libgit2 (simulator arm64)"
build_one libgit2 "$WORK_DIR/libgit2" SIMULATORARM64 "$LIBGIT2_ARGS -Dmbedtls_DIR=$WORK_DIR/build-mbedtls-SIMULATORARM64"
echo "==> Building libgit2 (simulator x86_64)"
build_one libgit2 "$WORK_DIR/libgit2" SIMULATOR64 "$LIBGIT2_ARGS -Dmbedtls_DIR=$WORK_DIR/build-mbedtls-SIMULATOR64"

# mbedTLS produces three static libs (libmbedtls, libmbedx509,
# libmbedcrypto); merge them into one per platform slice so we only
# need a single mbedtls.xcframework.
combine_mbedtls() {
  local build_dir="$1" out="$2"
  libtool -static -o "$out" \
    "$build_dir/library/libmbedtls.a" \
    "$build_dir/library/libmbedx509.a" \
    "$build_dir/library/libmbedcrypto.a"
}

echo "==> Combining mbedTLS static libs per slice"
combine_mbedtls "$WORK_DIR/build-mbedtls-OS64" "$WORK_DIR/build-mbedtls-OS64/libmbedtls_combined.a"
combine_mbedtls "$WORK_DIR/build-mbedtls-SIMULATORARM64" "$WORK_DIR/build-mbedtls-SIMULATORARM64/libmbedtls_combined.a"
combine_mbedtls "$WORK_DIR/build-mbedtls-SIMULATOR64" "$WORK_DIR/build-mbedtls-SIMULATOR64/libmbedtls_combined.a"

echo "==> Fusing simulator slices with lipo"
mkdir -p "$WORK_DIR/sim-fat"
lipo -create \
  "$WORK_DIR/build-libgit2-SIMULATORARM64/libgit2.a" \
  "$WORK_DIR/build-libgit2-SIMULATOR64/libgit2.a" \
  -output "$WORK_DIR/sim-fat/libgit2.a"
lipo -create \
  "$WORK_DIR/build-mbedtls-SIMULATORARM64/libmbedtls_combined.a" \
  "$WORK_DIR/build-mbedtls-SIMULATOR64/libmbedtls_combined.a" \
  -output "$WORK_DIR/sim-fat/libmbedtls.a"

echo "==> Creating libgit2.xcframework"
rm -rf "$FRAMEWORKS_DIR/libgit2.xcframework"
xcodebuild -create-xcframework \
  -library "$WORK_DIR/build-libgit2-OS64/libgit2.a" -headers "$WORK_DIR/libgit2/include" \
  -library "$WORK_DIR/sim-fat/libgit2.a" -headers "$WORK_DIR/libgit2/include" \
  -output "$FRAMEWORKS_DIR/libgit2.xcframework"

echo "==> Creating mbedtls.xcframework"
rm -rf "$FRAMEWORKS_DIR/mbedtls.xcframework"
xcodebuild -create-xcframework \
  -library "$WORK_DIR/build-mbedtls-OS64/libmbedtls_combined.a" -headers "$WORK_DIR/mbedtls/include" \
  -library "$WORK_DIR/sim-fat/libmbedtls.a" -headers "$WORK_DIR/mbedtls/include" \
  -output "$FRAMEWORKS_DIR/mbedtls.xcframework"

echo "==> Done. Frameworks written to $FRAMEWORKS_DIR"
echo "    Run 'pod install' in ios/ (from the app root) to pick them up."
