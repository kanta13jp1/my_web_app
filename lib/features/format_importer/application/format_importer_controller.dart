import 'package:flutter/foundation.dart';

import '../domain/format_importer_models.dart';

/// 汎用フォーマットインポート・JSONB属性定義・動的除外エクスポート状態管理 (#2741)。
class FormatImporterController extends ChangeNotifier {
  FormatImporterController({
    required FormatImporterRepository repository,
    FormatImporterSnapshot? initialSnapshot,
  })  : _repository = repository,
        _records = List<ImportedDataRecord>.from(
          initialSnapshot?.records ?? const <ImportedDataRecord>[],
        ),
        _customAttributes = List<CustomAttributeDefinition>.from(
          initialSnapshot?.customAttributes ??
              const <CustomAttributeDefinition>[],
        ) {
    if (_records.isNotEmpty) {
      _selectedRecordId = _records.first.id;
    }
  }

  static final RegExp _attributeKeyPattern = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  final FormatImporterRepository _repository;
  final List<ImportedDataRecord> _records;
  final List<CustomAttributeDefinition> _customAttributes;

  bool _isBusy = false;
  bool _disposed = false;
  String? _selectedRecordId;
  ExportResult? _latestExport;
  String _statusMessage = '';
  String _errorMessage = '';

  List<ImportedDataRecord> get records =>
      List<ImportedDataRecord>.unmodifiable(_records);
  List<CustomAttributeDefinition> get customAttributes =>
      List<CustomAttributeDefinition>.unmodifiable(_customAttributes);
  bool get isBusy => _isBusy;
  String? get selectedRecordId => _selectedRecordId;
  ExportResult? get latestExport => _latestExport;
  String get statusMessage => _statusMessage;
  String get errorMessage => _errorMessage;

  ImportedDataRecord? get selectedRecord {
    final String? id = _selectedRecordId;
    if (id == null) {
      return _records.isEmpty ? null : _records.first;
    }
    for (final ImportedDataRecord item in _records) {
      if (item.id == id) {
        return item;
      }
    }
    return _records.isEmpty ? null : _records.first;
  }

  void selectRecord(String recordId) {
    _selectedRecordId = recordId;
    _notifySafely();
  }

  /// `target=source.path` 形式の複数行マッピング定義を解析する。
  static Map<String, String> parseMappingLines(String rawMapping) {
    final Map<String, String> mapping = <String, String>{};
    for (final String rawLine in rawMapping.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final int eqIndex = line.indexOf('=');
      if (eqIndex <= 0 || eqIndex >= line.length - 1) {
        continue;
      }
      final String target = line.substring(0, eqIndex).trim();
      final String source = line.substring(eqIndex + 1).trim();
      if (target.isNotEmpty && source.isNotEmpty) {
        mapping[target] = source;
      }
    }
    return mapping;
  }

  /// カンマ区切りリストを正規化する。
  static List<String> parseCommaList(String raw) {
    return raw
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> loadWorkspace() async {
    _setBusy(true);
    _clearFeedback();
    try {
      final FormatImporterSnapshot snapshot = await _repository.loadWorkspace();
      _records
        ..clear()
        ..addAll(snapshot.records);
      _customAttributes
        ..clear()
        ..addAll(snapshot.customAttributes);
      if (_records.isNotEmpty && selectedRecord == null) {
        _selectedRecordId = _records.first.id;
      }
      _statusMessage =
          '${_records.length} 件のレコードと ${_customAttributes.length} 件のカスタム属性を読み込みました';
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> importPayload({
    required ImportFormat sourceFormat,
    required String formatProfile,
    required String payload,
    required String mappingText,
    required String tagsCsv,
    String rootPath = '',
    Map<String, Object?> customAttributes = const <String, Object?>{},
  }) async {
    final String trimmedPayload = payload.trim();
    if (trimmedPayload.isEmpty) {
      _errorMessage = 'インポートする JSON または CSV ペイロードを入力してください';
      _statusMessage = '';
      _notifySafely();
      return false;
    }

    _setBusy(true);
    _clearFeedback();
    try {
      final List<ImportedDataRecord> imported = await _repository.importPayload(
        sourceFormat: sourceFormat,
        formatProfile: formatProfile.trim().isEmpty
            ? 'generic_${sourceFormat.wireValue}'
            : formatProfile.trim(),
        payload: trimmedPayload,
        fieldMapping: parseMappingLines(mappingText),
        tags: parseCommaList(tagsCsv),
        customAttributes: customAttributes,
        rootPath: rootPath.trim(),
      );
      _records.insertAll(0, imported);
      if (imported.isNotEmpty) {
        _selectedRecordId = imported.first.id;
      }
      _statusMessage = '${imported.length} 件のレコードを取り込みました';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> defineCustomAttribute({
    required String key,
    required String label,
    required CustomAttributeType valueType,
    bool required = false,
    String defaultValueRaw = '',
  }) async {
    final String cleanKey = key.trim();
    if (!_attributeKeyPattern.hasMatch(cleanKey)) {
      _errorMessage = '属性キーは英小文字始まり・英数字とアンダースコアのみ使用できます (例: priority_tier)';
      _statusMessage = '';
      _notifySafely();
      return false;
    }

    _setBusy(true);
    _clearFeedback();
    try {
      final Object? parsedDefault = _coerceInputValue(
        defaultValueRaw.trim(),
        valueType,
        allowEmptyAsNull: true,
      );
      final CustomAttributeDefinition saved =
          await _repository.defineCustomAttribute(
        key: cleanKey,
        label: label.trim().isEmpty ? cleanKey : label.trim(),
        valueType: valueType,
        required: required,
        defaultValue: parsedDefault,
      );
      final int existingIndex = _customAttributes.indexWhere(
        (CustomAttributeDefinition item) => item.key == saved.key,
      );
      if (existingIndex >= 0) {
        _customAttributes[existingIndex] = saved;
      } else {
        _customAttributes.insert(0, saved);
      }
      _statusMessage = 'JSONB カスタム属性 "${saved.key}" を保存しました（DB スキーマ変更なし）';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> updateSelectedRecordAttribute({
    required String attributeKey,
    required String rawValue,
  }) async {
    final ImportedDataRecord? target = selectedRecord;
    if (target == null) {
      _errorMessage = '更新対象のレコードを選択してください';
      _statusMessage = '';
      _notifySafely();
      return false;
    }
    final String cleanKey = attributeKey.trim();
    if (!_attributeKeyPattern.hasMatch(cleanKey)) {
      _errorMessage = '属性キーは ^[a-z][a-z0-9_]{0,63}\$ 形式で入力してください';
      _statusMessage = '';
      _notifySafely();
      return false;
    }

    _setBusy(true);
    _clearFeedback();
    try {
      final CustomAttributeType valueType = _resolveTypeForKey(cleanKey);
      final Object? typedValue = _coerceInputValue(
        rawValue.trim(),
        valueType,
        allowEmptyAsNull: false,
      );
      final Map<String, Object?> nextAttrs = <String, Object?>{
        ...target.customAttributes,
        cleanKey: typedValue,
      };
      final ImportedDataRecord updated =
          await _repository.updateRecordAttributes(
        recordId: target.id,
        customAttributes: nextAttrs,
      );
      final int idx = _records.indexWhere(
        (ImportedDataRecord item) => item.id == updated.id,
      );
      if (idx >= 0) {
        _records[idx] = updated;
      }
      _statusMessage = 'レコード ${updated.id} の JSONB 属性 "$cleanKey" を更新しました';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> exportFiltered({
    required ExportFormat format,
    required String excludedFieldsCsv,
    required String excludedTagsCsv,
  }) async {
    _setBusy(true);
    _clearFeedback();
    try {
      final ExportResult result = await _repository.exportFilteredRecords(
        format: format,
        excludedFields: parseCommaList(excludedFieldsCsv),
        excludedTags: parseCommaList(excludedTagsCsv),
      );
      _latestExport = result;
      _statusMessage =
          '${result.recordCount} 件を ${result.format.label} でエクスポートしました';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setBusy(false);
    }
  }

  CustomAttributeType _resolveTypeForKey(String key) {
    for (final CustomAttributeDefinition def in _customAttributes) {
      if (def.key == key) {
        return def.valueType;
      }
    }
    return CustomAttributeType.string;
  }

  Object? _coerceInputValue(
    String raw,
    CustomAttributeType type, {
    required bool allowEmptyAsNull,
  }) {
    if (raw.isEmpty && allowEmptyAsNull) {
      return null;
    }
    switch (type) {
      case CustomAttributeType.string:
        return raw;
      case CustomAttributeType.number:
        final num? parsed = num.tryParse(raw);
        if (parsed == null) {
          throw const FormatException('数値型の属性には有効な数値を入力してください');
        }
        return parsed;
      case CustomAttributeType.boolean:
        final String lower = raw.toLowerCase();
        if (lower == 'true' || lower == '1') {
          return true;
        }
        if (lower == 'false' || lower == '0') {
          return false;
        }
        throw const FormatException('真偽値型の属性には true / false を入力してください');
      case CustomAttributeType.date:
        if (DateTime.tryParse(raw) == null) {
          throw const FormatException('日付型の属性には YYYY-MM-DD 形式で入力してください');
        }
        return raw;
      case CustomAttributeType.stringList:
        return parseCommaList(raw);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notifySafely();
  }

  void _clearFeedback() {
    _errorMessage = '';
    _statusMessage = '';
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
