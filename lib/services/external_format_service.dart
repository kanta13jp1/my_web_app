import 'package:supabase_flutter/supabase_flutter.dart';

class ExternalFieldMapping {
  final String sourceField;
  final String targetField;
  final bool include;
  final bool requiredField;

  const ExternalFieldMapping({
    required this.sourceField,
    required this.targetField,
    this.include = true,
    this.requiredField = false,
  });

  ExternalFieldMapping copyWith({
    String? sourceField,
    String? targetField,
    bool? include,
    bool? requiredField,
  }) {
    return ExternalFieldMapping(
      sourceField: sourceField ?? this.sourceField,
      targetField: targetField ?? this.targetField,
      include: include ?? this.include,
      requiredField: requiredField ?? this.requiredField,
    );
  }

  factory ExternalFieldMapping.fromJson(Map<String, dynamic> json) {
    return ExternalFieldMapping(
      sourceField: json['source_field']?.toString() ?? '',
      targetField: json['target_field']?.toString() ?? '',
      include: json['include'] != false,
      requiredField: json['required'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source_field': sourceField,
      'target_field': targetField,
      'include': include,
      'required': requiredField,
    };
  }
}

class ExternalFormatProfile {
  final String id;
  final String label;
  final String delimiter;
  final List<ExternalFieldMapping> mappings;

  const ExternalFormatProfile({
    required this.id,
    required this.label,
    required this.delimiter,
    required this.mappings,
  });

  ExternalFormatProfile copyWith({
    String? id,
    String? label,
    String? delimiter,
    List<ExternalFieldMapping>? mappings,
  }) {
    return ExternalFormatProfile(
      id: id ?? this.id,
      label: label ?? this.label,
      delimiter: delimiter ?? this.delimiter,
      mappings: mappings ?? this.mappings,
    );
  }

  factory ExternalFormatProfile.fromJson(Map<String, dynamic> json) {
    final mappingsJson =
        json['mappings'] as List<dynamic>? ?? const <dynamic>[];
    return ExternalFormatProfile(
      id: json['id']?.toString() ?? 'custom',
      label: json['label']?.toString() ?? 'Custom mapping',
      delimiter: json['delimiter']?.toString() ?? ',',
      mappings: mappingsJson
          .whereType<Map>()
          .map(
            (mapping) => ExternalFieldMapping.fromJson(
              Map<String, dynamic>.from(mapping),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'label': label,
      'delimiter': delimiter,
      'mappings': mappings.map((mapping) => mapping.toJson()).toList(),
    };
  }
}

class ExternalFormatTransformResult {
  final List<String> outputFields;
  final List<Map<String, String>> rows;
  final List<String> warnings;

  const ExternalFormatTransformResult({
    required this.outputFields,
    required this.rows,
    this.warnings = const <String>[],
  });
}

class ExternalFormatService {
  final SupabaseClient? _clientOverride;

  const ExternalFormatService({SupabaseClient? clientOverride})
      : _clientOverride = clientOverride;

  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static ExternalFormatProfile defaultProfile(String formatId) {
    switch (formatId) {
      case 'aidx':
        return const ExternalFormatProfile(
          id: 'aidx',
          label: 'AIDX運航イベント',
          delimiter: ',',
          mappings: <ExternalFieldMapping>[
            ExternalFieldMapping(
              sourceField: 'FlightId',
              targetField: 'flight_id',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'EventType',
              targetField: 'event_type',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'Station',
              targetField: 'station',
            ),
            ExternalFieldMapping(
              sourceField: 'ScheduledTime',
              targetField: 'scheduled_time',
            ),
            ExternalFieldMapping(
              sourceField: 'EstimatedTime',
              targetField: 'estimated_time',
            ),
            ExternalFieldMapping(sourceField: 'Gate', targetField: 'gate'),
            ExternalFieldMapping(sourceField: 'Status', targetField: 'status'),
          ],
        );
      case 'ssim':
      default:
        return const ExternalFormatProfile(
          id: 'ssim',
          label: 'SSIMスケジュール',
          delimiter: ',',
          mappings: <ExternalFieldMapping>[
            ExternalFieldMapping(
              sourceField: 'Carrier',
              targetField: 'carrier_code',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'FlightNumber',
              targetField: 'flight_number',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'Departure',
              targetField: 'departure_airport',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'Arrival',
              targetField: 'arrival_airport',
              requiredField: true,
            ),
            ExternalFieldMapping(
              sourceField: 'DepartureTime',
              targetField: 'departure_time',
            ),
            ExternalFieldMapping(
              sourceField: 'ArrivalTime',
              targetField: 'arrival_time',
            ),
            ExternalFieldMapping(
              sourceField: 'Aircraft',
              targetField: 'aircraft_type',
              include: false,
            ),
          ],
        );
    }
  }

  static String sampleText(String formatId) {
    if (formatId == 'aidx') {
      return [
        'FlightId,EventType,Station,ScheduledTime,EstimatedTime,Gate,Status',
        'NH007,ARR,NRT,2026-05-05T16:00:00Z,2026-05-05T16:08:00Z,54,DELAYED',
        'JL010,DEP,HND,2026-05-05T18:20:00Z,2026-05-05T18:20:00Z,12,ON_TIME',
      ].join('\n');
    }
    return [
      'Carrier,FlightNumber,Departure,Arrival,DepartureTime,ArrivalTime,Aircraft',
      'NH,007,NRT,LAX,1600,0935,789',
      'JL,010,HND,ORD,1820,1630,773',
    ].join('\n');
  }

  ExternalFormatTransformResult transform({
    required String inputText,
    required ExternalFormatProfile profile,
  }) {
    final parsedRows = _parseDelimited(inputText, profile.delimiter);
    if (parsedRows.length <= 1) {
      return const ExternalFormatTransformResult(
        outputFields: <String>[],
        rows: <Map<String, String>>[],
        warnings: <String>['No header and data rows were found.'],
      );
    }

    final headers = parsedRows.first.map((header) => header.trim()).toList();
    final headerIndex = <String, int>{
      for (var i = 0; i < headers.length; i++) headers[i].toLowerCase(): i,
    };
    final activeMappings = profile.mappings
        .where(
          (mapping) => mapping.include && mapping.targetField.trim().isNotEmpty,
        )
        .toList();
    final warnings = <String>[];
    final outputFields = activeMappings
        .map((mapping) => mapping.targetField.trim())
        .where((field) => field.isNotEmpty)
        .toList();
    final rows = <Map<String, String>>[];

    for (final mapping in activeMappings) {
      final sourceKey = mapping.sourceField.trim().toLowerCase();
      if (sourceKey.isEmpty || !headerIndex.containsKey(sourceKey)) {
        final severity = mapping.requiredField ? 'Required' : 'Optional';
        warnings.add(
          '$severity source field "${mapping.sourceField}" is missing.',
        );
      }
    }

    for (final rawRow in parsedRows.skip(1)) {
      if (rawRow.every((cell) => cell.trim().isEmpty)) {
        continue;
      }
      final mapped = <String, String>{};
      for (final mapping in activeMappings) {
        final sourceKey = mapping.sourceField.trim().toLowerCase();
        final targetKey = mapping.targetField.trim();
        final index = headerIndex[sourceKey];
        mapped[targetKey] =
            index == null || index >= rawRow.length ? '' : rawRow[index].trim();
      }
      rows.add(mapped);
    }

    return ExternalFormatTransformResult(
      outputFields: outputFields,
      rows: rows,
      warnings: warnings,
    );
  }

  String exportDelimited(
    ExternalFormatTransformResult result,
    String delimiter,
  ) {
    final lines = <String>[
      result.outputFields.map((field) => _escapeCell(field, delimiter)).join(
            delimiter,
          ),
      ...result.rows.map(
        (row) => result.outputFields
            .map((field) => _escapeCell(row[field] ?? '', delimiter))
            .join(delimiter),
      ),
    ];
    return lines.join('\n');
  }

  Future<List<ExternalFormatProfile>> listProfiles() async {
    final response = await _client.functions.invoke(
      'enterprise-hub',
      body: <String, dynamic>{'action': 'integration.mapping_profiles'},
    );
    final data = _asMap(response.data);
    final profiles = data['profiles'] as List<dynamic>? ?? const <dynamic>[];
    return profiles
        .whereType<Map>()
        .map((item) => _profileFromHubItem(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveProfile(ExternalFormatProfile profile) async {
    final response = await _client.functions.invoke(
      'enterprise-hub',
      body: <String, dynamic>{
        'action': 'integration.mapping_profile.save',
        'profile': profile.toJson(),
      },
    );
    final data = _asMap(response.data);
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? 'Mapping save failed.');
    }
  }

  ExternalFormatProfile _profileFromHubItem(Map<String, dynamic> item) {
    final metadata = item['metadata'] is Map
        ? Map<String, dynamic>.from(item['metadata'] as Map)
        : item;
    final profile = metadata['profile'] is Map
        ? Map<String, dynamic>.from(metadata['profile'] as Map)
        : metadata;
    return ExternalFormatProfile.fromJson(profile);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('Expected a JSON object response.');
  }

  List<List<String>> _parseDelimited(String input, String delimiter) {
    final separator = delimiter.isEmpty ? ',' : delimiter[0];
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final next = i + 1 < input.length ? input[i + 1] : null;
      if (char == '"') {
        if (inQuotes && next == '"') {
          currentCell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char == separator && !inQuotes) {
        currentRow.add(currentCell.toString());
        currentCell.clear();
        continue;
      }
      if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') i++;
        currentRow.add(currentCell.toString());
        currentCell.clear();
        rows.add(List<String>.from(currentRow));
        currentRow.clear();
        continue;
      }
      currentCell.write(char);
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(List<String>.from(currentRow));
    }
    return rows;
  }

  String _escapeCell(String value, String delimiter) {
    final separator = delimiter.isEmpty ? ',' : delimiter[0];
    if (!value.contains(separator) &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}
