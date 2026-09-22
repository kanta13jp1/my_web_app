import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/procrastination_reset/data/procrastination_reset_gateway.dart';
import 'package:my_web_app/ui/features/procrastination_reset/domain/procrastination_reset_models.dart';
import 'package:my_web_app/ui/features/procrastination_reset/view_models/procrastination_reset_view_model.dart';

void main() {
  group('ProcrastinationResetViewModel', () {
    test('入力を整えて5分プランを保存する', () async {
      final gateway = _MemoryGateway();
      final now = DateTime(2026, 8, 24, 12);
      final viewModel = ProcrastinationResetViewModel(
        gateway: gateway,
        now: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPlan(
        task: '  記事を   書く  ',
        fiveMinuteAction: ' タイトル案を3つ書く ',
        firstMove: ' メモを開く ',
        barrier: DistractionBarrier.notificationsOff,
      );

      expect(created, isTrue);
      expect(viewModel.session?.task, '記事を 書く');
      expect(viewModel.session?.fiveMinuteAction, 'タイトル案を3つ書く');
      expect(viewModel.session?.firstMove, 'メモを開く');
      expect(viewModel.session?.barrier, DistractionBarrier.notificationsOff);
      expect(gateway.snapshot.session?.createdAt, now);
    });

    test('最初の一手を開始し、完了すると回数を加算してプランを空にする', () async {
      final gateway = _MemoryGateway();
      final now = DateTime(2026, 8, 24, 12);
      final viewModel = ProcrastinationResetViewModel(
        gateway: gateway,
        now: () => now,
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();
      await viewModel.createPlan(
        task: '確定申告をする',
        fiveMinuteAction: '領収書を1枚記録する',
        firstMove: '会計画面を開く',
        barrier: DistractionBarrier.outOfSight,
      );

      expect(await viewModel.startSession(), isTrue);
      expect(viewModel.session?.startedAt, now);
      expect(viewModel.remainingSeconds, 300);

      expect(await viewModel.completeSession(), isTrue);
      expect(viewModel.session, isNull);
      expect(viewModel.completedCount, 1);
      expect(viewModel.lastCompletedAction, '領収書を1枚記録する');
      expect(gateway.snapshot.lastCompletedAt, now);
    });

    test('開始済みプランは経過時間を差し引いて復元する', () async {
      final now = DateTime(2026, 8, 24, 12, 5);
      final gateway = _MemoryGateway(
        ProcrastinationResetSnapshot(
          session: ProcrastinationResetSession(
            task: '営業する',
            fiveMinuteAction: '送付先を1件調べる',
            firstMove: '顧客リストを開く',
            barrier: DistractionBarrier.anotherRoom,
            createdAt: DateTime(2026, 8, 24, 12),
            startedAt: DateTime(2026, 8, 24, 12, 3),
          ),
        ),
      );
      final viewModel = ProcrastinationResetViewModel(
        gateway: gateway,
        now: () => now,
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.remainingSeconds, 180);
    });

    test('空の入力は保存せず、具体的なエラーを返す', () async {
      final gateway = _MemoryGateway();
      final viewModel = ProcrastinationResetViewModel(gateway: gateway);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPlan(
        task: '',
        fiveMinuteAction: '1件調べる',
        firstMove: '一覧を開く',
        barrier: DistractionBarrier.anotherRoom,
      );

      expect(created, isFalse);
      expect(viewModel.errorMessage, contains('先延ばししていること'));
      expect(gateway.saveCount, 0);
    });
  });
}

class _MemoryGateway implements ProcrastinationResetGateway {
  _MemoryGateway([this.snapshot = const ProcrastinationResetSnapshot()]);

  ProcrastinationResetSnapshot snapshot;
  int saveCount = 0;

  @override
  Future<ProcrastinationResetSnapshot> load() async => snapshot;

  @override
  Future<void> save(ProcrastinationResetSnapshot snapshot) async {
    saveCount += 1;
    this.snapshot = snapshot;
  }
}
