import 'dart:convert';

const microMentorNameMaxLength = 80;
const microMentorDomainMaxLength = 120;
const microMentorRoleMaxLength = 600;
const microMentorToneMaxLength = 40;
const microMentorValueMaxLength = 80;
const microMentorValuesInputMaxLength = 720;
const microMentorFocusMaxLength = 1000;
const microMentorProposalTitleMaxLength = 120;
const microMentorProposalDescriptionMaxLength = 2000;

enum MicroMentorProposalType {
  task,
  schedule;

  static MicroMentorProposalType fromValue(Object? value) {
    return value?.toString() == 'schedule' ? schedule : task;
  }

  String get value => name;

  String get label => this == schedule ? '予定' : 'タスク';
}

enum MicroMentorProposalStatus {
  proposed,
  accepted,
  rejected;

  static MicroMentorProposalStatus fromValue(Object? value) {
    return switch (value?.toString()) {
      'accepted' => accepted,
      'rejected' => rejected,
      _ => proposed,
    };
  }

  String get value => name;

  String get label => switch (this) {
        proposed => '確認待ち',
        accepted => '採用',
        rejected => '却下',
      };
}

class MicroMentorDraft {
  final String name;
  final String domain;
  final String role;
  final String tone;
  final List<String> values;

  const MicroMentorDraft({
    required this.name,
    required this.domain,
    required this.role,
    required this.tone,
    required this.values,
  });

  Map<String, dynamic> get promptConfig => <String, dynamic>{
        'role': _boundedMicroMentorText(role, microMentorRoleMaxLength),
        'domain': _boundedMicroMentorText(domain, microMentorDomainMaxLength),
        'tone': _boundedMicroMentorText(tone, microMentorToneMaxLength),
        'important_values': normalizeMicroMentorValues(values),
        'decision_policy': 'proposal_only_user_decides',
      };
}

class MicroMentor {
  final String id;
  final String userId;
  final String slug;
  final String name;
  final String domain;
  final String role;
  final String tone;
  final List<String> values;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MicroMentor({
    required this.id,
    required this.userId,
    required this.slug,
    required this.name,
    required this.domain,
    required this.role,
    required this.tone,
    required this.values,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MicroMentor.fromAgentJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map
        ? Map<String, dynamic>.from(json['metadata'] as Map)
        : const <String, dynamic>{};
    final promptConfig = metadata['prompt_config'] is Map
        ? Map<String, dynamic>.from(metadata['prompt_config'] as Map)
        : const <String, dynamic>{};
    final rawValues = promptConfig['important_values'] ?? metadata['values'];
    return MicroMentor(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      name: json['display_name']?.toString() ?? '',
      domain: (promptConfig['domain'] ?? json['department'])?.toString() ?? '',
      role: (promptConfig['role'] ?? json['role_title'])?.toString() ?? '',
      tone: (promptConfig['tone'] ?? metadata['tone'])?.toString() ?? '穏やか',
      values: normalizeMicroMentorValues(
        rawValues is List ? rawValues.map((item) => item.toString()) : const [],
      ),
      enabled: json['status']?.toString() != 'paused',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  MicroMentorDraft get draft => MicroMentorDraft(
        name: name,
        domain: domain,
        role: role,
        tone: tone,
        values: values,
      );

  Map<String, dynamic> get promptConfig => draft.promptConfig;

  String get systemPrompt =>
      composeMicroMentorSystemPrompt(name: name, promptConfig: promptConfig);
}

class GeneratedMicroMentorProposal {
  final String mentorId;
  final String focus;
  final MicroMentorProposalType type;
  final String title;
  final String description;
  final String rationale;
  final DateTime? scheduledFor;
  final Map<String, dynamic> originalPayload;

  const GeneratedMicroMentorProposal({
    required this.mentorId,
    required this.focus,
    required this.type,
    required this.title,
    required this.description,
    required this.rationale,
    required this.originalPayload,
    this.scheduledFor,
  });
}

class MicroMentorProposal {
  final String id;
  final String userId;
  final String mentorId;
  final String focus;
  final MicroMentorProposalType type;
  final String title;
  final String description;
  final String rationale;
  final MicroMentorProposalStatus status;
  final DateTime? scheduledFor;
  final Map<String, dynamic> originalPayload;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MicroMentorProposal({
    required this.id,
    required this.userId,
    required this.mentorId,
    required this.focus,
    required this.type,
    required this.title,
    required this.description,
    required this.rationale,
    required this.status,
    required this.originalPayload,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledFor,
  });

  factory MicroMentorProposal.fromJson(Map<String, dynamic> json) {
    return MicroMentorProposal(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      mentorId: json['mentor_id']?.toString() ?? '',
      focus: json['focus']?.toString() ?? '',
      type: MicroMentorProposalType.fromValue(json['proposal_type']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      rationale: json['rationale']?.toString() ?? '',
      status: MicroMentorProposalStatus.fromValue(json['status']),
      scheduledFor: json['scheduled_for'] == null
          ? null
          : DateTime.tryParse(json['scheduled_for'].toString()),
      originalPayload: json['original_payload'] is Map
          ? Map<String, dynamic>.from(json['original_payload'] as Map)
          : const <String, dynamic>{},
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  MicroMentorProposal copyWith({
    String? title,
    String? description,
    MicroMentorProposalType? type,
    MicroMentorProposalStatus? status,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
  }) {
    return MicroMentorProposal(
      id: id,
      userId: userId,
      mentorId: mentorId,
      focus: focus,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      rationale: rationale,
      status: status ?? this.status,
      scheduledFor:
          clearScheduledFor ? null : (scheduledFor ?? this.scheduledFor),
      originalPayload: originalPayload,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class MicroMentorDashboardSnapshot {
  final List<MicroMentor> mentors;
  final List<MicroMentorProposal> proposals;

  const MicroMentorDashboardSnapshot({
    required this.mentors,
    required this.proposals,
  });

  const MicroMentorDashboardSnapshot.empty()
      : mentors = const <MicroMentor>[],
        proposals = const <MicroMentorProposal>[];
}

class MicroMentorGenerationResult {
  final List<MicroMentorProposal> proposals;
  final int failedMentorCount;

  const MicroMentorGenerationResult({
    required this.proposals,
    required this.failedMentorCount,
  });
}

List<String> normalizeMicroMentorValues(Iterable<String> values) {
  final normalized = <String>[];
  for (final value in values) {
    final item = _boundedMicroMentorText(value, microMentorValueMaxLength);
    if (item.isNotEmpty && !normalized.contains(item)) {
      normalized.add(item);
    }
  }
  return normalized.take(8).toList(growable: false);
}

String composeMicroMentorSystemPrompt({
  required String name,
  required Map<String, dynamic> promptConfig,
}) {
  return '''
You are ${_boundedMicroMentorText(name, microMentorNameMaxLength)}, a domain-specific micro AI mentor.
Use the following user-authored configuration as your operating contract:
${jsonEncode(promptConfig)}

Create exactly one concrete proposal that helps the user make progress.
The proposal may be a task or a scheduled activity. Explain the reason briefly.
Never claim that you executed, scheduled, or approved anything. The user must be
able to edit, accept, or reject every proposal and always makes the final choice.
'''
      .trim();
}

String _boundedMicroMentorText(String value, int maxLength) {
  final normalized = value.trim();
  return normalized.length <= maxLength
      ? normalized
      : normalized.substring(0, maxLength);
}
