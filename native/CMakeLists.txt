# Builds libgit_bridge.so: vendors libgit2 + mbedTLS (for HTTPS — the
# Android NDK doesn't ship OpenSSL headers) as static libs via
# FetchContent, then compiles this repo's thin C wrapper
# (native/src/git_bridge.c, declared in native/include/git_bridge.h)
# on top and links everything into one shared object that Dart FFI
# dlopen()s at runtime (see packages/git2_bridge/lib/src/native_library.dart).
#
# Consumed two ways:
#  - Android: packages/git2_bridge/android/build.gradle points its
#    externalNativeBuild.cmake.path here; Flutter's Gradle plugin
#    invokes it per-ABI (arm64-v8a, x86_64 — see android/app/build.gradle.kts)
#    when a real Android NDK is present. Not runnable in this sandbox,
#    which has no Android SDK/NDK.
#  - Anywhere with a plain C toolchain + system libgit2 (this sandbox
#    included): `cmake -DGB_USE_SYSTEM_LIBGIT2=ON` skips the
#    FetchContent vendoring entirely and links the system library
#    instead — see scripts/native_smoke_test.sh for the even lighter
#    weight version of this (raw gcc, no CMake) used to validate
#    bridge logic on every change.
cmake_minimum_required(VERSION 3.22.1)
project(git_bridge_native C)

option(GB_USE_SYSTEM_LIBGIT2 "Link the system-installed libgit2 instead of vendoring one via FetchContent (host/desktop dev only)" OFF)

add_library(git_bridge SHARED
  ${CMAKE_CURRENT_SOURCE_DIR}/src/git_bridge.c
)
target_include_directories(git_bridge PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/include
)

if(GB_USE_SYSTEM_LIBGIT2)
  find_package(PkgConfig REQUIRED)
  pkg_check_modules(LIBGIT2 REQUIRED libgit2)
  target_include_directories(git_bridge PRIVATE ${LIBGIT2_INCLUDE_DIRS})
  target_link_libraries(git_bridge PRIVATE ${LIBGIT2_LIBRARIES})
else()
  include(FetchContent)

  # v1.7.2 (the plan's originally-specified version) still #includes
  # <mbedtls/config.h>, a header mbedTLS removed in 3.x — it only
  # supports mbedTLS 2.x. v1.9.6 (latest as of this writing) dropped
  # that include and builds cleanly against mbedTLS 3.6.2; verified
  # locally by a full FetchContent build (see git log for this line).
  set(LIBGIT2_VERSION "v1.9.6" CACHE STRING "libgit2 tag to vendor")
  set(MBEDTLS_VERSION "v3.6.2" CACHE STRING "mbedTLS tag to vendor")

  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(USE_SSH OFF CACHE BOOL "" FORCE)          # SSH auth is out of scope (plan §1 Scope Out)
  set(USE_HTTPS "mbedTLS" CACHE STRING "" FORCE)
  # NTLM (Windows-domain proxy auth) needs mbedtls/md4.h, which
  # mbedTLS doesn't build by default (MD4 is deprecated/insecure) —
  # and we don't use NTLM at all: GitHub HTTPS auth is Basic
  # (oauth2:token), not NTLM.
  set(USE_NTLMCLIENT OFF CACHE BOOL "" FORCE)
  set(USE_BUNDLED_ZLIB ON CACHE BOOL "" FORCE)
  set(REGEX_BACKEND "builtin" CACHE STRING "" FORCE)
  set(THREADSAFE ON CACHE BOOL "" FORCE)
  set(BUILD_CLI OFF CACHE BOOL "" FORCE)
  set(ENABLE_TRACE OFF CACHE BOOL "" FORCE)
  set(ENABLE_PROGRAMS OFF CACHE BOOL "" FORCE)
  set(ENABLE_TESTING OFF CACHE BOOL "" FORCE)

  # mbedTLS 3.6.2 split its shared CMake/build-script helpers out into
  # a "framework" submodule (shared with TF-PSA-Crypto); its top-level
  # CMakeLists.txt fails to even configure without it. We don't need
  # any of mbedTLS's *other* submodules (third-party test vectors,
  # etc.), so fetch just this one rather than everything.
  FetchContent_Declare(
    mbedtls
    GIT_REPOSITORY https://github.com/Mbed-TLS/mbedtls.git
    GIT_TAG ${MBEDTLS_VERSION}
    GIT_SUBMODULES "framework"
  )
  FetchContent_MakeAvailable(mbedtls)

  # libgit2's cmake/FindmbedTLS.cmake does a plain filesystem
  # find_path()/find_library() — it has no idea the mbedtls/mbedx509/
  # mbedcrypto CMake targets FetchContent just created even exist, and
  # a filesystem search would fail anyway since those .a files don't
  # exist until the *build* step runs, not at configure time. Pre-seed
  # the cache variables it looks for with mbedTLS's own build-output
  # layout (stable across versions: it mirrors the source tree's
  # library/ subdirectory) so find_package(mbedTLS) short-circuits
  # successfully instead of searching.
  set(MBEDTLS_INCLUDE_DIR "${mbedtls_SOURCE_DIR}/include" CACHE PATH "" FORCE)
  set(MBEDTLS_LIBRARY "${mbedtls_BINARY_DIR}/library/libmbedtls.a" CACHE FILEPATH "" FORCE)
  set(MBEDX509_LIBRARY "${mbedtls_BINARY_DIR}/library/libmbedx509.a" CACHE FILEPATH "" FORCE)
  set(MBEDCRYPTO_LIBRARY "${mbedtls_BINARY_DIR}/library/libmbedcrypto.a" CACHE FILEPATH "" FORCE)

  FetchContent_Declare(
    libgit2
    GIT_REPOSITORY https://github.com/libgit2/libgit2.git
    GIT_TAG ${LIBGIT2_VERSION}
  )
  FetchContent_MakeAvailable(libgit2)

  # libgit2's own CMake target is named "libgit2package" — "git2" is
  # only its *output filename* (see LIBGIT2_FILENAME in
  # src/libgit2/CMakeLists.txt). target_link_libraries(... git2) still
  # "worked" at configure time because CMake falls back to treating an
  # unrecognized name as a raw linker flag (-lgit2) rather than
  # erroring — but that means it carries none of the target's usual
  # include-directory propagation, hence the explicit include path
  # below (libgit2package's own target_include_directories call is
  # PRIVATE, so it doesn't propagate the public header either way).
  target_include_directories(git_bridge PRIVATE ${libgit2_SOURCE_DIR}/include)
  target_link_libraries(git_bridge PRIVATE git2)
  # libgit2 links mbedTLS via raw -L/-l flags (derived from the paths
  # above), not a CMake target reference, so Ninja has no inherent
  # build-order edge forcing mbedtls's .a files to exist before
  # libgit2package links against them — add one explicitly. (Also
  # needed for git_bridge -> libgit2package itself, since that link is
  # likewise a raw -lgit2 flag, not a target reference.)
  add_dependencies(libgit2package mbedtls mbedx509 mbedcrypto)
  add_dependencies(git_bridge libgit2package)
endif()

if(ANDROID)
  target_link_libraries(git_bridge PRIVATE log)
endif()
