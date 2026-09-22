import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/models/toeic_progress_model.dart';
import 'package:my_web_app/data/services/toeic_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists TOEIC target, performance, and practice dates', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final service = SharedPreferencesToeicProgressService(
      preferences: preferences,
    );

    await service.save(
      const ToeicProgressModel(
        targetScore: 860,
        totalAnswered: 12,
        totalCorrect: 9,
        answeredByPart: <String, int>{'part5': 8, 'part7': 4},
        correctByPart: <String, int>{'part5': 7, 'part7': 2},
        practiceDateKeys: <String>['2026-08-22', '2026-08-23'],
      ),
    );
    final restored = await service.load();

    expect(restored.targetScore, 860);
    expect(restored.totalAnswered, 12);
    expect(restored.totalCorrect, 9);
    expect(restored.answeredByPart, <String, int>{'part5': 8, 'part7': 4});
    expect(restored.practiceDateKeys, <String>['2026-08-22', '2026-08-23']);
  });

  test('falls back to initial progress when stored JSON is invalid', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesToeicProgressService.storageKey: '{invalid',
    });
    final service = SharedPreferencesToeicProgressService(
      preferences: await SharedPreferences.getInstance(),
    );

    final restored = await service.load();

    expect(restored.targetScore, 730);
    expect(restored.totalAnswered, 0);
  });
}
