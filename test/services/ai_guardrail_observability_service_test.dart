import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_guardrail_observability_service.dart';

void main() {
  test('fetchOverview maps privacy-safe guardrail statistics', () async {
    final service = AiGuardrailObservabilityService(
      invoker: (body) async {
        expect(body, {
          'action': 'observability.guardrails',
          'window_days': 30,
          'limit': 12,
        });
        return _overviewResponse();
      },
    );

    final overview = await service.fetchOverview(windowDays: 30, limit: 12);

    expect(overview.summary.sampledEvents, 8);
    expect(overview.summary.allowed, 5);
    expect(overview.summary.blocked, 2);
    expect(overview.summary.redacted, 1);
    expect(overview.summary.averageLatencyMs, 4);
    expect(overview.summary.categories.single.category, 'pii_email');
    expect(overview.summary.categories.single.count, 3);
    expect(overview.recentEvents.single.decision, 'redact');
    expect(overview.recentEvents.single.categories, ['pii_email']);
    expect(overview.recentEvents.single.shortTraceId, 'trace-123456');
    expect(overview.rawContentStored, isFalse);
    expect(overview.userIdReturned, isFalse);
  });

  test('fetchOverview clamps the requested window and event limit', () async {
    final service = AiGuardrailObservabilityService(
      invoker: (body) async {
        expect(body['window_days'], 90);
        expect(body['limit'], 1);
        return _overviewResponse();
      },
    );

    await service.fetchOverview(windowDays: 120, limit: 0);
  });

  test(
    'fetchOverview maps admin_required to a safe operator message',
    () async {
      final service = AiGuardrailObservabilityService(
        invoker: (_) async => <String, dynamic>{
          'success': false,
          'error': 'admin_required',
          'message': 'backend detail must not be displayed',
        },
      );

      await expectLater(
        service.fetchOverview(),
        throwsA(
          isA<AiGuardrailObservabilityException>()
              .having((error) => error.adminRequired, 'adminRequired', isTrue)
              .having(
                (error) => error.message,
                'message',
                '管理者アカウントでログインしてください。',
              ),
        ),
      );
    },
  );

  test('fetchOverview tolerates missing optional arrays', () async {
    final service = AiGuardrailObservabilityService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'summary': <String, dynamic>{'window_days': 7},
        'privacy': <String, dynamic>{
          'raw_content_stored': false,
          'user_id_returned': false,
        },
      },
    );

    final overview = await service.fetchOverview();

    expect(overview.summary.sampledEvents, 0);
    expect(overview.summary.categories, isEmpty);
    expect(overview.recentEvents, isEmpty);
  });
}

Map<String, dynamic> _overviewResponse() {
  return <String, dynamic>{
    'success': true,
    'summary': <String, dynamic>{
      'window_days': 30,
      'sampled_events': 8,
      'sample_limited': false,
      'allowed': 5,
      'blocked': 2,
      'redacted': 1,
      'average_latency_ms': 4,
      'categories': <Map<String, dynamic>>[
        <String, dynamic>{'category': 'pii_email', 'count': 3},
      ],
    },
    'recent_events': <Map<String, dynamic>>[
      <String, dynamic>{
        'trace_id': 'trace-1234567890',
        'provider': 'writer',
        'action': 'provider.chat',
        'stage': 'output',
        'decision': 'redact',
        'categories': <String>['pii_email'],
        'redaction_count': 1,
        'latency_ms': 3,
        'content_chars': 120,
        'policy_version': 'writer-content-v1',
        'created_at': '2026-08-24T01:02:03.000Z',
      },
    ],
    'privacy': <String, dynamic>{
      'raw_content_stored': false,
      'user_id_returned': false,
    },
  };
}
