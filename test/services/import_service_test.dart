import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/import_service.dart';
import 'package:my_web_app/services/gamification_service.dart';

// モック用のGamificationService
class MockGamificationService extends GamificationService {
  int awardedPoints = 0;
  String? lastReason;

  @override
  Future<void> awardPoints(int points, {String? reason}) async {
    awardedPoints += points;
    lastReason = reason;
  }
}

void main() {
  group('ImportService Tests', () {
    late ImportService importService;
    late MockGamificationService mockGamificationService;

    setUp(() {
      mockGamificationService = MockGamificationService();
      importService = ImportService(mockGamificationService);
    });

    test('importData awards correct points', () async {
      await importService.importData();
      expect(mockGamificationService.awardedPoints, 50);
      expect(mockGamificationService.lastReason, 'Import Data');
    });

    test('importNotes awards points based on note count', () async {
      final notes = List.generate(5, (index) => {'title': 'Note $index'});

      await importService.importNotes(
        userId: 'test-user',
        notes: notes,
        categoryId: 'general',
      );

      // 10 points per note * 5 notes = 50 points
      expect(mockGamificationService.awardedPoints, 50);
      expect(mockGamificationService.lastReason, 'Imported 5 notes');
    });
  });
}
