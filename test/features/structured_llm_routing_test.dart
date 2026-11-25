import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/features/structured_llm_routing/domain/structured_llm_routing_models.dart';
import 'package:my_web_app/features/structured_llm_routing/structured_llm_routing_container.dart';

class _FakeStructuredLlmRoutingRepository
    implements StructuredLlmRoutingRepository {
  _FakeStructuredLlmRoutingRepository({
    this.failLoadOnce = false,
    this.loadCompleter,
  });

  bool failLoadOnce;
  Completer<List<StructuredRoutingPreferenceRecord>>? loadCompleter;

  int resolveCalls = 0;
  int validateAndSaveCalls = 0;
  String? lastTaskType;
  bool? lastRequiresReasoning;

  final List<StructuredRoutingPreferenceRecord> _records =
      <StructuredRoutingPreferenceRecord>[];
  final LocalComplexityRouter _router = const LocalComplexityRouter();

  @override
  Future<List<StructuredRoutingPreferenceRecord>> listPreferences() async {
    if (loadCompleter != null && !loadCompleter!.isCompleted) {
      return loadCompleter!.future;
    }
    if (failLoadOnce) {
      failLoadOnce = false;
      throw StateError('Simulated network timeout');
    }
    return List<StructuredRoutingPreferenceRecord>.unmodifiable(_records);
  }

  @override
  Future<LlmRoutePlan> resolveRoute({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    Map<String, Object?>? responseSchema,
  }) async {
    resolveCalls += 1;
    lastTaskType = taskType;
    lastRequiresReasoning = requiresReasoning;
    return _router.previewRoute(
      taskType: taskType,
      prompt: prompt,
      requiresReasoning: requiresReasoning,
    );
  }

  @override
  Future<StructuredRoutingPersistResult> validateAndSave({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    required String rawOutput,
    required Map<String, Object?> responseSchema,
    required String schemaName,
  }) async {
    validateAndSaveCalls += 1;
    final validation = const StructuredJsonValidator().validate(
      rawOutput,
      responseSchema,
    );
    final route = _router.previewRoute(
      taskType: taskType,
      prompt: prompt,
      requiresReasoning: requiresReasoning,
    );
    if (!validation.valid) {
      return StructuredRoutingPersistResult(
        saved: false,
        validation: validation,
        route: route,
        preference: null,
      );
    }
    final pref = StructuredRoutingPreferenceRecord(
      task: route.taskType,
      provider: route.provider,
      model: route.model,
      isEnabled: true,
      source: 'recommendation',
      updatedAt: DateTime.utc(2026, 11, 25, 10),
    );
    _records
      ..removeWhere((item) => item.task == pref.task)
      ..insert(0, pref);
    return StructuredRoutingPersistResult(
      saved: true,
      validation: validation,
      route: route,
      preference: pref,
    );
  }
}

Widget _wrapTestApp(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScaleFactor = 1.0,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: brightness,
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: child,
    ),
  );
}

void main() {
  group('Domain routing and JSON Schema validation', () {
    test('routes lightweight vs advanced tasks accurately', () {
      const router = LocalComplexityRouter();

      final light = router.previewRoute(taskType: 'classification');
      expect(light.tier, LlmRoutingTier.trivial);
      expect(light.modelClass, LlmModelClass.lightweight);
      expect(light.provider, 'google_flash_lite');
      expect(light.model, 'gemini-2.5-flash-lite');

      final advanced = router.previewRoute(
        taskType: 'analysis',
        requiresReasoning: true,
      );
      expect(advanced.tier, LlmRoutingTier.complex);
      expect(advanced.modelClass, LlmModelClass.advanced);
      expect(advanced.provider, 'anthropic');
      expect(advanced.model, 'claude-sonnet-4-6');

      final critical = router.previewRoute(taskType: 'security_audit');
      expect(critical.tier, LlmRoutingTier.critical);
      expect(critical.model, 'claude-opus-4-7');
    });

    test('LlmRoutePlan.fromJson fails closed on invalid or missing fields', () {
      expect(
        () => LlmRoutePlan.fromJson(const <String, Object?>{
          'taskType': 'classification',
          'tier': 'unknown_tier',
        }),
        throwsFormatException,
      );
      expect(
        () => StructuredRoutingPreferenceRecord.fromJson(
          const <String, Object?>{
            'task': 'classification',
            'provider': 'google_flash_lite',
            'is_enabled': 'yes',
            'source': 'recommendation',
          },
        ),
        throwsFormatException,
      );
    });

    test('StructuredJsonValidator enforces strict schema and rejects extras',
        () {
      const validator = StructuredJsonValidator();
      const schema = <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <Object?>['category', 'confidence', 'tags'],
        'properties': <String, Object?>{
          'category': <String, Object?>{
            'type': 'string',
            'enum': <Object?>['food', 'software'],
          },
          'confidence': <String, Object?>{
            'type': 'number',
            'minimum': 0,
            'maximum': 1,
          },
          'tags': <String, Object?>{
            'type': 'array',
            'minItems': 1,
            'items': <String, Object?>{'type': 'string'},
          },
        },
      };

      final ok = validator.validate(
        '```json\n{"category":"software","confidence":0.95,"tags":["llm"]}\n```',
        schema,
      );
      expect(ok.valid, isTrue);
      expect(ok.issues, isEmpty);

      final bad = validator.validate(
        '{"category":"unknown","confidence":1.5,"extra":1}',
        schema,
      );
      expect(bad.valid, isFalse);
      expect(bad.normalizedJson, isNull);
      expect(bad.issues.length, greaterThanOrEqualTo(3));
    });
  });

  group('StructuredLlmRoutingContainer widget verification', () {
    testWidgets('evaluates complex route when analysis preset is selected',
        (WidgetTester tester) async {
      final repo = _FakeStructuredLlmRoutingRepository();
      await tester.pumpWidget(
        _wrapTestApp(StructuredLlmRoutingContainer(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('google_flash_lite'), findsOneWidget);

      final analyzeChip = find.text('分析 (高性能)');
      await tester.ensureVisible(analyzeChip);
      await tester.tap(analyzeChip);
      await tester.pumpAndSettle();

      final evalButton = find.byKey(
        const ValueKey<String>('evaluate_route_button'),
      );
      await tester.ensureVisible(evalButton);
      await tester.tap(evalButton);
      await tester.pumpAndSettle();

      expect(repo.resolveCalls, 1);
      expect(repo.lastTaskType, 'analysis');
      expect(repo.lastRequiresReasoning, isTrue);
      expect(find.textContaining('claude-sonnet-4-6'), findsOneWidget);
    });

    testWidgets(
        'blocks invalid JSON locally before calling save and persists valid output',
        (WidgetTester tester) async {
      final repo = _FakeStructuredLlmRoutingRepository();
      await tester.pumpWidget(
        _wrapTestApp(StructuredLlmRoutingContainer(repository: repo)),
      );
      await tester.pumpAndSettle();

      final outputField = find.byKey(
        const ValueKey<String>('output_json_field'),
      );
      await tester.ensureVisible(outputField);
      await tester.enterText(
        outputField,
        '{"category":"invalid_cat","confidence":2,"tags":[]}',
      );
      await tester.pump();

      final saveButton = find.byKey(
        const ValueKey<String>('validate_and_save_button'),
      );
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.validateAndSaveCalls, 0);
      expect(find.textContaining('JSON Schema 不一致'), findsOneWidget);

      await tester.ensureVisible(outputField);
      await tester.enterText(
        outputField,
        '{"category":"software","confidence":0.91,"tags":["routing"]}',
      );
      await tester.pump();

      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(repo.validateAndSaveCalls, 1);
      expect(find.textContaining('JSON Schema 検証 OK'), findsOneWidget);
      expect(
        find.textContaining('classification → google_flash_lite'),
        findsOneWidget,
      );
    });

    testWidgets('shows error banner on load failure and recovers on retry',
        (WidgetTester tester) async {
      final repo = _FakeStructuredLlmRoutingRepository(failLoadOnce: true);
      await tester.pumpWidget(
        _wrapTestApp(StructuredLlmRoutingContainer(repository: repo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('確認が必要です'), findsOneWidget);
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.text('確認が必要です'), findsNothing);
    });

    testWidgets('disposing container before in-flight load finishes stays safe',
        (WidgetTester tester) async {
      final completer = Completer<List<StructuredRoutingPreferenceRecord>>();
      final repo = _FakeStructuredLlmRoutingRepository(
        loadCompleter: completer,
      );
      await tester.pumpWidget(
        _wrapTestApp(StructuredLlmRoutingContainer(repository: repo)),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      completer.complete(const <StructuredRoutingPreferenceRecord>[]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    for (final Size viewport in const <Size>[
      Size(360, 800),
      Size(390, 844),
      Size(1280, 800),
    ]) {
      testWidgets(
          'renders cleanly without overflow at ${viewport.width.toInt()}x${viewport.height.toInt()} in dark 2.0x textScale',
          (WidgetTester tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = _FakeStructuredLlmRoutingRepository();
        await tester.pumpWidget(
          _wrapTestApp(
            StructuredLlmRoutingContainer(repository: repo),
            brightness: Brightness.dark,
            textScaleFactor: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final Size evalBtnSize = tester.getSize(
          find.byKey(const ValueKey<String>('evaluate_route_button')),
        );
        expect(evalBtnSize.height, greaterThanOrEqualTo(48));
      });
    }
  });
}
