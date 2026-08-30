import 'dart:math';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef TraceIdGenerator = String Function(int byteLength);
typedef ActiveSentryTraceProvider = ActiveSentryTrace? Function();
typedef TraceCorrelationCallback = Future<void> Function(String traceId);

class ActiveSentryTrace {
  const ActiveSentryTrace({
    required this.traceId,
    required this.spanId,
    required this.sampled,
  });

  final String traceId;
  final String spanId;
  final bool sampled;
}

/// Bridges Sentry's active span to Supabase's opt-in W3C trace propagation.
///
/// When no Sentry span is active, a fresh W3C context is generated and its
/// trace ID is attached to the Sentry scope as a correlation-only tag. No
/// request body, prompt, response, user data, or credential is copied.
class SupabaseSentryTraceContextProvider {
  SupabaseSentryTraceContextProvider({
    ActiveSentryTraceProvider? activeTraceProvider,
    TraceIdGenerator? idGenerator,
    TraceCorrelationCallback? correlateTrace,
  })  : _activeTraceProvider = activeTraceProvider ?? _readActiveSentryTrace,
        _idGenerator = idGenerator ?? _secureHex,
        _correlateTrace = correlateTrace ?? _tagSentryScope;

  final ActiveSentryTraceProvider _activeTraceProvider;
  final TraceIdGenerator _idGenerator;
  final TraceCorrelationCallback _correlateTrace;

  Future<TraceContext> call() async {
    final active = _activeTraceProvider();
    final traceId = active?.traceId ?? _idGenerator(16);
    final spanId = active?.spanId ?? _idGenerator(8);
    final sampled = active?.sampled ?? true;

    await _correlateTrace(traceId);

    return TraceContext(
      traceparent: '00-$traceId-$spanId-${sampled ? '01' : '00'}',
    );
  }

  static ActiveSentryTrace? _readActiveSentryTrace() {
    if (!Sentry.isEnabled) return null;
    final header = Sentry.getSpan()?.toSentryTrace();
    if (header == null) return null;
    return ActiveSentryTrace(
      traceId: header.traceId.toString(),
      spanId: header.spanId.toString(),
      sampled: header.sampled ?? true,
    );
  }

  static Future<void> _tagSentryScope(String traceId) async {
    if (!Sentry.isEnabled) return;
    await Sentry.configureScope(
      (scope) => scope.setTag('supabase.trace_id', traceId),
    );
  }

  static String _secureHex(int byteLength) {
    final random = Random.secure();
    return List<int>.generate(byteLength, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
