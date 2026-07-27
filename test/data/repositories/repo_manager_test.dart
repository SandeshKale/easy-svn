import 'package:easy_svn/data/repositories/repo_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('repoNameFromUrl', () {
    test('strips .git suffix', () {
      expect(
        repoNameFromUrl('https://github.com/octocat/Hello-World.git'),
        'Hello-World',
      );
    });

    test('handles a URL with no .git suffix', () {
      expect(
        repoNameFromUrl('https://github.com/octocat/Hello-World'),
        'Hello-World',
      );
    });

    test('strips a single trailing slash', () {
      expect(
        repoNameFromUrl('https://github.com/octocat/Hello-World/'),
        'Hello-World',
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        repoNameFromUrl('  https://github.com/octocat/Hello-World.git  '),
        'Hello-World',
      );
    });

    test('falls back to a default name for an empty URL', () {
      expect(repoNameFromUrl(''), 'repository');
    });

    test('takes the host as the name for a bare host URL', () {
      // No path segment to use — this is a degenerate input a real
      // clone would also reject, but the name derivation itself
      // shouldn't throw or produce an empty string.
      expect(repoNameFromUrl('https://github.com/'), 'github.com');
    });

    test('works for a self-hosted GitHub Enterprise-style URL', () {
      expect(
        repoNameFromUrl('https://git.example.com/team/sub/project.git'),
        'project',
      );
    });
  });
}
