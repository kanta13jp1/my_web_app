import 'package:flutter/material.dart';

import '../application/format_importer_controller.dart';
import '../domain/format_importer_models.dart';

/// 汎用フォーマットインポート・JSONB属性管理・動的除外エクスポート画面 (#2741)。
class FormatImporterView extends StatefulWidget {
  const FormatImporterView({
    super.key,
    required this.controller,
  });

  final FormatImporterController controller;

  @override
  State<FormatImporterView> createState() => _FormatImporterViewState();
}

class _FormatImporterViewState extends State<FormatImporterView> {
  final TextEditingController _profileController = TextEditingController(
    text: 'generic_standard',
  );
  final TextEditingController _rootPathController = TextEditingController();
  final TextEditingController _mappingController = TextEditingController(
    text: 'code=meta.code\nregion=meta.region',
  );
  final TextEditingController _tagsController = TextEditingController(
    text: 'external, sync',
  );
  final TextEditingController _payloadController = TextEditingController();
  final TextEditingController _attrKeyController = TextEditingController();
  final TextEditingController _attrLabelController = TextEditingController();
  final TextEditingController _attrDefaultController = TextEditingController();
  final TextEditingController _recordAttrKeyController =
      TextEditingController();
  final TextEditingController _recordAttrValController =
      TextEditingController();
  final TextEditingController _excludedFieldsController = TextEditingController(
    text: 'internal_note',
  );
  final TextEditingController _excludedTagsController = TextEditingController(
    text: 'internal',
  );

  ImportFormat _sourceFormat = ImportFormat.json;
  CustomAttributeType _attrType = CustomAttributeType.string;
  ExportFormat _exportFormat = ExportFormat.json;

  @override
  void dispose() {
    _profileController.dispose();
    _rootPathController.dispose();
    _mappingController.dispose();
    _tagsController.dispose();
    _payloadController.dispose();
    _attrKeyController.dispose();
    _attrLabelController.dispose();
    _attrDefaultController.dispose();
    _recordAttrKeyController.dispose();
    _recordAttrValController.dispose();
    _excludedFieldsController.dispose();
    _excludedTagsController.dispose();
    super.dispose();
  }

  Future<void> _handleImport() async {
    await widget.controller.importPayload(
      sourceFormat: _sourceFormat,
      formatProfile: _profileController.text,
      payload: _payloadController.text,
      mappingText: _mappingController.text,
      tagsCsv: _tagsController.text,
      rootPath: _rootPathController.text,
    );
  }

  Future<void> _handleDefineAttribute() async {
    final bool ok = await widget.controller.defineCustomAttribute(
      key: _attrKeyController.text,
      label: _attrLabelController.text,
      valueType: _attrType,
      defaultValueRaw: _attrDefaultController.text,
    );
    if (ok && mounted) {
      _attrKeyController.clear();
      _attrLabelController.clear();
      _attrDefaultController.clear();
    }
  }

  Future<void> _handleSaveRecordAttribute() async {
    await widget.controller.updateSelectedRecordAttribute(
      attributeKey: _recordAttrKeyController.text,
      rawValue: _recordAttrValController.text,
    );
  }

  Future<void> _handleExport() async {
    await widget.controller.exportFiltered(
      format: _exportFormat,
      excludedFieldsCsv: _excludedFieldsController.text,
      excludedTagsCsv: _excludedTagsController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final FormatImporterController ctrl = widget.controller;
        final ImportedDataRecord? selected = ctrl.selectedRecord;
        final ExportResult? latestExport = ctrl.latestExport;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '汎用フォーマット取込＆JSONBカスタム属性管理',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                '階層 JSON / 標準 CSV を動的にマッピングして取り込み、DB スキーマを変更せず '
                'JSONB 属性を追加・編集し、不要項目・タグを動的除外してエクスポートします。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (ctrl.isBusy) ...<Widget>[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (ctrl.errorMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey<String>('format_importer_error_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ctrl.errorMessage,
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ],
              if (ctrl.statusMessage.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const ValueKey<String>('format_importer_status_banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    ctrl.statusMessage,
                    style: TextStyle(color: colors.onPrimaryContainer),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildImportCard(colors),
              const SizedBox(height: 16),
              _buildAttributeDefinitionCard(ctrl, colors),
              const SizedBox(height: 16),
              _buildRecordEditorCard(ctrl, selected, colors),
              const SizedBox(height: 16),
              _buildExportCard(latestExport, colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImportCard(ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '1. 階層 JSON / CSV インポーター',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ImportFormat.values
                  .map(
                    (ImportFormat fmt) => ChoiceChip(
                      key: ValueKey<String>(
                        'format_importer_fmt_${fmt.wireValue}',
                      ),
                      label: Text(fmt.label),
                      selected: _sourceFormat == fmt,
                      onSelected: (bool picked) {
                        if (picked) {
                          setState(() => _sourceFormat = fmt);
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('format_importer_profile_field'),
              controller: _profileController,
              decoration: const InputDecoration(
                labelText: 'フォーマットプロファイル名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_root_path_field'),
              controller: _rootPathController,
              decoration: const InputDecoration(
                labelText: 'JSON ルートパス (任意: 例 envelope.entries)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_mapping_field'),
              controller: _mappingController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'フィールドマッピング (target=source.path)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_tags_field'),
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '付与タグ (カンマ区切り)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_payload_field'),
              controller: _payloadController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: '入力ペイロード (${_sourceFormat.label})',
                border: const OutlineInputBorder(),
                helperText: '階層 JSON またはヘッダ付き RFC-4180 CSV を入力',
                helperStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('format_importer_submit_button'),
              onPressed: _handleImport,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('インポート実行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeDefinitionCard(
    FormatImporterController ctrl,
    ColorScheme colors,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '2. JSONB カスタム属性定義（DB スキーマ変更不要）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_attr_key_field'),
              controller: _attrKeyController,
              decoration: const InputDecoration(
                labelText: '属性キー (例: priority_tier)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_attr_label_field'),
              controller: _attrLabelController,
              decoration: const InputDecoration(
                labelText: '表示ラベル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CustomAttributeType.values
                  .map(
                    (CustomAttributeType type) => ChoiceChip(
                      key: ValueKey<String>(
                        'format_importer_attr_type_${type.wireValue}',
                      ),
                      label: Text(type.label),
                      selected: _attrType == type,
                      onSelected: (bool picked) {
                        if (picked) {
                          setState(() => _attrType = type);
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('format_importer_attr_default_field'),
              controller: _attrDefaultController,
              decoration: const InputDecoration(
                labelText: 'デフォルト値 (任意)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey<String>('format_importer_define_attr_button'),
              onPressed: _handleDefineAttribute,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('属性を追加'),
            ),
            if (ctrl.customAttributes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ctrl.customAttributes
                    .map(
                      (CustomAttributeDefinition attr) => Chip(
                        backgroundColor: colors.surfaceContainerHighest,
                        label: Text(
                          '${attr.key} (${attr.valueType.wireValue})',
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecordEditorCard(
    FormatImporterController ctrl,
    ImportedDataRecord? selected,
    ColorScheme colors,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '3. 取込済みレコード (${ctrl.records.length} 件) ＆ JSONB 属性編集',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (ctrl.records.isEmpty)
              Text(
                '取り込み済みのレコードはまだありません。',
                style: TextStyle(color: colors.onSurfaceVariant),
              )
            else ...<Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ctrl.records
                    .map(
                      (ImportedDataRecord rec) => ChoiceChip(
                        key: ValueKey<String>(
                          'format_importer_rec_${rec.id}',
                        ),
                        label: Text('${rec.id} (${rec.formatProfile})'),
                        selected: selected?.id == rec.id,
                        onSelected: (bool picked) {
                          if (picked) {
                            ctrl.selectRecord(rec.id);
                          }
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              if (selected != null) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Mapped: ${selected.mappedFields}',
                        style: themeTextOrFallback(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JSONB Custom Attributes: ${selected.customAttributes}',
                      ),
                      const SizedBox(height: 4),
                      Text('Tags: ${selected.tags.join(', ')}'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>(
                    'format_importer_record_attr_key_field',
                  ),
                  controller: _recordAttrKeyController,
                  decoration: const InputDecoration(
                    labelText: '更新する属性キー',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey<String>(
                    'format_importer_record_attr_val_field',
                  ),
                  controller: _recordAttrValController,
                  decoration: const InputDecoration(
                    labelText: '属性値',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey<String>(
                    'format_importer_save_record_attr_button',
                  ),
                  onPressed: _handleSaveRecordAttribute,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('カスタム属性を保存'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExportCard(ExportResult? latestExport, ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text(
              '4. 動的除外フィルタ付きエクスポート',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ExportFormat.values
                  .map(
                    (ExportFormat fmt) => ChoiceChip(
                      key: ValueKey<String>(
                        'format_importer_export_fmt_${fmt.wireValue}',
                      ),
                      label: Text(fmt.label),
                      selected: _exportFormat == fmt,
                      onSelected: (bool picked) {
                        if (picked) {
                          setState(() => _exportFormat = fmt);
                        }
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>(
                'format_importer_excluded_fields_field',
              ),
              controller: _excludedFieldsController,
              decoration: const InputDecoration(
                labelText: '除外フィールド (カンマ区切り)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>(
                'format_importer_excluded_tags_field',
              ),
              controller: _excludedTagsController,
              decoration: const InputDecoration(
                labelText: '除外タグ (カンマ区切り)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey<String>('format_importer_export_button'),
              onPressed: _handleExport,
              icon: const Icon(Icons.download_outlined),
              label: const Text('エクスポート生成'),
            ),
            if (latestExport != null) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  latestExport.payloadText,
                  key: const ValueKey<String>('format_importer_export_output'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle? themeTextOrFallback(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium;
  }
}
