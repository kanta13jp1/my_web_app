import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/offline_secure_mode_settings_service.dart';
import 'package:my_web_app/services/supabase_trace_context.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    AiHubChatQuotaGuard.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
  test('empty records are unscored and never invoke AI', () async {
    var calls = 0;
    final snapshot = _buildSnapshot(
      expenseEntryCount: 0,
      recordedExpenseDays: 0,
      totalExpense: 0,
    );
    final service = AssetWasteTrainingAiService(
      invoker: (_) async {
        calls += 1;
        return {'success': true, 'text': 'unused'};
      },
    );
    expect(snapshot.disciplineScore, 0);
    for (final signedIn in const [false, true]) {
      final review = await service.generateReview(
        snapshot,
        isAuthenticated: signedIn,
      );
      expect(review.source, 'local-observation-check');
      expect(review.summary, contains('採点'));
      expect(review.summary, contains('未記録日は不明'));
    }
    expect(calls, 0);
  });

  test('guest gets local KPI and authenticated review can use the same records',
      () async {
    var calls = 0;
    final service = AssetWasteTrainingAiService(
      invoker: (_) async {
        calls += 1;
        return {'success': true, 'text': 'fixture provider summary'};
      },
    );
    final snapshot = _buildSnapshot();

    final guest = await service.generateReview(
      snapshot,
      isAuthenticated: false,
    );
    expect(calls, 0);
    expect(guest.isFallback, isTrue);
    expect(guest.source, 'local-kpi-engine');
    expect(guest.summary, contains('ログイン'));
    expect(guest.summary, contains('${snapshot.disciplineScore}点'));

    final authenticated = await service.generateReview(
      snapshot,
      isAuthenticated: true,
    );
    expect(calls, 1);
    expect(authenticated.isFallback, isFalse);
    expect(authenticated.summary, 'fixture provider summary');
  });

  test('transport rejection produces only the existing safe local fallback',
      () async {
    final service = AssetWasteTrainingAiService(
      invoker: (_) async => throw const SupabaseRequestSendRejected(),
    );

    final review = await service.generateReview(
      _buildSnapshot(),
      isAuthenticated: true,
    );

    expect(review.isFallback, isTrue);
    expect(review.source, 'local-kpi-engine');
    expect(review.summary, contains('認証またはアクセス権'));
    expect(review.summary, isNot(contains('login_required')));
    expect(const SupabaseRequestSendRejected().toString(), 'login_required');
  });

  for (final change in const ['owner-change', 'logout']) {
    test('offline-policy wait then $change aborts at the scoped transport',
        () async {
      Session? session = _fixtureSession();
      final settings = _DelayedOfflineSettingsService();
      var sends = 0;
      final transport = SupabaseTracingHttpClient(
        inner: MockClient((_) async {
          sends += 1;
          return http.Response('{}', 200);
        }),
        traceContextProvider: () async => const SupabaseTraceContext(
          traceparent:
              '00-11111111111111111111111111111111-2222222222222222-01',
        ),
      );
      addTearDown(transport.close);
      final guard = AssetWasteTrainingOwnerSendGuard(
        expectedOwnerId: 'fixture-owner-a',
        supabaseOrigin: Uri.parse('https://fixture.supabase.invalid'),
        readCurrentSession: () => session,
      );
      final service = AssetWasteTrainingAiService(
        chatService: AiHubChatService(
          offlineSettingsService: settings,
          invoker: (_) => runWithSupabaseRequestSendValidator(
            guard.allows,
            () async {
              final request = http.Request(
                'POST',
                Uri.parse(
                  'https://fixture.supabase.invalid/functions/v1/ai-hub',
                ),
              )..headers['Authorization'] = 'Bearer fixture-token-a';
              await transport.send(request);
              return <String, dynamic>{
                'success': true,
                'text': 'fixture provider summary',
              };
            },
          ),
        ),
      );

      final pending = service.generateReview(
        _buildSnapshot(),
        isAuthenticated: true,
      );
      await settings.entered.future;
      session = change == 'logout'
          ? null
          : _fixtureSession(ownerId: 'fixture-owner-b');
      settings.release.complete();
      final review = await pending;

      expect(sends, 0);
      expect(review.isFallback, isTrue);
      expect(review.summary, contains('認証またはアクセス権'));
    });
  }

  test('snapshot converts waste and lockdown metrics into a training score',
      () {
    final snapshot = _buildSnapshot(
      totalExpense: 100000,
      wasteExpense: 20000,
      noWasteDays: 16,
      elapsedDays: 20,
      ruleCompletedCount: 4,
      ruleTargetCount: 5,
      todayViolationCount: 0,
    );

    expect(snapshot.wasteRatio, 0.2);
    expect(snapshot.wasteControlScore, 80);
    expect(snapshot.disciplineScore, 82);
  });

  test('generateReview returns ai-hub provider summary when available',
      () async {
    final snapshot = _buildSnapshot();
    final service = AssetWasteTrainingAiService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (body) async {
        expect(body['action'], 'provider.chat');
        expect(body['provider'], 'deepinfra');
        expect(body['message'].toString(), contains('KGI'));
        expect(body['message'].toString(), contains('浪費抑制スコア'));
        return {
          'success': true,
          'text': 'KGIは判断力を鍛えること。最大CSFは浪費ゼロ日の継続で、次は夜の衝動支出を1件止める。',
        };
      },
    );

    final review = await service.generateReview(
      snapshot,
      isAuthenticated: true,
    );

    expect(review.isFallback, isFalse);
    expect(review.source, contains('ai-hub provider.chat'));
    expect(review.summary, contains('判断力'));
  });

  test('generateReview falls back when provider fails', () async {
    final snapshot = _buildSnapshot();
    final service = AssetWasteTrainingAiService(
      now: () => DateTime(2026, 4, 22, 9, 15),
      invoker: (_) async => {'success': false, 'message': 'rate limit'},
    );

    final review = await service.generateReview(
      snapshot,
      isAuthenticated: true,
    );

    expect(review.isFallback, isTrue);
    expect(review.source, 'local-kpi-engine');
    expect(review.summary, contains('浪費抑制スコア'));
    expect(review.summary, contains('AIの利用制限により取得できませんでした'));
    expect(review.summary, isNot(contains('。。')));
  });
  final failureCases = <String, String>{
    '429 rate limit': 'AIの利用制限',
    'offline external api blocked': 'オフライン設定',
    'secret_needed MISSING_PRIVATE_KEY': 'AIの接続設定',
    '401 unauthorized': '認証またはアクセス権',
    '403 forbidden': '認証またはアクセス権',
    'TimeoutException network': 'AIとの通信を完了できませんでした',
    'unexpected private-request-fragment sk-test-secret': '原因は未確認',
  };
  for (final entry in failureCases.entries) {
    test('failure description is safe: ${entry.value}', () async {
      var calls = 0;
      final service = AssetWasteTrainingAiService(
        invoker: (_) async {
          calls += 1;
          throw AiHubChatException(entry.key);
        },
      );
      final review = await service.generateReview(
        _buildSnapshot(),
        isAuthenticated: true,
      );
      expect(calls, 1);
      expect(review.isFallback, isTrue);
      expect(review.source, 'local-kpi-engine');
      expect(review.summary, contains(entry.value));
      expect(review.summary, contains('記録から参考値'));
      expect(review.summary, isNot(contains('待機中')));
      expect(review.summary, isNot(contains('private-request-fragment')));
      expect(review.summary, isNot(contains('sk-test-secret')));
      expect(review.summary, isNot(contains('MISSING_PRIVATE_KEY')));
    });
  }
}

AssetWasteTrainingSnapshot _buildSnapshot({
  int totalExpense = 100000,
  int expenseEntryCount = 24,
  int recordedExpenseDays = 20,
  int wasteExpense = 12000,
  int noWasteDays = 18,
  int elapsedDays = 20,
  int ruleCompletedCount = 4,
  int ruleTargetCount = 5,
  int todayViolationCount = 0,
}) {
  return AssetWasteTrainingSnapshot(
    month: DateTime(2026, 4),
    monitoredAt: DateTime(2026, 4, 22, 9, 15),
    totalExpense: totalExpense,
    wasteExpense: wasteExpense,
    expenseEntryCount: expenseEntryCount,
    recordedExpenseDays: recordedExpenseDays,
    wasteEntryCount: 3,
    noWasteDays: noWasteDays,
    elapsedDays: elapsedDays,
    ruleCompletedCount: ruleCompletedCount,
    ruleTargetCount: ruleTargetCount,
    todayViolationCount: todayViolationCount,
    compliantStreakDays: 6,
    lockdownActive: true,
  );
}


class _DelayedOfflineSettingsService extends OfflineSecureModeSettingsService {
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<OfflineSecureModeSettings> loadSettingsOrDefaults({
    SharedPreferences? prefs,
  }) async {
    entered.complete();
    await release.future;
    return const OfflineSecureModeSettings();
  }
}

Session _fixtureSession({String ownerId = 'fixture-owner-a'}) => Session(
      accessToken: 'fixture-token-a',
      tokenType: 'bearer',
      user: User(
        id: ownerId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-11-11T00:00:00Z',
      ),
    );
