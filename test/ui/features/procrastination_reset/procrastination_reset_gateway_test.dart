import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/procrastination_reset/data/procrastination_reset_gateway.dart';
import 'package:my_web_app/ui/features/procrastination_reset/domain/procrastination_reset_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('端末内に実行中プランと完了回数を保存して復元する', () async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = SharedPreferencesProcrastinationResetGateway(
      preferences: preferences,
    );
    final createdAt = DateTime(2026, 8, 24, 12);
    final startedAt = DateTime(2026, 8, 24, 12, 1);
    final snapshot = ProcrastinationResetSnapshot(
      session: ProcrastinationResetSession(
        task: '記事を書く',
        fiveMinuteAction: 'タイトル案を3つ書く',
        firstMove: 'メモを開く',
        barrier: DistractionBarrier.anotherRoom,
        createdAt: createdAt,
        startedAt: startedAt,
      ),
      completedCount: 4,
      lastCompletedAt: DateTime(2026, 8, 23, 9),
    );

    await gateway.save(snapshot);
    final restored = await gateway.load();

    expect(restored.completedCount, 4);
    expect(restored.session?.task, '記事を書く');
    expect(restored.session?.fiveMinuteAction, 'タイトル案を3つ書く');
    expect(restored.session?.firstMove, 'メモを開く');
    expect(restored.session?.barrier, DistractionBarrier.anotherRoom);
    expect(restored.session?.createdAt, createdAt);
    expect(restored.session?.startedAt, startedAt);
  });

  test('壊れた保存値は空の状態として安全に扱う', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPreferencesProcrastinationResetGateway.storageKey: '{broken',
    });
    final gateway = SharedPreferencesProcrastinationResetGateway(
      preferences: await SharedPreferences.getInstance(),
    );

    final restored = await gateway.load();

    expect(restored.session, isNull);
    expect(restored.completedCount, 0);
  });
}
