import 'package:archive/archive_io.dart';
import 'package:easy_svn/data/repositories/repo_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds an in-memory zip's bytes from a map of entry path -> file
/// content, for feeding into [decodeZipArchive] without touching disk.
List<int> _buildZipBytes(Map<String, String> entries) {
  final archive = Archive();
  for (final entry in entries.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encode(archive);
}

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

  group('repoNameFromZipPath', () {
    test('strips the .zip extension', () {
      expect(repoNameFromZipPath('/downloads/my-repo.zip'), 'my-repo');
    });

    test('falls back to a default name for an empty path', () {
      expect(repoNameFromZipPath(''), 'imported-repo');
    });
  });

  group('decodeZipArchive', () {
    test('leaves a zip with root-level entries untouched', () {
      final bytes = _buildZipBytes({
        'README.md': 'hello',
        'lib/main.dart': 'void main() {}',
      });

      final archive = decodeZipArchive(bytes);

      expect(
        archive.files.map((f) => f.name).toSet(),
        {'README.md', 'lib/main.dart'},
      );
    });

    test('strips a single common top-level wrapper directory', () {
      // Mirrors what GitHub's "Download ZIP" produces: everything
      // nested under one `<repo>-<branch>/` directory.
      final bytes = _buildZipBytes({
        'my-repo-main/README.md': 'hello',
        'my-repo-main/lib/main.dart': 'void main() {}',
      });

      final archive = decodeZipArchive(bytes);

      expect(
        archive.files.map((f) => f.name).toSet(),
        {'README.md', 'lib/main.dart'},
      );
    });

    test('unwraps a nested .git directory along with the wrapper', () {
      final bytes = _buildZipBytes({
        'my-repo-main/README.md': 'hello',
        'my-repo-main/.git/config': '[core]',
      });

      final archive = decodeZipArchive(bytes);

      expect(
        archive.files.map((f) => f.name).toSet(),
        {'README.md', '.git/config'},
      );
    });

    test('does not unwrap when there are multiple top-level entries', () {
      final bytes = _buildZipBytes({
        'README.md': 'hello',
        'lib/main.dart': 'void main() {}',
      });

      final archive = decodeZipArchive(bytes);

      expect(
        archive.files.map((f) => f.name).toSet(),
        {'README.md', 'lib/main.dart'},
      );
    });

    test('exclude drops matching entries after unwrapping', () {
      final bytes = _buildZipBytes({
        'my-repo-main/README.md': 'hello',
        'my-repo-main/.git/config': '[core]',
        'my-repo-main/.git/HEAD': 'ref: refs/heads/main',
      });

      final archive = decodeZipArchive(
        bytes,
        exclude: (name) => name == '.git' || name.startsWith('.git/'),
      );

      expect(archive.files.map((f) => f.name).toSet(), {'README.md'});
    });
  });
}
