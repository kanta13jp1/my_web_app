import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/debt_guard_repository.dart';
import 'package:my_web_app/domain/models/debt_guard_rule.dart';
import 'package:my_web_app/view_models/debt_guard_view_model.dart';
import 'package:my_web_app/widgets/debt_guard_panel.dart';

void main() {
  testWidgets('renders the canonical guard and records a check-in', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    expect(find.text('完済までの禁止事項'), findsOneWidget);
    expect(find.text('25項目'), findsOneWidget);
    expect(find.text(DebtGuardFoundationPolicy.motto), findsOneWidget);
    expect(find.text('先に守る土台（制限しない）'), findsOneWidget);
    expect(find.text('毎日の生活基盤チェック'), findsOneWidget);
    expect(find.text('その後の一歩（必須でない拡大）'), findsOneWidget);
    expect(find.text('脳内の虫（バグ）を弱らせる'), findsOneWidget);
    expect(
      find.byKey(const Key('debt-guard-rule-gambling')),
      findsOneWidget,
    );
    expect(find.text('必要な用事や生活ケアを放置したまま寝る'), findsOneWidget);

    await tester.tap(find.byTooltip('追加の借金を記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ここまで守った'));
    await tester.pumpAndSettle();

    expect(find.text('守れている 1'), findsOneWidget);
    expect(repository.events.single.type, DebtGuardEventType.checkIn);
  });

  testWidgets('shows the complete essential-action safety boundary', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    expect(
      find.byKey(const Key('debt-guard-foundation-mindset')),
      findsOneWidget,
    );
    for (final action in DebtGuardFoundationPolicy.essentialActions) {
      expect(find.textContaining(action), findsWidgets);
    }
    expect(find.textContaining('決して制限しません'), findsOneWidget);
    expect(find.textContaining('動機づけの比喩'), findsOneWidget);
    for (final task in debtGuardFoundationTasks) {
      expect(find.textContaining(task.title), findsWidgets);
    }
    for (final cadence in DebtGuardFoundationCadence.values) {
      expect(find.text(cadence.label), findsOneWidget);
    }
  });

  testWidgets('bug help records resisting a prohibited action', (tester) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byKey(const Key('debt-guard-urge-help')));
    await tester.pumpAndSettle();

    expect(find.text('脳内バグ退治'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('一時的な「脳内の虫（バグ）」'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('10分待つ'), findsOneWidget);
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(find.text('バグを弱めた 1'), findsOneWidget);
    expect(repository.events.single.type, DebtGuardEventType.urgeResisted);
  });

  testWidgets('starts a minimum foundation action in one tap', (tester) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byKey(const Key('debt-guard-start-foundation')));
    await tester.pumpAndSettle();

    expect(find.text('生活を1つ整える'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('bug-mode-start')))
          .selected,
      isTrue,
    );
    expect(find.textContaining('皿かコップを1つだけ洗う'), findsOneWidget);

    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(
      repository.events.single.type,
      DebtGuardEventType.requiredActionStarted,
    );
    expect(repository.events.single.ruleId, 'dishes_left_unwashed');
  });

  testWidgets('bug help starts a required action in a minimum unit', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byKey(const Key('debt-guard-urge-help')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bug-mode-start')));
    await tester.pumpAndSettle();

    expect(find.textContaining('皿かコップを1つだけ洗う'), findsOneWidget);
    expect(find.textContaining('2分だけ無理やり始める'), findsOneWidget);
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(find.text('バグを弱めた 1'), findsOneWidget);
    expect(
      repository.events.single.type,
      DebtGuardEventType.requiredActionStarted,
    );
    expect(repository.events.single.ruleId, 'dishes_left_unwashed');
  });

  testWidgets('a prohibited-rule dialog can switch to a required action', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byTooltip('追加の借金を記録'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('脳内バグに対処する'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bug-mode-start')));
    await tester.pumpAndSettle();

    expect(find.text('いま着手すること'), findsOneWidget);
    expect(find.textContaining('皿かコップを1つだけ洗う'), findsOneWidget);
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(
      repository.events.single.type,
      DebtGuardEventType.requiredActionStarted,
    );
    expect(repository.events.single.ruleId, 'dishes_left_unwashed');
  });

  testWidgets('uses two category columns only when width allows', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();

    await _pump(tester, viewModel, width: 1100);
    final wideCard = tester.getSize(
      find.byKey(const Key('debt-guard-category-debt')),
    );
    expect(wideCard.width, lessThan(550));

    await _pump(tester, viewModel, width: 430);
    final narrowCard = tester.getSize(
      find.byKey(const Key('debt-guard-category-debt')),
    );
    expect(narrowCard.width, greaterThan(350));
  });
}

DebtGuardViewModel _viewModel(_PanelRepository repository) {
  return DebtGuardViewModel(
    repository: repository,
    userId: 'user-1',
    clock: () => DateTime(2026, 8, 22, 10),
  );
}

Future<void> _pump(
  WidgetTester tester,
  DebtGuardViewModel viewModel, {
  required double width,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 5000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: DebtGuardPanel(
            viewModel: viewModel,
            isLocked: true,
            isPaidOff: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _PanelRepository implements DebtGuardRepository {
  final events = <DebtGuardEvent>[];
  int _nextId = 1;

  @override
  Future<List<DebtGuardEvent>> loadDailyEvents({
    required String userId,
    required DateTime date,
  }) async {
    return List.of(events);
  }

  @override
  Future<List<DebtGuardEvent>> appendEvents({
    required String userId,
    required DateTime date,
    required List<DebtGuardEventDraft> events,
  }) async {
    final inserted = [
      for (final draft in events)
        DebtGuardEvent(
          id: _nextId++,
          ruleId: draft.ruleId,
          type: draft.type,
          eventDate: DateTime(date.year, date.month, date.day),
          createdAt: date.add(Duration(microseconds: _nextId)),
          note: draft.note,
        ),
    ];
    this.events.addAll(inserted);
    return inserted;
  }
}
