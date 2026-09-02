import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';

void main() {
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
    expect(review.summary, contains('AI連携に失敗しました。浪費抑制スコア'));
    expect(review.summary, isNot(contains('。。')));
  });
}

AssetWasteTrainingSnapshot _buildSnapshot({
  int totalExpense = 100000,
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
    expenseEntryCount: 24,
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
