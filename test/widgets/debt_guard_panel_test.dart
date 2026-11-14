import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/debt_guard_repository.dart';
import 'package:my_web_app/domain/models/debt_guard_emotion.dart';
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
    expect(find.byKey(const Key('debt-guard-rule-gambling')), findsOneWidget);
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

  testWidgets('labels the feeling behind an urge and saves it', (tester) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    expect(find.textContaining('「いまの気持ち」を選ぶと'), findsOneWidget);

    await tester.tap(find.byKey(const Key('debt-guard-urge-help')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('debt-guard-emotion-signal')), findsNothing);
    for (final emotion in DebtGuardEmotion.values) {
      expect(
        find.byKey(Key('debt-guard-emotion-${emotion.wireName}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const Key('debt-guard-emotion-boredom')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(DebtGuardEmotion.boredom.minimumAction),
      findsOneWidget,
    );
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(repository.events.single.emotion, DebtGuardEmotion.boredom);
    expect(find.text('気持ち: 退屈'), findsOneWidget);
  });

  testWidgets('one-tap trigger wording fills the note that gets saved', (
    tester,
  ) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byKey(const Key('debt-guard-urge-help')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('debt-guard-emotion-trigger-anxiety-0')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('debt-guard-emotion-anxiety')));
    await tester.pumpAndSettle();
    expect(find.textContaining('「備えが足りていない」という知らせ'), findsOneWidget);
    final first = DebtGuardEmotion.anxiety.triggers[0];
    final second = DebtGuardEmotion.anxiety.triggers[1];
    await tester.tap(
      find.byKey(const Key('debt-guard-emotion-trigger-anxiety-0')),
    );
    await tester.tap(
      find.byKey(const Key('debt-guard-emotion-trigger-anxiety-1')),
    );
    // A second tap on the same phrase must not duplicate it.
    await tester.tap(
      find.byKey(const Key('debt-guard-emotion-trigger-anxiety-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(repository.events.single.emotion, DebtGuardEmotion.anxiety);
    expect(repository.events.single.note, '$first、$second');
  });

  testWidgets('skipping the feeling still records the urge', (tester) async {
    final repository = _PanelRepository();
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    await tester.tap(find.byKey(const Key('debt-guard-urge-help')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('debt-guard-emotion-anxiety')));
    await tester.pumpAndSettle();
    // Tapping the selected chip again clears the choice.
    await tester.tap(find.byKey(const Key('debt-guard-emotion-anxiety')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('バグを弱めた'));
    await tester.pumpAndSettle();

    expect(repository.events.single.emotion, isNull);
    expect(repository.events.single.type, DebtGuardEventType.urgeResisted);
  });

  testWidgets('shows which feeling precedes violations from history', (
    tester,
  ) async {
    final repository = _PanelRepository();
    var id = 500;
    DebtGuardEvent past(DebtGuardEventType type, DebtGuardEmotion emotion) {
      return DebtGuardEvent(
        id: id++,
        ruleId: 'eating_out',
        type: type,
        eventDate: DateTime(2026, 8, 15),
        createdAt: DateTime(2026, 8, 15, 20, 0, id),
        emotion: emotion,
      );
    }

    repository.labelledHistory.addAll([
      past(DebtGuardEventType.violation, DebtGuardEmotion.loneliness),
      past(DebtGuardEventType.violation, DebtGuardEmotion.loneliness),
      past(DebtGuardEventType.urgeResisted, DebtGuardEmotion.irritation),
      past(DebtGuardEventType.urgeResisted, DebtGuardEmotion.irritation),
    ]);
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    final riskiest = tester.widget<Text>(
      find.byKey(const Key('debt-guard-emotion-riskiest')),
    );
    expect(riskiest.data, contains('寂しさ'));
    expect(riskiest.data, contains('違反2回のうち2回'));
    final steadiest = tester.widget<Text>(
      find.byKey(const Key('debt-guard-emotion-steadiest')),
    );
    expect(steadiest.data, contains('イライラ'));
    expect(
      find.textContaining(DebtGuardEmotion.loneliness.minimumAction),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('debt-guard-emotion-tally-loneliness')),
      findsOneWidget,
    );
  });

  testWidgets('says so when the history could not be read', (tester) async {
    final repository = _PanelRepository()..failLabelled = true;
    final viewModel = _viewModel(repository);
    addTearDown(viewModel.dispose);
    await viewModel.load();
    await _pump(tester, viewModel, width: 430);

    expect(find.textContaining('気持ちの傾向を読み込めませんでした'), findsOneWidget);
    expect(find.textContaining('偏った違反はありません'), findsNothing);
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

  bool failLabelled = false;
  final labelledHistory = <DebtGuardEvent>[];
  DateTime? lastLabelledSince;

  @override
  Future<List<DebtGuardEvent>> loadLabelledEvents({
    required String userId,
    required DateTime since,
  }) async {
    if (failLabelled) throw StateError('offline');
    lastLabelledSince = since;
    return [
      ...labelledHistory,
      for (final event in events)
        if (event.emotion != null) event,
    ];
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
          emotion: draft.emotion,
        ),
    ];
    this.events.addAll(inserted);
    return inserted;
  }
}
