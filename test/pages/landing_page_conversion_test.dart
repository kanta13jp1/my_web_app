import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/growth_acquisition_service.dart';
import 'package:my_web_app/services/landing_conversion_analytics.dart';
import 'package:my_web_app/services/landing_conversion_experiment_service.dart';
import 'package:my_web_app/services/landing_oauth_callback_failure.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_signup_completion_service.dart';
import 'package:my_web_app/services/pending_landing_trial_service.dart';
import 'package:my_web_app/services/route_visibility_observer.dart';
import 'package:my_web_app/utils/route_document_title.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _LandingAdapter extends Fake implements LandingPageAdapter {
  int lpViews = 0;
  int socialProofLoads = 0;
  int trialRuns = 0;
  int saveCtas = 0;
  final List<String> conversionEvents = <String>[];
  final List<String> conversionVisitorIds = <String>[];
  final List<String> magicLinkEmails = <String>[];
  final List<bool> magicLinkShouldCreateUsers = <bool>[];
  final List<LandingOAuthCallbackFailureCategory> googleCallbackFailures =
      <LandingOAuthCallbackFailureCategory>[];
  int googleLaunches = 0;
  bool googleLaunchResult = true;
  Exception? magicLinkError;
  Completer<String>? trialResponse;
  Exception? trialError;
  Exception? socialProofError;
  String? lastTrialPrompt;
  LandingSocialProofStats socialProofStats = const LandingSocialProofStats(
    totalUsers: 38,
    publicMemoCount: 12,
  );

  @override
  Stream<AuthState> authStateChanges() => const Stream<AuthState>.empty();

  @override
  Future<void> recordLpView() async {
    lpViews += 1;
  }

  @override
  Future<LandingSocialProofStats> loadSocialProofStats() async {
    socialProofLoads += 1;
    if (socialProofError != null) throw socialProofError!;
    return socialProofStats;
  }

  @override
  Future<void> recordConversionEvent({
    required String eventKey,
    required String visitorId,
  }) async {
    conversionEvents.add(eventKey);
    conversionVisitorIds.add(visitorId);
  }

  @override
  Future<void> recordTrialRun() async {
    trialRuns += 1;
  }

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
    magicLinkShouldCreateUsers.add(shouldCreateUser);
    final error = magicLinkError;
    if (error != null) throw error;
  }

  @override
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    googleLaunches += 1;
    return googleLaunchResult;
  }

  @override
  Future<void> recordGoogleOAuthCallbackFailure({
    required LandingOAuthCallbackFailureCategory category,
  }) async {
    googleCallbackFailures.add(category);
  }

  @override
  Future<String> improveTrialPrompt({required String prompt}) async {
    lastTrialPrompt = prompt;
    final error = trialError;
    if (error != null) {
      throw error;
    }
    final pendingResponse = trialResponse;
    if (pendingResponse != null) {
      return pendingResponse.future;
    }
    return 'ACTION: 重要な案件を1件選ぶ\nREASON: 最初の判断を減らすため';
  }
}

class _DelayedExperimentService extends LandingConversionExperimentService {
  final Future<LandingExperimentAssignment> assignment;

  const _DelayedExperimentService(this.assignment);

  @override
  Future<LandingExperimentAssignment> resolve({
    Uri? uri,
    SharedPreferences? preferences,
    int? deterministicBucket,
  }) {
    return assignment;
  }
}

class _RecordingAcquisitionService extends GrowthAcquisitionService {
  _RecordingAcquisitionService();

  final List<String> stages = <String>[];

  @override
  Future<bool> recordFirstUserFunnelStage({
    required String stage,
    String? visitorId,
    Uri? currentUri,
    SharedPreferences? preferences,
    DateTime? now,
  }) async {
    stages.add(stage);
    return true;
  }
}

class _RecordingConversionAnalytics implements LandingConversionAnalytics {
  final List<String> eventKeys = <String>[];
  final List<Map<String, Object>> properties = <Map<String, Object>>[];

  @override
  Future<void> captureExperimentEvent({
    required String eventKey,
    Map<String, Object> properties = const <String, Object>{},
  }) async {
    eventKeys.add(eventKey);
    this.properties.add(Map<String, Object>.from(properties));
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

double _landingScrollOffset(WidgetTester tester) {
  final pageScrollable = find
      .descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  return tester.state<ScrollableState>(pageScrollable).position.pixels;
}

Future<void> _completeGuidedTrialWithQuickAnswers(WidgetTester tester) async {
  for (var step = 0; step < 5; step++) {
    final quickAnswer = find.byKey(
      const Key('landing_trial_guided_quick_answer'),
    );
    await Scrollable.ensureVisible(tester.element(quickAnswer), alignment: 0.6);
    await tester.pump();
    await tester.tap(quickAnswer);
    await tester.pump();
    final next = find.byKey(const Key('landing_trial_guided_next'));
    await Scrollable.ensureVisible(tester.element(next), alignment: 0.7);
    await tester.pump();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
  final submit = find.byKey(const Key('landing_trial_guided_submit'));
  await Scrollable.ensureVisible(tester.element(submit), alignment: 0.7);
  await tester.pump();
  await tester.tap(submit);
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<_LandingAdapter> pumpLanding(
    WidgetTester tester, {
    LandingExperimentAssignment? assignment,
    Size size = const Size(1200, 900),
    bool? analyticsEnabled,
    bool? googleLoginEnabled,
    bool showUnverifiedMarketingForQa = false,
    Uri? landingUri,
    LandingConversionExperimentService? conversionExperimentService,
    LandingConversionAnalytics? conversionAnalytics,
    GrowthAcquisitionService? acquisitionService,
    _LandingAdapter? landingAdapter,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final adapter = landingAdapter ?? _LandingAdapter();
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/privacy': (_) => const Scaffold(body: Text('privacy'))},
        home: LandingPage(
          key: ValueKey(
            '${assignment?.hypothesis.id ?? 'async'}-'
            '${assignment?.variant.name ?? 'pending'}-${size.width}',
          ),
          adapter: adapter,
          experimentAssignment: assignment,
          conversionExperimentService: conversionExperimentService,
          conversionAnalytics: conversionAnalytics,
          acquisitionService: acquisitionService,
          analyticsEnabled: analyticsEnabled,
          googleLoginEnabled: googleLoginEnabled,
          showUnverifiedMarketingForQa: showUnverifiedMarketingForQa,
          landingUri: landingUri,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    return adapter;
  }

  testWidgets('landing form fields expose concise accessible names', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pumpLanding(
        tester,
        assignment: _assignment('h04', LandingExperimentVariant.treatment),
      );

      expect(
        tester
            .getSemantics(
              find.byKey(const Key('landing_trial_prompt_input')),
            )
            .label,
        '例: 今日いちばん詰まっていることを簡単に書く',
      );
      final email = find.byKey(const Key('landing_auth_email'));
      await Scrollable.ensureVisible(tester.element(email));
      await tester.pump();
      expect(
        tester.getSemantics(email).label,
        'メールアドレス',
      );
    } finally {
      semantics.dispose();
    }
  });

  test('lp_qa query disables analytics only for explicit QA traffic', () {
    expect(
      LandingPage.analyticsEnabledForUri(
        Uri.parse('https://example.com/?lp_qa=1'),
      ),
      isFalse,
    );
    expect(
      LandingPage.analyticsEnabledForUri(
        Uri.parse('https://example.com/?lp_qa=0'),
      ),
      isTrue,
    );
    expect(LandingPage.analyticsEnabledForUri(null), isTrue);
  });

  test('lp_intent focuses only the explicit trial campaign', () {
    expect(
      LandingPage.shouldFocusTrialForUri(
        Uri.parse('https://example.com/?lp_intent=trial'),
      ),
      isTrue,
    );
    expect(
      LandingPage.shouldFocusTrialForUri(
        Uri.parse('https://example.com/?lp_intent=TRIAL'),
      ),
      isTrue,
    );
    expect(
      LandingPage.shouldFocusTrialForUri(
        Uri.parse('https://example.com/?lp_intent=signup'),
      ),
      isFalse,
    );
    expect(LandingPage.shouldFocusTrialForUri(null), isFalse);
  });

  test(
    'unverified marketing content requires an explicit test-only override',
    () {
      expect(
        LandingPage(
          landingUri: Uri.parse(
            'https://example.com/?lp_unverified_marketing_qa=1',
          ),
        ).showUnverifiedMarketingForQa,
        isFalse,
      );
      expect(
        const LandingPage(
          showUnverifiedMarketingForQa: true,
        ).showUnverifiedMarketingForQa,
        isTrue,
      );
    },
  );

  testWidgets('Google is the primary production registration path', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
      googleLoginEnabled: true,
    );

    final googleButton = find.byKey(const Key('landing_google_primary'));
    expect(googleButton, findsOneWidget);
    expect(find.text('Googleで無料登録'), findsOneWidget);
    expect(find.textContaining('登録時にカード入力はありません'), findsWidgets);
    expect(find.textContaining('約10秒'), findsNothing);

    await Scrollable.ensureVisible(tester.element(googleButton));
    await tester.tap(googleButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.googleLaunches, 1);
    expect(
      adapter.conversionEvents,
      contains('lp_exp_h04_treatment_signup_submit'),
    );
  });

  testWidgets('Google callback failure is visible, counted, and recoverable', (
    tester,
  ) async {
    await const LandingSignupCompletionService().markPending(
      email: null,
      eventKey: 'lp_exp_h04_treatment_signup_complete',
      visitorId: '00000000-0000-4000-8000-000000000001',
    );
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
      googleLoginEnabled: true,
      landingUri: Uri.parse(
        'https://example.com/#error=access_denied'
        '&error_code=user_cancelled_authorization'
        '&error_description=The+user+cancelled',
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const Key('landing_google_oauth_callback_error')),
      findsOneWidget,
    );
    expect(
      adapter.googleCallbackFailures,
      <LandingOAuthCallbackFailureCategory>[
        LandingOAuthCallbackFailureCategory.cancelled,
      ],
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.containsKey(LandingSignupCompletionService.storageKey),
      isFalse,
    );

    await tester.tap(find.byKey(const Key('landing_google_oauth_retry')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.googleLaunches, 1);
    expect(
      find.byKey(const Key('landing_google_oauth_callback_error')),
      findsNothing,
    );
  });

  testWidgets('Google callback recovery stays usable in the mobile viewport', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
      analyticsEnabled: false,
      googleLoginEnabled: true,
      landingUri: Uri.parse(
        'https://example.com/#error=server_error'
        '&error_description=Unable+to+exchange+external+code',
      ),
    );

    final notice = find.byKey(const Key('landing_google_oauth_callback_error'));
    expect(notice, findsOneWidget);
    expect(find.byKey(const Key('landing_google_oauth_retry')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_google_oauth_magic_link')),
      findsOneWidget,
    );
    expect(tester.getBottomRight(notice).dy, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid email is rejected before signup attribution', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
    );
    await tester.enterText(
      find.byKey(const Key('landing_auth_email')),
      'not-an-email',
    );
    final magicLinkButton = find.byKey(const Key('landing_h04_magic_primary'));
    await Scrollable.ensureVisible(tester.element(magicLinkButton));
    await tester.tap(magicLinkButton);
    await tester.pump();

    expect(adapter.magicLinkEmails, isEmpty);
    expect(find.byKey(const Key('landing_magic_link_error')), findsOneWidget);
    expect(
      adapter.conversionEvents,
      isNot(contains('lp_exp_h04_treatment_signup_submit')),
    );
  });

  testWidgets('email validation accepts s characters', (tester) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
    );
    final emailField = find.byKey(const Key('landing_auth_email'));
    final magicLinkButton = find.byKey(const Key('landing_h04_magic_primary'));

    await tester.enterText(emailField, 'sales@example.com');
    await Scrollable.ensureVisible(tester.element(magicLinkButton));
    await tester.tap(magicLinkButton);
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.magicLinkEmails, contains('sales@example.com'));
  });

  testWidgets('email validation rejects whitespace', (tester) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
    );
    await tester.enterText(
      find.byKey(const Key('landing_auth_email')),
      'sales @example.com',
    );
    final magicLinkButton = find.byKey(const Key('landing_h04_magic_primary'));
    await Scrollable.ensureVisible(tester.element(magicLinkButton));
    await tester.tap(magicLinkButton);
    await tester.pump();
    expect(adapter.magicLinkEmails, isEmpty);
    expect(find.byKey(const Key('landing_magic_link_error')), findsOneWidget);
  });

  testWidgets('Magic Link delivery failure offers Google recovery', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.treatment),
      googleLoginEnabled: true,
    );
    adapter.magicLinkError = const AuthException(
      'Email address not authorized',
      code: 'email_provider_disabled',
    );
    await tester.enterText(
      find.byKey(const Key('landing_auth_email')),
      'first-user@example.com',
    );
    final magicLinkButton = find.byKey(const Key('landing_h04_magic_primary'));
    await Scrollable.ensureVisible(tester.element(magicLinkButton));
    await tester.tap(magicLinkButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('landing_magic_link_error')), findsOneWidget);
    final recovery = find.byKey(
      const Key('landing_magic_link_google_recovery'),
    );
    expect(recovery, findsOneWidget);
    await Scrollable.ensureVisible(tester.element(recovery));
    await tester.tap(recovery);
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.googleLaunches, 1);
  });

  testWidgets('mirrors an anonymous experiment view with safe attribution', (
    tester,
  ) async {
    final analytics = _RecordingConversionAnalytics();
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
      conversionAnalytics: analytics,
      size: const Size(390, 844),
      landingUri: Uri.parse(
        'https://example.com/start?utm_source=x&utm_medium=organic'
        '&utm_campaign=first_user&ref=invite-code',
      ),
    );

    expect(analytics.eventKeys, contains('lp_exp_h01_treatment_view'));
    final viewIndex = analytics.eventKeys.indexOf('lp_exp_h01_treatment_view');
    expect(analytics.properties[viewIndex], <String, Object>{
      'path': '/start',
      'viewport': 'mobile',
      'utm_source': 'x',
      'utm_medium': 'organic',
      'utm_campaign': 'first_user',
      'referral_present': true,
    });
  });

  testWidgets('QA traffic does not reach conversion analytics', (tester) async {
    final analytics = _RecordingConversionAnalytics();
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.control),
      conversionAnalytics: analytics,
      landingUri: Uri.parse('https://example.com/?lp_qa=1'),
    );

    expect(analytics.eventKeys, isEmpty);
  });

  testWidgets('brand search intent is visible and exposed as headings', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.control),
    );

    expect(find.text('自分株式会社とは'), findsOneWidget);
    expect(find.textContaining('自分自身を一つの会社に見立て'), findsOneWidget);
    expect(find.text('自分が人生のCEOとして決める'), findsOneWidget);

    final heroHeading = tester.widget<Semantics>(
      find.byKey(const Key('landing_brand_heading')),
    );
    final appBarHeading = tester.widget<Semantics>(
      find.byKey(const Key('landing_appbar_brand_heading')),
    );
    final definitionHeading = tester.widget<Semantics>(
      find.byKey(const Key('landing_brand_definition_heading')),
    );
    expect(heroHeading.properties.header, isTrue);
    expect(appBarHeading.properties.header, isTrue);
    expect(definitionHeading.properties.header, isTrue);

    final documentTitle = tester.widget<Title>(
      find.byKey(const Key('landing_document_title')),
    );
    expect(documentTitle.title, landingDocumentTitle);
  });

  testWidgets(
    'landing title is inactive while a deep-linked route is current',
    (tester) async {
      await pumpLanding(
        tester,
        assignment: _assignment('h01', LandingExperimentVariant.control),
      );

      Navigator.of(tester.element(find.byType(LandingPage))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('deep link destination')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('deep link destination'), findsOneWidget);
      expect(find.byKey(const Key('landing_document_title')), findsNothing);
    },
  );

  testWidgets(
    'header login selects login mode without creating a new Magic Link user',
    (tester) async {
      final adapter = await pumpLanding(
        tester,
        assignment: _assignment('h04', LandingExperimentVariant.control),
      );

      await tester.tap(find.byKey(const Key('landing_header_login')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.text('ログインして続きから再開'), findsOneWidget);
      expect(find.text('メールでログイン'), findsOneWidget);
      expect(find.text('Magic Linkでログイン'), findsOneWidget);
      final emailField = tester.widget<TextField>(
        find.byKey(const Key('landing_auth_email')),
      );
      expect(emailField.focusNode?.hasFocus, isTrue);

      await tester.enterText(
        find.byKey(const Key('landing_auth_email')),
        'existing-user@example.com',
      );
      final magicLinkButton = find.byKey(
        const Key('landing_h04_magic_primary'),
      );
      await Scrollable.ensureVisible(
        tester.element(magicLinkButton),
        alignment: 0.5,
      );
      await tester.pump();
      await tester.tap(magicLinkButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(adapter.magicLinkEmails, <String>['existing-user@example.com']);
      expect(adapter.magicLinkShouldCreateUsers, <bool>[false]);
      expect(
        adapter.conversionEvents,
        isNot(contains('lp_exp_h04_control_signup_submit')),
      );
    },
  );

  testWidgets('signup CTA restores signup mode and keeps hero attribution', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h04', LandingExperimentVariant.control),
    );

    await tester.tap(find.byKey(const Key('landing_header_login')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('メールでログイン'), findsOneWidget);

    await tester.tap(find.byKey(const Key('landing_header_signup')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('今すぐ無料ではじめる'), findsOneWidget);
    expect(find.text('メールで新規登録'), findsOneWidget);
    expect(find.text('Magic Linkで今すぐ始める'), findsOneWidget);
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('landing_auth_email')),
    );
    expect(emailField.focusNode?.hasFocus, isTrue);
    expect(adapter.conversionEvents, contains('lp_exp_h04_control_hero_cta'));
  });

  testWidgets(
    'mobile auth mode selector clearly switches signup and login copy',
    (tester) async {
      await pumpLanding(
        tester,
        assignment: _assignment('h04', LandingExperimentVariant.control),
        size: const Size(390, 844),
      );

      final selectorFinder = find.byKey(
        const Key('landing_auth_mode_selector'),
      );
      expect(selectorFinder, findsOneWidget);
      expect(
        tester.widget<SegmentedButton<bool>>(selectorFinder).selected,
        <bool>{true},
      );
      expect(
        find.text('初めての方：無料アカウントを作成します'),
        findsOneWidget,
      );
      expect(find.text('メールを開くだけで新規登録が完了します。'), findsOneWidget);

      await Scrollable.ensureVisible(
        tester.element(selectorFinder),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('landing_auth_mode_login_option')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<SegmentedButton<bool>>(selectorFinder).selected,
        <bool>{false},
      );
      expect(find.text('ログインして続きから再開'), findsOneWidget);
      expect(find.text('Magic Linkでログイン'), findsOneWidget);
      expect(find.text('登録済みの方：続きから再開します'), findsOneWidget);
      expect(find.text('メールを開くだけでログインできます。'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('landing_auth_mode_signup_option')),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<SegmentedButton<bool>>(selectorFinder).selected,
        <bool>{true},
      );
      expect(find.text('今すぐ無料ではじめる'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lp_intent trial brings the promised trial into view for every H03 arm and viewport',
    (tester) async {
      for (final size in <Size>[const Size(1200, 900), const Size(390, 844)]) {
        for (final variant in LandingExperimentVariant.values) {
          final adapter = await pumpLanding(
            tester,
            assignment: _assignment('h03', variant),
            size: size,
            landingUri: Uri.parse(
              'https://example.com/?lp_intent=trial&lp_qa=1',
            ),
          );
          await tester.pumpAndSettle();

          final trialTop = tester
              .getTopLeft(find.byKey(const Key('landing_trial_section')))
              .dy;
          expect(trialTop, lessThan(size.height));
          expect(trialTop, greaterThanOrEqualTo(0));
          expect(_landingScrollOffset(tester), greaterThan(0));
          expect(adapter.lpViews, 0);
          expect(adapter.conversionEvents, isEmpty);
        }
      }
    },
  );

  testWidgets(
    'lp_intent waits for an asynchronous H03 layout before focusing the trial',
    (tester) async {
      const size = Size(390, 844);
      final assignment = Completer<LandingExperimentAssignment>();
      await pumpLanding(
        tester,
        size: size,
        analyticsEnabled: false,
        landingUri: Uri.parse('https://example.com/?lp_intent=trial&lp_qa=1'),
        conversionExperimentService: _DelayedExperimentService(
          assignment.future,
        ),
      );

      assignment.complete(_assignment('h03', LandingExperimentVariant.control));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('landing_h03_auth_before_trial')), findsOne);
      final trialTop =
          tester.getTopLeft(find.byKey(const Key('landing_trial_section'))).dy;
      expect(trialTop, inInclusiveRange(0, size.height));
      expect(_landingScrollOffset(tester), greaterThan(0));
    },
  );

  testWidgets('landing without lp_intent keeps the H03 control at the top', (
    tester,
  ) async {
    const size = Size(390, 844);
    await pumpLanding(
      tester,
      assignment: _assignment('h03', LandingExperimentVariant.control),
      size: size,
      landingUri: Uri.parse('https://example.com/?lp_qa=1'),
    );
    await tester.pumpAndSettle();

    expect(_landingScrollOffset(tester), 0);
    expect(find.byKey(const Key('landing_h03_auth_before_trial')), findsOne);
  });

  testWidgets('first-user X traffic gets a one-tap trial before registration', (
    tester,
  ) async {
    final acquisition = _RecordingAcquisitionService();
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h03', LandingExperimentVariant.control),
      landingUri: Uri.parse(
        'https://example.com/?lp_intent=trial'
        '&utm_source=x&utm_medium=organic'
        '&utm_campaign=first_user_growth'
        '&utm_content=outcome_first_a',
      ),
      acquisitionService: acquisition,
    );
    await tester.pumpAndSettle();

    expect(find.text('Xから来た方へ: まず1タップで結果を見る'), findsOneWidget);
    expect(
      find.byKey(const Key('first_user_growth_one_tap_trial')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('first_user_growth_trial_reassurance')),
      findsOneWidget,
    );
    expect(acquisition.stages, contains('view'));

    await tester.tap(find.byKey(const Key('first_user_growth_one_tap_trial')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.trialRuns, 1);
    expect(acquisition.stages, contains('trial'));
    expect(adapter.lastTrialPrompt, '仕事が多すぎて、何から始めるか決められない');
    expect(
      adapter.conversionEvents,
      containsAll(<String>[
        'lp_exp_h03_control_hero_cta',
        'lp_exp_h03_control_trial',
      ]),
    );
    expect(
      find.byKey(const Key('landing_trial_result_action')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsOneWidget,
    );
  });

  testWidgets('first-user one-tap trial stays in the mobile first viewport', (
    tester,
  ) async {
    const size = Size(390, 844);
    await pumpLanding(
      tester,
      assignment: _assignment('h03', LandingExperimentVariant.control),
      size: size,
      landingUri: Uri.parse(
        'https://example.com/?lp_intent=trial'
        '&utm_source=x&utm_medium=organic'
        '&utm_campaign=first_user_growth',
      ),
    );
    await tester.pumpAndSettle();

    final oneTapButton = find.byKey(
      const Key('first_user_growth_one_tap_trial'),
    );
    expect(oneTapButton, findsOneWidget);
    final buttonTop = tester.getTopLeft(oneTapButton).dy;
    final buttonBottom = tester.getBottomLeft(oneTapButton).dy;
    expect(buttonTop, greaterThanOrEqualTo(0));
    expect(buttonBottom, lessThanOrEqualTo(size.height));
  });

  testWidgets('non-campaign traffic keeps the generic one-tap trial', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
      landingUri: Uri.parse('https://example.com/?lp_intent=trial'),
    );

    expect(
      find.byKey(const Key('first_user_growth_one_tap_trial')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('first_user_growth_trial_reassurance')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('landing_h11_answer_preview_action')),
      findsOneWidget,
    );
  });

  testWidgets('H07 renders anonymous-safe public aggregate social proof', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h07', LandingExperimentVariant.treatment),
    );
    await tester.pumpAndSettle();

    expect(adapter.socialProofLoads, 1);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('登録ユーザー数'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('公開メモ数'), findsOneWidget);
  });

  testWidgets('social proof failure is disclosed and retry recovers', (
    tester,
  ) async {
    final adapter = _LandingAdapter()
      ..socialProofError = Exception('aggregate unavailable');
    await pumpLanding(
      tester,
      assignment: _assignment('h07', LandingExperimentVariant.treatment),
      landingAdapter: adapter,
    );
    await tester.pumpAndSettle();

    expect(adapter.socialProofLoads, 1);
    expect(
      find.byKey(const Key('landing_social_proof_error')),
      findsOneWidget,
    );
    expect(find.text('最新の利用状況を取得できませんでした。'), findsOneWidget);

    adapter.socialProofError = null;
    final retry = find.byKey(const Key('landing_social_proof_retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(adapter.socialProofLoads, 2);
    expect(find.byKey(const Key('landing_social_proof_error')), findsNothing);
    expect(find.text('38'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets(
    'public social proof preloads under a deep link while LP analytics stay gated',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final adapter = _LandingAdapter();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[
            deepLinkVisibilityRouteObserver,
          ],
          initialRoute: '/privacy',
          onGenerateRoute: (settings) {
            if (settings.name == '/privacy') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('privacy')),
              );
            }
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => LandingPage(
                adapter: adapter,
                experimentAssignment: _assignment(
                  'h07',
                  LandingExperimentVariant.treatment,
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('privacy'), findsOneWidget);
      expect(adapter.socialProofLoads, 1);
      expect(adapter.lpViews, 0);
      expect(adapter.conversionEvents, isEmpty);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(adapter.lpViews, 1);
      expect(
        adapter.conversionEvents,
        containsAll(<String>[
          'lp_exp_h07_treatment_view',
          'lp_exp_h07_treatment_mobile_view',
        ]),
      );
    },
  );

  testWidgets('QA mode preserves the trial but emits no LP analytics', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.control),
      analyticsEnabled: false,
    );

    expect(adapter.lpViews, 0);
    expect(adapter.conversionEvents, isEmpty);

    await tester.tap(find.byKey(const Key('landing_trial_sample_priority')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.trialRuns, 0);
    expect(adapter.conversionEvents, isEmpty);
    expect(adapter.lastTrialPrompt, isNotEmpty);
    expect(find.textContaining('重要'), findsWidgets);
  });

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
    expect(adapter.conversionVisitorIds, hasLength(1));
    expect(
      LandingConversionExperimentService.isValidVisitorId(
        adapter.conversionVisitorIds.single,
      ),
      isTrue,
    );
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
    expect(find.textContaining('今回の入力・提案・理由を同じブラウザから引き継げます'), findsOneWidget);
    expect(find.textContaining('実行履歴'), findsNothing);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsOneWidget,
    );
  });

  testWidgets('editorial lower page shows only verified decision aids', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
      landingUri: Uri.parse(
        'https://example.com/?lp_unverified_marketing_qa=1',
      ),
    );

    expect(find.byKey(const Key('landing_editorial_prologue')), findsOneWidget);
    for (var chapter = 1; chapter <= 4; chapter++) {
      expect(
        find.byKey(Key('landing_editorial_chapter_$chapter')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('landing_faq_more_toggle')), findsNothing);
    expect(find.byKey(const Key('landing_trust_disclosure')), findsOneWidget);
    expect(find.byKey(const Key('landing_pricing_disclosure')), findsOneWidget);
    expect(find.text('AIが勝手に「やること」を決めるのですか?'), findsOneWidget);
    expect(find.text('登録時にカード情報は必要ですか?'), findsOneWidget);
    expect(find.byKey(const Key('landing_migration_guide')), findsNothing);
    expect(find.byKey(const Key('landing_comparison_links')), findsNothing);
    expect(
      find.byKey(const Key('landing_editorial_archive_toggle')),
      findsNothing,
    );
    expect(find.textContaining('¥1,100〜/月'), findsNothing);
    expect(find.textContaining('21サービス分'), findsNothing);
  });

  testWidgets('pricing disclosure keeps verified trust essentials visible', (
    tester,
  ) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );

    expect(
      find.byKey(const Key('landing_pricing_trust_summary')),
      findsOneWidget,
    );
    expect(find.text('無料登録: カード不要 / 有料プラン: 内容・料金を事前確認'), findsOneWidget);
    expect(
      find.byKey(const Key('landing_pricing_disclosure_link')),
      findsOneWidget,
    );
    expect(find.text('競合サービスとの料金比較を見る'), findsNothing);
  });

  testWidgets('hero media keeps a readable fallback contract', (tester) async {
    await pumpLanding(
      tester,
      assignment: _assignment('h03', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    final imageFinder = find.byKey(const Key('landing_hero_media_image'));
    final image = tester.widget<Image>(imageFinder);
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 900);
    expect(image.errorBuilder, isNotNull);

    final fallback = image.errorBuilder!(
      tester.element(imageFinder),
      StateError('missing test asset'),
      StackTrace.empty,
    );
    expect(fallback.key, const Key('landing_hero_media_fallback'));
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
    final magicLinkButton = find.byKey(
      const Key('landing_h04_inline_magic_link'),
    );
    await Scrollable.ensureVisible(
      tester.element(magicLinkButton),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(magicLinkButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.saveCtas, 1);
    expect(adapter.magicLinkEmails, ['first-user@example.com']);
    final prefs = await SharedPreferences.getInstance();
    final pendingSignup = prefs.getString(
      LandingSignupCompletionService.storageKey,
    );
    expect(pendingSignup, isNotNull);
    expect(pendingSignup, contains('lp_exp_h04_treatment_signup_complete'));
    expect(pendingSignup, contains('first-user@example.com'));
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
    expect(adapter.conversionVisitorIds.toSet(), hasLength(1));
    expect(
      find.byKey(const Key('landing_h04_inline_open_inbox')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'trial results stay visible instead of jumping to the save form',
    (tester) async {
      for (final useInstantPreview in <bool>[false, true]) {
        for (final size in <Size>[
          const Size(1200, 720),
          const Size(390, 844),
        ]) {
          final adapter = await pumpLanding(
            tester,
            assignment: _assignment(
              'h04',
              LandingExperimentVariant.treatment,
            ),
            size: size,
          );
          if (useInstantPreview) {
            adapter.trialError = const LandingTrialPreviewException(
              'trial_ai_unavailable',
              statusCode: 503,
              canUseInstantPreview: true,
            );
          }

          final promptInput = find.byKey(
            const Key('landing_trial_prompt_input'),
          );
          final trialButton = find.byKey(
            const Key('landing_h03_inline_trial_action'),
          );
          await Scrollable.ensureVisible(
            tester.element(trialButton),
            alignment: 0.5,
          );
          await tester.enterText(promptInput, '今日の最優先タスクを1件に絞りたい');
          await tester.pump();
          await Scrollable.ensureVisible(
            tester.element(trialButton),
            alignment: 0.5,
          );
          await tester.pump();
          await tester.tap(trialButton);
          await tester.pump();
          await _completeGuidedTrialWithQuickAnswers(tester);

          final resultAction = find.byKey(
            const Key('landing_trial_result_action'),
          );
          expect(
            resultAction,
            findsOneWidget,
            reason:
                'result missing for instantPreview=$useInstantPreview at $size; '
                'submitted=${adapter.lastTrialPrompt}',
          );
          expect(tester.getTopLeft(resultAction).dy, greaterThanOrEqualTo(0));
          expect(
            tester.getBottomRight(resultAction).dy,
            lessThanOrEqualTo(size.height),
          );
          final email = find.byKey(const Key('landing_h04_inline_email'));
          if (useInstantPreview) {
            expect(email, findsNothing);
          } else {
            expect(
              tester.widget<TextField>(email).focusNode?.hasFocus,
              isFalse,
            );
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      }
    },
  );

  testWidgets(
    'H15 starts with three outcomes without exposing unverified feature claims',
    (tester) async {
      final adapter = await pumpLanding(
        tester,
        assignment: _assignment('h01', LandingExperimentVariant.treatment),
      );

      expect(find.text('最初に、3つの成果から始める'), findsOneWidget);
      expect(find.byKey(const Key('landing_h15_outcome_work')), findsOneWidget);
      expect(
        find.byKey(const Key('landing_h15_outcome_money')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('landing_h15_outcome_learning')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('landing_h15_try_without_signup')),
        findsOneWidget,
      );
      expect(find.text('競馬AI自動予想'), findsNothing);

      final trialCta = find.byKey(const Key('landing_h15_try_without_signup'));
      await Scrollable.ensureVisible(tester.element(trialCta), alignment: 0.7);
      await tester.pump();
      await tester.tap(trialCta);
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        adapter.conversionEvents,
        contains('lp_exp_h01_treatment_feature_outcome_trial'),
      );

      expect(find.text('競馬AI自動予想'), findsNothing);
      expect(
        find.byKey(const Key('landing_h15_feature_catalog_toggle')),
        findsNothing,
      );
      expect(find.textContaining('134機能'), findsNothing);
      expect(
        find.text('悩みを1文入力すると、AIが最初の一手を提案します。実行するかはあなたが決め、役立つ提案だけ登録後に引き継げます。'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'custom trial prompt hides the unrelated fixed sample after editing',
    (tester) async {
      await pumpLanding(
        tester,
        assignment: _assignment('h01', LandingExperimentVariant.treatment),
      );

      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsOneWidget,
      );
      expect(find.text('入力例と提案サンプル'), findsOneWidget);
      expect(
        find.textContaining('実際の提案は、入力内容によって変わります'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('landing_trial_prompt_input')),
        'サブスクで無駄な支払いが多い。サブスクを棚卸ししたい。',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsOneWidget,
      );

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsNothing,
      );
      expect(find.text('提案例: 止まっている案件を1つ選ぶ'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('landing_trial_prompt_input')),
        '',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'trial prompt keeps focus while characters are entered one at a time',
    (tester) async {
      await pumpLanding(
        tester,
        assignment: _assignment('h01', LandingExperimentVariant.treatment),
      );

      final promptInput = find.byKey(
        const Key('landing_trial_prompt_input'),
      );
      await Scrollable.ensureVisible(tester.element(promptInput));
      await tester.tap(promptInput);
      await tester.pump();

      final focusedNode = FocusManager.instance.primaryFocus;
      expect(focusedNode, isNotNull);
      expect(focusedNode!.hasFocus, isTrue);
      final inputTopLeft = tester.getTopLeft(promptInput);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'あ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(focusedNode));
      expect(focusedNode.hasFocus, isTrue);
      expect(tester.getTopLeft(promptInput), inputTopLeft);

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'あい',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(focusedNode));
      expect(focusedNode.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(promptInput).controller!.text,
        'あい',
      );
    },
  );

  testWidgets(
    'H11 shows proof before interaction and waits for the AI result',
    (tester) async {
      final adapter = await pumpLanding(
        tester,
        assignment: _assignment('h01', LandingExperimentVariant.treatment),
      );
      adapter.trialResponse = Completer<String>();

      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsOneWidget,
      );
      expect(find.textContaining('止まっている案件を1つ選ぶ'), findsOneWidget);
      expect(find.text('入力例と提案サンプル'), findsOneWidget);
      expect(find.textContaining('最初の10分'), findsNothing);

      await tester.tap(
        find.byKey(const Key('landing_h11_answer_preview_action')),
      );
      await tester.pump();

      expect(adapter.trialRuns, 1);
      expect(
        find.byKey(const Key('landing_h11_answer_preview')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('landing_trial_result_action')),
        findsNothing,
      );
      expect(find.byKey(const Key('landing_trial_loading')), findsOneWidget);
      expect(
        find.byKey(const Key('landing_h04_inline_magic_capture')),
        findsNothing,
      );

      adapter.trialResponse!.complete(
        'ACTION: 確認先を1人決める\nREASON: 停滞を最短で解消するため',
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('確認先を1人決める'), findsOneWidget);
      expect(find.byKey(const Key('landing_trial_loading')), findsNothing);
      expect(adapter.lastTrialPrompt, '仕事が多すぎて、何から始めるか決められない');
      expect(
        adapter.conversionEvents,
        containsAll(<String>[
          'lp_exp_h01_treatment_hero_cta',
          'lp_exp_h01_treatment_trial',
        ]),
      );

      await tester.enterText(
        find.byKey(const Key('landing_trial_prompt_input')),
        '別の仕事について相談したい',
      );
      await tester.pump();

      expect(
        find.byKey(const Key('landing_trial_result_action')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('landing_h04_inline_magic_capture')),
        findsNothing,
      );
    },
  );

  testWidgets('trial provider failure shows an honest retry state', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );
    adapter.trialError = Exception('provider unavailable');

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('landing_trial_result_action')), findsNothing);
    expect(find.byKey(const Key('landing_trial_error')), findsOneWidget);
    expect(find.text('AIの回答を取得できませんでした'), findsOneWidget);
    expect(find.byKey(const Key('landing_trial_retry')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );

    adapter.trialError = null;
    await tester.tap(find.byKey(const Key('landing_trial_retry')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('landing_trial_error')), findsNothing);
    expect(find.text('重要な案件を1件選ぶ'), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsOneWidget,
    );
  });

  testWidgets('trial provider fallback shows an honest instant preview', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );
    adapter.trialError = const LandingTrialPreviewException(
      'trial_ai_unavailable',
      statusCode: 503,
      canUseInstantPreview: true,
    );

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('landing_trial_error')), findsNothing);
    expect(find.text('簡易プレビュー（AI未使用）'), findsOneWidget);
    expect(find.textContaining('止まっている作業を1件開き'), findsOneWidget);
    expect(
      find.byKey(const Key('landing_trial_instant_preview_notice')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('landing_trial_ai_retry')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );
    expect(
      adapter.conversionEvents,
      contains('lp_exp_h01_treatment_trial_fallback'),
    );

    adapter.trialError = null;
    final retry = find.byKey(const Key('landing_trial_ai_retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump();

    expect(find.text('簡易プレビュー（AI未使用）'), findsNothing);
    expect(find.text('AIからの提案'), findsOneWidget);
    expect(find.text('重要な案件を1件選ぶ'), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsOneWidget,
    );
  });

  testWidgets(
      'instant preview stays usable without becoming a mobile save path', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );
    adapter.trialError = const LandingTrialPreviewException(
      'trial_ai_unavailable',
      statusCode: 503,
      canUseInstantPreview: true,
    );

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();

    final notice = find.byKey(
      const Key('landing_trial_instant_preview_notice'),
    );
    await tester.ensureVisible(notice);
    await tester.pumpAndSettle();

    expect(notice, findsOneWidget);
    expect(find.byKey(const Key('landing_trial_ai_retry')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const Key('landing_h09_mobile_sticky_cta')),
    );
    await tester.pump();

    expect(adapter.saveCtas, 0);
  });

  testWidgets('trial quota exhaustion explains the daily limit', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );
    adapter.trialError = const LandingTrialPreviewException(
      'trial_quota_exhausted',
      statusCode: 429,
      canUseInstantPreview: true,
    );

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('本日の無料試用回数に達しました'), findsOneWidget);
    expect(find.textContaining('1日3回'), findsOneWidget);
    expect(find.textContaining('日本時間の翌日'), findsOneWidget);
    expect(find.byKey(const Key('landing_trial_result_action')), findsNothing);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );
  });

  testWidgets('empty trial input is not recorded as an AI trial', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );

    await tester.tap(find.byKey(const Key('landing_h03_inline_trial_action')));
    await tester.pump();

    expect(find.text('入力内容を確認してください'), findsOneWidget);
    expect(find.textContaining('1行入力してください'), findsOneWidget);
    expect(adapter.trialRuns, 0);
    expect(adapter.lastTrialPrompt, isNull);
    expect(find.byKey(const Key('landing_trial_result_action')), findsNothing);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );
  });

  testWidgets('custom concern is deep-dived before one generated AI request', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );

    await tester.enterText(
      find.byKey(const Key('landing_trial_prompt_input')),
      'サブスクの支払いが多く、どれから見直すか決められない',
    );
    await tester.tap(find.byKey(const Key('landing_h03_inline_trial_action')));
    await tester.pump();

    expect(
      find.byKey(const Key('landing_trial_guided_intake')),
      findsOneWidget,
    );
    expect(find.text('質問 1 / 5'), findsOneWidget);
    expect(adapter.trialRuns, 0);
    expect(adapter.lastTrialPrompt, isNull);

    await _completeGuidedTrialWithQuickAnswers(tester);

    expect(adapter.trialRuns, 1);
    expect(adapter.lastTrialPrompt, contains('相談:サブスクの支払いが多く'));
    expect(adapter.lastTrialPrompt, contains('目標:まず動き出せればよい'));
    expect(adapter.lastTrialPrompt, contains('回避:大きな変更は避けたい'));
    expect(adapter.lastTrialPrompt!.runes.length, lessThanOrEqualTo(280));
    expect(
      find.byKey(const Key('landing_trial_result_action')),
      findsOneWidget,
    );
  });

  testWidgets('trial provider failure never presents a fixed finance answer', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h01', LandingExperimentVariant.treatment),
    );
    adapter.trialError = Exception('quality gate rejected response');

    await tester.enterText(
      find.byKey(const Key('landing_trial_prompt_input')),
      '家計の固定費が高く、今月どの支出から見直すべきか決められません',
    );
    await tester.tap(find.byKey(const Key('landing_h03_inline_trial_action')));
    await tester.pump();
    await _completeGuidedTrialWithQuickAnswers(tester);

    expect(find.byKey(const Key('landing_trial_result_action')), findsNothing);
    expect(find.text('先月の明細で最も高い固定費を1件特定'), findsNothing);
    expect(find.byKey(const Key('landing_trial_error')), findsOneWidget);
    expect(
      find.byKey(const Key('landing_h04_inline_magic_capture')),
      findsNothing,
    );
    expect(
      adapter.conversionEvents,
      contains('lp_exp_h01_treatment_trial_fallback'),
    );
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

  testWidgets('mobile treatment reveals the sticky signup CTA after the hero', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h09', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    final sticky = find.byKey(const Key('landing_h09_mobile_sticky_cta'));
    expect(sticky, findsNothing);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await tester.pump();
    expect(sticky, findsOneWidget);
    await tester.tap(
      find.descendant(of: sticky, matching: find.text('無料で始める')),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      adapter.conversionEvents,
      containsAll(<String>[
        'lp_exp_h09_treatment_mobile_view',
        'lp_exp_h09_treatment_sticky_cta',
      ]),
    );
  });

  testWidgets('mobile sticky CTA restores signup mode and email focus', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h09', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    final passwordToggle = find.byKey(const Key('landing_h04_password_toggle'));
    await Scrollable.ensureVisible(
      tester.element(passwordToggle),
      alignment: 0.35,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(passwordToggle);
    await tester.pump();
    final authModeSelector = find.byKey(
      const Key('landing_auth_mode_selector'),
    );
    await Scrollable.ensureVisible(
      tester.element(authModeSelector),
      alignment: 0.2,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('landing_auth_mode_login_option')),
    );
    await tester.pump();
    expect(find.text('ログインして続きから再開'), findsOneWidget);

    final sticky = find.byKey(const Key('landing_h09_mobile_sticky_cta'));
    await tester.tap(
      find.descendant(of: sticky, matching: find.text('無料で始める')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('今すぐ無料ではじめる'), findsOneWidget);
    expect(find.text('メールで新規登録'), findsOneWidget);
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('landing_auth_email')),
    );
    expect(emailField.focusNode?.hasFocus, isTrue);
    expect(
      adapter.conversionEvents,
      contains('lp_exp_h09_treatment_sticky_cta'),
    );
  });

  testWidgets('mobile Magic Link submit records the mobile signup metric', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h09', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('landing_h04_inline_email')),
      'mobile-first-user@example.com',
    );
    final magicLinkButton = find.byKey(
      const Key('landing_h04_inline_magic_link'),
    );
    await Scrollable.ensureVisible(
      tester.element(magicLinkButton),
      alignment: 0.5,
    );
    await tester.pump();
    await tester.tap(magicLinkButton);
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      adapter.conversionEvents,
      containsAll(<String>[
        'lp_exp_h09_treatment_mobile_view',
        'lp_exp_h09_treatment_signup_submit',
        'lp_exp_h09_treatment_mobile_signup_submit',
      ]),
    );
  });

  testWidgets('mobile trial result turns the sticky CTA into a save path', (
    tester,
  ) async {
    final adapter = await pumpLanding(
      tester,
      assignment: _assignment('h09', LandingExperimentVariant.treatment),
      size: const Size(390, 844),
    );

    await tester.tap(
      find.byKey(const Key('landing_h11_answer_preview_action')),
    );
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await tester.pump();

    final sticky = find.byKey(const Key('landing_h09_mobile_sticky_cta'));
    final saveSticky = find.descendant(
      of: sticky,
      matching: find.text('この提案を保存'),
    );
    expect(saveSticky, findsOneWidget);
    await tester.tap(saveSticky);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(adapter.saveCtas, 1);
    expect(
      adapter.conversionEvents,
      containsAll(<String>[
        'lp_exp_h09_treatment_sticky_cta',
        'lp_exp_h09_treatment_save_cta',
      ]),
    );
    final emailField = tester.widget<TextField>(
      find.byKey(const Key('landing_h04_inline_email')),
    );
    expect(emailField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('mobile H03 does not cover the first-view trial with sticky CTA',
      (
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
    final stickyCta = find.byKey(const Key('landing_h09_mobile_sticky_cta'));
    expect(trialAction, findsOneWidget);
    expect(stickyCta, findsNothing);
    expect(
      tester.getBottomRight(trialAction).dy,
      lessThanOrEqualTo(727),
    );
  });
}
