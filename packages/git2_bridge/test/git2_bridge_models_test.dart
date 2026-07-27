import 'package:flutter_test/flutter_test.dart';
import 'package:git2_bridge/git2_bridge.dart';

void main() {
  group('GbStatusEntry.fromJson', () {
    test('decodes a staged entry', () {
      final entry = GbStatusEntry.fromJson({
        'path': 'lib/main.dart',
        'status': 'modified',
        'staged': true,
      });
      expect(entry.path, 'lib/main.dart');
      expect(entry.status, 'modified');
      expect(entry.staged, isTrue);
    });

    test('decodes an unstaged entry', () {
      final entry = GbStatusEntry.fromJson({
        'path': 'README.md',
        'status': 'added',
        'staged': false,
      });
      expect(entry.staged, isFalse);
    });
  });

  group('GbTreeEntry.fromJson', () {
    test('decodes a blob with a size', () {
      final entry = GbTreeEntry.fromJson({
        'name': 'main.dart',
        'path': 'lib/main.dart',
        'type': 'blob',
        'size': 512,
      });
      expect(entry.name, 'main.dart');
      expect(entry.path, 'lib/main.dart');
      expect(entry.isDirectory, isFalse);
      expect(entry.size, 512);
    });

    test('decodes a tree with no size', () {
      final entry = GbTreeEntry.fromJson({
        'name': 'lib',
        'path': 'lib',
        'type': 'tree',
      });
      expect(entry.isDirectory, isTrue);
      expect(entry.size, isNull);
    });
  });

  group('GbHeadInfo.fromJson', () {
    test('decodes sha/summary/branch', () {
      final head = GbHeadInfo.fromJson({
        'sha': 'a1b2c3d',
        'summary': 'Fix crash on empty repo',
        'branch': 'main',
      });
      expect(head.sha, 'a1b2c3d');
      expect(head.summary, 'Fix crash on empty repo');
      expect(head.branch, 'main');
    });
  });

  group('GbProgress', () {
    test('toString includes percent and message', () {
      const progress = GbProgress(
        percent: 42,
        message: 'Receiving objects: 4/10',
        bytesReceived: 1024,
        totalObjects: 10,
        receivedObjects: 4,
      );
      expect(progress.toString(), 'GbProgress(42% Receiving objects: 4/10)');
    });

    test('percent of -1 is a valid "unknown percentage" sentinel', () {
      const progress = GbProgress(
        percent: -1,
        message: 'Resolving deltas',
        bytesReceived: 0,
        totalObjects: 0,
        receivedObjects: 0,
      );
      expect(progress.percent, -1);
    });
  });
}
