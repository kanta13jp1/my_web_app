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
}
