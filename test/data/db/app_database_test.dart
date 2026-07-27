import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:easy_svn/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('repos table', () {
    test('insert then read back a repo row', () async {
      final id = await db
          .into(db.repos)
          .insert(
            ReposCompanion.insert(
              name: 'easy-svn',
              localPath: '/tmp/repos/easy-svn',
              remoteUrl: 'https://github.com/octocat/easy-svn.git',
            ),
          );

      final row = await (db.select(
        db.repos,
      )..where((t) => t.id.equals(id))).getSingle();

      expect(row.name, 'easy-svn');
      expect(row.localPath, '/tmp/repos/easy-svn');
      expect(row.defaultBranch, 'main', reason: 'column default');
      expect(row.unpushedCommits, 0, reason: 'column default');
      expect(row.lastSyncedAt, isNull);
    });

    test('localPath is unique', () async {
      Future<void> insertOnce() => db
          .into(db.repos)
          .insert(
            ReposCompanion.insert(
              name: 'dup',
              localPath: '/tmp/repos/dup',
              remoteUrl: 'https://github.com/octocat/dup.git',
            ),
          );

      await insertOnce();
      await expectLater(insertOnce(), throwsA(anything));
    });

    test('watchRepos-equivalent stream emits on insert', () async {
      final stream = db.select(db.repos).watch();
      final emissions = <int>[];
      final sub = stream.listen((rows) => emissions.add(rows.length));
      addTearDown(sub.cancel);

      // Let the initial (empty) emission land.
      await pumpEventQueue();
      expect(emissions, [0]);

      await db
          .into(db.repos)
          .insert(
            ReposCompanion.insert(
              name: 'a',
              localPath: '/tmp/a',
              remoteUrl: 'https://github.com/o/a.git',
            ),
          );
      await pumpEventQueue();
      expect(emissions, [0, 1]);
    });

    test('delete removes the row', () async {
      final id = await db
          .into(db.repos)
          .insert(
            ReposCompanion.insert(
              name: 'to-delete',
              localPath: '/tmp/repos/to-delete',
              remoteUrl: 'https://github.com/o/to-delete.git',
            ),
          );

      await (db.delete(db.repos)..where((t) => t.id.equals(id))).go();

      final remaining = await db.select(db.repos).get();
      expect(remaining, isEmpty);
    });

    test('update bumps unpushedCommits and lastSyncedAt', () async {
      final id = await db
          .into(db.repos)
          .insert(
            ReposCompanion.insert(
              name: 'x',
              localPath: '/tmp/x',
              remoteUrl: 'https://github.com/o/x.git',
            ),
          );
      final now = DateTime.now();

      await (db.update(db.repos)..where((t) => t.id.equals(id))).write(
        ReposCompanion(
          unpushedCommits: const Value(3),
          lastSyncedAt: Value(now),
        ),
      );

      final row = await (db.select(
        db.repos,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.unpushedCommits, 3);
      expect(row.lastSyncedAt, isNotNull);
    });
  });

  group('ensureSettingsRow', () {
    test('creates the singleton row on first call', () async {
      final settings = await db.ensureSettingsRow();
      expect(settings.id, 1);
      expect(settings.authorName, isNull);
      expect(settings.authorEmail, isNull);
      expect(settings.useShallowClone, isTrue, reason: 'column default');
    });

    test('is idempotent and returns the same row on repeat calls', () async {
      final first = await db.ensureSettingsRow();
      await (db.update(db.userSettings)..where((t) => t.id.equals(1))).write(
        const UserSettingsCompanion(
          authorName: Value('Ada Lovelace'),
          authorEmail: Value('ada@example.com'),
        ),
      );

      final second = await db.ensureSettingsRow();
      expect(second.id, first.id);
      expect(second.authorName, 'Ada Lovelace');
      expect(second.authorEmail, 'ada@example.com');
    });
  });
}
