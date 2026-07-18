import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/version_check_service.dart';

void main() {
  final service = VersionCheckService();

  group('VersionCheckService.isOutdated', () {
    test('newer patch version is outdated', () {
      expect(service.isOutdated('1.0.1728', '1.0.1729'), isTrue);
    });

    test('identical version is not outdated', () {
      expect(service.isOutdated('1.0.1728', '1.0.1728'), isFalse);
    });

    test('older latest is not outdated (no downgrade prompt)', () {
      expect(service.isOutdated('1.0.1729', '1.0.1728'), isFalse);
    });

    test('newer minor or major is outdated', () {
      expect(service.isOutdated('1.0.9', '1.1.0'), isTrue);
      expect(service.isOutdated('1.9.9', '2.0.0'), isTrue);
    });

    test('higher major dominates a much higher patch', () {
      // current major 2 > latest major 1, so not outdated despite latest patch.
      expect(service.isOutdated('2.0.0', '1.0.9999'), isFalse);
    });

    test('missing trailing segment is treated as zero', () {
      expect(service.isOutdated('1.0', '1.0.1'), isTrue);
      expect(service.isOutdated('1.0.1', '1.0'), isFalse);
    });

    test('non-numeric segment is treated as zero without crashing', () {
      expect(service.isOutdated('1.0.x', '1.0.1'), isTrue);
      expect(service.isOutdated('1.0.1', '1.0.x'), isFalse);
    });
  });

  group('VersionCheckService.shouldCheck (checkNow cooldown)', () {
    test('first check (no previous timestamp) is allowed', () {
      final s = VersionCheckService();
      expect(s.shouldCheck(DateTime(2026, 7, 17, 9, 0)), isTrue);
    });

    test('check within 5 minutes of the previous one is suppressed', () {
      final s = VersionCheckService();
      s.debugSetLastCheckedAt(DateTime(2026, 7, 17, 9, 0));
      // フォーカス往復相当: 数秒〜数分後の再チェックは抑制される。
      expect(s.shouldCheck(DateTime(2026, 7, 17, 9, 0, 30)), isFalse);
      expect(s.shouldCheck(DateTime(2026, 7, 17, 9, 4, 59)), isFalse);
    });

    test('check after the 5 minute gap is allowed again', () {
      final s = VersionCheckService();
      s.debugSetLastCheckedAt(DateTime(2026, 7, 17, 9, 0));
      expect(s.shouldCheck(DateTime(2026, 7, 17, 9, 5)), isTrue);
      // 30分ポーリングは常に gap より長いので影響を受けない。
      expect(s.shouldCheck(DateTime(2026, 7, 17, 9, 30)), isTrue);
    });
  });
}
