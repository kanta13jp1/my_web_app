import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/services/supabase_trace_context.dart';

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
}
