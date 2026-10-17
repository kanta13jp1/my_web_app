import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/platform_release_checklist.dart';

void main() {
  test('defaults every platform to untested and round-trips local data', () {
    const checklist = PlatformReleaseChecklist(
      sharedScope: '保存前の入力を閉じる確認',
      notes: <String, String>{'Web': 'Chrome で確認'},
      statuses: <String, PlatformCheckStatus>{
        'Web': PlatformCheckStatus.passed,
        'iOS': PlatformCheckStatus.failed,
      },
    );

    final restored = PlatformReleaseChecklist.fromJson(
      checklist.toJson().cast<String, Object?>(),
    );

    expect(restored.statusFor('Web'), PlatformCheckStatus.passed);
    expect(restored.statusFor('iOS'), PlatformCheckStatus.failed);
    expect(restored.statusFor('Android'), PlatformCheckStatus.untested);
    expect(restored.notes['Web'], 'Chrome で確認');
  });

  test('share text keeps each platform status separate', () {
    const checklist = PlatformReleaseChecklist(
      sharedScope: '入力保護',
      statuses: <String, PlatformCheckStatus>{
        'Web': PlatformCheckStatus.passed,
        'iOS': PlatformCheckStatus.untested,
        'Android': PlatformCheckStatus.notApplicable,
      },
    );

    expect(
      checklist.toShareText(),
      contains('Web: 確認済み'),
    );
    expect(checklist.toShareText(), contains('iOS: 未確認'));
    expect(checklist.toShareText(), contains('Android: 対象外'));
  });

  test('rejects malformed persisted values instead of inventing a status', () {
    expect(
      () => PlatformReleaseChecklist.fromJson(<String, Object?>{
        'sharedScope': 42,
      }),
      throwsFormatException,
    );
    expect(
      () => PlatformReleaseChecklist.fromJson(<String, Object?>{
        'statuses': <String, String>{'iOS': 'finished'},
      }),
      throwsFormatException,
    );
  });
}
