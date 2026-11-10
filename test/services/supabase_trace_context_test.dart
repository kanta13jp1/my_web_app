import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/asset_waste_training_ai_service.dart';
import 'package:my_web_app/services/supabase_trace_context.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses the active Sentry trace for a normal sampled request', () async {
    String? correlated;
    final provider = SupabaseSentryTraceContextProvider(
      activeTraceProvider: () => const ActiveSentryTrace(
        traceId: '0123456789abcdef0123456789abcdef',
        spanId: '0123456789abcdef',
        sampled: true,
      ),
      correlateTrace: (traceId) async => correlated = traceId,
    );

    final context = await provider();

    expect(
      context.traceparent,
      '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01',
    );
    expect(correlated, '0123456789abcdef0123456789abcdef');
    expect(context.tracestate, isNull);
    expect(context.baggage, isNull);
    expect(
      context.sentryTrace,
      '0123456789abcdef0123456789abcdef-0123456789abcdef-1',
    );
  });

  test('preserves an unsampled Sentry decision for slow traces', () async {
    final provider = SupabaseSentryTraceContextProvider(
      activeTraceProvider: () => const ActiveSentryTrace(
        traceId: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        spanId: 'bbbbbbbbbbbbbbbb',
        sampled: false,
      ),
      correlateTrace: (_) async {},
    );

    final context = await provider();

    expect(
      context.traceparent,
      '00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-00',
    );
    expect(
      context.sentryTrace,
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-0',
    );
  });

  test('generates a fresh safe context when Sentry has no active span',
      () async {
    final generated = <String>[
      'cccccccccccccccccccccccccccccccc',
      'dddddddddddddddd',
    ];
    final provider = SupabaseSentryTraceContextProvider(
      activeTraceProvider: () => null,
      idGenerator: (_) => generated.removeAt(0),
      correlateTrace: (_) async {},
    );

    final context = await provider();

    expect(
      context.traceparent,
      '00-cccccccccccccccccccccccccccccccc-dddddddddddddddd-01',
    );
    expect(context.sentryTrace, isNull);
  });

  test('injects trace headers through the shared Supabase HTTP client',
      () async {
    late Map<String, String> sentHeaders;
    final client = SupabaseTracingHttpClient(
      inner: MockClient((request) async {
        sentHeaders = request.headers;
        return http.Response('{}', 200);
      }),
      traceContextProvider: () async => const SupabaseTraceContext(
        traceparent: '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01',
        tracestate: 'vendor=value',
        baggage: 'sentry-environment=production',
        sentryTrace: '0123456789abcdef0123456789abcdef-0123456789abcdef-1',
      ),
    );
    addTearDown(client.close);

    await client.get(Uri.parse('https://example.supabase.co/rest/v1/items'));

    expect(
      sentHeaders['traceparent'],
      '00-0123456789abcdef0123456789abcdef-0123456789abcdef-01',
    );
    expect(sentHeaders['tracestate'], 'vendor=value');
    expect(sentHeaders['baggage'], 'sentry-environment=production');
    expect(
      sentHeaders['sentry-trace'],
      '0123456789abcdef0123456789abcdef-0123456789abcdef-1',
    );
  });

  test('does not overwrite an explicitly supplied traceparent', () async {
    late Map<String, String> sentHeaders;
    final client = SupabaseTracingHttpClient(
      inner: MockClient((request) async {
        sentHeaders = request.headers;
        return http.Response('{}', 200);
      }),
      traceContextProvider: () async => const SupabaseTraceContext(
        traceparent: '00-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-01',
      ),
    );
    addTearDown(client.close);
    final request = http.Request(
      'GET',
      Uri.parse('https://example.supabase.co/auth/v1/user'),
    )..headers['traceparent'] =
        '00-11111111111111111111111111111111-2222222222222222-00';

    await client.send(request);

    expect(
      sentHeaders['traceparent'],
      '00-11111111111111111111111111111111-2222222222222222-00',
    );
  });

  test('scoped matching owner and actual bearer pass with one session read',
      () async {
    var sends = 0;
    var reads = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final guard = _fixtureGuard(() {
      reads += 1;
      return _fixtureSession();
    });

    await _sendGuarded(client, guard, _fixtureRequest());

    expect(sends, 1);
    expect(reads, 1);
  });

  for (final change in const ['owner-change', 'logout']) {
    test('$change before trace wait rejects before transport handoff',
        () async {
      Session? session = _fixtureSession();
      var sends = 0;
      final client = _fixtureClient((_) async {
        sends += 1;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final guard = _fixtureGuard(() => session);
      session = change == 'logout'
          ? null
          : _fixtureSession(ownerId: 'fixture-owner-b');

      await expectLater(
        _sendGuarded(client, guard, _fixtureRequest()),
        throwsA(isA<SupabaseRequestSendRejected>()),
      );

      expect(sends, 0);
    });

    test('$change during trace wait rejects after that wait', () async {
      Session? session = _fixtureSession();
      final entered = Completer<void>();
      final release = Completer<SupabaseTraceContext>();
      var sends = 0;
      final client = _fixtureClient(
        (_) async {
          sends += 1;
          return http.Response('{}', 200);
        },
        traceContextProvider: () {
          entered.complete();
          return release.future;
        },
      );
      addTearDown(client.close);
      final guard = _fixtureGuard(() => session);
      final pending = _sendGuarded(client, guard, _fixtureRequest());
      final rejected = expectLater(
        pending,
        throwsA(isA<SupabaseRequestSendRejected>()),
      );
      await entered.future;
      session = change == 'logout'
          ? null
          : _fixtureSession(ownerId: 'fixture-owner-b');
      release.complete(_fixtureTraceContext);
      await rejected;

      expect(sends, 0);
    });
  }

  test('A to B to A rejects an actual bearer selected while B was current',
      () async {
    Session? session = _fixtureSession();
    final entered = Completer<void>();
    final release = Completer<SupabaseTraceContext>();
    var sends = 0;
    final client = _fixtureClient(
      (_) async {
        sends += 1;
        return http.Response('{}', 200);
      },
      traceContextProvider: () {
        entered.complete();
        return release.future;
      },
    );
    addTearDown(client.close);
    final guard = _fixtureGuard(() => session);
    final pending = _sendGuarded(
      client,
      guard,
      _fixtureRequest(bearer: 'fixture-token-b'),
    );
    final rejected = expectLater(
      pending,
      throwsA(isA<SupabaseRequestSendRejected>()),
    );
    await entered.future;
    session = _fixtureSession(
      ownerId: 'fixture-owner-b',
      token: 'fixture-token-b',
    );
    session = _fixtureSession();
    release.complete(_fixtureTraceContext);
    await rejected;

    expect(sends, 0);
  });

  test('an explicit Authorization override fails the scoped actual-bearer gate',
      () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);

    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(_fixtureSession),
        _fixtureRequest(bearer: 'fixture-override-token'),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );

    expect(sends, 0);
  });

  test('a missing header or empty session credential rejects without fallback',
      () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(_fixtureSession),
        _fixtureRequest(bearer: null),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );
    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(() => _fixtureSession(token: '')),
        _fixtureRequest(bearer: ''),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );

    expect(sends, 0);
  });

  test('Auth refresh within the Zone keeps its existing transport behavior',
      () async {
    var sends = 0;
    var reads = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final guard = _fixtureGuard(() {
      reads += 1;
      return null;
    });

    await _sendGuarded(
      client,
      guard,
      _fixtureRequest(
        path: '/auth/v1/token',
        bearer: 'fixture-publishable-key',
      ),
    );

    expect(sends, 1);
    expect(reads, 0);
  });

  test('unscoped function calls preserve existing behavior', () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);

    await client.send(_fixtureRequest(bearer: null));

    expect(sends, 1);
  });

  test('parallel Zones use their own validator after independent trace waits',
      () async {
    Session? session = _fixtureSession();
    final entered = Completer<void>();
    final releases = [
      Completer<SupabaseTraceContext>(),
      Completer<SupabaseTraceContext>(),
      Completer<SupabaseTraceContext>(),
    ];
    var providerCalls = 0;
    var sends = 0;
    var aValidations = 0;
    var bValidations = 0;
    final client = _fixtureClient(
      (_) async {
        sends += 1;
        return http.Response('{}', 200);
      },
      traceContextProvider: () {
        final release = releases[providerCalls++];
        if (providerCalls == 2) entered.complete();
        return release.future;
      },
    );
    addTearDown(client.close);
    final aGuard = _fixtureGuard(() => session);
    final aPending = runWithSupabaseRequestSendValidator(
      (request) {
        aValidations += 1;
        return aGuard.allows(request);
      },
      () => client.send(_fixtureRequest()),
    );
    final aRejected = expectLater(
      aPending,
      throwsA(isA<SupabaseRequestSendRejected>()),
    );
    session = _fixtureSession(
      ownerId: 'fixture-owner-b',
      token: 'fixture-token-b',
    );
    final bGuard = _fixtureGuard(
      () => session,
      expectedOwnerId: 'fixture-owner-b',
    );
    final bPending = runWithSupabaseRequestSendValidator(
      (request) {
        bValidations += 1;
        return bGuard.allows(request);
      },
      () => client.send(_fixtureRequest(bearer: 'fixture-token-b')),
    );
    await entered.future;
    releases[1].complete(_fixtureTraceContext);
    await bPending;
    releases[0].complete(_fixtureTraceContext);
    await aRejected;

    expect(sends, 1);
    expect(aValidations, 1);
    expect(bValidations, 1);
    releases[2].complete(_fixtureTraceContext);
    await client.send(_fixtureRequest(bearer: null));
    expect(sends, 2);
    expect(aValidations, 1);
    expect(bValidations, 1);
    expect(providerCalls, 3);
  });

  test('the scoped function rejects a different configured origin', () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);

    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(_fixtureSession),
        _fixtureRequest(origin: 'https://other.fixture.invalid'),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );

    expect(sends, 0);
  });

  test('the scoped function rejects a different HTTP method', () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);

    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(_fixtureSession),
        _fixtureRequest(method: 'GET'),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );

    expect(sends, 0);
  });

  test('same-owner refresh with a matching actual bearer still passes',
      () async {
    Session? session = _fixtureSession();
    final entered = Completer<void>();
    final release = Completer<SupabaseTraceContext>();
    var sends = 0;
    final client = _fixtureClient(
      (_) async {
        sends += 1;
        return http.Response('{}', 200);
      },
      traceContextProvider: () {
        entered.complete();
        return release.future;
      },
    );
    addTearDown(client.close);
    final pending = _sendGuarded(
      client,
      _fixtureGuard(() => session),
      _fixtureRequest(bearer: 'fixture-token-a-refreshed'),
    );
    await entered.future;
    session = _fixtureSession(token: 'fixture-token-a-refreshed');
    release.complete(_fixtureTraceContext);
    await pending;

    expect(sends, 1);
  });

  test('same-owner refresh rejects a stale actual bearer', () async {
    var sends = 0;
    final client = _fixtureClient((_) async {
      sends += 1;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);

    await expectLater(
      _sendGuarded(
        client,
        _fixtureGuard(
          () => _fixtureSession(token: 'fixture-token-a-refreshed'),
        ),
        _fixtureRequest(),
      ),
      throwsA(isA<SupabaseRequestSendRejected>()),
    );

    expect(sends, 0);
  });

  test('a context change after handoff does not claim in-flight cancellation',
      () async {
    Session? session = _fixtureSession();
    final entered = Completer<void>();
    final reply = Completer<http.Response>();
    var sends = 0;
    final client = _fixtureClient((_) {
      sends += 1;
      entered.complete();
      return reply.future;
    });
    addTearDown(client.close);
    final pending = _sendGuarded(
      client,
      _fixtureGuard(() => session),
      _fixtureRequest(),
    );
    await entered.future;
    session = null;
    reply.complete(http.Response('{}', 200));
    final response = await pending;

    expect(sends, 1);
    expect(response.statusCode, 200);
  });
}

const _fixtureTraceContext = SupabaseTraceContext(
  traceparent: '00-11111111111111111111111111111111-2222222222222222-01',
);

SupabaseTracingHttpClient _fixtureClient(
  Future<http.Response> Function(http.Request request) onSend, {
  SupabaseTraceContextProvider? traceContextProvider,
}) =>
    SupabaseTracingHttpClient(
      inner: MockClient(onSend),
      traceContextProvider:
          traceContextProvider ?? () async => _fixtureTraceContext,
    );

AssetWasteTrainingOwnerSendGuard _fixtureGuard(
  Session? Function() readCurrentSession, {
  String expectedOwnerId = 'fixture-owner-a',
}) =>
    AssetWasteTrainingOwnerSendGuard(
      expectedOwnerId: expectedOwnerId,
      supabaseOrigin: Uri.parse('https://fixture.supabase.invalid'),
      readCurrentSession: readCurrentSession,
    );

Future<http.StreamedResponse> _sendGuarded(
  SupabaseTracingHttpClient client,
  AssetWasteTrainingOwnerSendGuard guard,
  http.Request request,
) =>
    runWithSupabaseRequestSendValidator(
      guard.allows,
      () => client.send(request),
    );

http.Request _fixtureRequest({
  String? bearer = 'fixture-token-a',
  String method = 'POST',
  String path = '/functions/v1/ai-hub',
  String origin = 'https://fixture.supabase.invalid',
}) {
  final request = http.Request(method, Uri.parse('$origin$path'));
  if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
  return request;
}

Session _fixtureSession({
  String ownerId = 'fixture-owner-a',
  String token = 'fixture-token-a',
}) =>
    Session(
      accessToken: token,
      tokenType: 'bearer',
      user: User(
        id: ownerId,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: '2026-11-11T00:00:00Z',
      ),
    );
