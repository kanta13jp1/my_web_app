// Review-only candidate for fixed T11. Not analyzed, formatted or executed.
// Requires ENVIRONMENT=test, SUPABASE_URL=http://127.0.0.1:9999 and
// SUPABASE_PUBLISHABLE_KEY=sb_publishable_fixture_owner_ui as Dart defines.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_management_display_mode_store.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/supabase_runtime_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _origin = 'http://127.0.0.1:9999';
const _publishableKey = 'sb_publishable_fixture_owner_ui';
// Captured once for the module, then shared by all snapshot inputs/cases.
// This does not inject every DateTime.now call in the production page.
late final DateTime _fixtureNow;
const _ownerA = '00000000-0000-4000-8000-0000000000a1';
const _ownerB = '00000000-0000-4000-8000-0000000000b2';
const _sentinel = 'OWNER_A_UI_SENTINEL_20261111';
const _noRecords = '支出記録がないため採点・浪費の有無の判定はできません。未記録日は不明です。';

enum _Transition { sameOwner, ownerB, logout }

String _session(String owner) => jsonEncode(<String, Object>{
      'access_token': 'fixture-$owner-not-valid-on-any-server',
      'token_type': 'bearer',
      'user': <String, Object>{
        'id': owner,
        'aud': 'authenticated',
        'app_metadata': <String, Object>{},
        'user_metadata': <String, Object>{},
        'created_at': _fixtureNow.toUtc().toIso8601String(),
      },
    });

class _NoSocketOverrides extends HttpOverrides {
  int socketAttempts = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _NoSocketClient(this);
}

class _NoSocketClient implements HttpClient {
  _NoSocketClient(this.owner);
  final _NoSocketOverrides owner;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    owner.socketAttempts += 1;
    throw const SocketException('No socket transport in owner UI fixture');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('No socket transport in owner UI fixture');
  }
}

// There is no delegate client. Only the exact synthetic A flow read and
// provider.chat request receive data. All other requests receive a denial.
// Request bodies/headers/query values are never stored or printed.
class _MemoryTransport extends http.BaseClient {
  final flowEntered = Completer<void>();
  final flowRelease = Completer<void>();
  final aiEntered = Completer<void>();
  final aiReply = Completer<String>();
  int aiCalls = 0;
  int deniedRequests = 0;
  bool promptContainsOwnedExpense = false;
  bool flowSatisfiesObservedCutoff = false;
  String? fixtureFailure;

  http.StreamedResponse _json(
    http.BaseRequest request,
    Object body,
    int status,
  ) {
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }

  http.StreamedResponse _deny(http.BaseRequest request) {
    deniedRequests += 1;
    return _json(
      request,
      const {
        'code': 'FIXTURE_DENIED',
        'message': 'No fixture for this request',
      },
      403,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != _origin) return _deny(request);
    if (request.method == 'GET' &&
        request.url.path == '/rest/v1/wealth_struggles' &&
        request.url.queryParameters['user_id'] == 'eq.$_ownerA' &&
        request.url.queryParameters['select'] ==
            'id,action_type,amount,description,occurred_at') {
      final filter = request.url.queryParameters['occurred_at'];
      final cutoff = filter != null && filter.startsWith('gte.')
          ? DateTime.tryParse(filter.substring(4))
          : null;
      if (cutoff == null || _fixtureNow.isBefore(cutoff)) {
        fixtureFailure = 'The fixture flow must satisfy the actual gte cutoff';
        return _deny(request);
      }
      flowSatisfiesObservedCutoff = true;
      if (!flowEntered.isCompleted) flowEntered.complete();
      await flowRelease.future;
      return _json(
        request,
        [
          {
            'id': 'fixture-a-expense',
            'action_type': 'expense',
            'amount': 123,
            'description': 'fixture A expense',
            'occurred_at': _fixtureNow.toIso8601String(),
          },
        ],
        200,
      );
    }
    if (request.method == 'POST' &&
        request.url.path == '/functions/v1/ai-hub' &&
        request is http.Request) {
      final data = jsonDecode(request.body);
      if (data is Map && data['action'] == 'provider.chat') {
        aiCalls += 1;
        final message = data['message'];
        promptContainsOwnedExpense = message is String &&
            message.contains('支出総額: 123円') &&
            message.contains('支出記録日: 1/');
        if (aiCalls != 1 || !promptContainsOwnedExpense) return _deny(request);
        if (!aiEntered.isCompleted) aiEntered.complete();
        final summary = await aiReply.future;
        return _json(request, {'success': true, 'text': summary}, 200);
      }
    }
    return _deny(request);
  }

  @override
  void close() {}
}

Finder get _card => find.byKey(const Key('asset_waste_training_ai_card'));

Finder get _review => find.descendant(
      of: _card,
      matching: find.byWidgetPredicate(
        (widget) => widget is FutureBuilder<AssetWasteTrainingAiReview>,
      ),
    );

Finder _inside(String value) =>
    find.descendant(of: _card, matching: find.text(value));

// Only SDK/external event work crosses runAsync. Widget pumps and fixture
// flow/AI gates stay in fakeAsync. Never treat a captured error/null as success.
Future<void> _runSdkBoundary(
  WidgetTester tester,
  Future<void> Function() action,
  String phase, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  Object? callbackError;
  StackTrace? callbackStack;
  final completed = await tester.runAsync<bool>(
    () async {
      try {
        await action().timeout(timeout);
        return true;
      } catch (error, stack) {
        callbackError = error;
        callbackStack = stack;
        return false;
      }
    },
  );
  final error = callbackError;
  if (error != null) {
    debugPrint('owner-ui async-failed: $phase');
    Error.throwWithStackTrace(
      error,
      callbackStack ?? StackTrace.current,
    );
  }
  if (completed != true) {
    debugPrint('owner-ui async-no-success: $phase');
    final frameworkError = tester.takeException();
    if (frameworkError != null) {
      Error.throwWithStackTrace(frameworkError, StackTrace.current);
    }
    fail('SDK async boundary returned no success: $phase');
  }
}

void _phase(_Transition transition, String label) {
  debugPrint('owner-ui ${transition.name}: $label');
}

// A bounded predicate wait, not an assumed number of boot/auth frames.
// Stopwatch is only a failure deadline; product time uses debugNow below.
Future<void> _pumpUntil(
  WidgetTester tester,
  _MemoryTransport transport,
  bool Function() condition,
  String reason,
) async {
  final deadline = Stopwatch()..start();
  while (!condition()) {
    if (transport.fixtureFailure != null) fail(transport.fixtureFailure!);
    if (deadline.elapsed > const Duration(seconds: 10)) fail(reason);
    await tester.pump(const Duration(milliseconds: 16));
    final remaining = const Duration(seconds: 10) - deadline.elapsed;
    if (remaining <= Duration.zero) {
      fail(reason);
    }
    await _runSdkBoundary(
      tester,
      () => Future<void>.delayed(Duration.zero),
      'event-loop-turn',
      timeout: remaining,
    );
    await tester.pump();
  }
  if (transport.fixtureFailure != null) fail(transport.fixtureFailure!);
  await tester.pump();
  if (transport.fixtureFailure != null) fail(transport.fixtureFailure!);
}

Future<void> _showText(WidgetTester tester, Finder text) async {
  expect(text, findsOneWidget);
  expect(tester.widget(text), isA<Text>());
  await tester.ensureVisible(text);
  await tester.pump();
  final viewport = tester.getRect(find.byType(Scaffold).first);
  expect(
    tester.getRect(text).overlaps(viewport),
    isTrue,
    reason: 'The summary Text itself must overlap the actual Scaffold viewport',
  );
}

void main() {
  _fixtureNow = DateTime.now();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final config = SupabaseRuntimeConfig.fromCompileTimeEnvironment();
    expect(
      config.environment == 'test',
      isTrue,
      reason: 'Use ENVIRONMENT=test',
    );
    expect(config.url == _origin, isTrue, reason: 'Use the fixed Mock origin');
    expect(
      config.publishableKey == _publishableKey,
      isTrue,
      reason: 'Use only the fixed dummy publishable key',
    );
  });
  for (final transition in _Transition.values) {
    testWidgets('waste page owner result: ${transition.name}', (tester) async {
      _phase(transition, 'setup');
      final transport = _MemoryTransport();
      final offline = _NoSocketOverrides();
      final previousOverrides = HttpOverrides.current;
      final previousFontFetching = GoogleFonts.config.allowRuntimeFetching;
      HttpOverrides.global = offline;
      GoogleFonts.config.allowRuntimeFetching = false;
      addTearDown(() {
        HttpOverrides.global = previousOverrides;
        GoogleFonts.config.allowRuntimeFetching = previousFontFetching;
      });
      SharedPreferences.setMockInitialValues(<String, Object>{
        'offline_secure_mode_enabled_v1': false,
        'asset_management_display_mode_v1': 'full',
        'asset_management_section_overrides_v1': jsonEncode({
          for (final section in AssetManagementSectionId.values)
            section.storageId: section == AssetManagementSectionId.wasteAi
                ? 'pinned'
                : 'hidden',
        }),
      });
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await http.runWithClient(
        () async {
          await _runSdkBoundary(
            tester,
            () async {
              await Supabase.initialize(
                url: _origin,
                publishableKey: _publishableKey,
                debug: false,
                httpClient: transport,
                authOptions: const FlutterAuthClientOptions(
                  autoRefreshToken: false,
                  detectSessionInUri: false,
                  localStorage: EmptyLocalStorage(),
                ),
              );
            },
            'initialize',
          );
          final auth = Supabase.instance.client.auth;
          final events = <AuthState>[];
          final subscription = auth.onAuthStateChange.listen(events.add);
          try {
            await _runSdkBoundary(
              tester,
              () async {
                await auth.recoverSession(_session(_ownerA));
              },
              'auth-initial',
            );
            expect(auth.currentUser?.id, _ownerA);
            _phase(transition, 'page');
            await tester.pumpWidget(
              MaterialApp(
                home: AssetManagementPage(
                  key: const Key('owner-ui-same-page-instance'),
                  assetLiabilityRepository:
                      const SharedPreferencesAssetLiabilityRepository(),
                  debugNow: _fixtureNow,
                  debugCalendarNow: _fixtureNow,
                  debugInitialAssetData: const {},
                  debugMirrorPrefsRows: const [],
                ),
              ),
            );
            await _pumpUntil(
              tester,
              transport,
              () =>
                  _card.evaluate().isNotEmpty &&
                  transport.flowEntered.isCompleted,
              'The page must start its owner-A flow read and build the actual card',
            );
            expect(transport.flowSatisfiesObservedCutoff, isTrue);
            _phase(transition, 'flow');
            transport.flowRelease.complete();
            await _pumpUntil(
              tester,
              transport,
              () => transport.aiEntered.isCompleted,
              'The real page must hand off exactly one owned provider.chat request',
            );
            expect(transport.aiCalls, 1);
            expect(transport.promptContainsOwnedExpense, isTrue);
            _phase(transition, 'ai');
            expect(_review, findsOneWidget);
            final pageState = tester.state(find.byType(AssetManagementPage));
            final aWidget =
                tester.widget<FutureBuilder<AssetWasteTrainingAiReview>>(
              _review,
            );
            expect(aWidget.key, const ValueKey<String?>(_ownerA));
            final aFuture = aWidget.future!;
            AssetWasteTrainingAiReview? completedA;
            unawaited(aFuture.then((value) => completedA = value));
            expect(_inside(_sentinel), findsNothing);

            _phase(transition, 'auth');
            final eventStart = events.length;
            if (transition == _Transition.ownerB) {
              await _runSdkBoundary(
                tester,
                () async {
                  await auth.recoverSession(_session(_ownerB));
                },
                'auth-switch',
              );
            } else if (transition == _Transition.logout) {
              // Local removal + signedOut occurs before the denied admin request;
              // gotrue2.21 ignores that synthetic403 after local sign-out.
              await _runSdkBoundary(
                tester,
                () async {
                  await auth.signOut();
                },
                'auth-logout',
              );
            }
            if (transition != _Transition.sameOwner) {
              final expectedOwner =
                  transition == _Transition.ownerB ? _ownerB : null;
              await _pumpUntil(
                tester,
                transport,
                () =>
                    auth.currentUser?.id == expectedOwner &&
                    _inside('local-observation-check').evaluate().isNotEmpty,
                'The actual auth event must rebuild the existing card for its owner',
              );
              final expectedEvent = transition == _Transition.logout
                  ? AuthChangeEvent.signedOut
                  : AuthChangeEvent.tokenRefreshed;
              expect(
                events.skip(eventStart).any(
                      (event) =>
                          event.event == expectedEvent &&
                          event.session?.user.id == expectedOwner,
                    ),
                isTrue,
              );
              final next =
                  tester.widget<FutureBuilder<AssetWasteTrainingAiReview>>(
                _review,
              );
              expect(next.key, ValueKey<String?>(expectedOwner));
              expect(identical(next.future, aFuture), isFalse);
              expect(
                tester.state(find.byType(AssetManagementPage)),
                same(pageState),
              );
              expect(_inside(_noRecords), findsOneWidget);
              expect(_inside('記録不足・採点なし'), findsOneWidget);
            }

            _phase(transition, 'reply');
            transport.aiReply.complete(_sentinel);
            await _pumpUntil(
              tester,
              transport,
              () => completedA != null,
              'The old A Future must actually complete, not merely remain pending',
            );
            expect(completedA?.summary, _sentinel);
            if (transition == _Transition.sameOwner) {
              expect(_inside(_sentinel), findsOneWidget);
              await _showText(tester, _inside(_sentinel));
            } else {
              expect(_inside(_sentinel), findsNothing);
              expect(_inside(_noRecords), findsOneWidget);
              expect(_inside('local-observation-check'), findsOneWidget);
              await _showText(tester, _inside(_noRecords));
            }
            expect(transport.aiCalls, 1);
            expect(offline.socketAttempts, 0);
            expect(tester.takeException(), isNull);
          } finally {
            _phase(transition, 'cleanup');
            if (!transport.flowRelease.isCompleted) {
              transport.flowRelease.complete();
            }
            if (!transport.aiReply.isCompleted) {
              transport.aiReply.complete(_sentinel);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            await _runSdkBoundary(
              tester,
              () async {
                await subscription.cancel();
                await Supabase.instance.dispose();
              },
              'cleanup-sdk',
            );
            _phase(transition, 'cleaned');
          }
        },
        () => transport,
      );
    });
  }
}
