import 'package:flutter/foundation.dart';

/// 5要素構造化プロンプトテンプレートの最大文字数定義 (#2665).
abstract final class PromptTemplateLimits {
  static const int maxTitleLength = 120;
  static const int maxRoleLength = 2000;
  static const int maxElementLength = 4000;
}

/// テンプレート一覧の表示フィルタ区分 (#2665).
enum PromptTemplateFilter {
  all('all', 'すべて'),
  shared('shared', 'チーム共有'),
  mine('mine', '自分のみ');

  const PromptTemplateFilter(this.wireName, this.labelJa);

  final String wireName;
  final String labelJa;
}

/// 5要素構造化プロンプトの各要素 (#2665).
@immutable
class PromptElements {
  const PromptElements({
    this.roleSetting = '',
    this.contextInfo = '',
    this.deliverableDefinition = '',
    this.constraintsText = '',
    this.thinkingProcess = '',
  });

  final String roleSetting;
  final String contextInfo;
  final String deliverableDefinition;
  final String constraintsText;
  final String thinkingProcess;

  bool get isComplete => validateErrors().isEmpty;

  PromptElements copyWith({
    final String? roleSetting,
    final String? contextInfo,
    final String? deliverableDefinition,
    final String? constraintsText,
    final String? thinkingProcess,
  }) {
    return PromptElements(
      roleSetting: roleSetting ?? this.roleSetting,
      contextInfo: contextInfo ?? this.contextInfo,
      deliverableDefinition:
          deliverableDefinition ?? this.deliverableDefinition,
      constraintsText: constraintsText ?? this.constraintsText,
      thinkingProcess: thinkingProcess ?? this.thinkingProcess,
    );
  }

  /// 未入力または上限超過の要素エラー一覧を返す。
  List<String> validateErrors() {
    final errors = <String>[];
    final role = roleSetting.trim();
    final context = contextInfo.trim();
    final deliverable = deliverableDefinition.trim();
    final constraints = constraintsText.trim();
    final thinking = thinkingProcess.trim();

    if (role.isEmpty) {
      errors.add('役割設定を入力してください。');
    } else if (role.length > PromptTemplateLimits.maxRoleLength) {
      errors.add(
        '役割設定は${PromptTemplateLimits.maxRoleLength}文字以内で入力してください。',
      );
    }

    if (context.isEmpty) {
      errors.add('コンテキスト情報を入力してください。');
    } else if (context.length > PromptTemplateLimits.maxElementLength) {
      errors.add(
        'コンテキスト情報は${PromptTemplateLimits.maxElementLength}文字以内で入力してください。',
      );
    }

    if (deliverable.isEmpty) {
      errors.add('成果物の定義を入力してください。');
    } else if (deliverable.length > PromptTemplateLimits.maxElementLength) {
      errors.add(
        '成果物の定義は${PromptTemplateLimits.maxElementLength}文字以内で入力してください。',
      );
    }

    if (constraints.isEmpty) {
      errors.add('制約条件を入力してください。');
    } else if (constraints.length > PromptTemplateLimits.maxElementLength) {
      errors.add(
        '制約条件は${PromptTemplateLimits.maxElementLength}文字以内で入力してください。',
      );
    }

    if (thinking.isEmpty) {
      errors.add('思考プロセスを入力してください。');
    } else if (thinking.length > PromptTemplateLimits.maxElementLength) {
      errors.add(
        '思考プロセスは${PromptTemplateLimits.maxElementLength}文字以内で入力してください。',
      );
    }

    return errors;
  }

  /// 5要素を1つの決定論的なプレーンテキストプロンプトへ結合する。
  String compilePlainText({final String? title}) {
    final buffer = StringBuffer();
    final normalizedTitle = title?.trim() ?? '';
    if (normalizedTitle.isNotEmpty) {
      buffer.writeln('# $normalizedTitle');
      buffer.writeln();
    }

    final sections = <({String heading, String body})>[
      (heading: '## 1. 役割設定', body: roleSetting.trim()),
      (heading: '## 2. コンテキスト情報', body: contextInfo.trim()),
      (heading: '## 3. 成果物の定義', body: deliverableDefinition.trim()),
      (heading: '## 4. 制約条件', body: constraintsText.trim()),
      (heading: '## 5. 思考プロセス', body: thinkingProcess.trim()),
    ];

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      buffer.writeln(section.heading);
      buffer.write(section.body.isEmpty ? '(未入力)' : section.body);
      if (i < sections.length - 1) {
        buffer.writeln();
        buffer.writeln();
      }
    }

    return buffer.toString().trim();
  }

  bool matchesQuery(final String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return true;
    }
    return roleSetting.toLowerCase().contains(normalizedQuery) ||
        contextInfo.toLowerCase().contains(normalizedQuery) ||
        deliverableDefinition.toLowerCase().contains(normalizedQuery) ||
        constraintsText.toLowerCase().contains(normalizedQuery) ||
        thinkingProcess.toLowerCase().contains(normalizedQuery);
  }

  @override
  bool operator ==(final Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PromptElements &&
        other.roleSetting == roleSetting &&
        other.contextInfo == contextInfo &&
        other.deliverableDefinition == deliverableDefinition &&
        other.constraintsText == constraintsText &&
        other.thinkingProcess == thinkingProcess;
  }

  @override
  int get hashCode => Object.hash(
        roleSetting,
        contextInfo,
        deliverableDefinition,
        constraintsText,
        thinkingProcess,
      );
}

/// テンプレート保存・更新用の入力ドラフト (#2665).
@immutable
class PromptTemplateDraft {
  const PromptTemplateDraft({
    required this.title,
    required this.elements,
    this.isShared = false,
    this.editingTemplateId,
  });

  final String title;
  final PromptElements elements;
  final bool isShared;
  final String? editingTemplateId;

  List<String> validate() {
    final errors = <String>[];
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      errors.add('テンプレート名を入力してください。');
    } else if (normalizedTitle.length > PromptTemplateLimits.maxTitleLength) {
      errors.add(
        'テンプレート名は${PromptTemplateLimits.maxTitleLength}文字以内で入力してください。',
      );
    }
    errors.addAll(elements.validateErrors());
    return errors;
  }

  Map<String, Object?> toInsertPayload({required final String userId}) {
    return <String, Object?>{
      'user_id': userId,
      'title': title.trim(),
      'role_setting': elements.roleSetting.trim(),
      'context_info': elements.contextInfo.trim(),
      'deliverable_definition': elements.deliverableDefinition.trim(),
      'constraints_text': elements.constraintsText.trim(),
      'thinking_process': elements.thinkingProcess.trim(),
      'is_shared': isShared,
    };
  }

  Map<String, Object?> toUpdatePayload() {
    return <String, Object?>{
      'title': title.trim(),
      'role_setting': elements.roleSetting.trim(),
      'context_info': elements.contextInfo.trim(),
      'deliverable_definition': elements.deliverableDefinition.trim(),
      'constraints_text': elements.constraintsText.trim(),
      'thinking_process': elements.thinkingProcess.trim(),
      'is_shared': isShared,
    };
  }
}

/// Supabase `prompt_templates` テーブルのドメインモデル (#2665).
@immutable
class PromptTemplate {
  const PromptTemplate({
    required this.id,
    required this.userId,
    required this.title,
    required this.elements,
    required this.isShared,
    required this.usageCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromptTemplate.fromSupabaseRow(final Map<String, Object?> row) {
    final createdRaw = row['created_at']?.toString() ?? '';
    final updatedRaw = row['updated_at']?.toString() ?? '';
    final createdAt = DateTime.tryParse(createdRaw)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final updatedAt = DateTime.tryParse(updatedRaw)?.toUtc() ?? createdAt;
    return PromptTemplate(
      id: (row['id']?.toString() ?? '').trim(),
      userId: (row['user_id']?.toString() ?? '').trim(),
      title: (row['title']?.toString() ?? '').trim(),
      elements: PromptElements(
        roleSetting: (row['role_setting']?.toString() ?? '').trim(),
        contextInfo: (row['context_info']?.toString() ?? '').trim(),
        deliverableDefinition:
            (row['deliverable_definition']?.toString() ?? '').trim(),
        constraintsText: (row['constraints_text']?.toString() ?? '').trim(),
        thinkingProcess: (row['thinking_process']?.toString() ?? '').trim(),
      ),
      isShared: row['is_shared'] == true,
      usageCount: (row['usage_count'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  final String id;
  final String userId;
  final String title;
  final PromptElements elements;
  final bool isShared;
  final int usageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get compiledPrompt => elements.compilePlainText(title: title);

  bool matchesSearch(final String rawQuery) {
    final normalized = rawQuery.trim().toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }
    return title.toLowerCase().contains(normalized) ||
        elements.matchesQuery(normalized);
  }

  PromptTemplate copyWith({
    final String? id,
    final String? userId,
    final String? title,
    final PromptElements? elements,
    final bool? isShared,
    final int? usageCount,
    final DateTime? createdAt,
    final DateTime? updatedAt,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      elements: elements ?? this.elements,
      isShared: isShared ?? this.isShared,
      usageCount: usageCount ?? this.usageCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 外部 AI API 送信結果 (#2665).
@immutable
class PromptTemplateSendResult {
  const PromptTemplateSendResult({
    required this.responseText,
    this.providerLabel = 'ai-hub',
    this.latencyMs,
  });

  final String responseText;
  final String providerLabel;
  final int? latencyMs;
}

/// 5要素構造化プロンプトテンプレートのリポジトリ契約 (#2665).
abstract interface class PromptTemplateRepository {
  String? get currentUserId;

  Future<List<PromptTemplate>> listTemplates();

  Future<PromptTemplate> saveTemplate(final PromptTemplateDraft draft);

  Future<void> deleteTemplate(final String templateId);

  Future<PromptTemplate> recordTemplateUsage(final String templateId);

  Future<PromptTemplateSendResult> sendCompiledPrompt(
    final String compiledPrompt,
  );
}
