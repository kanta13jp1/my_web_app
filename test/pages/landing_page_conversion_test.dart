import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/landing_conversion_experiment_service.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/pending_landing_trial_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LandingAdapter extends Fake implements LandingPageAdapter {
  int lpViews = 0;
  int saveCtas = 0;
  final List<String> conversionEvents = <String>[];
  final List<String> magicLinkEmails = <String>[];

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<void> recordLpView() async {
    lpViews += 1;
  }

  @override
  Future<void> recordConversionEvent({required String eventKey}) async {
    conversionEvents.add(eventKey);
  }

  @override
  Future<void> recordTrialRun() async {}

  @override
  Future<void> recordSaveCta() async {
    saveCtas += 1;
  }

  @override
  Future<void> recordInboxOpen() async {}

  @override
  Future<void> sendMagicLink({
    required String email,
    String? emailRedirectTo,
    bool shouldCreateUser = true,
  }) async {
    magicLinkEmails.add(email);
  }

  @override
  Future<String> improveTrialPrompt({required String prompt}) async {
    return 'ACTION: 重要な案件を1件選ぶ\nREASON: 最初の判断を減らすため';
  }
}

LandingConversionHypothesis _hypothesis(String id) {
  return LandingConversionExperimentService.hypotheses.firstWhere(
    (hypothesis) => hypothesis.id == id,
  );
}

LandingExperimentAssignment _assignment(
  String id,
  LandingExperimentVariant variant,
) {
  return LandingExperimentAssignment(
    hypothesis: _hypothesis(id),
    variant: variant,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<_LandingAdapter> pumpLanding(
    WidgetTester tester, {
    required LandingExperimentAssignment assignment,
    Size size = const Size(1200, 900),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final adapter = _LandingAdapter();
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/privacy': (_) => const Scaffold(body: Text('privacy'))},
        home: LandingPage(
          key: ValueKey(
            '${assignment.hypothesis.id}-${assignment.variant.name}-${size.width}',
          ),
          adapter: adapter,
          experimentAssignment: assignment,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return adapter;
  }

  testWidgets('treatment renders the complete conversion-first journey', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );

    expect(find.byKey(const Key('landing_h01_outcome_offer')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h02_intent_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('landing_h03_trial_before_auth')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('landing_h04_password_toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing_password_field')), findsNothing);
    expect(find.byKey(const Key('landing_h05_risk_reversal')), findsOneWidget);
    expect(find.byKey(const Key('landing_h06_product_proof')), findsOneWidget);
    expect(find.byKey(const Key('landing_social_proof_stats')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h08_privacy_assurance')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('landing_trial_section'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('landing_auth_section'))).dy,
      ),
    );
    expect(adapter.lpViews, 1);
    expect(adapter.conversionEvents, contains('lp_exp_h01_treatment_view'));
    expect(
      find.descendant(
        of: find.byKey(const Key('landing_hero_section')),
        matching: find.byKey(const Key('landing_h03_inline_trial')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('landing_trial_sample_priority')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const Key('landing_h10_continuity_value')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsOneWidget,
    );
  });

  testWidgets('trial result converts inline with one-field Magic Link', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
    );

    await tester.tap(find.byKey(const Key('landing_trial_sample_priority')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(
      find.byKey(const Key('landing_h04_inline_email')),
      'first-user@example.com',
    );
    await tester.tap(find.byKey(const Key('landing_h04_inline_magic_link')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.saveCtas, 1);
    expect(adapter.magicLinkEmails, ['first-user@example.com']);
    final pendingTrial = await const PendingLandingTrialService().loadForEmail(
      'first-user@example.com',
    );
    expect(pendingTrial, isNotNull);
    expect(pendingTrial!.intent, 'work');
    expect(pendingTrial.prompt, isNotEmpty);
    expect(pendingTrial.action, isNotEmpty);
    expect(pendingTrial.reason, isNotEmpty);
    expect(
      adapter.conversionEvents,
      containsAll(<String>[
        'lp_exp_h04_treatment_trial',
        'lp_exp_h04_treatment_save_cta',
        'lp_exp_h04_treatment_signup_submit',
      ]),
    );
    expect(
      find.byKey(const Key('landing_h04_inline_open_inbox')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('all ten control conditions remove only their tested mechanism', (
    tester,
  ) async {
    for (final id in <String>[
      'h01',
      'h02',
      'h03',
      'h04',
      'h05',
      'h06',
      'h07',
      'h08',
      'h09',
      'h10',
    ]) {
      await pumpLanding(
        tester,
        assignment: _assignment(id, LandingExperimentVariant.control),
        size: id == 'h09' ? const Size(390, 844) : const Size(1200, 900),
      );

      switch (id) {
        case 'h01':
          expect(
            find.byKey(const Key('landing_h01_control_offer')),
            findsOneWidget,
          );
          break;
        case 'h02':
          expect(
            find.byKey(const Key('landing_h02_intent_selector')),
            findsNothing,
          );
          break;
        case 'h03':
          expect(
            find.byKey(const Key('landing_h03_auth_before_trial')),
            findsOneWidget,
          );
          expect(
            tester.getTopLeft(find.byKey(const Key('landing_auth_section'))).dy,
            lessThan(
              tester
                  .getTopLeft(find.byKey(const Key('landing_trial_section')))
                  .dy,
            ),
          );
          expect(
            find.byKey(const Key('landing_h03_inline_trial')),
            findsNothing,
          );
          break;
        case 'h04':
          expect(
            find.byKey(const Key('landing_password_field')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('landing_h04_password_toggle')),
            findsNothing,
          );
          await tester.tap(
            find.byKey(const Key('landing_trial_sample_priority')),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(const Key('landing_h04_inline_magic_capture')),
            findsNothing,
          );
          expect(
            find.byKey(const Key('landing_h04_control_save_scroll')),
            findsOneWidget,
          );
          break;
        case 'h05':
          expect(
            find.byKey(const Key('landing_h05_risk_reversal')),
            findsNothing,
          );
          break;
        case 'h06':
          expect(
            find.byKey(const Key('landing_h06_product_proof')),
            findsNothing,
          );
          break;
        case 'h07':
          expect(
            tester
                .getTopLeft(find.byKey(const Key('landing_social_proof_stats')))
                .dy,
            greaterThan(
              tester
                  .getTopLeft(find.byKey(const Key('landing_auth_section')))
                  .dy,
            ),
          );
          break;
        case 'h08':
          expect(
            find.byKey(const Key('landing_h08_privacy_assurance')),
            findsNothing,
          );
          break;
        case 'h09':
          expect(
            find.byKey(const Key('landing_h09_mobile_sticky_cta')),
            findsNothing,
          );
          break;
        case 'h10':
          await tester.tap(
            find.byKey(const Key('landing_trial_sample_priority')),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            find.byKey(const Key('landing_h10_continuity_value')),
            findsNothing,
          );
          break;
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('mobile treatment exposes and measures the sticky signup CTA', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h09', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    final sticky = find.byKey(const Key('landing_h09_mobile_sticky_cta'));
    expect(sticky, findsOneWidget);
    await tester.tap(
      find.descendant(of: sticky, matching: find.text('無料で始める')),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      adapter.conversionEvents,
      contains('lp_exp_h09_treatment_sticky_cta'),
    );
  });

  testWidgets('mobile H03 keeps the trial action above the sticky CTA', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h03', LandingExperimentVariant.treatment),
      size: const Size(393, 727),
    );

    final trialAction = find.byKey(
      const Key('landing_h03_inline_trial_action'),
    );
    final stickyCta = find.byKey(
      const Key('landing_h09_mobile_sticky_cta'),
    );
    expect(trialAction, findsOneWidget);
    expect(stickyCta, findsOneWidget);
    expect(
      tester.getBottomRight(trialAction).dy,
      lessThanOrEqualTo(tester.getTopLeft(stickyCta).dy),
    );
  });
}
