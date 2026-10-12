// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedDocumentsTable extends CachedDocuments
    with TableInfo<$CachedDocumentsTable, CachedDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocument(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedDocumentsTable createAlias(String alias) {
    return $CachedDocumentsTable(attachedDatabase, alias);
  }
}

class CachedDocument extends DataClass implements Insertable<CachedDocument> {
  final String key;
  final String payload;
  final DateTime updatedAt;
  const CachedDocument({
    required this.key,
    required this.payload,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedDocumentsCompanion toCompanion(bool nullToAbsent) {
    return CachedDocumentsCompanion(
      key: Value(key),
      payload: Value(payload),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocument(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedDocument copyWith({
    String? key,
    String? payload,
    DateTime? updatedAt,
  }) => CachedDocument(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedDocument copyWithCompanion(CachedDocumentsCompanion data) {
    return CachedDocument(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocument(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocument &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.updatedAt == this.updatedAt);
}

class CachedDocumentsCompanion extends UpdateCompanion<CachedDocument> {
  final Value<String> key;
  final Value<String> payload;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedDocumentsCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocumentsCompanion.insert({
    required String key,
    required String payload,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       updatedAt = Value(updatedAt);
  static Insertable<CachedDocument> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocumentsCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedDocumentsCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocumentsCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QueuedOperationsTable extends QueuedOperations
    with TableInfo<$QueuedOperationsTable, QueuedOperation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QueuedOperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationKeyMeta = const VerificationMeta(
    'operationKey',
  );
  @override
  late final GeneratedColumn<String> operationKey = GeneratedColumn<String>(
    'operation_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _conflictPayloadMeta = const VerificationMeta(
    'conflictPayload',
  );
  @override
  late final GeneratedColumn<String> conflictPayload = GeneratedColumn<String>(
    'conflict_payload',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    operationKey,
    payload,
    state,
    conflictPayload,
    attempts,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'queued_operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<QueuedOperation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('operation_key')) {
      context.handle(
        _operationKeyMeta,
        operationKey.isAcceptableOrUnknown(
          data['operation_key']!,
          _operationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('conflict_payload')) {
      context.handle(
        _conflictPayloadMeta,
        conflictPayload.isAcceptableOrUnknown(
          data['conflict_payload']!,
          _conflictPayloadMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  QueuedOperation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QueuedOperation(
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      operationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      conflictPayload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conflict_payload'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $QueuedOperationsTable createAlias(String alias) {
    return $QueuedOperationsTable(attachedDatabase, alias);
  }
}

class QueuedOperation extends DataClass implements Insertable<QueuedOperation> {
  final String requestId;
  final String operationKey;
  final String payload;
  final String state;
  final String? conflictPayload;
  final int attempts;
  final DateTime createdAt;
  const QueuedOperation({
    required this.requestId,
    required this.operationKey,
    required this.payload,
    required this.state,
    this.conflictPayload,
    required this.attempts,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['operation_key'] = Variable<String>(operationKey);
    map['payload'] = Variable<String>(payload);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || conflictPayload != null) {
      map['conflict_payload'] = Variable<String>(conflictPayload);
    }
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  QueuedOperationsCompanion toCompanion(bool nullToAbsent) {
    return QueuedOperationsCompanion(
      requestId: Value(requestId),
      operationKey: Value(operationKey),
      payload: Value(payload),
      state: Value(state),
      conflictPayload: conflictPayload == null && nullToAbsent
          ? const Value.absent()
          : Value(conflictPayload),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
    );
  }

  factory QueuedOperation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QueuedOperation(
      requestId: serializer.fromJson<String>(json['requestId']),
      operationKey: serializer.fromJson<String>(json['operationKey']),
      payload: serializer.fromJson<String>(json['payload']),
      state: serializer.fromJson<String>(json['state']),
      conflictPayload: serializer.fromJson<String?>(json['conflictPayload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'operationKey': serializer.toJson<String>(operationKey),
      'payload': serializer.toJson<String>(payload),
      'state': serializer.toJson<String>(state),
      'conflictPayload': serializer.toJson<String?>(conflictPayload),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  QueuedOperation copyWith({
    String? requestId,
    String? operationKey,
    String? payload,
    String? state,
    Value<String?> conflictPayload = const Value.absent(),
    int? attempts,
    DateTime? createdAt,
  }) => QueuedOperation(
    requestId: requestId ?? this.requestId,
    operationKey: operationKey ?? this.operationKey,
    payload: payload ?? this.payload,
    state: state ?? this.state,
    conflictPayload: conflictPayload.present
        ? conflictPayload.value
        : this.conflictPayload,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
  );
  QueuedOperation copyWithCompanion(QueuedOperationsCompanion data) {
    return QueuedOperation(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      operationKey: data.operationKey.present
          ? data.operationKey.value
          : this.operationKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      state: data.state.present ? data.state.value : this.state,
      conflictPayload: data.conflictPayload.present
          ? data.conflictPayload.value
          : this.conflictPayload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QueuedOperation(')
          ..write('requestId: $requestId, ')
          ..write('operationKey: $operationKey, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('conflictPayload: $conflictPayload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    operationKey,
    payload,
    state,
    conflictPayload,
    attempts,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueuedOperation &&
          other.requestId == this.requestId &&
          other.operationKey == this.operationKey &&
          other.payload == this.payload &&
          other.state == this.state &&
          other.conflictPayload == this.conflictPayload &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt);
}

class QueuedOperationsCompanion extends UpdateCompanion<QueuedOperation> {
  final Value<String> requestId;
  final Value<String> operationKey;
  final Value<String> payload;
  final Value<String> state;
  final Value<String?> conflictPayload;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const QueuedOperationsCompanion({
    this.requestId = const Value.absent(),
    this.operationKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.state = const Value.absent(),
    this.conflictPayload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QueuedOperationsCompanion.insert({
    required String requestId,
    required String operationKey,
    required String payload,
    this.state = const Value.absent(),
    this.conflictPayload = const Value.absent(),
    this.attempts = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       operationKey = Value(operationKey),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<QueuedOperation> custom({
    Expression<String>? requestId,
    Expression<String>? operationKey,
    Expression<String>? payload,
    Expression<String>? state,
    Expression<String>? conflictPayload,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (operationKey != null) 'operation_key': operationKey,
      if (payload != null) 'payload': payload,
      if (state != null) 'state': state,
      if (conflictPayload != null) 'conflict_payload': conflictPayload,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QueuedOperationsCompanion copyWith({
    Value<String>? requestId,
    Value<String>? operationKey,
    Value<String>? payload,
    Value<String>? state,
    Value<String?>? conflictPayload,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return QueuedOperationsCompanion(
      requestId: requestId ?? this.requestId,
      operationKey: operationKey ?? this.operationKey,
      payload: payload ?? this.payload,
      state: state ?? this.state,
      conflictPayload: conflictPayload ?? this.conflictPayload,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (operationKey.present) {
      map['operation_key'] = Variable<String>(operationKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (conflictPayload.present) {
      map['conflict_payload'] = Variable<String>(conflictPayload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QueuedOperationsCompanion(')
          ..write('requestId: $requestId, ')
          ..write('operationKey: $operationKey, ')
          ..write('payload: $payload, ')
          ..write('state: $state, ')
          ..write('conflictPayload: $conflictPayload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalEventsTable extends LocalEvents
    with TableInfo<$LocalEventsTable, LocalEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startsAtMeta = const VerificationMeta(
    'startsAt',
  );
  @override
  late final GeneratedColumn<DateTime> startsAt = GeneratedColumn<DateTime>(
    'starts_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsAtMeta = const VerificationMeta('endsAt');
  @override
  late final GeneratedColumn<DateTime> endsAt = GeneratedColumn<DateTime>(
    'ends_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _allDayMeta = const VerificationMeta('allDay');
  @override
  late final GeneratedColumn<bool> allDay = GeneratedColumn<bool>(
    'all_day',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("all_day" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importantMeta = const VerificationMeta(
    'important',
  );
  @override
  late final GeneratedColumn<bool> important = GeneratedColumn<bool>(
    'important',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("important" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recurrenceMeta = const VerificationMeta(
    'recurrence',
  );
  @override
  late final GeneratedColumn<String> recurrence = GeneratedColumn<String>(
    'recurrence',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remindersMeta = const VerificationMeta(
    'reminders',
  );
  @override
  late final GeneratedColumn<String> reminders = GeneratedColumn<String>(
    'reminders',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    title,
    notes,
    startsAt,
    endsAt,
    allDay,
    color,
    important,
    recurrence,
    reminders,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('starts_at')) {
      context.handle(
        _startsAtMeta,
        startsAt.isAcceptableOrUnknown(data['starts_at']!, _startsAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startsAtMeta);
    }
    if (data.containsKey('ends_at')) {
      context.handle(
        _endsAtMeta,
        endsAt.isAcceptableOrUnknown(data['ends_at']!, _endsAtMeta),
      );
    }
    if (data.containsKey('all_day')) {
      context.handle(
        _allDayMeta,
        allDay.isAcceptableOrUnknown(data['all_day']!, _allDayMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('important')) {
      context.handle(
        _importantMeta,
        important.isAcceptableOrUnknown(data['important']!, _importantMeta),
      );
    }
    if (data.containsKey('recurrence')) {
      context.handle(
        _recurrenceMeta,
        recurrence.isAcceptableOrUnknown(data['recurrence']!, _recurrenceMeta),
      );
    }
    if (data.containsKey('reminders')) {
      context.handle(
        _remindersMeta,
        reminders.isAcceptableOrUnknown(data['reminders']!, _remindersMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      startsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_at'],
      )!,
      endsAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_at'],
      ),
      allDay: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}all_day'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      important: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}important'],
      )!,
      recurrence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurrence'],
      ),
      reminders: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminders'],
      )!,
    );
  }

  @override
  $LocalEventsTable createAlias(String alias) {
    return $LocalEventsTable(attachedDatabase, alias);
  }
}

class LocalEvent extends DataClass implements Insertable<LocalEvent> {
  final String id;
  final int updatedAtMs;
  final int? deletedAtMs;
  final bool dirty;
  final String title;
  final String? notes;
  final DateTime startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final int? color;
  final bool important;

  /// `{"freq": "daily|weekly|monthly|everyNDays", "interval": 1, "weekdays": [1,3], "until": "..."}`
  final String? recurrence;

  /// `[{"offsetMinutes": 10, "priority": "normal"}, {"at": "2026-10-09T08:00:00Z"}]`
  final String reminders;
  const LocalEvent({
    required this.id,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.dirty,
    required this.title,
    this.notes,
    required this.startsAt,
    this.endsAt,
    required this.allDay,
    this.color,
    required this.important,
    this.recurrence,
    required this.reminders,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['starts_at'] = Variable<DateTime>(startsAt);
    if (!nullToAbsent || endsAt != null) {
      map['ends_at'] = Variable<DateTime>(endsAt);
    }
    map['all_day'] = Variable<bool>(allDay);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['important'] = Variable<bool>(important);
    if (!nullToAbsent || recurrence != null) {
      map['recurrence'] = Variable<String>(recurrence);
    }
    map['reminders'] = Variable<String>(reminders);
    return map;
  }

  LocalEventsCompanion toCompanion(bool nullToAbsent) {
    return LocalEventsCompanion(
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      dirty: Value(dirty),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      startsAt: Value(startsAt),
      endsAt: endsAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endsAt),
      allDay: Value(allDay),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      important: Value(important),
      recurrence: recurrence == null && nullToAbsent
          ? const Value.absent()
          : Value(recurrence),
      reminders: Value(reminders),
    );
  }

  factory LocalEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalEvent(
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      startsAt: serializer.fromJson<DateTime>(json['startsAt']),
      endsAt: serializer.fromJson<DateTime?>(json['endsAt']),
      allDay: serializer.fromJson<bool>(json['allDay']),
      color: serializer.fromJson<int?>(json['color']),
      important: serializer.fromJson<bool>(json['important']),
      recurrence: serializer.fromJson<String?>(json['recurrence']),
      reminders: serializer.fromJson<String>(json['reminders']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'dirty': serializer.toJson<bool>(dirty),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'startsAt': serializer.toJson<DateTime>(startsAt),
      'endsAt': serializer.toJson<DateTime?>(endsAt),
      'allDay': serializer.toJson<bool>(allDay),
      'color': serializer.toJson<int?>(color),
      'important': serializer.toJson<bool>(important),
      'recurrence': serializer.toJson<String?>(recurrence),
      'reminders': serializer.toJson<String>(reminders),
    };
  }

  LocalEvent copyWith({
    String? id,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    bool? dirty,
    String? title,
    Value<String?> notes = const Value.absent(),
    DateTime? startsAt,
    Value<DateTime?> endsAt = const Value.absent(),
    bool? allDay,
    Value<int?> color = const Value.absent(),
    bool? important,
    Value<String?> recurrence = const Value.absent(),
    String? reminders,
  }) => LocalEvent(
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    dirty: dirty ?? this.dirty,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    startsAt: startsAt ?? this.startsAt,
    endsAt: endsAt.present ? endsAt.value : this.endsAt,
    allDay: allDay ?? this.allDay,
    color: color.present ? color.value : this.color,
    important: important ?? this.important,
    recurrence: recurrence.present ? recurrence.value : this.recurrence,
    reminders: reminders ?? this.reminders,
  );
  LocalEvent copyWithCompanion(LocalEventsCompanion data) {
    return LocalEvent(
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      startsAt: data.startsAt.present ? data.startsAt.value : this.startsAt,
      endsAt: data.endsAt.present ? data.endsAt.value : this.endsAt,
      allDay: data.allDay.present ? data.allDay.value : this.allDay,
      color: data.color.present ? data.color.value : this.color,
      important: data.important.present ? data.important.value : this.important,
      recurrence: data.recurrence.present
          ? data.recurrence.value
          : this.recurrence,
      reminders: data.reminders.present ? data.reminders.value : this.reminders,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalEvent(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('color: $color, ')
          ..write('important: $important, ')
          ..write('recurrence: $recurrence, ')
          ..write('reminders: $reminders')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    title,
    notes,
    startsAt,
    endsAt,
    allDay,
    color,
    important,
    recurrence,
    reminders,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalEvent &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.dirty == this.dirty &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.startsAt == this.startsAt &&
          other.endsAt == this.endsAt &&
          other.allDay == this.allDay &&
          other.color == this.color &&
          other.important == this.important &&
          other.recurrence == this.recurrence &&
          other.reminders == this.reminders);
}

class LocalEventsCompanion extends UpdateCompanion<LocalEvent> {
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<bool> dirty;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime> startsAt;
  final Value<DateTime?> endsAt;
  final Value<bool> allDay;
  final Value<int?> color;
  final Value<bool> important;
  final Value<String?> recurrence;
  final Value<String> reminders;
  final Value<int> rowid;
  const LocalEventsCompanion({
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.startsAt = const Value.absent(),
    this.endsAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.color = const Value.absent(),
    this.important = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.reminders = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalEventsCompanion.insert({
    required String id,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    required DateTime startsAt,
    this.endsAt = const Value.absent(),
    this.allDay = const Value.absent(),
    this.color = const Value.absent(),
    this.important = const Value.absent(),
    this.recurrence = const Value.absent(),
    this.reminders = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAtMs = Value(updatedAtMs),
       title = Value(title),
       startsAt = Value(startsAt);
  static Insertable<LocalEvent> custom({
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<bool>? dirty,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? startsAt,
    Expression<DateTime>? endsAt,
    Expression<bool>? allDay,
    Expression<int>? color,
    Expression<bool>? important,
    Expression<String>? recurrence,
    Expression<String>? reminders,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (dirty != null) 'dirty': dirty,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (startsAt != null) 'starts_at': startsAt,
      if (endsAt != null) 'ends_at': endsAt,
      if (allDay != null) 'all_day': allDay,
      if (color != null) 'color': color,
      if (important != null) 'important': important,
      if (recurrence != null) 'recurrence': recurrence,
      if (reminders != null) 'reminders': reminders,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalEventsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<bool>? dirty,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime>? startsAt,
    Value<DateTime?>? endsAt,
    Value<bool>? allDay,
    Value<int?>? color,
    Value<bool>? important,
    Value<String?>? recurrence,
    Value<String>? reminders,
    Value<int>? rowid,
  }) {
    return LocalEventsCompanion(
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      dirty: dirty ?? this.dirty,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      allDay: allDay ?? this.allDay,
      color: color ?? this.color,
      important: important ?? this.important,
      recurrence: recurrence ?? this.recurrence,
      reminders: reminders ?? this.reminders,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (startsAt.present) {
      map['starts_at'] = Variable<DateTime>(startsAt.value);
    }
    if (endsAt.present) {
      map['ends_at'] = Variable<DateTime>(endsAt.value);
    }
    if (allDay.present) {
      map['all_day'] = Variable<bool>(allDay.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (important.present) {
      map['important'] = Variable<bool>(important.value);
    }
    if (recurrence.present) {
      map['recurrence'] = Variable<String>(recurrence.value);
    }
    if (reminders.present) {
      map['reminders'] = Variable<String>(reminders.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalEventsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('startsAt: $startsAt, ')
          ..write('endsAt: $endsAt, ')
          ..write('allDay: $allDay, ')
          ..write('color: $color, ')
          ..write('important: $important, ')
          ..write('recurrence: $recurrence, ')
          ..write('reminders: $reminders, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMedicationsTable extends LocalMedications
    with TableInfo<$LocalMedicationsTable, LocalMedication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMedicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
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
  static const VerificationMeta _formMeta = const VerificationMeta('form');
  @override
  late final GeneratedColumn<String> form = GeneratedColumn<String>(
    'form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tablet'),
  );
  static const VerificationMeta _doseAmountMeta = const VerificationMeta(
    'doseAmount',
  );
  @override
  late final GeneratedColumn<double> doseAmount = GeneratedColumn<double>(
    'dose_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _doseUnitMeta = const VerificationMeta(
    'doseUnit',
  );
  @override
  late final GeneratedColumn<String> doseUnit = GeneratedColumn<String>(
    'dose_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('tablet'),
  );
  static const VerificationMeta _mealRelationMeta = const VerificationMeta(
    'mealRelation',
  );
  @override
  late final GeneratedColumn<String> mealRelation = GeneratedColumn<String>(
    'meal_relation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scheduleMeta = const VerificationMeta(
    'schedule',
  );
  @override
  late final GeneratedColumn<String> schedule = GeneratedColumn<String>(
    'schedule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startsOnMeta = const VerificationMeta(
    'startsOn',
  );
  @override
  late final GeneratedColumn<DateTime> startsOn = GeneratedColumn<DateTime>(
    'starts_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsOnMeta = const VerificationMeta('endsOn');
  @override
  late final GeneratedColumn<DateTime> endsOn = GeneratedColumn<DateTime>(
    'ends_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<double> stock = GeneratedColumn<double>(
    'stock',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockAlertMeta = const VerificationMeta(
    'stockAlert',
  );
  @override
  late final GeneratedColumn<double> stockAlert = GeneratedColumn<double>(
    'stock_alert',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alarmMeta = const VerificationMeta('alarm');
  @override
  late final GeneratedColumn<String> alarm = GeneratedColumn<String>(
    'alarm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    name,
    form,
    doseAmount,
    doseUnit,
    mealRelation,
    notes,
    schedule,
    startsOn,
    endsOn,
    stock,
    stockAlert,
    alarm,
    active,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_medications';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMedication> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('form')) {
      context.handle(
        _formMeta,
        form.isAcceptableOrUnknown(data['form']!, _formMeta),
      );
    }
    if (data.containsKey('dose_amount')) {
      context.handle(
        _doseAmountMeta,
        doseAmount.isAcceptableOrUnknown(data['dose_amount']!, _doseAmountMeta),
      );
    }
    if (data.containsKey('dose_unit')) {
      context.handle(
        _doseUnitMeta,
        doseUnit.isAcceptableOrUnknown(data['dose_unit']!, _doseUnitMeta),
      );
    }
    if (data.containsKey('meal_relation')) {
      context.handle(
        _mealRelationMeta,
        mealRelation.isAcceptableOrUnknown(
          data['meal_relation']!,
          _mealRelationMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('schedule')) {
      context.handle(
        _scheduleMeta,
        schedule.isAcceptableOrUnknown(data['schedule']!, _scheduleMeta),
      );
    } else if (isInserting) {
      context.missing(_scheduleMeta);
    }
    if (data.containsKey('starts_on')) {
      context.handle(
        _startsOnMeta,
        startsOn.isAcceptableOrUnknown(data['starts_on']!, _startsOnMeta),
      );
    } else if (isInserting) {
      context.missing(_startsOnMeta);
    }
    if (data.containsKey('ends_on')) {
      context.handle(
        _endsOnMeta,
        endsOn.isAcceptableOrUnknown(data['ends_on']!, _endsOnMeta),
      );
    }
    if (data.containsKey('stock')) {
      context.handle(
        _stockMeta,
        stock.isAcceptableOrUnknown(data['stock']!, _stockMeta),
      );
    }
    if (data.containsKey('stock_alert')) {
      context.handle(
        _stockAlertMeta,
        stockAlert.isAcceptableOrUnknown(data['stock_alert']!, _stockAlertMeta),
      );
    }
    if (data.containsKey('alarm')) {
      context.handle(
        _alarmMeta,
        alarm.isAcceptableOrUnknown(data['alarm']!, _alarmMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMedication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMedication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      form: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form'],
      )!,
      doseAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dose_amount'],
      )!,
      doseUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dose_unit'],
      )!,
      mealRelation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_relation'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      schedule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schedule'],
      )!,
      startsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}starts_on'],
      )!,
      endsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_on'],
      ),
      stock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock'],
      ),
      stockAlert: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock_alert'],
      ),
      alarm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alarm'],
      )!,
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
    );
  }

  @override
  $LocalMedicationsTable createAlias(String alias) {
    return $LocalMedicationsTable(attachedDatabase, alias);
  }
}

class LocalMedication extends DataClass implements Insertable<LocalMedication> {
  final String id;
  final int updatedAtMs;
  final int? deletedAtMs;
  final bool dirty;
  final String name;

  /// tablet, capsule, syrup, drops, injection, other
  final String form;
  final double doseAmount;
  final String doseUnit;

  /// before_meal, after_meal, with_meal, empty_stomach, any
  final String? mealRelation;
  final String? notes;

  /// `{"mode": "times|weekdays|everyNDays|everyNHours|asNeeded", "times": ["09:00"], ...}`
  final String schedule;
  final DateTime startsOn;
  final DateTime? endsOn;
  final double? stock;
  final double? stockAlert;

  /// `{"fullScreen": true, "snoozeMinutes": 10, "repeatEveryMinutes": 5, "maxRepeats": 3}`
  final String alarm;
  final bool active;
  const LocalMedication({
    required this.id,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.dirty,
    required this.name,
    required this.form,
    required this.doseAmount,
    required this.doseUnit,
    this.mealRelation,
    this.notes,
    required this.schedule,
    required this.startsOn,
    this.endsOn,
    this.stock,
    this.stockAlert,
    required this.alarm,
    required this.active,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['name'] = Variable<String>(name);
    map['form'] = Variable<String>(form);
    map['dose_amount'] = Variable<double>(doseAmount);
    map['dose_unit'] = Variable<String>(doseUnit);
    if (!nullToAbsent || mealRelation != null) {
      map['meal_relation'] = Variable<String>(mealRelation);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['schedule'] = Variable<String>(schedule);
    map['starts_on'] = Variable<DateTime>(startsOn);
    if (!nullToAbsent || endsOn != null) {
      map['ends_on'] = Variable<DateTime>(endsOn);
    }
    if (!nullToAbsent || stock != null) {
      map['stock'] = Variable<double>(stock);
    }
    if (!nullToAbsent || stockAlert != null) {
      map['stock_alert'] = Variable<double>(stockAlert);
    }
    map['alarm'] = Variable<String>(alarm);
    map['active'] = Variable<bool>(active);
    return map;
  }

  LocalMedicationsCompanion toCompanion(bool nullToAbsent) {
    return LocalMedicationsCompanion(
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      dirty: Value(dirty),
      name: Value(name),
      form: Value(form),
      doseAmount: Value(doseAmount),
      doseUnit: Value(doseUnit),
      mealRelation: mealRelation == null && nullToAbsent
          ? const Value.absent()
          : Value(mealRelation),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      schedule: Value(schedule),
      startsOn: Value(startsOn),
      endsOn: endsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(endsOn),
      stock: stock == null && nullToAbsent
          ? const Value.absent()
          : Value(stock),
      stockAlert: stockAlert == null && nullToAbsent
          ? const Value.absent()
          : Value(stockAlert),
      alarm: Value(alarm),
      active: Value(active),
    );
  }

  factory LocalMedication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMedication(
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      name: serializer.fromJson<String>(json['name']),
      form: serializer.fromJson<String>(json['form']),
      doseAmount: serializer.fromJson<double>(json['doseAmount']),
      doseUnit: serializer.fromJson<String>(json['doseUnit']),
      mealRelation: serializer.fromJson<String?>(json['mealRelation']),
      notes: serializer.fromJson<String?>(json['notes']),
      schedule: serializer.fromJson<String>(json['schedule']),
      startsOn: serializer.fromJson<DateTime>(json['startsOn']),
      endsOn: serializer.fromJson<DateTime?>(json['endsOn']),
      stock: serializer.fromJson<double?>(json['stock']),
      stockAlert: serializer.fromJson<double?>(json['stockAlert']),
      alarm: serializer.fromJson<String>(json['alarm']),
      active: serializer.fromJson<bool>(json['active']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'dirty': serializer.toJson<bool>(dirty),
      'name': serializer.toJson<String>(name),
      'form': serializer.toJson<String>(form),
      'doseAmount': serializer.toJson<double>(doseAmount),
      'doseUnit': serializer.toJson<String>(doseUnit),
      'mealRelation': serializer.toJson<String?>(mealRelation),
      'notes': serializer.toJson<String?>(notes),
      'schedule': serializer.toJson<String>(schedule),
      'startsOn': serializer.toJson<DateTime>(startsOn),
      'endsOn': serializer.toJson<DateTime?>(endsOn),
      'stock': serializer.toJson<double?>(stock),
      'stockAlert': serializer.toJson<double?>(stockAlert),
      'alarm': serializer.toJson<String>(alarm),
      'active': serializer.toJson<bool>(active),
    };
  }

  LocalMedication copyWith({
    String? id,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    bool? dirty,
    String? name,
    String? form,
    double? doseAmount,
    String? doseUnit,
    Value<String?> mealRelation = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    String? schedule,
    DateTime? startsOn,
    Value<DateTime?> endsOn = const Value.absent(),
    Value<double?> stock = const Value.absent(),
    Value<double?> stockAlert = const Value.absent(),
    String? alarm,
    bool? active,
  }) => LocalMedication(
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    dirty: dirty ?? this.dirty,
    name: name ?? this.name,
    form: form ?? this.form,
    doseAmount: doseAmount ?? this.doseAmount,
    doseUnit: doseUnit ?? this.doseUnit,
    mealRelation: mealRelation.present ? mealRelation.value : this.mealRelation,
    notes: notes.present ? notes.value : this.notes,
    schedule: schedule ?? this.schedule,
    startsOn: startsOn ?? this.startsOn,
    endsOn: endsOn.present ? endsOn.value : this.endsOn,
    stock: stock.present ? stock.value : this.stock,
    stockAlert: stockAlert.present ? stockAlert.value : this.stockAlert,
    alarm: alarm ?? this.alarm,
    active: active ?? this.active,
  );
  LocalMedication copyWithCompanion(LocalMedicationsCompanion data) {
    return LocalMedication(
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      name: data.name.present ? data.name.value : this.name,
      form: data.form.present ? data.form.value : this.form,
      doseAmount: data.doseAmount.present
          ? data.doseAmount.value
          : this.doseAmount,
      doseUnit: data.doseUnit.present ? data.doseUnit.value : this.doseUnit,
      mealRelation: data.mealRelation.present
          ? data.mealRelation.value
          : this.mealRelation,
      notes: data.notes.present ? data.notes.value : this.notes,
      schedule: data.schedule.present ? data.schedule.value : this.schedule,
      startsOn: data.startsOn.present ? data.startsOn.value : this.startsOn,
      endsOn: data.endsOn.present ? data.endsOn.value : this.endsOn,
      stock: data.stock.present ? data.stock.value : this.stock,
      stockAlert: data.stockAlert.present
          ? data.stockAlert.value
          : this.stockAlert,
      alarm: data.alarm.present ? data.alarm.value : this.alarm,
      active: data.active.present ? data.active.value : this.active,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMedication(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('form: $form, ')
          ..write('doseAmount: $doseAmount, ')
          ..write('doseUnit: $doseUnit, ')
          ..write('mealRelation: $mealRelation, ')
          ..write('notes: $notes, ')
          ..write('schedule: $schedule, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('stock: $stock, ')
          ..write('stockAlert: $stockAlert, ')
          ..write('alarm: $alarm, ')
          ..write('active: $active')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    name,
    form,
    doseAmount,
    doseUnit,
    mealRelation,
    notes,
    schedule,
    startsOn,
    endsOn,
    stock,
    stockAlert,
    alarm,
    active,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMedication &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.dirty == this.dirty &&
          other.name == this.name &&
          other.form == this.form &&
          other.doseAmount == this.doseAmount &&
          other.doseUnit == this.doseUnit &&
          other.mealRelation == this.mealRelation &&
          other.notes == this.notes &&
          other.schedule == this.schedule &&
          other.startsOn == this.startsOn &&
          other.endsOn == this.endsOn &&
          other.stock == this.stock &&
          other.stockAlert == this.stockAlert &&
          other.alarm == this.alarm &&
          other.active == this.active);
}

class LocalMedicationsCompanion extends UpdateCompanion<LocalMedication> {
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<bool> dirty;
  final Value<String> name;
  final Value<String> form;
  final Value<double> doseAmount;
  final Value<String> doseUnit;
  final Value<String?> mealRelation;
  final Value<String?> notes;
  final Value<String> schedule;
  final Value<DateTime> startsOn;
  final Value<DateTime?> endsOn;
  final Value<double?> stock;
  final Value<double?> stockAlert;
  final Value<String> alarm;
  final Value<bool> active;
  final Value<int> rowid;
  const LocalMedicationsCompanion({
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.name = const Value.absent(),
    this.form = const Value.absent(),
    this.doseAmount = const Value.absent(),
    this.doseUnit = const Value.absent(),
    this.mealRelation = const Value.absent(),
    this.notes = const Value.absent(),
    this.schedule = const Value.absent(),
    this.startsOn = const Value.absent(),
    this.endsOn = const Value.absent(),
    this.stock = const Value.absent(),
    this.stockAlert = const Value.absent(),
    this.alarm = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMedicationsCompanion.insert({
    required String id,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    required String name,
    this.form = const Value.absent(),
    this.doseAmount = const Value.absent(),
    this.doseUnit = const Value.absent(),
    this.mealRelation = const Value.absent(),
    this.notes = const Value.absent(),
    required String schedule,
    required DateTime startsOn,
    this.endsOn = const Value.absent(),
    this.stock = const Value.absent(),
    this.stockAlert = const Value.absent(),
    this.alarm = const Value.absent(),
    this.active = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAtMs = Value(updatedAtMs),
       name = Value(name),
       schedule = Value(schedule),
       startsOn = Value(startsOn);
  static Insertable<LocalMedication> custom({
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<bool>? dirty,
    Expression<String>? name,
    Expression<String>? form,
    Expression<double>? doseAmount,
    Expression<String>? doseUnit,
    Expression<String>? mealRelation,
    Expression<String>? notes,
    Expression<String>? schedule,
    Expression<DateTime>? startsOn,
    Expression<DateTime>? endsOn,
    Expression<double>? stock,
    Expression<double>? stockAlert,
    Expression<String>? alarm,
    Expression<bool>? active,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (dirty != null) 'dirty': dirty,
      if (name != null) 'name': name,
      if (form != null) 'form': form,
      if (doseAmount != null) 'dose_amount': doseAmount,
      if (doseUnit != null) 'dose_unit': doseUnit,
      if (mealRelation != null) 'meal_relation': mealRelation,
      if (notes != null) 'notes': notes,
      if (schedule != null) 'schedule': schedule,
      if (startsOn != null) 'starts_on': startsOn,
      if (endsOn != null) 'ends_on': endsOn,
      if (stock != null) 'stock': stock,
      if (stockAlert != null) 'stock_alert': stockAlert,
      if (alarm != null) 'alarm': alarm,
      if (active != null) 'active': active,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMedicationsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<bool>? dirty,
    Value<String>? name,
    Value<String>? form,
    Value<double>? doseAmount,
    Value<String>? doseUnit,
    Value<String?>? mealRelation,
    Value<String?>? notes,
    Value<String>? schedule,
    Value<DateTime>? startsOn,
    Value<DateTime?>? endsOn,
    Value<double?>? stock,
    Value<double?>? stockAlert,
    Value<String>? alarm,
    Value<bool>? active,
    Value<int>? rowid,
  }) {
    return LocalMedicationsCompanion(
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      dirty: dirty ?? this.dirty,
      name: name ?? this.name,
      form: form ?? this.form,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      mealRelation: mealRelation ?? this.mealRelation,
      notes: notes ?? this.notes,
      schedule: schedule ?? this.schedule,
      startsOn: startsOn ?? this.startsOn,
      endsOn: endsOn ?? this.endsOn,
      stock: stock ?? this.stock,
      stockAlert: stockAlert ?? this.stockAlert,
      alarm: alarm ?? this.alarm,
      active: active ?? this.active,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (form.present) {
      map['form'] = Variable<String>(form.value);
    }
    if (doseAmount.present) {
      map['dose_amount'] = Variable<double>(doseAmount.value);
    }
    if (doseUnit.present) {
      map['dose_unit'] = Variable<String>(doseUnit.value);
    }
    if (mealRelation.present) {
      map['meal_relation'] = Variable<String>(mealRelation.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (schedule.present) {
      map['schedule'] = Variable<String>(schedule.value);
    }
    if (startsOn.present) {
      map['starts_on'] = Variable<DateTime>(startsOn.value);
    }
    if (endsOn.present) {
      map['ends_on'] = Variable<DateTime>(endsOn.value);
    }
    if (stock.present) {
      map['stock'] = Variable<double>(stock.value);
    }
    if (stockAlert.present) {
      map['stock_alert'] = Variable<double>(stockAlert.value);
    }
    if (alarm.present) {
      map['alarm'] = Variable<String>(alarm.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMedicationsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('form: $form, ')
          ..write('doseAmount: $doseAmount, ')
          ..write('doseUnit: $doseUnit, ')
          ..write('mealRelation: $mealRelation, ')
          ..write('notes: $notes, ')
          ..write('schedule: $schedule, ')
          ..write('startsOn: $startsOn, ')
          ..write('endsOn: $endsOn, ')
          ..write('stock: $stock, ')
          ..write('stockAlert: $stockAlert, ')
          ..write('alarm: $alarm, ')
          ..write('active: $active, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalDoseLogsTable extends LocalDoseLogs
    with TableInfo<$LocalDoseLogsTable, LocalDoseLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalDoseLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _medicationIdMeta = const VerificationMeta(
    'medicationId',
  );
  @override
  late final GeneratedColumn<String> medicationId = GeneratedColumn<String>(
    'medication_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledForMeta = const VerificationMeta(
    'scheduledFor',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledFor = GeneratedColumn<DateTime>(
    'scheduled_for',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actedAtMeta = const VerificationMeta(
    'actedAt',
  );
  @override
  late final GeneratedColumn<DateTime> actedAt = GeneratedColumn<DateTime>(
    'acted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    medicationId,
    scheduledFor,
    status,
    actedAt,
    snoozedUntil,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_dose_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalDoseLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('medication_id')) {
      context.handle(
        _medicationIdMeta,
        medicationId.isAcceptableOrUnknown(
          data['medication_id']!,
          _medicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_medicationIdMeta);
    }
    if (data.containsKey('scheduled_for')) {
      context.handle(
        _scheduledForMeta,
        scheduledFor.isAcceptableOrUnknown(
          data['scheduled_for']!,
          _scheduledForMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledForMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('acted_at')) {
      context.handle(
        _actedAtMeta,
        actedAt.isAcceptableOrUnknown(data['acted_at']!, _actedAtMeta),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalDoseLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalDoseLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      medicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medication_id'],
      )!,
      scheduledFor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_for'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      actedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acted_at'],
      ),
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
    );
  }

  @override
  $LocalDoseLogsTable createAlias(String alias) {
    return $LocalDoseLogsTable(attachedDatabase, alias);
  }
}

class LocalDoseLog extends DataClass implements Insertable<LocalDoseLog> {
  final String id;
  final int updatedAtMs;
  final int? deletedAtMs;
  final bool dirty;
  final String medicationId;
  final DateTime scheduledFor;

  /// taken, snoozed, skipped
  final String status;
  final DateTime? actedAt;
  final DateTime? snoozedUntil;
  const LocalDoseLog({
    required this.id,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.dirty,
    required this.medicationId,
    required this.scheduledFor,
    required this.status,
    this.actedAt,
    this.snoozedUntil,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['medication_id'] = Variable<String>(medicationId);
    map['scheduled_for'] = Variable<DateTime>(scheduledFor);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || actedAt != null) {
      map['acted_at'] = Variable<DateTime>(actedAt);
    }
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    return map;
  }

  LocalDoseLogsCompanion toCompanion(bool nullToAbsent) {
    return LocalDoseLogsCompanion(
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      dirty: Value(dirty),
      medicationId: Value(medicationId),
      scheduledFor: Value(scheduledFor),
      status: Value(status),
      actedAt: actedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(actedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
    );
  }

  factory LocalDoseLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalDoseLog(
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      medicationId: serializer.fromJson<String>(json['medicationId']),
      scheduledFor: serializer.fromJson<DateTime>(json['scheduledFor']),
      status: serializer.fromJson<String>(json['status']),
      actedAt: serializer.fromJson<DateTime?>(json['actedAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'dirty': serializer.toJson<bool>(dirty),
      'medicationId': serializer.toJson<String>(medicationId),
      'scheduledFor': serializer.toJson<DateTime>(scheduledFor),
      'status': serializer.toJson<String>(status),
      'actedAt': serializer.toJson<DateTime?>(actedAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
    };
  }

  LocalDoseLog copyWith({
    String? id,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    bool? dirty,
    String? medicationId,
    DateTime? scheduledFor,
    String? status,
    Value<DateTime?> actedAt = const Value.absent(),
    Value<DateTime?> snoozedUntil = const Value.absent(),
  }) => LocalDoseLog(
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    dirty: dirty ?? this.dirty,
    medicationId: medicationId ?? this.medicationId,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    status: status ?? this.status,
    actedAt: actedAt.present ? actedAt.value : this.actedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
  );
  LocalDoseLog copyWithCompanion(LocalDoseLogsCompanion data) {
    return LocalDoseLog(
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      medicationId: data.medicationId.present
          ? data.medicationId.value
          : this.medicationId,
      scheduledFor: data.scheduledFor.present
          ? data.scheduledFor.value
          : this.scheduledFor,
      status: data.status.present ? data.status.value : this.status,
      actedAt: data.actedAt.present ? data.actedAt.value : this.actedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalDoseLog(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('medicationId: $medicationId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('status: $status, ')
          ..write('actedAt: $actedAt, ')
          ..write('snoozedUntil: $snoozedUntil')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    medicationId,
    scheduledFor,
    status,
    actedAt,
    snoozedUntil,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalDoseLog &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.dirty == this.dirty &&
          other.medicationId == this.medicationId &&
          other.scheduledFor == this.scheduledFor &&
          other.status == this.status &&
          other.actedAt == this.actedAt &&
          other.snoozedUntil == this.snoozedUntil);
}

class LocalDoseLogsCompanion extends UpdateCompanion<LocalDoseLog> {
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<bool> dirty;
  final Value<String> medicationId;
  final Value<DateTime> scheduledFor;
  final Value<String> status;
  final Value<DateTime?> actedAt;
  final Value<DateTime?> snoozedUntil;
  final Value<int> rowid;
  const LocalDoseLogsCompanion({
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.medicationId = const Value.absent(),
    this.scheduledFor = const Value.absent(),
    this.status = const Value.absent(),
    this.actedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalDoseLogsCompanion.insert({
    required String id,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    required String medicationId,
    required DateTime scheduledFor,
    required String status,
    this.actedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAtMs = Value(updatedAtMs),
       medicationId = Value(medicationId),
       scheduledFor = Value(scheduledFor),
       status = Value(status);
  static Insertable<LocalDoseLog> custom({
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<bool>? dirty,
    Expression<String>? medicationId,
    Expression<DateTime>? scheduledFor,
    Expression<String>? status,
    Expression<DateTime>? actedAt,
    Expression<DateTime>? snoozedUntil,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (dirty != null) 'dirty': dirty,
      if (medicationId != null) 'medication_id': medicationId,
      if (scheduledFor != null) 'scheduled_for': scheduledFor,
      if (status != null) 'status': status,
      if (actedAt != null) 'acted_at': actedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalDoseLogsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<bool>? dirty,
    Value<String>? medicationId,
    Value<DateTime>? scheduledFor,
    Value<String>? status,
    Value<DateTime?>? actedAt,
    Value<DateTime?>? snoozedUntil,
    Value<int>? rowid,
  }) {
    return LocalDoseLogsCompanion(
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      dirty: dirty ?? this.dirty,
      medicationId: medicationId ?? this.medicationId,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      status: status ?? this.status,
      actedAt: actedAt ?? this.actedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (medicationId.present) {
      map['medication_id'] = Variable<String>(medicationId.value);
    }
    if (scheduledFor.present) {
      map['scheduled_for'] = Variable<DateTime>(scheduledFor.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (actedAt.present) {
      map['acted_at'] = Variable<DateTime>(actedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalDoseLogsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('medicationId: $medicationId, ')
          ..write('scheduledFor: $scheduledFor, ')
          ..write('status: $status, ')
          ..write('actedAt: $actedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String key;
  final String value;
  const SyncState({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(key: Value(key), value: Value(value));
  }

  factory SyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncState copyWith({String? key, String? value}) =>
      SyncState(key: key ?? this.key, value: value ?? this.value);
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncState> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletAccountsTable extends WalletAccounts
    with TableInfo<$WalletAccountsTable, WalletAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<int> ownerId = GeneratedColumn<int>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bankMeta = const VerificationMeta('bank');
  @override
  late final GeneratedColumn<String> bank = GeneratedColumn<String>(
    'bank',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TRY'),
  );
  static const VerificationMeta _balanceCentsMeta = const VerificationMeta(
    'balanceCents',
  );
  @override
  late final GeneratedColumn<int> balanceCents = GeneratedColumn<int>(
    'balance_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingCentsMeta = const VerificationMeta(
    'openingCents',
  );
  @override
  late final GeneratedColumn<int> openingCents = GeneratedColumn<int>(
    'opening_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _limitCentsMeta = const VerificationMeta(
    'limitCents',
  );
  @override
  late final GeneratedColumn<int> limitCents = GeneratedColumn<int>(
    'limit_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statementDayMeta = const VerificationMeta(
    'statementDay',
  );
  @override
  late final GeneratedColumn<int> statementDay = GeneratedColumn<int>(
    'statement_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
    'due_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('personal'),
  );
  static const VerificationMeta _last4Meta = const VerificationMeta('last4');
  @override
  late final GeneratedColumn<String> last4 = GeneratedColumn<String>(
    'last4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _networkMeta = const VerificationMeta(
    'network',
  );
  @override
  late final GeneratedColumn<String> network = GeneratedColumn<String>(
    'network',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ibanMeta = const VerificationMeta('iban');
  @override
  late final GeneratedColumn<String> iban = GeneratedColumn<String>(
    'iban',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    ownerId,
    name,
    type,
    bank,
    currency,
    balanceCents,
    openingCents,
    limitCents,
    statementDay,
    dueDay,
    visibility,
    last4,
    network,
    color,
    iban,
    active,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('bank')) {
      context.handle(
        _bankMeta,
        bank.isAcceptableOrUnknown(data['bank']!, _bankMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('balance_cents')) {
      context.handle(
        _balanceCentsMeta,
        balanceCents.isAcceptableOrUnknown(
          data['balance_cents']!,
          _balanceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceCentsMeta);
    }
    if (data.containsKey('opening_cents')) {
      context.handle(
        _openingCentsMeta,
        openingCents.isAcceptableOrUnknown(
          data['opening_cents']!,
          _openingCentsMeta,
        ),
      );
    }
    if (data.containsKey('limit_cents')) {
      context.handle(
        _limitCentsMeta,
        limitCents.isAcceptableOrUnknown(data['limit_cents']!, _limitCentsMeta),
      );
    }
    if (data.containsKey('statement_day')) {
      context.handle(
        _statementDayMeta,
        statementDay.isAcceptableOrUnknown(
          data['statement_day']!,
          _statementDayMeta,
        ),
      );
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('last4')) {
      context.handle(
        _last4Meta,
        last4.isAcceptableOrUnknown(data['last4']!, _last4Meta),
      );
    }
    if (data.containsKey('network')) {
      context.handle(
        _networkMeta,
        network.isAcceptableOrUnknown(data['network']!, _networkMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('iban')) {
      context.handle(
        _ibanMeta,
        iban.isAcceptableOrUnknown(data['iban']!, _ibanMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletAccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      bank: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bank'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      balanceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_cents'],
      )!,
      openingCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_cents'],
      )!,
      limitCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit_cents'],
      ),
      statementDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}statement_day'],
      ),
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_day'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      last4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last4'],
      ),
      network: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}network'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      iban: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}iban'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $WalletAccountsTable createAlias(String alias) {
    return $WalletAccountsTable(attachedDatabase, alias);
  }
}

class WalletAccountRow extends DataClass
    implements Insertable<WalletAccountRow> {
  final String id;
  final int? serverId;
  final int ownerId;
  final String name;

  /// cash, bank, credit_card
  final String type;
  final String? bank;
  final String currency;

  /// Cards: minus the debt (available = limit + balance).
  final int balanceCents;
  final int openingCents;
  final int? limitCents;
  final int? statementDay;
  final int? dueDay;

  /// personal, shared
  final String visibility;
  final String? last4;
  final String? network;
  final String? color;
  final String? iban;
  final bool active;
  final int version;
  const WalletAccountRow({
    required this.id,
    this.serverId,
    required this.ownerId,
    required this.name,
    required this.type,
    this.bank,
    required this.currency,
    required this.balanceCents,
    required this.openingCents,
    this.limitCents,
    this.statementDay,
    this.dueDay,
    required this.visibility,
    this.last4,
    this.network,
    this.color,
    this.iban,
    required this.active,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['owner_id'] = Variable<int>(ownerId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || bank != null) {
      map['bank'] = Variable<String>(bank);
    }
    map['currency'] = Variable<String>(currency);
    map['balance_cents'] = Variable<int>(balanceCents);
    map['opening_cents'] = Variable<int>(openingCents);
    if (!nullToAbsent || limitCents != null) {
      map['limit_cents'] = Variable<int>(limitCents);
    }
    if (!nullToAbsent || statementDay != null) {
      map['statement_day'] = Variable<int>(statementDay);
    }
    if (!nullToAbsent || dueDay != null) {
      map['due_day'] = Variable<int>(dueDay);
    }
    map['visibility'] = Variable<String>(visibility);
    if (!nullToAbsent || last4 != null) {
      map['last4'] = Variable<String>(last4);
    }
    if (!nullToAbsent || network != null) {
      map['network'] = Variable<String>(network);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    if (!nullToAbsent || iban != null) {
      map['iban'] = Variable<String>(iban);
    }
    map['active'] = Variable<bool>(active);
    map['version'] = Variable<int>(version);
    return map;
  }

  WalletAccountsCompanion toCompanion(bool nullToAbsent) {
    return WalletAccountsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      ownerId: Value(ownerId),
      name: Value(name),
      type: Value(type),
      bank: bank == null && nullToAbsent ? const Value.absent() : Value(bank),
      currency: Value(currency),
      balanceCents: Value(balanceCents),
      openingCents: Value(openingCents),
      limitCents: limitCents == null && nullToAbsent
          ? const Value.absent()
          : Value(limitCents),
      statementDay: statementDay == null && nullToAbsent
          ? const Value.absent()
          : Value(statementDay),
      dueDay: dueDay == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDay),
      visibility: Value(visibility),
      last4: last4 == null && nullToAbsent
          ? const Value.absent()
          : Value(last4),
      network: network == null && nullToAbsent
          ? const Value.absent()
          : Value(network),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      iban: iban == null && nullToAbsent ? const Value.absent() : Value(iban),
      active: Value(active),
      version: Value(version),
    );
  }

  factory WalletAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletAccountRow(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      ownerId: serializer.fromJson<int>(json['ownerId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      bank: serializer.fromJson<String?>(json['bank']),
      currency: serializer.fromJson<String>(json['currency']),
      balanceCents: serializer.fromJson<int>(json['balanceCents']),
      openingCents: serializer.fromJson<int>(json['openingCents']),
      limitCents: serializer.fromJson<int?>(json['limitCents']),
      statementDay: serializer.fromJson<int?>(json['statementDay']),
      dueDay: serializer.fromJson<int?>(json['dueDay']),
      visibility: serializer.fromJson<String>(json['visibility']),
      last4: serializer.fromJson<String?>(json['last4']),
      network: serializer.fromJson<String?>(json['network']),
      color: serializer.fromJson<String?>(json['color']),
      iban: serializer.fromJson<String?>(json['iban']),
      active: serializer.fromJson<bool>(json['active']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'ownerId': serializer.toJson<int>(ownerId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'bank': serializer.toJson<String?>(bank),
      'currency': serializer.toJson<String>(currency),
      'balanceCents': serializer.toJson<int>(balanceCents),
      'openingCents': serializer.toJson<int>(openingCents),
      'limitCents': serializer.toJson<int?>(limitCents),
      'statementDay': serializer.toJson<int?>(statementDay),
      'dueDay': serializer.toJson<int?>(dueDay),
      'visibility': serializer.toJson<String>(visibility),
      'last4': serializer.toJson<String?>(last4),
      'network': serializer.toJson<String?>(network),
      'color': serializer.toJson<String?>(color),
      'iban': serializer.toJson<String?>(iban),
      'active': serializer.toJson<bool>(active),
      'version': serializer.toJson<int>(version),
    };
  }

  WalletAccountRow copyWith({
    String? id,
    Value<int?> serverId = const Value.absent(),
    int? ownerId,
    String? name,
    String? type,
    Value<String?> bank = const Value.absent(),
    String? currency,
    int? balanceCents,
    int? openingCents,
    Value<int?> limitCents = const Value.absent(),
    Value<int?> statementDay = const Value.absent(),
    Value<int?> dueDay = const Value.absent(),
    String? visibility,
    Value<String?> last4 = const Value.absent(),
    Value<String?> network = const Value.absent(),
    Value<String?> color = const Value.absent(),
    Value<String?> iban = const Value.absent(),
    bool? active,
    int? version,
  }) => WalletAccountRow(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    type: type ?? this.type,
    bank: bank.present ? bank.value : this.bank,
    currency: currency ?? this.currency,
    balanceCents: balanceCents ?? this.balanceCents,
    openingCents: openingCents ?? this.openingCents,
    limitCents: limitCents.present ? limitCents.value : this.limitCents,
    statementDay: statementDay.present ? statementDay.value : this.statementDay,
    dueDay: dueDay.present ? dueDay.value : this.dueDay,
    visibility: visibility ?? this.visibility,
    last4: last4.present ? last4.value : this.last4,
    network: network.present ? network.value : this.network,
    color: color.present ? color.value : this.color,
    iban: iban.present ? iban.value : this.iban,
    active: active ?? this.active,
    version: version ?? this.version,
  );
  WalletAccountRow copyWithCompanion(WalletAccountsCompanion data) {
    return WalletAccountRow(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      bank: data.bank.present ? data.bank.value : this.bank,
      currency: data.currency.present ? data.currency.value : this.currency,
      balanceCents: data.balanceCents.present
          ? data.balanceCents.value
          : this.balanceCents,
      openingCents: data.openingCents.present
          ? data.openingCents.value
          : this.openingCents,
      limitCents: data.limitCents.present
          ? data.limitCents.value
          : this.limitCents,
      statementDay: data.statementDay.present
          ? data.statementDay.value
          : this.statementDay,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      last4: data.last4.present ? data.last4.value : this.last4,
      network: data.network.present ? data.network.value : this.network,
      color: data.color.present ? data.color.value : this.color,
      iban: data.iban.present ? data.iban.value : this.iban,
      active: data.active.present ? data.active.value : this.active,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletAccountRow(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bank: $bank, ')
          ..write('currency: $currency, ')
          ..write('balanceCents: $balanceCents, ')
          ..write('openingCents: $openingCents, ')
          ..write('limitCents: $limitCents, ')
          ..write('statementDay: $statementDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('visibility: $visibility, ')
          ..write('last4: $last4, ')
          ..write('network: $network, ')
          ..write('color: $color, ')
          ..write('iban: $iban, ')
          ..write('active: $active, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    ownerId,
    name,
    type,
    bank,
    currency,
    balanceCents,
    openingCents,
    limitCents,
    statementDay,
    dueDay,
    visibility,
    last4,
    network,
    color,
    iban,
    active,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletAccountRow &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.ownerId == this.ownerId &&
          other.name == this.name &&
          other.type == this.type &&
          other.bank == this.bank &&
          other.currency == this.currency &&
          other.balanceCents == this.balanceCents &&
          other.openingCents == this.openingCents &&
          other.limitCents == this.limitCents &&
          other.statementDay == this.statementDay &&
          other.dueDay == this.dueDay &&
          other.visibility == this.visibility &&
          other.last4 == this.last4 &&
          other.network == this.network &&
          other.color == this.color &&
          other.iban == this.iban &&
          other.active == this.active &&
          other.version == this.version);
}

class WalletAccountsCompanion extends UpdateCompanion<WalletAccountRow> {
  final Value<String> id;
  final Value<int?> serverId;
  final Value<int> ownerId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> bank;
  final Value<String> currency;
  final Value<int> balanceCents;
  final Value<int> openingCents;
  final Value<int?> limitCents;
  final Value<int?> statementDay;
  final Value<int?> dueDay;
  final Value<String> visibility;
  final Value<String?> last4;
  final Value<String?> network;
  final Value<String?> color;
  final Value<String?> iban;
  final Value<bool> active;
  final Value<int> version;
  final Value<int> rowid;
  const WalletAccountsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.bank = const Value.absent(),
    this.currency = const Value.absent(),
    this.balanceCents = const Value.absent(),
    this.openingCents = const Value.absent(),
    this.limitCents = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.visibility = const Value.absent(),
    this.last4 = const Value.absent(),
    this.network = const Value.absent(),
    this.color = const Value.absent(),
    this.iban = const Value.absent(),
    this.active = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletAccountsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required int ownerId,
    required String name,
    required String type,
    this.bank = const Value.absent(),
    this.currency = const Value.absent(),
    required int balanceCents,
    this.openingCents = const Value.absent(),
    this.limitCents = const Value.absent(),
    this.statementDay = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.visibility = const Value.absent(),
    this.last4 = const Value.absent(),
    this.network = const Value.absent(),
    this.color = const Value.absent(),
    this.iban = const Value.absent(),
    this.active = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ownerId = Value(ownerId),
       name = Value(name),
       type = Value(type),
       balanceCents = Value(balanceCents);
  static Insertable<WalletAccountRow> custom({
    Expression<String>? id,
    Expression<int>? serverId,
    Expression<int>? ownerId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? bank,
    Expression<String>? currency,
    Expression<int>? balanceCents,
    Expression<int>? openingCents,
    Expression<int>? limitCents,
    Expression<int>? statementDay,
    Expression<int>? dueDay,
    Expression<String>? visibility,
    Expression<String>? last4,
    Expression<String>? network,
    Expression<String>? color,
    Expression<String>? iban,
    Expression<bool>? active,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (ownerId != null) 'owner_id': ownerId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (bank != null) 'bank': bank,
      if (currency != null) 'currency': currency,
      if (balanceCents != null) 'balance_cents': balanceCents,
      if (openingCents != null) 'opening_cents': openingCents,
      if (limitCents != null) 'limit_cents': limitCents,
      if (statementDay != null) 'statement_day': statementDay,
      if (dueDay != null) 'due_day': dueDay,
      if (visibility != null) 'visibility': visibility,
      if (last4 != null) 'last4': last4,
      if (network != null) 'network': network,
      if (color != null) 'color': color,
      if (iban != null) 'iban': iban,
      if (active != null) 'active': active,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletAccountsCompanion copyWith({
    Value<String>? id,
    Value<int?>? serverId,
    Value<int>? ownerId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? bank,
    Value<String>? currency,
    Value<int>? balanceCents,
    Value<int>? openingCents,
    Value<int?>? limitCents,
    Value<int?>? statementDay,
    Value<int?>? dueDay,
    Value<String>? visibility,
    Value<String?>? last4,
    Value<String?>? network,
    Value<String?>? color,
    Value<String?>? iban,
    Value<bool>? active,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return WalletAccountsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      type: type ?? this.type,
      bank: bank ?? this.bank,
      currency: currency ?? this.currency,
      balanceCents: balanceCents ?? this.balanceCents,
      openingCents: openingCents ?? this.openingCents,
      limitCents: limitCents ?? this.limitCents,
      statementDay: statementDay ?? this.statementDay,
      dueDay: dueDay ?? this.dueDay,
      visibility: visibility ?? this.visibility,
      last4: last4 ?? this.last4,
      network: network ?? this.network,
      color: color ?? this.color,
      iban: iban ?? this.iban,
      active: active ?? this.active,
      version: version ?? this.version,
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
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<int>(ownerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (bank.present) {
      map['bank'] = Variable<String>(bank.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (balanceCents.present) {
      map['balance_cents'] = Variable<int>(balanceCents.value);
    }
    if (openingCents.present) {
      map['opening_cents'] = Variable<int>(openingCents.value);
    }
    if (limitCents.present) {
      map['limit_cents'] = Variable<int>(limitCents.value);
    }
    if (statementDay.present) {
      map['statement_day'] = Variable<int>(statementDay.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (last4.present) {
      map['last4'] = Variable<String>(last4.value);
    }
    if (network.present) {
      map['network'] = Variable<String>(network.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (iban.present) {
      map['iban'] = Variable<String>(iban.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletAccountsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('ownerId: $ownerId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('bank: $bank, ')
          ..write('currency: $currency, ')
          ..write('balanceCents: $balanceCents, ')
          ..write('openingCents: $openingCents, ')
          ..write('limitCents: $limitCents, ')
          ..write('statementDay: $statementDay, ')
          ..write('dueDay: $dueDay, ')
          ..write('visibility: $visibility, ')
          ..write('last4: $last4, ')
          ..write('network: $network, ')
          ..write('color: $color, ')
          ..write('iban: $iban, ')
          ..write('active: $active, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletTransactionsTable extends WalletTransactions
    with TableInfo<$WalletTransactionsTable, WalletTransactionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statementMonthMeta = const VerificationMeta(
    'statementMonth',
  );
  @override
  late final GeneratedColumn<DateTime> statementMonth =
      GeneratedColumn<DateTime>(
        'statement_month',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _installmentGroupMeta = const VerificationMeta(
    'installmentGroup',
  );
  @override
  late final GeneratedColumn<String> installmentGroup = GeneratedColumn<String>(
    'installment_group',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installmentIndexMeta = const VerificationMeta(
    'installmentIndex',
  );
  @override
  late final GeneratedColumn<int> installmentIndex = GeneratedColumn<int>(
    'installment_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _installmentCountMeta = const VerificationMeta(
    'installmentCount',
  );
  @override
  late final GeneratedColumn<int> installmentCount = GeneratedColumn<int>(
    'installment_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    kind,
    categoryId,
    category,
    amountCents,
    occurredAt,
    statementMonth,
    note,
    createdBy,
    installmentGroup,
    installmentIndex,
    installmentCount,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletTransactionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('statement_month')) {
      context.handle(
        _statementMonthMeta,
        statementMonth.isAcceptableOrUnknown(
          data['statement_month']!,
          _statementMonthMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('installment_group')) {
      context.handle(
        _installmentGroupMeta,
        installmentGroup.isAcceptableOrUnknown(
          data['installment_group']!,
          _installmentGroupMeta,
        ),
      );
    }
    if (data.containsKey('installment_index')) {
      context.handle(
        _installmentIndexMeta,
        installmentIndex.isAcceptableOrUnknown(
          data['installment_index']!,
          _installmentIndexMeta,
        ),
      );
    }
    if (data.containsKey('installment_count')) {
      context.handle(
        _installmentCountMeta,
        installmentCount.isAcceptableOrUnknown(
          data['installment_count']!,
          _installmentCountMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletTransactionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletTransactionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      statementMonth: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}statement_month'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      installmentGroup: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}installment_group'],
      ),
      installmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installment_index'],
      ),
      installmentCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installment_count'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $WalletTransactionsTable createAlias(String alias) {
    return $WalletTransactionsTable(attachedDatabase, alias);
  }
}

class WalletTransactionRow extends DataClass
    implements Insertable<WalletTransactionRow> {
  final String id;
  final String accountId;

  /// expense, income, payment
  final String kind;
  final int? categoryId;
  final String? category;
  final int amountCents;
  final DateTime occurredAt;
  final DateTime? statementMonth;
  final String? note;
  final int createdBy;
  final String? installmentGroup;
  final int? installmentIndex;
  final int? installmentCount;
  final int version;
  const WalletTransactionRow({
    required this.id,
    required this.accountId,
    required this.kind,
    this.categoryId,
    this.category,
    required this.amountCents,
    required this.occurredAt,
    this.statementMonth,
    this.note,
    required this.createdBy,
    this.installmentGroup,
    this.installmentIndex,
    this.installmentCount,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['amount_cents'] = Variable<int>(amountCents);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || statementMonth != null) {
      map['statement_month'] = Variable<DateTime>(statementMonth);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_by'] = Variable<int>(createdBy);
    if (!nullToAbsent || installmentGroup != null) {
      map['installment_group'] = Variable<String>(installmentGroup);
    }
    if (!nullToAbsent || installmentIndex != null) {
      map['installment_index'] = Variable<int>(installmentIndex);
    }
    if (!nullToAbsent || installmentCount != null) {
      map['installment_count'] = Variable<int>(installmentCount);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  WalletTransactionsCompanion toCompanion(bool nullToAbsent) {
    return WalletTransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      kind: Value(kind),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      amountCents: Value(amountCents),
      occurredAt: Value(occurredAt),
      statementMonth: statementMonth == null && nullToAbsent
          ? const Value.absent()
          : Value(statementMonth),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdBy: Value(createdBy),
      installmentGroup: installmentGroup == null && nullToAbsent
          ? const Value.absent()
          : Value(installmentGroup),
      installmentIndex: installmentIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(installmentIndex),
      installmentCount: installmentCount == null && nullToAbsent
          ? const Value.absent()
          : Value(installmentCount),
      version: Value(version),
    );
  }

  factory WalletTransactionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletTransactionRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      kind: serializer.fromJson<String>(json['kind']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      category: serializer.fromJson<String?>(json['category']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      statementMonth: serializer.fromJson<DateTime?>(json['statementMonth']),
      note: serializer.fromJson<String?>(json['note']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      installmentGroup: serializer.fromJson<String?>(json['installmentGroup']),
      installmentIndex: serializer.fromJson<int?>(json['installmentIndex']),
      installmentCount: serializer.fromJson<int?>(json['installmentCount']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'kind': serializer.toJson<String>(kind),
      'categoryId': serializer.toJson<int?>(categoryId),
      'category': serializer.toJson<String?>(category),
      'amountCents': serializer.toJson<int>(amountCents),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'statementMonth': serializer.toJson<DateTime?>(statementMonth),
      'note': serializer.toJson<String?>(note),
      'createdBy': serializer.toJson<int>(createdBy),
      'installmentGroup': serializer.toJson<String?>(installmentGroup),
      'installmentIndex': serializer.toJson<int?>(installmentIndex),
      'installmentCount': serializer.toJson<int?>(installmentCount),
      'version': serializer.toJson<int>(version),
    };
  }

  WalletTransactionRow copyWith({
    String? id,
    String? accountId,
    String? kind,
    Value<int?> categoryId = const Value.absent(),
    Value<String?> category = const Value.absent(),
    int? amountCents,
    DateTime? occurredAt,
    Value<DateTime?> statementMonth = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdBy,
    Value<String?> installmentGroup = const Value.absent(),
    Value<int?> installmentIndex = const Value.absent(),
    Value<int?> installmentCount = const Value.absent(),
    int? version,
  }) => WalletTransactionRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    kind: kind ?? this.kind,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    category: category.present ? category.value : this.category,
    amountCents: amountCents ?? this.amountCents,
    occurredAt: occurredAt ?? this.occurredAt,
    statementMonth: statementMonth.present
        ? statementMonth.value
        : this.statementMonth,
    note: note.present ? note.value : this.note,
    createdBy: createdBy ?? this.createdBy,
    installmentGroup: installmentGroup.present
        ? installmentGroup.value
        : this.installmentGroup,
    installmentIndex: installmentIndex.present
        ? installmentIndex.value
        : this.installmentIndex,
    installmentCount: installmentCount.present
        ? installmentCount.value
        : this.installmentCount,
    version: version ?? this.version,
  );
  WalletTransactionRow copyWithCompanion(WalletTransactionsCompanion data) {
    return WalletTransactionRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      kind: data.kind.present ? data.kind.value : this.kind,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      category: data.category.present ? data.category.value : this.category,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      statementMonth: data.statementMonth.present
          ? data.statementMonth.value
          : this.statementMonth,
      note: data.note.present ? data.note.value : this.note,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      installmentGroup: data.installmentGroup.present
          ? data.installmentGroup.value
          : this.installmentGroup,
      installmentIndex: data.installmentIndex.present
          ? data.installmentIndex.value
          : this.installmentIndex,
      installmentCount: data.installmentCount.present
          ? data.installmentCount.value
          : this.installmentCount,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransactionRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('category: $category, ')
          ..write('amountCents: $amountCents, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('statementMonth: $statementMonth, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('installmentGroup: $installmentGroup, ')
          ..write('installmentIndex: $installmentIndex, ')
          ..write('installmentCount: $installmentCount, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    kind,
    categoryId,
    category,
    amountCents,
    occurredAt,
    statementMonth,
    note,
    createdBy,
    installmentGroup,
    installmentIndex,
    installmentCount,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletTransactionRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.kind == this.kind &&
          other.categoryId == this.categoryId &&
          other.category == this.category &&
          other.amountCents == this.amountCents &&
          other.occurredAt == this.occurredAt &&
          other.statementMonth == this.statementMonth &&
          other.note == this.note &&
          other.createdBy == this.createdBy &&
          other.installmentGroup == this.installmentGroup &&
          other.installmentIndex == this.installmentIndex &&
          other.installmentCount == this.installmentCount &&
          other.version == this.version);
}

class WalletTransactionsCompanion
    extends UpdateCompanion<WalletTransactionRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> kind;
  final Value<int?> categoryId;
  final Value<String?> category;
  final Value<int> amountCents;
  final Value<DateTime> occurredAt;
  final Value<DateTime?> statementMonth;
  final Value<String?> note;
  final Value<int> createdBy;
  final Value<String?> installmentGroup;
  final Value<int?> installmentIndex;
  final Value<int?> installmentCount;
  final Value<int> version;
  final Value<int> rowid;
  const WalletTransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.kind = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.category = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.statementMonth = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.installmentGroup = const Value.absent(),
    this.installmentIndex = const Value.absent(),
    this.installmentCount = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletTransactionsCompanion.insert({
    required String id,
    required String accountId,
    required String kind,
    this.categoryId = const Value.absent(),
    this.category = const Value.absent(),
    required int amountCents,
    required DateTime occurredAt,
    this.statementMonth = const Value.absent(),
    this.note = const Value.absent(),
    required int createdBy,
    this.installmentGroup = const Value.absent(),
    this.installmentIndex = const Value.absent(),
    this.installmentCount = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       kind = Value(kind),
       amountCents = Value(amountCents),
       occurredAt = Value(occurredAt),
       createdBy = Value(createdBy);
  static Insertable<WalletTransactionRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? kind,
    Expression<int>? categoryId,
    Expression<String>? category,
    Expression<int>? amountCents,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? statementMonth,
    Expression<String>? note,
    Expression<int>? createdBy,
    Expression<String>? installmentGroup,
    Expression<int>? installmentIndex,
    Expression<int>? installmentCount,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (kind != null) 'kind': kind,
      if (categoryId != null) 'category_id': categoryId,
      if (category != null) 'category': category,
      if (amountCents != null) 'amount_cents': amountCents,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (statementMonth != null) 'statement_month': statementMonth,
      if (note != null) 'note': note,
      if (createdBy != null) 'created_by': createdBy,
      if (installmentGroup != null) 'installment_group': installmentGroup,
      if (installmentIndex != null) 'installment_index': installmentIndex,
      if (installmentCount != null) 'installment_count': installmentCount,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? kind,
    Value<int?>? categoryId,
    Value<String?>? category,
    Value<int>? amountCents,
    Value<DateTime>? occurredAt,
    Value<DateTime?>? statementMonth,
    Value<String?>? note,
    Value<int>? createdBy,
    Value<String?>? installmentGroup,
    Value<int?>? installmentIndex,
    Value<int?>? installmentCount,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return WalletTransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      kind: kind ?? this.kind,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      amountCents: amountCents ?? this.amountCents,
      occurredAt: occurredAt ?? this.occurredAt,
      statementMonth: statementMonth ?? this.statementMonth,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      installmentGroup: installmentGroup ?? this.installmentGroup,
      installmentIndex: installmentIndex ?? this.installmentIndex,
      installmentCount: installmentCount ?? this.installmentCount,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (statementMonth.present) {
      map['statement_month'] = Variable<DateTime>(statementMonth.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (installmentGroup.present) {
      map['installment_group'] = Variable<String>(installmentGroup.value);
    }
    if (installmentIndex.present) {
      map['installment_index'] = Variable<int>(installmentIndex.value);
    }
    if (installmentCount.present) {
      map['installment_count'] = Variable<int>(installmentCount.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('kind: $kind, ')
          ..write('categoryId: $categoryId, ')
          ..write('category: $category, ')
          ..write('amountCents: $amountCents, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('statementMonth: $statementMonth, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('installmentGroup: $installmentGroup, ')
          ..write('installmentIndex: $installmentIndex, ')
          ..write('installmentCount: $installmentCount, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletTransfersTable extends WalletTransfers
    with TableInfo<$WalletTransfersTable, WalletTransferRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletTransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromAccountIdMeta = const VerificationMeta(
    'fromAccountId',
  );
  @override
  late final GeneratedColumn<String> fromAccountId = GeneratedColumn<String>(
    'from_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fromAccountId,
    toAccountId,
    amountCents,
    occurredAt,
    note,
    createdBy,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletTransferRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('from_account_id')) {
      context.handle(
        _fromAccountIdMeta,
        fromAccountId.isAcceptableOrUnknown(
          data['from_account_id']!,
          _fromAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromAccountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_toAccountIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletTransferRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletTransferRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fromAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $WalletTransfersTable createAlias(String alias) {
    return $WalletTransfersTable(attachedDatabase, alias);
  }
}

class WalletTransferRow extends DataClass
    implements Insertable<WalletTransferRow> {
  final String id;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final DateTime occurredAt;
  final String? note;
  final int createdBy;
  final int version;
  const WalletTransferRow({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.occurredAt,
    this.note,
    required this.createdBy,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['from_account_id'] = Variable<String>(fromAccountId);
    map['to_account_id'] = Variable<String>(toAccountId);
    map['amount_cents'] = Variable<int>(amountCents);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_by'] = Variable<int>(createdBy);
    map['version'] = Variable<int>(version);
    return map;
  }

  WalletTransfersCompanion toCompanion(bool nullToAbsent) {
    return WalletTransfersCompanion(
      id: Value(id),
      fromAccountId: Value(fromAccountId),
      toAccountId: Value(toAccountId),
      amountCents: Value(amountCents),
      occurredAt: Value(occurredAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdBy: Value(createdBy),
      version: Value(version),
    );
  }

  factory WalletTransferRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletTransferRow(
      id: serializer.fromJson<String>(json['id']),
      fromAccountId: serializer.fromJson<String>(json['fromAccountId']),
      toAccountId: serializer.fromJson<String>(json['toAccountId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      note: serializer.fromJson<String?>(json['note']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fromAccountId': serializer.toJson<String>(fromAccountId),
      'toAccountId': serializer.toJson<String>(toAccountId),
      'amountCents': serializer.toJson<int>(amountCents),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'note': serializer.toJson<String?>(note),
      'createdBy': serializer.toJson<int>(createdBy),
      'version': serializer.toJson<int>(version),
    };
  }

  WalletTransferRow copyWith({
    String? id,
    String? fromAccountId,
    String? toAccountId,
    int? amountCents,
    DateTime? occurredAt,
    Value<String?> note = const Value.absent(),
    int? createdBy,
    int? version,
  }) => WalletTransferRow(
    id: id ?? this.id,
    fromAccountId: fromAccountId ?? this.fromAccountId,
    toAccountId: toAccountId ?? this.toAccountId,
    amountCents: amountCents ?? this.amountCents,
    occurredAt: occurredAt ?? this.occurredAt,
    note: note.present ? note.value : this.note,
    createdBy: createdBy ?? this.createdBy,
    version: version ?? this.version,
  );
  WalletTransferRow copyWithCompanion(WalletTransfersCompanion data) {
    return WalletTransferRow(
      id: data.id.present ? data.id.value : this.id,
      fromAccountId: data.fromAccountId.present
          ? data.fromAccountId.value
          : this.fromAccountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      note: data.note.present ? data.note.value : this.note,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransferRow(')
          ..write('id: $id, ')
          ..write('fromAccountId: $fromAccountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('amountCents: $amountCents, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fromAccountId,
    toAccountId,
    amountCents,
    occurredAt,
    note,
    createdBy,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletTransferRow &&
          other.id == this.id &&
          other.fromAccountId == this.fromAccountId &&
          other.toAccountId == this.toAccountId &&
          other.amountCents == this.amountCents &&
          other.occurredAt == this.occurredAt &&
          other.note == this.note &&
          other.createdBy == this.createdBy &&
          other.version == this.version);
}

class WalletTransfersCompanion extends UpdateCompanion<WalletTransferRow> {
  final Value<String> id;
  final Value<String> fromAccountId;
  final Value<String> toAccountId;
  final Value<int> amountCents;
  final Value<DateTime> occurredAt;
  final Value<String?> note;
  final Value<int> createdBy;
  final Value<int> version;
  final Value<int> rowid;
  const WalletTransfersCompanion({
    this.id = const Value.absent(),
    this.fromAccountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.note = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletTransfersCompanion.insert({
    required String id,
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    required DateTime occurredAt,
    this.note = const Value.absent(),
    required int createdBy,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fromAccountId = Value(fromAccountId),
       toAccountId = Value(toAccountId),
       amountCents = Value(amountCents),
       occurredAt = Value(occurredAt),
       createdBy = Value(createdBy);
  static Insertable<WalletTransferRow> custom({
    Expression<String>? id,
    Expression<String>? fromAccountId,
    Expression<String>? toAccountId,
    Expression<int>? amountCents,
    Expression<DateTime>? occurredAt,
    Expression<String>? note,
    Expression<int>? createdBy,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fromAccountId != null) 'from_account_id': fromAccountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (note != null) 'note': note,
      if (createdBy != null) 'created_by': createdBy,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletTransfersCompanion copyWith({
    Value<String>? id,
    Value<String>? fromAccountId,
    Value<String>? toAccountId,
    Value<int>? amountCents,
    Value<DateTime>? occurredAt,
    Value<String?>? note,
    Value<int>? createdBy,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return WalletTransfersCompanion(
      id: id ?? this.id,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      amountCents: amountCents ?? this.amountCents,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fromAccountId.present) {
      map['from_account_id'] = Variable<String>(fromAccountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletTransfersCompanion(')
          ..write('id: $id, ')
          ..write('fromAccountId: $fromAccountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('amountCents: $amountCents, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('note: $note, ')
          ..write('createdBy: $createdBy, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletStatementMarksTable extends WalletStatementMarks
    with TableInfo<$WalletStatementMarksTable, WalletMarkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletStatementMarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<DateTime> month = GeneratedColumn<DateTime>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<bool> paid = GeneratedColumn<bool>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paid" IN (0, 1))',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [id, accountId, month, paid, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_statement_marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletMarkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    } else if (isInserting) {
      context.missing(_paidMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletMarkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletMarkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}month'],
      )!,
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paid'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $WalletStatementMarksTable createAlias(String alias) {
    return $WalletStatementMarksTable(attachedDatabase, alias);
  }
}

class WalletMarkRow extends DataClass implements Insertable<WalletMarkRow> {
  final String id;
  final String accountId;
  final DateTime month;
  final bool paid;
  final int version;
  const WalletMarkRow({
    required this.id,
    required this.accountId,
    required this.month,
    required this.paid,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['month'] = Variable<DateTime>(month);
    map['paid'] = Variable<bool>(paid);
    map['version'] = Variable<int>(version);
    return map;
  }

  WalletStatementMarksCompanion toCompanion(bool nullToAbsent) {
    return WalletStatementMarksCompanion(
      id: Value(id),
      accountId: Value(accountId),
      month: Value(month),
      paid: Value(paid),
      version: Value(version),
    );
  }

  factory WalletMarkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletMarkRow(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      month: serializer.fromJson<DateTime>(json['month']),
      paid: serializer.fromJson<bool>(json['paid']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'month': serializer.toJson<DateTime>(month),
      'paid': serializer.toJson<bool>(paid),
      'version': serializer.toJson<int>(version),
    };
  }

  WalletMarkRow copyWith({
    String? id,
    String? accountId,
    DateTime? month,
    bool? paid,
    int? version,
  }) => WalletMarkRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    month: month ?? this.month,
    paid: paid ?? this.paid,
    version: version ?? this.version,
  );
  WalletMarkRow copyWithCompanion(WalletStatementMarksCompanion data) {
    return WalletMarkRow(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      month: data.month.present ? data.month.value : this.month,
      paid: data.paid.present ? data.paid.value : this.paid,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletMarkRow(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('month: $month, ')
          ..write('paid: $paid, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, month, paid, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletMarkRow &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.month == this.month &&
          other.paid == this.paid &&
          other.version == this.version);
}

class WalletStatementMarksCompanion extends UpdateCompanion<WalletMarkRow> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<DateTime> month;
  final Value<bool> paid;
  final Value<int> version;
  final Value<int> rowid;
  const WalletStatementMarksCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.month = const Value.absent(),
    this.paid = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletStatementMarksCompanion.insert({
    required String id,
    required String accountId,
    required DateTime month,
    required bool paid,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       month = Value(month),
       paid = Value(paid);
  static Insertable<WalletMarkRow> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<DateTime>? month,
    Expression<bool>? paid,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (month != null) 'month': month,
      if (paid != null) 'paid': paid,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletStatementMarksCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<DateTime>? month,
    Value<bool>? paid,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return WalletStatementMarksCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      month: month ?? this.month,
      paid: paid ?? this.paid,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (month.present) {
      map['month'] = Variable<DateTime>(month.value);
    }
    if (paid.present) {
      map['paid'] = Variable<bool>(paid.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletStatementMarksCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('month: $month, ')
          ..write('paid: $paid, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletScheduledPaymentsTable extends WalletScheduledPayments
    with TableInfo<$WalletScheduledPaymentsTable, WalletPaymentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletScheduledPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toAccountIdMeta = const VerificationMeta(
    'toAccountId',
  );
  @override
  late final GeneratedColumn<String> toAccountId = GeneratedColumn<String>(
    'to_account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueAtMeta = const VerificationMeta('dueAt');
  @override
  late final GeneratedColumn<DateTime> dueAt = GeneratedColumn<DateTime>(
    'due_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatMonthlyMeta = const VerificationMeta(
    'repeatMonthly',
  );
  @override
  late final GeneratedColumn<bool> repeatMonthly = GeneratedColumn<bool>(
    'repeat_monthly',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("repeat_monthly" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastPaidAtMeta = const VerificationMeta(
    'lastPaidAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPaidAt = GeneratedColumn<DateTime>(
    'last_paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<int> createdBy = GeneratedColumn<int>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    kind,
    accountId,
    toAccountId,
    categoryId,
    amountCents,
    dueAt,
    repeatMonthly,
    completed,
    lastPaidAt,
    createdBy,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_scheduled_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletPaymentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('to_account_id')) {
      context.handle(
        _toAccountIdMeta,
        toAccountId.isAcceptableOrUnknown(
          data['to_account_id']!,
          _toAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('due_at')) {
      context.handle(
        _dueAtMeta,
        dueAt.isAcceptableOrUnknown(data['due_at']!, _dueAtMeta),
      );
    } else if (isInserting) {
      context.missing(_dueAtMeta);
    }
    if (data.containsKey('repeat_monthly')) {
      context.handle(
        _repeatMonthlyMeta,
        repeatMonthly.isAcceptableOrUnknown(
          data['repeat_monthly']!,
          _repeatMonthlyMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('last_paid_at')) {
      context.handle(
        _lastPaidAtMeta,
        lastPaidAt.isAcceptableOrUnknown(
          data['last_paid_at']!,
          _lastPaidAtMeta,
        ),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WalletPaymentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletPaymentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      toAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      dueAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_at'],
      )!,
      repeatMonthly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}repeat_monthly'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      lastPaidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_paid_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_by'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $WalletScheduledPaymentsTable createAlias(String alias) {
    return $WalletScheduledPaymentsTable(attachedDatabase, alias);
  }
}

class WalletPaymentRow extends DataClass
    implements Insertable<WalletPaymentRow> {
  final String id;
  final String title;

  /// expense, transfer
  final String kind;
  final String accountId;
  final String? toAccountId;
  final int? categoryId;
  final int amountCents;
  final DateTime dueAt;
  final bool repeatMonthly;
  final bool completed;
  final DateTime? lastPaidAt;
  final int createdBy;
  final int version;
  const WalletPaymentRow({
    required this.id,
    required this.title,
    required this.kind,
    required this.accountId,
    this.toAccountId,
    this.categoryId,
    required this.amountCents,
    required this.dueAt,
    required this.repeatMonthly,
    required this.completed,
    this.lastPaidAt,
    required this.createdBy,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<String>(kind);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || toAccountId != null) {
      map['to_account_id'] = Variable<String>(toAccountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['amount_cents'] = Variable<int>(amountCents);
    map['due_at'] = Variable<DateTime>(dueAt);
    map['repeat_monthly'] = Variable<bool>(repeatMonthly);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || lastPaidAt != null) {
      map['last_paid_at'] = Variable<DateTime>(lastPaidAt);
    }
    map['created_by'] = Variable<int>(createdBy);
    map['version'] = Variable<int>(version);
    return map;
  }

  WalletScheduledPaymentsCompanion toCompanion(bool nullToAbsent) {
    return WalletScheduledPaymentsCompanion(
      id: Value(id),
      title: Value(title),
      kind: Value(kind),
      accountId: Value(accountId),
      toAccountId: toAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(toAccountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amountCents: Value(amountCents),
      dueAt: Value(dueAt),
      repeatMonthly: Value(repeatMonthly),
      completed: Value(completed),
      lastPaidAt: lastPaidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPaidAt),
      createdBy: Value(createdBy),
      version: Value(version),
    );
  }

  factory WalletPaymentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletPaymentRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<String>(json['kind']),
      accountId: serializer.fromJson<String>(json['accountId']),
      toAccountId: serializer.fromJson<String?>(json['toAccountId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      dueAt: serializer.fromJson<DateTime>(json['dueAt']),
      repeatMonthly: serializer.fromJson<bool>(json['repeatMonthly']),
      completed: serializer.fromJson<bool>(json['completed']),
      lastPaidAt: serializer.fromJson<DateTime?>(json['lastPaidAt']),
      createdBy: serializer.fromJson<int>(json['createdBy']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<String>(kind),
      'accountId': serializer.toJson<String>(accountId),
      'toAccountId': serializer.toJson<String?>(toAccountId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'amountCents': serializer.toJson<int>(amountCents),
      'dueAt': serializer.toJson<DateTime>(dueAt),
      'repeatMonthly': serializer.toJson<bool>(repeatMonthly),
      'completed': serializer.toJson<bool>(completed),
      'lastPaidAt': serializer.toJson<DateTime?>(lastPaidAt),
      'createdBy': serializer.toJson<int>(createdBy),
      'version': serializer.toJson<int>(version),
    };
  }

  WalletPaymentRow copyWith({
    String? id,
    String? title,
    String? kind,
    String? accountId,
    Value<String?> toAccountId = const Value.absent(),
    Value<int?> categoryId = const Value.absent(),
    int? amountCents,
    DateTime? dueAt,
    bool? repeatMonthly,
    bool? completed,
    Value<DateTime?> lastPaidAt = const Value.absent(),
    int? createdBy,
    int? version,
  }) => WalletPaymentRow(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    accountId: accountId ?? this.accountId,
    toAccountId: toAccountId.present ? toAccountId.value : this.toAccountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amountCents: amountCents ?? this.amountCents,
    dueAt: dueAt ?? this.dueAt,
    repeatMonthly: repeatMonthly ?? this.repeatMonthly,
    completed: completed ?? this.completed,
    lastPaidAt: lastPaidAt.present ? lastPaidAt.value : this.lastPaidAt,
    createdBy: createdBy ?? this.createdBy,
    version: version ?? this.version,
  );
  WalletPaymentRow copyWithCompanion(WalletScheduledPaymentsCompanion data) {
    return WalletPaymentRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      toAccountId: data.toAccountId.present
          ? data.toAccountId.value
          : this.toAccountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      dueAt: data.dueAt.present ? data.dueAt.value : this.dueAt,
      repeatMonthly: data.repeatMonthly.present
          ? data.repeatMonthly.value
          : this.repeatMonthly,
      completed: data.completed.present ? data.completed.value : this.completed,
      lastPaidAt: data.lastPaidAt.present
          ? data.lastPaidAt.value
          : this.lastPaidAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletPaymentRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueAt: $dueAt, ')
          ..write('repeatMonthly: $repeatMonthly, ')
          ..write('completed: $completed, ')
          ..write('lastPaidAt: $lastPaidAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    kind,
    accountId,
    toAccountId,
    categoryId,
    amountCents,
    dueAt,
    repeatMonthly,
    completed,
    lastPaidAt,
    createdBy,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletPaymentRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.accountId == this.accountId &&
          other.toAccountId == this.toAccountId &&
          other.categoryId == this.categoryId &&
          other.amountCents == this.amountCents &&
          other.dueAt == this.dueAt &&
          other.repeatMonthly == this.repeatMonthly &&
          other.completed == this.completed &&
          other.lastPaidAt == this.lastPaidAt &&
          other.createdBy == this.createdBy &&
          other.version == this.version);
}

class WalletScheduledPaymentsCompanion
    extends UpdateCompanion<WalletPaymentRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> kind;
  final Value<String> accountId;
  final Value<String?> toAccountId;
  final Value<int?> categoryId;
  final Value<int> amountCents;
  final Value<DateTime> dueAt;
  final Value<bool> repeatMonthly;
  final Value<bool> completed;
  final Value<DateTime?> lastPaidAt;
  final Value<int> createdBy;
  final Value<int> version;
  final Value<int> rowid;
  const WalletScheduledPaymentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.accountId = const Value.absent(),
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.dueAt = const Value.absent(),
    this.repeatMonthly = const Value.absent(),
    this.completed = const Value.absent(),
    this.lastPaidAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletScheduledPaymentsCompanion.insert({
    required String id,
    required String title,
    required String kind,
    required String accountId,
    this.toAccountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required int amountCents,
    required DateTime dueAt,
    this.repeatMonthly = const Value.absent(),
    this.completed = const Value.absent(),
    this.lastPaidAt = const Value.absent(),
    required int createdBy,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       kind = Value(kind),
       accountId = Value(accountId),
       amountCents = Value(amountCents),
       dueAt = Value(dueAt),
       createdBy = Value(createdBy);
  static Insertable<WalletPaymentRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? kind,
    Expression<String>? accountId,
    Expression<String>? toAccountId,
    Expression<int>? categoryId,
    Expression<int>? amountCents,
    Expression<DateTime>? dueAt,
    Expression<bool>? repeatMonthly,
    Expression<bool>? completed,
    Expression<DateTime>? lastPaidAt,
    Expression<int>? createdBy,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (accountId != null) 'account_id': accountId,
      if (toAccountId != null) 'to_account_id': toAccountId,
      if (categoryId != null) 'category_id': categoryId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (dueAt != null) 'due_at': dueAt,
      if (repeatMonthly != null) 'repeat_monthly': repeatMonthly,
      if (completed != null) 'completed': completed,
      if (lastPaidAt != null) 'last_paid_at': lastPaidAt,
      if (createdBy != null) 'created_by': createdBy,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletScheduledPaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? kind,
    Value<String>? accountId,
    Value<String?>? toAccountId,
    Value<int?>? categoryId,
    Value<int>? amountCents,
    Value<DateTime>? dueAt,
    Value<bool>? repeatMonthly,
    Value<bool>? completed,
    Value<DateTime?>? lastPaidAt,
    Value<int>? createdBy,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return WalletScheduledPaymentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      categoryId: categoryId ?? this.categoryId,
      amountCents: amountCents ?? this.amountCents,
      dueAt: dueAt ?? this.dueAt,
      repeatMonthly: repeatMonthly ?? this.repeatMonthly,
      completed: completed ?? this.completed,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
      createdBy: createdBy ?? this.createdBy,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (toAccountId.present) {
      map['to_account_id'] = Variable<String>(toAccountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (dueAt.present) {
      map['due_at'] = Variable<DateTime>(dueAt.value);
    }
    if (repeatMonthly.present) {
      map['repeat_monthly'] = Variable<bool>(repeatMonthly.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (lastPaidAt.present) {
      map['last_paid_at'] = Variable<DateTime>(lastPaidAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<int>(createdBy.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletScheduledPaymentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('accountId: $accountId, ')
          ..write('toAccountId: $toAccountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueAt: $dueAt, ')
          ..write('repeatMonthly: $repeatMonthly, ')
          ..write('completed: $completed, ')
          ..write('lastPaidAt: $lastPaidAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WalletOutboxTable extends WalletOutbox
    with TableInfo<$WalletOutboxTable, WalletOutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WalletOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _requestIdMeta = const VerificationMeta(
    'requestId',
  );
  @override
  late final GeneratedColumn<String> requestId = GeneratedColumn<String>(
    'request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationKeyMeta = const VerificationMeta(
    'operationKey',
  );
  @override
  late final GeneratedColumn<String> operationKey = GeneratedColumn<String>(
    'operation_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountKeysMeta = const VerificationMeta(
    'accountKeys',
  );
  @override
  late final GeneratedColumn<String> accountKeys = GeneratedColumn<String>(
    'account_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    requestId,
    seq,
    operationKey,
    payload,
    accountKeys,
    state,
    attempts,
    nextAttemptAt,
    detail,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wallet_outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<WalletOutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('request_id')) {
      context.handle(
        _requestIdMeta,
        requestId.isAcceptableOrUnknown(data['request_id']!, _requestIdMeta),
      );
    } else if (isInserting) {
      context.missing(_requestIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('operation_key')) {
      context.handle(
        _operationKeyMeta,
        operationKey.isAcceptableOrUnknown(
          data['operation_key']!,
          _operationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationKeyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('account_keys')) {
      context.handle(
        _accountKeysMeta,
        accountKeys.isAcceptableOrUnknown(
          data['account_keys']!,
          _accountKeysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountKeysMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {requestId};
  @override
  WalletOutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WalletOutboxRow(
      requestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      operationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      accountKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_keys'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WalletOutboxTable createAlias(String alias) {
    return $WalletOutboxTable(attachedDatabase, alias);
  }
}

class WalletOutboxRow extends DataClass implements Insertable<WalletOutboxRow> {
  final String requestId;

  /// Queue order (timestamps are only second-precise).
  final int seq;
  final String operationKey;

  /// The full operation envelope (request_id, operation_key, values).
  final String payload;

  /// Comma-separated account ids.
  final String accountKeys;

  /// pending, sent (accepted, waiting for the pull that includes it),
  /// conflict, failed
  final String state;
  final int attempts;
  final DateTime? nextAttemptAt;

  /// 409: the server's current record; failed: the error message.
  final String? detail;
  final DateTime createdAt;
  const WalletOutboxRow({
    required this.requestId,
    required this.seq,
    required this.operationKey,
    required this.payload,
    required this.accountKeys,
    required this.state,
    required this.attempts,
    this.nextAttemptAt,
    this.detail,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['request_id'] = Variable<String>(requestId);
    map['seq'] = Variable<int>(seq);
    map['operation_key'] = Variable<String>(operationKey);
    map['payload'] = Variable<String>(payload);
    map['account_keys'] = Variable<String>(accountKeys);
    map['state'] = Variable<String>(state);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WalletOutboxCompanion toCompanion(bool nullToAbsent) {
    return WalletOutboxCompanion(
      requestId: Value(requestId),
      seq: Value(seq),
      operationKey: Value(operationKey),
      payload: Value(payload),
      accountKeys: Value(accountKeys),
      state: Value(state),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      createdAt: Value(createdAt),
    );
  }

  factory WalletOutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WalletOutboxRow(
      requestId: serializer.fromJson<String>(json['requestId']),
      seq: serializer.fromJson<int>(json['seq']),
      operationKey: serializer.fromJson<String>(json['operationKey']),
      payload: serializer.fromJson<String>(json['payload']),
      accountKeys: serializer.fromJson<String>(json['accountKeys']),
      state: serializer.fromJson<String>(json['state']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      detail: serializer.fromJson<String?>(json['detail']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'requestId': serializer.toJson<String>(requestId),
      'seq': serializer.toJson<int>(seq),
      'operationKey': serializer.toJson<String>(operationKey),
      'payload': serializer.toJson<String>(payload),
      'accountKeys': serializer.toJson<String>(accountKeys),
      'state': serializer.toJson<String>(state),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'detail': serializer.toJson<String?>(detail),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WalletOutboxRow copyWith({
    String? requestId,
    int? seq,
    String? operationKey,
    String? payload,
    String? accountKeys,
    String? state,
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> detail = const Value.absent(),
    DateTime? createdAt,
  }) => WalletOutboxRow(
    requestId: requestId ?? this.requestId,
    seq: seq ?? this.seq,
    operationKey: operationKey ?? this.operationKey,
    payload: payload ?? this.payload,
    accountKeys: accountKeys ?? this.accountKeys,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    detail: detail.present ? detail.value : this.detail,
    createdAt: createdAt ?? this.createdAt,
  );
  WalletOutboxRow copyWithCompanion(WalletOutboxCompanion data) {
    return WalletOutboxRow(
      requestId: data.requestId.present ? data.requestId.value : this.requestId,
      seq: data.seq.present ? data.seq.value : this.seq,
      operationKey: data.operationKey.present
          ? data.operationKey.value
          : this.operationKey,
      payload: data.payload.present ? data.payload.value : this.payload,
      accountKeys: data.accountKeys.present
          ? data.accountKeys.value
          : this.accountKeys,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WalletOutboxRow(')
          ..write('requestId: $requestId, ')
          ..write('seq: $seq, ')
          ..write('operationKey: $operationKey, ')
          ..write('payload: $payload, ')
          ..write('accountKeys: $accountKeys, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    seq,
    operationKey,
    payload,
    accountKeys,
    state,
    attempts,
    nextAttemptAt,
    detail,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WalletOutboxRow &&
          other.requestId == this.requestId &&
          other.seq == this.seq &&
          other.operationKey == this.operationKey &&
          other.payload == this.payload &&
          other.accountKeys == this.accountKeys &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.detail == this.detail &&
          other.createdAt == this.createdAt);
}

class WalletOutboxCompanion extends UpdateCompanion<WalletOutboxRow> {
  final Value<String> requestId;
  final Value<int> seq;
  final Value<String> operationKey;
  final Value<String> payload;
  final Value<String> accountKeys;
  final Value<String> state;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> detail;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const WalletOutboxCompanion({
    this.requestId = const Value.absent(),
    this.seq = const Value.absent(),
    this.operationKey = const Value.absent(),
    this.payload = const Value.absent(),
    this.accountKeys = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WalletOutboxCompanion.insert({
    required String requestId,
    required int seq,
    required String operationKey,
    required String payload,
    required String accountKeys,
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.detail = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : requestId = Value(requestId),
       seq = Value(seq),
       operationKey = Value(operationKey),
       payload = Value(payload),
       accountKeys = Value(accountKeys),
       createdAt = Value(createdAt);
  static Insertable<WalletOutboxRow> custom({
    Expression<String>? requestId,
    Expression<int>? seq,
    Expression<String>? operationKey,
    Expression<String>? payload,
    Expression<String>? accountKeys,
    Expression<String>? state,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? detail,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (requestId != null) 'request_id': requestId,
      if (seq != null) 'seq': seq,
      if (operationKey != null) 'operation_key': operationKey,
      if (payload != null) 'payload': payload,
      if (accountKeys != null) 'account_keys': accountKeys,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (detail != null) 'detail': detail,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WalletOutboxCompanion copyWith({
    Value<String>? requestId,
    Value<int>? seq,
    Value<String>? operationKey,
    Value<String>? payload,
    Value<String>? accountKeys,
    Value<String>? state,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? detail,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return WalletOutboxCompanion(
      requestId: requestId ?? this.requestId,
      seq: seq ?? this.seq,
      operationKey: operationKey ?? this.operationKey,
      payload: payload ?? this.payload,
      accountKeys: accountKeys ?? this.accountKeys,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (requestId.present) {
      map['request_id'] = Variable<String>(requestId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (operationKey.present) {
      map['operation_key'] = Variable<String>(operationKey.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (accountKeys.present) {
      map['account_keys'] = Variable<String>(accountKeys.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WalletOutboxCompanion(')
          ..write('requestId: $requestId, ')
          ..write('seq: $seq, ')
          ..write('operationKey: $operationKey, ')
          ..write('payload: $payload, ')
          ..write('accountKeys: $accountKeys, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('note'),
  );
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pinned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _spaceMeta = const VerificationMeta('space');
  @override
  late final GeneratedColumn<String> space = GeneratedColumn<String>(
    'space',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('me'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    title,
    body,
    kind,
    pinned,
    color,
    eventId,
    archived,
    space,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('pinned')) {
      context.handle(
        _pinnedMeta,
        pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('space')) {
      context.handle(
        _spaceMeta,
        space.isAcceptableOrUnknown(data['space']!, _spaceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      pinned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pinned'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      space: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space'],
      )!,
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final int updatedAtMs;
  final int? deletedAtMs;
  final bool dirty;
  final String title;
  final String body;

  /// note, list
  final String kind;
  final bool pinned;
  final int? color;

  /// The calendar event made from this note, if any.
  final String? eventId;
  final bool archived;
  final String space;
  const LocalNote({
    required this.id,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.dirty,
    required this.title,
    required this.body,
    required this.kind,
    required this.pinned,
    this.color,
    this.eventId,
    required this.archived,
    required this.space,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['kind'] = Variable<String>(kind);
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['archived'] = Variable<bool>(archived);
    map['space'] = Variable<String>(space);
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      dirty: Value(dirty),
      title: Value(title),
      body: Value(body),
      kind: Value(kind),
      pinned: Value(pinned),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      archived: Value(archived),
      space: Value(space),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      kind: serializer.fromJson<String>(json['kind']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      color: serializer.fromJson<int?>(json['color']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      archived: serializer.fromJson<bool>(json['archived']),
      space: serializer.fromJson<String>(json['space']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'dirty': serializer.toJson<bool>(dirty),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'kind': serializer.toJson<String>(kind),
      'pinned': serializer.toJson<bool>(pinned),
      'color': serializer.toJson<int?>(color),
      'eventId': serializer.toJson<String?>(eventId),
      'archived': serializer.toJson<bool>(archived),
      'space': serializer.toJson<String>(space),
    };
  }

  LocalNote copyWith({
    String? id,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    bool? dirty,
    String? title,
    String? body,
    String? kind,
    bool? pinned,
    Value<int?> color = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    bool? archived,
    String? space,
  }) => LocalNote(
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    dirty: dirty ?? this.dirty,
    title: title ?? this.title,
    body: body ?? this.body,
    kind: kind ?? this.kind,
    pinned: pinned ?? this.pinned,
    color: color.present ? color.value : this.color,
    eventId: eventId.present ? eventId.value : this.eventId,
    archived: archived ?? this.archived,
    space: space ?? this.space,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      kind: data.kind.present ? data.kind.value : this.kind,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      color: data.color.present ? data.color.value : this.color,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      archived: data.archived.present ? data.archived.value : this.archived,
      space: data.space.present ? data.space.value : this.space,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('eventId: $eventId, ')
          ..write('archived: $archived, ')
          ..write('space: $space')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    title,
    body,
    kind,
    pinned,
    color,
    eventId,
    archived,
    space,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.dirty == this.dirty &&
          other.title == this.title &&
          other.body == this.body &&
          other.kind == this.kind &&
          other.pinned == this.pinned &&
          other.color == this.color &&
          other.eventId == this.eventId &&
          other.archived == this.archived &&
          other.space == this.space);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<bool> dirty;
  final Value<String> title;
  final Value<String> body;
  final Value<String> kind;
  final Value<bool> pinned;
  final Value<int?> color;
  final Value<String?> eventId;
  final Value<bool> archived;
  final Value<String> space;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.kind = const Value.absent(),
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    this.eventId = const Value.absent(),
    this.archived = const Value.absent(),
    this.space = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.kind = const Value.absent(),
    this.pinned = const Value.absent(),
    this.color = const Value.absent(),
    this.eventId = const Value.absent(),
    this.archived = const Value.absent(),
    this.space = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<bool>? dirty,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? kind,
    Expression<bool>? pinned,
    Expression<int>? color,
    Expression<String>? eventId,
    Expression<bool>? archived,
    Expression<String>? space,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (dirty != null) 'dirty': dirty,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (kind != null) 'kind': kind,
      if (pinned != null) 'pinned': pinned,
      if (color != null) 'color': color,
      if (eventId != null) 'event_id': eventId,
      if (archived != null) 'archived': archived,
      if (space != null) 'space': space,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<bool>? dirty,
    Value<String>? title,
    Value<String>? body,
    Value<String>? kind,
    Value<bool>? pinned,
    Value<int?>? color,
    Value<String?>? eventId,
    Value<bool>? archived,
    Value<String>? space,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      dirty: dirty ?? this.dirty,
      title: title ?? this.title,
      body: body ?? this.body,
      kind: kind ?? this.kind,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
      eventId: eventId ?? this.eventId,
      archived: archived ?? this.archived,
      space: space ?? this.space,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (space.present) {
      map['space'] = Variable<String>(space.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('kind: $kind, ')
          ..write('pinned: $pinned, ')
          ..write('color: $color, ')
          ..write('eventId: $eventId, ')
          ..write('archived: $archived, ')
          ..write('space: $space, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNoteItemsTable extends LocalNoteItems
    with TableInfo<$LocalNoteItemsTable, LocalNoteItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNoteItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMsMeta = const VerificationMeta(
    'deletedAtMs',
  );
  @override
  late final GeneratedColumn<int> deletedAtMs = GeneratedColumn<int>(
    'deleted_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<bool> done = GeneratedColumn<bool>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<double> position = GeneratedColumn<double>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _doneByMeta = const VerificationMeta('doneBy');
  @override
  late final GeneratedColumn<int> doneBy = GeneratedColumn<int>(
    'done_by',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spaceMeta = const VerificationMeta('space');
  @override
  late final GeneratedColumn<String> space = GeneratedColumn<String>(
    'space',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('me'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    noteId,
    content,
    done,
    position,
    doneBy,
    space,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_note_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNoteItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    if (data.containsKey('deleted_at_ms')) {
      context.handle(
        _deletedAtMsMeta,
        deletedAtMs.isAcceptableOrUnknown(
          data['deleted_at_ms']!,
          _deletedAtMsMeta,
        ),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('done_by')) {
      context.handle(
        _doneByMeta,
        doneBy.isAcceptableOrUnknown(data['done_by']!, _doneByMeta),
      );
    }
    if (data.containsKey('space')) {
      context.handle(
        _spaceMeta,
        space.isAcceptableOrUnknown(data['space']!, _spaceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalNoteItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNoteItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
      deletedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_ms'],
      ),
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}done'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position'],
      )!,
      doneBy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_by'],
      ),
      space: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space'],
      )!,
    );
  }

  @override
  $LocalNoteItemsTable createAlias(String alias) {
    return $LocalNoteItemsTable(attachedDatabase, alias);
  }
}

class LocalNoteItem extends DataClass implements Insertable<LocalNoteItem> {
  final String id;
  final int updatedAtMs;
  final int? deletedAtMs;
  final bool dirty;
  final String noteId;
  final String content;
  final bool done;
  final double position;

  /// User id that ticked it (shared lists).
  final int? doneBy;
  final String space;
  const LocalNoteItem({
    required this.id,
    required this.updatedAtMs,
    this.deletedAtMs,
    required this.dirty,
    required this.noteId,
    required this.content,
    required this.done,
    required this.position,
    this.doneBy,
    required this.space,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    if (!nullToAbsent || deletedAtMs != null) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs);
    }
    map['dirty'] = Variable<bool>(dirty);
    map['note_id'] = Variable<String>(noteId);
    map['content'] = Variable<String>(content);
    map['done'] = Variable<bool>(done);
    map['position'] = Variable<double>(position);
    if (!nullToAbsent || doneBy != null) {
      map['done_by'] = Variable<int>(doneBy);
    }
    map['space'] = Variable<String>(space);
    return map;
  }

  LocalNoteItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalNoteItemsCompanion(
      id: Value(id),
      updatedAtMs: Value(updatedAtMs),
      deletedAtMs: deletedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtMs),
      dirty: Value(dirty),
      noteId: Value(noteId),
      content: Value(content),
      done: Value(done),
      position: Value(position),
      doneBy: doneBy == null && nullToAbsent
          ? const Value.absent()
          : Value(doneBy),
      space: Value(space),
    );
  }

  factory LocalNoteItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNoteItem(
      id: serializer.fromJson<String>(json['id']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
      deletedAtMs: serializer.fromJson<int?>(json['deletedAtMs']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      noteId: serializer.fromJson<String>(json['noteId']),
      content: serializer.fromJson<String>(json['content']),
      done: serializer.fromJson<bool>(json['done']),
      position: serializer.fromJson<double>(json['position']),
      doneBy: serializer.fromJson<int?>(json['doneBy']),
      space: serializer.fromJson<String>(json['space']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
      'deletedAtMs': serializer.toJson<int?>(deletedAtMs),
      'dirty': serializer.toJson<bool>(dirty),
      'noteId': serializer.toJson<String>(noteId),
      'content': serializer.toJson<String>(content),
      'done': serializer.toJson<bool>(done),
      'position': serializer.toJson<double>(position),
      'doneBy': serializer.toJson<int?>(doneBy),
      'space': serializer.toJson<String>(space),
    };
  }

  LocalNoteItem copyWith({
    String? id,
    int? updatedAtMs,
    Value<int?> deletedAtMs = const Value.absent(),
    bool? dirty,
    String? noteId,
    String? content,
    bool? done,
    double? position,
    Value<int?> doneBy = const Value.absent(),
    String? space,
  }) => LocalNoteItem(
    id: id ?? this.id,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    deletedAtMs: deletedAtMs.present ? deletedAtMs.value : this.deletedAtMs,
    dirty: dirty ?? this.dirty,
    noteId: noteId ?? this.noteId,
    content: content ?? this.content,
    done: done ?? this.done,
    position: position ?? this.position,
    doneBy: doneBy.present ? doneBy.value : this.doneBy,
    space: space ?? this.space,
  );
  LocalNoteItem copyWithCompanion(LocalNoteItemsCompanion data) {
    return LocalNoteItem(
      id: data.id.present ? data.id.value : this.id,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
      deletedAtMs: data.deletedAtMs.present
          ? data.deletedAtMs.value
          : this.deletedAtMs,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      content: data.content.present ? data.content.value : this.content,
      done: data.done.present ? data.done.value : this.done,
      position: data.position.present ? data.position.value : this.position,
      doneBy: data.doneBy.present ? data.doneBy.value : this.doneBy,
      space: data.space.present ? data.space.value : this.space,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNoteItem(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('noteId: $noteId, ')
          ..write('content: $content, ')
          ..write('done: $done, ')
          ..write('position: $position, ')
          ..write('doneBy: $doneBy, ')
          ..write('space: $space')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    updatedAtMs,
    deletedAtMs,
    dirty,
    noteId,
    content,
    done,
    position,
    doneBy,
    space,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNoteItem &&
          other.id == this.id &&
          other.updatedAtMs == this.updatedAtMs &&
          other.deletedAtMs == this.deletedAtMs &&
          other.dirty == this.dirty &&
          other.noteId == this.noteId &&
          other.content == this.content &&
          other.done == this.done &&
          other.position == this.position &&
          other.doneBy == this.doneBy &&
          other.space == this.space);
}

class LocalNoteItemsCompanion extends UpdateCompanion<LocalNoteItem> {
  final Value<String> id;
  final Value<int> updatedAtMs;
  final Value<int?> deletedAtMs;
  final Value<bool> dirty;
  final Value<String> noteId;
  final Value<String> content;
  final Value<bool> done;
  final Value<double> position;
  final Value<int?> doneBy;
  final Value<String> space;
  final Value<int> rowid;
  const LocalNoteItemsCompanion({
    this.id = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    this.noteId = const Value.absent(),
    this.content = const Value.absent(),
    this.done = const Value.absent(),
    this.position = const Value.absent(),
    this.doneBy = const Value.absent(),
    this.space = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNoteItemsCompanion.insert({
    required String id,
    required int updatedAtMs,
    this.deletedAtMs = const Value.absent(),
    this.dirty = const Value.absent(),
    required String noteId,
    this.content = const Value.absent(),
    this.done = const Value.absent(),
    this.position = const Value.absent(),
    this.doneBy = const Value.absent(),
    this.space = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       updatedAtMs = Value(updatedAtMs),
       noteId = Value(noteId);
  static Insertable<LocalNoteItem> custom({
    Expression<String>? id,
    Expression<int>? updatedAtMs,
    Expression<int>? deletedAtMs,
    Expression<bool>? dirty,
    Expression<String>? noteId,
    Expression<String>? content,
    Expression<bool>? done,
    Expression<double>? position,
    Expression<int>? doneBy,
    Expression<String>? space,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (deletedAtMs != null) 'deleted_at_ms': deletedAtMs,
      if (dirty != null) 'dirty': dirty,
      if (noteId != null) 'note_id': noteId,
      if (content != null) 'content': content,
      if (done != null) 'done': done,
      if (position != null) 'position': position,
      if (doneBy != null) 'done_by': doneBy,
      if (space != null) 'space': space,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNoteItemsCompanion copyWith({
    Value<String>? id,
    Value<int>? updatedAtMs,
    Value<int?>? deletedAtMs,
    Value<bool>? dirty,
    Value<String>? noteId,
    Value<String>? content,
    Value<bool>? done,
    Value<double>? position,
    Value<int?>? doneBy,
    Value<String>? space,
    Value<int>? rowid,
  }) {
    return LocalNoteItemsCompanion(
      id: id ?? this.id,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deletedAtMs: deletedAtMs ?? this.deletedAtMs,
      dirty: dirty ?? this.dirty,
      noteId: noteId ?? this.noteId,
      content: content ?? this.content,
      done: done ?? this.done,
      position: position ?? this.position,
      doneBy: doneBy ?? this.doneBy,
      space: space ?? this.space,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (deletedAtMs.present) {
      map['deleted_at_ms'] = Variable<int>(deletedAtMs.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (done.present) {
      map['done'] = Variable<bool>(done.value);
    }
    if (position.present) {
      map['position'] = Variable<double>(position.value);
    }
    if (doneBy.present) {
      map['done_by'] = Variable<int>(doneBy.value);
    }
    if (space.present) {
      map['space'] = Variable<String>(space.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNoteItemsCompanion(')
          ..write('id: $id, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('deletedAtMs: $deletedAtMs, ')
          ..write('dirty: $dirty, ')
          ..write('noteId: $noteId, ')
          ..write('content: $content, ')
          ..write('done: $done, ')
          ..write('position: $position, ')
          ..write('doneBy: $doneBy, ')
          ..write('space: $space, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedDocumentsTable cachedDocuments = $CachedDocumentsTable(
    this,
  );
  late final $QueuedOperationsTable queuedOperations = $QueuedOperationsTable(
    this,
  );
  late final $LocalEventsTable localEvents = $LocalEventsTable(this);
  late final $LocalMedicationsTable localMedications = $LocalMedicationsTable(
    this,
  );
  late final $LocalDoseLogsTable localDoseLogs = $LocalDoseLogsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $WalletAccountsTable walletAccounts = $WalletAccountsTable(this);
  late final $WalletTransactionsTable walletTransactions =
      $WalletTransactionsTable(this);
  late final $WalletTransfersTable walletTransfers = $WalletTransfersTable(
    this,
  );
  late final $WalletStatementMarksTable walletStatementMarks =
      $WalletStatementMarksTable(this);
  late final $WalletScheduledPaymentsTable walletScheduledPayments =
      $WalletScheduledPaymentsTable(this);
  late final $WalletOutboxTable walletOutbox = $WalletOutboxTable(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $LocalNoteItemsTable localNoteItems = $LocalNoteItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedDocuments,
    queuedOperations,
    localEvents,
    localMedications,
    localDoseLogs,
    syncStates,
    walletAccounts,
    walletTransactions,
    walletTransfers,
    walletStatementMarks,
    walletScheduledPayments,
    walletOutbox,
    localNotes,
    localNoteItems,
  ];
}

typedef $$CachedDocumentsTableCreateCompanionBuilder =
    CachedDocumentsCompanion Function({
      required String key,
      required String payload,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedDocumentsTableUpdateCompanionBuilder =
    CachedDocumentsCompanion Function({
      Value<String> key,
      Value<String> payload,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedDocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocumentsTable> {
  $$CachedDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedDocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocumentsTable,
          CachedDocument,
          $$CachedDocumentsTableFilterComposer,
          $$CachedDocumentsTableOrderingComposer,
          $$CachedDocumentsTableAnnotationComposer,
          $$CachedDocumentsTableCreateCompanionBuilder,
          $$CachedDocumentsTableUpdateCompanionBuilder,
          (
            CachedDocument,
            BaseReferences<
              _$AppDatabase,
              $CachedDocumentsTable,
              CachedDocument
            >,
          ),
          CachedDocument,
          PrefetchHooks Function()
        > {
  $$CachedDocumentsTableTableManager(
    _$AppDatabase db,
    $CachedDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion(
                key: key,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDocumentsCompanion.insert(
                key: key,
                payload: payload,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocumentsTable,
      CachedDocument,
      $$CachedDocumentsTableFilterComposer,
      $$CachedDocumentsTableOrderingComposer,
      $$CachedDocumentsTableAnnotationComposer,
      $$CachedDocumentsTableCreateCompanionBuilder,
      $$CachedDocumentsTableUpdateCompanionBuilder,
      (
        CachedDocument,
        BaseReferences<_$AppDatabase, $CachedDocumentsTable, CachedDocument>,
      ),
      CachedDocument,
      PrefetchHooks Function()
    >;
typedef $$QueuedOperationsTableCreateCompanionBuilder =
    QueuedOperationsCompanion Function({
      required String requestId,
      required String operationKey,
      required String payload,
      Value<String> state,
      Value<String?> conflictPayload,
      Value<int> attempts,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$QueuedOperationsTableUpdateCompanionBuilder =
    QueuedOperationsCompanion Function({
      Value<String> requestId,
      Value<String> operationKey,
      Value<String> payload,
      Value<String> state,
      Value<String?> conflictPayload,
      Value<int> attempts,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$QueuedOperationsTableFilterComposer
    extends Composer<_$AppDatabase, $QueuedOperationsTable> {
  $$QueuedOperationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conflictPayload => $composableBuilder(
    column: $table.conflictPayload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QueuedOperationsTableOrderingComposer
    extends Composer<_$AppDatabase, $QueuedOperationsTable> {
  $$QueuedOperationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conflictPayload => $composableBuilder(
    column: $table.conflictPayload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QueuedOperationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QueuedOperationsTable> {
  $$QueuedOperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get conflictPayload => $composableBuilder(
    column: $table.conflictPayload,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$QueuedOperationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QueuedOperationsTable,
          QueuedOperation,
          $$QueuedOperationsTableFilterComposer,
          $$QueuedOperationsTableOrderingComposer,
          $$QueuedOperationsTableAnnotationComposer,
          $$QueuedOperationsTableCreateCompanionBuilder,
          $$QueuedOperationsTableUpdateCompanionBuilder,
          (
            QueuedOperation,
            BaseReferences<
              _$AppDatabase,
              $QueuedOperationsTable,
              QueuedOperation
            >,
          ),
          QueuedOperation,
          PrefetchHooks Function()
        > {
  $$QueuedOperationsTableTableManager(
    _$AppDatabase db,
    $QueuedOperationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QueuedOperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QueuedOperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QueuedOperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<String> operationKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> conflictPayload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QueuedOperationsCompanion(
                requestId: requestId,
                operationKey: operationKey,
                payload: payload,
                state: state,
                conflictPayload: conflictPayload,
                attempts: attempts,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required String operationKey,
                required String payload,
                Value<String> state = const Value.absent(),
                Value<String?> conflictPayload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => QueuedOperationsCompanion.insert(
                requestId: requestId,
                operationKey: operationKey,
                payload: payload,
                state: state,
                conflictPayload: conflictPayload,
                attempts: attempts,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QueuedOperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QueuedOperationsTable,
      QueuedOperation,
      $$QueuedOperationsTableFilterComposer,
      $$QueuedOperationsTableOrderingComposer,
      $$QueuedOperationsTableAnnotationComposer,
      $$QueuedOperationsTableCreateCompanionBuilder,
      $$QueuedOperationsTableUpdateCompanionBuilder,
      (
        QueuedOperation,
        BaseReferences<_$AppDatabase, $QueuedOperationsTable, QueuedOperation>,
      ),
      QueuedOperation,
      PrefetchHooks Function()
    >;
typedef $$LocalEventsTableCreateCompanionBuilder =
    LocalEventsCompanion Function({
      required String id,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      required String title,
      Value<String?> notes,
      required DateTime startsAt,
      Value<DateTime?> endsAt,
      Value<bool> allDay,
      Value<int?> color,
      Value<bool> important,
      Value<String?> recurrence,
      Value<String> reminders,
      Value<int> rowid,
    });
typedef $$LocalEventsTableUpdateCompanionBuilder =
    LocalEventsCompanion Function({
      Value<String> id,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime> startsAt,
      Value<DateTime?> endsAt,
      Value<bool> allDay,
      Value<int?> color,
      Value<bool> important,
      Value<String?> recurrence,
      Value<String> reminders,
      Value<int> rowid,
    });

class $$LocalEventsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get important => $composableBuilder(
    column: $table.important,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsAt => $composableBuilder(
    column: $table.startsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsAt => $composableBuilder(
    column: $table.endsAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get allDay => $composableBuilder(
    column: $table.allDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get important => $composableBuilder(
    column: $table.important,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminders => $composableBuilder(
    column: $table.reminders,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalEventsTable> {
  $$LocalEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get startsAt =>
      $composableBuilder(column: $table.startsAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endsAt =>
      $composableBuilder(column: $table.endsAt, builder: (column) => column);

  GeneratedColumn<bool> get allDay =>
      $composableBuilder(column: $table.allDay, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get important =>
      $composableBuilder(column: $table.important, builder: (column) => column);

  GeneratedColumn<String> get recurrence => $composableBuilder(
    column: $table.recurrence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminders =>
      $composableBuilder(column: $table.reminders, builder: (column) => column);
}

class $$LocalEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalEventsTable,
          LocalEvent,
          $$LocalEventsTableFilterComposer,
          $$LocalEventsTableOrderingComposer,
          $$LocalEventsTableAnnotationComposer,
          $$LocalEventsTableCreateCompanionBuilder,
          $$LocalEventsTableUpdateCompanionBuilder,
          (
            LocalEvent,
            BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
          ),
          LocalEvent,
          PrefetchHooks Function()
        > {
  $$LocalEventsTableTableManager(_$AppDatabase db, $LocalEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> startsAt = const Value.absent(),
                Value<DateTime?> endsAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<bool> important = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                title: title,
                notes: notes,
                startsAt: startsAt,
                endsAt: endsAt,
                allDay: allDay,
                color: color,
                important: important,
                recurrence: recurrence,
                reminders: reminders,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String title,
                Value<String?> notes = const Value.absent(),
                required DateTime startsAt,
                Value<DateTime?> endsAt = const Value.absent(),
                Value<bool> allDay = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<bool> important = const Value.absent(),
                Value<String?> recurrence = const Value.absent(),
                Value<String> reminders = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalEventsCompanion.insert(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                title: title,
                notes: notes,
                startsAt: startsAt,
                endsAt: endsAt,
                allDay: allDay,
                color: color,
                important: important,
                recurrence: recurrence,
                reminders: reminders,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalEventsTable,
      LocalEvent,
      $$LocalEventsTableFilterComposer,
      $$LocalEventsTableOrderingComposer,
      $$LocalEventsTableAnnotationComposer,
      $$LocalEventsTableCreateCompanionBuilder,
      $$LocalEventsTableUpdateCompanionBuilder,
      (
        LocalEvent,
        BaseReferences<_$AppDatabase, $LocalEventsTable, LocalEvent>,
      ),
      LocalEvent,
      PrefetchHooks Function()
    >;
typedef $$LocalMedicationsTableCreateCompanionBuilder =
    LocalMedicationsCompanion Function({
      required String id,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      required String name,
      Value<String> form,
      Value<double> doseAmount,
      Value<String> doseUnit,
      Value<String?> mealRelation,
      Value<String?> notes,
      required String schedule,
      required DateTime startsOn,
      Value<DateTime?> endsOn,
      Value<double?> stock,
      Value<double?> stockAlert,
      Value<String> alarm,
      Value<bool> active,
      Value<int> rowid,
    });
typedef $$LocalMedicationsTableUpdateCompanionBuilder =
    LocalMedicationsCompanion Function({
      Value<String> id,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> name,
      Value<String> form,
      Value<double> doseAmount,
      Value<String> doseUnit,
      Value<String?> mealRelation,
      Value<String?> notes,
      Value<String> schedule,
      Value<DateTime> startsOn,
      Value<DateTime?> endsOn,
      Value<double?> stock,
      Value<double?> stockAlert,
      Value<String> alarm,
      Value<bool> active,
      Value<int> rowid,
    });

class $$LocalMedicationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMedicationsTable> {
  $$LocalMedicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get doseAmount => $composableBuilder(
    column: $table.doseAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get doseUnit => $composableBuilder(
    column: $table.doseUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealRelation => $composableBuilder(
    column: $table.mealRelation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stockAlert => $composableBuilder(
    column: $table.stockAlert,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alarm => $composableBuilder(
    column: $table.alarm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMedicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMedicationsTable> {
  $$LocalMedicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get form => $composableBuilder(
    column: $table.form,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get doseAmount => $composableBuilder(
    column: $table.doseAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get doseUnit => $composableBuilder(
    column: $table.doseUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealRelation => $composableBuilder(
    column: $table.mealRelation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schedule => $composableBuilder(
    column: $table.schedule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startsOn => $composableBuilder(
    column: $table.startsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stockAlert => $composableBuilder(
    column: $table.stockAlert,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alarm => $composableBuilder(
    column: $table.alarm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMedicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMedicationsTable> {
  $$LocalMedicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get form =>
      $composableBuilder(column: $table.form, builder: (column) => column);

  GeneratedColumn<double> get doseAmount => $composableBuilder(
    column: $table.doseAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get doseUnit =>
      $composableBuilder(column: $table.doseUnit, builder: (column) => column);

  GeneratedColumn<String> get mealRelation => $composableBuilder(
    column: $table.mealRelation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get schedule =>
      $composableBuilder(column: $table.schedule, builder: (column) => column);

  GeneratedColumn<DateTime> get startsOn =>
      $composableBuilder(column: $table.startsOn, builder: (column) => column);

  GeneratedColumn<DateTime> get endsOn =>
      $composableBuilder(column: $table.endsOn, builder: (column) => column);

  GeneratedColumn<double> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<double> get stockAlert => $composableBuilder(
    column: $table.stockAlert,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alarm =>
      $composableBuilder(column: $table.alarm, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);
}

class $$LocalMedicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMedicationsTable,
          LocalMedication,
          $$LocalMedicationsTableFilterComposer,
          $$LocalMedicationsTableOrderingComposer,
          $$LocalMedicationsTableAnnotationComposer,
          $$LocalMedicationsTableCreateCompanionBuilder,
          $$LocalMedicationsTableUpdateCompanionBuilder,
          (
            LocalMedication,
            BaseReferences<
              _$AppDatabase,
              $LocalMedicationsTable,
              LocalMedication
            >,
          ),
          LocalMedication,
          PrefetchHooks Function()
        > {
  $$LocalMedicationsTableTableManager(
    _$AppDatabase db,
    $LocalMedicationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMedicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMedicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMedicationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> form = const Value.absent(),
                Value<double> doseAmount = const Value.absent(),
                Value<String> doseUnit = const Value.absent(),
                Value<String?> mealRelation = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> schedule = const Value.absent(),
                Value<DateTime> startsOn = const Value.absent(),
                Value<DateTime?> endsOn = const Value.absent(),
                Value<double?> stock = const Value.absent(),
                Value<double?> stockAlert = const Value.absent(),
                Value<String> alarm = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMedicationsCompanion(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                name: name,
                form: form,
                doseAmount: doseAmount,
                doseUnit: doseUnit,
                mealRelation: mealRelation,
                notes: notes,
                schedule: schedule,
                startsOn: startsOn,
                endsOn: endsOn,
                stock: stock,
                stockAlert: stockAlert,
                alarm: alarm,
                active: active,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String name,
                Value<String> form = const Value.absent(),
                Value<double> doseAmount = const Value.absent(),
                Value<String> doseUnit = const Value.absent(),
                Value<String?> mealRelation = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                required String schedule,
                required DateTime startsOn,
                Value<DateTime?> endsOn = const Value.absent(),
                Value<double?> stock = const Value.absent(),
                Value<double?> stockAlert = const Value.absent(),
                Value<String> alarm = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMedicationsCompanion.insert(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                name: name,
                form: form,
                doseAmount: doseAmount,
                doseUnit: doseUnit,
                mealRelation: mealRelation,
                notes: notes,
                schedule: schedule,
                startsOn: startsOn,
                endsOn: endsOn,
                stock: stock,
                stockAlert: stockAlert,
                alarm: alarm,
                active: active,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMedicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMedicationsTable,
      LocalMedication,
      $$LocalMedicationsTableFilterComposer,
      $$LocalMedicationsTableOrderingComposer,
      $$LocalMedicationsTableAnnotationComposer,
      $$LocalMedicationsTableCreateCompanionBuilder,
      $$LocalMedicationsTableUpdateCompanionBuilder,
      (
        LocalMedication,
        BaseReferences<_$AppDatabase, $LocalMedicationsTable, LocalMedication>,
      ),
      LocalMedication,
      PrefetchHooks Function()
    >;
typedef $$LocalDoseLogsTableCreateCompanionBuilder =
    LocalDoseLogsCompanion Function({
      required String id,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      required String medicationId,
      required DateTime scheduledFor,
      required String status,
      Value<DateTime?> actedAt,
      Value<DateTime?> snoozedUntil,
      Value<int> rowid,
    });
typedef $$LocalDoseLogsTableUpdateCompanionBuilder =
    LocalDoseLogsCompanion Function({
      Value<String> id,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> medicationId,
      Value<DateTime> scheduledFor,
      Value<String> status,
      Value<DateTime?> actedAt,
      Value<DateTime?> snoozedUntil,
      Value<int> rowid,
    });

class $$LocalDoseLogsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actedAt => $composableBuilder(
    column: $table.actedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalDoseLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actedAt => $composableBuilder(
    column: $table.actedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalDoseLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalDoseLogsTable> {
  $$LocalDoseLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get medicationId => $composableBuilder(
    column: $table.medicationId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledFor => $composableBuilder(
    column: $table.scheduledFor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get actedAt =>
      $composableBuilder(column: $table.actedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );
}

class $$LocalDoseLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalDoseLogsTable,
          LocalDoseLog,
          $$LocalDoseLogsTableFilterComposer,
          $$LocalDoseLogsTableOrderingComposer,
          $$LocalDoseLogsTableAnnotationComposer,
          $$LocalDoseLogsTableCreateCompanionBuilder,
          $$LocalDoseLogsTableUpdateCompanionBuilder,
          (
            LocalDoseLog,
            BaseReferences<_$AppDatabase, $LocalDoseLogsTable, LocalDoseLog>,
          ),
          LocalDoseLog,
          PrefetchHooks Function()
        > {
  $$LocalDoseLogsTableTableManager(_$AppDatabase db, $LocalDoseLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalDoseLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalDoseLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalDoseLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> medicationId = const Value.absent(),
                Value<DateTime> scheduledFor = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> actedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDoseLogsCompanion(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                medicationId: medicationId,
                scheduledFor: scheduledFor,
                status: status,
                actedAt: actedAt,
                snoozedUntil: snoozedUntil,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String medicationId,
                required DateTime scheduledFor,
                required String status,
                Value<DateTime?> actedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalDoseLogsCompanion.insert(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                medicationId: medicationId,
                scheduledFor: scheduledFor,
                status: status,
                actedAt: actedAt,
                snoozedUntil: snoozedUntil,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalDoseLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalDoseLogsTable,
      LocalDoseLog,
      $$LocalDoseLogsTableFilterComposer,
      $$LocalDoseLogsTableOrderingComposer,
      $$LocalDoseLogsTableAnnotationComposer,
      $$LocalDoseLogsTableCreateCompanionBuilder,
      $$LocalDoseLogsTableUpdateCompanionBuilder,
      (
        LocalDoseLog,
        BaseReferences<_$AppDatabase, $LocalDoseLogsTable, LocalDoseLog>,
      ),
      LocalDoseLog,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncState,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncState,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>,
          ),
          SyncState,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncState,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
      SyncState,
      PrefetchHooks Function()
    >;
typedef $$WalletAccountsTableCreateCompanionBuilder =
    WalletAccountsCompanion Function({
      required String id,
      Value<int?> serverId,
      required int ownerId,
      required String name,
      required String type,
      Value<String?> bank,
      Value<String> currency,
      required int balanceCents,
      Value<int> openingCents,
      Value<int?> limitCents,
      Value<int?> statementDay,
      Value<int?> dueDay,
      Value<String> visibility,
      Value<String?> last4,
      Value<String?> network,
      Value<String?> color,
      Value<String?> iban,
      Value<bool> active,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$WalletAccountsTableUpdateCompanionBuilder =
    WalletAccountsCompanion Function({
      Value<String> id,
      Value<int?> serverId,
      Value<int> ownerId,
      Value<String> name,
      Value<String> type,
      Value<String?> bank,
      Value<String> currency,
      Value<int> balanceCents,
      Value<int> openingCents,
      Value<int?> limitCents,
      Value<int?> statementDay,
      Value<int?> dueDay,
      Value<String> visibility,
      Value<String?> last4,
      Value<String?> network,
      Value<String?> color,
      Value<String?> iban,
      Value<bool> active,
      Value<int> version,
      Value<int> rowid,
    });

class $$WalletAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletAccountsTable> {
  $$WalletAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceCents => $composableBuilder(
    column: $table.balanceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingCents => $composableBuilder(
    column: $table.openingCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitCents => $composableBuilder(
    column: $table.limitCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletAccountsTable> {
  $$WalletAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bank => $composableBuilder(
    column: $table.bank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceCents => $composableBuilder(
    column: $table.balanceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingCents => $composableBuilder(
    column: $table.openingCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitCents => $composableBuilder(
    column: $table.limitCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get last4 => $composableBuilder(
    column: $table.last4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get network => $composableBuilder(
    column: $table.network,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iban => $composableBuilder(
    column: $table.iban,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletAccountsTable> {
  $$WalletAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get bank =>
      $composableBuilder(column: $table.bank, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get balanceCents => $composableBuilder(
    column: $table.balanceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get openingCents => $composableBuilder(
    column: $table.openingCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get limitCents => $composableBuilder(
    column: $table.limitCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get statementDay => $composableBuilder(
    column: $table.statementDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get last4 =>
      $composableBuilder(column: $table.last4, builder: (column) => column);

  GeneratedColumn<String> get network =>
      $composableBuilder(column: $table.network, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get iban =>
      $composableBuilder(column: $table.iban, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$WalletAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletAccountsTable,
          WalletAccountRow,
          $$WalletAccountsTableFilterComposer,
          $$WalletAccountsTableOrderingComposer,
          $$WalletAccountsTableAnnotationComposer,
          $$WalletAccountsTableCreateCompanionBuilder,
          $$WalletAccountsTableUpdateCompanionBuilder,
          (
            WalletAccountRow,
            BaseReferences<
              _$AppDatabase,
              $WalletAccountsTable,
              WalletAccountRow
            >,
          ),
          WalletAccountRow,
          PrefetchHooks Function()
        > {
  $$WalletAccountsTableTableManager(
    _$AppDatabase db,
    $WalletAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<int> ownerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> bank = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> balanceCents = const Value.absent(),
                Value<int> openingCents = const Value.absent(),
                Value<int?> limitCents = const Value.absent(),
                Value<int?> statementDay = const Value.absent(),
                Value<int?> dueDay = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<String?> network = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletAccountsCompanion(
                id: id,
                serverId: serverId,
                ownerId: ownerId,
                name: name,
                type: type,
                bank: bank,
                currency: currency,
                balanceCents: balanceCents,
                openingCents: openingCents,
                limitCents: limitCents,
                statementDay: statementDay,
                dueDay: dueDay,
                visibility: visibility,
                last4: last4,
                network: network,
                color: color,
                iban: iban,
                active: active,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int?> serverId = const Value.absent(),
                required int ownerId,
                required String name,
                required String type,
                Value<String?> bank = const Value.absent(),
                Value<String> currency = const Value.absent(),
                required int balanceCents,
                Value<int> openingCents = const Value.absent(),
                Value<int?> limitCents = const Value.absent(),
                Value<int?> statementDay = const Value.absent(),
                Value<int?> dueDay = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String?> last4 = const Value.absent(),
                Value<String?> network = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<String?> iban = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletAccountsCompanion.insert(
                id: id,
                serverId: serverId,
                ownerId: ownerId,
                name: name,
                type: type,
                bank: bank,
                currency: currency,
                balanceCents: balanceCents,
                openingCents: openingCents,
                limitCents: limitCents,
                statementDay: statementDay,
                dueDay: dueDay,
                visibility: visibility,
                last4: last4,
                network: network,
                color: color,
                iban: iban,
                active: active,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletAccountsTable,
      WalletAccountRow,
      $$WalletAccountsTableFilterComposer,
      $$WalletAccountsTableOrderingComposer,
      $$WalletAccountsTableAnnotationComposer,
      $$WalletAccountsTableCreateCompanionBuilder,
      $$WalletAccountsTableUpdateCompanionBuilder,
      (
        WalletAccountRow,
        BaseReferences<_$AppDatabase, $WalletAccountsTable, WalletAccountRow>,
      ),
      WalletAccountRow,
      PrefetchHooks Function()
    >;
typedef $$WalletTransactionsTableCreateCompanionBuilder =
    WalletTransactionsCompanion Function({
      required String id,
      required String accountId,
      required String kind,
      Value<int?> categoryId,
      Value<String?> category,
      required int amountCents,
      required DateTime occurredAt,
      Value<DateTime?> statementMonth,
      Value<String?> note,
      required int createdBy,
      Value<String?> installmentGroup,
      Value<int?> installmentIndex,
      Value<int?> installmentCount,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$WalletTransactionsTableUpdateCompanionBuilder =
    WalletTransactionsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> kind,
      Value<int?> categoryId,
      Value<String?> category,
      Value<int> amountCents,
      Value<DateTime> occurredAt,
      Value<DateTime?> statementMonth,
      Value<String?> note,
      Value<int> createdBy,
      Value<String?> installmentGroup,
      Value<int?> installmentIndex,
      Value<int?> installmentCount,
      Value<int> version,
      Value<int> rowid,
    });

class $$WalletTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get statementMonth => $composableBuilder(
    column: $table.statementMonth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get installmentGroup => $composableBuilder(
    column: $table.installmentGroup,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get installmentIndex => $composableBuilder(
    column: $table.installmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get installmentCount => $composableBuilder(
    column: $table.installmentCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get statementMonth => $composableBuilder(
    column: $table.statementMonth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get installmentGroup => $composableBuilder(
    column: $table.installmentGroup,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installmentIndex => $composableBuilder(
    column: $table.installmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installmentCount => $composableBuilder(
    column: $table.installmentCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletTransactionsTable> {
  $$WalletTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get statementMonth => $composableBuilder(
    column: $table.statementMonth,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get installmentGroup => $composableBuilder(
    column: $table.installmentGroup,
    builder: (column) => column,
  );

  GeneratedColumn<int> get installmentIndex => $composableBuilder(
    column: $table.installmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get installmentCount => $composableBuilder(
    column: $table.installmentCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$WalletTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletTransactionsTable,
          WalletTransactionRow,
          $$WalletTransactionsTableFilterComposer,
          $$WalletTransactionsTableOrderingComposer,
          $$WalletTransactionsTableAnnotationComposer,
          $$WalletTransactionsTableCreateCompanionBuilder,
          $$WalletTransactionsTableUpdateCompanionBuilder,
          (
            WalletTransactionRow,
            BaseReferences<
              _$AppDatabase,
              $WalletTransactionsTable,
              WalletTransactionRow
            >,
          ),
          WalletTransactionRow,
          PrefetchHooks Function()
        > {
  $$WalletTransactionsTableTableManager(
    _$AppDatabase db,
    $WalletTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime?> statementMonth = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<String?> installmentGroup = const Value.absent(),
                Value<int?> installmentIndex = const Value.absent(),
                Value<int?> installmentCount = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletTransactionsCompanion(
                id: id,
                accountId: accountId,
                kind: kind,
                categoryId: categoryId,
                category: category,
                amountCents: amountCents,
                occurredAt: occurredAt,
                statementMonth: statementMonth,
                note: note,
                createdBy: createdBy,
                installmentGroup: installmentGroup,
                installmentIndex: installmentIndex,
                installmentCount: installmentCount,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String kind,
                Value<int?> categoryId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                required int amountCents,
                required DateTime occurredAt,
                Value<DateTime?> statementMonth = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdBy,
                Value<String?> installmentGroup = const Value.absent(),
                Value<int?> installmentIndex = const Value.absent(),
                Value<int?> installmentCount = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletTransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                kind: kind,
                categoryId: categoryId,
                category: category,
                amountCents: amountCents,
                occurredAt: occurredAt,
                statementMonth: statementMonth,
                note: note,
                createdBy: createdBy,
                installmentGroup: installmentGroup,
                installmentIndex: installmentIndex,
                installmentCount: installmentCount,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletTransactionsTable,
      WalletTransactionRow,
      $$WalletTransactionsTableFilterComposer,
      $$WalletTransactionsTableOrderingComposer,
      $$WalletTransactionsTableAnnotationComposer,
      $$WalletTransactionsTableCreateCompanionBuilder,
      $$WalletTransactionsTableUpdateCompanionBuilder,
      (
        WalletTransactionRow,
        BaseReferences<
          _$AppDatabase,
          $WalletTransactionsTable,
          WalletTransactionRow
        >,
      ),
      WalletTransactionRow,
      PrefetchHooks Function()
    >;
typedef $$WalletTransfersTableCreateCompanionBuilder =
    WalletTransfersCompanion Function({
      required String id,
      required String fromAccountId,
      required String toAccountId,
      required int amountCents,
      required DateTime occurredAt,
      Value<String?> note,
      required int createdBy,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$WalletTransfersTableUpdateCompanionBuilder =
    WalletTransfersCompanion Function({
      Value<String> id,
      Value<String> fromAccountId,
      Value<String> toAccountId,
      Value<int> amountCents,
      Value<DateTime> occurredAt,
      Value<String?> note,
      Value<int> createdBy,
      Value<int> version,
      Value<int> rowid,
    });

class $$WalletTransfersTableFilterComposer
    extends Composer<_$AppDatabase, $WalletTransfersTable> {
  $$WalletTransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromAccountId => $composableBuilder(
    column: $table.fromAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletTransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletTransfersTable> {
  $$WalletTransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromAccountId => $composableBuilder(
    column: $table.fromAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletTransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletTransfersTable> {
  $$WalletTransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fromAccountId => $composableBuilder(
    column: $table.fromAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$WalletTransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletTransfersTable,
          WalletTransferRow,
          $$WalletTransfersTableFilterComposer,
          $$WalletTransfersTableOrderingComposer,
          $$WalletTransfersTableAnnotationComposer,
          $$WalletTransfersTableCreateCompanionBuilder,
          $$WalletTransfersTableUpdateCompanionBuilder,
          (
            WalletTransferRow,
            BaseReferences<
              _$AppDatabase,
              $WalletTransfersTable,
              WalletTransferRow
            >,
          ),
          WalletTransferRow,
          PrefetchHooks Function()
        > {
  $$WalletTransfersTableTableManager(
    _$AppDatabase db,
    $WalletTransfersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletTransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletTransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletTransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fromAccountId = const Value.absent(),
                Value<String> toAccountId = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletTransfersCompanion(
                id: id,
                fromAccountId: fromAccountId,
                toAccountId: toAccountId,
                amountCents: amountCents,
                occurredAt: occurredAt,
                note: note,
                createdBy: createdBy,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fromAccountId,
                required String toAccountId,
                required int amountCents,
                required DateTime occurredAt,
                Value<String?> note = const Value.absent(),
                required int createdBy,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletTransfersCompanion.insert(
                id: id,
                fromAccountId: fromAccountId,
                toAccountId: toAccountId,
                amountCents: amountCents,
                occurredAt: occurredAt,
                note: note,
                createdBy: createdBy,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletTransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletTransfersTable,
      WalletTransferRow,
      $$WalletTransfersTableFilterComposer,
      $$WalletTransfersTableOrderingComposer,
      $$WalletTransfersTableAnnotationComposer,
      $$WalletTransfersTableCreateCompanionBuilder,
      $$WalletTransfersTableUpdateCompanionBuilder,
      (
        WalletTransferRow,
        BaseReferences<_$AppDatabase, $WalletTransfersTable, WalletTransferRow>,
      ),
      WalletTransferRow,
      PrefetchHooks Function()
    >;
typedef $$WalletStatementMarksTableCreateCompanionBuilder =
    WalletStatementMarksCompanion Function({
      required String id,
      required String accountId,
      required DateTime month,
      required bool paid,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$WalletStatementMarksTableUpdateCompanionBuilder =
    WalletStatementMarksCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<DateTime> month,
      Value<bool> paid,
      Value<int> version,
      Value<int> rowid,
    });

class $$WalletStatementMarksTableFilterComposer
    extends Composer<_$AppDatabase, $WalletStatementMarksTable> {
  $$WalletStatementMarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletStatementMarksTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletStatementMarksTable> {
  $$WalletStatementMarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletStatementMarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletStatementMarksTable> {
  $$WalletStatementMarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<DateTime> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<bool> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$WalletStatementMarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletStatementMarksTable,
          WalletMarkRow,
          $$WalletStatementMarksTableFilterComposer,
          $$WalletStatementMarksTableOrderingComposer,
          $$WalletStatementMarksTableAnnotationComposer,
          $$WalletStatementMarksTableCreateCompanionBuilder,
          $$WalletStatementMarksTableUpdateCompanionBuilder,
          (
            WalletMarkRow,
            BaseReferences<
              _$AppDatabase,
              $WalletStatementMarksTable,
              WalletMarkRow
            >,
          ),
          WalletMarkRow,
          PrefetchHooks Function()
        > {
  $$WalletStatementMarksTableTableManager(
    _$AppDatabase db,
    $WalletStatementMarksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletStatementMarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletStatementMarksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WalletStatementMarksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<DateTime> month = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletStatementMarksCompanion(
                id: id,
                accountId: accountId,
                month: month,
                paid: paid,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required DateTime month,
                required bool paid,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletStatementMarksCompanion.insert(
                id: id,
                accountId: accountId,
                month: month,
                paid: paid,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletStatementMarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletStatementMarksTable,
      WalletMarkRow,
      $$WalletStatementMarksTableFilterComposer,
      $$WalletStatementMarksTableOrderingComposer,
      $$WalletStatementMarksTableAnnotationComposer,
      $$WalletStatementMarksTableCreateCompanionBuilder,
      $$WalletStatementMarksTableUpdateCompanionBuilder,
      (
        WalletMarkRow,
        BaseReferences<
          _$AppDatabase,
          $WalletStatementMarksTable,
          WalletMarkRow
        >,
      ),
      WalletMarkRow,
      PrefetchHooks Function()
    >;
typedef $$WalletScheduledPaymentsTableCreateCompanionBuilder =
    WalletScheduledPaymentsCompanion Function({
      required String id,
      required String title,
      required String kind,
      required String accountId,
      Value<String?> toAccountId,
      Value<int?> categoryId,
      required int amountCents,
      required DateTime dueAt,
      Value<bool> repeatMonthly,
      Value<bool> completed,
      Value<DateTime?> lastPaidAt,
      required int createdBy,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$WalletScheduledPaymentsTableUpdateCompanionBuilder =
    WalletScheduledPaymentsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> kind,
      Value<String> accountId,
      Value<String?> toAccountId,
      Value<int?> categoryId,
      Value<int> amountCents,
      Value<DateTime> dueAt,
      Value<bool> repeatMonthly,
      Value<bool> completed,
      Value<DateTime?> lastPaidAt,
      Value<int> createdBy,
      Value<int> version,
      Value<int> rowid,
    });

class $$WalletScheduledPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $WalletScheduledPaymentsTable> {
  $$WalletScheduledPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get repeatMonthly => $composableBuilder(
    column: $table.repeatMonthly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletScheduledPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletScheduledPaymentsTable> {
  $$WalletScheduledPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueAt => $composableBuilder(
    column: $table.dueAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get repeatMonthly => $composableBuilder(
    column: $table.repeatMonthly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletScheduledPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletScheduledPaymentsTable> {
  $$WalletScheduledPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get toAccountId => $composableBuilder(
    column: $table.toAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueAt =>
      $composableBuilder(column: $table.dueAt, builder: (column) => column);

  GeneratedColumn<bool> get repeatMonthly => $composableBuilder(
    column: $table.repeatMonthly,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPaidAt => $composableBuilder(
    column: $table.lastPaidAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$WalletScheduledPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletScheduledPaymentsTable,
          WalletPaymentRow,
          $$WalletScheduledPaymentsTableFilterComposer,
          $$WalletScheduledPaymentsTableOrderingComposer,
          $$WalletScheduledPaymentsTableAnnotationComposer,
          $$WalletScheduledPaymentsTableCreateCompanionBuilder,
          $$WalletScheduledPaymentsTableUpdateCompanionBuilder,
          (
            WalletPaymentRow,
            BaseReferences<
              _$AppDatabase,
              $WalletScheduledPaymentsTable,
              WalletPaymentRow
            >,
          ),
          WalletPaymentRow,
          PrefetchHooks Function()
        > {
  $$WalletScheduledPaymentsTableTableManager(
    _$AppDatabase db,
    $WalletScheduledPaymentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletScheduledPaymentsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$WalletScheduledPaymentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$WalletScheduledPaymentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> toAccountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> dueAt = const Value.absent(),
                Value<bool> repeatMonthly = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> lastPaidAt = const Value.absent(),
                Value<int> createdBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletScheduledPaymentsCompanion(
                id: id,
                title: title,
                kind: kind,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                amountCents: amountCents,
                dueAt: dueAt,
                repeatMonthly: repeatMonthly,
                completed: completed,
                lastPaidAt: lastPaidAt,
                createdBy: createdBy,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String kind,
                required String accountId,
                Value<String?> toAccountId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                required int amountCents,
                required DateTime dueAt,
                Value<bool> repeatMonthly = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<DateTime?> lastPaidAt = const Value.absent(),
                required int createdBy,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletScheduledPaymentsCompanion.insert(
                id: id,
                title: title,
                kind: kind,
                accountId: accountId,
                toAccountId: toAccountId,
                categoryId: categoryId,
                amountCents: amountCents,
                dueAt: dueAt,
                repeatMonthly: repeatMonthly,
                completed: completed,
                lastPaidAt: lastPaidAt,
                createdBy: createdBy,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletScheduledPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletScheduledPaymentsTable,
      WalletPaymentRow,
      $$WalletScheduledPaymentsTableFilterComposer,
      $$WalletScheduledPaymentsTableOrderingComposer,
      $$WalletScheduledPaymentsTableAnnotationComposer,
      $$WalletScheduledPaymentsTableCreateCompanionBuilder,
      $$WalletScheduledPaymentsTableUpdateCompanionBuilder,
      (
        WalletPaymentRow,
        BaseReferences<
          _$AppDatabase,
          $WalletScheduledPaymentsTable,
          WalletPaymentRow
        >,
      ),
      WalletPaymentRow,
      PrefetchHooks Function()
    >;
typedef $$WalletOutboxTableCreateCompanionBuilder =
    WalletOutboxCompanion Function({
      required String requestId,
      required int seq,
      required String operationKey,
      required String payload,
      required String accountKeys,
      Value<String> state,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<String?> detail,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$WalletOutboxTableUpdateCompanionBuilder =
    WalletOutboxCompanion Function({
      Value<String> requestId,
      Value<int> seq,
      Value<String> operationKey,
      Value<String> payload,
      Value<String> accountKeys,
      Value<String> state,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<String?> detail,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$WalletOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $WalletOutboxTable> {
  $$WalletOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountKeys => $composableBuilder(
    column: $table.accountKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WalletOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $WalletOutboxTable> {
  $$WalletOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get requestId => $composableBuilder(
    column: $table.requestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountKeys => $composableBuilder(
    column: $table.accountKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WalletOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $WalletOutboxTable> {
  $$WalletOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get requestId =>
      $composableBuilder(column: $table.requestId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get operationKey => $composableBuilder(
    column: $table.operationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get accountKeys => $composableBuilder(
    column: $table.accountKeys,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WalletOutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WalletOutboxTable,
          WalletOutboxRow,
          $$WalletOutboxTableFilterComposer,
          $$WalletOutboxTableOrderingComposer,
          $$WalletOutboxTableAnnotationComposer,
          $$WalletOutboxTableCreateCompanionBuilder,
          $$WalletOutboxTableUpdateCompanionBuilder,
          (
            WalletOutboxRow,
            BaseReferences<_$AppDatabase, $WalletOutboxTable, WalletOutboxRow>,
          ),
          WalletOutboxRow,
          PrefetchHooks Function()
        > {
  $$WalletOutboxTableTableManager(_$AppDatabase db, $WalletOutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WalletOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WalletOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WalletOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> requestId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> operationKey = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> accountKeys = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WalletOutboxCompanion(
                requestId: requestId,
                seq: seq,
                operationKey: operationKey,
                payload: payload,
                accountKeys: accountKeys,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                detail: detail,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String requestId,
                required int seq,
                required String operationKey,
                required String payload,
                required String accountKeys,
                Value<String> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => WalletOutboxCompanion.insert(
                requestId: requestId,
                seq: seq,
                operationKey: operationKey,
                payload: payload,
                accountKeys: accountKeys,
                state: state,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                detail: detail,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WalletOutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WalletOutboxTable,
      WalletOutboxRow,
      $$WalletOutboxTableFilterComposer,
      $$WalletOutboxTableOrderingComposer,
      $$WalletOutboxTableAnnotationComposer,
      $$WalletOutboxTableCreateCompanionBuilder,
      $$WalletOutboxTableUpdateCompanionBuilder,
      (
        WalletOutboxRow,
        BaseReferences<_$AppDatabase, $WalletOutboxTable, WalletOutboxRow>,
      ),
      WalletOutboxRow,
      PrefetchHooks Function()
    >;
typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String id,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> title,
      Value<String> body,
      Value<String> kind,
      Value<bool> pinned,
      Value<int?> color,
      Value<String?> eventId,
      Value<bool> archived,
      Value<String> space,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> id,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> title,
      Value<String> body,
      Value<String> kind,
      Value<bool> pinned,
      Value<int?> color,
      Value<String?> eventId,
      Value<bool> archived,
      Value<String> space,
      Value<int> rowid,
    });

class $$LocalNotesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get space => $composableBuilder(
    column: $table.space,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinned => $composableBuilder(
    column: $table.pinned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get space => $composableBuilder(
    column: $table.space,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get space =>
      $composableBuilder(column: $table.space, builder: (column) => column);
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (
            LocalNote,
            BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>,
          ),
          LocalNote,
          PrefetchHooks Function()
        > {
  $$LocalNotesTableTableManager(_$AppDatabase db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> space = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                title: title,
                body: body,
                kind: kind,
                pinned: pinned,
                color: color,
                eventId: eventId,
                archived: archived,
                space: space,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<bool> pinned = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String> space = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                title: title,
                body: body,
                kind: kind,
                pinned: pinned,
                color: color,
                eventId: eventId,
                archived: archived,
                space: space,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, BaseReferences<_$AppDatabase, $LocalNotesTable, LocalNote>),
      LocalNote,
      PrefetchHooks Function()
    >;
typedef $$LocalNoteItemsTableCreateCompanionBuilder =
    LocalNoteItemsCompanion Function({
      required String id,
      required int updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      required String noteId,
      Value<String> content,
      Value<bool> done,
      Value<double> position,
      Value<int?> doneBy,
      Value<String> space,
      Value<int> rowid,
    });
typedef $$LocalNoteItemsTableUpdateCompanionBuilder =
    LocalNoteItemsCompanion Function({
      Value<String> id,
      Value<int> updatedAtMs,
      Value<int?> deletedAtMs,
      Value<bool> dirty,
      Value<String> noteId,
      Value<String> content,
      Value<bool> done,
      Value<double> position,
      Value<int?> doneBy,
      Value<String> space,
      Value<int> rowid,
    });

class $$LocalNoteItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalNoteItemsTable> {
  $$LocalNoteItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneBy => $composableBuilder(
    column: $table.doneBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get space => $composableBuilder(
    column: $table.space,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalNoteItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalNoteItemsTable> {
  $$LocalNoteItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noteId => $composableBuilder(
    column: $table.noteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneBy => $composableBuilder(
    column: $table.doneBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get space => $composableBuilder(
    column: $table.space,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalNoteItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalNoteItemsTable> {
  $$LocalNoteItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtMs => $composableBuilder(
    column: $table.deletedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get noteId =>
      $composableBuilder(column: $table.noteId, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<double> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get doneBy =>
      $composableBuilder(column: $table.doneBy, builder: (column) => column);

  GeneratedColumn<String> get space =>
      $composableBuilder(column: $table.space, builder: (column) => column);
}

class $$LocalNoteItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalNoteItemsTable,
          LocalNoteItem,
          $$LocalNoteItemsTableFilterComposer,
          $$LocalNoteItemsTableOrderingComposer,
          $$LocalNoteItemsTableAnnotationComposer,
          $$LocalNoteItemsTableCreateCompanionBuilder,
          $$LocalNoteItemsTableUpdateCompanionBuilder,
          (
            LocalNoteItem,
            BaseReferences<_$AppDatabase, $LocalNoteItemsTable, LocalNoteItem>,
          ),
          LocalNoteItem,
          PrefetchHooks Function()
        > {
  $$LocalNoteItemsTableTableManager(
    _$AppDatabase db,
    $LocalNoteItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNoteItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNoteItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNoteItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<int?> doneBy = const Value.absent(),
                Value<String> space = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNoteItemsCompanion(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                noteId: noteId,
                content: content,
                done: done,
                position: position,
                doneBy: doneBy,
                space: space,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int updatedAtMs,
                Value<int?> deletedAtMs = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String noteId,
                Value<String> content = const Value.absent(),
                Value<bool> done = const Value.absent(),
                Value<double> position = const Value.absent(),
                Value<int?> doneBy = const Value.absent(),
                Value<String> space = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNoteItemsCompanion.insert(
                id: id,
                updatedAtMs: updatedAtMs,
                deletedAtMs: deletedAtMs,
                dirty: dirty,
                noteId: noteId,
                content: content,
                done: done,
                position: position,
                doneBy: doneBy,
                space: space,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalNoteItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalNoteItemsTable,
      LocalNoteItem,
      $$LocalNoteItemsTableFilterComposer,
      $$LocalNoteItemsTableOrderingComposer,
      $$LocalNoteItemsTableAnnotationComposer,
      $$LocalNoteItemsTableCreateCompanionBuilder,
      $$LocalNoteItemsTableUpdateCompanionBuilder,
      (
        LocalNoteItem,
        BaseReferences<_$AppDatabase, $LocalNoteItemsTable, LocalNoteItem>,
      ),
      LocalNoteItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedDocumentsTableTableManager get cachedDocuments =>
      $$CachedDocumentsTableTableManager(_db, _db.cachedDocuments);
  $$QueuedOperationsTableTableManager get queuedOperations =>
      $$QueuedOperationsTableTableManager(_db, _db.queuedOperations);
  $$LocalEventsTableTableManager get localEvents =>
      $$LocalEventsTableTableManager(_db, _db.localEvents);
  $$LocalMedicationsTableTableManager get localMedications =>
      $$LocalMedicationsTableTableManager(_db, _db.localMedications);
  $$LocalDoseLogsTableTableManager get localDoseLogs =>
      $$LocalDoseLogsTableTableManager(_db, _db.localDoseLogs);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$WalletAccountsTableTableManager get walletAccounts =>
      $$WalletAccountsTableTableManager(_db, _db.walletAccounts);
  $$WalletTransactionsTableTableManager get walletTransactions =>
      $$WalletTransactionsTableTableManager(_db, _db.walletTransactions);
  $$WalletTransfersTableTableManager get walletTransfers =>
      $$WalletTransfersTableTableManager(_db, _db.walletTransfers);
  $$WalletStatementMarksTableTableManager get walletStatementMarks =>
      $$WalletStatementMarksTableTableManager(_db, _db.walletStatementMarks);
  $$WalletScheduledPaymentsTableTableManager get walletScheduledPayments =>
      $$WalletScheduledPaymentsTableTableManager(
        _db,
        _db.walletScheduledPayments,
      );
  $$WalletOutboxTableTableManager get walletOutbox =>
      $$WalletOutboxTableTableManager(_db, _db.walletOutbox);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$LocalNoteItemsTableTableManager get localNoteItems =>
      $$LocalNoteItemsTableTableManager(_db, _db.localNoteItems);
}
