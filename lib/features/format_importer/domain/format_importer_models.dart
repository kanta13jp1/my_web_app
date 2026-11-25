import 'package:flutter/foundation.dart';

/// サポートする汎用インポート入力形式。
enum ImportFormat {
  json('json', '階層 JSON'),
  csv('csv', '標準 CSV (RFC-4180)');

  const ImportFormat(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ImportFormat fromWire(String raw) {
    for (final ImportFormat value in ImportFormat.values) {
      if (value.wireValue == raw) {
        return value;
      }
    }
    return ImportFormat.json;
  }
}

/// DB スキーマ変更なしで追加できる JSONB カスタム属性の型定義。
enum CustomAttributeType {
  string('string', '文字列 (String)'),
  number('number', '数値 (Number)'),
  boolean('boolean', '真偽値 (Boolean)'),
  date('date', '日付 ISO-8601 (Date)'),
  stringList('string_list', '文字列リスト (CSV)');

  const CustomAttributeType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static CustomAttributeType fromWire(String raw) {
    for (final CustomAttributeType value in CustomAttributeType.values) {
      if (value.wireValue == raw) {
        return value;
      }
    }
    return CustomAttributeType.string;
  }
}

/// エクスポート出力フォーマット。
enum ExportFormat {
  json('json', 'JSON'),
  csv('csv', 'CSV');

  const ExportFormat(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

/// `hub_data` の JSONB スキーマ外定義として保存されるカスタム属性メタデータ。
@immutable
class CustomAttributeDefinition {
  const CustomAttributeDefinition({
    required this.key,
    required this.label,
    required this.valueType,
    this.id = '',
    this.required = false,
    this.defaultValue,
  });

  factory CustomAttributeDefinition.fromJson(Map<String, Object?> json) {
    return CustomAttributeDefinition(
      id: (json['id'] as String? ?? '').trim(),
      key: (json['key'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? json['key'] as String? ?? '').trim(),
      valueType: CustomAttributeType.fromWire(
        (json['value_type'] as String? ?? 'string').trim(),
      ),
      required: json['required'] as bool? ?? false,
      defaultValue: json['default_value'],
    );
  }

  final String id;
  final String key;
  final String label;
  final CustomAttributeType valueType;
  final bool required;
  final Object? defaultValue;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'key': key,
      'label': label,
      'value_type': valueType.wireValue,
      'required': required,
      'default_value': defaultValue,
    };
  }
}

/// マッピング取り込み済みレコード（JSONB カスタム属性を内包）。
@immutable
class ImportedDataRecord {
  const ImportedDataRecord({
    required this.id,
    required this.formatProfile,
    required this.sourceFormat,
    required this.tags,
    required this.mappedFields,
    required this.customAttributes,
    required this.createdAtIso,
  });

  factory ImportedDataRecord.fromHubRow(Map<String, Object?> row) {
    final Object? rawMeta = row['metadata'];
    final Map<String, Object?> meta = rawMeta is Map<Object?, Object?>
        ? Map<String, Object?>.from(rawMeta)
        : const <String, Object?>{};
    final Object? rawTags = meta['tags'];
    final List<String> tags = rawTags is List<Object?>
        ? rawTags
            .map((Object? item) => item?.toString().trim() ?? '')
            .where((String item) => item.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final Object? rawMapped = meta['mapped_fields'];
    final Map<String, Object?> mappedFields = rawMapped is Map<Object?, Object?>
        ? Map<String, Object?>.from(rawMapped)
        : const <String, Object?>{};
    final Object? rawCustom = meta['custom_attributes'];
    final Map<String, Object?> customAttrs = rawCustom is Map<Object?, Object?>
        ? Map<String, Object?>.from(rawCustom)
        : const <String, Object?>{};

    return ImportedDataRecord(
      id: (row['id'] as String? ?? '').trim(),
      formatProfile: (meta['format_profile'] as String? ?? 'generic').trim(),
      sourceFormat: ImportFormat.fromWire(
        (meta['source_format'] as String? ?? 'json').trim(),
      ),
      tags: tags,
      mappedFields: mappedFields,
      customAttributes: customAttrs,
      createdAtIso: (row['created_at'] as String? ?? '').trim(),
    );
  }

  final String id;
  final String formatProfile;
  final ImportFormat sourceFormat;
  final List<String> tags;
  final Map<String, Object?> mappedFields;
  final Map<String, Object?> customAttributes;
  final String createdAtIso;
}

/// 動的フィールド／タグ除外付きエクスポート結果。
@immutable
class ExportResult {
  const ExportResult({
    required this.format,
    required this.recordCount,
    required this.excludedFields,
    required this.excludedTags,
    required this.payloadText,
  });

  factory ExportResult.fromJson(Map<String, Object?> json) {
    final String rawFormat = (json['format'] as String? ?? 'json').trim();
    final Object? rawFields = json['excluded_fields'];
    final Object? rawTags = json['excluded_tags'];
    return ExportResult(
      format: rawFormat == 'csv' ? ExportFormat.csv : ExportFormat.json,
      recordCount: (json['record_count'] as num?)?.toInt() ?? 0,
      excludedFields: rawFields is List<Object?>
          ? rawFields.map((Object? v) => v.toString()).toList(growable: false)
          : const <String>[],
      excludedTags: rawTags is List<Object?>
          ? rawTags.map((Object? v) => v.toString()).toList(growable: false)
          : const <String>[],
      payloadText: json['payload_text'] as String? ?? '',
    );
  }

  final ExportFormat format;
  final int recordCount;
  final List<String> excludedFields;
  final List<String> excludedTags;
  final String payloadText;
}

/// インポート済みデータおよび JSONB 属性スキーマのワークスペース状態。
@immutable
class FormatImporterSnapshot {
  const FormatImporterSnapshot({
    required this.records,
    required this.customAttributes,
  });

  final List<ImportedDataRecord> records;
  final List<CustomAttributeDefinition> customAttributes;
}

/// `app-hub` バックエンドまたはテスト用インメモリリポジトリ境界。
abstract class FormatImporterRepository {
  Future<FormatImporterSnapshot> loadWorkspace();

  Future<List<ImportedDataRecord>> importPayload({
    required ImportFormat sourceFormat,
    required String formatProfile,
    required String payload,
    required Map<String, String> fieldMapping,
    required List<String> tags,
    required Map<String, Object?> customAttributes,
    String rootPath = '',
  });

  Future<CustomAttributeDefinition> defineCustomAttribute({
    required String key,
    required String label,
    required CustomAttributeType valueType,
    bool required = false,
    Object? defaultValue,
  });

  Future<ImportedDataRecord> updateRecordAttributes({
    required String recordId,
    required Map<String, Object?> customAttributes,
    List<String>? tags,
  });

  Future<ExportResult> exportFilteredRecords({
    required ExportFormat format,
    required List<String> excludedFields,
    required List<String> excludedTags,
  });
}
