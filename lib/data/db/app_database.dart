import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// One cloned repository (plan §10 Appendix: Storage Layout).
class Repos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get localPath => text().unique()();
  TextColumn get remoteUrl => text()();
  TextColumn get defaultBranch => text().withDefault(const Constant('main'))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();
  IntColumn get unpushedCommits => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Singleton row (id always 1) for cross-repo settings. The GitHub
/// token itself lives in flutter_secure_storage, not here — see
/// lib/features/auth — this table only holds the non-secret prefs.
class UserSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get authorName => text().nullable()();
  TextColumn get authorEmail => text().nullable()();
  BoolColumn get useShallowClone =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Repos, UserSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<UserSetting> ensureSettingsRow() async {
    final existing = await (select(
      userSettings,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (existing != null) return existing;
    await into(userSettings).insert(const UserSettingsCompanion(id: Value(1)));
    return (select(userSettings)..where((t) => t.id.equals(1))).getSingle();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'metadata.db'));
    return NativeDatabase.createInBackground(file);
  });
}
