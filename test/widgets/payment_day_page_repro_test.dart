// Detached regression suite. The production page is instrumented only in the
// isolated CI copy with the debug hooks described by the accompanying task.
// Never use real tokens, real user data, or a production database here.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_liability_repository.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _ownerA = 'synthetic-owner-a';
const _ownerB = 'synthetic-owner-b';
const _tokenA = 'synthetic-token-a';
const _tokenA2 = 'synthetic-token-a-refreshed';
const _tokenB = 'synthetic-token-b';

Session _session(String owner, String token) => Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(
        id: owner,
        appMetadata: const <String, dynamic>{},
        userMetadata: const <String, dynamic>{},
        aud: 'authenticated',
        createdAt: '2026-01-01T00:00:00Z',
      ),
    );

// Models the replay of the most recent AuthState followed by live events.
// Owner and token getters change independently of event delivery.
class _Auth {
  _Auth({this.owner = _ownerA, this.token = _tokenA,
    this.replay = AuthChangeEvent.signedIn});

  String? owner;
  String? token;
  final AuthChangeEvent replay;
  final _events = StreamController<AuthState>.broadcast(sync: true);

  Stream<AuthState> get stream => Stream<AuthState>.multi((sink) {
        final currentOwner = owner;
        final currentToken = token;
        sink.add(AuthState(
          replay,
          currentOwner == null || currentToken == null
              ? null
              : _session(currentOwner, currentToken),
        ));
        final subscription = _events.stream.listen(
          sink.add,
          onError: (Object error, StackTrace stack) => sink.addError(error, stack),
          onDone: sink.close,
        );
        sink.onCancel = subscription.cancel;
      }, isBroadcast: true);

  void change(String? nextOwner, String? nextToken, AuthChangeEvent event) {
    owner = nextOwner;
    token = nextToken;
    _events.add(AuthState(
      event,
      nextOwner == null || nextToken == null ? null : _session(nextOwner, nextToken),
    ));
  }

  void fail() => _events.addError(StateError('synthetic auth stream error'), StackTrace.current);
  Future<void> close() => _events.close();
}

class _Repository extends SharedPreferencesAssetLiabilityRepository {
  final saved = <Map<String, int>>[];
  final saveStarted = Completer<void>();
  Completer<void>? saveRelease;

  @override
  Future<void> saveDebtPaymentDayOverrides(Map<String, int> values) async {
    saved.add(Map<String, int>.of(values));
    if (!saveStarted.isCompleted) saveStarted.complete();
    final release = saveRelease;
    if (release != null) await release.future;
  }
}

class _Transport {
  int reads = 0;
  final readOwners = <String>[];
  final readStarted = Completer<void>();
  final result = Completer<List<Map<String, dynamic>>>();
  final writes = <Map<String, int>>[];

  Future<List<Map<String, dynamic>>> read(String owner) {
    reads++;
    readOwners.add(owner);
    if (!readStarted.isCompleted) readStarted.complete();
    return result.future;
  }

  Future<void> write(Map<String, int> value) async {
    writes.add(Map<String, int>.of(value));
  }
}

Future<Object?> _awaitWithPumps<T>(WidgetTester tester, Future<T> future, String phase) async {
  var done = false;
  Object? value;
  Object? failure;
  StackTrace? failureStack;
  future.then<void>((result) {
    value = result;
    done = true;
  }, onError: (Object error, StackTrace stack) {
    failure = error;
    failureStack = stack;
    done = true;
  });
  for (var i = 0; i < 150 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) throw TestFailure('synthetic phase did not finish: $phase');
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return value;
}

Future<dynamic> _mount(WidgetTester tester, _Auth auth, _Transport transport,
    _Repository repository, {required bool authoritative}) async {
  // Each testWidgets callback owns a fresh FakeAsync zone.
  AssetSyncDirtyKeysStore.resetWriteLockForTest();
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() async {
    if (!transport.result.isCompleted) {
      // A test that never initiated a read must not completeError an unobserved
      // future; harmless empty data simply allows an in-flight read to finish.
      transport.result.complete(<Map<String, dynamic>>[]);
    }
    final saveRelease = repository.saveRelease;
    if (saveRelease != null && !saveRelease.isCompleted) saveRelease.complete();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await auth.close();
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(MaterialApp(home: AssetManagementPage(
    key: key,
    assetLiabilityRepository: repository,
    debugMirrorReadsAuthoritative: authoritative,
    debugDisableDebtBoot: true,
    debugDebtRead: transport.read,
    debugDebtWrite: transport.write,
    debugDebtOwner: () => auth.owner,
    debugDebtToken: () => auth.token,
    debugDebtAuthEvents: auth.stream,
  )));
  await tester.pump(); // Deliver the synthetic replay to the actual listener.
  final dynamic page = key.currentState;
  expect(page, isNotNull);
  page.debugSetDebtForTest(<String, int>{'debt-a': 10});
  await tester.pump();
  return page;
}

Future<void> _finish(WidgetTester tester, dynamic page, Future<void> restore) async {
  await _awaitWithPumps<void>(tester, restore, 'restore completion');
  // These test-only barriers track actual unawaited futures already started by
  // the page; they must never manufacture successful completion.
  await _awaitWithPumps<void>(tester,
      page.debugWaitDebtBackfillsForTest() as Future<void>, 'backfill completion');
  await _awaitWithPumps<void>(tester,
      page.debugWaitDebtSavesForTest() as Future<void>, 'local save completion');
  await _awaitWithPumps<void>(tester,
      page.debugWaitDebtWritesForTest() as Future<void>, 'mirror write completion');
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  for (final authoritative in [false, true]) {
    testWidgets('read exception cannot trigger backfill (authoritative=$authoritative)', (tester) async {
      final auth = _Auth();
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
      transport.result.completeError(StateError('synthetic read failed'), StackTrace.current);
      await _finish(tester, page, restore);
      expect(transport.reads, 1);
      expect(transport.readOwners, <String>[_ownerA]);
      expect(transport.writes, isEmpty);
      expect(page.debugDebtValuesForTest(), <String, int>{'debt-a': 10});
      expect(repository.saved, isEmpty);
    });

    testWidgets('actual missing row backfills once (authoritative=$authoritative)', (tester) async {
      final auth = _Auth();
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
      transport.result.complete(<Map<String, dynamic>>[]);
      await _finish(tester, page, restore);
      expect(transport.reads, 1);
      expect(transport.readOwners, <String>[_ownerA]);
      expect(transport.writes, <Map<String, int>>[<String, int>{'debt-a': 10}],
          reason: 'positive control: a confirmed absent row really backfills');
    });

    if (!authoritative) {
      testWidgets('existing row is not backfilled by non-authoritative read', (tester) async {
        final auth = _Auth();
        final transport = _Transport();
        final repository = _Repository();
        final dynamic page = await _mount(tester, auth, transport, repository,
            authoritative: false);
        final restore = page.debugRestoreDebtForTest() as Future<void>;
        await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
        transport.result.complete(<Map<String, dynamic>>[
          <String, dynamic>{'user_id': _ownerA, 'pref_key': 'debt_payment_day_overrides',
            'value': <String, int>{'debt-a': 10, 'debt-b': 5}, 'updated_at': null},
        ]);
        await _finish(tester, page, restore);
        expect(transport.reads, 1);
        expect(transport.writes, isEmpty);
        expect(page.debugDebtValuesForTest(), <String, int>{'debt-a': 10});
      });
    }

    testWidgets('owner A to B during read rejects even an empty response (authoritative=$authoritative)', (tester) async {
      final auth = _Auth();
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
      auth.change(_ownerB, _tokenB, AuthChangeEvent.signedIn);
      await tester.pump();
      transport.result.complete(<Map<String, dynamic>>[]);
      await _finish(tester, page, restore);
      expect(transport.writes, isEmpty);
      expect(page.debugDebtValuesForTest(), <String, int>{'debt-a': 10});
    });

    testWidgets('auth stream failure during read blocks backfill (authoritative=$authoritative)', (tester) async {
      final auth = _Auth();
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
      auth.fail();
      await tester.pump();
      transport.result.complete(<Map<String, dynamic>>[]);
      await _finish(tester, page, restore);
      expect(transport.writes, isEmpty);
      expect(tester.takeException(), isNull, reason: 'stream failure must be handled');
    });

    testWidgets('same-owner signedIn replay and completed refresh still allow read (authoritative=$authoritative)', (tester) async {
      final auth = _Auth(replay: AuthChangeEvent.signedIn);
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      auth.change(_ownerA, _tokenA2, AuthChangeEvent.tokenRefreshed);
      await tester.pump();
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read after refresh');
      transport.result.complete(<Map<String, dynamic>>[]);
      await _finish(tester, page, restore);
      expect(transport.reads, 1);
      expect(transport.writes, <Map<String, int>>[<String, int>{'debt-a': 10}]);
    });

    testWidgets('token refresh during read rejects old observation (authoritative=$authoritative)', (tester) async {
      final auth = _Auth();
      final transport = _Transport();
      final repository = _Repository();
      final dynamic page = await _mount(tester, auth, transport, repository,
          authoritative: authoritative);
      final restore = page.debugRestoreDebtForTest() as Future<void>;
      await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
      auth.change(_ownerA, _tokenA2, AuthChangeEvent.tokenRefreshed);
      await tester.pump();
      transport.result.complete(<Map<String, dynamic>>[]);
      await _finish(tester, page, restore);
      expect(transport.writes, isEmpty);
    });
  }

  testWidgets('existing row preserves server-only key in authoritative restore', (tester) async {
    final auth = _Auth();
    final transport = _Transport();
    final repository = _Repository();
    final dynamic page = await _mount(tester, auth, transport, repository, authoritative: true);
    final restore = page.debugRestoreDebtForTest() as Future<void>;
    await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
    transport.result.complete(<Map<String, dynamic>>[
      <String, dynamic>{'user_id': _ownerA, 'pref_key': 'debt_payment_day_overrides',
        'value': <String, int>{'debt-a': 10, 'debt-b': 5}, 'updated_at': null},
    ]);
    await _finish(tester, page, restore);
    expect(page.debugDebtValuesForTest(), <String, int>{'debt-a': 10, 'debt-b': 5});
    expect(
      repository.saved.any((value) => value.length == 2 &&
          value['debt-a'] == 10 && value['debt-b'] == 5),
      isTrue,
      reason: 'the restored map must be persisted with both exact keys',
    );
    for (final payload in transport.writes) {
      expect(payload['debt-b'], 5, reason: 'no incomplete whole-map write');
    }
  });

  testWidgets('a different owner before restore is never read or written', (tester) async {
    final auth = _Auth();
    final transport = _Transport();
    final repository = _Repository();
    final dynamic page = await _mount(tester, auth, transport, repository, authoritative: true);
    auth.change(_ownerB, _tokenB, AuthChangeEvent.signedIn);
    await tester.pump();
    await _finish(tester, page, page.debugRestoreDebtForTest() as Future<void>);
    expect(transport.reads, 0);
    expect(transport.writes, isEmpty);
    expect(page.debugDebtValuesForTest(), <String, int>{'debt-a': 10});
  });

  testWidgets('a page opened before login does not attribute unknown local data to new owner', (tester) async {
    final auth = _Auth(owner: null, token: null, replay: AuthChangeEvent.initialSession);
    final transport = _Transport();
    final repository = _Repository();
    final dynamic page = await _mount(tester, auth, transport, repository, authoritative: true);
    auth.change(_ownerA, _tokenA, AuthChangeEvent.signedIn);
    await tester.pump();
    await _finish(tester, page, page.debugRestoreDebtForTest() as Future<void>);
    expect(transport.reads, 0);
    expect(transport.writes, isEmpty);
  });

  testWidgets('owner changes during local restore save prevent later server write', (tester) async {
    final auth = _Auth();
    final transport = _Transport();
    final repository = _Repository()..saveRelease = Completer<void>();
    final dynamic page = await _mount(tester, auth, transport, repository, authoritative: true);
    final restore = page.debugRestoreDebtForTest() as Future<void>;
    await _awaitWithPumps<void>(tester, transport.readStarted.future, 'read started');
    transport.result.complete(<Map<String, dynamic>>[
      <String, dynamic>{'user_id': _ownerA, 'pref_key': 'debt_payment_day_overrides',
        'value': <String, int>{'debt-a': 10, 'debt-b': 5}, 'updated_at': null},
    ]);
    await _awaitWithPumps<void>(tester, repository.saveStarted.future, 'local save started');
    auth.change(_ownerB, _tokenB, AuthChangeEvent.signedIn);
    await tester.pump();
    repository.saveRelease!.complete();
    await _finish(tester, page, restore);
    expect(transport.writes, isEmpty);
  });

  testWidgets('auth stream subscription is released when page is disposed', (tester) async {
    final auth = _Auth();
    final transport = _Transport();
    final repository = _Repository();
    await _mount(tester, auth, transport, repository, authoritative: true);
    expect(auth._events.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(auth._events.hasListener, isFalse);
  });
}
