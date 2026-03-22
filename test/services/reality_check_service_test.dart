import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/reality_check_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('addEntry stores entry and updates today count and streak', () async {
    const service = RealityCheckService();

    var result = await service.addEntry(
      category: '仕事と金',
      claim: '今の収入構造では固定費が重い',
      observableFacts: '今月の固定費は8万円で、手取りは18万円だった',
      interpretation: '転職しかないとはまだ断定できない',
      nextAction: '固定費を3件見直す',
      now: DateTime(2026, 3, 22, 9),
    );

    expect(result.entries, hasLength(1));
    expect(result.stats.reviewedTodayCount, 1);
    expect(result.stats.currentStreak, 1);
    expect(result.stats.categoriesCoveredToday, contains('仕事と金'));

    result = await service.addEntry(
      category: '能力と言論',
      claim: '議論になると押し切られやすい',
      observableFacts: '先週の会議で反論の根拠を3回詰め切れなかった',
      interpretation: '自分が常に負けるとまではまだ言えない',
      nextAction: '次回の会議前に論点を3つメモする',
      now: DateTime(2026, 3, 23, 8),
    );

    expect(result.entries, hasLength(2));
    expect(result.stats.reviewedTodayCount, 1);
    expect(result.stats.currentStreak, 2);
    expect(result.stats.categoriesCoveredToday, contains('能力と言論'));
  });
}
