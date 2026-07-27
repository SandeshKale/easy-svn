// This is a standalone diagnostic CLI script (run via
// ../../scripts/dart_ffi_smoke_test.sh), not app/package library code —
// console output and a terse positional-bool `check()` helper are the
// point, not something to launder through a logging framework.
// ignore_for_file: avoid_print, avoid_positional_boolean_parameters
// ignore_for_file: prefer_const_declarations, no_adjacent_strings_in_list
// ignore_for_file: unnecessary_lambdas, lines_longer_than_80_chars

import 'dart:io';

import 'package:git2_bridge/git2_bridge.dart';

Future<void> main() async {
  final originPath = '/tmp/dart_gb_origin';
  final seedPath = '/tmp/dart_gb_seed';
  final clonePath = '/tmp/dart_gb_clone';
  for (final p in [originPath, seedPath, clonePath]) {
    final d = Directory(p);
    if (d.existsSync()) d.deleteSync(recursive: true);
  }

  await Process.run('git', ['init', '-q', '--bare', '-b', 'main', originPath]);
  await Process.run('bash', [
    '-c',
    'git clone -q $originPath $seedPath && cd $seedPath && '
        'git config user.email a@b.com && git config user.name Test && '
        'echo hello > README.md && git add README.md && '
        "git commit -q -m 'initial commit' && git push -q origin main",
  ]);

  var failures = 0;
  void check(bool cond, String label) {
    if (cond) {
      print('OK:   $label');
    } else {
      print('FAIL: $label');
      failures++;
    }
  }

  final progressEvents = <GbProgress>[];
  await Git2Bridge.clone(
    url: 'file://$originPath',
    path: clonePath,
    shallow: false,
    onProgress: (p) => progressEvents.add(p),
  );
  check(Directory('$clonePath/.git').existsSync(), 'clone produced .git dir');
  check(
    progressEvents.isNotEmpty,
    'progress callback fired at least once (isolate->isolate NativeCallable works)',
  );
  print(
    '  saw ${progressEvents.length} progress events, last: ${progressEvents.last}',
  );

  final head = await Git2Bridge.getHeadInfo(clonePath);
  check(
    head != null && head.branch == 'main',
    'getHeadInfo reports branch main',
  );
  print('  head: $head');

  final tree = await Git2Bridge.getFileTree(repoPath: clonePath);
  check(tree.any((e) => e.name == 'README.md'), 'file tree lists README.md');

  File('$clonePath/NOTES.md').writeAsStringSync('notes\n');
  var status = await Git2Bridge.getStatus(clonePath);
  check(
    status.any((e) => e.path == 'NOTES.md' && !e.staged),
    'status shows NOTES.md unstaged',
  );

  await Git2Bridge.stage(repoPath: clonePath, filePath: 'NOTES.md');
  status = await Git2Bridge.getStatus(clonePath);
  check(
    status.any((e) => e.path == 'NOTES.md' && e.staged),
    'status shows NOTES.md staged after stage()',
  );

  await Git2Bridge.commit(
    repoPath: clonePath,
    message: 'Add notes',
    authorName: 'Dart Test',
    authorEmail: 'dart@example.com',
  );
  final unpushed = await Git2Bridge.getUnpushedCount(clonePath);
  check(unpushed == 1, 'unpushed count is 1 after local commit');

  final pushProgress = <GbProgress>[];
  await Git2Bridge.push(
    path: clonePath,
    onProgress: (p) => pushProgress.add(p),
  );
  check(pushProgress.isNotEmpty, 'push progress callback fired');
  final unpushedAfterPush = await Git2Bridge.getUnpushedCount(clonePath);
  check(unpushedAfterPush == 0, 'unpushed count is 0 after push');

  // Exercise the mapped-error path.
  try {
    await Git2Bridge.getHeadInfo('/tmp/does-not-exist-repo');
    check(false, 'getHeadInfo on missing repo should throw');
  } on GitBridgeException catch (e) {
    check(
      true,
      'getHeadInfo on missing repo threw GitBridgeException(${e.errorCode.name})',
    );
  }

  // Git2Bridge.init — importing a plain (non-git) folder as a new
  // local repository (the zip-import feature's "standalone repo"
  // path).
  final initPath = '/tmp/dart_gb_init';
  final initDir = Directory(initPath);
  if (initDir.existsSync()) initDir.deleteSync(recursive: true);
  initDir.createSync(recursive: true);
  File('$initPath/README.md').writeAsStringSync('hello\n');

  check(
    !await Git2Bridge.isRepository(initPath),
    'plain folder is not a repository yet',
  );
  await Git2Bridge.init(initPath);
  check(
    await Git2Bridge.isRepository(initPath),
    'isRepository true after init',
  );

  try {
    await Git2Bridge.init(initPath);
    check(false, 'init on an already-initialized repo should throw');
  } on GitBridgeException catch (e) {
    check(
      e.errorCode == GbErrorCode.exists,
      'init on existing repo throws GbErrorCode.exists',
    );
  }

  final initStatus = await Git2Bridge.getStatus(initPath);
  check(
    initStatus.any((e) => e.path == 'README.md' && !e.staged),
    "freshly-init'd repo shows README.md as untracked",
  );
  await Git2Bridge.stage(repoPath: initPath, filePath: 'README.md');
  await Git2Bridge.commit(
    repoPath: initPath,
    message: 'Initial import',
    authorName: 'Dart Test',
    authorEmail: 'dart@example.com',
  );
  final initHead = await Git2Bridge.getHeadInfo(initPath);
  check(
    initHead?.branch == 'main',
    "first commit on a gb_init'd repo lands on branch main",
  );

  print('\n${failures == 0 ? "ALL PASS" : "SOME FAILED"} ($failures failures)');
  exit(failures == 0 ? 0 : 1);
}
