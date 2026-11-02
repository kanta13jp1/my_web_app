enum AiFormFieldKind { text, multiline, choice, boolean }

class AiFormFieldDefinition {
  const AiFormFieldDefinition({
    required this.id,
    required this.label,
    required this.description,
    required this.kind,
    required this.defaultValue,
    this.required = false,
    this.options = const <String>[],
    this.maxLength,
  });

  final String id;
  final String label;
  final String description;
  final AiFormFieldKind kind;
  final Object defaultValue;
  final bool required;
  final List<String> options;
  final int? maxLength;

  Object? normalizeAiValue(Object? rawValue) {
    switch (kind) {
      case AiFormFieldKind.text:
      case AiFormFieldKind.multiline:
        final value = rawValue?.toString().trim() ?? '';
        if (maxLength != null && value.length > maxLength!) return null;
        return value;
      case AiFormFieldKind.choice:
        final value = rawValue?.toString().trim() ?? '';
        return options.contains(value) ? value : null;
      case AiFormFieldKind.boolean:
        if (rawValue is bool) return rawValue;
        final value = rawValue?.toString().trim().toLowerCase();
        if (value == 'true') return true;
        if (value == 'false') return false;
        return null;
    }
  }

  String? validate(Object? rawValue) {
    final value = rawValue?.toString().trim() ?? '';
    if (required && value.isEmpty) return '$labelを入力してください';
    if (maxLength != null && value.length > maxLength!) {
      return '$labelは$maxLength文字以内で入力してください';
    }
    if (kind == AiFormFieldKind.choice && !options.contains(rawValue)) {
      return '$labelを選択してください';
    }
    if (kind == AiFormFieldKind.boolean && rawValue is! bool) {
      return '$labelの設定が不正です';
    }
    return null;
  }

  Map<String, Object?> toPromptSchema() => <String, Object?>{
        'field_id': id,
        'label': label,
        'description': description,
        'type': kind.name,
        'required': required,
        if (options.isNotEmpty) 'allowed_values': options,
        if (maxLength != null) 'max_length': maxLength,
      };
}

const List<AiFormFieldDefinition> aiWorkflowFormFields =
    <AiFormFieldDefinition>[
  AiFormFieldDefinition(
    id: 'workflow_name',
    label: '設定名',
    description: '何のための設定か一目で分かる短い名前',
    kind: AiFormFieldKind.text,
    defaultValue: '',
    required: true,
    maxLength: 80,
  ),
  AiFormFieldDefinition(
    id: 'purpose',
    label: '目的',
    description: '達成したい状態と利用者が分かる具体的な説明',
    kind: AiFormFieldKind.multiline,
    defaultValue: '',
    required: true,
    maxLength: 400,
  ),
  AiFormFieldDefinition(
    id: 'trigger',
    label: '実行タイミング',
    description: '設定を実行するタイミング',
    kind: AiFormFieldKind.choice,
    defaultValue: '毎週',
    required: true,
    options: <String>['毎日', '毎週', 'イベント発生時', '手動'],
  ),
  AiFormFieldDefinition(
    id: 'notification_target',
    label: '通知先',
    description: '結果を受け取るメールアドレスまたはチャンネル名',
    kind: AiFormFieldKind.text,
    defaultValue: '',
    maxLength: 160,
  ),
  AiFormFieldDefinition(
    id: 'approval_required',
    label: '実行前の承認',
    description: '実行前に人の確認を必須にするか',
    kind: AiFormFieldKind.boolean,
    defaultValue: true,
  ),
  AiFormFieldDefinition(
    id: 'approver',
    label: '承認者',
    description: '承認を担当する人または役割。承認不要なら空欄',
    kind: AiFormFieldKind.text,
    defaultValue: '',
    maxLength: 80,
  ),
  AiFormFieldDefinition(
    id: 'success_criteria',
    label: '完了条件',
    description: '成功したと判断できる測定可能な基準',
    kind: AiFormFieldKind.multiline,
    defaultValue: '',
    maxLength: 300,
  ),
];

enum AiFormChatRole { user, assistant }

class AiFormChatMessage {
  const AiFormChatMessage({required this.role, required this.text});

  final AiFormChatRole role;
  final String text;
}

class AiFormChange {
  const AiFormChange({
    required this.fieldId,
    required this.value,
    required this.reason,
  });

  final String fieldId;
  final Object value;
  final String reason;
}

class AiFormAssistantReply {
  const AiFormAssistantReply({
    required this.message,
    this.changes = const <AiFormChange>[],
  });

  final String message;
  final List<AiFormChange> changes;
}

class AiFormProposal {
  const AiFormProposal({
    required this.changes,
    required this.baseFieldRevisions,
  });

  final List<AiFormChange> changes;
  final Map<String, int> baseFieldRevisions;
}

class AiFormApplyResult {
  const AiFormApplyResult({required this.applied, required this.skipped});

  final List<AiFormChange> applied;
  final List<AiFormChange> skipped;
}
