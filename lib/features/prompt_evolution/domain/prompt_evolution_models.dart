import 'package:flutter/foundation.dart';

Map<String, Object?> normalizeJsonObject(Object? raw, String context) {
  if (raw is! Map<Object?, Object?>) {
    throw FormatException('Expected JSON object for $context.');
  }
  final normalized = <String, Object?>{};
  for (final entry in raw.entries) {
    final Object? key = entry.key;
    if (key is! String) {
      throw FormatException('Expected String keys in $context.');
    }
    normalized[key] = entry.value;
  }
  return normalized;
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

double _requireDouble(Map<String, Object?> json, String key) {
  final Object? raw = json[key];
  if (raw is! num) {
    throw FormatException('Missing or invalid num "$key".');
  }
  return raw.toDouble();
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

@immutable
class PromptEvolutionDraft {
  const PromptEvolutionDraft({
    required this.title,
    required this.roleSetting,
    required this.contextInfo,
    required this.deliverableDefinition,
    required this.constraintsText,
    required this.thinkingProcess,
  });

  final String title;
  final String roleSetting;
  final String contextInfo;
  final String deliverableDefinition;
  final String constraintsText;
  final String thinkingProcess;

  factory PromptEvolutionDraft.fromJson(Map<String, Object?> json) {
    return PromptEvolutionDraft(
      title: _requireNonEmptyString(json, 'title'),
      roleSetting: _requireNonEmptyString(json, 'roleSetting'),
      contextInfo: _requireNonEmptyString(json, 'contextInfo'),
      deliverableDefinition:
          _requireNonEmptyString(json, 'deliverableDefinition'),
      constraintsText: _requireNonEmptyString(json, 'constraintsText'),
      thinkingProcess: _requireNonEmptyString(json, 'thinkingProcess'),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'title': title,
        'role_setting': roleSetting,
        'context_info': contextInfo,
        'deliverable_definition': deliverableDefinition,
        'constraints_text': constraintsText,
        'thinking_process': thinkingProcess,
      };
}

@immutable
class GpaBatchEvaluationReport {
  const GpaBatchEvaluationReport({
    required this.sampleCount,
    required this.meanGpa,
    required this.meanConsistency,
    required this.meanEfficiency,
    required this.scoreVariance,
    required this.scoreStddev,
    required this.varianceThreshold,
    required this.evolutionTriggered,
  });

  final int sampleCount;
  final double meanGpa;
  final double meanConsistency;
  final double meanEfficiency;
  final double scoreVariance;
  final double scoreStddev;
  final double varianceThreshold;
  final bool evolutionTriggered;

  factory GpaBatchEvaluationReport.fromJson(Map<String, Object?> json) {
    return GpaBatchEvaluationReport(
      sampleCount: _requireInt(json, 'sampleCount'),
      meanGpa: _requireDouble(json, 'meanGpa'),
      meanConsistency: _requireDouble(json, 'meanConsistency'),
      meanEfficiency: _requireDouble(json, 'meanEfficiency'),
      scoreVariance: _requireDouble(json, 'scoreVariance'),
      scoreStddev: _requireDouble(json, 'scoreStddev'),
      varianceThreshold: _requireDouble(json, 'varianceThreshold'),
      evolutionTriggered: _requireBool(json, 'evolutionTriggered'),
    );
  }
}

@immutable
class EvolvedPromptCandidateModel {
  const EvolvedPromptCandidateModel({
    required this.candidateId,
    required this.strategy,
    required this.generation,
    required this.parentTitle,
    required this.draft,
    required this.fitnessScore,
    required this.projectedGpa,
    required this.projectedVarianceDrop,
    required this.reflectionSummary,
    required this.safetyValid,
    required this.safetyIssues,
  });

  final String candidateId;
  final String strategy;
  final int generation;
  final String parentTitle;
  final PromptEvolutionDraft draft;
  final double fitnessScore;
  final double projectedGpa;
  final double projectedVarianceDrop;
  final String reflectionSummary;
  final bool safetyValid;
  final List<String> safetyIssues;

  factory EvolvedPromptCandidateModel.fromJson(Map<String, Object?> json) {
    return EvolvedPromptCandidateModel(
      candidateId: _requireNonEmptyString(json, 'candidateId'),
      strategy: _requireNonEmptyString(json, 'strategy'),
      generation: _requireInt(json, 'generation'),
      parentTitle: _requireNonEmptyString(json, 'parentTitle'),
      draft: PromptEvolutionDraft.fromJson(
        normalizeJsonObject(json['draft'], 'candidate.draft'),
      ),
      fitnessScore: _requireDouble(json, 'fitnessScore'),
      projectedGpa: _requireDouble(json, 'projectedGpa'),
      projectedVarianceDrop: _requireDouble(json, 'projectedVarianceDrop'),
      reflectionSummary: _requireString(json, 'reflectionSummary'),
      safetyValid: _requireBool(json, 'safetyValid'),
      safetyIssues: _requireStringList(json, 'safetyIssues'),
    );
  }
}

@immutable
class PromptEvolutionRunResult {
  const PromptEvolutionRunResult({
    required this.evolutionTriggered,
    required this.savedTemplateId,
    required this.batch,
    required this.candidates,
  });

  final bool evolutionTriggered;
  final String? savedTemplateId;
  final GpaBatchEvaluationReport batch;
  final List<EvolvedPromptCandidateModel> candidates;

  factory PromptEvolutionRunResult.fromJson(Map<String, Object?> json) {
    final Object? rawSavedId = json['saved_template_id'];
    if (rawSavedId != null && rawSavedId is! String) {
      throw const FormatException('Invalid String? "saved_template_id".');
    }
    final Object? rawCandidates = json['candidates'];
    if (rawCandidates is! List<Object?>) {
      throw const FormatException('Missing or invalid List "candidates".');
    }
    final parsedCandidates = <EvolvedPromptCandidateModel>[];
    for (final item in rawCandidates) {
      parsedCandidates.add(
        EvolvedPromptCandidateModel.fromJson(
          normalizeJsonObject(item, 'candidates[]'),
        ),
      );
    }
    return PromptEvolutionRunResult(
      evolutionTriggered: _requireBool(json, 'evolution_triggered'),
      savedTemplateId: rawSavedId as String?,
      batch: GpaBatchEvaluationReport.fromJson(
        normalizeJsonObject(json['batch'], 'batch'),
      ),
      candidates: List<EvolvedPromptCandidateModel>.unmodifiable(
        parsedCandidates,
      ),
    );
  }
}

class PromptSafetyGuard {
  const PromptSafetyGuard();

  static final RegExp _unsafeRegex = RegExp(
    r'(?:SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|DEVELOPER_POLICY_OVERRIDE|ignore all previous instructions)',
    caseSensitive: false,
  );

  List<String> validateDraft(PromptEvolutionDraft draft) {
    final issues = <String>[];
    final checks = <MapEntry<String, String>>[
      MapEntry<String, String>('title', draft.title),
      MapEntry<String, String>('role_setting', draft.roleSetting),
      MapEntry<String, String>('context_info', draft.contextInfo),
      MapEntry<String, String>(
        'deliverable_definition',
        draft.deliverableDefinition,
      ),
      MapEntry<String, String>('constraints_text', draft.constraintsText),
      MapEntry<String, String>('thinking_process', draft.thinkingProcess),
    ];
    for (final entry in checks) {
      final String trimmed = entry.value.trim();
      if (trimmed.isEmpty) {
        issues.add('${entry.key} must not be empty.');
      } else if (_unsafeRegex.hasMatch(trimmed)) {
        issues.add('${entry.key} matched blocked prompt-leak marker.');
      }
    }
    return List<String>.unmodifiable(issues);
  }
}

abstract interface class PromptEvolutionRepository {
  Future<GpaBatchEvaluationReport> evaluateTraceBatch({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
    bool persist = true,
  });

  Future<PromptEvolutionRunResult> evolveFromTraces({
    required double varianceThreshold,
    required List<Map<String, Object?>> traces,
    required PromptEvolutionDraft basePrompt,
    bool persistCandidate = true,
  });

  Future<List<Map<String, Object?>>> listRecentEvaluations({int limit = 20});
}
