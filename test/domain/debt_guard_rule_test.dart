import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/debt_guard_rule.dart';

void main() {
  group('debtGuardRules', () {
    test('contains the canonical 25 unique payoff rules', () {
      expect(debtGuardRules, hasLength(25));
      expect(debtGuardRules.map((rule) => rule.id).toSet(), hasLength(25));
      expect(
        debtGuardRules.where((rule) => rule.id == 'gambling'),
        hasLength(1),
      );
      expect(
        debtGuardRules
            .firstWhere((rule) => rule.id == 'additional_borrowing')
            .detail,
        contains('リボ払い'),
      );
    });

    test('protects essential sleep and essential communication', () {
      final sleep = debtGuardRules.firstWhere(
        (rule) => rule.id == 'sleep_before_essential_care',
      );
      final communication = debtGuardRules.firstWhere(
        (rule) => rule.id == 'nonessential_communication',
      );

      expect(sleep.detail, contains('睡眠そのものは禁止しない'));
      expect(communication.detail, contains('緊急'));
      expect(communication.detail, contains('返済先'));
    });

    test('turns required care into a safe minimum first action', () {
      final dishes = debtGuardRules.firstWhere(
        (rule) => rule.id == 'dishes_left_unwashed',
      );
      final brushing = debtGuardRules.firstWhere(
        (rule) => rule.id == 'skip_brushing_teeth',
      );

      expect(dishes.requiredAction, '皿かコップを1つだけ洗う');
      expect(brushing.requiredAction, contains('30秒だけ'));
    });
  });

  group('DebtGuardFoundationPolicy', () {
    test('puts the daily foundation before nonessential expansion', () {
      expect(DebtGuardFoundationPolicy.motto, '整える → 生き抜く → 一歩進む');
      expect(
        DebtGuardFoundationPolicy.dailyFoundationCopy,
        contains('今日を生き抜く'),
      );
      expect(DebtGuardFoundationPolicy.expansionCopy, contains('土台が整ってから'));
    });

    test('protects every essential action from the guard', () {
      expect(
        DebtGuardFoundationPolicy.essentialActions,
        containsAll(<String>[
          '睡眠',
          '食事',
          '水分補給',
          '医療',
          '衛生',
          '仕事',
          '緊急対応',
          '借金返済',
          '必要な連絡',
        ]),
      );
      expect(DebtGuardFoundationPolicy.safetyCopy, contains('決して制限しません'));
    });

    test('defines the requested 20 concrete foundation tasks once each', () {
      expect(debtGuardFoundationTasks, hasLength(20));
      expect(
        debtGuardFoundationTasks.map((task) => task.id).toSet(),
        hasLength(20),
      );
      expect(
        debtGuardFoundationTasks.map((task) => task.title),
        containsAll(<String>[
          '掃除',
          '洗濯',
          '洗い物',
          '整理整頓',
          '風呂',
          '自炊',
          '食事',
          '食料品・調味料の賞味期限管理',
          '不用品の廃棄',
          '歯磨き',
          '毎日着替える',
          '髭を剃る',
          '髪を切る',
          '爪を切る',
          '資産管理',
          '日記をつける',
          '読書',
          '学習',
          '運動',
          '筋トレ',
        ]),
      );
    });

    test('uses safe frequencies for periodic care and training', () {
      final haircut = debtGuardFoundationTasks.firstWhere(
        (task) => task.id == 'haircut',
      );
      final strengthTraining = debtGuardFoundationTasks.firstWhere(
        (task) => task.id == 'strength_training',
      );
      final meals = debtGuardFoundationTasks.firstWhere(
        (task) => task.id == 'meals',
      );

      expect(haircut.cadence, DebtGuardFoundationCadence.whenDue);
      expect(
        strengthTraining.cadence,
        DebtGuardFoundationCadence.recoveryAware,
      );
      expect(strengthTraining.minimumAction, contains('回復'));
      expect(meals.minimumAction, contains('食事を抜かず'));
    });
  });

  group('DebtGuardDailySnapshot', () {
    test('a violation cannot be overwritten by a later check-in', () {
      final events = [
        _event(1, DebtGuardEventType.violation, hour: 9),
        _event(2, DebtGuardEventType.checkIn, hour: 12),
      ];

      final snapshot = DebtGuardDailySnapshot.fromEvents(
        rules: debtGuardRules,
        events: events,
      );

      expect(
        snapshot.statusFor('additional_borrowing'),
        DebtGuardRuleStatus.violated,
      );
      expect(snapshot.violatedCount, 1);
      expect(snapshot.keptCount, 0);
      expect(snapshot.unrecordedCount, 24);
    });

    test('opposite actions weaken the bug and remain auditable', () {
      final snapshot = DebtGuardDailySnapshot.fromEvents(
        rules: debtGuardRules,
        events: [
          _event(1, DebtGuardEventType.urgeResisted, hour: 20),
          _event(
            2,
            DebtGuardEventType.requiredActionStarted,
            hour: 21,
            ruleId: 'dishes_left_unwashed',
          ),
        ],
      );

      expect(
        snapshot.statusFor('additional_borrowing'),
        DebtGuardRuleStatus.kept,
      );
      expect(snapshot.resistedUrgeCount, 1);
      expect(snapshot.requiredActionStartedCount, 1);
      expect(snapshot.bugWeakenedCount, 2);
      expect(snapshot.events, hasLength(2));
    });

    test('round-trips the required-action event wire name', () {
      expect(
        DebtGuardEventType.requiredActionStarted.wireName,
        'required_action_started',
      );
      expect(
        DebtGuardEventTypeCopy.fromWireName('required_action_started'),
        DebtGuardEventType.requiredActionStarted,
      );
    });
  });
}

DebtGuardEvent _event(
  int id,
  DebtGuardEventType type, {
  required int hour,
  String ruleId = 'additional_borrowing',
}) {
  return DebtGuardEvent(
    id: id,
    ruleId: ruleId,
    type: type,
    eventDate: DateTime(2026, 8, 22),
    createdAt: DateTime(2026, 8, 22, hour),
  );
}
