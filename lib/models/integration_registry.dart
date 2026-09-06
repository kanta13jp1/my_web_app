class IntegrationFieldDefinition {
  const IntegrationFieldDefinition({
    required this.name,
    required this.dataType,
    required this.required,
    this.description = '',
  });

  final String name;
  final String dataType;
  final bool required;
  final String description;

  factory IntegrationFieldDefinition.fromJson(Map<String, dynamic> json) {
    return IntegrationFieldDefinition(
      name: json['name']?.toString() ?? '',
      dataType: json['data_type']?.toString() ?? 'string',
      required: json['required'] == true,
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'data_type': dataType,
        'required': required,
        'description': description,
      };
}

class IntegrationSystemDefinition {
  const IntegrationSystemDefinition({
    required this.id,
    required this.systemKey,
    required this.name,
    required this.version,
    required this.status,
    this.description = '',
    this.owner = '',
    this.createdAt,
  });

  final String id;
  final String systemKey;
  final String name;
  final int version;
  final String status;
  final String description;
  final String owner;
  final DateTime? createdAt;

  factory IntegrationSystemDefinition.fromJson(Map<String, dynamic> json) {
    return IntegrationSystemDefinition(
      id: json['id']?.toString() ?? '',
      systemKey: json['system_key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: _intValue(json['version'], 1),
      status: json['status']?.toString() ?? 'active',
      description: json['description']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class IntegrationInterfaceDefinition {
  const IntegrationInterfaceDefinition({
    required this.id,
    required this.interfaceKey,
    required this.name,
    required this.sourceSystemKey,
    required this.targetSystemKey,
    required this.version,
    required this.protocol,
    required this.format,
    required this.status,
    required this.fields,
    this.direction = 'outbound',
    this.description = '',
    this.createdAt,
  });

  final String id;
  final String interfaceKey;
  final String name;
  final String sourceSystemKey;
  final String targetSystemKey;
  final int version;
  final String protocol;
  final String format;
  final String status;
  final String direction;
  final String description;
  final List<IntegrationFieldDefinition> fields;
  final DateTime? createdAt;

  factory IntegrationInterfaceDefinition.fromJson(Map<String, dynamic> json) {
    return IntegrationInterfaceDefinition(
      id: json['id']?.toString() ?? '',
      interfaceKey: json['interface_key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sourceSystemKey: json['source_system_key']?.toString() ?? '',
      targetSystemKey: json['target_system_key']?.toString() ?? '',
      version: _intValue(json['version'], 1),
      protocol: json['protocol']?.toString() ?? 'REST',
      format: json['format']?.toString() ?? 'JSON',
      status: json['status']?.toString() ?? 'active',
      direction: json['direction']?.toString() ?? 'outbound',
      description: json['description']?.toString() ?? '',
      fields: _mapList(
        json['fields'],
      ).map(IntegrationFieldDefinition.fromJson).toList(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class IntegrationCodeMappingEntry {
  const IntegrationCodeMappingEntry({
    required this.oldCode,
    required this.newCode,
    this.description = '',
    this.active = true,
  });

  final String oldCode;
  final String newCode;
  final String description;
  final bool active;

  factory IntegrationCodeMappingEntry.fromJson(Map<String, dynamic> json) {
    return IntegrationCodeMappingEntry(
      oldCode:
          json['old_code']?.toString() ?? json['source_code']?.toString() ?? '',
      newCode:
          json['new_code']?.toString() ?? json['target_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      active: json['active'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'old_code': oldCode,
        'new_code': newCode,
        'description': description,
        'active': active,
      };
}

class IntegrationCodeMappingSet {
  const IntegrationCodeMappingSet({
    required this.id,
    required this.mappingKey,
    required this.name,
    required this.sourceSystemKey,
    required this.targetSystemKey,
    required this.version,
    required this.entries,
    this.description = '',
    this.createdAt,
  });

  final String id;
  final String mappingKey;
  final String name;
  final String sourceSystemKey;
  final String targetSystemKey;
  final int version;
  final String description;
  final List<IntegrationCodeMappingEntry> entries;
  final DateTime? createdAt;

  factory IntegrationCodeMappingSet.fromJson(Map<String, dynamic> json) {
    return IntegrationCodeMappingSet(
      id: json['id']?.toString() ?? '',
      mappingKey: json['mapping_key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sourceSystemKey: json['source_system_key']?.toString() ?? '',
      targetSystemKey: json['target_system_key']?.toString() ?? '',
      version: _intValue(json['version'], 1),
      description: json['description']?.toString() ?? '',
      entries: _mapList(
        json['entries'],
      ).map(IntegrationCodeMappingEntry.fromJson).toList(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class IntegrationRegistrySnapshot {
  const IntegrationRegistrySnapshot({
    this.systems = const <IntegrationSystemDefinition>[],
    this.systemVersions = const <IntegrationSystemDefinition>[],
    this.interfaces = const <IntegrationInterfaceDefinition>[],
    this.interfaceVersions = const <IntegrationInterfaceDefinition>[],
    this.mappings = const <IntegrationCodeMappingSet>[],
    this.mappingVersions = const <IntegrationCodeMappingSet>[],
  });

  final List<IntegrationSystemDefinition> systems;
  final List<IntegrationSystemDefinition> systemVersions;
  final List<IntegrationInterfaceDefinition> interfaces;
  final List<IntegrationInterfaceDefinition> interfaceVersions;
  final List<IntegrationCodeMappingSet> mappings;
  final List<IntegrationCodeMappingSet> mappingVersions;

  factory IntegrationRegistrySnapshot.fromJson(Map<String, dynamic> json) {
    return IntegrationRegistrySnapshot(
      systems: _mapList(
        json['systems'],
      ).map(IntegrationSystemDefinition.fromJson).toList(),
      systemVersions: _mapList(
        json['system_versions'],
      ).map(IntegrationSystemDefinition.fromJson).toList(),
      interfaces: _mapList(
        json['interfaces'],
      ).map(IntegrationInterfaceDefinition.fromJson).toList(),
      interfaceVersions: _mapList(
        json['interface_versions'],
      ).map(IntegrationInterfaceDefinition.fromJson).toList(),
      mappings: _mapList(
        json['mappings'],
      ).map(IntegrationCodeMappingSet.fromJson).toList(),
      mappingVersions: _mapList(
        json['mapping_versions'],
      ).map(IntegrationCodeMappingSet.fromJson).toList(),
    );
  }
}

class IntegrationImpactReport {
  const IntegrationImpactReport({
    required this.rootSystemKey,
    required this.systems,
    required this.interfaces,
    required this.mappings,
  });

  final String rootSystemKey;
  final List<IntegrationSystemDefinition> systems;
  final List<IntegrationInterfaceDefinition> interfaces;
  final List<IntegrationCodeMappingSet> mappings;

  factory IntegrationImpactReport.fromJson(Map<String, dynamic> json) {
    return IntegrationImpactReport(
      rootSystemKey: json['root_system_key']?.toString() ?? '',
      systems: _mapList(
        json['systems'],
      ).map(IntegrationSystemDefinition.fromJson).toList(),
      interfaces: _mapList(
        json['interfaces'],
      ).map(IntegrationInterfaceDefinition.fromJson).toList(),
      mappings: _mapList(
        json['mappings'],
      ).map(IntegrationCodeMappingSet.fromJson).toList(),
    );
  }
}

class IntegrationSystemDraft {
  const IntegrationSystemDraft({
    required this.name,
    this.systemKey = '',
    this.description = '',
    this.owner = '',
    this.status = 'active',
  });

  final String name;
  final String systemKey;
  final String description;
  final String owner;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'system_key': systemKey,
        'description': description,
        'owner': owner,
        'status': status,
      };
}

class IntegrationInterfaceDraft {
  const IntegrationInterfaceDraft({
    required this.name,
    required this.sourceSystemKey,
    required this.targetSystemKey,
    required this.fields,
    this.interfaceKey = '',
    this.protocol = 'REST',
    this.format = 'JSON',
    this.direction = 'outbound',
    this.description = '',
    this.status = 'active',
  });

  final String name;
  final String sourceSystemKey;
  final String targetSystemKey;
  final List<IntegrationFieldDefinition> fields;
  final String interfaceKey;
  final String protocol;
  final String format;
  final String direction;
  final String description;
  final String status;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'interface_key': interfaceKey,
        'source_system_key': sourceSystemKey,
        'target_system_key': targetSystemKey,
        'fields': fields.map((field) => field.toJson()).toList(),
        'protocol': protocol,
        'format': format,
        'direction': direction,
        'description': description,
        'status': status,
      };
}

class IntegrationMappingImportDraft {
  const IntegrationMappingImportDraft({
    required this.name,
    required this.sourceSystemKey,
    required this.targetSystemKey,
    required this.entries,
    this.mappingKey = '',
    this.description = '',
  });

  final String name;
  final String sourceSystemKey;
  final String targetSystemKey;
  final List<IntegrationCodeMappingEntry> entries;
  final String mappingKey;
  final String description;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'mapping_key': mappingKey,
        'source_system_key': sourceSystemKey,
        'target_system_key': targetSystemKey,
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'description': description,
      };
}

class IntegrationCodeMappingCsvParser {
  const IntegrationCodeMappingCsvParser();

  List<IntegrationCodeMappingEntry> parse(String csvText) {
    final rows = _parseRows(csvText);
    if (rows.length < 2) {
      throw const FormatException('CSV must include a header and data rows.');
    }
    final headers =
        rows.first.map((cell) => cell.trim().toLowerCase()).toList();
    final oldIndex = _headerIndex(headers, const <String>[
      'old_code',
      'source_code',
      'old',
      'source',
    ])!;
    final newIndex = _headerIndex(headers, const <String>[
      'new_code',
      'target_code',
      'new',
      'target',
    ])!;
    final descriptionIndex = _headerIndex(
      headers,
      const <String>[
        'description',
        'note',
        'memo',
      ],
      required: false,
    );
    final entries = <IntegrationCodeMappingEntry>[];
    final seen = <String>{};
    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final oldCode = _cell(row, oldIndex);
      final newCode = _cell(row, newIndex);
      if (oldCode.isEmpty || newCode.isEmpty) {
        throw FormatException(
          'Row ${rowIndex + 1} requires old_code and new_code.',
        );
      }
      final key = '$oldCode\u0000$newCode';
      if (!seen.add(key)) continue;
      entries.add(
        IntegrationCodeMappingEntry(
          oldCode: oldCode,
          newCode: newCode,
          description:
              descriptionIndex == null ? '' : _cell(row, descriptionIndex),
        ),
      );
    }
    if (entries.isEmpty) {
      throw const FormatException('CSV contains no mapping rows.');
    }
    return entries;
  }

  int? _headerIndex(
    List<String> headers,
    List<String> aliases, {
    bool required = true,
  }) {
    for (final alias in aliases) {
      final index = headers.indexOf(alias);
      if (index >= 0) return index;
    }
    if (required) {
      throw FormatException('Missing CSV column: ${aliases.first}.');
    }
    return null;
  }

  String _cell(List<String> row, int index) {
    return index < row.length ? row[index].trim() : '';
  }

  List<List<String>> _parseRows(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      final next = index + 1 < input.length ? input[index + 1] : null;
      if (char == '"') {
        if (quoted && next == '"') {
          cell.write('"');
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\r' || char == '\n') && !quoted) {
        if (char == '\r' && next == '\n') index++;
        row.add(cell.toString());
        cell.clear();
        rows.add(List<String>.from(row));
        row.clear();
      } else {
        cell.write(char);
      }
    }
    if (quoted) {
      throw const FormatException('CSV has an unterminated quoted value.');
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(List<String>.from(row));
    }
    return rows;
  }
}

int _intValue(dynamic value, int fallback) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
