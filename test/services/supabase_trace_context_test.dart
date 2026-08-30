import 'package:flutter_test/flutter_test.dart';
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
  });
}
