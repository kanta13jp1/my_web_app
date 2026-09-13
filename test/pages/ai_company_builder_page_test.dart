import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_company_builder_page.dart';
import 'package:my_web_app/services/ai_company_builder_service.dart';

class _FakeCompanyBuilderService extends AiCompanyBuilderService {
  _FakeCompanyBuilderService({this.includeTimeout = false});

  final bool includeTimeout;
  final List<String> commands = <String>[];
  final List<String> researchUrls = <String>[];

  @override
  bool get isSignedIn => true;

  @override
  Future<List<Map<String, dynamic>>> listCompanies() async => [
        {
          'id': 'company-1',
          'created_at': '2026-08-16T00:00:00Z',
          'metadata': {
            'company_name': 'Signal School',
            'summary': 'Daily evidence-led lessons for founders.',
            'passed': true,
            'status': 'approved',
            'overall_score': 8.1,
          },
        },
      ];

  @override
  Future<Map<String, dynamic>> getCompany(String companyId) async => {
        'company': {
          'id': companyId,
          'metadata': {
            'company_name': 'Signal School',
            'offer': 'Daily evidence-led lessons for founders.',
            'audience': 'Japanese founders',
            'business_model': 'Subscription',
            'passed': true,
            'status': 'approved',
            'overall_score': 8.1,
            'threshold': 7.0,
            'criteria': <Map<String, dynamic>>[],
            'launch_channels': <String>['Direct outreach'],
          },
        },
        'manager_agents': <Map<String, dynamic>>[],
        'tool_agents': <Map<String, dynamic>>[],
        'tasks': [
          {
            'id': 'task-1',
            'title': 'Shape the MVP',
            'description': 'Keep one painful workflow.',
            'status': 'queued',
            'metadata': {'stage': 'product'},
          },
        ],
        'vault_notes': <Map<String, dynamic>>[],
        'audit_entries': <Map<String, dynamic>>[],
        'runtime_events': [
          if (includeTimeout)
            {
              'event_type': 'task_timed_out',
              'status': 'failed',
              'occurred_at': '2026-09-03T00:00:00Z',
              'payload': {
                'title': 'Shape the MVP',
                'timeout_seconds': 300,
              },
            },
          {
            'event_type': 'bootstrap_completed',
            'status': 'idle',
            'occurred_at': '2026-08-16T00:00:00Z',
            'payload': <String, dynamic>{},
          },
        ],
        'runtime_control': {
          'state': commands.isEmpty ? 'idle' : 'running',
          'kill_switch': false,
        },
        'runtime_master_control': {'kill_switch': false},
        'research_sources': [
          {
            'id': 'source-1',
            'title': 'Pricing evidence',
            'source_url': 'https://example.com/pricing',
            'excerpt': 'The pro plan costs twenty dollars.',
            'status': 'ready',
          },
        ],
        'routing_profiles': [
          {
            'routing_key': 'company_builder.finance',
            'current_tier': 'budget',
            'last_decision': 'downgraded_after_5_successes',
          },
        ],
        'a2a_agent_card_url':
            'https://example.com/functions/v1/ai-hub/.well-known/agent-card.json',
      };

  @override
  Future<Map<String, dynamic>> runtimeCommand({
    required String companyId,
    required String command,
  }) async {
    commands.add(command);
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> addResearchSource({
    required String companyId,
    required String sourceUrl,
  }) async {
    researchUrls.add(sourceUrl);
    return {'success': true};
  }

  @override
  void subscribe(String companyId, void Function() onChange) {}

  @override
  Future<void> dispose() async {}
}

Future<void> _pumpPage(
  WidgetTester tester,
  _FakeCompanyBuilderService service,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: AiCompanyBuilderPage(service: service)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts a viable company runtime', (tester) async {
    final service = _FakeCompanyBuilderService();
    await _pumpPage(tester, service, const Size(390, 844));

    expect(find.text('Company Runtime'), findsOneWidget);
    expect(find.text('Live Runtime Events'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('company-builder-scroll')),
      const Offset(0, -1300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('company-runtime-start')));
    await tester.pumpAndSettle();

    expect(service.commands, ['start']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the desktop workspace overflow-free', (tester) async {
    final service = _FakeCompanyBuilderService();
    await _pumpPage(tester, service, const Size(1280, 900));

    expect(find.text('Company Instances'), findsOneWidget);
    expect(find.text('Signal School'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('surfaces an agent timeout alert', (tester) async {
    final service = _FakeCompanyBuilderService(includeTimeout: true);
    await _pumpPage(tester, service, const Size(390, 844));

    expect(
      find.byKey(const Key('company-runtime-timeout-alert')),
      findsOneWidget,
    );
    expect(
      find.textContaining('task was stopped after five minutes'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a cited research source and exposes the A2A card', (
    tester,
  ) async {
    final service = _FakeCompanyBuilderService();
    await _pumpPage(tester, service, const Size(390, 844));

    await tester.scrollUntilVisible(
      find.byKey(const Key('company-research-source-url')),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('company-research-source-url')),
      'https://docs.example.com/market',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('company-research-add')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('company-research-add')));
    await tester.pumpAndSettle();

    expect(service.researchUrls, ['https://docs.example.com/market']);
    expect(find.text('Pricing evidence'), findsOneWidget);
    expect(find.byKey(const Key('company-a2a-agent-card-url')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
