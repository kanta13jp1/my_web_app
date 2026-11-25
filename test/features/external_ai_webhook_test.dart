import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/external_ai_webhook/domain/external_ai_webhook_models.dart';
import 'package:my_web_app/features/external_ai_webhook/external_ai_webhook_container.dart';

class _FakeExternalAiWebhookRepository implements ExternalAiWebhookRepository {
  _FakeExternalAiWebhookRepository({
    final List<ExternalAiWebhookEvent>? initialEvents,
    final List<ExternalAiWebhookKey>? initialKeys,
  })  : events = List<ExternalAiWebhookEvent>.from(
          initialEvents ?? const <ExternalAiWebhookEvent>[],
        ),
        keys = List<ExternalAiWebhookKey>.from(
          initialKeys ?? const <ExternalAiWebhookKey>[],
        );

  final List<ExternalAiWebhookEvent> events;
  final List<ExternalAiWebhookKey> keys;
  final List<String> invokedEndpoints = <String>[];
  final List<bool> dryRunCalls = <bool>[];
  final List<String> storedKeyHashes = <String>[];
  bool throwOnLoad = false;
  bool disposed = false;
  Completer<List<ExternalAiWebhookEvent>>? pendingLoad;
  void Function()? _realtimeCallback;

  @override
  Future<List<ExternalAiWebhookEvent>> fetchRecentEvents({
    final int limit = 40,
  }) async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('webhook feed unavailable');
    }
    return List<ExternalAiWebhookEvent>.unmodifiable(events.take(limit));
  }

  @override
  Future<List<ExternalAiWebhookKey>> fetchWebhookKeys() async {
    if (throwOnLoad) {
      throw StateError('webhook keys unavailable');
    }
    return List<ExternalAiWebhookKey>.unmodifiable(keys);
  }

  @override
  Future<ExternalAiWebhookKey> createWebhookKey({
    required final String label,
    required final String keyPrefix,
    required final String keyHash,
  }) async {
    storedKeyHashes.add(keyHash);
    final created = ExternalAiWebhookKey(
      id: 'key-${keys.length + 1}',
      userId: 'user-1',
      label: label,
      keyPrefix: keyPrefix,
      isActive: true,
      createdAt: DateTime.utc(2026, 11, 25, 1, 0),
    );
    keys.insert(0, created);
    return created;
  }

  @override
  Future<void> revokeWebhookKey(final String keyId) async {
    for (var i = 0; i < keys.length; i += 1) {
      if (keys[i].id == keyId) {
        keys[i] = keys[i].copyWith(isActive: false);
      }
    }
  }

  @override
  Future<ExternalWebhookInvokeResult> invokeWebhookEndpoint({
    required final ExternalWebhookSourceTool sourceTool,
    required final String eventType,
    required final Map<String, Object?> payload,
    required final bool dryRun,
  }) async {
    invokedEndpoints.add('external-ai-webhook');
    dryRunCalls.add(dryRun);
    if (dryRun) {
      return const ExternalWebhookInvokeResult(
        ok: true,
        dryRun: true,
        authMethod: ExternalWebhookAuthMethod.jwt,
      );
    }
    final added = ExternalAiWebhookEvent(
      id: 'evt-${events.length + 1}',
      userId: 'user-1',
      sourceTool: sourceTool,
      eventType: eventType,
      externalEventId: 'ext-${events.length + 1}',
      payloadSummary: '{"source":"${sourceTool.wireValue}"}',
      authMethod: ExternalWebhookAuthMethod.jwt,
      processingStatus: ExternalWebhookProcessingStatus.processed,
      errorMessage: '',
      createdAt: DateTime.utc(2026, 11, 25, 2, 0),
    );
    events.insert(0, added);
    return ExternalWebhookInvokeResult(
      ok: true,
      dryRun: false,
      authMethod: ExternalWebhookAuthMethod.jwt,
      eventId: added.id,
    );
  }

  @override
  bool subscribeToEvents(final void Function() onRealtimeChange) {
    _realtimeCallback = onRealtimeChange;
    return true;
  }

  void simulateRealtimeIncomingEvent(final ExternalAiWebhookEvent event) {
    events.insert(0, event);
    _realtimeCallback?.call();
  }

  @override
  Future<void> disposeSubscription() async {
    disposed = true;
    _realtimeCallback = null;
  }
}

List<ExternalAiWebhookEvent> _seedEvents() => <ExternalAiWebhookEvent>[
      ExternalAiWebhookEvent(
        id: 'seed-1',
        userId: 'user-1',
        sourceTool: ExternalWebhookSourceTool.n8n,
        eventType: 'youtube.metrics.synced',
        externalEventId: 'n8n-101',
        payloadSummary: '{"views":14200,"ctr":6.1}',
        authMethod: ExternalWebhookAuthMethod.apiKey,
        processingStatus: ExternalWebhookProcessingStatus.processed,
        errorMessage: '',
        createdAt: DateTime.utc(2026, 11, 25, 0, 30),
      ),
      ExternalAiWebhookEvent(
        id: 'seed-2',
        userId: 'user-1',
        sourceTool: ExternalWebhookSourceTool.zapier,
        eventType: 'video.script.completed',
        externalEventId: 'zap-202',
        payloadSummary: '{"status":"ready"}',
        authMethod: ExternalWebhookAuthMethod.jwt,
        processingStatus: ExternalWebhookProcessingStatus.received,
        errorMessage: '',
        createdAt: DateTime.utc(2026, 11, 25, 0, 20),
      ),
    ];

List<ExternalAiWebhookKey> _seedKeys() => <ExternalAiWebhookKey>[
      ExternalAiWebhookKey(
        id: 'seed-key-1',
        userId: 'user-1',
        label: 'n8n Production',
        keyPrefix: 'eaw_seed1234',
        isActive: true,
        createdAt: DateTime.utc(2026, 11, 25, 0, 10),
      ),
    ];

void main() {
  group(
    'ExternalAiWebhookContainer (#2663)',
    () {
      testWidgets(
        'subscribes to Realtime, creates hashed API keys, filters sources, and tests dry-run endpoint',
        (final WidgetTester tester) async {
          final repo = _FakeExternalAiWebhookRepository(
            initialEvents: _seedEvents(),
            initialKeys: _seedKeys(),
          );

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: ExternalAiWebhookContainer(repository: repo),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(const ValueKey<String>('webhook_realtime_badge')),
              matching: find.text('Realtime 購読中'),
              matchRoot: true,
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('webhook_event_seed-1')),
            findsOneWidget,
          );

          final labelField = find.byKey(
            const ValueKey<String>('webhook_key_label_field'),
          );
          await tester.ensureVisible(labelField);
          await tester.pumpAndSettle();
          await tester.enterText(labelField, 'Zapier Sync');
          final createBtn = find.byKey(
            const ValueKey<String>('webhook_create_key_button'),
          );
          await tester.ensureVisible(createBtn);
          await tester.pumpAndSettle();
          await tester.tap(createBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('webhook_created_key_card')),
            findsOneWidget,
          );
          expect(repo.storedKeyHashes.length, equals(1));
          expect(repo.storedKeyHashes.first.length, equals(64));

          final dryRunBtn = find.byKey(
            const ValueKey<String>('webhook_dry_run_button'),
          );
          await tester.ensureVisible(dryRunBtn);
          await tester.pumpAndSettle();
          await tester.tap(dryRunBtn);
          await tester.pumpAndSettle();
          expect(
            repo.invokedEndpoints,
            equals(const <String>['external-ai-webhook']),
          );
          expect(repo.dryRunCalls, equals(const <bool>[true]));

          repo.simulateRealtimeIncomingEvent(
            ExternalAiWebhookEvent(
              id: 'rt-live-99',
              userId: 'user-1',
              sourceTool: ExternalWebhookSourceTool.analytics,
              eventType: 'analytics.ctr.spike',
              externalEventId: 'ana-99',
              payloadSummary: '{"ctr":8.9}',
              authMethod: ExternalWebhookAuthMethod.apiKey,
              processingStatus: ExternalWebhookProcessingStatus.processed,
              errorMessage: '',
              createdAt: DateTime.utc(2026, 11, 25, 2, 10),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('webhook_event_rt-live-99')),
            findsOneWidget,
          );

          final analyticsFilter = find.byKey(
            const ValueKey<String>('webhook_filter_analytics'),
          );
          await tester.ensureVisible(analyticsFilter);
          await tester.pumpAndSettle();
          await tester.tap(analyticsFilter);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('webhook_event_rt-live-99')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey<String>('webhook_event_seed-1')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'displays error banner and recovers cleanly on retry',
        (final WidgetTester tester) async {
          final repo = _FakeExternalAiWebhookRepository(
            initialEvents: _seedEvents(),
            initialKeys: _seedKeys(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: ExternalAiWebhookContainer(repository: repo),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('webhook_error_banner')),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('webhook_retry_button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.pumpAndSettle();
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey<String>('webhook_error_banner')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey<String>('webhook_event_seed-1')),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'disposes cleanly while initial load Completer is pending',
        (final WidgetTester tester) async {
          final completer = Completer<List<ExternalAiWebhookEvent>>();
          final repo = _FakeExternalAiWebhookRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ExternalAiWebhookContainer(repository: repo),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_seedEvents());
          await tester.pumpAndSettle();

          expect(repo.disposed, isTrue);
          expect(tester.takeException(), isNull);
        },
      );

      for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
        for (final brightness in const <Brightness>[
          Brightness.light,
          Brightness.dark,
        ]) {
          testWidgets(
            'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (final WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _FakeExternalAiWebhookRepository(
                  initialEvents: _seedEvents(),
                  initialKeys: _seedKeys(),
                );
                final theme = brightness == Brightness.dark
                    ? ThemeData.dark()
                    : ThemeData.light();
                await tester.pumpWidget(
                  MaterialApp(
                    key: ValueKey<String>(
                      '${viewport.width.toInt()}_${brightness.name}',
                    ),
                    theme: theme,
                    home: Builder(
                      builder: (final BuildContext context) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: const TextScaler.linear(2.0),
                          ),
                          child: Scaffold(
                            body: ExternalAiWebhookContainer(repository: repo),
                          ),
                        );
                      },
                    ),
                  ),
                );
                await tester.pumpAndSettle();

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
              }
            },
          );
        }
      }
    },
  );
}
