import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

typedef TraceIdGenerator = String Function(int byteLength);
typedef ActiveSentryTraceProvider = ActiveSentryTrace? Function();
typedef TraceCorrelationCallback = Future<void> Function(String traceId);
typedef SupabaseTraceContextProvider = Future<SupabaseTraceContext> Function();

class SupabaseTraceContext {
  const SupabaseTraceContext({
    required this.traceparent,
    this.tracestate,
    this.baggage,
    this.sentryTrace,
  });

  final String traceparent;
  final String? tracestate;
  final String? baggage;
  final String? sentryTrace;
}

class ActiveSentryTrace {
  const ActiveSentryTrace({
    required this.traceId,
    required this.spanId,
    required this.sampled,
    this.baggage,
  });

  final String traceId;
  final String spanId;
  final bool sampled;
  final String? baggage;
}

/// Adds trace headers to every request made by the shared Supabase client.
///
/// The pinned Supabase SDK exposes one HTTP client for Auth, PostgREST,
/// Storage, and Edge Functions. Decorating that client keeps propagation
/// centralized while preserving the repository's mock-compatible SDK version.
class SupabaseTracingHttpClient extends http.BaseClient {
  SupabaseTracingHttpClient({
    http.Client? inner,
    SupabaseTraceContextProvider? traceContextProvider,
  })  : _inner = inner ?? http.Client(),
        _traceContextProvider =
            traceContextProvider ?? SupabaseSentryTraceContextProvider().call;

  final http.Client _inner;
  final SupabaseTraceContextProvider _traceContextProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final context = await _traceContextProvider();
    _setIfAbsent(request, 'traceparent', context.traceparent);
    _setIfAbsent(request, 'tracestate', context.tracestate);
    _setIfAbsent(request, 'baggage', context.baggage);
    _setIfAbsent(request, 'sentry-trace', context.sentryTrace);
    return _inner.send(request);
  }

  static void _setIfAbsent(
    http.BaseRequest request,
    String name,
    String? value,
  ) {
    if (value == null || value.isEmpty) return;
    final alreadySet = request.headers.keys.any(
      (existing) => existing.toLowerCase() == name,
    );
    if (!alreadySet) request.headers[name] = value;
  }

  @override
  void close() => _inner.close();
}

/// Bridges Sentry's active span to the W3C and Sentry propagation headers.
///
/// When no Sentry span is active, a fresh W3C context is generated without
/// mutating the process-wide Sentry scope. No request body, prompt, response,
/// user data, or credential is copied.
class SupabaseSentryTraceContextProvider {
  SupabaseSentryTraceContextProvider({
    ActiveSentryTraceProvider? activeTraceProvider,
    TraceIdGenerator? idGenerator,
    TraceCorrelationCallback? correlateTrace,
  })  : _activeTraceProvider = activeTraceProvider ?? _readActiveSentryTrace,
        _idGenerator = idGenerator ?? _secureHex,
        _correlateTrace = correlateTrace ?? _noopCorrelation;

  final ActiveSentryTraceProvider _activeTraceProvider;
  final TraceIdGenerator _idGenerator;
  final TraceCorrelationCallback _correlateTrace;

  Future<SupabaseTraceContext> call() async {
    final active = _activeTraceProvider();
    final traceId = active?.traceId ?? _idGenerator(16);
    final spanId = active?.spanId ?? _idGenerator(8);
    final sampled = active?.sampled ?? true;

    await _correlateTrace(traceId);

    return SupabaseTraceContext(
      traceparent: '00-$traceId-$spanId-${sampled ? '01' : '00'}',
      baggage: active?.baggage,
      sentryTrace:
          active == null ? null : '$traceId-$spanId-${sampled ? '1' : '0'}',
    );
  }

  static ActiveSentryTrace? _readActiveSentryTrace() {
    if (!Sentry.isEnabled) return null;
    final span = Sentry.getSpan();
    if (span == null) return null;
    final header = span.toSentryTrace();
    return ActiveSentryTrace(
      traceId: header.traceId.toString(),
      spanId: header.spanId.toString(),
      sampled: header.sampled ?? true,
      baggage: span.toBaggageHeader()?.value,
    );
  }

  static Future<void> _noopCorrelation(String _) async {}

  static String _secureHex(int byteLength) {
    final random = Random.secure();
    return List<int>.generate(byteLength, (_) => random.nextInt(256))
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
