// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CreationsTable extends Creations
    with TableInfo<$CreationsTable, Creation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CreationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Untitled'),
  );
  static const VerificationMeta _gridSizeMeta = const VerificationMeta(
    'gridSize',
  );
  @override
  late final GeneratedColumn<int> gridSize = GeneratedColumn<int>(
    'grid_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gridDataMeta = const VerificationMeta(
    'gridData',
  );
  @override
  late final GeneratedColumn<String> gridData = GeneratedColumn<String>(
    'grid_data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paletteNameMeta = const VerificationMeta(
    'paletteName',
  );
  @override
  late final GeneratedColumn<String> paletteName = GeneratedColumn<String>(
    'palette_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paletteColorsMeta = const VerificationMeta(
    'paletteColors',
  );
  @override
  late final GeneratedColumn<String> paletteColors = GeneratedColumn<String>(
    'palette_colors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decomposedComponentsMeta =
      const VerificationMeta('decomposedComponents');
  @override
  late final GeneratedColumn<String> decomposedComponents =
      GeneratedColumn<String>(
        'decomposed_components',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _aiHistoryLogsMeta = const VerificationMeta(
    'aiHistoryLogs',
  );
  @override
  late final GeneratedColumn<String> aiHistoryLogs = GeneratedColumn<String>(
    'ai_history_logs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceImageMeta = const VerificationMeta(
    'referenceImage',
  );
  @override
  late final GeneratedColumn<Uint8List> referenceImage =
      GeneratedColumn<Uint8List>(
        'reference_image',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _originalReferenceImageMeta =
      const VerificationMeta('originalReferenceImage');
  @override
  late final GeneratedColumn<Uint8List> originalReferenceImage =
      GeneratedColumn<Uint8List>(
        'original_reference_image',
        aliasedName,
        true,
        type: DriftSqlType.blob,
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
  List<GeneratedColumn> get $columns => [
    id,
    title,
    gridSize,
    gridData,
    paletteName,
    paletteColors,
    decomposedComponents,
    aiHistoryLogs,
    referenceImage,
    originalReferenceImage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'creations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Creation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('grid_size')) {
      context.handle(
        _gridSizeMeta,
        gridSize.isAcceptableOrUnknown(data['grid_size']!, _gridSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_gridSizeMeta);
    }
    if (data.containsKey('grid_data')) {
      context.handle(
        _gridDataMeta,
        gridData.isAcceptableOrUnknown(data['grid_data']!, _gridDataMeta),
      );
    } else if (isInserting) {
      context.missing(_gridDataMeta);
    }
    if (data.containsKey('palette_name')) {
      context.handle(
        _paletteNameMeta,
        paletteName.isAcceptableOrUnknown(
          data['palette_name']!,
          _paletteNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paletteNameMeta);
    }
    if (data.containsKey('palette_colors')) {
      context.handle(
        _paletteColorsMeta,
        paletteColors.isAcceptableOrUnknown(
          data['palette_colors']!,
          _paletteColorsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paletteColorsMeta);
    }
    if (data.containsKey('decomposed_components')) {
      context.handle(
        _decomposedComponentsMeta,
        decomposedComponents.isAcceptableOrUnknown(
          data['decomposed_components']!,
          _decomposedComponentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_decomposedComponentsMeta);
    }
    if (data.containsKey('ai_history_logs')) {
      context.handle(
        _aiHistoryLogsMeta,
        aiHistoryLogs.isAcceptableOrUnknown(
          data['ai_history_logs']!,
          _aiHistoryLogsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aiHistoryLogsMeta);
    }
    if (data.containsKey('reference_image')) {
      context.handle(
        _referenceImageMeta,
        referenceImage.isAcceptableOrUnknown(
          data['reference_image']!,
          _referenceImageMeta,
        ),
      );
    }
    if (data.containsKey('original_reference_image')) {
      context.handle(
        _originalReferenceImageMeta,
        originalReferenceImage.isAcceptableOrUnknown(
          data['original_reference_image']!,
          _originalReferenceImageMeta,
        ),
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Creation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Creation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      gridSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}grid_size'],
      )!,
      gridData: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}grid_data'],
      )!,
      paletteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}palette_name'],
      )!,
      paletteColors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}palette_colors'],
      )!,
      decomposedComponents: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}decomposed_components'],
      )!,
      aiHistoryLogs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ai_history_logs'],
      )!,
      referenceImage: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}reference_image'],
      ),
      originalReferenceImage: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}original_reference_image'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CreationsTable createAlias(String alias) {
    return $CreationsTable(attachedDatabase, alias);
  }
}

class Creation extends DataClass implements Insertable<Creation> {
  final int id;
  final String title;
  final int gridSize;
  final String gridData;
  final String paletteName;
  final String paletteColors;
  final String decomposedComponents;
  final String aiHistoryLogs;
  final Uint8List? referenceImage;
  final Uint8List? originalReferenceImage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Creation({
    required this.id,
    required this.title,
    required this.gridSize,
    required this.gridData,
    required this.paletteName,
    required this.paletteColors,
    required this.decomposedComponents,
    required this.aiHistoryLogs,
    this.referenceImage,
    this.originalReferenceImage,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['grid_size'] = Variable<int>(gridSize);
    map['grid_data'] = Variable<String>(gridData);
    map['palette_name'] = Variable<String>(paletteName);
    map['palette_colors'] = Variable<String>(paletteColors);
    map['decomposed_components'] = Variable<String>(decomposedComponents);
    map['ai_history_logs'] = Variable<String>(aiHistoryLogs);
    if (!nullToAbsent || referenceImage != null) {
      map['reference_image'] = Variable<Uint8List>(referenceImage);
    }
    if (!nullToAbsent || originalReferenceImage != null) {
      map['original_reference_image'] = Variable<Uint8List>(
        originalReferenceImage,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CreationsCompanion toCompanion(bool nullToAbsent) {
    return CreationsCompanion(
      id: Value(id),
      title: Value(title),
      gridSize: Value(gridSize),
      gridData: Value(gridData),
      paletteName: Value(paletteName),
      paletteColors: Value(paletteColors),
      decomposedComponents: Value(decomposedComponents),
      aiHistoryLogs: Value(aiHistoryLogs),
      referenceImage: referenceImage == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceImage),
      originalReferenceImage: originalReferenceImage == null && nullToAbsent
          ? const Value.absent()
          : Value(originalReferenceImage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Creation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Creation(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      gridSize: serializer.fromJson<int>(json['gridSize']),
      gridData: serializer.fromJson<String>(json['gridData']),
      paletteName: serializer.fromJson<String>(json['paletteName']),
      paletteColors: serializer.fromJson<String>(json['paletteColors']),
      decomposedComponents: serializer.fromJson<String>(
        json['decomposedComponents'],
      ),
      aiHistoryLogs: serializer.fromJson<String>(json['aiHistoryLogs']),
      referenceImage: serializer.fromJson<Uint8List?>(json['referenceImage']),
      originalReferenceImage: serializer.fromJson<Uint8List?>(
        json['originalReferenceImage'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'gridSize': serializer.toJson<int>(gridSize),
      'gridData': serializer.toJson<String>(gridData),
      'paletteName': serializer.toJson<String>(paletteName),
      'paletteColors': serializer.toJson<String>(paletteColors),
      'decomposedComponents': serializer.toJson<String>(decomposedComponents),
      'aiHistoryLogs': serializer.toJson<String>(aiHistoryLogs),
      'referenceImage': serializer.toJson<Uint8List?>(referenceImage),
      'originalReferenceImage': serializer.toJson<Uint8List?>(
        originalReferenceImage,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Creation copyWith({
    int? id,
    String? title,
    int? gridSize,
    String? gridData,
    String? paletteName,
    String? paletteColors,
    String? decomposedComponents,
    String? aiHistoryLogs,
    Value<Uint8List?> referenceImage = const Value.absent(),
    Value<Uint8List?> originalReferenceImage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Creation(
    id: id ?? this.id,
    title: title ?? this.title,
    gridSize: gridSize ?? this.gridSize,
    gridData: gridData ?? this.gridData,
    paletteName: paletteName ?? this.paletteName,
    paletteColors: paletteColors ?? this.paletteColors,
    decomposedComponents: decomposedComponents ?? this.decomposedComponents,
    aiHistoryLogs: aiHistoryLogs ?? this.aiHistoryLogs,
    referenceImage: referenceImage.present
        ? referenceImage.value
        : this.referenceImage,
    originalReferenceImage: originalReferenceImage.present
        ? originalReferenceImage.value
        : this.originalReferenceImage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Creation copyWithCompanion(CreationsCompanion data) {
    return Creation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      gridSize: data.gridSize.present ? data.gridSize.value : this.gridSize,
      gridData: data.gridData.present ? data.gridData.value : this.gridData,
      paletteName: data.paletteName.present
          ? data.paletteName.value
          : this.paletteName,
      paletteColors: data.paletteColors.present
          ? data.paletteColors.value
          : this.paletteColors,
      decomposedComponents: data.decomposedComponents.present
          ? data.decomposedComponents.value
          : this.decomposedComponents,
      aiHistoryLogs: data.aiHistoryLogs.present
          ? data.aiHistoryLogs.value
          : this.aiHistoryLogs,
      referenceImage: data.referenceImage.present
          ? data.referenceImage.value
          : this.referenceImage,
      originalReferenceImage: data.originalReferenceImage.present
          ? data.originalReferenceImage.value
          : this.originalReferenceImage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Creation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('gridSize: $gridSize, ')
          ..write('gridData: $gridData, ')
          ..write('paletteName: $paletteName, ')
          ..write('paletteColors: $paletteColors, ')
          ..write('decomposedComponents: $decomposedComponents, ')
          ..write('aiHistoryLogs: $aiHistoryLogs, ')
          ..write('referenceImage: $referenceImage, ')
          ..write('originalReferenceImage: $originalReferenceImage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    gridSize,
    gridData,
    paletteName,
    paletteColors,
    decomposedComponents,
    aiHistoryLogs,
    $driftBlobEquality.hash(referenceImage),
    $driftBlobEquality.hash(originalReferenceImage),
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Creation &&
          other.id == this.id &&
          other.title == this.title &&
          other.gridSize == this.gridSize &&
          other.gridData == this.gridData &&
          other.paletteName == this.paletteName &&
          other.paletteColors == this.paletteColors &&
          other.decomposedComponents == this.decomposedComponents &&
          other.aiHistoryLogs == this.aiHistoryLogs &&
          $driftBlobEquality.equals(
            other.referenceImage,
            this.referenceImage,
          ) &&
          $driftBlobEquality.equals(
            other.originalReferenceImage,
            this.originalReferenceImage,
          ) &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CreationsCompanion extends UpdateCompanion<Creation> {
  final Value<int> id;
  final Value<String> title;
  final Value<int> gridSize;
  final Value<String> gridData;
  final Value<String> paletteName;
  final Value<String> paletteColors;
  final Value<String> decomposedComponents;
  final Value<String> aiHistoryLogs;
  final Value<Uint8List?> referenceImage;
  final Value<Uint8List?> originalReferenceImage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const CreationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.gridSize = const Value.absent(),
    this.gridData = const Value.absent(),
    this.paletteName = const Value.absent(),
    this.paletteColors = const Value.absent(),
    this.decomposedComponents = const Value.absent(),
    this.aiHistoryLogs = const Value.absent(),
    this.referenceImage = const Value.absent(),
    this.originalReferenceImage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CreationsCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    required int gridSize,
    required String gridData,
    required String paletteName,
    required String paletteColors,
    required String decomposedComponents,
    required String aiHistoryLogs,
    this.referenceImage = const Value.absent(),
    this.originalReferenceImage = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : gridSize = Value(gridSize),
       gridData = Value(gridData),
       paletteName = Value(paletteName),
       paletteColors = Value(paletteColors),
       decomposedComponents = Value(decomposedComponents),
       aiHistoryLogs = Value(aiHistoryLogs),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Creation> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? gridSize,
    Expression<String>? gridData,
    Expression<String>? paletteName,
    Expression<String>? paletteColors,
    Expression<String>? decomposedComponents,
    Expression<String>? aiHistoryLogs,
    Expression<Uint8List>? referenceImage,
    Expression<Uint8List>? originalReferenceImage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (gridSize != null) 'grid_size': gridSize,
      if (gridData != null) 'grid_data': gridData,
      if (paletteName != null) 'palette_name': paletteName,
      if (paletteColors != null) 'palette_colors': paletteColors,
      if (decomposedComponents != null)
        'decomposed_components': decomposedComponents,
      if (aiHistoryLogs != null) 'ai_history_logs': aiHistoryLogs,
      if (referenceImage != null) 'reference_image': referenceImage,
      if (originalReferenceImage != null)
        'original_reference_image': originalReferenceImage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CreationsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int>? gridSize,
    Value<String>? gridData,
    Value<String>? paletteName,
    Value<String>? paletteColors,
    Value<String>? decomposedComponents,
    Value<String>? aiHistoryLogs,
    Value<Uint8List?>? referenceImage,
    Value<Uint8List?>? originalReferenceImage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return CreationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      gridSize: gridSize ?? this.gridSize,
      gridData: gridData ?? this.gridData,
      paletteName: paletteName ?? this.paletteName,
      paletteColors: paletteColors ?? this.paletteColors,
      decomposedComponents: decomposedComponents ?? this.decomposedComponents,
      aiHistoryLogs: aiHistoryLogs ?? this.aiHistoryLogs,
      referenceImage: referenceImage ?? this.referenceImage,
      originalReferenceImage:
          originalReferenceImage ?? this.originalReferenceImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (gridSize.present) {
      map['grid_size'] = Variable<int>(gridSize.value);
    }
    if (gridData.present) {
      map['grid_data'] = Variable<String>(gridData.value);
    }
    if (paletteName.present) {
      map['palette_name'] = Variable<String>(paletteName.value);
    }
    if (paletteColors.present) {
      map['palette_colors'] = Variable<String>(paletteColors.value);
    }
    if (decomposedComponents.present) {
      map['decomposed_components'] = Variable<String>(
        decomposedComponents.value,
      );
    }
    if (aiHistoryLogs.present) {
      map['ai_history_logs'] = Variable<String>(aiHistoryLogs.value);
    }
    if (referenceImage.present) {
      map['reference_image'] = Variable<Uint8List>(referenceImage.value);
    }
    if (originalReferenceImage.present) {
      map['original_reference_image'] = Variable<Uint8List>(
        originalReferenceImage.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CreationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('gridSize: $gridSize, ')
          ..write('gridData: $gridData, ')
          ..write('paletteName: $paletteName, ')
          ..write('paletteColors: $paletteColors, ')
          ..write('decomposedComponents: $decomposedComponents, ')
          ..write('aiHistoryLogs: $aiHistoryLogs, ')
          ..write('referenceImage: $referenceImage, ')
          ..write('originalReferenceImage: $originalReferenceImage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $WorkspaceSessionsTable extends WorkspaceSessions
    with TableInfo<$WorkspaceSessionsTable, WorkspaceSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkspaceSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'DEFAULT 1 CHECK (id = 1) NOT NULL',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _activeCreationIdMeta = const VerificationMeta(
    'activeCreationId',
  );
  @override
  late final GeneratedColumn<int> activeCreationId = GeneratedColumn<int>(
    'active_creation_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES creations (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _selectedColorIndexMeta =
      const VerificationMeta('selectedColorIndex');
  @override
  late final GeneratedColumn<int> selectedColorIndex = GeneratedColumn<int>(
    'selected_color_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _selectedToolMeta = const VerificationMeta(
    'selectedTool',
  );
  @override
  late final GeneratedColumn<String> selectedTool = GeneratedColumn<String>(
    'selected_tool',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('line'),
  );
  static const VerificationMeta _userPromptMeta = const VerificationMeta(
    'userPrompt',
  );
  @override
  late final GeneratedColumn<String> userPrompt = GeneratedColumn<String>(
    'user_prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastSavedAtMeta = const VerificationMeta(
    'lastSavedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSavedAt = GeneratedColumn<DateTime>(
    'last_saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    activeCreationId,
    selectedColorIndex,
    selectedTool,
    userPrompt,
    lastSavedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workspace_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkspaceSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('active_creation_id')) {
      context.handle(
        _activeCreationIdMeta,
        activeCreationId.isAcceptableOrUnknown(
          data['active_creation_id']!,
          _activeCreationIdMeta,
        ),
      );
    }
    if (data.containsKey('selected_color_index')) {
      context.handle(
        _selectedColorIndexMeta,
        selectedColorIndex.isAcceptableOrUnknown(
          data['selected_color_index']!,
          _selectedColorIndexMeta,
        ),
      );
    }
    if (data.containsKey('selected_tool')) {
      context.handle(
        _selectedToolMeta,
        selectedTool.isAcceptableOrUnknown(
          data['selected_tool']!,
          _selectedToolMeta,
        ),
      );
    }
    if (data.containsKey('user_prompt')) {
      context.handle(
        _userPromptMeta,
        userPrompt.isAcceptableOrUnknown(data['user_prompt']!, _userPromptMeta),
      );
    }
    if (data.containsKey('last_saved_at')) {
      context.handle(
        _lastSavedAtMeta,
        lastSavedAt.isAcceptableOrUnknown(
          data['last_saved_at']!,
          _lastSavedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSavedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkspaceSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkspaceSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      activeCreationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_creation_id'],
      ),
      selectedColorIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}selected_color_index'],
      )!,
      selectedTool: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_tool'],
      )!,
      userPrompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_prompt'],
      )!,
      lastSavedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_saved_at'],
      )!,
    );
  }

  @override
  $WorkspaceSessionsTable createAlias(String alias) {
    return $WorkspaceSessionsTable(attachedDatabase, alias);
  }
}

class WorkspaceSession extends DataClass
    implements Insertable<WorkspaceSession> {
  final int id;
  final int? activeCreationId;
  final int selectedColorIndex;
  final String selectedTool;
  final String userPrompt;
  final DateTime lastSavedAt;
  const WorkspaceSession({
    required this.id,
    this.activeCreationId,
    required this.selectedColorIndex,
    required this.selectedTool,
    required this.userPrompt,
    required this.lastSavedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || activeCreationId != null) {
      map['active_creation_id'] = Variable<int>(activeCreationId);
    }
    map['selected_color_index'] = Variable<int>(selectedColorIndex);
    map['selected_tool'] = Variable<String>(selectedTool);
    map['user_prompt'] = Variable<String>(userPrompt);
    map['last_saved_at'] = Variable<DateTime>(lastSavedAt);
    return map;
  }

  WorkspaceSessionsCompanion toCompanion(bool nullToAbsent) {
    return WorkspaceSessionsCompanion(
      id: Value(id),
      activeCreationId: activeCreationId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeCreationId),
      selectedColorIndex: Value(selectedColorIndex),
      selectedTool: Value(selectedTool),
      userPrompt: Value(userPrompt),
      lastSavedAt: Value(lastSavedAt),
    );
  }

  factory WorkspaceSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkspaceSession(
      id: serializer.fromJson<int>(json['id']),
      activeCreationId: serializer.fromJson<int?>(json['activeCreationId']),
      selectedColorIndex: serializer.fromJson<int>(json['selectedColorIndex']),
      selectedTool: serializer.fromJson<String>(json['selectedTool']),
      userPrompt: serializer.fromJson<String>(json['userPrompt']),
      lastSavedAt: serializer.fromJson<DateTime>(json['lastSavedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'activeCreationId': serializer.toJson<int?>(activeCreationId),
      'selectedColorIndex': serializer.toJson<int>(selectedColorIndex),
      'selectedTool': serializer.toJson<String>(selectedTool),
      'userPrompt': serializer.toJson<String>(userPrompt),
      'lastSavedAt': serializer.toJson<DateTime>(lastSavedAt),
    };
  }

  WorkspaceSession copyWith({
    int? id,
    Value<int?> activeCreationId = const Value.absent(),
    int? selectedColorIndex,
    String? selectedTool,
    String? userPrompt,
    DateTime? lastSavedAt,
  }) => WorkspaceSession(
    id: id ?? this.id,
    activeCreationId: activeCreationId.present
        ? activeCreationId.value
        : this.activeCreationId,
    selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
    selectedTool: selectedTool ?? this.selectedTool,
    userPrompt: userPrompt ?? this.userPrompt,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
  );
  WorkspaceSession copyWithCompanion(WorkspaceSessionsCompanion data) {
    return WorkspaceSession(
      id: data.id.present ? data.id.value : this.id,
      activeCreationId: data.activeCreationId.present
          ? data.activeCreationId.value
          : this.activeCreationId,
      selectedColorIndex: data.selectedColorIndex.present
          ? data.selectedColorIndex.value
          : this.selectedColorIndex,
      selectedTool: data.selectedTool.present
          ? data.selectedTool.value
          : this.selectedTool,
      userPrompt: data.userPrompt.present
          ? data.userPrompt.value
          : this.userPrompt,
      lastSavedAt: data.lastSavedAt.present
          ? data.lastSavedAt.value
          : this.lastSavedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceSession(')
          ..write('id: $id, ')
          ..write('activeCreationId: $activeCreationId, ')
          ..write('selectedColorIndex: $selectedColorIndex, ')
          ..write('selectedTool: $selectedTool, ')
          ..write('userPrompt: $userPrompt, ')
          ..write('lastSavedAt: $lastSavedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    activeCreationId,
    selectedColorIndex,
    selectedTool,
    userPrompt,
    lastSavedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceSession &&
          other.id == this.id &&
          other.activeCreationId == this.activeCreationId &&
          other.selectedColorIndex == this.selectedColorIndex &&
          other.selectedTool == this.selectedTool &&
          other.userPrompt == this.userPrompt &&
          other.lastSavedAt == this.lastSavedAt);
}

class WorkspaceSessionsCompanion extends UpdateCompanion<WorkspaceSession> {
  final Value<int> id;
  final Value<int?> activeCreationId;
  final Value<int> selectedColorIndex;
  final Value<String> selectedTool;
  final Value<String> userPrompt;
  final Value<DateTime> lastSavedAt;
  const WorkspaceSessionsCompanion({
    this.id = const Value.absent(),
    this.activeCreationId = const Value.absent(),
    this.selectedColorIndex = const Value.absent(),
    this.selectedTool = const Value.absent(),
    this.userPrompt = const Value.absent(),
    this.lastSavedAt = const Value.absent(),
  });
  WorkspaceSessionsCompanion.insert({
    this.id = const Value.absent(),
    this.activeCreationId = const Value.absent(),
    this.selectedColorIndex = const Value.absent(),
    this.selectedTool = const Value.absent(),
    this.userPrompt = const Value.absent(),
    required DateTime lastSavedAt,
  }) : lastSavedAt = Value(lastSavedAt);
  static Insertable<WorkspaceSession> custom({
    Expression<int>? id,
    Expression<int>? activeCreationId,
    Expression<int>? selectedColorIndex,
    Expression<String>? selectedTool,
    Expression<String>? userPrompt,
    Expression<DateTime>? lastSavedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (activeCreationId != null) 'active_creation_id': activeCreationId,
      if (selectedColorIndex != null)
        'selected_color_index': selectedColorIndex,
      if (selectedTool != null) 'selected_tool': selectedTool,
      if (userPrompt != null) 'user_prompt': userPrompt,
      if (lastSavedAt != null) 'last_saved_at': lastSavedAt,
    });
  }

  WorkspaceSessionsCompanion copyWith({
    Value<int>? id,
    Value<int?>? activeCreationId,
    Value<int>? selectedColorIndex,
    Value<String>? selectedTool,
    Value<String>? userPrompt,
    Value<DateTime>? lastSavedAt,
  }) {
    return WorkspaceSessionsCompanion(
      id: id ?? this.id,
      activeCreationId: activeCreationId ?? this.activeCreationId,
      selectedColorIndex: selectedColorIndex ?? this.selectedColorIndex,
      selectedTool: selectedTool ?? this.selectedTool,
      userPrompt: userPrompt ?? this.userPrompt,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (activeCreationId.present) {
      map['active_creation_id'] = Variable<int>(activeCreationId.value);
    }
    if (selectedColorIndex.present) {
      map['selected_color_index'] = Variable<int>(selectedColorIndex.value);
    }
    if (selectedTool.present) {
      map['selected_tool'] = Variable<String>(selectedTool.value);
    }
    if (userPrompt.present) {
      map['user_prompt'] = Variable<String>(userPrompt.value);
    }
    if (lastSavedAt.present) {
      map['last_saved_at'] = Variable<DateTime>(lastSavedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkspaceSessionsCompanion(')
          ..write('id: $id, ')
          ..write('activeCreationId: $activeCreationId, ')
          ..write('selectedColorIndex: $selectedColorIndex, ')
          ..write('selectedTool: $selectedTool, ')
          ..write('userPrompt: $userPrompt, ')
          ..write('lastSavedAt: $lastSavedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CreationsTable creations = $CreationsTable(this);
  late final $WorkspaceSessionsTable workspaceSessions =
      $WorkspaceSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    creations,
    workspaceSessions,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'creations',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workspace_sessions', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$CreationsTableCreateCompanionBuilder =
    CreationsCompanion Function({
      Value<int> id,
      Value<String> title,
      required int gridSize,
      required String gridData,
      required String paletteName,
      required String paletteColors,
      required String decomposedComponents,
      required String aiHistoryLogs,
      Value<Uint8List?> referenceImage,
      Value<Uint8List?> originalReferenceImage,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$CreationsTableUpdateCompanionBuilder =
    CreationsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int> gridSize,
      Value<String> gridData,
      Value<String> paletteName,
      Value<String> paletteColors,
      Value<String> decomposedComponents,
      Value<String> aiHistoryLogs,
      Value<Uint8List?> referenceImage,
      Value<Uint8List?> originalReferenceImage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$CreationsTableReferences
    extends BaseReferences<_$AppDatabase, $CreationsTable, Creation> {
  $$CreationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$WorkspaceSessionsTable, List<WorkspaceSession>>
  _workspaceSessionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workspaceSessions,
        aliasName: 'creations__id__workspace_sessions__active_creation_id',
      );

  $$WorkspaceSessionsTableProcessedTableManager get workspaceSessionsRefs {
    final manager = $$WorkspaceSessionsTableTableManager(
      $_db,
      $_db.workspaceSessions,
    ).filter((f) => f.activeCreationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workspaceSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CreationsTableFilterComposer
    extends Composer<_$AppDatabase, $CreationsTable> {
  $$CreationsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gridSize => $composableBuilder(
    column: $table.gridSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gridData => $composableBuilder(
    column: $table.gridData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paletteName => $composableBuilder(
    column: $table.paletteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paletteColors => $composableBuilder(
    column: $table.paletteColors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get decomposedComponents => $composableBuilder(
    column: $table.decomposedComponents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aiHistoryLogs => $composableBuilder(
    column: $table.aiHistoryLogs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get referenceImage => $composableBuilder(
    column: $table.referenceImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get originalReferenceImage => $composableBuilder(
    column: $table.originalReferenceImage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workspaceSessionsRefs(
    Expression<bool> Function($$WorkspaceSessionsTableFilterComposer f) f,
  ) {
    final $$WorkspaceSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workspaceSessions,
      getReferencedColumn: (t) => t.activeCreationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkspaceSessionsTableFilterComposer(
            $db: $db,
            $table: $db.workspaceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CreationsTableOrderingComposer
    extends Composer<_$AppDatabase, $CreationsTable> {
  $$CreationsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gridSize => $composableBuilder(
    column: $table.gridSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gridData => $composableBuilder(
    column: $table.gridData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paletteName => $composableBuilder(
    column: $table.paletteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paletteColors => $composableBuilder(
    column: $table.paletteColors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get decomposedComponents => $composableBuilder(
    column: $table.decomposedComponents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aiHistoryLogs => $composableBuilder(
    column: $table.aiHistoryLogs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get referenceImage => $composableBuilder(
    column: $table.referenceImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get originalReferenceImage => $composableBuilder(
    column: $table.originalReferenceImage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CreationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CreationsTable> {
  $$CreationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get gridSize =>
      $composableBuilder(column: $table.gridSize, builder: (column) => column);

  GeneratedColumn<String> get gridData =>
      $composableBuilder(column: $table.gridData, builder: (column) => column);

  GeneratedColumn<String> get paletteName => $composableBuilder(
    column: $table.paletteName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paletteColors => $composableBuilder(
    column: $table.paletteColors,
    builder: (column) => column,
  );

  GeneratedColumn<String> get decomposedComponents => $composableBuilder(
    column: $table.decomposedComponents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aiHistoryLogs => $composableBuilder(
    column: $table.aiHistoryLogs,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get referenceImage => $composableBuilder(
    column: $table.referenceImage,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get originalReferenceImage => $composableBuilder(
    column: $table.originalReferenceImage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> workspaceSessionsRefs<T extends Object>(
    Expression<T> Function($$WorkspaceSessionsTableAnnotationComposer a) f,
  ) {
    final $$WorkspaceSessionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workspaceSessions,
          getReferencedColumn: (t) => t.activeCreationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkspaceSessionsTableAnnotationComposer(
                $db: $db,
                $table: $db.workspaceSessions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CreationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CreationsTable,
          Creation,
          $$CreationsTableFilterComposer,
          $$CreationsTableOrderingComposer,
          $$CreationsTableAnnotationComposer,
          $$CreationsTableCreateCompanionBuilder,
          $$CreationsTableUpdateCompanionBuilder,
          (Creation, $$CreationsTableReferences),
          Creation,
          PrefetchHooks Function({bool workspaceSessionsRefs})
        > {
  $$CreationsTableTableManager(_$AppDatabase db, $CreationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CreationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CreationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CreationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> gridSize = const Value.absent(),
                Value<String> gridData = const Value.absent(),
                Value<String> paletteName = const Value.absent(),
                Value<String> paletteColors = const Value.absent(),
                Value<String> decomposedComponents = const Value.absent(),
                Value<String> aiHistoryLogs = const Value.absent(),
                Value<Uint8List?> referenceImage = const Value.absent(),
                Value<Uint8List?> originalReferenceImage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => CreationsCompanion(
                id: id,
                title: title,
                gridSize: gridSize,
                gridData: gridData,
                paletteName: paletteName,
                paletteColors: paletteColors,
                decomposedComponents: decomposedComponents,
                aiHistoryLogs: aiHistoryLogs,
                referenceImage: referenceImage,
                originalReferenceImage: originalReferenceImage,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                required int gridSize,
                required String gridData,
                required String paletteName,
                required String paletteColors,
                required String decomposedComponents,
                required String aiHistoryLogs,
                Value<Uint8List?> referenceImage = const Value.absent(),
                Value<Uint8List?> originalReferenceImage = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => CreationsCompanion.insert(
                id: id,
                title: title,
                gridSize: gridSize,
                gridData: gridData,
                paletteName: paletteName,
                paletteColors: paletteColors,
                decomposedComponents: decomposedComponents,
                aiHistoryLogs: aiHistoryLogs,
                referenceImage: referenceImage,
                originalReferenceImage: originalReferenceImage,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CreationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({workspaceSessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workspaceSessionsRefs) db.workspaceSessions,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workspaceSessionsRefs)
                    await $_getPrefetchedData<
                      Creation,
                      $CreationsTable,
                      WorkspaceSession
                    >(
                      currentTable: table,
                      referencedTable: $$CreationsTableReferences
                          ._workspaceSessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CreationsTableReferences(
                            db,
                            table,
                            p0,
                          ).workspaceSessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.activeCreationId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CreationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CreationsTable,
      Creation,
      $$CreationsTableFilterComposer,
      $$CreationsTableOrderingComposer,
      $$CreationsTableAnnotationComposer,
      $$CreationsTableCreateCompanionBuilder,
      $$CreationsTableUpdateCompanionBuilder,
      (Creation, $$CreationsTableReferences),
      Creation,
      PrefetchHooks Function({bool workspaceSessionsRefs})
    >;
typedef $$WorkspaceSessionsTableCreateCompanionBuilder =
    WorkspaceSessionsCompanion Function({
      Value<int> id,
      Value<int?> activeCreationId,
      Value<int> selectedColorIndex,
      Value<String> selectedTool,
      Value<String> userPrompt,
      required DateTime lastSavedAt,
    });
typedef $$WorkspaceSessionsTableUpdateCompanionBuilder =
    WorkspaceSessionsCompanion Function({
      Value<int> id,
      Value<int?> activeCreationId,
      Value<int> selectedColorIndex,
      Value<String> selectedTool,
      Value<String> userPrompt,
      Value<DateTime> lastSavedAt,
    });

final class $$WorkspaceSessionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkspaceSessionsTable,
          WorkspaceSession
        > {
  $$WorkspaceSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CreationsTable _activeCreationIdTable(_$AppDatabase db) => db
      .creations
      .createAlias('workspace_sessions__active_creation_id__creations__id');

  $$CreationsTableProcessedTableManager? get activeCreationId {
    final $_column = $_itemColumn<int>('active_creation_id');
    if ($_column == null) return null;
    final manager = $$CreationsTableTableManager(
      $_db,
      $_db.creations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_activeCreationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkspaceSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkspaceSessionsTable> {
  $$WorkspaceSessionsTableFilterComposer({
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

  ColumnFilters<int> get selectedColorIndex => $composableBuilder(
    column: $table.selectedColorIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedTool => $composableBuilder(
    column: $table.selectedTool,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userPrompt => $composableBuilder(
    column: $table.userPrompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CreationsTableFilterComposer get activeCreationId {
    final $$CreationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activeCreationId,
      referencedTable: $db.creations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CreationsTableFilterComposer(
            $db: $db,
            $table: $db.creations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkspaceSessionsTable> {
  $$WorkspaceSessionsTableOrderingComposer({
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

  ColumnOrderings<int> get selectedColorIndex => $composableBuilder(
    column: $table.selectedColorIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedTool => $composableBuilder(
    column: $table.selectedTool,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userPrompt => $composableBuilder(
    column: $table.userPrompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CreationsTableOrderingComposer get activeCreationId {
    final $$CreationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activeCreationId,
      referencedTable: $db.creations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CreationsTableOrderingComposer(
            $db: $db,
            $table: $db.creations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkspaceSessionsTable> {
  $$WorkspaceSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get selectedColorIndex => $composableBuilder(
    column: $table.selectedColorIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedTool => $composableBuilder(
    column: $table.selectedTool,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userPrompt => $composableBuilder(
    column: $table.userPrompt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSavedAt => $composableBuilder(
    column: $table.lastSavedAt,
    builder: (column) => column,
  );

  $$CreationsTableAnnotationComposer get activeCreationId {
    final $$CreationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.activeCreationId,
      referencedTable: $db.creations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CreationsTableAnnotationComposer(
            $db: $db,
            $table: $db.creations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkspaceSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkspaceSessionsTable,
          WorkspaceSession,
          $$WorkspaceSessionsTableFilterComposer,
          $$WorkspaceSessionsTableOrderingComposer,
          $$WorkspaceSessionsTableAnnotationComposer,
          $$WorkspaceSessionsTableCreateCompanionBuilder,
          $$WorkspaceSessionsTableUpdateCompanionBuilder,
          (WorkspaceSession, $$WorkspaceSessionsTableReferences),
          WorkspaceSession,
          PrefetchHooks Function({bool activeCreationId})
        > {
  $$WorkspaceSessionsTableTableManager(
    _$AppDatabase db,
    $WorkspaceSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkspaceSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkspaceSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkspaceSessionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activeCreationId = const Value.absent(),
                Value<int> selectedColorIndex = const Value.absent(),
                Value<String> selectedTool = const Value.absent(),
                Value<String> userPrompt = const Value.absent(),
                Value<DateTime> lastSavedAt = const Value.absent(),
              }) => WorkspaceSessionsCompanion(
                id: id,
                activeCreationId: activeCreationId,
                selectedColorIndex: selectedColorIndex,
                selectedTool: selectedTool,
                userPrompt: userPrompt,
                lastSavedAt: lastSavedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> activeCreationId = const Value.absent(),
                Value<int> selectedColorIndex = const Value.absent(),
                Value<String> selectedTool = const Value.absent(),
                Value<String> userPrompt = const Value.absent(),
                required DateTime lastSavedAt,
              }) => WorkspaceSessionsCompanion.insert(
                id: id,
                activeCreationId: activeCreationId,
                selectedColorIndex: selectedColorIndex,
                selectedTool: selectedTool,
                userPrompt: userPrompt,
                lastSavedAt: lastSavedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$WorkspaceSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activeCreationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (activeCreationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.activeCreationId,
                                referencedTable:
                                    $$WorkspaceSessionsTableReferences
                                        ._activeCreationIdTable(db),
                                referencedColumn:
                                    $$WorkspaceSessionsTableReferences
                                        ._activeCreationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkspaceSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkspaceSessionsTable,
      WorkspaceSession,
      $$WorkspaceSessionsTableFilterComposer,
      $$WorkspaceSessionsTableOrderingComposer,
      $$WorkspaceSessionsTableAnnotationComposer,
      $$WorkspaceSessionsTableCreateCompanionBuilder,
      $$WorkspaceSessionsTableUpdateCompanionBuilder,
      (WorkspaceSession, $$WorkspaceSessionsTableReferences),
      WorkspaceSession,
      PrefetchHooks Function({bool activeCreationId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CreationsTableTableManager get creations =>
      $$CreationsTableTableManager(_db, _db.creations);
  $$WorkspaceSessionsTableTableManager get workspaceSessions =>
      $$WorkspaceSessionsTableTableManager(_db, _db.workspaceSessions);
}
