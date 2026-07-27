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

  print('\n${failures == 0 ? "ALL PASS" : "SOME FAILED"} ($failures failures)');
  exit(failures == 0 ? 0 : 1);
}
