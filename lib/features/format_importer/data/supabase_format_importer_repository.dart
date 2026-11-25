import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/format_importer_models.dart';

/// `app-hub` Edge Function 経由の汎用フォーマット取込＆JSONB属性管理 (#2741)。
class SupabaseFormatImporterRepository implements FormatImporterRepository {
  SupabaseFormatImporterRepository({
    SupabaseClient Function()? clientResolver,
  }) : _clientResolver = clientResolver ?? _defaultClient;

  final SupabaseClient Function() _clientResolver;

  static SupabaseClient _defaultClient() => Supabase.instance.client;

  Future<Map<String, Object?>> _invokeAppHub(
    Map<String, Object?> payload,
  ) async {
    final SupabaseClient client = _clientResolver();
    try {
      final FunctionResponse response = await client.functions.invoke(
        'app-hub',
        body: payload,
      );
      final Map<String, Object?> body = _normalizeMap(response.data);
      final String errorText = (body['error'] as String? ?? '').trim();
      if (response.status >= 400 || errorText.isNotEmpty) {
        throw StateError(
          errorText.isNotEmpty
              ? errorText
              : 'Format importer request failed (${response.status})',
        );
      }
      return body;
    } on FunctionException catch (error) {
      final Map<String, Object?> details = _normalizeMap(error.details);
      final String detailError = (details['error'] as String? ?? '').trim();
      final String reason = (error.reasonPhrase ?? '').trim();
      throw StateError(
        detailError.isNotEmpty
            ? detailError
            : (reason.isNotEmpty
                ? reason
                : 'Format importer request failed (${error.status})'),
      );
    }
  }

  Map<String, Object?> _normalizeMap(Object? raw) {
    if (raw is Map<Object?, Object?>) {
      return Map<String, Object?>.from(raw);
    }
    return const <String, Object?>{};
  }

  @override
  Future<FormatImporterSnapshot> loadWorkspace() async {
    final Map<String, Object?> data = await _invokeAppHub(
      const <String, Object?>{'action': 'format_importer.list'},
    );
    final Object? rawRecords = data['records'];
    final Object? rawAttrs = data['custom_attributes'];

    final List<ImportedDataRecord> records = rawRecords is List<Object?>
        ? rawRecords
            .whereType<Map<Object?, Object?>>()
            .map(
              (Map<Object?, Object?> row) => ImportedDataRecord.fromHubRow(
                Map<String, Object?>.from(row),
              ),
            )
            .toList(growable: false)
        : const <ImportedDataRecord>[];

    final List<CustomAttributeDefinition> customAttributes =
        rawAttrs is List<Object?>
            ? rawAttrs
                .whereType<Map<Object?, Object?>>()
                .map(
                  (Map<Object?, Object?> item) =>
                      CustomAttributeDefinition.fromJson(
                    Map<String, Object?>.from(item),
                  ),
                )
                .toList(growable: false)
            : const <CustomAttributeDefinition>[];

    return FormatImporterSnapshot(
      records: records,
      customAttributes: customAttributes,
    );
  }

  @override
  Future<List<ImportedDataRecord>> importPayload({
    required ImportFormat sourceFormat,
    required String formatProfile,
    required String payload,
    required Map<String, String> fieldMapping,
    required List<String> tags,
    required Map<String, Object?> customAttributes,
    String rootPath = '',
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'format_importer.import',
        'source_format': sourceFormat.wireValue,
        'format_profile': formatProfile,
        'payload': payload,
        'field_mapping': fieldMapping,
        'tags': tags,
        'custom_attributes': customAttributes,
        if (rootPath.trim().isNotEmpty) 'root_path': rootPath.trim(),
      },
    );
    final Object? rawRecords = data['records'];
    if (rawRecords is! List<Object?>) {
      return const <ImportedDataRecord>[];
    }
    return rawRecords
        .whereType<Map<Object?, Object?>>()
        .map(
          (Map<Object?, Object?> row) =>
              ImportedDataRecord.fromHubRow(Map<String, Object?>.from(row)),
        )
        .toList(growable: false);
  }

  @override
  Future<CustomAttributeDefinition> defineCustomAttribute({
    required String key,
    required String label,
    required CustomAttributeType valueType,
    bool required = false,
    Object? defaultValue,
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'format_importer.define_attribute',
        'key': key,
        'label': label,
        'value_type': valueType.wireValue,
        'required': required,
        'default_value': defaultValue,
      },
    );
    return CustomAttributeDefinition.fromJson(
      _normalizeMap(data['custom_attribute']),
    );
  }

  @override
  Future<ImportedDataRecord> updateRecordAttributes({
    required String recordId,
    required Map<String, Object?> customAttributes,
    List<String>? tags,
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'format_importer.update_record_attributes',
        'record_id': recordId,
        'custom_attributes': customAttributes,
        if (tags != null) 'tags': tags,
      },
    );
    return ImportedDataRecord.fromHubRow(_normalizeMap(data['record']));
  }

  @override
  Future<ExportResult> exportFilteredRecords({
    required ExportFormat format,
    required List<String> excludedFields,
    required List<String> excludedTags,
  }) async {
    final Map<String, Object?> data = await _invokeAppHub(
      <String, Object?>{
        'action': 'format_importer.export',
        'format': format.wireValue,
        'excluded_fields': excludedFields,
        'excluded_tags': excludedTags,
      },
    );
    return ExportResult.fromJson(data);
  }
}
