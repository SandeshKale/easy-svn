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

  set(LIBGIT2_VERSION "v1.7.2" CACHE STRING "libgit2 tag to vendor")
  set(MBEDTLS_VERSION "v3.6.2" CACHE STRING "mbedTLS tag to vendor")

  set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
  set(BUILD_TESTS OFF CACHE BOOL "" FORCE)
  set(USE_SSH OFF CACHE BOOL "" FORCE)          # SSH auth is out of scope (plan §1 Scope Out)
  set(USE_HTTPS "mbedTLS" CACHE STRING "" FORCE)
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

  FetchContent_Declare(
    libgit2
    GIT_REPOSITORY https://github.com/libgit2/libgit2.git
    GIT_TAG ${LIBGIT2_VERSION}
  )
  FetchContent_MakeAvailable(libgit2)

  target_link_libraries(git_bridge PRIVATE git2)
endif()

if(ANDROID)
  target_link_libraries(git_bridge PRIVATE log)
endif()
