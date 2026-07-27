#
# Compiles native/src/git_bridge.c directly into the app binary (no
# separate .so — iOS FFI plugins link everything statically) and
# links it against the vendored libgit2 + mbedTLS static libraries.
#
# Those libraries are NOT checked into the repo (they're large, and
# would go stale immediately) — run
# `ios/Scripts/build_libgit2_xcframework.sh` from a Mac with Xcode
# first (see that script's header comment for details, and plan §4
# W1: "Compile libgit2 for iOS (arm64 + simulator) as .xcframework").
# `pod install` will fail with a clear "no such file" error on
# Frameworks/*.xcframework until that script has been run once.
#
Pod::Spec.new do |s|
  s.name             = 'git2_bridge'
  s.version          = '0.0.1'
  s.summary          = 'FFI bridge to libgit2 for easy_svn.'
  s.description      = 'Thin C wrapper around libgit2, exposed to Dart via dart:ffi.'
  s.homepage         = 'https://github.com/sandeshkale/easy-svn'
  s.license          = { :type => 'Unlicensed', :text => 'Internal package, not published.' }
  s.author           = { 'easy-svn' => 'noreply@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*', '../../../native/src/**/*.c', '../../../native/include/**/*.h'
  s.public_header_files = '../../../native/include/**/*.h'
  s.vendored_frameworks = 'Frameworks/libgit2.xcframework', 'Frameworks/mbedtls.xcframework'

  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/../../../native/include',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
  s.swift_version = '5.0'
end
