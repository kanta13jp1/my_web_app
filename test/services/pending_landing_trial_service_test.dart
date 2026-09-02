import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/pending_landing_trial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips a matching trial and normalizes the email', () async {
    final now = DateTime.utc(2026, 7, 21, 1);
    final service = PendingLandingTrialService(clock: () => now);

    await service.save(
      email: ' First.User@Example.com ',
      intent: 'learning',
      prompt: 'AI学習の優先順位を決めたい',
      action: '教材を1つ選ぶ',
      reason: '選択肢を減らすと着手しやすいため',
    );

    final trial = await service.loadForEmail('first.user@example.com');
    expect(trial, isNotNull);
    expect(trial!.email, 'first.user@example.com');
    expect(trial.intent, 'learning');
    expect(trial.prompt, 'AI学習の優先順位を決めたい');
    expect(trial.action, '教材を1つ選ぶ');
    expect(trial.createdAt, now);
  });

  test('does not expose or clear a trial for another email', () async {
    final service = PendingLandingTrialService(
      clock: () => DateTime.utc(2026, 7, 21, 1),
    );
    await service.save(
      email: 'owner@example.com',
      intent: 'work',
      prompt: '今日の仕事を決めたい',
      action: '最優先を1件選ぶ',
      reason: '完了条件を固定できるため',
    );

    expect(await service.loadForEmail('other@example.com'), isNull);
    expect(await service.clearForEmail('other@example.com'), isFalse);
    expect(await service.loadForEmail('owner@example.com'), isNotNull);
  });

  test(
    'restores an OAuth trial only after an authenticated email returns',
    () async {
      final service = PendingLandingTrialService(
        clock: () => DateTime.utc(2026, 8, 19, 1),
      );
      await service.saveForOAuth(
        intent: 'work',
        prompt: '今日の最優先を決めたい',
        action: '案件を1件開く',
        reason: '着手を具体化できるため',
      );

      expect(await service.loadForEmail(null), isNull);
      final trial = await service.loadForEmail('google-user@example.com');
      expect(trial, isNotNull);
      expect(trial!.acceptsAuthenticatedUser, isTrue);
      expect(trial.email, isEmpty);
      expect(await service.clearForEmail('google-user@example.com'), isTrue);
    },
  );

  test('removes an expired trial', () async {
    var now = DateTime.utc(2026, 7, 21, 1);
    final service = PendingLandingTrialService(clock: () => now);
    await service.save(
      email: 'first@example.com',
      intent: 'money',
      prompt: '支出を確認したい',
      action: '明細を1件開く',
      reason: '現在地を数字で確認できるため',
    );
    now = now.add(const Duration(hours: 24));

    expect(await service.loadForEmail('first@example.com'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(PendingLandingTrialService.storageKey), isFalse);
  });

  test('removes malformed local data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PendingLandingTrialService.storageKey: '{not-json',
    });
    final service = PendingLandingTrialService(
      clock: () => DateTime.utc(2026, 7, 21, 1),
    );

    expect(await service.loadForEmail('first@example.com'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(PendingLandingTrialService.storageKey), isFalse);
  });
}
