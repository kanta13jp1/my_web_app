import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/onboarding_page.dart';
import 'package:my_web_app/services/activation_revenue_experiment_service.dart';
import 'package:my_web_app/services/activation_revenue_tracker.dart';
import 'package:my_web_app/services/onboarding_activation_gateway.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('completes first value flow and reveals optional paid choices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final gateway = _FakeOnboardingGateway();
    final tracker = _FakeTracker();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingPage(
          gateway: gateway,
          tracker: tracker,
          assignment: _assignment('a10', ActivationRevenueVariant.treatment),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最短60秒で、今日やる1件を決めます'), findsOneWidget);
    await tester.tap(find.byKey(const Key('intent_learning')));
    await tester.tap(find.byKey(const Key('challenge_example_0')));
    final generateButton = find.byKey(
      const Key('generate_first_action_button'),
    );
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('あなた向けの最初の一手'), findsOneWidget);
    expect(find.byKey(const Key('first_action_plan_card')), findsOneWidget);
    final completeButton = find.byKey(const Key('complete_onboarding_button'));
    await tester.ensureVisible(completeButton);
    await tester.pumpAndSettle();
    await tester.tap(completeButton);
    await tester.pumpAndSettle();

    expect(gateway.completion, isNotNull);
    expect(gateway.completion!.intent, 'learning');
    expect(gateway.completion!.firstAction, contains('25分'));
    expect(gateway.completion!.saveAsDailyTask, isTrue);
    expect(find.byKey(const Key('value_recap_title')), findsOneWidget);
    expect(find.byKey(const Key('continue_free_button')), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding_supporter_choice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('onboarding_pro_choice')), findsOneWidget);
    expect(
      tracker.stages,
      containsAllInOrder([
        'onboarding_view',
        'intent_selected',
        'first_action_started',
        'first_action_completed',
        'onboarding_completed',
        'value_recap_view',
      ]),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A03 treatment requires one challenge while control can skip it',
      (
    tester,
  ) async {
    Future<void> pump(ActivationRevenueVariant variant) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingPage(
            key: ValueKey(variant),
            gateway: _FakeOnboardingGateway(),
            tracker: _FakeTracker(),
            assignment: _assignment('a03', variant),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(ActivationRevenueVariant.treatment);
    var generateButton = find.byKey(
      const Key('generate_first_action_button'),
    );
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pump();
    expect(find.byKey(const Key('challenge_input')), findsOneWidget);
    expect(find.textContaining('いま一番困っていること'), findsWidgets);

    await pump(ActivationRevenueVariant.control);
    generateButton = find.byKey(const Key('generate_first_action_button'));
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('first_action_plan_card')), findsOneWidget);
  });

  testWidgets('A01 A02 A04 A06 A07 and A08 render distinct arms', (
    tester,
  ) async {
    await _pumpArm(tester, 'a01', ActivationRevenueVariant.control);
    expect(find.text('初期設定を始めます'), findsOneWidget);
    await _pumpArm(tester, 'a01', ActivationRevenueVariant.treatment);
    expect(find.text('最短60秒で、今日やる1件を決めます'), findsOneWidget);

    await _pumpArm(tester, 'a02', ActivationRevenueVariant.control);
    expect(find.byKey(const Key('intent_work')), findsNothing);
    await _pumpArm(tester, 'a02', ActivationRevenueVariant.treatment);
    expect(find.byKey(const Key('intent_work')), findsOneWidget);

    await _pumpArm(tester, 'a04', ActivationRevenueVariant.control);
    expect(find.byKey(const Key('challenge_example_0')), findsNothing);
    await _pumpArm(tester, 'a04', ActivationRevenueVariant.treatment);
    expect(find.byKey(const Key('challenge_example_0')), findsOneWidget);

    await _pumpArm(tester, 'a06', ActivationRevenueVariant.control);
    expect(find.text('表示名'), findsOneWidget);
    await _pumpArm(tester, 'a06', ActivationRevenueVariant.treatment);
    expect(find.text('表示名（任意）'), findsOneWidget);

    await _pumpArm(tester, 'a07', ActivationRevenueVariant.control);
    expect(find.text('目的'), findsNothing);
    await _pumpArm(tester, 'a07', ActivationRevenueVariant.treatment);
    expect(find.text('目的'), findsOneWidget);

    await _pumpArm(tester, 'a08', ActivationRevenueVariant.control);
    await tester.enterText(
      find.byKey(const Key('challenge_input')),
      '今日の情報を整理したい',
    );
    await _generatePlan(tester);
    expect(find.textContaining('ホームからいつでも再開'), findsNothing);
    await _pumpArm(tester, 'a08', ActivationRevenueVariant.treatment);
    await tester.enterText(
      find.byKey(const Key('challenge_input')),
      '今日の情報を整理したい',
    );
    await _generatePlan(tester);
    expect(find.textContaining('ホームからいつでも再開'), findsOneWidget);
  });

  testWidgets('A05 personalizes the first action only in treatment', (
    tester,
  ) async {
    const challenge = '請求書の確認が終わらない';

    await _pumpArm(tester, 'a05', ActivationRevenueVariant.control);
    await tester.enterText(find.byKey(const Key('challenge_input')), challenge);
    await _generatePlan(tester);
    expect(find.textContaining(challenge), findsNothing);

    await _pumpArm(tester, 'a05', ActivationRevenueVariant.treatment);
    await tester.enterText(find.byKey(const Key('challenge_input')), challenge);
    await _generatePlan(tester);
    expect(find.textContaining(challenge), findsOneWidget);
  });

  testWidgets('A08 controls whether the first action becomes a Home task', (
    tester,
  ) async {
    final controlGateway = _FakeOnboardingGateway();
    await _pumpArm(
      tester,
      'a08',
      ActivationRevenueVariant.control,
      gateway: controlGateway,
    );
    await _completeFlow(tester);
    expect(controlGateway.completion!.saveAsDailyTask, isFalse);

    final treatmentGateway = _FakeOnboardingGateway();
    await _pumpArm(
      tester,
      'a08',
      ActivationRevenueVariant.treatment,
      gateway: treatmentGateway,
    );
    await _completeFlow(tester);
    expect(treatmentGateway.completion!.saveAsDailyTask, isTrue);
  });

  testWidgets('A09 reveals paid choices only after saved value', (
    tester,
  ) async {
    await _pumpArm(tester, 'a09', ActivationRevenueVariant.control);
    await _completeFlow(tester);
    expect(find.byKey(const Key('continue_free_button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding_supporter_choice')), findsNothing);

    await _pumpArm(tester, 'a09', ActivationRevenueVariant.treatment);
    await _completeFlow(tester);
    expect(find.byKey(const Key('continue_free_button')), findsOneWidget);
    expect(
      find.byKey(const Key('onboarding_supporter_choice')),
      findsOneWidget,
    );
  });

  testWidgets('A10 explains free supporter and Pro choices by value', (
    tester,
  ) async {
    await _pumpArm(tester, 'a10', ActivationRevenueVariant.control);
    await _completeFlow(tester);
    expect(find.text('サポーター'), findsOneWidget);
    expect(find.text('1回100円で応援'), findsNothing);

    await _pumpArm(tester, 'a10', ActivationRevenueVariant.treatment);
    await _completeFlow(tester);
    expect(find.text('1回100円で応援'), findsOneWidget);
    expect(find.textContaining('自動更新なし'), findsOneWidget);
    expect(find.text('ProでAI利用量を増やす'), findsOneWidget);
  });
}

Future<void> _pumpArm(
  WidgetTester tester,
  String id,
  ActivationRevenueVariant variant, {
  _FakeOnboardingGateway? gateway,
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    MaterialApp(
      home: OnboardingPage(
        key: ValueKey('$id-${variant.name}'),
        gateway: gateway ?? _FakeOnboardingGateway(),
        tracker: _FakeTracker(),
        assignment: _assignment(id, variant),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _generatePlan(WidgetTester tester) async {
  final button = find.byKey(const Key('generate_first_action_button'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _completeFlow(WidgetTester tester) async {
  final challenge = find.byKey(const Key('challenge_input'));
  if (challenge.evaluate().isNotEmpty) {
    await tester.enterText(challenge, '今日の情報を整理したい');
  }
  final displayName = find.byKey(const Key('display_name_input'));
  if (displayName.evaluate().isNotEmpty) {
    await tester.enterText(displayName, 'テスト利用者');
  }
  await _generatePlan(tester);
  final complete = find.byKey(const Key('complete_onboarding_button'));
  await tester.ensureVisible(complete);
  await tester.pumpAndSettle();
  await tester.tap(complete);
  await tester.pumpAndSettle();
}

ActivationRevenueAssignment _assignment(
  String id,
  ActivationRevenueVariant variant,
) {
  return ActivationRevenueAssignment(
    hypothesis: ActivationRevenueExperimentService.hypotheses.firstWhere(
      (hypothesis) => hypothesis.id == id,
    ),
    variant: variant,
  );
}

class _FakeOnboardingGateway implements OnboardingActivationGateway {
  OnboardingCompletion? completion;

  @override
  OnboardingUserContext? currentUser() {
    return const OnboardingUserContext(
      id: 'activation-test-user',
      email: 'activation@example.test',
    );
  }

  @override
  Future<void> complete(OnboardingCompletion completion) async {
    this.completion = completion;
  }
}

class _FakeTracker implements ActivationRevenueEventTracker {
  final List<String> stages = [];

  @override
  Future<void> record({
    required ActivationRevenueAssignment assignment,
    required String stage,
  }) async {
    stages.add(stage);
  }
}
