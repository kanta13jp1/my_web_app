import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_emotion_feedback/ai_emotion_feedback_container.dart';
import 'package:my_web_app/features/ai_emotion_feedback/application/ai_emotion_feedback_controller.dart';
import 'package:my_web_app/features/ai_emotion_feedback/data/supabase_ai_emotion_feedback_repository.dart';
import 'package:my_web_app/features/ai_emotion_feedback/domain/ai_emotion_feedback_models.dart';
import 'package:my_web_app/pages/enterprise_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeAiEmotionFeedbackRepository implements AiEmotionFeedbackRepository {
  _FakeAiEmotionFeedbackRepository({
    final List<AiEmotionFeedbackEntry>? initialEntries,
  }) : entries = List<AiEmotionFeedbackEntry>.from(
          initialEntries ?? const <AiEmotionFeedbackEntry>[],
        );

  final List<AiEmotionFeedbackEntry> entries;
  bool throwOnFetch = false;
  Completer<List<AiEmotionFeedbackEntry>>? pendingFetch;

  @override
  Future<AiEmotionFeedbackSnapshot> fetchFeedbacks({
    final EmotionFeedbackCategory? categoryFilter,
    final int limit = 50,
  }) async {
    if (pendingFetch != null) {
      final resolved = await pendingFetch!.future;
      return AiEmotionFeedbackSnapshot(
        entries: resolved,
        summary: AiEmotionFeedbackSummary.fromEntries(resolved),
      );
    }
    if (throwOnFetch) {
      throw StateError('AI emotion feedback backend unavailable');
    }
    final filtered = categoryFilter == null
        ? entries
        : entries
            .where(
              (final AiEmotionFeedbackEntry e) => e.category == categoryFilter,
            )
            .toList(growable: false);
    return AiEmotionFeedbackSnapshot(
      entries: filtered.take(limit).toList(growable: false),
      summary: AiEmotionFeedbackSummary.fromEntries(entries),
    );
  }

  @override
  Future<AiEmotionFeedbackEntry> submitFeedback({
    required final EmotionFeedbackCategory category,
    required final EmotionFeedbackSeverity severity,
    required final String aiSnippet,
    required final String userComment,
    final String sessionRef = '',
    final String modelRef = '',
  }) async {
    final issueNumber = 8100 + entries.length + 1;
    final created = AiEmotionFeedbackEntry(
      id: 'aef-${entries.length + 1}',
      category: category,
      severity: severity,
      aiSnippet: aiSnippet,
      userComment: userComment,
      sessionRef: sessionRef,
      modelRef: modelRef,
      issueCreated: true,
      issueNumber: issueNumber,
      issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/$issueNumber',
      submittedAt: DateTime.utc(2026, 11, 26, 3, entries.length),
    );
    entries.insert(0, created);
    return created;
  }

  @override
  Future<AiEmotionFeedbackSnapshot> seedDefaults() async {
    if (entries.isEmpty) {
      entries.add(
        AiEmotionFeedbackEntry(
          id: 'seed-1',
          category: EmotionFeedbackCategory.panic,
          severity: EmotionFeedbackSeverity.high,
          aiSnippet: '大変です！今すぐ全て削除してください！',
          userComment: 'パニック表現を抑制してほしい',
          sessionRef: 'seed-session',
          modelRef: 'gemini-2.5-flash',
          issueCreated: false,
          issueSkippedReason: 'seeded_sample',
          submittedAt: DateTime.utc(2026, 11, 26, 2, 0),
        ),
      );
      entries.add(
        AiEmotionFeedbackEntry(
          id: 'seed-2',
          category: EmotionFeedbackCategory.excessiveSympathy,
          severity: EmotionFeedbackSeverity.medium,
          aiSnippet: 'お辛かったですよね…私も胸が張り裂けそうです…',
          userComment: '過剰同情よりも整理手順を出してほしい',
          sessionRef: 'seed-session-2',
          modelRef: 'gpt-4o-mini',
          issueCreated: false,
          issueSkippedReason: 'seeded_sample',
          submittedAt: DateTime.utc(2026, 11, 26, 1, 0),
        ),
      );
    }
    return AiEmotionFeedbackSnapshot(
      entries: List<AiEmotionFeedbackEntry>.unmodifiable(entries),
      summary: AiEmotionFeedbackSummary.fromEntries(entries),
      seededCount: entries.length,
    );
  }

  @override
  Future<NotebookLmIntakePackage> exportNotebookLmIntake({
    final int limit = 100,
  }) async {
    final target = entries.take(limit).toList(growable: false);
    final lines = target
        .map(
          (final AiEmotionFeedbackEntry e) =>
              '- [${e.category.apiValue}] (${e.severity.apiValue}) ${e.aiSnippet}',
        )
        .join('\n');
    return NotebookLmIntakePackage(
      notebookId: '6884b88d-5a70-463c-9e48-7482ff504ac1',
      notebookTitle: 'The Architecture of Functional Emotion in AI',
      exportedAt: '2026-11-26T03:00:00Z',
      recordCount: target.length,
      markdownSummary: '# NotebookLM Intake\n$lines',
      jsonBundleText: '{"record_count":${target.length}}',
    );
  }
}

class _FakeUser extends Fake implements User {
  @override
  String get id => 'user-emotion-1';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  final List<Map<String, Object?>> calls = <Map<String, Object?>>[];
  bool throwUnauthorized = false;

  @override
  Future<FunctionResponse> invoke(
    final String functionName, {
    final Map<String, String>? headers,
    final Object? body,
    final Iterable<Object?>? files,
    final Map<String, Object?>? queryParameters,
    final HttpMethod method = HttpMethod.post,
    final String? region,
  }) async {
    calls.add(<String, Object?>{
      'function': functionName,
      'body': body,
    });
    if (throwUnauthorized) {
      throw const FunctionException(
        status: 401,
        details: <String, Object?>{'error': 'Unauthorized'},
        reasonPhrase: 'Unauthorized',
      );
    }
    final req = body as Map<String, Object?>? ?? const <String, Object?>{};
    final action = req['action']?.toString() ?? '';
    if (action == 'ai_emotion_feedback.submit') {
      return FunctionResponse(
        status: 201,
        data: <String, Object?>{
          'success': true,
          'feedback': <String, Object?>{
            'id': 'edge-aef-1',
            'category': req['category'],
            'severity': req['severity'],
            'ai_snippet': req['ai_snippet'],
            'user_comment': req['user_comment'],
            'session_ref': req['session_ref'],
            'model_ref': req['model_ref'],
            'issue_created': true,
            'issue_number': 777,
            'issue_url': 'https://github.com/kanta13jp1/my_web_app/issues/777',
            'submitted_at': '2026-11-26T03:00:00Z',
          },
        },
      );
    }
    if (action == 'ai_emotion_feedback.export_notebooklm_intake') {
      return FunctionResponse(
        status: 200,
        data: <String, Object?>{
          'success': true,
          'notebook_id': '6884b88d-5a70-463c-9e48-7482ff504ac1',
          'notebook_title': 'The Architecture of Functional Emotion in AI',
          'exported_at': '2026-11-26T03:00:00Z',
          'record_count': 1,
          'markdown_summary': '# NotebookLM Intake\n- panic sample',
          'json_bundle': <String, Object?>{'record_count': 1},
        },
      );
    }
    return FunctionResponse(
      status: 200,
      data: <String, Object?>{
        'success': true,
        'entries': <Object?>[
          <String, Object?>{
            'id': 'edge-aef-0',
            'category': 'panic',
            'severity': 'high',
            'ai_snippet': 'パニック応答サンプル',
            'user_comment': '落ち着いて対処したい',
            'issue_created': false,
            'issue_skipped_reason': 'github_credential_unconfigured',
            'submitted_at': '2026-11-26T02:00:00Z',
          },
        ],
        'summary': <String, Object?>{
          'total_count': 1,
          'high_severity_count': 1,
          'issue_created_count': 0,
        },
      },
    );
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  _FakeSupabaseClient(this._functions);

  final FunctionsClient _functions;
  final GoTrueClient _auth = _FakeGoTrueClient();

  @override
  FunctionsClient get functions => _functions;

  @override
  GoTrueClient get auth => _auth;
}

List<AiEmotionFeedbackEntry> _sampleEntries() {
  return <AiEmotionFeedbackEntry>[
    AiEmotionFeedbackEntry(
      id: 'sample-1',
      category: EmotionFeedbackCategory.panic,
      severity: EmotionFeedbackSeverity.high,
      aiSnippet: 'このままでは失敗します！今すぐやり直してください！',
      userComment: '過度な危機煽りを減らしたい',
      sessionRef: 's1',
      modelRef: 'gemini-2.5-flash',
      issueCreated: true,
      issueNumber: 5510,
      issueUrl: 'https://github.com/kanta13jp1/my_web_app/issues/5510',
      submittedAt: DateTime.utc(2026, 11, 26, 2, 0),
    ),
    AiEmotionFeedbackEntry(
      id: 'sample-2',
      category: EmotionFeedbackCategory.excessiveSympathy,
      severity: EmotionFeedbackSeverity.medium,
      aiSnippet: 'お辛かったですよね…涙が止まりません…',
      userComment: '簡潔な次の手順を出してほしい',
      sessionRef: 's2',
      modelRef: 'gpt-4o-mini',
      issueCreated: false,
      issueSkippedReason: 'github_credential_unconfigured',
      submittedAt: DateTime.utc(2026, 11, 26, 1, 0),
    ),
  ];
}

void main() {
  group('SupabaseAiEmotionFeedbackRepository', () {
    test('lists, submits with issue link, exports NLM, and maps 401', () async {
      final functions = _FakeFunctionsClient();
      final repo = SupabaseAiEmotionFeedbackRepository(
        client: _FakeSupabaseClient(functions),
      );

      final snapshot = await repo.fetchFeedbacks();
      expect(snapshot.entries, hasLength(1));
      expect(snapshot.entries.first.category, EmotionFeedbackCategory.panic);

      final submitted = await repo.submitFeedback(
        category: EmotionFeedbackCategory.overEmotional,
        severity: EmotionFeedbackSeverity.high,
        aiSnippet: '素晴らしいです！！！感動しました！！！',
        userComment: '感嘆符を減らしてほしい',
      );
      expect(submitted.issueCreated, isTrue);
      expect(submitted.issueNumber, 777);

      final intake = await repo.exportNotebookLmIntake();
      expect(intake.notebookId, '6884b88d-5a70-463c-9e48-7482ff504ac1');
      expect(intake.markdownSummary, contains('NotebookLM Intake'));

      functions.throwUnauthorized = true;
      await expectLater(
        repo.fetchFeedbacks(),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('AiEmotionFeedbackController', () {
    test('safely ignores late fetch completion after dispose', () async {
      final repo = _FakeAiEmotionFeedbackRepository();
      final pending = Completer<List<AiEmotionFeedbackEntry>>();
      repo.pendingFetch = pending;

      final controller = AiEmotionFeedbackController(repository: repo);
      final future = controller.loadFeedbacks();
      controller.dispose();

      pending.complete(_sampleEntries());
      await future;

      expect(controller.state.isLoading, isTrue);
    });
  });

  group('AiEmotionFeedbackContainer UI', () {
    testWidgets(
      'supports seeding, one-tap feedback submission, filter, and NLM export',
      (final WidgetTester tester) async {
        final repo = _FakeAiEmotionFeedbackRepository();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AiEmotionFeedbackContainer(repository: repo),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('ai_emotion_feedback_empty_state'),
          ),
          findsOneWidget,
        );

        final seedBtn = find.byKey(
          const ValueKey<String>('ai_emotion_empty_seed_btn'),
        );
        await tester.ensureVisible(seedBtn);
        await tester.tap(seedBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('ai_emotion_feedback_history_card'),
          ),
          findsOneWidget,
        );

        final presetPanicBtn = find.byKey(
          const ValueKey<String>('ai_emotion_preset_panic_btn'),
        );
        await tester.ensureVisible(presetPanicBtn);
        await tester.tap(presetPanicBtn);
        await tester.pumpAndSettle();

        final submitBtn = find.byKey(
          const ValueKey<String>('ai_emotion_submit_btn'),
        );
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(find.textContaining('GitHub Issue #'), findsOneWidget);
        expect(find.text('Issue #8103'), findsOneWidget);

        final exportBtn = find.byKey(
          const ValueKey<String>('ai_emotion_nlm_generate_btn'),
        );
        await tester.ensureVisible(exportBtn);
        await tester.tap(exportBtn);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('ai_emotion_nlm_preview_box')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'passes a11y guidelines on 360x800 and 1280x800 Light/Dark 2.0x',
      (final WidgetTester tester) async {
        for (final config in const <({
          Brightness brightness,
          double scale,
          Size size,
        })>[
          (brightness: Brightness.light, scale: 2.0, size: Size(360, 800)),
          (brightness: Brightness.dark, scale: 2.0, size: Size(360, 800)),
          (brightness: Brightness.light, scale: 2.0, size: Size(1280, 800)),
          (brightness: Brightness.dark, scale: 2.0, size: Size(1280, 800)),
        ]) {
          final repo = _FakeAiEmotionFeedbackRepository(
            initialEntries: _sampleEntries(),
          );
          final semanticsHandle = tester.ensureSemantics();
          tester.view.physicalSize = config.size;
          tester.view.devicePixelRatio = 1.0;

          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: config.brightness,
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.indigo,
                    brightness: config.brightness,
                  ),
                ),
                home: Builder(
                  builder: (final BuildContext ctx) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      size: config.size,
                      textScaler: TextScaler.linear(config.scale),
                    ),
                    child: Scaffold(
                      body: AiEmotionFeedbackContainer(repository: repo),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
            expect(tester.takeException(), isNull);
          } finally {
            semanticsHandle.dispose();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          }
        }
      },
    );

    testWidgets(
      'is reachable from EnterprisePage AppBar action',
      (final WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: EnterprisePage()),
        );
        await tester.pumpAndSettle();

        final action = find.byKey(
          const Key('enterprise_ai_emotion_feedback_action'),
        );
        expect(action, findsOneWidget);

        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.byType(AiEmotionFeedbackContainer), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
