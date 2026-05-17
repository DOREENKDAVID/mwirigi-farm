// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalCowsTable extends LocalCows
    with TableInfo<$LocalCowsTable, LocalCowData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
      'tag', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nicknameMeta =
      const VerificationMeta('nickname');
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
      'nickname', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _breedMeta = const VerificationMeta('breed');
  @override
  late final GeneratedColumn<String> breed = GeneratedColumn<String>(
      'breed', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _breedOriginMeta =
      const VerificationMeta('breedOrigin');
  @override
  late final GeneratedColumn<String> breedOrigin = GeneratedColumn<String>(
      'breed_origin', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusReasonMeta =
      const VerificationMeta('statusReason');
  @override
  late final GeneratedColumn<String> statusReason = GeneratedColumn<String>(
      'status_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dateOfBirthMeta =
      const VerificationMeta('dateOfBirth');
  @override
  late final GeneratedColumn<DateTime> dateOfBirth = GeneratedColumn<DateTime>(
      'date_of_birth', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _workerIdMeta =
      const VerificationMeta('workerId');
  @override
  late final GeneratedColumn<String> workerId = GeneratedColumn<String>(
      'worker_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _workerNameMeta =
      const VerificationMeta('workerName');
  @override
  late final GeneratedColumn<String> workerName = GeneratedColumn<String>(
      'worker_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _houseIdMeta =
      const VerificationMeta('houseId');
  @override
  late final GeneratedColumn<String> houseId = GeneratedColumn<String>(
      'house_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _houseNameMeta =
      const VerificationMeta('houseName');
  @override
  late final GeneratedColumn<String> houseName = GeneratedColumn<String>(
      'house_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageUrlMeta =
      const VerificationMeta('imageUrl');
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
      'image_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _acquisitionTypeMeta =
      const VerificationMeta('acquisitionType');
  @override
  late final GeneratedColumn<String> acquisitionType = GeneratedColumn<String>(
      'acquisition_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _healthNotesMeta =
      const VerificationMeta('healthNotes');
  @override
  late final GeneratedColumn<String> healthNotes = GeneratedColumn<String>(
      'health_notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _todayLitresMeta =
      const VerificationMeta('todayLitres');
  @override
  late final GeneratedColumn<double> todayLitres = GeneratedColumn<double>(
      'today_litres', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _weekAvgMeta =
      const VerificationMeta('weekAvg');
  @override
  late final GeneratedColumn<double> weekAvg = GeneratedColumn<double>(
      'week_avg', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _calvesLifetimeMeta =
      const VerificationMeta('calvesLifetime');
  @override
  late final GeneratedColumn<int> calvesLifetime = GeneratedColumn<int>(
      'calves_lifetime', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _pendingSyncMeta =
      const VerificationMeta('pendingSync');
  @override
  late final GeneratedColumn<bool> pendingSync = GeneratedColumn<bool>(
      'pending_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("pending_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _releasedAtMeta =
      const VerificationMeta('releasedAt');
  @override
  late final GeneratedColumn<DateTime> releasedAt = GeneratedColumn<DateTime>(
      'released_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        serverId,
        tag,
        nickname,
        breed,
        breedOrigin,
        status,
        statusReason,
        dateOfBirth,
        workerId,
        workerName,
        houseId,
        houseName,
        imageUrl,
        acquisitionType,
        healthNotes,
        todayLitres,
        weekAvg,
        calvesLifetime,
        updatedAt,
        pendingSync,
        releasedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_cows';
  @override
  VerificationContext validateIntegrity(Insertable<LocalCowData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    }
    if (data.containsKey('tag')) {
      context.handle(
          _tagMeta, tag.isAcceptableOrUnknown(data['tag']!, _tagMeta));
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(_nicknameMeta,
          nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta));
    }
    if (data.containsKey('breed')) {
      context.handle(
          _breedMeta, breed.isAcceptableOrUnknown(data['breed']!, _breedMeta));
    }
    if (data.containsKey('breed_origin')) {
      context.handle(
          _breedOriginMeta,
          breedOrigin.isAcceptableOrUnknown(
              data['breed_origin']!, _breedOriginMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('status_reason')) {
      context.handle(
          _statusReasonMeta,
          statusReason.isAcceptableOrUnknown(
              data['status_reason']!, _statusReasonMeta));
    }
    if (data.containsKey('date_of_birth')) {
      context.handle(
          _dateOfBirthMeta,
          dateOfBirth.isAcceptableOrUnknown(
              data['date_of_birth']!, _dateOfBirthMeta));
    }
    if (data.containsKey('worker_id')) {
      context.handle(_workerIdMeta,
          workerId.isAcceptableOrUnknown(data['worker_id']!, _workerIdMeta));
    }
    if (data.containsKey('worker_name')) {
      context.handle(
          _workerNameMeta,
          workerName.isAcceptableOrUnknown(
              data['worker_name']!, _workerNameMeta));
    }
    if (data.containsKey('house_id')) {
      context.handle(_houseIdMeta,
          houseId.isAcceptableOrUnknown(data['house_id']!, _houseIdMeta));
    }
    if (data.containsKey('house_name')) {
      context.handle(_houseNameMeta,
          houseName.isAcceptableOrUnknown(data['house_name']!, _houseNameMeta));
    }
    if (data.containsKey('image_url')) {
      context.handle(_imageUrlMeta,
          imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta));
    }
    if (data.containsKey('acquisition_type')) {
      context.handle(
          _acquisitionTypeMeta,
          acquisitionType.isAcceptableOrUnknown(
              data['acquisition_type']!, _acquisitionTypeMeta));
    }
    if (data.containsKey('health_notes')) {
      context.handle(
          _healthNotesMeta,
          healthNotes.isAcceptableOrUnknown(
              data['health_notes']!, _healthNotesMeta));
    }
    if (data.containsKey('today_litres')) {
      context.handle(
          _todayLitresMeta,
          todayLitres.isAcceptableOrUnknown(
              data['today_litres']!, _todayLitresMeta));
    }
    if (data.containsKey('week_avg')) {
      context.handle(_weekAvgMeta,
          weekAvg.isAcceptableOrUnknown(data['week_avg']!, _weekAvgMeta));
    }
    if (data.containsKey('calves_lifetime')) {
      context.handle(
          _calvesLifetimeMeta,
          calvesLifetime.isAcceptableOrUnknown(
              data['calves_lifetime']!, _calvesLifetimeMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    if (data.containsKey('pending_sync')) {
      context.handle(
          _pendingSyncMeta,
          pendingSync.isAcceptableOrUnknown(
              data['pending_sync']!, _pendingSyncMeta));
    }
    if (data.containsKey('released_at')) {
      context.handle(
          _releasedAtMeta,
          releasedAt.isAcceptableOrUnknown(
              data['released_at']!, _releasedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCowData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCowData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id']),
      tag: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tag'])!,
      nickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nickname']),
      breed: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}breed']),
      breedOrigin: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}breed_origin']),
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      statusReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status_reason']),
      dateOfBirth: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}date_of_birth']),
      workerId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}worker_id']),
      workerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}worker_name']),
      houseId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}house_id']),
      houseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}house_name']),
      imageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_url']),
      acquisitionType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}acquisition_type']),
      healthNotes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}health_notes']),
      todayLitres: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}today_litres'])!,
      weekAvg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}week_avg'])!,
      calvesLifetime: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calves_lifetime'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      pendingSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pending_sync'])!,
      releasedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}released_at']),
    );
  }

  @override
  $LocalCowsTable createAlias(String alias) {
    return $LocalCowsTable(attachedDatabase, alias);
  }
}

class LocalCowData extends DataClass implements Insertable<LocalCowData> {
  final String id;
  final String? serverId;
  final String tag;
  final String? nickname;
  final String? breed;
  final String? breedOrigin;
  final String status;
  final String? statusReason;
  final DateTime? dateOfBirth;
  final String? workerId;
  final String? workerName;
  final String? houseId;
  final String? houseName;
  final String? imageUrl;
  final String? acquisitionType;
  final String? healthNotes;
  final double todayLitres;
  final double weekAvg;
  final int calvesLifetime;
  final DateTime updatedAt;
  final bool pendingSync;

  /// Set when the cow has been released; tombstones it from the active
  /// list without an actual delete (preserves milk history references).
  final DateTime? releasedAt;
  const LocalCowData(
      {required this.id,
      this.serverId,
      required this.tag,
      this.nickname,
      this.breed,
      this.breedOrigin,
      required this.status,
      this.statusReason,
      this.dateOfBirth,
      this.workerId,
      this.workerName,
      this.houseId,
      this.houseName,
      this.imageUrl,
      this.acquisitionType,
      this.healthNotes,
      required this.todayLitres,
      required this.weekAvg,
      required this.calvesLifetime,
      required this.updatedAt,
      required this.pendingSync,
      this.releasedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    if (!nullToAbsent || breed != null) {
      map['breed'] = Variable<String>(breed);
    }
    if (!nullToAbsent || breedOrigin != null) {
      map['breed_origin'] = Variable<String>(breedOrigin);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || statusReason != null) {
      map['status_reason'] = Variable<String>(statusReason);
    }
    if (!nullToAbsent || dateOfBirth != null) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth);
    }
    if (!nullToAbsent || workerId != null) {
      map['worker_id'] = Variable<String>(workerId);
    }
    if (!nullToAbsent || workerName != null) {
      map['worker_name'] = Variable<String>(workerName);
    }
    if (!nullToAbsent || houseId != null) {
      map['house_id'] = Variable<String>(houseId);
    }
    if (!nullToAbsent || houseName != null) {
      map['house_name'] = Variable<String>(houseName);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || acquisitionType != null) {
      map['acquisition_type'] = Variable<String>(acquisitionType);
    }
    if (!nullToAbsent || healthNotes != null) {
      map['health_notes'] = Variable<String>(healthNotes);
    }
    map['today_litres'] = Variable<double>(todayLitres);
    map['week_avg'] = Variable<double>(weekAvg);
    map['calves_lifetime'] = Variable<int>(calvesLifetime);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['pending_sync'] = Variable<bool>(pendingSync);
    if (!nullToAbsent || releasedAt != null) {
      map['released_at'] = Variable<DateTime>(releasedAt);
    }
    return map;
  }

  LocalCowsCompanion toCompanion(bool nullToAbsent) {
    return LocalCowsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      tag: Value(tag),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      breed:
          breed == null && nullToAbsent ? const Value.absent() : Value(breed),
      breedOrigin: breedOrigin == null && nullToAbsent
          ? const Value.absent()
          : Value(breedOrigin),
      status: Value(status),
      statusReason: statusReason == null && nullToAbsent
          ? const Value.absent()
          : Value(statusReason),
      dateOfBirth: dateOfBirth == null && nullToAbsent
          ? const Value.absent()
          : Value(dateOfBirth),
      workerId: workerId == null && nullToAbsent
          ? const Value.absent()
          : Value(workerId),
      workerName: workerName == null && nullToAbsent
          ? const Value.absent()
          : Value(workerName),
      houseId: houseId == null && nullToAbsent
          ? const Value.absent()
          : Value(houseId),
      houseName: houseName == null && nullToAbsent
          ? const Value.absent()
          : Value(houseName),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      acquisitionType: acquisitionType == null && nullToAbsent
          ? const Value.absent()
          : Value(acquisitionType),
      healthNotes: healthNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(healthNotes),
      todayLitres: Value(todayLitres),
      weekAvg: Value(weekAvg),
      calvesLifetime: Value(calvesLifetime),
      updatedAt: Value(updatedAt),
      pendingSync: Value(pendingSync),
      releasedAt: releasedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(releasedAt),
    );
  }

  factory LocalCowData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCowData(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      tag: serializer.fromJson<String>(json['tag']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      breed: serializer.fromJson<String?>(json['breed']),
      breedOrigin: serializer.fromJson<String?>(json['breedOrigin']),
      status: serializer.fromJson<String>(json['status']),
      statusReason: serializer.fromJson<String?>(json['statusReason']),
      dateOfBirth: serializer.fromJson<DateTime?>(json['dateOfBirth']),
      workerId: serializer.fromJson<String?>(json['workerId']),
      workerName: serializer.fromJson<String?>(json['workerName']),
      houseId: serializer.fromJson<String?>(json['houseId']),
      houseName: serializer.fromJson<String?>(json['houseName']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      acquisitionType: serializer.fromJson<String?>(json['acquisitionType']),
      healthNotes: serializer.fromJson<String?>(json['healthNotes']),
      todayLitres: serializer.fromJson<double>(json['todayLitres']),
      weekAvg: serializer.fromJson<double>(json['weekAvg']),
      calvesLifetime: serializer.fromJson<int>(json['calvesLifetime']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      pendingSync: serializer.fromJson<bool>(json['pendingSync']),
      releasedAt: serializer.fromJson<DateTime?>(json['releasedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'tag': serializer.toJson<String>(tag),
      'nickname': serializer.toJson<String?>(nickname),
      'breed': serializer.toJson<String?>(breed),
      'breedOrigin': serializer.toJson<String?>(breedOrigin),
      'status': serializer.toJson<String>(status),
      'statusReason': serializer.toJson<String?>(statusReason),
      'dateOfBirth': serializer.toJson<DateTime?>(dateOfBirth),
      'workerId': serializer.toJson<String?>(workerId),
      'workerName': serializer.toJson<String?>(workerName),
      'houseId': serializer.toJson<String?>(houseId),
      'houseName': serializer.toJson<String?>(houseName),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'acquisitionType': serializer.toJson<String?>(acquisitionType),
      'healthNotes': serializer.toJson<String?>(healthNotes),
      'todayLitres': serializer.toJson<double>(todayLitres),
      'weekAvg': serializer.toJson<double>(weekAvg),
      'calvesLifetime': serializer.toJson<int>(calvesLifetime),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'pendingSync': serializer.toJson<bool>(pendingSync),
      'releasedAt': serializer.toJson<DateTime?>(releasedAt),
    };
  }

  LocalCowData copyWith(
          {String? id,
          Value<String?> serverId = const Value.absent(),
          String? tag,
          Value<String?> nickname = const Value.absent(),
          Value<String?> breed = const Value.absent(),
          Value<String?> breedOrigin = const Value.absent(),
          String? status,
          Value<String?> statusReason = const Value.absent(),
          Value<DateTime?> dateOfBirth = const Value.absent(),
          Value<String?> workerId = const Value.absent(),
          Value<String?> workerName = const Value.absent(),
          Value<String?> houseId = const Value.absent(),
          Value<String?> houseName = const Value.absent(),
          Value<String?> imageUrl = const Value.absent(),
          Value<String?> acquisitionType = const Value.absent(),
          Value<String?> healthNotes = const Value.absent(),
          double? todayLitres,
          double? weekAvg,
          int? calvesLifetime,
          DateTime? updatedAt,
          bool? pendingSync,
          Value<DateTime?> releasedAt = const Value.absent()}) =>
      LocalCowData(
        id: id ?? this.id,
        serverId: serverId.present ? serverId.value : this.serverId,
        tag: tag ?? this.tag,
        nickname: nickname.present ? nickname.value : this.nickname,
        breed: breed.present ? breed.value : this.breed,
        breedOrigin: breedOrigin.present ? breedOrigin.value : this.breedOrigin,
        status: status ?? this.status,
        statusReason:
            statusReason.present ? statusReason.value : this.statusReason,
        dateOfBirth: dateOfBirth.present ? dateOfBirth.value : this.dateOfBirth,
        workerId: workerId.present ? workerId.value : this.workerId,
        workerName: workerName.present ? workerName.value : this.workerName,
        houseId: houseId.present ? houseId.value : this.houseId,
        houseName: houseName.present ? houseName.value : this.houseName,
        imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
        acquisitionType: acquisitionType.present
            ? acquisitionType.value
            : this.acquisitionType,
        healthNotes: healthNotes.present ? healthNotes.value : this.healthNotes,
        todayLitres: todayLitres ?? this.todayLitres,
        weekAvg: weekAvg ?? this.weekAvg,
        calvesLifetime: calvesLifetime ?? this.calvesLifetime,
        updatedAt: updatedAt ?? this.updatedAt,
        pendingSync: pendingSync ?? this.pendingSync,
        releasedAt: releasedAt.present ? releasedAt.value : this.releasedAt,
      );
  LocalCowData copyWithCompanion(LocalCowsCompanion data) {
    return LocalCowData(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      tag: data.tag.present ? data.tag.value : this.tag,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      breed: data.breed.present ? data.breed.value : this.breed,
      breedOrigin:
          data.breedOrigin.present ? data.breedOrigin.value : this.breedOrigin,
      status: data.status.present ? data.status.value : this.status,
      statusReason: data.statusReason.present
          ? data.statusReason.value
          : this.statusReason,
      dateOfBirth:
          data.dateOfBirth.present ? data.dateOfBirth.value : this.dateOfBirth,
      workerId: data.workerId.present ? data.workerId.value : this.workerId,
      workerName:
          data.workerName.present ? data.workerName.value : this.workerName,
      houseId: data.houseId.present ? data.houseId.value : this.houseId,
      houseName: data.houseName.present ? data.houseName.value : this.houseName,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      acquisitionType: data.acquisitionType.present
          ? data.acquisitionType.value
          : this.acquisitionType,
      healthNotes:
          data.healthNotes.present ? data.healthNotes.value : this.healthNotes,
      todayLitres:
          data.todayLitres.present ? data.todayLitres.value : this.todayLitres,
      weekAvg: data.weekAvg.present ? data.weekAvg.value : this.weekAvg,
      calvesLifetime: data.calvesLifetime.present
          ? data.calvesLifetime.value
          : this.calvesLifetime,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      pendingSync:
          data.pendingSync.present ? data.pendingSync.value : this.pendingSync,
      releasedAt:
          data.releasedAt.present ? data.releasedAt.value : this.releasedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCowData(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('tag: $tag, ')
          ..write('nickname: $nickname, ')
          ..write('breed: $breed, ')
          ..write('breedOrigin: $breedOrigin, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('workerId: $workerId, ')
          ..write('workerName: $workerName, ')
          ..write('houseId: $houseId, ')
          ..write('houseName: $houseName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('acquisitionType: $acquisitionType, ')
          ..write('healthNotes: $healthNotes, ')
          ..write('todayLitres: $todayLitres, ')
          ..write('weekAvg: $weekAvg, ')
          ..write('calvesLifetime: $calvesLifetime, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('releasedAt: $releasedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        serverId,
        tag,
        nickname,
        breed,
        breedOrigin,
        status,
        statusReason,
        dateOfBirth,
        workerId,
        workerName,
        houseId,
        houseName,
        imageUrl,
        acquisitionType,
        healthNotes,
        todayLitres,
        weekAvg,
        calvesLifetime,
        updatedAt,
        pendingSync,
        releasedAt
      ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCowData &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.tag == this.tag &&
          other.nickname == this.nickname &&
          other.breed == this.breed &&
          other.breedOrigin == this.breedOrigin &&
          other.status == this.status &&
          other.statusReason == this.statusReason &&
          other.dateOfBirth == this.dateOfBirth &&
          other.workerId == this.workerId &&
          other.workerName == this.workerName &&
          other.houseId == this.houseId &&
          other.houseName == this.houseName &&
          other.imageUrl == this.imageUrl &&
          other.acquisitionType == this.acquisitionType &&
          other.healthNotes == this.healthNotes &&
          other.todayLitres == this.todayLitres &&
          other.weekAvg == this.weekAvg &&
          other.calvesLifetime == this.calvesLifetime &&
          other.updatedAt == this.updatedAt &&
          other.pendingSync == this.pendingSync &&
          other.releasedAt == this.releasedAt);
}

class LocalCowsCompanion extends UpdateCompanion<LocalCowData> {
  final Value<String> id;
  final Value<String?> serverId;
  final Value<String> tag;
  final Value<String?> nickname;
  final Value<String?> breed;
  final Value<String?> breedOrigin;
  final Value<String> status;
  final Value<String?> statusReason;
  final Value<DateTime?> dateOfBirth;
  final Value<String?> workerId;
  final Value<String?> workerName;
  final Value<String?> houseId;
  final Value<String?> houseName;
  final Value<String?> imageUrl;
  final Value<String?> acquisitionType;
  final Value<String?> healthNotes;
  final Value<double> todayLitres;
  final Value<double> weekAvg;
  final Value<int> calvesLifetime;
  final Value<DateTime> updatedAt;
  final Value<bool> pendingSync;
  final Value<DateTime?> releasedAt;
  final Value<int> rowid;
  const LocalCowsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.tag = const Value.absent(),
    this.nickname = const Value.absent(),
    this.breed = const Value.absent(),
    this.breedOrigin = const Value.absent(),
    this.status = const Value.absent(),
    this.statusReason = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.workerId = const Value.absent(),
    this.workerName = const Value.absent(),
    this.houseId = const Value.absent(),
    this.houseName = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.acquisitionType = const Value.absent(),
    this.healthNotes = const Value.absent(),
    this.todayLitres = const Value.absent(),
    this.weekAvg = const Value.absent(),
    this.calvesLifetime = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalCowsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String tag,
    this.nickname = const Value.absent(),
    this.breed = const Value.absent(),
    this.breedOrigin = const Value.absent(),
    required String status,
    this.statusReason = const Value.absent(),
    this.dateOfBirth = const Value.absent(),
    this.workerId = const Value.absent(),
    this.workerName = const Value.absent(),
    this.houseId = const Value.absent(),
    this.houseName = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.acquisitionType = const Value.absent(),
    this.healthNotes = const Value.absent(),
    this.todayLitres = const Value.absent(),
    this.weekAvg = const Value.absent(),
    this.calvesLifetime = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.pendingSync = const Value.absent(),
    this.releasedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        tag = Value(tag),
        status = Value(status);
  static Insertable<LocalCowData> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? tag,
    Expression<String>? nickname,
    Expression<String>? breed,
    Expression<String>? breedOrigin,
    Expression<String>? status,
    Expression<String>? statusReason,
    Expression<DateTime>? dateOfBirth,
    Expression<String>? workerId,
    Expression<String>? workerName,
    Expression<String>? houseId,
    Expression<String>? houseName,
    Expression<String>? imageUrl,
    Expression<String>? acquisitionType,
    Expression<String>? healthNotes,
    Expression<double>? todayLitres,
    Expression<double>? weekAvg,
    Expression<int>? calvesLifetime,
    Expression<DateTime>? updatedAt,
    Expression<bool>? pendingSync,
    Expression<DateTime>? releasedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (tag != null) 'tag': tag,
      if (nickname != null) 'nickname': nickname,
      if (breed != null) 'breed': breed,
      if (breedOrigin != null) 'breed_origin': breedOrigin,
      if (status != null) 'status': status,
      if (statusReason != null) 'status_reason': statusReason,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (workerId != null) 'worker_id': workerId,
      if (workerName != null) 'worker_name': workerName,
      if (houseId != null) 'house_id': houseId,
      if (houseName != null) 'house_name': houseName,
      if (imageUrl != null) 'image_url': imageUrl,
      if (acquisitionType != null) 'acquisition_type': acquisitionType,
      if (healthNotes != null) 'health_notes': healthNotes,
      if (todayLitres != null) 'today_litres': todayLitres,
      if (weekAvg != null) 'week_avg': weekAvg,
      if (calvesLifetime != null) 'calves_lifetime': calvesLifetime,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (pendingSync != null) 'pending_sync': pendingSync,
      if (releasedAt != null) 'released_at': releasedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalCowsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? serverId,
      Value<String>? tag,
      Value<String?>? nickname,
      Value<String?>? breed,
      Value<String?>? breedOrigin,
      Value<String>? status,
      Value<String?>? statusReason,
      Value<DateTime?>? dateOfBirth,
      Value<String?>? workerId,
      Value<String?>? workerName,
      Value<String?>? houseId,
      Value<String?>? houseName,
      Value<String?>? imageUrl,
      Value<String?>? acquisitionType,
      Value<String?>? healthNotes,
      Value<double>? todayLitres,
      Value<double>? weekAvg,
      Value<int>? calvesLifetime,
      Value<DateTime>? updatedAt,
      Value<bool>? pendingSync,
      Value<DateTime?>? releasedAt,
      Value<int>? rowid}) {
    return LocalCowsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      tag: tag ?? this.tag,
      nickname: nickname ?? this.nickname,
      breed: breed ?? this.breed,
      breedOrigin: breedOrigin ?? this.breedOrigin,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      houseId: houseId ?? this.houseId,
      houseName: houseName ?? this.houseName,
      imageUrl: imageUrl ?? this.imageUrl,
      acquisitionType: acquisitionType ?? this.acquisitionType,
      healthNotes: healthNotes ?? this.healthNotes,
      todayLitres: todayLitres ?? this.todayLitres,
      weekAvg: weekAvg ?? this.weekAvg,
      calvesLifetime: calvesLifetime ?? this.calvesLifetime,
      updatedAt: updatedAt ?? this.updatedAt,
      pendingSync: pendingSync ?? this.pendingSync,
      releasedAt: releasedAt ?? this.releasedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (breed.present) {
      map['breed'] = Variable<String>(breed.value);
    }
    if (breedOrigin.present) {
      map['breed_origin'] = Variable<String>(breedOrigin.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (statusReason.present) {
      map['status_reason'] = Variable<String>(statusReason.value);
    }
    if (dateOfBirth.present) {
      map['date_of_birth'] = Variable<DateTime>(dateOfBirth.value);
    }
    if (workerId.present) {
      map['worker_id'] = Variable<String>(workerId.value);
    }
    if (workerName.present) {
      map['worker_name'] = Variable<String>(workerName.value);
    }
    if (houseId.present) {
      map['house_id'] = Variable<String>(houseId.value);
    }
    if (houseName.present) {
      map['house_name'] = Variable<String>(houseName.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (acquisitionType.present) {
      map['acquisition_type'] = Variable<String>(acquisitionType.value);
    }
    if (healthNotes.present) {
      map['health_notes'] = Variable<String>(healthNotes.value);
    }
    if (todayLitres.present) {
      map['today_litres'] = Variable<double>(todayLitres.value);
    }
    if (weekAvg.present) {
      map['week_avg'] = Variable<double>(weekAvg.value);
    }
    if (calvesLifetime.present) {
      map['calves_lifetime'] = Variable<int>(calvesLifetime.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (pendingSync.present) {
      map['pending_sync'] = Variable<bool>(pendingSync.value);
    }
    if (releasedAt.present) {
      map['released_at'] = Variable<DateTime>(releasedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCowsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('tag: $tag, ')
          ..write('nickname: $nickname, ')
          ..write('breed: $breed, ')
          ..write('breedOrigin: $breedOrigin, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('dateOfBirth: $dateOfBirth, ')
          ..write('workerId: $workerId, ')
          ..write('workerName: $workerName, ')
          ..write('houseId: $houseId, ')
          ..write('houseName: $houseName, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('acquisitionType: $acquisitionType, ')
          ..write('healthNotes: $healthNotes, ')
          ..write('todayLitres: $todayLitres, ')
          ..write('weekAvg: $weekAvg, ')
          ..write('calvesLifetime: $calvesLifetime, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('pendingSync: $pendingSync, ')
          ..write('releasedAt: $releasedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingSyncActionsTable extends PendingSyncActions
    with TableInfo<$PendingSyncActionsTable, PendingSyncActionData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncActionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endpointMeta =
      const VerificationMeta('endpoint');
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
      'endpoint', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
      'entity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localRowIdMeta =
      const VerificationMeta('localRowId');
  @override
  late final GeneratedColumn<String> localRowId = GeneratedColumn<String>(
      'local_row_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _actorIdMeta =
      const VerificationMeta('actorId');
  @override
  late final GeneratedColumn<String> actorId = GeneratedColumn<String>(
      'actor_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('PENDING'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        endpoint,
        method,
        payload,
        entity,
        localRowId,
        actorId,
        syncStatus,
        retryCount,
        lastError,
        createdAt,
        lastAttemptAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sync_actions';
  @override
  VerificationContext validateIntegrity(
      Insertable<PendingSyncActionData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(_endpointMeta,
          endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta));
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(_entityMeta,
          entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('local_row_id')) {
      context.handle(
          _localRowIdMeta,
          localRowId.isAcceptableOrUnknown(
              data['local_row_id']!, _localRowIdMeta));
    }
    if (data.containsKey('actor_id')) {
      context.handle(_actorIdMeta,
          actorId.isAcceptableOrUnknown(data['actor_id']!, _actorIdMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSyncActionData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncActionData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      endpoint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endpoint'])!,
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      entity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      localRowId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_row_id']),
      actorId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}actor_id']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
    );
  }

  @override
  $PendingSyncActionsTable createAlias(String alias) {
    return $PendingSyncActionsTable(attachedDatabase, alias);
  }
}

class PendingSyncActionData extends DataClass
    implements Insertable<PendingSyncActionData> {
  final String id;

  /// e.g. "/dairy/cows" — the relative path under /api.
  final String endpoint;

  /// HTTP verb: POST | PUT | PATCH | DELETE.
  final String method;

  /// JSON-encoded request body.
  final String payload;

  /// Entity name this action mutates (Cow, Bull, BrooderOccurrence...).
  /// Used to map success responses back to the matching local row.
  final String entity;

  /// Local id of the row this action belongs to (so we can flip
  /// pendingSync = false / patch serverId once the action succeeds).
  final String? localRowId;

  /// User who originated the action — written to the AuditLog by the
  /// server once it reaches it, but kept locally too so we can show
  /// "queued by X" in the Sync Status page.
  final String? actorId;

  /// PENDING | IN_FLIGHT | FAILED. Successful actions are deleted from
  /// the table outright; we never need to read the "DONE" state back.
  final String syncStatus;
  final int retryCount;

  /// Last error message — surfaced on the Sync Status page so a user
  /// can see why something is stuck.
  final String? lastError;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  const PendingSyncActionData(
      {required this.id,
      required this.endpoint,
      required this.method,
      required this.payload,
      required this.entity,
      this.localRowId,
      this.actorId,
      required this.syncStatus,
      required this.retryCount,
      this.lastError,
      required this.createdAt,
      this.lastAttemptAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['endpoint'] = Variable<String>(endpoint);
    map['method'] = Variable<String>(method);
    map['payload'] = Variable<String>(payload);
    map['entity'] = Variable<String>(entity);
    if (!nullToAbsent || localRowId != null) {
      map['local_row_id'] = Variable<String>(localRowId);
    }
    if (!nullToAbsent || actorId != null) {
      map['actor_id'] = Variable<String>(actorId);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    return map;
  }

  PendingSyncActionsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncActionsCompanion(
      id: Value(id),
      endpoint: Value(endpoint),
      method: Value(method),
      payload: Value(payload),
      entity: Value(entity),
      localRowId: localRowId == null && nullToAbsent
          ? const Value.absent()
          : Value(localRowId),
      actorId: actorId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorId),
      syncStatus: Value(syncStatus),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
    );
  }

  factory PendingSyncActionData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncActionData(
      id: serializer.fromJson<String>(json['id']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      method: serializer.fromJson<String>(json['method']),
      payload: serializer.fromJson<String>(json['payload']),
      entity: serializer.fromJson<String>(json['entity']),
      localRowId: serializer.fromJson<String?>(json['localRowId']),
      actorId: serializer.fromJson<String?>(json['actorId']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'endpoint': serializer.toJson<String>(endpoint),
      'method': serializer.toJson<String>(method),
      'payload': serializer.toJson<String>(payload),
      'entity': serializer.toJson<String>(entity),
      'localRowId': serializer.toJson<String?>(localRowId),
      'actorId': serializer.toJson<String?>(actorId),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
    };
  }

  PendingSyncActionData copyWith(
          {String? id,
          String? endpoint,
          String? method,
          String? payload,
          String? entity,
          Value<String?> localRowId = const Value.absent(),
          Value<String?> actorId = const Value.absent(),
          String? syncStatus,
          int? retryCount,
          Value<String?> lastError = const Value.absent(),
          DateTime? createdAt,
          Value<DateTime?> lastAttemptAt = const Value.absent()}) =>
      PendingSyncActionData(
        id: id ?? this.id,
        endpoint: endpoint ?? this.endpoint,
        method: method ?? this.method,
        payload: payload ?? this.payload,
        entity: entity ?? this.entity,
        localRowId: localRowId.present ? localRowId.value : this.localRowId,
        actorId: actorId.present ? actorId.value : this.actorId,
        syncStatus: syncStatus ?? this.syncStatus,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        createdAt: createdAt ?? this.createdAt,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
      );
  PendingSyncActionData copyWithCompanion(PendingSyncActionsCompanion data) {
    return PendingSyncActionData(
      id: data.id.present ? data.id.value : this.id,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      method: data.method.present ? data.method.value : this.method,
      payload: data.payload.present ? data.payload.value : this.payload,
      entity: data.entity.present ? data.entity.value : this.entity,
      localRowId:
          data.localRowId.present ? data.localRowId.value : this.localRowId,
      actorId: data.actorId.present ? data.actorId.value : this.actorId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncActionData(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('entity: $entity, ')
          ..write('localRowId: $localRowId, ')
          ..write('actorId: $actorId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      endpoint,
      method,
      payload,
      entity,
      localRowId,
      actorId,
      syncStatus,
      retryCount,
      lastError,
      createdAt,
      lastAttemptAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncActionData &&
          other.id == this.id &&
          other.endpoint == this.endpoint &&
          other.method == this.method &&
          other.payload == this.payload &&
          other.entity == this.entity &&
          other.localRowId == this.localRowId &&
          other.actorId == this.actorId &&
          other.syncStatus == this.syncStatus &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt &&
          other.lastAttemptAt == this.lastAttemptAt);
}

class PendingSyncActionsCompanion
    extends UpdateCompanion<PendingSyncActionData> {
  final Value<String> id;
  final Value<String> endpoint;
  final Value<String> method;
  final Value<String> payload;
  final Value<String> entity;
  final Value<String?> localRowId;
  final Value<String?> actorId;
  final Value<String> syncStatus;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<int> rowid;
  const PendingSyncActionsCompanion({
    this.id = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.method = const Value.absent(),
    this.payload = const Value.absent(),
    this.entity = const Value.absent(),
    this.localRowId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingSyncActionsCompanion.insert({
    required String id,
    required String endpoint,
    required String method,
    required String payload,
    required String entity,
    this.localRowId = const Value.absent(),
    this.actorId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        endpoint = Value(endpoint),
        method = Value(method),
        payload = Value(payload),
        entity = Value(entity);
  static Insertable<PendingSyncActionData> custom({
    Expression<String>? id,
    Expression<String>? endpoint,
    Expression<String>? method,
    Expression<String>? payload,
    Expression<String>? entity,
    Expression<String>? localRowId,
    Expression<String>? actorId,
    Expression<String>? syncStatus,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (payload != null) 'payload': payload,
      if (entity != null) 'entity': entity,
      if (localRowId != null) 'local_row_id': localRowId,
      if (actorId != null) 'actor_id': actorId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingSyncActionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? endpoint,
      Value<String>? method,
      Value<String>? payload,
      Value<String>? entity,
      Value<String?>? localRowId,
      Value<String?>? actorId,
      Value<String>? syncStatus,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastAttemptAt,
      Value<int>? rowid}) {
    return PendingSyncActionsCompanion(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      entity: entity ?? this.entity,
      localRowId: localRowId ?? this.localRowId,
      actorId: actorId ?? this.actorId,
      syncStatus: syncStatus ?? this.syncStatus,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (localRowId.present) {
      map['local_row_id'] = Variable<String>(localRowId.value);
    }
    if (actorId.present) {
      map['actor_id'] = Variable<String>(actorId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncActionsCompanion(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('entity: $entity, ')
          ..write('localRowId: $localRowId, ')
          ..write('actorId: $actorId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
      'entity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [entity, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(Insertable<SyncStateData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta,
          entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      entity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String entity;
  final DateTime? lastSyncedAt;
  const SyncStateData({required this.entity, this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      entity: Value(entity),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory SyncStateData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      entity: serializer.fromJson<String>(json['entity']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  SyncStateData copyWith(
          {String? entity,
          Value<DateTime?> lastSyncedAt = const Value.absent()}) =>
      SyncStateData(
        entity: entity ?? this.entity,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
      );
  SyncStateData copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateData(
      entity: data.entity.present ? data.entity.value : this.entity,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('entity: $entity, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.entity == this.entity &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> entity;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.entity = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String entity,
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity);
  static Insertable<SyncStateData> custom({
    Expression<String>? entity,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith(
      {Value<String>? entity,
      Value<DateTime?>? lastSyncedAt,
      Value<int>? rowid}) {
    return SyncStatesCompanion(
      entity: entity ?? this.entity,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('entity: $entity, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalDatabase extends GeneratedDatabase {
  _$LocalDatabase(QueryExecutor e) : super(e);
  $LocalDatabaseManager get managers => $LocalDatabaseManager(this);
  late final $LocalCowsTable localCows = $LocalCowsTable(this);
  late final $PendingSyncActionsTable pendingSyncActions =
      $PendingSyncActionsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [localCows, pendingSyncActions, syncStates];
}

typedef $$LocalCowsTableCreateCompanionBuilder = LocalCowsCompanion Function({
  required String id,
  Value<String?> serverId,
  required String tag,
  Value<String?> nickname,
  Value<String?> breed,
  Value<String?> breedOrigin,
  required String status,
  Value<String?> statusReason,
  Value<DateTime?> dateOfBirth,
  Value<String?> workerId,
  Value<String?> workerName,
  Value<String?> houseId,
  Value<String?> houseName,
  Value<String?> imageUrl,
  Value<String?> acquisitionType,
  Value<String?> healthNotes,
  Value<double> todayLitres,
  Value<double> weekAvg,
  Value<int> calvesLifetime,
  Value<DateTime> updatedAt,
  Value<bool> pendingSync,
  Value<DateTime?> releasedAt,
  Value<int> rowid,
});
typedef $$LocalCowsTableUpdateCompanionBuilder = LocalCowsCompanion Function({
  Value<String> id,
  Value<String?> serverId,
  Value<String> tag,
  Value<String?> nickname,
  Value<String?> breed,
  Value<String?> breedOrigin,
  Value<String> status,
  Value<String?> statusReason,
  Value<DateTime?> dateOfBirth,
  Value<String?> workerId,
  Value<String?> workerName,
  Value<String?> houseId,
  Value<String?> houseName,
  Value<String?> imageUrl,
  Value<String?> acquisitionType,
  Value<String?> healthNotes,
  Value<double> todayLitres,
  Value<double> weekAvg,
  Value<int> calvesLifetime,
  Value<DateTime> updatedAt,
  Value<bool> pendingSync,
  Value<DateTime?> releasedAt,
  Value<int> rowid,
});

class $$LocalCowsTableFilterComposer
    extends Composer<_$LocalDatabase, $LocalCowsTable> {
  $$LocalCowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get breed => $composableBuilder(
      column: $table.breed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get breedOrigin => $composableBuilder(
      column: $table.breedOrigin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get statusReason => $composableBuilder(
      column: $table.statusReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get dateOfBirth => $composableBuilder(
      column: $table.dateOfBirth, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workerId => $composableBuilder(
      column: $table.workerId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workerName => $composableBuilder(
      column: $table.workerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get houseId => $composableBuilder(
      column: $table.houseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get houseName => $composableBuilder(
      column: $table.houseName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get acquisitionType => $composableBuilder(
      column: $table.acquisitionType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get healthNotes => $composableBuilder(
      column: $table.healthNotes, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get todayLitres => $composableBuilder(
      column: $table.todayLitres, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weekAvg => $composableBuilder(
      column: $table.weekAvg, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get calvesLifetime => $composableBuilder(
      column: $table.calvesLifetime,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get releasedAt => $composableBuilder(
      column: $table.releasedAt, builder: (column) => ColumnFilters(column));
}

class $$LocalCowsTableOrderingComposer
    extends Composer<_$LocalDatabase, $LocalCowsTable> {
  $$LocalCowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tag => $composableBuilder(
      column: $table.tag, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get breed => $composableBuilder(
      column: $table.breed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get breedOrigin => $composableBuilder(
      column: $table.breedOrigin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get statusReason => $composableBuilder(
      column: $table.statusReason,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get dateOfBirth => $composableBuilder(
      column: $table.dateOfBirth, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workerId => $composableBuilder(
      column: $table.workerId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workerName => $composableBuilder(
      column: $table.workerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get houseId => $composableBuilder(
      column: $table.houseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get houseName => $composableBuilder(
      column: $table.houseName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageUrl => $composableBuilder(
      column: $table.imageUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get acquisitionType => $composableBuilder(
      column: $table.acquisitionType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get healthNotes => $composableBuilder(
      column: $table.healthNotes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get todayLitres => $composableBuilder(
      column: $table.todayLitres, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weekAvg => $composableBuilder(
      column: $table.weekAvg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get calvesLifetime => $composableBuilder(
      column: $table.calvesLifetime,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get releasedAt => $composableBuilder(
      column: $table.releasedAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalCowsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $LocalCowsTable> {
  $$LocalCowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get breed =>
      $composableBuilder(column: $table.breed, builder: (column) => column);

  GeneratedColumn<String> get breedOrigin => $composableBuilder(
      column: $table.breedOrigin, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get statusReason => $composableBuilder(
      column: $table.statusReason, builder: (column) => column);

  GeneratedColumn<DateTime> get dateOfBirth => $composableBuilder(
      column: $table.dateOfBirth, builder: (column) => column);

  GeneratedColumn<String> get workerId =>
      $composableBuilder(column: $table.workerId, builder: (column) => column);

  GeneratedColumn<String> get workerName => $composableBuilder(
      column: $table.workerName, builder: (column) => column);

  GeneratedColumn<String> get houseId =>
      $composableBuilder(column: $table.houseId, builder: (column) => column);

  GeneratedColumn<String> get houseName =>
      $composableBuilder(column: $table.houseName, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get acquisitionType => $composableBuilder(
      column: $table.acquisitionType, builder: (column) => column);

  GeneratedColumn<String> get healthNotes => $composableBuilder(
      column: $table.healthNotes, builder: (column) => column);

  GeneratedColumn<double> get todayLitres => $composableBuilder(
      column: $table.todayLitres, builder: (column) => column);

  GeneratedColumn<double> get weekAvg =>
      $composableBuilder(column: $table.weekAvg, builder: (column) => column);

  GeneratedColumn<int> get calvesLifetime => $composableBuilder(
      column: $table.calvesLifetime, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get pendingSync => $composableBuilder(
      column: $table.pendingSync, builder: (column) => column);

  GeneratedColumn<DateTime> get releasedAt => $composableBuilder(
      column: $table.releasedAt, builder: (column) => column);
}

class $$LocalCowsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $LocalCowsTable,
    LocalCowData,
    $$LocalCowsTableFilterComposer,
    $$LocalCowsTableOrderingComposer,
    $$LocalCowsTableAnnotationComposer,
    $$LocalCowsTableCreateCompanionBuilder,
    $$LocalCowsTableUpdateCompanionBuilder,
    (
      LocalCowData,
      BaseReferences<_$LocalDatabase, $LocalCowsTable, LocalCowData>
    ),
    LocalCowData,
    PrefetchHooks Function()> {
  $$LocalCowsTableTableManager(_$LocalDatabase db, $LocalCowsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> serverId = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<String?> nickname = const Value.absent(),
            Value<String?> breed = const Value.absent(),
            Value<String?> breedOrigin = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> statusReason = const Value.absent(),
            Value<DateTime?> dateOfBirth = const Value.absent(),
            Value<String?> workerId = const Value.absent(),
            Value<String?> workerName = const Value.absent(),
            Value<String?> houseId = const Value.absent(),
            Value<String?> houseName = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> acquisitionType = const Value.absent(),
            Value<String?> healthNotes = const Value.absent(),
            Value<double> todayLitres = const Value.absent(),
            Value<double> weekAvg = const Value.absent(),
            Value<int> calvesLifetime = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> pendingSync = const Value.absent(),
            Value<DateTime?> releasedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCowsCompanion(
            id: id,
            serverId: serverId,
            tag: tag,
            nickname: nickname,
            breed: breed,
            breedOrigin: breedOrigin,
            status: status,
            statusReason: statusReason,
            dateOfBirth: dateOfBirth,
            workerId: workerId,
            workerName: workerName,
            houseId: houseId,
            houseName: houseName,
            imageUrl: imageUrl,
            acquisitionType: acquisitionType,
            healthNotes: healthNotes,
            todayLitres: todayLitres,
            weekAvg: weekAvg,
            calvesLifetime: calvesLifetime,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            releasedAt: releasedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> serverId = const Value.absent(),
            required String tag,
            Value<String?> nickname = const Value.absent(),
            Value<String?> breed = const Value.absent(),
            Value<String?> breedOrigin = const Value.absent(),
            required String status,
            Value<String?> statusReason = const Value.absent(),
            Value<DateTime?> dateOfBirth = const Value.absent(),
            Value<String?> workerId = const Value.absent(),
            Value<String?> workerName = const Value.absent(),
            Value<String?> houseId = const Value.absent(),
            Value<String?> houseName = const Value.absent(),
            Value<String?> imageUrl = const Value.absent(),
            Value<String?> acquisitionType = const Value.absent(),
            Value<String?> healthNotes = const Value.absent(),
            Value<double> todayLitres = const Value.absent(),
            Value<double> weekAvg = const Value.absent(),
            Value<int> calvesLifetime = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> pendingSync = const Value.absent(),
            Value<DateTime?> releasedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalCowsCompanion.insert(
            id: id,
            serverId: serverId,
            tag: tag,
            nickname: nickname,
            breed: breed,
            breedOrigin: breedOrigin,
            status: status,
            statusReason: statusReason,
            dateOfBirth: dateOfBirth,
            workerId: workerId,
            workerName: workerName,
            houseId: houseId,
            houseName: houseName,
            imageUrl: imageUrl,
            acquisitionType: acquisitionType,
            healthNotes: healthNotes,
            todayLitres: todayLitres,
            weekAvg: weekAvg,
            calvesLifetime: calvesLifetime,
            updatedAt: updatedAt,
            pendingSync: pendingSync,
            releasedAt: releasedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalCowsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $LocalCowsTable,
    LocalCowData,
    $$LocalCowsTableFilterComposer,
    $$LocalCowsTableOrderingComposer,
    $$LocalCowsTableAnnotationComposer,
    $$LocalCowsTableCreateCompanionBuilder,
    $$LocalCowsTableUpdateCompanionBuilder,
    (
      LocalCowData,
      BaseReferences<_$LocalDatabase, $LocalCowsTable, LocalCowData>
    ),
    LocalCowData,
    PrefetchHooks Function()>;
typedef $$PendingSyncActionsTableCreateCompanionBuilder
    = PendingSyncActionsCompanion Function({
  required String id,
  required String endpoint,
  required String method,
  required String payload,
  required String entity,
  Value<String?> localRowId,
  Value<String?> actorId,
  Value<String> syncStatus,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> rowid,
});
typedef $$PendingSyncActionsTableUpdateCompanionBuilder
    = PendingSyncActionsCompanion Function({
  Value<String> id,
  Value<String> endpoint,
  Value<String> method,
  Value<String> payload,
  Value<String> entity,
  Value<String?> localRowId,
  Value<String?> actorId,
  Value<String> syncStatus,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<DateTime> createdAt,
  Value<DateTime?> lastAttemptAt,
  Value<int> rowid,
});

class $$PendingSyncActionsTableFilterComposer
    extends Composer<_$LocalDatabase, $PendingSyncActionsTable> {
  $$PendingSyncActionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localRowId => $composableBuilder(
      column: $table.localRowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));
}

class $$PendingSyncActionsTableOrderingComposer
    extends Composer<_$LocalDatabase, $PendingSyncActionsTable> {
  $$PendingSyncActionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localRowId => $composableBuilder(
      column: $table.localRowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorId => $composableBuilder(
      column: $table.actorId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));
}

class $$PendingSyncActionsTableAnnotationComposer
    extends Composer<_$LocalDatabase, $PendingSyncActionsTable> {
  $$PendingSyncActionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get localRowId => $composableBuilder(
      column: $table.localRowId, builder: (column) => column);

  GeneratedColumn<String> get actorId =>
      $composableBuilder(column: $table.actorId, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);
}

class $$PendingSyncActionsTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $PendingSyncActionsTable,
    PendingSyncActionData,
    $$PendingSyncActionsTableFilterComposer,
    $$PendingSyncActionsTableOrderingComposer,
    $$PendingSyncActionsTableAnnotationComposer,
    $$PendingSyncActionsTableCreateCompanionBuilder,
    $$PendingSyncActionsTableUpdateCompanionBuilder,
    (
      PendingSyncActionData,
      BaseReferences<_$LocalDatabase, $PendingSyncActionsTable,
          PendingSyncActionData>
    ),
    PendingSyncActionData,
    PrefetchHooks Function()> {
  $$PendingSyncActionsTableTableManager(
      _$LocalDatabase db, $PendingSyncActionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncActionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncActionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncActionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> endpoint = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<String> entity = const Value.absent(),
            Value<String?> localRowId = const Value.absent(),
            Value<String?> actorId = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingSyncActionsCompanion(
            id: id,
            endpoint: endpoint,
            method: method,
            payload: payload,
            entity: entity,
            localRowId: localRowId,
            actorId: actorId,
            syncStatus: syncStatus,
            retryCount: retryCount,
            lastError: lastError,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String endpoint,
            required String method,
            required String payload,
            required String entity,
            Value<String?> localRowId = const Value.absent(),
            Value<String?> actorId = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingSyncActionsCompanion.insert(
            id: id,
            endpoint: endpoint,
            method: method,
            payload: payload,
            entity: entity,
            localRowId: localRowId,
            actorId: actorId,
            syncStatus: syncStatus,
            retryCount: retryCount,
            lastError: lastError,
            createdAt: createdAt,
            lastAttemptAt: lastAttemptAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingSyncActionsTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $PendingSyncActionsTable,
    PendingSyncActionData,
    $$PendingSyncActionsTableFilterComposer,
    $$PendingSyncActionsTableOrderingComposer,
    $$PendingSyncActionsTableAnnotationComposer,
    $$PendingSyncActionsTableCreateCompanionBuilder,
    $$PendingSyncActionsTableUpdateCompanionBuilder,
    (
      PendingSyncActionData,
      BaseReferences<_$LocalDatabase, $PendingSyncActionsTable,
          PendingSyncActionData>
    ),
    PendingSyncActionData,
    PrefetchHooks Function()>;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String entity,
  Value<DateTime?> lastSyncedAt,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> entity,
  Value<DateTime?> lastSyncedAt,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$LocalDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$LocalDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$LocalDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);
}

class $$SyncStatesTableTableManager extends RootTableManager<
    _$LocalDatabase,
    $SyncStatesTable,
    SyncStateData,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$LocalDatabase, $SyncStatesTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()> {
  $$SyncStatesTableTableManager(_$LocalDatabase db, $SyncStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entity = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion(
            entity: entity,
            lastSyncedAt: lastSyncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String entity,
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion.insert(
            entity: entity,
            lastSyncedAt: lastSyncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStatesTableProcessedTableManager = ProcessedTableManager<
    _$LocalDatabase,
    $SyncStatesTable,
    SyncStateData,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (
      SyncStateData,
      BaseReferences<_$LocalDatabase, $SyncStatesTable, SyncStateData>
    ),
    SyncStateData,
    PrefetchHooks Function()>;

class $LocalDatabaseManager {
  final _$LocalDatabase _db;
  $LocalDatabaseManager(this._db);
  $$LocalCowsTableTableManager get localCows =>
      $$LocalCowsTableTableManager(_db, _db.localCows);
  $$PendingSyncActionsTableTableManager get pendingSyncActions =>
      $$PendingSyncActionsTableTableManager(_db, _db.pendingSyncActions);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
}
