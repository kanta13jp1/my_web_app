import 'dart:convert';

import 'package:flutter/foundation.dart';

enum LlmRoutingTier {
  trivial('trivial', 'low', 'lightweight'),
  standard('standard', 'medium', 'balanced'),
  complex('complex', 'high', 'advanced'),
  critical('critical', 'xhigh', 'advanced');

  const LlmRoutingTier(this.wireValue, this.effort, this.modelClass);

  final String wireValue;
  final String effort;
  final String modelClass;

  static LlmRoutingTier fromValue(Object? raw) {
    if (raw is! String) {
      throw FormatException(
        'Expected String for tier, got ${raw.runtimeType}.',
      );
    }
    for (final tier in LlmRoutingTier.values) {
      if (tier.wireValue == raw) {
        return tier;
      }
    }
    throw FormatException('Unknown LlmRoutingTier: "$raw".');
  }
}

enum LlmModelClass {
  lightweight('lightweight'),
  balanced('balanced'),
  advanced('advanced');

  const LlmModelClass(this.wireValue);

  final String wireValue;

  static LlmModelClass fromValue(Object? raw) {
    if (raw is! String) {
      throw FormatException(
        'Expected String for modelClass, got ${raw.runtimeType}.',
      );
    }
    for (final value in LlmModelClass.values) {
      if (value.wireValue == raw) {
        return value;
      }
    }
    throw FormatException('Unknown LlmModelClass: "$raw".');
  }
}

String _requireNonEmptyString(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('Missing or invalid non-empty String "$key".');
  }
  return raw;
}

String _requireString(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! String) {
    throw FormatException('Missing or invalid String "$key".');
  }
  return raw;
}

bool _requireBool(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! bool) {
    throw FormatException('Missing or invalid bool "$key".');
  }
  return raw;
}

int _requireInt(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! int) {
    throw FormatException('Missing or invalid int "$key".');
  }
  return raw;
}

List<String> _requireStringList(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! List<Object?>) {
    throw FormatException('Missing or invalid List "$key".');
  }
  final result = <String>[];
  for (final item in raw) {
    if (item is! String) {
      throw FormatException('List "$key" contains non-String element.');
    }
    result.add(item);
  }
  return List<String>.unmodifiable(result);
}

Map<String, Object?> _requireMap(Map<String, Object?> json, String key) {
  return normalizeJsonObject(json[key], 'property "$key"');
}

Map<String, Object?> normalizeJsonObject(Object? raw, String context) {
  if (raw is! Map<Object?, Object?>) {
    throw FormatException('Expected JSON object for $context.');
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final Object? entryKey = entry.key;
    if (entryKey is! String) {
      throw FormatException('Expected String keys in $context.');
    }
    normalized[entryKey] = entry.value;
  }
  return normalized;
}

Map<String, Object?> _asStringMap(Object? raw, String context) =>
    normalizeJsonObject(raw, context);

@immutable
class StructuredOutputSchema {
  const StructuredOutputSchema({
    required this.schemaName,
    required this.schema,
  });

  final String schemaName;
  final Map<String, Object?> schema;

  String toFormattedJson() =>
      const JsonEncoder.withIndent('  ').convert(schema);

  static StructuredOutputSchema parseJsonText({
    required String schemaName,
    required String rawJson,
  }) {
    final String trimmedName = schemaName.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Schema name must not be empty.');
    }
    final Object? decoded = jsonDecode(rawJson);
    final Map<String, Object?> schemaMap = _asStringMap(
      decoded,
      'response_schema',
    );
    final Object? typeValue = schemaMap['type'];
    if (typeValue is! String || typeValue.isEmpty) {
      throw const FormatException(
        'response_schema must specify a root "type" string.',
      );
    }
    return StructuredOutputSchema(
      schemaName: trimmedName,
      schema: Map<String, Object?>.unmodifiable(schemaMap),
    );
  }
}

@immutable
class StructuredValidationIssue {
  const StructuredValidationIssue({
    required this.path,
    required this.message,
  });

  final String path;
  final String message;

  factory StructuredValidationIssue.fromJson(Map<String, Object?> json) {
    return StructuredValidationIssue(
      path: _requireString(json, 'path'),
      message: _requireNonEmptyString(json, 'message'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'path': path,
        'message': message,
      };
}

@immutable
class StructuredValidationOutcome {
  const StructuredValidationOutcome({
    required this.valid,
    required this.issues,
    required this.normalizedJson,
  });

  final bool valid;
  final List<StructuredValidationIssue> issues;
  final String? normalizedJson;

  factory StructuredValidationOutcome.fromJson(Map<String, Object?> json) {
    final Object? rawIssues = json['issues'];
    if (rawIssues is! List<Object?>) {
      throw const FormatException('Missing or invalid List "issues".');
    }
    final parsedIssues = <StructuredValidationIssue>[];
    for (final item in rawIssues) {
      parsedIssues.add(
        StructuredValidationIssue.fromJson(
          _asStringMap(item, 'validation.issues[]'),
        ),
      );
    }
    final Object? rawNormalized = json['normalizedJson'];
    if (rawNormalized != null && rawNormalized is! String) {
      throw const FormatException('Invalid String? "normalizedJson".');
    }
    return StructuredValidationOutcome(
      valid: _requireBool(json, 'valid'),
      issues: List<StructuredValidationIssue>.unmodifiable(parsedIssues),
      normalizedJson: rawNormalized as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'valid': valid,
        'issues': issues.map((issue) => issue.toJson()).toList(growable: false),
        'normalizedJson': normalizedJson,
      };
}

@immutable
class LlmRoutePlan {
  const LlmRoutePlan({
    required this.taskType,
    required this.tier,
    required this.effort,
    required this.modelClass,
    required this.provider,
    required this.model,
    required this.fallbackChain,
    required this.recommendedOutputLimit,
    required this.reason,
    required this.preferenceApplied,
    required this.recommendedTier,
    required this.recommendedProvider,
    required this.recommendedModel,
  });

  final String taskType;
  final LlmRoutingTier tier;
  final String effort;
  final LlmModelClass modelClass;
  final String provider;
  final String model;
  final List<String> fallbackChain;
  final int recommendedOutputLimit;
  final String reason;
  final bool preferenceApplied;
  final LlmRoutingTier recommendedTier;
  final String recommendedProvider;
  final String recommendedModel;

  factory LlmRoutePlan.fromJson(Map<String, Object?> json) {
    return LlmRoutePlan(
      taskType: _requireNonEmptyString(json, 'taskType'),
      tier: LlmRoutingTier.fromValue(json['tier']),
      effort: _requireNonEmptyString(json, 'effort'),
      modelClass: LlmModelClass.fromValue(json['modelClass']),
      provider: _requireNonEmptyString(json, 'provider'),
      model: _requireNonEmptyString(json, 'model'),
      fallbackChain: _requireStringList(json, 'fallbackChain'),
      recommendedOutputLimit: _requireInt(json, 'recommendedOutputLimit'),
      reason: _requireNonEmptyString(json, 'reason'),
      preferenceApplied: _requireBool(json, 'preferenceApplied'),
      recommendedTier: LlmRoutingTier.fromValue(json['recommendedTier']),
      recommendedProvider: _requireNonEmptyString(json, 'recommendedProvider'),
      recommendedModel: _requireNonEmptyString(json, 'recommendedModel'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'taskType': taskType,
        'tier': tier.wireValue,
        'effort': effort,
        'modelClass': modelClass.wireValue,
        'provider': provider,
        'model': model,
        'fallbackChain': fallbackChain,
        'recommendedOutputLimit': recommendedOutputLimit,
        'reason': reason,
        'preferenceApplied': preferenceApplied,
        'recommendedTier': recommendedTier.wireValue,
        'recommendedProvider': recommendedProvider,
        'recommendedModel': recommendedModel,
      };
}

@immutable
class StructuredRoutingPreferenceRecord {
  const StructuredRoutingPreferenceRecord({
    required this.task,
    required this.provider,
    required this.model,
    required this.isEnabled,
    required this.source,
    required this.updatedAt,
  });

  final String task;
  final String provider;
  final String? model;
  final bool isEnabled;
  final String source;
  final DateTime? updatedAt;

  factory StructuredRoutingPreferenceRecord.fromJson(
    Map<String, Object?> json,
  ) {
    final Object? rawModel = json['model'];
    if (rawModel != null && rawModel is! String) {
      throw const FormatException('Invalid String? "model".');
    }
    final Object? rawUpdatedAt = json['updated_at'];
    if (rawUpdatedAt != null && rawUpdatedAt is! String) {
      throw const FormatException('Invalid String? "updated_at".');
    }
    return StructuredRoutingPreferenceRecord(
      task: _requireNonEmptyString(json, 'task'),
      provider: _requireNonEmptyString(json, 'provider'),
      model: rawModel as String?,
      isEnabled: _requireBool(json, 'is_enabled'),
      source: _requireNonEmptyString(json, 'source'),
      updatedAt:
          rawUpdatedAt is String ? DateTime.tryParse(rawUpdatedAt) : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'task': task,
        'provider': provider,
        'model': model,
        'is_enabled': isEnabled,
        'source': source,
        'updated_at': updatedAt?.toIso8601String(),
      };
}

@immutable
class StructuredRoutingPersistResult {
  const StructuredRoutingPersistResult({
    required this.saved,
    required this.validation,
    required this.route,
    required this.preference,
  });

  final bool saved;
  final StructuredValidationOutcome validation;
  final LlmRoutePlan route;
  final StructuredRoutingPreferenceRecord? preference;

  factory StructuredRoutingPersistResult.fromJson(Map<String, Object?> json) {
    final Object? rawPref = json['preference'];
    StructuredRoutingPreferenceRecord? pref;
    if (rawPref != null) {
      pref = StructuredRoutingPreferenceRecord.fromJson(
        _asStringMap(rawPref, 'preference'),
      );
    }
    return StructuredRoutingPersistResult(
      saved: _requireBool(json, 'saved'),
      validation: StructuredValidationOutcome.fromJson(
        _requireMap(json, 'validation'),
      ),
      route: LlmRoutePlan.fromJson(_requireMap(json, 'route')),
      preference: pref,
    );
  }
}

class StructuredJsonValidator {
  const StructuredJsonValidator();

  static String stripCodeFences(String raw) {
    final String trimmed = raw.trim();
    if (!trimmed.startsWith('```')) {
      return trimmed;
    }
    final int firstNewline = trimmed.indexOf('\n');
    if (firstNewline == -1) {
      return trimmed;
    }
    final String body = trimmed.substring(firstNewline + 1);
    final int closingIndex = body.lastIndexOf('```');
    if (closingIndex == -1) {
      return body.trim();
    }
    return body.substring(0, closingIndex).trim();
  }

  StructuredValidationOutcome validate(
    String rawOutput,
    Map<String, Object?> schema,
  ) {
    final String cleaned = stripCodeFences(rawOutput);
    if (cleaned.isEmpty) {
      return const StructuredValidationOutcome(
        valid: false,
        issues: <StructuredValidationIssue>[
          StructuredValidationIssue(
            path: r'$',
            message: 'Structured JSON output must not be empty.',
          ),
        ],
        normalizedJson: null,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(cleaned);
    } on FormatException catch (error) {
      return StructuredValidationOutcome(
        valid: false,
        issues: <StructuredValidationIssue>[
          StructuredValidationIssue(
            path: r'$',
            message: 'Invalid JSON syntax: ${error.message}',
          ),
        ],
        normalizedJson: null,
      );
    }

    final issues = <StructuredValidationIssue>[];
    _validateNode(decoded, schema, r'$', issues, 0);
    if (issues.isNotEmpty) {
      return StructuredValidationOutcome(
        valid: false,
        issues: List<StructuredValidationIssue>.unmodifiable(issues),
        normalizedJson: null,
      );
    }
    return StructuredValidationOutcome(
      valid: true,
      issues: const <StructuredValidationIssue>[],
      normalizedJson: jsonEncode(decoded),
    );
  }

  void _validateNode(
    Object? value,
    Map<String, Object?> schema,
    String path,
    List<StructuredValidationIssue> issues,
    int depth,
  ) {
    if (depth > 16) {
      issues.add(
        StructuredValidationIssue(
          path: path,
          message: 'Maximum JSON schema validation depth exceeded.',
        ),
      );
      return;
    }

    final Object? rawEnum = schema['enum'];
    if (rawEnum is List<Object?>) {
      final bool matched = rawEnum.any(
        (entry) => jsonEncode(entry) == jsonEncode(value),
      );
      if (!matched) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'Value must be one of ${jsonEncode(rawEnum)}.',
          ),
        );
        return;
      }
    }

    final Object? rawType = schema['type'];
    if (rawType is String && !_matchesType(value, rawType)) {
      issues.add(
        StructuredValidationIssue(
          path: path,
          message: 'Expected type "$rawType".',
        ),
      );
      return;
    }

    if (value is String) {
      final Object? minLen = schema['minLength'];
      final Object? maxLen = schema['maxLength'];
      if (minLen is num && value.length < minLen.toInt()) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'String length must be >= ${minLen.toInt()}.',
          ),
        );
      }
      if (maxLen is num && value.length > maxLen.toInt()) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'String length must be <= ${maxLen.toInt()}.',
          ),
        );
      }
      return;
    }

    if (value is num) {
      final Object? minVal = schema['minimum'];
      final Object? maxVal = schema['maximum'];
      if (minVal is num && value < minVal) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'Number must be >= $minVal.',
          ),
        );
      }
      if (maxVal is num && value > maxVal) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'Number must be <= $maxVal.',
          ),
        );
      }
      return;
    }

    if (value is List<Object?>) {
      final Object? minItems = schema['minItems'];
      final Object? maxItems = schema['maxItems'];
      if (minItems is num && value.length < minItems.toInt()) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'Array must contain at least ${minItems.toInt()} item(s).',
          ),
        );
      }
      if (maxItems is num && value.length > maxItems.toInt()) {
        issues.add(
          StructuredValidationIssue(
            path: path,
            message: 'Array must contain at most ${maxItems.toInt()} item(s).',
          ),
        );
      }
      final Object? itemSchemaRaw = schema['items'];
      if (itemSchemaRaw is Map<Object?, Object?>) {
        final itemSchema = _asStringMap(itemSchemaRaw, '$path.items');
        for (int i = 0; i < value.length; i += 1) {
          _validateNode(value[i], itemSchema, '$path[$i]', issues, depth + 1);
        }
      }
      return;
    }

    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> obj = _asStringMap(value, path);
      final Object? propsRaw = schema['properties'];
      final Map<String, Object?> props = propsRaw is Map<Object?, Object?>
          ? _asStringMap(propsRaw, '$path.properties')
          : const <String, Object?>{};

      final Object? requiredRaw = schema['required'];
      if (requiredRaw is List<Object?>) {
        for (final reqKey in requiredRaw) {
          if (reqKey is String && !obj.containsKey(reqKey)) {
            issues.add(
              StructuredValidationIssue(
                path: '$path.$reqKey',
                message: 'Missing required property "$reqKey".',
              ),
            );
          }
        }
      }

      if (schema['additionalProperties'] == false) {
        for (final key in obj.keys) {
          if (!props.containsKey(key)) {
            issues.add(
              StructuredValidationIssue(
                path: '$path.$key',
                message: 'Unexpected property "$key" is not allowed.',
              ),
            );
          }
        }
      }

      for (final entry in props.entries) {
        if (!obj.containsKey(entry.key)) {
          continue;
        }
        if (entry.value is Map<Object?, Object?>) {
          _validateNode(
            obj[entry.key],
            _asStringMap(entry.value, '$path.${entry.key}.schema'),
            '$path.${entry.key}',
            issues,
            depth + 1,
          );
        }
      }
    }
  }

  bool _matchesType(Object? value, String expectedType) {
    switch (expectedType) {
      case 'object':
        return value is Map<Object?, Object?>;
      case 'array':
        return value is List<Object?>;
      case 'string':
        return value is String;
      case 'number':
        return value is num;
      case 'integer':
        return value is int;
      case 'boolean':
        return value is bool;
      case 'null':
        return value == null;
      default:
        return true;
    }
  }
}

@immutable
class LlmRoutingTierSpec {
  const LlmRoutingTierSpec({
    required this.tier,
    required this.modelClass,
    required this.provider,
    required this.model,
    required this.fallbackChain,
    required this.outputLimit,
  });

  final LlmRoutingTier tier;
  final LlmModelClass modelClass;
  final String provider;
  final String model;
  final List<String> fallbackChain;
  final int outputLimit;
}

const Map<LlmRoutingTier, LlmRoutingTierSpec> kDefaultRoutingTierSpecs =
    <LlmRoutingTier, LlmRoutingTierSpec>{
  LlmRoutingTier.trivial: LlmRoutingTierSpec(
    tier: LlmRoutingTier.trivial,
    modelClass: LlmModelClass.lightweight,
    provider: 'google_flash_lite',
    model: 'gemini-2.5-flash-lite',
    fallbackChain: <String>['google', 'groq', 'anthropic'],
    outputLimit: 1024,
  ),
  LlmRoutingTier.standard: LlmRoutingTierSpec(
    tier: LlmRoutingTier.standard,
    modelClass: LlmModelClass.balanced,
    provider: 'openai',
    model: 'gpt-5.4-mini',
    fallbackChain: <String>['google', 'anthropic', 'groq'],
    outputLimit: 2048,
  ),
  LlmRoutingTier.complex: LlmRoutingTierSpec(
    tier: LlmRoutingTier.complex,
    modelClass: LlmModelClass.advanced,
    provider: 'anthropic',
    model: 'claude-sonnet-4-6',
    fallbackChain: <String>['google', 'openai'],
    outputLimit: 4096,
  ),
  LlmRoutingTier.critical: LlmRoutingTierSpec(
    tier: LlmRoutingTier.critical,
    modelClass: LlmModelClass.advanced,
    provider: 'anthropic',
    model: 'claude-opus-4-7',
    fallbackChain: <String>['openai', 'google'],
    outputLimit: 8192,
  ),
};

class LocalComplexityRouter {
  const LocalComplexityRouter();

  static const Set<String> _trivialTasks = <String>{
    'classification',
    'tagging',
    'formatting',
    'extraction',
    'routing',
    'triage',
    'labeling',
    'sentiment',
  };

  static const Set<String> _complexTasks = <String>{
    'analysis',
    'code_review',
    'coding',
    'reasoning',
    'planning',
    'multi_step_synthesis',
    'refactor',
  };

  static const Set<String> _criticalTasks = <String>{
    'security_audit',
    'architecture',
    'incident_root_cause',
    'compliance_review',
    'financial_audit',
  };

  LlmRoutePlan previewRoute({
    required String taskType,
    String prompt = '',
    bool requiresReasoning = false,
  }) {
    final String normalizedTask = taskType.trim().toLowerCase();
    final LlmRoutingTier tier;
    final String reason;

    if (_criticalTasks.contains(normalizedTask)) {
      tier = LlmRoutingTier.critical;
      reason =
          'High-stakes audit or architecture task routed to critical tier.';
    } else if (_complexTasks.contains(normalizedTask) ||
        requiresReasoning ||
        prompt.length > 4000) {
      tier = LlmRoutingTier.complex;
      reason = 'Complex reasoning or long prompt routed to advanced model.';
    } else if (_trivialTasks.contains(normalizedTask)) {
      tier = LlmRoutingTier.trivial;
      reason = 'Lightweight classification/tagging task routed to flash-lite.';
    } else {
      tier = LlmRoutingTier.standard;
      reason = 'Standard structured task routed to balanced model.';
    }

    final LlmRoutingTierSpec spec = kDefaultRoutingTierSpecs[tier]!;
    return LlmRoutePlan(
      taskType: normalizedTask.isEmpty ? 'classification' : normalizedTask,
      tier: tier,
      effort: tier.effort,
      modelClass: spec.modelClass,
      provider: spec.provider,
      model: spec.model,
      fallbackChain: spec.fallbackChain,
      recommendedOutputLimit: spec.outputLimit,
      reason: reason,
      preferenceApplied: false,
      recommendedTier: tier,
      recommendedProvider: spec.provider,
      recommendedModel: spec.model,
    );
  }
}

abstract interface class StructuredLlmRoutingRepository {
  Future<LlmRoutePlan> resolveRoute({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    Map<String, Object?>? responseSchema,
  });

  Future<StructuredRoutingPersistResult> validateAndSave({
    required String taskType,
    required String prompt,
    required bool requiresReasoning,
    required String rawOutput,
    required Map<String, Object?> responseSchema,
    required String schemaName,
  });

  Future<List<StructuredRoutingPreferenceRecord>> listPreferences();
}
