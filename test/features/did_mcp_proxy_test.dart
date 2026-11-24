import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/did_mcp_proxy/application/did_mcp_proxy_controller.dart';
import 'package:my_web_app/features/did_mcp_proxy/data/supabase_did_mcp_proxy_repository.dart';
import 'package:my_web_app/features/did_mcp_proxy/did_mcp_proxy_container.dart';
import 'package:my_web_app/features/did_mcp_proxy/domain/did_mcp_proxy_models.dart';

class _FakeDidMcpProxyRepository implements DidMcpProxyRepository {
  _FakeDidMcpProxyRepository({
    required this.events,
    required this.alerts,
  });

  final List<DidMcpProxyEvent> events;
  final List<DidMcpAlert> alerts;

  @override
  Future<DidMcpDashboardSnapshot> fetchDashboard() async {
    return DidMcpDashboardSnapshot(
      events: List<DidMcpProxyEvent>.from(events),
      alerts: List<DidMcpAlert>.from(alerts),
    );
  }

  @override
  Future<String> executeToolCall(final DidMcpExecutionInput input) async {
    events.insert(
      0,
      DidMcpProxyEvent(
        id: 'evt-new',
        toolName: input.tool.wireName,
        rpcMethod: 'tools/call',
        promptSummary: input.prompt,
        status: DidMcpEventStatus.queued,
        httpStatus: 200,
        dryRun: input.dryRun,
        alertDispatched: false,
        latencyMs: 12,
        upstreamHost: 'dry-run',
        createdAt: DateTime.utc(2026, 11, 25, 2, 10),
      ),
    );
    return '{"dry_run": true, "tool": "${input.tool.wireName}"}';
  }

  @override
  Future<DidMcpAlert> acknowledgeAlert(final String alertId) async {
    for (int i = 0; i < alerts.length; i++) {
      if (alerts[i].id == alertId) {
        final DidMcpAlert updated = alerts[i].copyWith(acknowledged: true);
        alerts[i] = updated;
        return updated;
      }
    }
    throw StateError('Alert not found: $alertId');
  }
}

class _DelayedDidMcpProxyRepository implements DidMcpProxyRepository {
  final Completer<DidMcpDashboardSnapshot> dashboardCompleter =
      Completer<DidMcpDashboardSnapshot>();
  final Completer<String> executeCompleter = Completer<String>();
  final Completer<DidMcpAlert> ackCompleter = Completer<DidMcpAlert>();

  @override
  Future<DidMcpDashboardSnapshot> fetchDashboard() => dashboardCompleter.future;

  @override
  Future<String> executeToolCall(final DidMcpExecutionInput input) =>
      executeCompleter.future;

  @override
  Future<DidMcpAlert> acknowledgeAlert(final String alertId) =>
      ackCompleter.future;
}

void main() {
  group('DidMcpProxy models and safety validation', () {
    test('buildDidMcpClientConfigJson exposes public URL without API secrets',
        () {
      final String snippet = buildDidMcpClientConfigJson();
      expect(snippet, contains('https://docs.d-id.com/mcp'));
      expect(snippet.toLowerCase(), isNot(contains('api_key')));
      expect(snippet.toLowerCase(), isNot(contains('authorization')));
    });

    test('DidMcpExecutionInput validates prompt length and encodes JSON-RPC',
        () {
      const DidMcpExecutionInput emptyInput = DidMcpExecutionInput(
        tool: DidMcpTool.docsLookup,
        prompt: '   ',
      );
      expect(emptyInput.validate(), isNotNull);

      const DidMcpExecutionInput validInput = DidMcpExecutionInput(
        tool: DidMcpTool.agentChat,
        prompt: '導入手順を教えてください',
        targetId: 'agt-demo-01',
        dryRun: true,
      );
      expect(validInput.validate(), isNull);
      final Map<String, Object?> rpc = validInput.toJsonRpcBody();
      expect(rpc['method'], 'tools/call');
    });

    test(
        'DidMcpProxyController handles disposal cleanly while async Completers settle',
        () async {
      final _DelayedDidMcpProxyRepository delayedRepo =
          _DelayedDidMcpProxyRepository();
      final DidMcpProxyController controller = DidMcpProxyController(
        repository: delayedRepo,
      );

      final Future<void> loadFuture = controller.loadDashboard();
      final Future<bool> runFuture =
          controller.runToolCall(prompt: 'テスト用 MCP プロンプト');

      controller.dispose();

      delayedRepo.dashboardCompleter.complete(
        const DidMcpDashboardSnapshot(
          events: <DidMcpProxyEvent>[],
          alerts: <DidMcpAlert>[],
        ),
      );
      delayedRepo.executeCompleter.complete('{"ok": true}');

      await loadFuture;
      expect(await runFuture, isFalse);
      expect(controller.state.isLoading, isTrue);
    });
  });

  group('DidMcpProxyContainer widget & a11y', () {
    Future<void> pumpViewport(
      final WidgetTester tester, {
      required final Size size,
      required final Brightness brightness,
      required final DidMcpProxyController controller,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1D4ED8),
              brightness: brightness,
            ),
          ),
          home: Scaffold(
            body: Builder(
              builder: (final BuildContext context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: DidMcpProxyContainer(
                  controller: controller,
                  autoLoad: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'executes dry-run MCP call, acknowledges 429 alert, and passes Light/Dark a11y',
      (final WidgetTester tester) async {
        final SemanticsHandle semanticsHandle = tester.ensureSemantics();
        final _FakeDidMcpProxyRepository repo = _FakeDidMcpProxyRepository(
          events: <DidMcpProxyEvent>[
            DidMcpProxyEvent(
              id: 'evt-rate-1',
              toolName: 'did_generate_talk_video',
              rpcMethod: 'tools/call',
              promptSummary: '大量同時生成テスト',
              status: DidMcpEventStatus.rateLimited,
              httpStatus: 429,
              dryRun: false,
              alertDispatched: true,
              latencyMs: 320,
              upstreamHost: 'api.d-id.com',
              createdAt: DateTime.utc(2026, 11, 25, 1, 0),
            ),
          ],
          alerts: <DidMcpAlert>[
            DidMcpAlert(
              id: 'alt-429-1',
              eventId: 'evt-rate-1',
              severity: 'critical',
              alertType: 'rate_limit',
              message:
                  'HTTP 429 rate limit received on did_generate_talk_video',
              acknowledged: false,
              createdAt: DateTime.utc(2026, 11, 25, 1, 0),
            ),
          ],
        );
        final DidMcpProxyController controller = DidMcpProxyController(
          repository: repo,
        );

        try {
          await controller.loadDashboard();

          await pumpViewport(
            tester,
            size: const Size(360, 800),
            brightness: Brightness.light,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const ValueKey<String>('did-mcp-endpoint-card')),
            findsOneWidget,
          );

          final Finder executeBtn = find.byKey(
            const ValueKey<String>('did-mcp-execute-button'),
          );
          await tester.ensureVisible(executeBtn);
          await tester.tap(executeBtn);
          await tester.pumpAndSettle();

          final Finder resultBanner = find.byKey(
            const ValueKey<String>('did-mcp-result-banner'),
          );
          await tester.ensureVisible(resultBanner);
          expect(resultBanner, findsOneWidget);

          final Finder ackBtn = find.byKey(
            const ValueKey<String>('did-mcp-ack-button-alt-429-1'),
          );
          await tester.ensureVisible(ackBtn);
          await tester.tap(ackBtn);
          await tester.pumpAndSettle();
          expect(controller.state.unacknowledgedAlertCount, 0);

          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
          );

          await pumpViewport(
            tester,
            size: const Size(1280, 800),
            brightness: Brightness.dark,
            controller: controller,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
          );
        } finally {
          semanticsHandle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          controller.dispose();
        }
      },
    );
  });
}
