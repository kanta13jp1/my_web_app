import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/voice_ai_governance_page.dart';
import 'package:my_web_app/services/voice_ai_settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('consent save rejects duplicate writes and stale refresh',
      (tester) async {
    final service = _DelayedConsentService();
    await tester.pumpWidget(
      MaterialApp(home: VoiceAiGovernancePage(service: service)),
    );
    await tester.pumpAndSettle();
    final toggle = tester
        .widget<SwitchListTile>(
          find.byType(SwitchListTile),
        )
        .onChanged!;
    final refreshButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Refresh',
    );
    final refresh = tester.widget<IconButton>(refreshButton).onPressed!;
    toggle(true);
    toggle(false);
    refresh();
    await tester.pump();
    expect(service.writes, <bool>[true]);
    expect(service.loads, 1);
    expect(
      tester.widget<IconButton>(refreshButton).onPressed,
      isNull,
    );

    service.saved.complete(const VoiceAiSettings(trainingConsent: true));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(service.loads, 1);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedConsentService extends VoiceAiSettingsService {
  _DelayedConsentService() : super(_UnusedSupabaseClient());

  final saved = Completer<VoiceAiSettings>();
  final writes = <bool>[];
  int loads = 0;

  @override
  Future<VoiceAiSettings> loadSettings() async {
    loads += 1;
    return VoiceAiSettings.empty;
  }

  @override
  Future<List<VoiceAiUsageSummary>> loadUsageSummary() async => [];

  @override
  Future<VoiceAiSettings> updateTrainingConsent(bool enabled) {
    writes.add(enabled);
    return saved.future;
  }
}

// All service methods used by the page are overridden above.
class _UnusedSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
