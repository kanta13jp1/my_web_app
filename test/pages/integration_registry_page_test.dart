import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/integration_registry.dart';
import 'package:my_web_app/pages/integration_registry_page.dart';
import 'package:my_web_app/services/csv_bytes_decoder.dart';
import 'package:my_web_app/services/integration_registry_service.dart';

class _FakeIntegrationRegistryService
    implements IntegrationRegistryServiceContract {
  int savedSystems = 0;
  int publishedInterfaces = 0;
  int importedMappings = 0;
  int impactCalls = 0;

  final IntegrationRegistrySnapshot snapshot =
      const IntegrationRegistrySnapshot(
    systems: <IntegrationSystemDefinition>[
      IntegrationSystemDefinition(
        id: 'system-1',
        systemKey: 'billing',
        name: 'Billing',
        version: 2,
        status: 'active',
        owner: 'Finance',
      ),
      IntegrationSystemDefinition(
        id: 'system-2',
        systemKey: 'ledger',
        name: 'Ledger',
        version: 1,
        status: 'active',
      ),
    ],
    systemVersions: <IntegrationSystemDefinition>[
      IntegrationSystemDefinition(
        id: 'system-1',
        systemKey: 'billing',
        name: 'Billing',
        version: 2,
        status: 'active',
      ),
      IntegrationSystemDefinition(
        id: 'system-0',
        systemKey: 'billing',
        name: 'Billing old',
        version: 1,
        status: 'deprecated',
      ),
      IntegrationSystemDefinition(
        id: 'system-2',
        systemKey: 'ledger',
        name: 'Ledger',
        version: 1,
        status: 'active',
      ),
    ],
    interfaces: <IntegrationInterfaceDefinition>[
      IntegrationInterfaceDefinition(
        id: 'if-1',
        interfaceKey: 'billing-ledger',
        name: 'Journal export',
        sourceSystemKey: 'billing',
        targetSystemKey: 'ledger',
        version: 1,
        protocol: 'SFTP',
        format: 'CSV',
        status: 'active',
        fields: <IntegrationFieldDefinition>[
          IntegrationFieldDefinition(
            name: 'journal_code',
            dataType: 'string',
            required: true,
          ),
        ],
      ),
    ],
    interfaceVersions: <IntegrationInterfaceDefinition>[
      IntegrationInterfaceDefinition(
        id: 'if-1',
        interfaceKey: 'billing-ledger',
        name: 'Journal export',
        sourceSystemKey: 'billing',
        targetSystemKey: 'ledger',
        version: 1,
        protocol: 'SFTP',
        format: 'CSV',
        status: 'active',
        fields: <IntegrationFieldDefinition>[],
      ),
    ],
    mappings: <IntegrationCodeMappingSet>[
      IntegrationCodeMappingSet(
        id: 'map-1',
        mappingKey: 'account-codes',
        name: 'Account codes',
        sourceSystemKey: 'billing',
        targetSystemKey: 'ledger',
        version: 1,
        entries: <IntegrationCodeMappingEntry>[
          IntegrationCodeMappingEntry(oldCode: '100', newCode: 'A100'),
        ],
      ),
    ],
    mappingVersions: <IntegrationCodeMappingSet>[
      IntegrationCodeMappingSet(
        id: 'map-1',
        mappingKey: 'account-codes',
        name: 'Account codes',
        sourceSystemKey: 'billing',
        targetSystemKey: 'ledger',
        version: 1,
        entries: <IntegrationCodeMappingEntry>[
          IntegrationCodeMappingEntry(oldCode: '100', newCode: 'A100'),
        ],
      ),
    ],
  );

  @override
  Future<IntegrationRegistrySnapshot> loadSnapshot() async => snapshot;

  @override
  Future<IntegrationSystemDefinition> saveSystem(
    IntegrationSystemDraft draft,
  ) async {
    savedSystems++;
    return IntegrationSystemDefinition(
      id: 'new-system',
      systemKey: draft.systemKey,
      name: draft.name,
      version: 1,
      status: draft.status,
    );
  }

  @override
  Future<IntegrationInterfaceDefinition> publishInterface(
    IntegrationInterfaceDraft draft,
  ) async {
    publishedInterfaces++;
    return IntegrationInterfaceDefinition(
      id: 'new-interface',
      interfaceKey: draft.interfaceKey,
      name: draft.name,
      sourceSystemKey: draft.sourceSystemKey,
      targetSystemKey: draft.targetSystemKey,
      version: 1,
      protocol: draft.protocol,
      format: draft.format,
      status: draft.status,
      fields: draft.fields,
    );
  }

  @override
  Future<IntegrationCodeMappingSet> importMappings(
    IntegrationMappingImportDraft draft,
  ) async {
    importedMappings++;
    return IntegrationCodeMappingSet(
      id: 'new-mapping',
      mappingKey: draft.mappingKey,
      name: draft.name,
      sourceSystemKey: draft.sourceSystemKey,
      targetSystemKey: draft.targetSystemKey,
      version: 1,
      entries: draft.entries,
    );
  }

  @override
  Future<IntegrationImpactReport> analyzeImpact(String systemKey) async {
    impactCalls++;
    return IntegrationImpactReport(
      rootSystemKey: systemKey,
      systems: snapshot.systems,
      interfaces: snapshot.interfaces,
      mappings: snapshot.mappings,
    );
  }
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeIntegrationRegistryService service, {
  IntegrationMappingCsvPicker? mappingCsvPicker,
  CsvBytesDecoder? csvBytesDecoder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: IntegrationRegistryPage(
        service: service,
        mappingCsvPicker: mappingCsvPicker,
        csvBytesDecoder: csvBytesDecoder,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  final tabText = find.descendant(
    of: find.byType(TabBar),
    matching: find.text(label),
  );
  await tester.ensureVisible(tabText);
  await tester.tap(tabText);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows versioned systems and interface inventory', (
    tester,
  ) async {
    final service = _FakeIntegrationRegistryService();
    await _pumpPage(tester, service);

    expect(find.text('Integration Registry'), findsOneWidget);
    expect(find.text('Billing'), findsOneWidget);
    expect(find.textContaining('2 versions'), findsOneWidget);

    await _tapTab(tester, 'Interfaces');
    expect(find.text('Journal export'), findsOneWidget);
    expect(find.textContaining('SFTP / CSV'), findsOneWidget);
  });

  testWidgets('imports a previewed CSV mapping', (tester) async {
    final service = _FakeIntegrationRegistryService();
    await _pumpPage(tester, service);

    await _tapTab(tester, 'Code mappings');
    await tester.tap(find.byKey(const Key('import-mapping-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('mapping-name-field')),
      'Migrated account codes',
    );
    await tester.enterText(
      find.byKey(const Key('mapping-key-field')),
      'migrated-account-codes',
    );
    final previewButton = find.byKey(const Key('preview-mapping-csv-button'));
    await tester.ensureVisible(previewButton);
    await tester.tap(previewButton);
    await tester.pumpAndSettle();

    expect(find.text('2 valid mapping rows'), findsOneWidget);
    final importButton = find.byKey(const Key('import-mapping-dialog-button'));
    await tester.ensureVisible(importButton);
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    expect(service.importedMappings, 1);
  });

  testWidgets('decodes a Shift_JIS mapping file and shows its preview', (
    tester,
  ) async {
    final service = _FakeIntegrationRegistryService();
    final bytes = Uint8List.fromList(const <int>[0x82, 0xa0]);
    await _pumpPage(
      tester,
      service,
      mappingCsvPicker: () async => bytes,
      csvBytesDecoder: CsvBytesDecoder(
        shiftJisDecoder: (_) =>
            'old_code,new_code,description\n100,A100,Revenue',
      ),
    );

    await _tapTab(tester, 'Code mappings');
    await tester.tap(find.byKey(const Key('import-mapping-button')));
    await tester.pumpAndSettle();
    final pickButton = find.byKey(const Key('pick-mapping-csv-button'));
    await tester.ensureVisible(pickButton);
    await tester.tap(pickButton);
    await tester.pumpAndSettle();

    expect(find.text('1 valid mapping rows'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('calculates and displays dependency impact', (tester) async {
    final service = _FakeIntegrationRegistryService();
    await _pumpPage(tester, service);

    await _tapTab(tester, 'Impact');
    await tester.tap(find.byKey(const Key('analyze-impact-button')));
    await tester.pumpAndSettle();

    expect(service.impactCalls, 1);
    expect(find.text('Affected systems'), findsOneWidget);
    expect(find.text('Affected interfaces'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('impact-results-list')),
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
    expect(find.text('Affected mappings'), findsOneWidget);
  });

  testWidgets('renders without overflow on a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeIntegrationRegistryService();
    await _pumpPage(tester, service);

    expect(tester.takeException(), isNull);
    await _tapTab(tester, 'Code mappings');
    expect(tester.takeException(), isNull);
  });
}
