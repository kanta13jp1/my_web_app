import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/offline_secure_mode_settings_page.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuditGateway implements OfflineSecureModeAuditGateway {
  final List<OfflineSecureModeAuditEntry> entries =
      <OfflineSecureModeAuditEntry>[];
  int listCalls = 0;

  @override
  Future<List<OfflineSecureModeAuditEntry>> listRecent({int limit = 10}) async {
    listCalls += 1;
    return entries.take(limit).toList(growable: false);
  }

  @override
  Future<bool> recordPolicyEvent({
    required OfflineSecureModeSettings settings,
    required String auditAction,
    required String status,
  }) async {
    entries.insert(
      0,
      OfflineSecureModeAuditEntry(
        id: 'audit-${entries.length + 1}',
        action: auditAction,
        provider: settings.inferenceEngine,
        status: status,
        secureModeEnabled: settings.enabled,
        externalApiBlocked: settings.externalApiBlocked,
        memoryLimitMb: settings.memoryLimitMb,
        localRuntimeConfigured: settings.localRuntimeConfigured,
        recordedAt: '2026-11-25T14:05:00Z',
      ),
    );
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'toggles secure mode, displays 8GB RAM guard, and persists audit trail',
      (WidgetTester tester) async {
    final auditGateway = _FakeAuditGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: OfflineSecureModeSettingsPage(
          auditGateway: auditGateway,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('オンラインLLM許可'), findsOneWidget);
    expect(find.textContaining('8192 MB (8GB RAM制約対応)'), findsOneWidget);

    final toggle = find.byKey(
      const ValueKey<String>('offline_secure_mode_switch'),
    );
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.text('外部API遮断中'), findsOneWidget);

    final saveButton = find.byKey(
      const ValueKey<String>('offline_save_button'),
    );
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(auditGateway.entries, hasLength(1));
    expect(auditGateway.entries.single.externalApiBlocked, isTrue);
    expect(auditGateway.entries.single.memoryLimitMb, 8192);

    final auditSection = find.byKey(
      const ValueKey<String>('offline_audit_section'),
    );
    await tester.scrollUntilVisible(
      auditSection,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('settings.update · external_api_blocked'),
      findsOneWidget,
    );
  });

  testWidgets('renders safely without Supabase initialized across viewports',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OfflineSecureModeSettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('オンラインLLM許可'), findsOneWidget);
    for (final Size viewport in const <Size>[
      Size(360, 800),
      Size(1280, 800),
    ]) {
      await tester.binding.setSurfaceSize(viewport);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
