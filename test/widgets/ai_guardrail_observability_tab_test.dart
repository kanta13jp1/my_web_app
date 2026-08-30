import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_guardrail_observability_service.dart';
import 'package:my_web_app/widgets/ai_guardrail_observability_tab.dart';

void main() {
  for (final size in <Size>[const Size(390, 844), const Size(1200, 900)]) {
    testWidgets('renders privacy-safe overview at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = AiGuardrailObservabilityService(
        invoker: (_) async => _overviewResponse(),
      );

      await tester.pumpWidget(_app(service));
      await tester.pumpAndSettle();

      expect(find.text('Writer Content Guardrails'), findsOneWidget);
      expect(find.byKey(const Key('guardrail-privacy-notice')), findsOneWidget);
      expect(find.textContaining('本文と利用者IDは保存・返却していません'), findsOneWidget);
      expect(find.text('ブロック'), findsOneWidget);
      expect(find.text('マスキング'), findsOneWidget);
      expect(find.text('pii_email  3'), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(find.textContaining('secret prompt body'), findsNothing);
      expect(find.textContaining('user-123'), findsNothing);
    });
  }

  testWidgets('shows a safe empty state without event content', (tester) async {
    final service = AiGuardrailObservabilityService(
      invoker: (_) async => <String, dynamic>{
        'success': true,
        'summary': <String, dynamic>{
          'window_days': 7,
          'sampled_events': 0,
          'categories': <Object>[],
        },
        'recent_events': <Object>[],
        'privacy': <String, dynamic>{
          'raw_content_stored': false,
          'user_id_returned': false,
        },
      },
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('guardrail-empty')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('選択期間内のガードレール判定はありません。'), findsOneWidget);
  });

  testWidgets('shows admin guidance for an unauthorized operator', (
    tester,
  ) async {
    final service = AiGuardrailObservabilityService(
      invoker: (_) async => <String, dynamic>{
        'success': false,
        'error': 'admin_required',
        'message': 'sensitive backend detail',
      },
    );

    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('管理者アカウントでログインしてください。'), findsOneWidget);
    expect(find.textContaining('sensitive backend detail'), findsNothing);
    expect(find.text('再試行'), findsOneWidget);
  });
}

Widget _app(AiGuardrailObservabilityService service) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: AiGuardrailObservabilityTab(service: service),
    ),
  );
}

Map<String, dynamic> _overviewResponse() {
  return <String, dynamic>{
    'success': true,
    'summary': <String, dynamic>{
      'window_days': 7,
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
        'prompt': 'secret prompt body',
        'user_id': 'user-123',
      },
    ],
    'privacy': <String, dynamic>{
      'raw_content_stored': false,
      'user_id_returned': false,
    },
  };
}
