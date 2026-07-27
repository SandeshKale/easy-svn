import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:easy_svn/core/providers.dart';
import 'package:easy_svn/data/db/app_database.dart';
import 'package:easy_svn/data/repositories/repo_manager.dart';
import 'package:easy_svn/features/staging_commit/staging_commit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git2_bridge/git2_bridge.dart';

/// Stands in for the real [RepoManager] so this screen's tests never
/// touch the native git2_bridge FFI.
class _FakeRepoManager extends RepoManager {
  _FakeRepoManager(super.db, this._entries);

  List<GbStatusEntry> _entries;
  final List<String> stagedCalls = [];
  final List<String> unstagedCalls = [];
  String? committedMessage;
  String? committedAuthorName;
  String? committedAuthorEmail;

  @override
  Future<List<GbStatusEntry>> status(Repo repo) async => _entries;

  @override
  Future<void> stage(Repo repo, String filePath) async {
    stagedCalls.add(filePath);
    _entries = [
      for (final e in _entries)
        if (e.path == filePath)
          GbStatusEntry(path: e.path, status: e.status, staged: true)
        else
          e,
    ];
  }

  @override
  Future<void> unstage(Repo repo, String filePath) async {
    unstagedCalls.add(filePath);
    _entries = [
      for (final e in _entries)
        if (e.path == filePath)
          GbStatusEntry(path: e.path, status: e.status, staged: false)
        else
          e,
    ];
  }

  @override
  Future<void> commit({
    required Repo repo,
    required String message,
    required String authorName,
    required String authorEmail,
  }) async {
    committedMessage = message;
    committedAuthorName = authorName;
    committedAuthorEmail = authorEmail;
    _entries = [];
  }
}

Repo _testRepo() => Repo(
  id: 1,
  name: 'easy-svn',
  localPath: '/tmp/easy-svn',
  remoteUrl: 'https://github.com/o/easy-svn.git',
  defaultBranch: 'main',
  unpushedCommits: 0,
  createdAt: DateTime.now(),
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<_FakeRepoManager> pump(
    WidgetTester tester,
    List<GbStatusEntry> entries, {
    bool seedAuthorIdentity = true,
  }) async {
    if (seedAuthorIdentity) {
      await db.ensureSettingsRow();
      await (db.update(
        db.userSettings,
      )..where((t) => t.id.equals(1))).write(
        const UserSettingsCompanion(
          authorName: Value('Ada Lovelace'),
          authorEmail: Value('ada@example.com'),
        ),
      );
    }
    final fakeRepoManager = _FakeRepoManager(db, entries);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          repoManagerProvider.overrideWithValue(fakeRepoManager),
        ],
        child: MaterialApp(home: StagingCommitScreen(repo: _testRepo())),
      ),
    );
    await tester.pumpAndSettle();
    return fakeRepoManager;
  }

  testWidgets('shows a clean-tree message when there is nothing to commit', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(
      find.text('Working tree clean — nothing to commit.'),
      findsOneWidget,
    );
  });

  testWidgets('splits entries into Unstaged / Staged sections', (
    tester,
  ) async {
    await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'modified', staged: false),
      GbStatusEntry(path: 'lib/b.dart', status: 'added', staged: true),
    ]);

    expect(find.text('Unstaged (1)'), findsOneWidget);
    expect(find.text('Staged (1)'), findsOneWidget);
    expect(find.text('lib/a.dart'), findsOneWidget);
    expect(find.text('lib/b.dart'), findsOneWidget);
  });

  testWidgets('Commit button is disabled with nothing staged', (
    tester,
  ) async {
    await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'modified', staged: false),
    ]);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Commit'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('Commit button is enabled once something is staged', (
    tester,
  ) async {
    await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'added', staged: true),
    ]);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Commit'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('tapping the stage action calls RepoManager.stage', (
    tester,
  ) async {
    final fake = await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'modified', staged: false),
    ]);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    expect(fake.stagedCalls, ['lib/a.dart']);
    expect(find.text('Staged (1)'), findsOneWidget);
  });

  testWidgets('tapping the unstage action calls RepoManager.unstage', (
    tester,
  ) async {
    final fake = await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'added', staged: true),
    ]);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pumpAndSettle();

    expect(fake.unstagedCalls, ['lib/a.dart']);
    expect(find.text('Unstaged (1)'), findsOneWidget);
  });

  testWidgets('committing sends the message and stored author identity', (
    tester,
  ) async {
    final fake = await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'added', staged: true),
    ]);

    await tester.enterText(find.byType(TextField), 'Fix the thing');
    await tester.tap(find.widgetWithText(FilledButton, 'Commit'));
    await tester.pumpAndSettle();

    expect(fake.committedMessage, 'Fix the thing');
    expect(fake.committedAuthorName, 'Ada Lovelace');
    expect(fake.committedAuthorEmail, 'ada@example.com');
    // The screen refreshes status after a successful commit, and the
    // fake clears its entries on commit — so the tree is now "clean".
    expect(
      find.text('Working tree clean — nothing to commit.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a snackbar instead of committing with an empty message', (
    tester,
  ) async {
    final fake = await pump(tester, const [
      GbStatusEntry(path: 'lib/a.dart', status: 'added', staged: true),
    ]);

    await tester.tap(find.widgetWithText(FilledButton, 'Commit'));
    await tester.pump();

    expect(find.text('Enter a commit message first.'), findsOneWidget);
    expect(fake.committedMessage, isNull);
  });
}
