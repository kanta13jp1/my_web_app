import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/micro_mentor.dart';
import 'edge_llm_playground_service.dart';

abstract class MicroMentorServiceContract {
  Future<MicroMentorDashboardSnapshot> loadDashboard();

  Future<MicroMentor> saveMentor({
    String? mentorId,
    required MicroMentorDraft draft,
  });

  Future<void> setMentorEnabled(String mentorId, bool enabled);

  Future<MicroMentorGenerationResult> generateProposals(String focus);

  Future<MicroMentorProposal> updateProposal({
    required String proposalId,
    required String title,
    required String description,
    required MicroMentorProposalType type,
    DateTime? scheduledFor,
  });

  Future<void> setProposalStatus(
    String proposalId,
    MicroMentorProposalStatus status,
  );
}

typedef MicroMentorLlmInvoker = Future<Map<String, dynamic>> Function({
  required MicroMentor mentor,
  required String userPrompt,
  required String systemPrompt,
  required Map<String, dynamic> context,
});

class MicroMentorGenerationException implements Exception {
  final String message;

  const MicroMentorGenerationException(this.message);

  @override
  String toString() => message;
}

class MicroMentorProposalGenerator {
  final EdgeLlmPlaygroundService _llm;
  final MicroMentorLlmInvoker? _invoker;
  final int _maxConcurrentMentors;

  const MicroMentorProposalGenerator({
    EdgeLlmPlaygroundService llm = const EdgeLlmPlaygroundService(),
    MicroMentorLlmInvoker? invoker,
    int maxConcurrentMentors = 4,
  })  : _llm = llm,
        _invoker = invoker,
        _maxConcurrentMentors = maxConcurrentMentors,
        assert(maxConcurrentMentors > 0);

  Future<GeneratedMicroMentorProposalBatch> generate({
    required List<MicroMentor> mentors,
    required String focus,
  }) async {
    final normalizedFocus = focus.trim();
    if (normalizedFocus.isEmpty) {
      throw const MicroMentorGenerationException('相談したいテーマを入力してください。');
    }
    if (normalizedFocus.length > microMentorFocusMaxLength) {
      throw const MicroMentorGenerationException(
        '相談テーマは1000文字以内で入力してください。',
      );
    }

    final activeMentors = mentors.where((mentor) => mentor.enabled).toList();
    if (activeMentors.isEmpty) {
      throw const MicroMentorGenerationException('有効なメンターを1人以上登録してください。');
    }

    final attempts = List<_GenerationAttempt?>.filled(
      activeMentors.length,
      null,
    );
    var nextMentorIndex = 0;

    Future<void> runWorker() async {
      while (nextMentorIndex < activeMentors.length) {
        final mentorIndex = nextMentorIndex++;
        attempts[mentorIndex] = await _generateOne(
          mentor: activeMentors[mentorIndex],
          focus: normalizedFocus,
        );
      }
    }

    final workerCount = activeMentors.length < _maxConcurrentMentors
        ? activeMentors.length
        : _maxConcurrentMentors;
    await Future.wait(
      List<Future<void>>.generate(workerCount, (_) => runWorker()),
    );
    final completedAttempts = attempts.whereType<_GenerationAttempt>().toList();
    final proposals = completedAttempts
        .map((attempt) => attempt.proposal)
        .whereType<GeneratedMicroMentorProposal>()
        .toList(growable: false);
    final failedCount = completedAttempts.length - proposals.length;
    if (proposals.isEmpty) {
      throw const MicroMentorGenerationException(
        '提案を生成できませんでした。時間をおいて再試行してください。',
      );
    }
    return GeneratedMicroMentorProposalBatch(
      proposals: proposals,
      failedMentorCount: failedCount,
    );
  }

  Future<_GenerationAttempt> _generateOne({
    required MicroMentor mentor,
    required String focus,
  }) async {
    final userPrompt = '''
テーマ: $focus

次のJSON形式で1件だけ提案してください。
{"proposal_type":"task または schedule","title":"短い見出し","description":"ユーザーが編集できる具体的な内容","rationale":"この提案の理由","scheduled_for":"ISO 8601日時またはnull"}
'''
        .trim();
    try {
      final invoker = _invoker;
      final payload = invoker != null
          ? await invoker(
              mentor: mentor,
              userPrompt: userPrompt,
              systemPrompt: mentor.systemPrompt,
              context: mentor.promptConfig,
            )
          : await _invokeEdgeLlm(mentor: mentor, userPrompt: userPrompt);
      return _GenerationAttempt(
        proposal: _parseProposal(
          mentor: mentor,
          focus: focus,
          payload: payload,
        ),
      );
    } catch (_) {
      return const _GenerationAttempt();
    }
  }

  Future<Map<String, dynamic>> _invokeEdgeLlm({
    required MicroMentor mentor,
    required String userPrompt,
  }) async {
    final response = await _llm.invoke(
      userPrompt: userPrompt,
      systemPrompt: mentor.systemPrompt,
      responseFormat: 'json',
      contextDraft: jsonEncode(mentor.promptConfig),
      sessionId: 'micro-mentor-${mentor.id}',
    );
    final parsed = response.parsedJson;
    if (parsed != null) {
      return parsed;
    }
    final decoded = jsonDecode(response.text);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  GeneratedMicroMentorProposal _parseProposal({
    required MicroMentor mentor,
    required String focus,
    required Map<String, dynamic> payload,
  }) {
    final title = _boundedText(payload['title'], 120);
    final description = _boundedText(payload['description'], 2000);
    final rationale = _boundedText(payload['rationale'], 1000);
    if (title.isEmpty || description.isEmpty || rationale.isEmpty) {
      throw const FormatException('Proposal fields are incomplete.');
    }
    final type = MicroMentorProposalType.fromValue(payload['proposal_type']);
    final rawScheduledFor = payload['scheduled_for']?.toString().trim();
    final parsedScheduledFor = rawScheduledFor == null ||
            rawScheduledFor.isEmpty ||
            rawScheduledFor == 'null'
        ? null
        : DateTime.tryParse(rawScheduledFor);
    final scheduledFor =
        type == MicroMentorProposalType.schedule ? parsedScheduledFor : null;
    return GeneratedMicroMentorProposal(
      mentorId: mentor.id,
      focus: focus,
      type: type,
      title: title,
      description: description,
      rationale: rationale,
      scheduledFor: scheduledFor,
      originalPayload: Map<String, dynamic>.from(payload),
    );
  }

  String _boundedText(Object? value, int maxLength) {
    final text = value?.toString().trim() ?? '';
    return text.length <= maxLength ? text : text.substring(0, maxLength);
  }
}

class MicroMentorService implements MicroMentorServiceContract {
  static const _profileType = 'micro_mentor';
  static const _proposalTable = 'micro_mentor_proposals';

  final SupabaseClient _supabase;
  final MicroMentorProposalGenerator _generator;

  MicroMentorService({
    SupabaseClient? supabase,
    MicroMentorProposalGenerator generator =
        const MicroMentorProposalGenerator(),
  })  : _supabase = supabase ?? Supabase.instance.client,
        _generator = generator;

  @override
  Future<MicroMentorDashboardSnapshot> loadDashboard() async {
    final userId = _requireUserId();
    final dynamic mentorRows = await _supabase
        .from('agents')
        .select()
        .eq('user_id', userId)
        .eq('metadata->>profile_type', _profileType)
        .order('created_at', ascending: true);
    final dynamic proposalRows = await _supabase
        .from(_proposalTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return MicroMentorDashboardSnapshot(
      mentors: (mentorRows as List)
          .whereType<Map>()
          .map(
            (row) => MicroMentor.fromAgentJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
      proposals: (proposalRows as List)
          .whereType<Map>()
          .map(
            (row) =>
                MicroMentorProposal.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<MicroMentor> saveMentor({
    String? mentorId,
    required MicroMentorDraft draft,
  }) async {
    final userId = _requireUserId();
    _validateDraft(draft);
    final promptConfig = draft.promptConfig;
    final payload = <String, dynamic>{
      'display_name': draft.name.trim(),
      'role_title': draft.role.trim(),
      'department': draft.domain.trim(),
      'identity_prompt': composeMicroMentorSystemPrompt(
        name: draft.name,
        promptConfig: promptConfig,
      ),
      'permissions_summary': '提案のみを行い、予定やタスクの確定・実行はユーザーが判断する。',
      'metadata': <String, dynamic>{
        'profile_type': _profileType,
        'tone': draft.tone.trim(),
        'values': normalizeMicroMentorValues(draft.values),
        'prompt_config': promptConfig,
      },
    };

    final dynamic row;
    if (mentorId == null) {
      row = await _supabase
          .from('agents')
          .insert(<String, dynamic>{
            ...payload,
            'user_id': userId,
            'slug': 'micro-mentor-${DateTime.now().microsecondsSinceEpoch}',
            'status': 'active',
          })
          .select()
          .single();
    } else {
      row = await _supabase
          .from('agents')
          .update(payload)
          .eq('id', mentorId)
          .eq('user_id', userId)
          .eq('metadata->>profile_type', _profileType)
          .select()
          .single();
    }
    return MicroMentor.fromAgentJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> setMentorEnabled(String mentorId, bool enabled) async {
    final userId = _requireUserId();
    await _supabase
        .from('agents')
        .update(<String, dynamic>{'status': enabled ? 'active' : 'paused'})
        .eq('id', mentorId)
        .eq('user_id', userId)
        .eq('metadata->>profile_type', _profileType);
  }

  @override
  Future<MicroMentorGenerationResult> generateProposals(String focus) async {
    final userId = _requireUserId();
    final dashboard = await loadDashboard();
    final batch = await _generator.generate(
      mentors: dashboard.mentors,
      focus: focus,
    );
    final rows = batch.proposals
        .map(
          (proposal) => <String, dynamic>{
            'user_id': userId,
            'mentor_id': proposal.mentorId,
            'focus': proposal.focus,
            'proposal_type': proposal.type.value,
            'title': proposal.title,
            'description': proposal.description,
            'rationale': proposal.rationale,
            'scheduled_for': proposal.scheduledFor?.toIso8601String(),
            'original_payload': proposal.originalPayload,
          },
        )
        .toList(growable: false);
    final dynamic inserted =
        await _supabase.from(_proposalTable).insert(rows).select();
    final proposals = (inserted as List)
        .whereType<Map>()
        .map(
          (row) => MicroMentorProposal.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    return MicroMentorGenerationResult(
      proposals: proposals,
      failedMentorCount: batch.failedMentorCount,
    );
  }

  @override
  Future<MicroMentorProposal> updateProposal({
    required String proposalId,
    required String title,
    required String description,
    required MicroMentorProposalType type,
    DateTime? scheduledFor,
  }) async {
    final userId = _requireUserId();
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty || normalizedDescription.isEmpty) {
      throw ArgumentError('提案の見出しと内容は必須です。');
    }
    if (normalizedTitle.length > microMentorProposalTitleMaxLength ||
        normalizedDescription.length >
            microMentorProposalDescriptionMaxLength) {
      throw ArgumentError('提案の見出しは120文字、内容は2000文字以内で入力してください。');
    }
    final dynamic row = await _supabase
        .from(_proposalTable)
        .update(<String, dynamic>{
          'title': normalizedTitle,
          'description': normalizedDescription,
          'proposal_type': type.value,
          'scheduled_for': type == MicroMentorProposalType.schedule
              ? scheduledFor?.toIso8601String()
              : null,
        })
        .eq('id', proposalId)
        .eq('user_id', userId)
        .select()
        .single();
    return MicroMentorProposal.fromJson(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<void> setProposalStatus(
    String proposalId,
    MicroMentorProposalStatus status,
  ) async {
    final userId = _requireUserId();
    await _supabase
        .from(_proposalTable)
        .update(<String, dynamic>{'status': status.value})
        .eq('id', proposalId)
        .eq('user_id', userId);
  }

  void _validateDraft(MicroMentorDraft draft) {
    final values = draft.values.map((value) => value.trim()).toList();
    if (draft.name.trim().isEmpty ||
        draft.domain.trim().isEmpty ||
        draft.role.trim().isEmpty ||
        draft.tone.trim().isEmpty ||
        normalizeMicroMentorValues(values).isEmpty) {
      throw ArgumentError('名前、領域、役割、口調、大切な価値観を入力してください。');
    }
    if (draft.name.trim().length > microMentorNameMaxLength ||
        draft.domain.trim().length > microMentorDomainMaxLength ||
        draft.role.trim().length > microMentorRoleMaxLength ||
        draft.tone.trim().length > microMentorToneMaxLength ||
        values.any((value) => value.length > microMentorValueMaxLength)) {
      throw ArgumentError('メンター設定が入力可能な文字数を超えています。');
    }
  }

  String _requireUserId() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('ログインが必要です。');
    }
    return userId;
  }
}

class _GenerationAttempt {
  final GeneratedMicroMentorProposal? proposal;

  const _GenerationAttempt({this.proposal});
}

class GeneratedMicroMentorProposalBatch {
  final List<GeneratedMicroMentorProposal> proposals;
  final int failedMentorCount;

  const GeneratedMicroMentorProposalBatch({
    required this.proposals,
    required this.failedMentorCount,
  });
}
