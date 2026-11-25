import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/format_importer/application/format_importer_controller.dart';
import 'package:my_web_app/features/format_importer/domain/format_importer_models.dart';
import 'package:my_web_app/features/format_importer/format_importer_container.dart';

class _InMemoryFormatImporterRepository implements FormatImporterRepository {
  _InMemoryFormatImporterRepository({
    this.throwOnLoad = false,
  })  : _records = <ImportedDataRecord>[
          const ImportedDataRecord(
            id: 'rec-seed-1',
            formatProfile: 'generic_json',
            sourceFormat: ImportFormat.json,
            tags: <String>['external'],
            mappedFields: <String, Object?>{
              'code': 'SEED-01',
              'internal_note': 'secret-draft',
            },
            customAttributes: <String, Object?>{
              'priority_tier': 2,
            },
            createdAtIso: '2026-11-25T00:00:00Z',
          ),
          const ImportedDataRecord(
            id: 'rec-seed-2',
            formatProfile: 'generic_csv',
            sourceFormat: ImportFormat.csv,
            tags: <String>['internal'],
            mappedFields: <String, Object?>{'code': 'SEED-INTERNAL'},
            customAttributes: <String, Object?>{},
            createdAtIso: '2026-11-25T00:01:00Z',
          ),
        ],
        _attrs = <CustomAttributeDefinition>[
          const CustomAttributeDefinition(
            id: 'attr-1',
            key: 'priority_tier',
            label: 'Priority Tier',
            valueType: CustomAttributeType.number,
            required: false,
            defaultValue: 1,
          ),
        ];

  final bool throwOnLoad;
  final List<ImportedDataRecord> _records;
  final List<CustomAttributeDefinition> _attrs;
  int _seq = 10;

  @override
  Future<FormatImporterSnapshot> loadWorkspace() async {
    if (throwOnLoad) {
      throw StateError('Simulated backend outage');
    }
    return FormatImporterSnapshot(
      records: List<ImportedDataRecord>.from(_records),
      customAttributes: List<CustomAttributeDefinition>.from(_attrs),
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
    final Map<String, Object?> mapped = <String, Object?>{};
    if (sourceFormat == ImportFormat.json) {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map<String, Object?>) {
        mapped.addAll(decoded);
      } else {
        mapped['raw_preview'] = payload;
      }
    } else {
      final List<String> lines = payload.trim().split('\n');
      mapped['row_count'] = lines.length - 1;
      mapped['mapping_keys'] = fieldMapping.keys.toList(growable: false);
    }
    final ImportedDataRecord created = ImportedDataRecord(
      id: 'rec-${_seq++}',
      formatProfile: formatProfile,
      sourceFormat: sourceFormat,
      tags: tags,
      mappedFields: mapped,
      customAttributes: customAttributes,
      createdAtIso: '2026-11-25T01:00:00Z',
    );
    _records.insert(0, created);
    return <ImportedDataRecord>[created];
  }

  @override
  Future<CustomAttributeDefinition> defineCustomAttribute({
    required String key,
    required String label,
    required CustomAttributeType valueType,
    bool required = false,
    Object? defaultValue,
  }) async {
    final CustomAttributeDefinition item = CustomAttributeDefinition(
      id: 'attr-${_seq++}',
      key: key,
      label: label,
      valueType: valueType,
      required: required,
      defaultValue: defaultValue,
    );
    _attrs.removeWhere(
      (CustomAttributeDefinition entry) => entry.key == key,
    );
    _attrs.insert(0, item);
    return item;
  }

  @override
  Future<ImportedDataRecord> updateRecordAttributes({
    required String recordId,
    required Map<String, Object?> customAttributes,
    List<String>? tags,
  }) async {
    final int idx = _records.indexWhere(
      (ImportedDataRecord item) => item.id == recordId,
    );
    if (idx < 0) {
      throw StateError('Record not found: $recordId');
    }
    final ImportedDataRecord prev = _records[idx];
    final ImportedDataRecord updated = ImportedDataRecord(
      id: prev.id,
      formatProfile: prev.formatProfile,
      sourceFormat: prev.sourceFormat,
      tags: tags ?? prev.tags,
      mappedFields: prev.mappedFields,
      customAttributes: customAttributes,
      createdAtIso: prev.createdAtIso,
    );
    _records[idx] = updated;
    return updated;
  }

  @override
  Future<ExportResult> exportFilteredRecords({
    required ExportFormat format,
    required List<String> excludedFields,
    required List<String> excludedTags,
  }) async {
    final Set<String> exFields = excludedFields.toSet();
    final Set<String> exTags =
        excludedTags.map((String t) => t.toLowerCase()).toSet();
    final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
    for (final ImportedDataRecord rec in _records) {
      final bool blocked = rec.tags.any(
        (String t) => exTags.contains(t.toLowerCase()),
      );
      if (blocked) {
        continue;
      }
      final Map<String, Object?> out = <String, Object?>{'id': rec.id};
      for (final MapEntry<String, Object?> e in rec.mappedFields.entries) {
        if (!exFields.contains(e.key)) {
          out[e.key] = e.value;
        }
      }
      for (final MapEntry<String, Object?> e in rec.customAttributes.entries) {
        if (!exFields.contains(e.key)) {
          out[e.key] = e.value;
        }
      }
      rows.add(out);
    }
    final String rendered = format == ExportFormat.csv
        ? rows.map((Map<String, Object?> r) => r.values.join(',')).join('\n')
        : const JsonEncoder.withIndent('  ').convert(rows);
    return ExportResult(
      format: format,
      recordCount: rows.length,
      excludedFields: excludedFields,
      excludedTags: excludedTags,
      payloadText: rendered,
    );
  }
}

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

Future<void> _enterTextVisible(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.enterText(finder, text);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'renders workspace, imports JSON/CSV, defines JSONB attr, updates record, and filters export',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final _InMemoryFormatImporterRepository repo =
          _InMemoryFormatImporterRepository();
      await tester.pumpWidget(
        _wrapWithMaterial(
          FormatImporterContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('SEED-01'), findsOneWidget);
      expect(find.textContaining('priority_tier (number)'), findsOneWidget);

      // 1. Define a new JSONB attribute without schema changes.
      await _enterTextVisible(
        tester,
        find.byKey(const ValueKey<String>('format_importer_attr_key_field')),
        'region_zone',
      );
      await _enterTextVisible(
        tester,
        find.byKey(const ValueKey<String>('format_importer_attr_label_field')),
        'Region Zone',
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey<String>('format_importer_define_attr_button'),
        ),
      );
      expect(find.textContaining('region_zone (string)'), findsOneWidget);

      // 2. Import hierarchical JSON payload.
      await _enterTextVisible(
        tester,
        find.byKey(const ValueKey<String>('format_importer_payload_field')),
        '{"meta": {"code": "NEW-99", "region": "APAC"}}',
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('format_importer_submit_button')),
      );
      expect(find.textContaining('NEW-99'), findsOneWidget);

      // 3. Update selected record JSONB custom attribute.
      await _enterTextVisible(
        tester,
        find.byKey(
          const ValueKey<String>('format_importer_record_attr_key_field'),
        ),
        'region_zone',
      );
      await _enterTextVisible(
        tester,
        find.byKey(
          const ValueKey<String>('format_importer_record_attr_val_field'),
        ),
        'JP-EAST',
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey<String>('format_importer_save_record_attr_button'),
        ),
      );
      expect(find.textContaining('JP-EAST'), findsOneWidget);

      // 4. Export while excluding internal_note field & internal tag.
      await _tapVisible(
        tester,
        find.byKey(const ValueKey<String>('format_importer_export_button')),
      );
      final Finder exportFinder = find.byKey(
        const ValueKey<String>('format_importer_export_output'),
      );
      await tester.ensureVisible(exportFinder);
      await tester.pumpAndSettle();
      final SelectableText exportWidget = tester.widget<SelectableText>(
        exportFinder,
      );
      final String exported = exportWidget.data ?? '';
      expect(exported.contains('SEED-01'), isTrue);
      expect(exported.contains('SEED-INTERNAL'), isFalse);
      expect(exported.contains('secret-draft'), isFalse);
    },
  );

  testWidgets('renders cleanly across 360x800 and 1280x800 viewports', (
    WidgetTester tester,
  ) async {
    for (final Size viewport in const <Size>[
      Size(360, 800),
      Size(1280, 800),
    ]) {
      await tester.binding.setSurfaceSize(viewport);
      await tester.pumpWidget(
        _wrapWithMaterial(
          FormatImporterContainer(
            repository: _InMemoryFormatImporterRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('surfaces load errors and validates invalid attribute keys', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final _InMemoryFormatImporterRepository failingRepo =
        _InMemoryFormatImporterRepository(throwOnLoad: true);
    await tester.pumpWidget(
      _wrapWithMaterial(
        FormatImporterContainer(repository: failingRepo),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('format_importer_error_banner')),
      findsOneWidget,
    );

    final FormatImporterController ctrl = FormatImporterController(
      repository: _InMemoryFormatImporterRepository(),
    );
    final bool ok = await ctrl.defineCustomAttribute(
      key: 'Invalid-Key!',
      label: 'Bad',
      valueType: CustomAttributeType.string,
    );
    expect(ok, isFalse);
    expect(ctrl.errorMessage, isNotEmpty);
    ctrl.dispose();
  });

  testWidgets('controller survives safe disposal mid-lifecycle', (
    WidgetTester tester,
  ) async {
    final FormatImporterController ctrl = FormatImporterController(
      repository: _InMemoryFormatImporterRepository(),
    );
    ctrl.dispose();
    // Should not throw after disposal.
    ctrl.selectRecord('rec-seed-1');
  });
}
