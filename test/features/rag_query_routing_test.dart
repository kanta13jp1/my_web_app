import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/rag_query_routing/application/rag_query_routing_controller.dart';
import 'package:my_web_app/features/rag_query_routing/data/supabase_rag_query_routing_repository.dart';
import 'package:my_web_app/features/rag_query_routing/domain/rag_query_routing_models.dart';
import 'package:my_web_app/features/rag_query_routing/rag_query_routing_container.dart';

class _RecordedCall {
  const _RecordedCall({
    required this.query,
    required this.queryReport,
    required this.autoReport,
  });

  final String query;
  final String? queryReport;
  final bool autoReport;
}

class _FakeRagQueryRoutingRepository implements RagQueryRoutingRepository {
  final List<_RecordedCall> calls = <_RecordedCall>[];
  bool throwOnExecute = false;
  Completer<QueryRouteOutcome>? pendingCompleter;

  @override
  Future<QueryRouteOutcome> executeQueryRoute({
    required final String query,
    final String? queryReport,
    final bool autoReport = true,
    final int topK = 8,
  }) async {
    calls.add(
      _RecordedCall(
        query: query,
        queryReport: queryReport,
        autoReport: autoReport,
      ),
    );
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    if (throwOnExecute) {
      throw StateError('memory-search-hub unavailable');
    }

    final reportText = queryReport ?? '';
    if (query.trim() == 'あれを調べて' || reportText.contains('unclear')) {
      return QueryRouteOutcome.fromPayload(
        <String, Object?>{
          'success': false,
          'error': 'query_clarification_required',
          'query_route': <String, Object?>{
            'state': 'unclear',
            'action': 'clarify',
            'original_query': query,
            'search_query': query,
            'used_reformulated_query': false,
            'feedback': '検索対象（機能名や対象文書）を具体的に入力してください。',
            'report_source': reportText.isEmpty ? 'heuristic' : 'explicit',
          },
        },
        clarificationRequired: true,
        fallbackQuery: query,
      );
    }

    if (query.trim() == 'Pleias' || reportText.contains('reformulated')) {
      return QueryRouteOutcome.fromPayload(
        <String, Object?>{
          'success': true,
          'action': 'memory.query_route',
          'query_route': <String, Object?>{
            'state': 'reformulated',
            'action': 'search',
            'original_query': query,
            'search_query': 'Pleias Open Data Layers enterprise RAG',
            'used_reformulated_query': true,
            'feedback': '専門検索クエリへ自動再定式化しました。',
            'report_source': reportText.isEmpty ? 'llm' : 'explicit',
          },
          'stages': <String, Object?>{
            'bm25_candidates': 12,
            'vector_candidates': 4,
          },
          'results': <Object?>[
            <String, Object?>{
              'file_path': 'docs/rag/pleias_layers.md',
              'title': 'Pleias Open Data Layers Architecture',
              'score': 0.942,
              'match_reason': 'bm25+vector',
              'snippet': 'Query report state controls automatic search.',
            },
          ],
        },
        fallbackQuery: query,
      );
    }

    return QueryRouteOutcome.fromPayload(
      <String, Object?>{
        'success': true,
        'action': 'memory.query_route',
        'query_route': <String, Object?>{
          'state': 'trivial',
          'action': 'search',
          'original_query': query,
          'search_query': query,
          'used_reformulated_query': false,
          'feedback': 'クエリが明確なため直接検索を実行しました。',
          'report_source': reportText.isEmpty ? 'heuristic' : 'explicit',
        },
        'stages': <String, Object?>{
          'bm25_candidates': 5,
          'vector_candidates': 2,
        },
        'results': <Object?>[
          <String, Object?>{
            'file_path': 'docs/rag/citation_tokens.md',
            'title': 'Pleias Citation Tokens',
            'score': 0.88,
            'match_reason': 'bm25',
            'snippet': 'Supports <|query_report_start|> and citation spans.',
          },
        ],
      },
      fallbackQuery: query,
    );
  }
}

void main() {
  group('QueryReport domain & HTTP 422 parsing', () {
    test('parses HTTP 422 FunctionException details from Map and JSON String',
        () {
      final raw422 = <String, Object?>{
        'success': false,
        'error': 'query_clarification_required',
        'query_route': <String, Object?>{
          'state': 'unclear',
          'action': 'clarify',
          'original_query': 'あれを調べて',
          'search_query': 'あれを調べて',
          'used_reformulated_query': false,
          'feedback': '対象が不足しています。',
        },
      };

      final fromMap =
          SupabaseRagQueryRoutingRepository.parseClarificationFromErrorDetails(
        status: 422,
        details: raw422,
        fallbackQuery: 'あれを調べて',
      );
      expect(fromMap, isNotNull);
      expect(fromMap!.clarificationRequired, isTrue);
      expect(fromMap.decision.state, QueryReportState.unclear);
      expect(fromMap.decision.feedback, '対象が不足しています。');

      final fromJsonString =
          SupabaseRagQueryRoutingRepository.parseClarificationFromErrorDetails(
        status: 422,
        details: jsonEncode(raw422),
        fallbackQuery: 'あれを調べて',
      );
      expect(fromJsonString, isNotNull);
      expect(fromJsonString!.decision.requiresClarification, isTrue);

      final non422 =
          SupabaseRagQueryRoutingRepository.parseClarificationFromErrorDetails(
        status: 500,
        details: raw422,
        fallbackQuery: 'あれを調べて',
      );
      expect(non422, isNull);
    });

    test('controller rejects blank query and ignores completion after dispose',
        () async {
      final repo = _FakeRagQueryRoutingRepository();
      final controller = RagQueryRoutingController(repository: repo);

      final blankOk = await controller.submitQuery(query: '   ');
      expect(blankOk, isFalse);
      expect(controller.state.errorMessage, isNotNull);
      expect(repo.calls, isEmpty);

      final completer = Completer<QueryRouteOutcome>();
      repo.pendingCompleter = completer;
      final pendingFuture = controller.submitQuery(query: 'Pleias');
      controller.dispose();
      completer.complete(
        QueryRouteOutcome.fromPayload(
          const <String, Object?>{
            'query_route': <String, Object?>{
              'state': 'trivial',
              'action': 'search',
              'original_query': 'Pleias',
              'search_query': 'Pleias',
              'used_reformulated_query': false,
            },
          },
        ),
      );
      expect(await pendingFuture, isFalse);
    });
  });

  group('RagQueryRoutingContainer UI', () {
    testWidgets(
      'reruns search on reformulated query and surfaces original vs search banner',
      (final WidgetTester tester) async {
        final repo = _FakeRagQueryRoutingRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RagQueryRoutingContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final presetBtn = find.byKey(
          const ValueKey<String>('rag_routing_preset_reformulated'),
        );
        await tester.ensureVisible(presetBtn);
        await tester.pumpAndSettle();
        await tester.tap(presetBtn);
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(
          const ValueKey<String>('rag_routing_submit_button'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('rag_routing_reformulated_banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Pleias Open Data Layers enterprise RAG'),
          findsWidgets,
        );
        expect(
          find.byKey(const ValueKey<String>('rag_routing_results_card')),
          findsOneWidget,
        );
        expect(
          find.text('Pleias Open Data Layers Architecture'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'halts inference on unclear state, opens AlertDialog, and retries with revised query',
      (final WidgetTester tester) async {
        final repo = _FakeRagQueryRoutingRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RagQueryRoutingContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final unclearPreset = find.byKey(
          const ValueKey<String>('rag_routing_preset_unclear'),
        );
        await tester.ensureVisible(unclearPreset);
        await tester.pumpAndSettle();
        await tester.tap(unclearPreset);
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(
          const ValueKey<String>('rag_routing_submit_button'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.pumpAndSettle();
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('rag_routing_results_card')),
          findsNothing,
        );

        final clarifyInput = find.byKey(
          const ValueKey<String>('rag_routing_clarify_input'),
        );
        await tester.enterText(clarifyInput, '   ');
        await tester.tap(
          find.byKey(const ValueKey<String>('rag_routing_clarify_submit')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsOneWidget,
        );
        expect(find.text('具体的な検索クエリを入力してください。'), findsOneWidget);

        await tester.enterText(clarifyInput, 'Pleias citation tokens');
        await tester.tap(
          find.byKey(const ValueKey<String>('rag_routing_clarify_submit')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsNothing,
        );
        expect(repo.calls.length, 2);
        expect(repo.calls.last.query, 'Pleias citation tokens');
        expect(repo.calls.last.queryReport ?? '', isEmpty);
        expect(
          find.byKey(const ValueKey<String>('rag_routing_results_card')),
          findsOneWidget,
        );
        expect(find.text('Pleias Citation Tokens'), findsOneWidget);
      },
    );

    testWidgets(
      'supports dialog cancel reopen, error recovery, and safe unmount while pending',
      (final WidgetTester tester) async {
        final repo = _FakeRagQueryRoutingRepository()..throwOnExecute = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RagQueryRoutingContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final queryField = find.byKey(
          const ValueKey<String>('rag_routing_query_input'),
        );
        await tester.ensureVisible(queryField);
        await tester.enterText(queryField, 'あれを調べて');

        final submitBtn = find.byKey(
          const ValueKey<String>('rag_routing_submit_button'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_error_banner')),
          findsOneWidget,
        );

        repo.throwOnExecute = false;
        final retryBtn = find.byKey(
          const ValueKey<String>('rag_routing_retry_button'),
        );
        await tester.ensureVisible(retryBtn);
        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('rag_routing_clarify_cancel')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsNothing,
        );
        final reopenBtn = find.byKey(
          const ValueKey<String>('rag_routing_reopen_clarify_button'),
        );
        await tester.ensureVisible(reopenBtn);
        await tester.tap(reopenBtn);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('rag_routing_clarify_dialog')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('rag_routing_clarify_cancel')),
        );
        await tester.pumpAndSettle();

        final completer = Completer<QueryRouteOutcome>();
        repo.pendingCompleter = completer;
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pump();
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
        );
        completer.complete(
          QueryRouteOutcome.fromPayload(
            const <String, Object?>{
              'query_route': <String, Object?>{
                'state': 'trivial',
                'action': 'search',
                'original_query': 'あれを調べて',
                'search_query': 'あれを調べて',
                'used_reformulated_query': false,
              },
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    for (final viewport in const <Size>[Size(360, 800), Size(1280, 800)]) {
      for (final brightness in const <Brightness>[
        Brightness.light,
        Brightness.dark,
      ]) {
        testWidgets(
          'passes a11y guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} ${brightness.name} 2.0x textScale',
          (final WidgetTester tester) async {
            final semanticsHandle = tester.ensureSemantics();
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;
            try {
              final repo = _FakeRagQueryRoutingRepository();
              await tester.pumpWidget(
                MaterialApp(
                  key: ValueKey<String>(
                    'rag_routing_${viewport.width.toInt()}_${brightness.name}',
                  ),
                  theme: brightness == Brightness.dark
                      ? ThemeData.dark()
                      : ThemeData.light(),
                  home: Builder(
                    builder: (final BuildContext context) {
                      return MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.0),
                        ),
                        child: Scaffold(
                          body: RagQueryRoutingContainer(repository: repo),
                        ),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

              final presetBtn = find.byKey(
                const ValueKey<String>('rag_routing_preset_reformulated'),
              );
              await tester.ensureVisible(presetBtn);
              await tester.tap(presetBtn);
              await tester.pumpAndSettle();

              final submitBtn = find.byKey(
                const ValueKey<String>('rag_routing_submit_button'),
              );
              await tester.ensureVisible(submitBtn);
              await tester.tap(submitBtn);
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
              expect(tester.takeException(), isNull);
            } finally {
              semanticsHandle.dispose();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          },
        );
      }
    }
  });
}
