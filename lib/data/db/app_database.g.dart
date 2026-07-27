// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ReposTable extends Repos with TableInfo<$ReposTable, Repo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReposTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _remoteUrlMeta = const VerificationMeta(
    'remoteUrl',
  );
  @override
  late final GeneratedColumn<String> remoteUrl = GeneratedColumn<String>(
    'remote_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultBranchMeta = const VerificationMeta(
    'defaultBranch',
  );
  @override
  late final GeneratedColumn<String> defaultBranch = GeneratedColumn<String>(
    'default_branch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('main'),
  );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unpushedCommitsMeta = const VerificationMeta(
    'unpushedCommits',
  );
  @override
  late final GeneratedColumn<int> unpushedCommits = GeneratedColumn<int>(
    'unpushed_commits',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    localPath,
    remoteUrl,
    defaultBranch,
    lastSyncedAt,
    unpushedCommits,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Repo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('remote_url')) {
      context.handle(
        _remoteUrlMeta,
        remoteUrl.isAcceptableOrUnknown(data['remote_url']!, _remoteUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteUrlMeta);
    }
    if (data.containsKey('default_branch')) {
      context.handle(
        _defaultBranchMeta,
        defaultBranch.isAcceptableOrUnknown(
          data['default_branch']!,
          _defaultBranchMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('unpushed_commits')) {
      context.handle(
        _unpushedCommitsMeta,
        unpushedCommits.isAcceptableOrUnknown(
          data['unpushed_commits']!,
          _unpushedCommitsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Repo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Repo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      remoteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_url'],
      )!,
      defaultBranch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_branch'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      ),
      unpushedCommits: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unpushed_commits'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReposTable createAlias(String alias) {
    return $ReposTable(attachedDatabase, alias);
  }
}

class Repo extends DataClass implements Insertable<Repo> {
  final int id;
  final String name;
  final String localPath;
  final String remoteUrl;
  final String defaultBranch;
  final DateTime? lastSyncedAt;
  final int unpushedCommits;
  final DateTime createdAt;
  const Repo({
    required this.id,
    required this.name,
    required this.localPath,
    required this.remoteUrl,
    required this.defaultBranch,
    this.lastSyncedAt,
    required this.unpushedCommits,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['local_path'] = Variable<String>(localPath);
    map['remote_url'] = Variable<String>(remoteUrl);
    map['default_branch'] = Variable<String>(defaultBranch);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    map['unpushed_commits'] = Variable<int>(unpushedCommits);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReposCompanion toCompanion(bool nullToAbsent) {
    return ReposCompanion(
      id: Value(id),
      name: Value(name),
      localPath: Value(localPath),
      remoteUrl: Value(remoteUrl),
      defaultBranch: Value(defaultBranch),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
      unpushedCommits: Value(unpushedCommits),
      createdAt: Value(createdAt),
    );
  }

  factory Repo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Repo(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      localPath: serializer.fromJson<String>(json['localPath']),
      remoteUrl: serializer.fromJson<String>(json['remoteUrl']),
      defaultBranch: serializer.fromJson<String>(json['defaultBranch']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
      unpushedCommits: serializer.fromJson<int>(json['unpushedCommits']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'localPath': serializer.toJson<String>(localPath),
      'remoteUrl': serializer.toJson<String>(remoteUrl),
      'defaultBranch': serializer.toJson<String>(defaultBranch),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
      'unpushedCommits': serializer.toJson<int>(unpushedCommits),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Repo copyWith({
    int? id,
    String? name,
    String? localPath,
    String? remoteUrl,
    String? defaultBranch,
    Value<DateTime?> lastSyncedAt = const Value.absent(),
    int? unpushedCommits,
    DateTime? createdAt,
  }) => Repo(
    id: id ?? this.id,
    name: name ?? this.name,
    localPath: localPath ?? this.localPath,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    defaultBranch: defaultBranch ?? this.defaultBranch,
    lastSyncedAt: lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
    unpushedCommits: unpushedCommits ?? this.unpushedCommits,
    createdAt: createdAt ?? this.createdAt,
  );
  Repo copyWithCompanion(ReposCompanion data) {
    return Repo(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remoteUrl: data.remoteUrl.present ? data.remoteUrl.value : this.remoteUrl,
      defaultBranch: data.defaultBranch.present
          ? data.defaultBranch.value
          : this.defaultBranch,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      unpushedCommits: data.unpushedCommits.present
          ? data.unpushedCommits.value
          : this.unpushedCommits,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Repo(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('defaultBranch: $defaultBranch, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('unpushedCommits: $unpushedCommits, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    localPath,
    remoteUrl,
    defaultBranch,
    lastSyncedAt,
    unpushedCommits,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Repo &&
          other.id == this.id &&
          other.name == this.name &&
          other.localPath == this.localPath &&
          other.remoteUrl == this.remoteUrl &&
          other.defaultBranch == this.defaultBranch &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.unpushedCommits == this.unpushedCommits &&
          other.createdAt == this.createdAt);
}

class ReposCompanion extends UpdateCompanion<Repo> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> localPath;
  final Value<String> remoteUrl;
  final Value<String> defaultBranch;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> unpushedCommits;
  final Value<DateTime> createdAt;
  const ReposCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remoteUrl = const Value.absent(),
    this.defaultBranch = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.unpushedCommits = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReposCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String localPath,
    required String remoteUrl,
    this.defaultBranch = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.unpushedCommits = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : name = Value(name),
       localPath = Value(localPath),
       remoteUrl = Value(remoteUrl);
  static Insertable<Repo> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? localPath,
    Expression<String>? remoteUrl,
    Expression<String>? defaultBranch,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? unpushedCommits,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (localPath != null) 'local_path': localPath,
      if (remoteUrl != null) 'remote_url': remoteUrl,
      if (defaultBranch != null) 'default_branch': defaultBranch,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (unpushedCommits != null) 'unpushed_commits': unpushedCommits,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReposCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? localPath,
    Value<String>? remoteUrl,
    Value<String>? defaultBranch,
    Value<DateTime?>? lastSyncedAt,
    Value<int>? unpushedCommits,
    Value<DateTime>? createdAt,
  }) {
    return ReposCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      defaultBranch: defaultBranch ?? this.defaultBranch,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      unpushedCommits: unpushedCommits ?? this.unpushedCommits,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remoteUrl.present) {
      map['remote_url'] = Variable<String>(remoteUrl.value);
    }
    if (defaultBranch.present) {
      map['default_branch'] = Variable<String>(defaultBranch.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (unpushedCommits.present) {
      map['unpushed_commits'] = Variable<int>(unpushedCommits.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReposCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('localPath: $localPath, ')
          ..write('remoteUrl: $remoteUrl, ')
          ..write('defaultBranch: $defaultBranch, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('unpushedCommits: $unpushedCommits, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    check: () => id.equals(1),
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _authorNameMeta = const VerificationMeta(
    'authorName',
  );
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
    'author_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorEmailMeta = const VerificationMeta(
    'authorEmail',
  );
  @override
  late final GeneratedColumn<String> authorEmail = GeneratedColumn<String>(
    'author_email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useShallowCloneMeta = const VerificationMeta(
    'useShallowClone',
  );
  @override
  late final GeneratedColumn<bool> useShallowClone = GeneratedColumn<bool>(
    'use_shallow_clone',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_shallow_clone" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    authorName,
    authorEmail,
    useShallowClone,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('author_name')) {
      context.handle(
        _authorNameMeta,
        authorName.isAcceptableOrUnknown(data['author_name']!, _authorNameMeta),
      );
    }
    if (data.containsKey('author_email')) {
      context.handle(
        _authorEmailMeta,
        authorEmail.isAcceptableOrUnknown(
          data['author_email']!,
          _authorEmailMeta,
        ),
      );
    }
    if (data.containsKey('use_shallow_clone')) {
      context.handle(
        _useShallowCloneMeta,
        useShallowClone.isAcceptableOrUnknown(
          data['use_shallow_clone']!,
          _useShallowCloneMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      authorName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_name'],
      ),
      authorEmail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_email'],
      ),
      useShallowClone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_shallow_clone'],
      )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final int id;
  final String? authorName;
  final String? authorEmail;
  final bool useShallowClone;
  const UserSetting({
    required this.id,
    this.authorName,
    this.authorEmail,
    required this.useShallowClone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || authorName != null) {
      map['author_name'] = Variable<String>(authorName);
    }
    if (!nullToAbsent || authorEmail != null) {
      map['author_email'] = Variable<String>(authorEmail);
    }
    map['use_shallow_clone'] = Variable<bool>(useShallowClone);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      authorName: authorName == null && nullToAbsent
          ? const Value.absent()
          : Value(authorName),
      authorEmail: authorEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(authorEmail),
      useShallowClone: Value(useShallowClone),
    );
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      id: serializer.fromJson<int>(json['id']),
      authorName: serializer.fromJson<String?>(json['authorName']),
      authorEmail: serializer.fromJson<String?>(json['authorEmail']),
      useShallowClone: serializer.fromJson<bool>(json['useShallowClone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'authorName': serializer.toJson<String?>(authorName),
      'authorEmail': serializer.toJson<String?>(authorEmail),
      'useShallowClone': serializer.toJson<bool>(useShallowClone),
    };
  }

  UserSetting copyWith({
    int? id,
    Value<String?> authorName = const Value.absent(),
    Value<String?> authorEmail = const Value.absent(),
    bool? useShallowClone,
  }) => UserSetting(
    id: id ?? this.id,
    authorName: authorName.present ? authorName.value : this.authorName,
    authorEmail: authorEmail.present ? authorEmail.value : this.authorEmail,
    useShallowClone: useShallowClone ?? this.useShallowClone,
  );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      id: data.id.present ? data.id.value : this.id,
      authorName: data.authorName.present
          ? data.authorName.value
          : this.authorName,
      authorEmail: data.authorEmail.present
          ? data.authorEmail.value
          : this.authorEmail,
      useShallowClone: data.useShallowClone.present
          ? data.useShallowClone.value
          : this.useShallowClone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('id: $id, ')
          ..write('authorName: $authorName, ')
          ..write('authorEmail: $authorEmail, ')
          ..write('useShallowClone: $useShallowClone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, authorName, authorEmail, useShallowClone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.id == this.id &&
          other.authorName == this.authorName &&
          other.authorEmail == this.authorEmail &&
          other.useShallowClone == this.useShallowClone);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<int> id;
  final Value<String?> authorName;
  final Value<String?> authorEmail;
  final Value<bool> useShallowClone;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.authorName = const Value.absent(),
    this.authorEmail = const Value.absent(),
    this.useShallowClone = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.authorName = const Value.absent(),
    this.authorEmail = const Value.absent(),
    this.useShallowClone = const Value.absent(),
  });
  static Insertable<UserSetting> custom({
    Expression<int>? id,
    Expression<String>? authorName,
    Expression<String>? authorEmail,
    Expression<bool>? useShallowClone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorName != null) 'author_name': authorName,
      if (authorEmail != null) 'author_email': authorEmail,
      if (useShallowClone != null) 'use_shallow_clone': useShallowClone,
    });
  }

  UserSettingsCompanion copyWith({
    Value<int>? id,
    Value<String?>? authorName,
    Value<String?>? authorEmail,
    Value<bool>? useShallowClone,
  }) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      authorEmail: authorEmail ?? this.authorEmail,
      useShallowClone: useShallowClone ?? this.useShallowClone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (authorEmail.present) {
      map['author_email'] = Variable<String>(authorEmail.value);
    }
    if (useShallowClone.present) {
      map['use_shallow_clone'] = Variable<bool>(useShallowClone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('id: $id, ')
          ..write('authorName: $authorName, ')
          ..write('authorEmail: $authorEmail, ')
          ..write('useShallowClone: $useShallowClone')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ReposTable repos = $ReposTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [repos, userSettings];
}

typedef $$ReposTableCreateCompanionBuilder =
    ReposCompanion Function({
      Value<int> id,
      required String name,
      required String localPath,
      required String remoteUrl,
      Value<String> defaultBranch,
      Value<DateTime?> lastSyncedAt,
      Value<int> unpushedCommits,
      Value<DateTime> createdAt,
    });
typedef $$ReposTableUpdateCompanionBuilder =
    ReposCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> localPath,
      Value<String> remoteUrl,
      Value<String> defaultBranch,
      Value<DateTime?> lastSyncedAt,
      Value<int> unpushedCommits,
      Value<DateTime> createdAt,
    });

class $$ReposTableFilterComposer extends Composer<_$AppDatabase, $ReposTable> {
  $$ReposTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultBranch => $composableBuilder(
    column: $table.defaultBranch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unpushedCommits => $composableBuilder(
    column: $table.unpushedCommits,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReposTableOrderingComposer
    extends Composer<_$AppDatabase, $ReposTable> {
  $$ReposTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUrl => $composableBuilder(
    column: $table.remoteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultBranch => $composableBuilder(
    column: $table.defaultBranch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unpushedCommits => $composableBuilder(
    column: $table.unpushedCommits,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReposTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReposTable> {
  $$ReposTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remoteUrl =>
      $composableBuilder(column: $table.remoteUrl, builder: (column) => column);

  GeneratedColumn<String> get defaultBranch => $composableBuilder(
    column: $table.defaultBranch,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unpushedCommits => $composableBuilder(
    column: $table.unpushedCommits,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReposTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReposTable,
          Repo,
          $$ReposTableFilterComposer,
          $$ReposTableOrderingComposer,
          $$ReposTableAnnotationComposer,
          $$ReposTableCreateCompanionBuilder,
          $$ReposTableUpdateCompanionBuilder,
          (Repo, BaseReferences<_$AppDatabase, $ReposTable, Repo>),
          Repo,
          PrefetchHooks Function()
        > {
  $$ReposTableTableManager(_$AppDatabase db, $ReposTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReposTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReposTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReposTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> remoteUrl = const Value.absent(),
                Value<String> defaultBranch = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> unpushedCommits = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReposCompanion(
                id: id,
                name: name,
                localPath: localPath,
                remoteUrl: remoteUrl,
                defaultBranch: defaultBranch,
                lastSyncedAt: lastSyncedAt,
                unpushedCommits: unpushedCommits,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String localPath,
                required String remoteUrl,
                Value<String> defaultBranch = const Value.absent(),
                Value<DateTime?> lastSyncedAt = const Value.absent(),
                Value<int> unpushedCommits = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReposCompanion.insert(
                id: id,
                name: name,
                localPath: localPath,
                remoteUrl: remoteUrl,
                defaultBranch: defaultBranch,
                lastSyncedAt: lastSyncedAt,
                unpushedCommits: unpushedCommits,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReposTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReposTable,
      Repo,
      $$ReposTableFilterComposer,
      $$ReposTableOrderingComposer,
      $$ReposTableAnnotationComposer,
      $$ReposTableCreateCompanionBuilder,
      $$ReposTableUpdateCompanionBuilder,
      (Repo, BaseReferences<_$AppDatabase, $ReposTable, Repo>),
      Repo,
      PrefetchHooks Function()
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String?> authorName,
      Value<String?> authorEmail,
      Value<bool> useShallowClone,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<String?> authorName,
      Value<String?> authorEmail,
      Value<bool> useShallowClone,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorEmail => $composableBuilder(
    column: $table.authorEmail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useShallowClone => $composableBuilder(
    column: $table.useShallowClone,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorEmail => $composableBuilder(
    column: $table.authorEmail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useShallowClone => $composableBuilder(
    column: $table.useShallowClone,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorName => $composableBuilder(
    column: $table.authorName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get authorEmail => $composableBuilder(
    column: $table.authorEmail,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get useShallowClone => $composableBuilder(
    column: $table.useShallowClone,
    builder: (column) => column,
  );
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<String?> authorEmail = const Value.absent(),
                Value<bool> useShallowClone = const Value.absent(),
              }) => UserSettingsCompanion(
                id: id,
                authorName: authorName,
                authorEmail: authorEmail,
                useShallowClone: useShallowClone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> authorName = const Value.absent(),
                Value<String?> authorEmail = const Value.absent(),
                Value<bool> useShallowClone = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                id: id,
                authorName: authorName,
                authorEmail: authorEmail,
                useShallowClone: useShallowClone,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ReposTableTableManager get repos =>
      $$ReposTableTableManager(_db, _db.repos);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
}
