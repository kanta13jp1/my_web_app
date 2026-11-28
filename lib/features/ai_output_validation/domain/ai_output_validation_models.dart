import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 決定的 AI 出力検証の最終判定 (#2657).
enum ValidationDecision {
  passed(wireValue: 'passed', displayLabel: '通過'),
  remediated(wireValue: 'remediated', displayLabel: '自動修正'),
  blocked(wireValue: 'blocked', displayLabel: 'ブロック');

  const ValidationDecision({
    required this.wireValue,
    required this.displayLabel,
  });

  final String wireValue;
  final String displayLabel;

  static ValidationDecision fromWireValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final item in ValidationDecision.values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return ValidationDecision.blocked;
  }
}

/// 出力形式コントラクト (#2657).
enum OutputFormatContract {
  markdownSections(
    wireValue: 'markdown_sections',
    displayLabel: 'Markdown見出し構造',
  ),
  jsonObject(
    wireValue: 'json_object',
    displayLabel: 'JSON構造スキーマ',
  ),
  conciseSummary(
    wireValue: 'concise_summary',
    displayLabel: '簡潔サマリー',
  ),
  plainText(
    wireValue: 'plain_text',
    displayLabel: 'プレーンテキスト',
  );

  const OutputFormatContract({
    required this.wireValue,
    required this.displayLabel,
  });

  final String wireValue;
  final String displayLabel;

  static OutputFormatContract fromWireValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final item in OutputFormatContract.values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return OutputFormatContract.markdownSections;
  }
}

/// 個別ルール違反の重要度 (#2657).
enum ViolationSeverity {
  warning(wireValue: 'warning', displayLabel: '注意'),
  remediate(wireValue: 'remediate', displayLabel: '修正'),
  block(wireValue: 'block', displayLabel: '停止');

  const ViolationSeverity({
    required this.wireValue,
    required this.displayLabel,
  });

  final String wireValue;
  final String displayLabel;

  static ViolationSeverity fromWireValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    for (final item in ViolationSeverity.values) {
      if (item.wireValue == normalized) {
        return item;
      }
    }
    return ViolationSeverity.block;
  }
}

/// 検証で検知された個別違反詳細 (#2657).
@immutable
class ValidationViolation {
  const ValidationViolation({
    required this.code,
    required this.severity,
    required this.message,
  });

  factory ValidationViolation.fromJson(Map<String, Object?> json) {
    return ValidationViolation(
      code: (json['code'] as String? ?? 'unknown_violation').trim(),
      severity: ViolationSeverity.fromWireValue(json['severity'] as String?),
      message: (json['message'] as String? ?? '').trim(),
    );
  }

  final String code;
  final ViolationSeverity severity;
  final String message;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'code': code,
      'severity': severity.wireValue,
      'message': message,
    };
  }
}

/// `ai_output_validation_logs` 監査ログモデル (#2657).
@immutable
class AiOutputValidationLog {
  const AiOutputValidationLog({
    required this.id,
    required this.ruleSetVersion,
    required this.decision,
    required this.formatContract,
    required this.promptExcerpt,
    required this.originalOutputExcerpt,
    required this.remediatedOutputExcerpt,
    required this.violations,
    required this.driftScore,
    required this.reviewedByAdmin,
    required this.createdAt,
  });

  factory AiOutputValidationLog.fromSupabaseRow(Map<String, Object?> row) {
    final rawViolations = row['violations'];
    final parsedViolations = <ValidationViolation>[];
    if (rawViolations is List<Object?>) {
      for (final item in rawViolations) {
        if (item is Map<String, Object?>) {
          parsedViolations.add(ValidationViolation.fromJson(item));
        } else if (item is Map<Object?, Object?>) {
          final normalized = <String, Object?>{};
          for (final entry in item.entries) {
            if (entry.key != null) {
              normalized[entry.key.toString()] = entry.value;
            }
          }
          parsedViolations.add(ValidationViolation.fromJson(normalized));
        }
      }
    }

    final rawCreated = row['created_at'] as String?;
    final parsedCreated = rawCreated != null
        ? DateTime.tryParse(rawCreated)?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return AiOutputValidationLog(
      id: (row['id'] as String? ?? '').trim(),
      ruleSetVersion: (row['rule_set_version'] as String? ?? 'v1.0').trim(),
      decision: ValidationDecision.fromWireValue(row['decision'] as String?),
      formatContract: OutputFormatContract.fromWireValue(
        row['format_contract'] as String?,
      ),
      promptExcerpt: (row['prompt_excerpt'] as String? ?? '').trim(),
      originalOutputExcerpt:
          (row['original_output_excerpt'] as String? ?? '').trim(),
      remediatedOutputExcerpt:
          (row['remediated_output_excerpt'] as String? ?? '').trim(),
      violations: List<ValidationViolation>.unmodifiable(parsedViolations),
      driftScore: (row['drift_score'] as num?)?.toDouble() ?? 0.0,
      reviewedByAdmin: row['reviewed_by_admin'] as bool? ?? false,
      createdAt: parsedCreated,
    );
  }

  final String id;
  final String ruleSetVersion;
  final ValidationDecision decision;
  final OutputFormatContract formatContract;
  final String promptExcerpt;
  final String originalOutputExcerpt;
  final String remediatedOutputExcerpt;
  final List<ValidationViolation> violations;
  final double driftScore;
  final bool reviewedByAdmin;
  final DateTime createdAt;

  int get violationCount => violations.length;

  AiOutputValidationLog copyWith({
    String? id,
    String? ruleSetVersion,
    ValidationDecision? decision,
    OutputFormatContract? formatContract,
    String? promptExcerpt,
    String? originalOutputExcerpt,
    String? remediatedOutputExcerpt,
    List<ValidationViolation>? violations,
    double? driftScore,
    bool? reviewedByAdmin,
    DateTime? createdAt,
  }) {
    return AiOutputValidationLog(
      id: id ?? this.id,
      ruleSetVersion: ruleSetVersion ?? this.ruleSetVersion,
      decision: decision ?? this.decision,
      formatContract: formatContract ?? this.formatContract,
      promptExcerpt: promptExcerpt ?? this.promptExcerpt,
      originalOutputExcerpt:
          originalOutputExcerpt ?? this.originalOutputExcerpt,
      remediatedOutputExcerpt:
          remediatedOutputExcerpt ?? this.remediatedOutputExcerpt,
      violations: violations ?? this.violations,
      driftScore: driftScore ?? this.driftScore,
      reviewedByAdmin: reviewedByAdmin ?? this.reviewedByAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 決定論的 AI 出力検証シミュレータ (#2657).
class DeterministicAiOutputValidator {
  const DeterministicAiOutputValidator._();

  static const String defaultRuleSetVersion = 'v1.0';

  static final RegExp _emailRe = RegExp(
    r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}',
    caseSensitive: false,
  );
  static final RegExp _jpPhoneRe = RegExp(r'0\d{1,4}-\d{1,4}-\d{3,4}');
  static final RegExp _tokenRe = RegExp(
    r'(?:sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|sb_secret_[A-Za-z0-9_]{12,}|AIza[0-9A-Za-z\-_]{30,})',
  );
  static final RegExp _promptLeakRe = RegExp(
    r'(?:SYSTEM_PROMPT:|BEGIN_INTERNAL_INSTRUCTIONS|DEVELOPER_POLICY_OVERRIDE)',
    caseSensitive: false,
  );
  static final RegExp _guaranteeRe = RegExp(
    r'(?:100%\s*guaranteed\s*(?:profit|return)|確実に儲かる|元本保証で必ず増える|絶対に副作用はありません|医学的診断を確定します)',
    caseSensitive: false,
  );
  static final RegExp _placeholderRe = RegExp(
    r'\b(?:TODO_PLACEHOLDER|FIXME_OUTPUT|LOREM_IPSUM_PLACEHOLDER)\b',
    caseSensitive: false,
  );
  static final RegExp _fenceRe = RegExp(
    r'^```(?:json|JSON)?\s*\n([\s\S]*?)\n```$',
  );

  static bool _jsonValuesEqual(Object? a, Object? b) {
    if (identical(a, b)) {
      return true;
    }
    if (a == null || b == null) {
      return a == null && b == null;
    }
    if (a is bool || b is bool) {
      return a is bool && b is bool && a == b;
    }
    if (a is num && b is num) {
      return a == b;
    }
    if (a is List<Object?> && b is List<Object?>) {
      if (a.length != b.length) {
        return false;
      }
      for (var i = 0; i < a.length; i++) {
        if (!_jsonValuesEqual(a[i], b[i])) {
          return false;
        }
      }
      return true;
    }
    if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
      if (a.length != b.length) {
        return false;
      }
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key) ||
            !_jsonValuesEqual(entry.value, b[entry.key])) {
          return false;
        }
      }
      return true;
    }
    return a == b;
  }

  static String maskSensitiveText(String raw, {int maxChars = 1000}) {
    final masked = raw
        .replaceAll(_emailRe, '***')
        .replaceAll(_jpPhoneRe, '***')
        .replaceAll(_tokenRe, '***')
        .trim();
    if (masked.length <= maxChars) {
      return masked;
    }
    if (maxChars <= 3) {
      return masked.substring(0, maxChars);
    }
    return '${masked.substring(0, maxChars - 3)}...';
  }

  static AiOutputValidationLog evaluate({
    required String prompt,
    required String candidateOutput,
    OutputFormatContract formatContract = OutputFormatContract.markdownSections,
    List<String> requiredHeadings = const <String>['## 結論', '## 根拠'],
    List<String> requiredFields = const <String>[],
    bool disallowExtraFields = false,
    Map<String, Object?> forbiddenExampleValues = const <String, Object?>{},
    List<String> bannedTerms = const <String>[],
    int maxLength = 4000,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final violations = <ValidationViolation>[];
    String working = candidateOutput.trim();

    if (working.isEmpty) {
      violations.add(
        const ValidationViolation(
          code: 'empty_output',
          severity: ViolationSeverity.block,
          message: 'AI出力が空のためブロックしました。',
        ),
      );
      return AiOutputValidationLog(
        id: 'pending-local',
        ruleSetVersion: defaultRuleSetVersion,
        decision: ValidationDecision.blocked,
        formatContract: formatContract,
        promptExcerpt: maskSensitiveText(prompt, maxChars: 1000).isEmpty
            ? '(empty-prompt)'
            : maskSensitiveText(prompt, maxChars: 1000),
        originalOutputExcerpt: '',
        remediatedOutputExcerpt: '[BLOCKED]',
        violations: List<ValidationViolation>.unmodifiable(violations),
        driftScore: 0.5,
        reviewedByAdmin: false,
        createdAt: timestamp,
      );
    }

    if (_promptLeakRe.hasMatch(working)) {
      violations.add(
        const ValidationViolation(
          code: 'system_prompt_leak_marker',
          severity: ViolationSeverity.block,
          message: '内部システムプロンプト露出マーカーを検出したため出力をブロックしました。',
        ),
      );
    }
    if (_guaranteeRe.hasMatch(working)) {
      violations.add(
        const ValidationViolation(
          code: 'ungrounded_absolute_guarantee',
          severity: ViolationSeverity.block,
          message: '根拠のない断定的保証表現を検出したため出力をブロックしました。',
        ),
      );
    }
    if (_tokenRe.hasMatch(working)) {
      violations.add(
        const ValidationViolation(
          code: 'compliance_pii_credential',
          severity: ViolationSeverity.block,
          message: '認証トークンリテラルを検出したため出力をブロックしました。',
        ),
      );
    }

    final piiMasked =
        working.replaceAll(_emailRe, '***').replaceAll(_jpPhoneRe, '***');
    if (piiMasked != working) {
      working = piiMasked;
      violations.add(
        const ValidationViolation(
          code: 'compliance_pii_masked',
          severity: ViolationSeverity.remediate,
          message: '連絡先等の機微情報を自動マスクしました。',
        ),
      );
    }

    if (_placeholderRe.hasMatch(working)) {
      working = working.replaceAll(_placeholderRe, '[REMOVED]').trim();
      violations.add(
        const ValidationViolation(
          code: 'degenerate_placeholder_token',
          severity: ViolationSeverity.remediate,
          message: '未完成プレースホルダートークンを除去しました。',
        ),
      );
    }

    for (final rawTerm in bannedTerms) {
      final term = rawTerm.trim();
      if (term.isEmpty) {
        continue;
      }
      final termRe = RegExp(RegExp.escape(term), caseSensitive: false);
      if (termRe.hasMatch(working)) {
        working = working.replaceAll(termRe, '[REMOVED]').trim();
        violations.add(
          const ValidationViolation(
            code: 'custom_banned_term_remediated',
            severity: ViolationSeverity.remediate,
            message: '指定禁止語句を自動除去しました。',
          ),
        );
      }
    }

    if (formatContract == OutputFormatContract.jsonObject) {
      final fenceMatch = _fenceRe.firstMatch(working);
      if (fenceMatch != null) {
        working = (fenceMatch.group(1) ?? '').trim();
        violations.add(
          const ValidationViolation(
            code: 'json_code_fence_stripped',
            severity: ViolationSeverity.remediate,
            message: 'JSON周囲のMarkdownコードフェンスを除去しました。',
          ),
        );
      }
      try {
        final rawDecoded = jsonDecode(working);
        if (rawDecoded is! Map<Object?, Object?>) {
          violations.add(
            const ValidationViolation(
              code: 'invalid_json_object_type',
              severity: ViolationSeverity.block,
              message: 'JSON出力はオブジェクト形式である必要があります。',
            ),
          );
        } else {
          final fieldMap = <String, Object?>{
            for (final entry in rawDecoded.entries)
              if (entry.key != null) entry.key.toString(): entry.value,
          };
          final allowedFields = <String>{};
          for (final rawField in requiredFields) {
            final field = rawField.trim();
            if (field.isEmpty) {
              continue;
            }
            allowedFields.add(field);
            final fieldVal = fieldMap[field];
            final isBlankString = fieldVal is String &&
                fieldVal.trim().isEmpty &&
                !fieldVal.contains('\t');
            if (fieldVal == null || isBlankString) {
              violations.add(
                ValidationViolation(
                  code: 'missing_required_field_$field',
                  severity: ViolationSeverity.block,
                  message: '必須JSONフィールド「$field」が欠落しています。',
                ),
              );
            }
          }
          if (disallowExtraFields && allowedFields.isNotEmpty) {
            for (final extraKey in fieldMap.keys) {
              if (!allowedFields.contains(extraKey)) {
                violations.add(
                  ValidationViolation(
                    code: 'unexpected_extra_field_$extraKey',
                    severity: ViolationSeverity.block,
                    message: '指定外のJSONフィールド「$extraKey」が含まれています。',
                  ),
                );
              }
            }
          }
          if (forbiddenExampleValues.isNotEmpty) {
            for (final entry in forbiddenExampleValues.entries) {
              if (fieldMap.containsKey(entry.key) &&
                  _jsonValuesEqual(fieldMap[entry.key], entry.value)) {
                violations.add(
                  ValidationViolation(
                    code: 'copied_example_value_${entry.key}',
                    severity: ViolationSeverity.block,
                    message: 'サンプル値と同一の値がフィールド「${entry.key}」に混入しています。',
                  ),
                );
              }
            }
          }
          working = jsonEncode(fieldMap);
        }
      } on FormatException {
        violations.add(
          const ValidationViolation(
            code: 'invalid_json_syntax',
            severity: ViolationSeverity.block,
            message: 'JSON構文のパースに失敗しました。',
          ),
        );
      }
    } else if (formatContract == OutputFormatContract.markdownSections) {
      final headings = requiredHeadings.isNotEmpty
          ? requiredHeadings
          : const <String>['## 結論', '## 根拠'];
      for (final heading in headings) {
        final trimmedHeading = heading.trim();
        if (trimmedHeading.isNotEmpty && !working.contains(trimmedHeading)) {
          violations.add(
            ValidationViolation(
              code: 'missing_required_markdown_heading',
              severity: ViolationSeverity.block,
              message: '必須Markdown見出し「$trimmedHeading」が不足しています。',
            ),
          );
        }
      }
    } else if (formatContract == OutputFormatContract.conciseSummary) {
      final effectiveLimit = maxLength < 40 ? 40 : maxLength;
      if (working.length > effectiveLimit) {
        working = '${working.substring(0, effectiveLimit - 3).trimRight()}...';
        violations.add(
          ValidationViolation(
            code: 'summary_max_length_truncated',
            severity: ViolationSeverity.remediate,
            message: '上限文字数 ($effectiveLimit) を超過したため短縮しました。',
          ),
        );
      }
    }

    final hasBlock = violations.any(
      (ValidationViolation v) => v.severity == ViolationSeverity.block,
    );
    final hasRemediate = violations.any(
      (ValidationViolation v) => v.severity == ViolationSeverity.remediate,
    );

    final ValidationDecision decision;
    if (hasBlock) {
      decision = ValidationDecision.blocked;
    } else if (hasRemediate || violations.isNotEmpty) {
      decision = ValidationDecision.remediated;
    } else {
      decision = ValidationDecision.passed;
    }

    double rawDrift = 0;
    for (final v in violations) {
      if (v.severity == ViolationSeverity.block) {
        rawDrift += 0.5;
      } else if (v.severity == ViolationSeverity.remediate) {
        rawDrift += 0.2;
      } else {
        rawDrift += 0.05;
      }
    }
    final boundedDrift =
        ((rawDrift.clamp(0.0, 1.0)) * 10000).roundToDouble() / 10000;

    final safePrompt = maskSensitiveText(prompt, maxChars: 1000);
    return AiOutputValidationLog(
      id: 'pending-local',
      ruleSetVersion: defaultRuleSetVersion,
      decision: decision,
      formatContract: formatContract,
      promptExcerpt: safePrompt.isEmpty ? '(empty-prompt)' : safePrompt,
      originalOutputExcerpt: maskSensitiveText(candidateOutput, maxChars: 2000),
      remediatedOutputExcerpt: decision == ValidationDecision.blocked
          ? '[BLOCKED]'
          : maskSensitiveText(working, maxChars: 2000),
      violations: List<ValidationViolation>.unmodifiable(violations),
      driftScore: boundedDrift,
      reviewedByAdmin: false,
      createdAt: timestamp,
    );
  }
}

/// 検証監査ログ永続化リポジトリ契約 (#2657).
abstract interface class AiOutputValidationRepository {
  Future<List<AiOutputValidationLog>> fetchLogs();

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
  });
}
