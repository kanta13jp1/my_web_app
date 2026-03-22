import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/thought_anchor_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('completeSession stores records and updates daily stats', () async {
    const service = ThoughtAnchorService();

    var result = await service.completeSession(
      anchorText: '会議で伝える論点を3つ整理する',
      whyNow: 'これを先に固めないと他の作業がぼやける',
      returnPhrase: '今は論点に戻る',
      durationMinutes: 10,
      distractionNotes: const <String>['昼食のことを考えた'],
      completedAt: DateTime(2026, 3, 22, 9),
    );

    expect(result.records, hasLength(1));
    expect(result.record.distractionCount, 1);
    expect(result.stats.sessionsCompletedToday, 1);
    expect(result.stats.currentStreak, 1);
    expect(result.stats.distractionNotesToday, 1);

    result = await service.completeSession(
      anchorText: '資料の構成を決める',
      whyNow: '午後の作業の前提になる',
      returnPhrase: '今は資料構成に戻る',
      durationMinutes: 5,
      distractionNotes: const <String>['SNSの通知が気になった', '別件の連絡を思い出した'],
      completedAt: DateTime(2026, 3, 23, 8),
    );

    expect(result.records, hasLength(2));
    expect(result.stats.sessionsCompletedToday, 1);
    expect(result.stats.currentStreak, 2);
    expect(result.stats.distractionNotesToday, 2);
  });
}
