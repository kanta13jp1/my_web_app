import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_token_cache_monitor/ai_token_cache_monitor_container.dart';
import 'package:my_web_app/features/ai_token_cache_monitor/domain/ai_token_cache_monitor_models.dart';

class _FakeAiTokenCacheMonitorRepository
    implements AiTokenCacheMonitorRepository {
  _FakeAiTokenCacheMonitorRepository();

  TokenCacheSummarySnapshot currentSummary = _buildSnapshot(
    totalRequests: 4,
    cacheReuseRatio: 0.25,
    toolCountLabel: 'claude-search',
  );
  bool throwOnFetch = false;
  Completer<TokenCacheSummarySnapshot>? pendingSummaryCompleter;
  int fetchCalls = 0;
  int recordCalls = 0;

  @override
  Future<TokenCacheSummarySnapshot> fetchSummary({int limit = 50}) async {
    fetchCalls += 1;
    if (pendingSummaryCompleter != null) {
      return pendingSummaryCompleter!.future;
    }
    if (throwOnFetch) {
      throw StateError('network unavailable ($limit)');
    }
    return currentSummary;
  }

  @override
  Future<PrefixStabilityDiagnostic> diagnosePrefix({
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) async {
    return const LocalPrefixStabilityAnalyzer().analyze(
      systemPrompt: systemPrompt,
      toolCount: toolCount,
      useToolSearch: useToolSearch,
      breakpointCount: breakpointCount,
    );
  }

  @override
  Future<PrefixStabilityDiagnostic> recordToolUsage({
    required String toolName,
    required String modelId,
    required int inputUnits,
    required int outputUnits,
    required int cachedReadUnits,
    required String systemPrompt,
    required int toolCount,
    required bool useToolSearch,
    required int breakpointCount,
  }) async {
    recordCalls += 1;
    currentSummary = _buildSnapshot(
      totalRequests: currentSummary.totalRequests + 1,
      cacheReuseRatio: 0.72,
      toolCountLabel: '$toolName/$modelId',
    );
    return const LocalPrefixStabilityAnalyzer().analyze(
      systemPrompt: systemPrompt,
      toolCount: toolCount,
      useToolSearch: useToolSearch,
      breakpointCount: breakpointCount,
    );
  }
}

TokenCacheSummarySnapshot _buildSnapshot({
  required int totalRequests,
  required double cacheReuseRatio,
  required String toolCountLabel,
}) {
  return TokenCacheSummarySnapshot(
    totalRequests: totalRequests,
    totalInputUnits: 4000,
    totalOutputUnits: 800,
    totalUsageUnits: 4800,
    cachedReadUnits: 2800,
    cacheWriteUnits: 400,
    uncachedInputUnits: 800,
    cacheHitCount: 3,
    cacheRequestCount: 4,
    cacheReuseRatio: cacheReuseRatio,
    cacheHitRate: 0.75,
    totalNetSavingsUsd: 0.0124,
    perToolBreakdown: <ToolUsageBreakdownEntry>[
      ToolUsageBreakdownEntry(
        toolName: toolCountLabel,
        modelId: 'claude-haiku-4-5',
        specializationTier: ModelSpecializationTier.searchToolDiscovery,
        requestCount: totalRequests,
        inputUnits: 4000,
        outputUnits: 800,
        totalUnits: 4800,
        avgLatencyMs: 210,
      ),
    ],
    specializationMatrix: const <ModelSpecializationSpec>[
      ModelSpecializationSpec(
        tier: ModelSpecializationTier.searchToolDiscovery,
        labelJa: '検索・ツール探索',
        recommendedModels: <String>['claude-haiku-4-5', 'gemini-2.5-flash'],
        primaryUseCases: <String>['Tool Search Tool', 'ファイル探索'],
        cachingStrategy: 'ツールスキーマを遅延ロードし静的プレフィックスのみ保持',
        measurementScope: 'analytical_spec',
      ),
      ModelSpecializationSpec(
        tier: ModelSpecializationTier.complexReasoning,
        labelJa: '複合推論・設計監査',
        recommendedModels: <String>['claude-sonnet-4-6', 'claude-opus-4-6'],
        primaryUseCases: <String>['仕様監査', 'マルチファイル統合'],
        cachingStrategy: '1h / 5m ephemeral ブレークポイントを最大 4 箇所配置',
        measurementScope: 'analytical_spec',
      ),
    ],
  );
}

void main() {
  group('Domain models and local prefix analyzer', () {
    test('rejects invalid JSON payload and parses valid snapshot', () {
      expect(
        () => TokenCacheSummarySnapshot.fromJson(
          const <String, Object?>{'totalRequests': 'not-int'},
        ),
        throwsFormatException,
      );

      final parsed = TokenCacheSummarySnapshot.fromJson(const <String, Object?>{
        'totalRequests': 2,
        'totalInputUnits': 1000,
        'totalOutputUnits': 200,
        'totalUsageUnits': 1200,
        'cachedReadUnits': 700,
        'cacheWriteUnits': 100,
        'uncachedInputUnits': 200,
        'cacheHitCount': 1,
        'cacheRequestCount': 2,
        'cacheReuseRatio': 0.7,
        'cacheHitRate': 0.5,
        'totalNetSavingsUsd': 0.0042,
        'perToolBreakdown': <Object?>[
          <String, Object?>{
            'toolName': 'search_docs',
            'modelId': 'claude-haiku-4-5',
            'specializationTier': 'search_tool_discovery',
            'requestCount': 2,
            'inputUnits': 1000,
            'outputUnits': 200,
            'totalUnits': 1200,
            'avgLatencyMs': 180,
          },
        ],
        'specializationMatrix': <Object?>[
          <String, Object?>{
            'tier': 'bounded_execution',
            'labelJa': '限定編集',
            'recommendedModels': <String>['claude-sonnet-4-6'],
            'primaryUseCases': <String>['単発パッチ'],
            'cachingStrategy': '5m cache breakpoint',
            'measurementScope': 'analytical_spec',
          },
        ],
      });

      expect(parsed.totalRequests, 2);
      expect(parsed.cacheReuseRatio, 0.7);
      expect(
        parsed.specializationMatrix.first.tier,
        ModelSpecializationTier.boundedExecution,
      );
      expect(describeIssueNote('note-2733'), 'note-2733');
    });

    test('detects dynamic timestamp, UUID, and non-deferred tool bloat', () {
      const analyzer = LocalPrefixStabilityAnalyzer();
      final unstable = analyzer.analyze(
        systemPrompt:
            'Now: 2026-11-25T10:00:00Z session=123e4567-e89b-12d3-a456-426614174000',
        toolCount: 24,
        useToolSearch: false,
        breakpointCount: 0,
      );
      expect(unstable.stabilityScore, 5);
      expect(unstable.status, 'unstable');
      expect(unstable.warnings.length, 4);

      final optimal = analyzer.analyze(
        systemPrompt: 'Static deterministic instructions.',
        toolCount: 24,
        useToolSearch: true,
        breakpointCount: 2,
      );
      expect(optimal.stabilityScore, 100);
      expect(optimal.status, 'optimal');
      expect(optimal.warnings, isEmpty);
    });
  });

  group('AiTokenCacheMonitorContainer widget tests', () {
    testWidgets('renders initial KPI summary and model specialization matrix', (
      WidgetTester tester,
    ) async {
      final repo = _FakeAiTokenCacheMonitorRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AiTokenCacheMonitorContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI ツール消費・キャッシュ最適化'), findsOneWidget);
      expect(find.text('25.0%'), findsOneWidget);
      expect(find.textContaining('検索・ツール探索'), findsOneWidget);
      expect(find.textContaining('複合推論・設計監査'), findsOneWidget);
    });

    testWidgets(
        'previews dynamic timestamp warning and submits record updating KPI', (
      WidgetTester tester,
    ) async {
      final repo = _FakeAiTokenCacheMonitorRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: AiTokenCacheMonitorContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      final promptField =
          find.byKey(const Key('ai_token_cache_system_prompt_field'));
      await tester.ensureVisible(promptField);
      await tester.enterText(
        promptField,
        'Static system header at 2026-11-25T12:34:56Z',
      );
      await tester.pump();

      final previewBtn = find.byKey(const Key('ai_token_cache_preview_btn'));
      await tester.ensureVisible(previewBtn);
      await tester.tap(previewBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('タイムスタンプが含まれています'), findsOneWidget);

      final submitBtn = find.byKey(const Key('ai_token_cache_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(repo.recordCalls, 1);
      expect(find.text('72.0%'), findsOneWidget);
    });

    testWidgets('renders error banner on failure and retries cleanly', (
      WidgetTester tester,
    ) async {
      final repo = _FakeAiTokenCacheMonitorRepository()..throwOnFetch = true;
      await tester.pumpWidget(
        MaterialApp(
          home: AiTokenCacheMonitorContainer(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('取得に失敗しました'), findsOneWidget);

      repo.throwOnFetch = false;
      final retryBtn = find.byKey(const Key('ai_token_cache_retry_btn'));
      await tester.ensureVisible(retryBtn);
      await tester.tap(retryBtn);
      await tester.pumpAndSettle();

      expect(find.text('25.0%'), findsOneWidget);
      expect(repo.fetchCalls, 2);
    });

    testWidgets('ignores mid-flight fetch completion after dispose', (
      WidgetTester tester,
    ) async {
      final repo = _FakeAiTokenCacheMonitorRepository()
        ..pendingSummaryCompleter = Completer<TokenCacheSummarySnapshot>();

      await tester.pumpWidget(
        MaterialApp(
          home: AiTokenCacheMonitorContainer(repository: repo),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      repo.pendingSummaryCompleter!.complete(
        _buildSnapshot(
          totalRequests: 9,
          cacheReuseRatio: 0.9,
          toolCountLabel: 'late',
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('supports mobile and desktop viewports in dark 2.0x textScale',
        (WidgetTester tester) async {
      final repo = _FakeAiTokenCacheMonitorRepository();
      for (final Size viewport in const <Size>[
        Size(360, 800),
        Size(390, 844),
        Size(1280, 800),
      ]) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: const TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: ThemeData.dark(useMaterial3: true),
              home: AiTokenCacheMonitorContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        for (final Finder buttonFinder in <Finder>[
          find.byKey(const Key('ai_token_cache_refresh_btn')),
          find.byKey(const Key('ai_token_cache_preview_btn')),
          find.byKey(const Key('ai_token_cache_submit_btn')),
        ]) {
          final size = tester.getSize(buttonFinder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
  });
}
