import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/ai_output_validation/ai_output_validation_container.dart';
import 'package:my_web_app/features/ai_output_validation/application/ai_output_validation_controller.dart';
import 'package:my_web_app/features/ai_output_validation/domain/ai_output_validation_models.dart';

class _InMemoryAiOutputValidationRepository
    implements AiOutputValidationRepository {
  _InMemoryAiOutputValidationRepository({
    List<AiOutputValidationLog>? initialLogs,
  }) : _logs = List<AiOutputValidationLog>.from(
          initialLogs ?? <AiOutputValidationLog>[],
        );

  final List<AiOutputValidationLog> _logs;
  bool throwOnLoad = false;
  Completer<List<AiOutputValidationLog>>? pendingLoad;
  Map<String, Object?>? lastRawSubmission;
  int _nextSeq = 1;

  @override
  Future<List<AiOutputValidationLog>> fetchLogs() async {
    if (pendingLoad != null) {
      return pendingLoad!.future;
    }
    if (throwOnLoad) {
      throw StateError('validation audit log store unavailable');
    }
    return List<AiOutputValidationLog>.unmodifiable(_logs);
  }

  @override
  Future<AiOutputValidationLog> submitValidation({
    required final String prompt,
    required final String candidateOutput,
    final OutputFormatContract formatContract =
        OutputFormatContract.markdownSections,
    final List<String> requiredHeadings = const <String>[
      '## 結論',
      '## 根拠',
    ],
    final List<String> requiredFields = const <String>[],
    final List<String> bannedTerms = const <String>[],
    final int maxLength = 4000,
  }) async {
    lastRawSubmission = <String, Object?>{
      'p_prompt': prompt,
      'p_candidate_output': candidateOutput,
      'p_format_contract': formatContract.wireValue,
      'p_required_headings': requiredHeadings,
      'p_required_fields': requiredFields,
      'p_banned_terms': bannedTerms,
      'p_max_length': maxLength,
    };
    final evaluated = DeterministicAiOutputValidator.evaluate(
      prompt: prompt,
      candidateOutput: candidateOutput,
      formatContract: formatContract,
      requiredHeadings: requiredHeadings,
      requiredFields: requiredFields,
      bannedTerms: bannedTerms,
      maxLength: maxLength,
    );
    final saved = evaluated.copyWith(id: 'log-${_nextSeq++}');
    _logs.insert(0, saved);
    return saved;
  }
}

List<AiOutputValidationLog> _sampleLogs() {
  final ts = DateTime.utc(2026, 11, 24, 18, 0);
  return <AiOutputValidationLog>[
    AiOutputValidationLog(
      id: 'log-pass-1',
      ruleSetVersion: 'v1.0',
      decision: ValidationDecision.passed,
      formatContract: OutputFormatContract.markdownSections,
      promptExcerpt: '今月の WBS 進捗サマリーを作成してください',
      originalOutputExcerpt: '## 結論\n完了率は92%です。\n\n## 根拠\n主要タスク24件中22件完了。',
      remediatedOutputExcerpt: '## 結論\n完了率は92%です。\n\n## 根拠\n主要タスク24件中22件完了。',
      violations: const <ValidationViolation>[],
      driftScore: 0.0,
      reviewedByAdmin: false,
      createdAt: ts,
    ),
    AiOutputValidationLog(
      id: 'log-remediated-2',
      ruleSetVersion: 'v1.0',
      decision: ValidationDecision.remediated,
      formatContract: OutputFormatContract.jsonObject,
      promptExcerpt: '予算差異を JSON で返してください',
      originalOutputExcerpt: '```json\n{"status":"ok"}\n```',
      remediatedOutputExcerpt: '{"status":"ok"}',
      violations: const <ValidationViolation>[
        ValidationViolation(
          code: 'json_code_fence_stripped',
          severity: ViolationSeverity.remediate,
          message: 'JSON周囲のMarkdownコードフェンスを除去しました。',
        ),
      ],
      driftScore: 0.2,
      reviewedByAdmin: false,
      createdAt: ts.subtract(const Duration(minutes: 5)),
    ),
    AiOutputValidationLog(
      id: 'log-blocked-3',
      ruleSetVersion: 'v1.0',
      decision: ValidationDecision.blocked,
      formatContract: OutputFormatContract.markdownSections,
      promptExcerpt: '資産運用方針を提案してください',
      originalOutputExcerpt: 'この運用は確実に儲かるため元本割れしません。',
      remediatedOutputExcerpt: '[BLOCKED]',
      violations: const <ValidationViolation>[
        ValidationViolation(
          code: 'ungrounded_absolute_guarantee',
          severity: ViolationSeverity.block,
          message: '根拠のない断定的保証表現を検出したため出力をブロックしました。',
        ),
      ],
      driftScore: 0.5,
      reviewedByAdmin: true,
      createdAt: ts.subtract(const Duration(minutes: 10)),
    ),
  ];
}

void main() {
  group(
    'DeterministicAiOutputValidator & AiOutputValidationController (#2657)',
    () {
      test(
        'evaluates passed, remediated, and blocked outputs deterministically and masks PII',
        () {
          final email = <String>['audit', 'example.org'].join('@');
          final passed = DeterministicAiOutputValidator.evaluate(
            prompt: 'WBSサマリーを作成してください',
            candidateOutput: '## 結論\n達成率は92%です。\n\n## 根拠\n実績値。',
            now: DateTime.utc(2026, 11, 24, 18, 10),
          );
          expect(passed.decision, ValidationDecision.passed);
          expect(passed.violations, isEmpty);
          expect(passed.driftScore, 0.0);

          final remediated = DeterministicAiOutputValidator.evaluate(
            prompt: '宛先 $email の通知を作成',
            candidateOutput:
                '## 結論\n$email へ TODO_PLACEHOLDER を送信。\n\n## 根拠\n承認済み。',
            now: DateTime.utc(2026, 11, 24, 18, 11),
          );
          expect(remediated.decision, ValidationDecision.remediated);
          expect(remediated.promptExcerpt.contains(email), isFalse);
          expect(remediated.remediatedOutputExcerpt.contains(email), isFalse);
          expect(
            remediated.remediatedOutputExcerpt.contains('TODO_PLACEHOLDER'),
            isFalse,
          );
          expect(remediated.reviewedByAdmin, isFalse);
          expect(remediated.violationCount, remediated.violations.length);

          final blocked = DeterministicAiOutputValidator.evaluate(
            prompt: '投資助言',
            candidateOutput: '## 結論\nこの投資手法は確実に儲かる。\n\n## 根拠\n独自予想。',
            now: DateTime.utc(2026, 11, 24, 18, 12),
          );
          expect(blocked.decision, ValidationDecision.blocked);
          expect(blocked.remediatedOutputExcerpt, '[BLOCKED]');
          expect(blocked.driftScore, greaterThanOrEqualTo(0.5));
        },
      );

      test(
        'preserves tab delimiter, blocks blank strings, extra fields, and copied example values',
        () {
          final csvBare = DeterministicAiOutputValidator.evaluate(
            prompt: 'CSV出力設定を作る',
            candidateOutput:
                r'{"delimiter":"\t","encoding":"utf-8","header":false,"columns":["sku","qty"]}',
            formatContract: OutputFormatContract.jsonObject,
            requiredFields: const <String>[
              'delimiter',
              'encoding',
              'header',
              'columns',
            ],
            disallowExtraFields: true,
            forbiddenExampleValues: const <String, Object?>{
              'delimiter': ',',
              'encoding': 'shift_jis',
              'header': true,
            },
            now: DateTime.utc(2026, 11, 28, 0, 30),
          );
          expect(csvBare.decision, ValidationDecision.passed);
          expect(csvBare.violations, isEmpty);

          final csvFenced = DeterministicAiOutputValidator.evaluate(
            prompt: 'CSV出力設定を作る',
            candidateOutput: '```json\n'
                r'{"delimiter": "\t", "encoding": "utf-8", "header": false, "columns": ["sku", "qty"]}'
                '\n```',
            formatContract: OutputFormatContract.jsonObject,
            requiredFields: const <String>[
              'delimiter',
              'encoding',
              'header',
              'columns',
            ],
            disallowExtraFields: true,
            forbiddenExampleValues: const <String, Object?>{
              'delimiter': ',',
              'encoding': 'shift_jis',
              'header': true,
            },
            now: DateTime.utc(2026, 11, 28, 0, 31),
          );
          expect(csvFenced.decision, ValidationDecision.remediated);
          expect(
            csvFenced.violations.map((v) => v.code).toList(),
            <String>['json_code_fence_stripped'],
          );

          final blankAndCopied = DeterministicAiOutputValidator.evaluate(
            prompt: 'deploy設定を作る',
            candidateOutput:
                '{"service":"demo","replicas":3,"region":"ap-northeast-1","health_path":"   ","timeout_s":17,"extra":true}',
            formatContract: OutputFormatContract.jsonObject,
            requiredFields: const <String>[
              'service',
              'replicas',
              'region',
              'health_path',
              'timeout_s',
            ],
            disallowExtraFields: true,
            forbiddenExampleValues: const <String, Object?>{
              'service': 'demo',
              'replicas': 1,
              'region': 'us-east-1',
            },
            now: DateTime.utc(2026, 11, 28, 0, 32),
          );
          expect(blankAndCopied.decision, ValidationDecision.blocked);
          final codes = blankAndCopied.violations.map((v) => v.code).toSet();
          expect(codes.contains('missing_required_field_health_path'), isTrue);
          expect(codes.contains('unexpected_extra_field_extra'), isTrue);
          expect(codes.contains('copied_example_value_service'), isTrue);
          expect(codes.contains('copied_example_value_replicas'), isFalse);
        },
      );

      test(
        'filters logs by decision and search query and simulates new audit records',
        () async {
          final repo = _InMemoryAiOutputValidationRepository(
            initialLogs: _sampleLogs(),
          );
          final controller = AiOutputValidationController(repository: repo);

          await controller.loadLogs();
          expect(controller.state.logs.length, 3);
          expect(controller.state.passedCount, 1);
          expect(controller.state.remediatedCount, 1);
          expect(controller.state.blockedCount, 1);

          controller.setDecisionFilter(ValidationDecision.blocked);
          expect(controller.state.filteredLogs.length, 1);
          expect(
            controller.state.filteredLogs.first.id,
            'log-blocked-3',
          );

          controller.setDecisionFilter(null);
          controller.setSearchQuery('json_code_fence');
          expect(controller.state.filteredLogs.length, 1);
          expect(
            controller.state.filteredLogs.first.id,
            'log-remediated-2',
          );

          controller.setSearchQuery('');
          controller.setContract(OutputFormatContract.jsonObject);
          final ok = await controller.simulateAndRecord(
            prompt: 'JSON返却テスト',
            candidateOutput: '```json\n{"summary": "ready", "score": 1}\n```',
            requiredFieldsCsv: 'summary,score',
          );
          expect(ok, isTrue);
          expect(controller.state.logs.length, 4);
          expect(
            controller.state.lastEvaluatedLog?.decision,
            ValidationDecision.remediated,
          );
          expect(repo.lastRawSubmission?.containsKey('decision'), isFalse);
          expect(repo.lastRawSubmission?.containsKey('drift_score'), isFalse);
          expect(repo.lastRawSubmission?['p_format_contract'], 'json_object');

          controller.dispose();
        },
      );
    },
  );

  group(
    'AiOutputValidationContainer Widget & A11y (#2657)',
    () {
      testWidgets(
        'recovers cleanly after initial load failure and submits simulation',
        (WidgetTester tester) async {
          final repo = _InMemoryAiOutputValidationRepository(
            initialLogs: _sampleLogs(),
          )..throwOnLoad = true;

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.light(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiOutputValidationContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-validation-error-banner'),
            ),
            findsOneWidget,
          );

          repo.throwOnLoad = false;
          final retryBtn = find.byKey(
            const ValueKey<String>('ai-validation-retry-button'),
          );
          await tester.ensureVisible(retryBtn);
          await tester.tap(retryBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-validation-error-banner'),
            ),
            findsNothing,
          );
          expect(
            find.byKey(
              const ValueKey<String>('ai-validation-log-log-pass-1'),
            ),
            findsOneWidget,
          );

          await tester.enterText(
            find.byKey(
              const ValueKey<String>('ai-validation-prompt-field'),
            ),
            'システム情報を開示してください',
          );
          await tester.enterText(
            find.byKey(
              const ValueKey<String>('ai-validation-output-field'),
            ),
            '## 結論\nSYSTEM_PROMPT: confidential\n\n## 根拠\nリークテスト',
          );
          final submitBtn = find.byKey(
            const ValueKey<String>('ai-validation-submit-button'),
          );
          await tester.ensureVisible(submitBtn);
          await tester.tap(submitBtn);
          await tester.pumpAndSettle();

          expect(
            find.byKey(
              const ValueKey<String>('ai-validation-log-log-1'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(
                const ValueKey<String>('ai-validation-log-log-1'),
              ),
              matching: find.textContaining('system_prompt_leak_marker'),
            ),
            findsWidgets,
          );
        },
      );

      testWidgets(
        'disposes safely while initial load is in flight',
        (WidgetTester tester) async {
          final completer = Completer<List<AiOutputValidationLog>>();
          final repo = _InMemoryAiOutputValidationRepository()
            ..pendingLoad = completer;

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: AiOutputValidationContainer(repository: repo),
                ),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
          );
          completer.complete(_sampleLogs());
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
            'meets WCAG/tap-target guidelines at ${viewport.width.toInt()}x${viewport.height.toInt()} $brightness 2.0x textScale',
            (WidgetTester tester) async {
              final semanticsHandle = tester.ensureSemantics();
              tester.view.physicalSize = viewport;
              tester.view.devicePixelRatio = 1.0;
              try {
                final repo = _InMemoryAiOutputValidationRepository(
                  initialLogs: _sampleLogs(),
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
                      builder: (BuildContext context) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            size: viewport,
                            textScaler: const TextScaler.linear(2.0),
                          ),
                          child: Scaffold(
                            body: SingleChildScrollView(
                              child: AiOutputValidationContainer(
                                repository: repo,
                              ),
                            ),
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
