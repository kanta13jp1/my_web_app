import 'package:flutter/foundation.dart';

import '../domain/structured_llm_routing_models.dart';

class StructuredLlmRoutingController extends ChangeNotifier {
  StructuredLlmRoutingController({
    required StructuredLlmRoutingRepository repository,
    StructuredJsonValidator validator = const StructuredJsonValidator(),
    LocalComplexityRouter localRouter = const LocalComplexityRouter(),
  })  : _repository = repository,
        _validator = validator,
        _localRouter = localRouter;

  final StructuredLlmRoutingRepository _repository;
  final StructuredJsonValidator _validator;
  final LocalComplexityRouter _localRouter;

  bool _disposed = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  LlmRoutePlan? _routePlan;
  StructuredValidationOutcome? _validationOutcome;
  StructuredRoutingPersistResult? _persistResult;
  List<StructuredRoutingPreferenceRecord> _preferences =
      const <StructuredRoutingPreferenceRecord>[];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  LlmRoutePlan? get routePlan => _routePlan;
  StructuredValidationOutcome? get validationOutcome => _validationOutcome;
  StructuredRoutingPersistResult? get persistResult => _persistResult;
  List<StructuredRoutingPreferenceRecord> get preferences => _preferences;

  LlmRoutePlan previewRoute({
    required String taskType,
    String prompt = '',
    bool requiresReasoning = false,
  }) {
    final plan = _localRouter.previewRoute(
      taskType: taskType,
      prompt: prompt,
      requiresReasoning: requiresReasoning,
    );
    if (!_disposed) {
      _routePlan = plan;
      notifyListeners();
    }
    return plan;
  }

  Future<void> loadPreferences() async {
    if (_disposed || _isLoading) {
      return;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await _repository.listPreferences();
      if (_disposed) {
        return;
      }
      _preferences = loaded;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = '保存済みルーティング設定の取得に失敗しました: $error';
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> evaluateRoute({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    String? rawSchemaJson,
    String schemaName = 'structured_output',
  }) async {
    if (_disposed || _isSubmitting) {
      return;
    }
    Map<String, Object?>? parsedSchema;
    if (rawSchemaJson != null && rawSchemaJson.trim().isNotEmpty) {
      try {
        parsedSchema = StructuredOutputSchema.parseJsonText(
          schemaName: schemaName,
          rawJson: rawSchemaJson,
        ).schema;
      } on FormatException catch (error) {
        _errorMessage = 'JSON Schema 構文エラー: ${error.message}';
        notifyListeners();
        return;
      }
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final plan = await _repository.resolveRoute(
        taskType: taskType,
        prompt: prompt,
        requiresReasoning: requiresReasoning,
        responseSchema: parsedSchema,
      );
      if (_disposed) {
        return;
      }
      _routePlan = plan;
    } catch (error) {
      if (_disposed) {
        return;
      }
      _errorMessage = 'モデルルーティング判定に失敗しました: $error';
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  Future<bool> validateAndPersist({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    required String rawOutput,
    required String rawSchemaJson,
    String schemaName = 'structured_output',
  }) async {
    if (_disposed || _isSubmitting) {
      return false;
    }
    final StructuredOutputSchema schema;
    try {
      schema = StructuredOutputSchema.parseJsonText(
        schemaName: schemaName,
        rawJson: rawSchemaJson,
      );
    } on FormatException catch (error) {
      _errorMessage = 'JSON Schema 構文エラー: ${error.message}';
      _validationOutcome = null;
      notifyListeners();
      return false;
    }

    final StructuredValidationOutcome localOutcome = _validator.validate(
      rawOutput,
      schema.schema,
    );
    _validationOutcome = localOutcome;
    _persistResult = null;
    if (!localOutcome.valid) {
      _errorMessage = '構造化出力が JSON Schema に適合しないため保存をブロックしました。';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.validateAndSave(
        taskType: taskType,
        prompt: prompt,
        requiresReasoning: requiresReasoning,
        rawOutput: rawOutput,
        responseSchema: schema.schema,
        schemaName: schema.schemaName,
      );
      if (_disposed) {
        return false;
      }
      _persistResult = result;
      _validationOutcome = result.validation;
      _routePlan = result.route;
      if (!result.saved || !result.validation.valid) {
        _errorMessage = 'サーバー検証でスキーマ不一致が検出されました。';
        return false;
      }
      final StructuredRoutingPreferenceRecord? savedPref = result.preference;
      if (savedPref != null) {
        final next = _preferences
            .where((item) => item.task != savedPref.task)
            .toList(growable: true);
        next.insert(0, savedPref);
        _preferences = List<StructuredRoutingPreferenceRecord>.unmodifiable(
          next,
        );
      }
      return true;
    } catch (error) {
      if (_disposed) {
        return false;
      }
      _errorMessage = '構造化ルーティング保存に失敗しました: $error';
      return false;
    } finally {
      if (!_disposed) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
