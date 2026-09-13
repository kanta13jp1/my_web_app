import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/shop_attribution.dart';
import 'package:my_web_app/models/shop_login_continuation.dart';
import 'package:my_web_app/pages/landing_page.dart';
import 'package:my_web_app/services/growth_mission_service.dart';
import 'package:my_web_app/services/landing_conversion_experiment_service.dart';
import 'package:my_web_app/services/landing_page_adapter.dart';
import 'package:my_web_app/services/landing_signup_completion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Adapter extends Fake implements LandingPageAdapter {
  final events = StreamController<AuthState>.broadcast(sync: true);

  @override
  Stream<AuthState> authStateChanges() => events.stream;

  @override
  Future<LandingSocialProofStats> loadSocialProofStats() async =>
      const LandingSocialProofStats.empty();
}

class _Growth extends Fake implements GrowthMissionService {
  @override
  Future<void> capturePendingReferralFromUri({Uri? currentUri}) async {}
  @override
  Future<String?> loadPendingReferralCode() async => null;
  @override
  Future<void> applyPendingReferralIfPossible() async {}
}

class _Signup extends Fake implements LandingSignupCompletionService {
  @override
  Future<bool> completeIfPending({
    required String? signupUserId,
    String? signupEmail,
    DateTime? accountCreatedAt,
    SharedPreferences? preferences,
  }) async =>
      false;
}

class _RouteObserver extends NavigatorObserver {
  _RouteObserver(this.destinations);
  final List<String> destinations;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) destinations.add(name);
  }
}

// Synthetic in-memory event only: no Supabase sign-in, HTTP or real account.
final _session = Session(
  accessToken: 'synthetic-not-a-real-token',
  tokenType: 'bearer',
  user: const User(
    id: 'synthetic-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-12T00:00:00Z',
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpLogin(
    WidgetTester tester,
    _Adapter adapter,
    Uri loginLocation,
    List<String> destinations, {
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(adapter.events.close);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: [_RouteObserver(destinations)],
        home: LandingPage(
          shopLoginUri: loginLocation,
          landingUri: Uri.parse('/unrelated-browser-location'),
          adapter: adapter,
          growthService: _Growth(),
          signupCompletionService: _Signup(),
          analyticsEnabled: false,
          experimentAssignment: LandingExperimentAssignment(
            hypothesis: LandingConversionExperimentService.hypotheses.first,
            variant: LandingExperimentVariant.control,
          ),
        ),
        onGenerateRoute: (settings) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Destination')),
          );
        },
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    destinations.clear();
  }

  testWidgets('successful sign-in returns to the same product and post',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    final login = ShopLoginContinuation.loginUri(
      productId: 'hexciv-win64',
      attribution: ShopAttribution.parse(source: 'x', contentId: 'post-a'),
    );
    await pumpLogin(tester, adapter, login, destinations);
    adapter.events.add(AuthState(AuthChangeEvent.signedIn, _session));
    await tester.pumpAndSettle();
    expect(destinations, [ShopLoginContinuation.productUri(login).toString()]);
    expect(find.byType(LandingPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restored callback session also returns after app reinitializes',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    final login =
        Uri.parse('/login?shop_product=hexciv-win64&utm_campaign=launch');
    await pumpLogin(tester, adapter, login, destinations);
    adapter.events.add(AuthState(AuthChangeEvent.initialSession, _session));
    await tester.pumpAndSettle();
    expect(destinations, [ShopLoginContinuation.productUri(login).toString()]);
  });

  testWidgets('canceled or signed-out auth cannot trigger a product return',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    await pumpLogin(
      tester,
      adapter,
      Uri.parse('/login?shop_product=hexciv-win64'),
      destinations,
    );
    adapter.events.add(const AuthState(AuthChangeEvent.initialSession, null));
    adapter.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    adapter.events.add(const AuthState(AuthChangeEvent.signedIn, null));
    await tester.pumpAndSettle();
    expect(destinations, isEmpty);
    expect(find.byType(LandingPage), findsOneWidget);
  });

  testWidgets('ordinary sign-in keeps the existing home destination',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    await pumpLogin(tester, adapter, Uri.parse('/login'), destinations);
    adapter.events.add(AuthState(AuthChangeEvent.signedIn, _session));
    await tester.pumpAndSettle();
    expect(destinations, ['/']);
  });

  testWidgets(
      'sign-out before the next frame cancels queued product navigation',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    await pumpLogin(
      tester,
      adapter,
      Uri.parse('/login?shop_product=hexciv-win64&utm_content=post-a'),
      destinations,
    );
    // Deliver both events before rendering: no real account/session mutation.
    adapter.events.add(AuthState(AuthChangeEvent.signedIn, _session));
    adapter.events.add(const AuthState(AuthChangeEvent.signedOut, null));
    await tester.pumpAndSettle();
    expect(destinations, isEmpty);
    expect(find.byType(LandingPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Cancellation must not prevent a later genuine successful sign-in.
    adapter.events.add(AuthState(AuthChangeEvent.signedIn, _session));
    await tester.pumpAndSettle();
    expect(destinations, [
      '/shop/product?product_id=hexciv-win64&utm_source=direct&utm_content=post-a',
    ]);
  });

  testWidgets('hidden landing route cannot override the active page',
      (tester) async {
    final adapter = _Adapter();
    final destinations = <String>[];
    final navigatorKey = GlobalKey<NavigatorState>();
    await pumpLogin(
      tester,
      adapter,
      Uri.parse('/login'),
      destinations,
      navigatorKey: navigatorKey,
    );
    unawaited(
      navigatorKey.currentState!.pushNamed('/shop/product?product_id=other'),
    );
    await tester.pumpAndSettle();
    adapter.events.add(AuthState(AuthChangeEvent.signedIn, _session));
    await tester.pumpAndSettle();
    expect(destinations, ['/shop/product?product_id=other']);
    expect(tester.takeException(), isNull);
  });
}
