import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/services/gamification_service.dart';

// モッククラスの生成用アノテーション
// テスト実行前に `flutter pub run build_runner build` を実行してください
@GenerateMocks([SupabaseClient])
import 'gamification_service_test.mocks.dart';

void main() {
  group('GamificationService Tests', () {
    late GamificationService gamificationService;
    late MockSupabaseClient mockSupabaseClient;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      // 現在の実装ではコンストラクタ引数は dynamic ですが、
      // 将来的に SupabaseClient を受け取ることを想定してモックを渡します
      gamificationService = GamificationService(mockSupabaseClient);
    });

    // --- 1. 初期状態の検証 ---

    test('初期化時にカテゴリが正しく設定されていること', () {
      // 各カテゴリgetterの検証
      expect(gamificationService.general.id, 'general');
      expect(gamificationService.notes.id, 'notes');
      expect(gamificationService.categories.id, 'categories');
      expect(gamificationService.sharing.id, 'sharing');
      expect(gamificationService.organization.id, 'organization');
      expect(gamificationService.streak.id, 'streak');

      // 全カテゴリリストの検証
      expect(gamificationService.achievementCategories.length, 6);
      expect(
        gamificationService.achievementCategories,
        contains(gamificationService.general),
      );
    });

    test('初期ポイントと実績が空であること', () {
      expect(gamificationService.totalPoints, 0);
      expect(gamificationService.recentUnlocked, isEmpty);
    });

    // --- 2. ロジック検証 & 状態通知 ---

    test('awardPoints: ポイント付与時にリスナーに通知されること', () async {
      // Arrange
      const points = 100;
      const reason = 'クエスト達成';
      bool listenerCalled = false;

      gamificationService.addListener(() {
        listenerCalled = true;
      });

      // Act
      await gamificationService.awardPoints(points, reason: reason);

      // Assert
      expect(listenerCalled, isTrue, reason: 'notifyListeners() が呼ばれるべきです');
    });

    test('awardPoints: reasonがnullの場合でも正常に完了し通知されること', () async {
      // Arrange
      const points = 50;
      bool listenerCalled = false;
      gamificationService.addListener(() {
        listenerCalled = true;
      });

      // Act & Assert
      await gamificationService.awardPoints(points, reason: null);
      expect(listenerCalled, isTrue);
    });

    test('checkAchievements: 実行時にリスナーに通知されること', () async {
      // Arrange
      bool listenerCalled = false;
      gamificationService.addListener(() {
        listenerCalled = true;
      });

      // Act
      await gamificationService.checkAchievements();

      // Assert
      expect(listenerCalled, isTrue);
    });

    // --- 3. 異常系・境界値・スタブの検証 (カバレッジ確保) ---

    test('awardPoints: 0ポイントや負のポイントでもエラーにならないこと（境界値）', () async {
      // Act & Assert
      await expectLater(
        gamificationService.awardPoints(0, reason: 'Zero points'),
        completes,
      );
      await expectLater(
        gamificationService.awardPoints(-10, reason: 'Penalty'),
        completes,
      );
    });

    test('スタブメソッドがエラーなく完了し、デフォルト値を返すこと', () async {
      expect(await gamificationService.getUserStats(), isNull);
      expect(await gamificationService.getUserAchievements(), isEmpty);

      await expectLater(gamificationService.initializeUserStats(), completes);
    });
  });
}
