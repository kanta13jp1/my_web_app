import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_hub_chat_service.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';

void main() {
  setUp(AiHubChatQuotaGuard.resetForTesting);
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
    final review = await service.generateReview(snapshot);
    expect(calls, 0);
    expect(review.summary, contains('採点'));
    expect(review.summary, contains('未記録日は不明'));
  });

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

    final review = await service.generateReview(snapshot);

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

    final review = await service.generateReview(snapshot);

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
      final review = await service.generateReview(_buildSnapshot());
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
