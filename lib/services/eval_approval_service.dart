import 'package:supabase_flutter/supabase_flutter.dart';

enum EvalApprovalDecision { approved, rejected }

class EvalApprovalOption {
  const EvalApprovalOption({
    required this.id,
    required this.label,
    required this.summary,
    this.recommended = false,
  });

  final String id;
  final String label;
  final String summary;
  final bool recommended;

  factory EvalApprovalOption.fromJson(Map<String, dynamic> json) {
    return EvalApprovalOption(
      id: _text(json['id'] ?? json['value']),
      label: _text(json['label'] ?? json['title'], fallback: 'Option'),
      summary: _text(json['summary'] ?? json['description']),
      recommended: json['recommended'] == true,
    );
  }
}

class EvalBackgroundStep {
  const EvalBackgroundStep({required this.label, required this.status});

  final String label;
  final String status;

  bool get isCompleted => status == 'completed';
  bool get isRunning => status == 'running' || status == 'in_progress';

  factory EvalBackgroundStep.fromJson(Map<String, dynamic> json) {
    return EvalBackgroundStep(
      label: _text(json['label'] ?? json['title'], fallback: 'AI work'),
      status: _text(json['status'], fallback: 'completed').toLowerCase(),
    );
  }
}

class EvalApprovalExecution {
  const EvalApprovalExecution({
    required this.status,
    required this.tasksCreated,
    required this.calendarEventsCreated,
  });

  final String status;
  final int tasksCreated;
  final int calendarEventsCreated;

  factory EvalApprovalExecution.fromJson(Map<String, dynamic> json) {
    return EvalApprovalExecution(
      status: _text(json['status'], fallback: 'completed'),
      tasksCreated: _integer(json['tasks_created']),
      calendarEventsCreated: _integer(json['calendar_events_created']),
    );
  }
}

class EvalApprovalRequest {
  const EvalApprovalRequest({
    required this.id,
    required this.title,
    required this.summary,
    required this.status,
    required this.options,
    required this.backgroundSteps,
    required this.createdAt,
    this.selectedOptionId,
    this.reviewNote = '',
    this.execution,
  });

  final String id;
  final String title;
  final String summary;
  final String status;
  final List<EvalApprovalOption> options;
  final List<EvalBackgroundStep> backgroundSteps;
  final DateTime? createdAt;
  final String? selectedOptionId;
  final String reviewNote;
  final EvalApprovalExecution? execution;

  bool get isPending => status == 'pending';

  String? get defaultOptionId {
    if (options.isEmpty) return null;
    for (final option in options) {
      if (option.recommended) return option.id;
    }
    return options.first.id;
  }

  factory EvalApprovalRequest.fromJson(Map<String, dynamic> json) {
    final preview = _map(json['preview']);
    final rawOptions = preview['options'] is List
        ? preview['options'] as List
        : const [];
    final rawSteps = preview['background_steps'] is List
        ? preview['background_steps'] as List
        : json['background_steps'] is List
        ? json['background_steps'] as List
        : const [];
    final executionMap = _map(json['execution']);
    return EvalApprovalRequest(
      id: _text(json['id']),
      title: _text(
        preview['title'] ?? json['action_label'],
        fallback: 'CEO decision',
      ),
      summary: _text(
        preview['summary'] ?? preview['description'] ?? json['action_key'],
      ),
      status: _text(json['status'], fallback: 'pending').toLowerCase(),
      options: rawOptions
          .whereType<Map>()
          .map((item) => EvalApprovalOption.fromJson(_map(item)))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      backgroundSteps: rawSteps
          .whereType<Map>()
          .map((item) => EvalBackgroundStep.fromJson(_map(item)))
          .toList(growable: false),
      createdAt: DateTime.tryParse(_text(json['created_at'])),
      selectedOptionId: _text(json['selected_option_id']).isEmpty
          ? null
          : _text(json['selected_option_id']),
      reviewNote: _text(json['review_note']),
      execution: executionMap.isEmpty
          ? null
          : EvalApprovalExecution.fromJson(executionMap),
    );
  }
}

abstract class EvalApprovalGateway {
  Future<List<EvalApprovalRequest>> loadRequests();

  Future<EvalApprovalRequest> decide({
    required String requestId,
    required EvalApprovalDecision decision,
    String? selectedOptionId,
    String reason = '',
  });
}

class EvalApprovalService implements EvalApprovalGateway {
  EvalApprovalService({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  @override
  Future<List<EvalApprovalRequest>> loadRequests() async {
    final response = await _supabase.functions.invoke(
      'tools-hub',
      body: const {'action': 'saas_approval.list', 'limit': 100},
    );
    final data = _map(response.data);
    if (data['error'] != null) throw StateError(data['error'].toString());
    final raw = data['approvals'] is List
        ? data['approvals'] as List
        : const [];
    final requests = raw
        .whereType<Map>()
        .map((item) => EvalApprovalRequest.fromJson(_map(item)))
        .where((item) => item.id.isNotEmpty)
        .toList();
    requests.sort((left, right) {
      if (left.isPending != right.isPending) return left.isPending ? -1 : 1;
      final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });
    return requests;
  }

  @override
  Future<EvalApprovalRequest> decide({
    required String requestId,
    required EvalApprovalDecision decision,
    String? selectedOptionId,
    String reason = '',
  }) async {
    final response = await _supabase.functions.invoke(
      'tools-hub',
      body: buildEvalApprovalDecisionBody(
        requestId: requestId,
        decision: decision,
        selectedOptionId: selectedOptionId,
        reason: reason,
      ),
    );
    final data = _map(response.data);
    if (data['error'] != null) throw StateError(data['error'].toString());
    final approval = _map(data['approval']);
    if (approval.isEmpty) throw StateError('Approval response is missing.');
    return EvalApprovalRequest.fromJson(approval);
  }
}

Map<String, dynamic> buildEvalApprovalDecisionBody({
  required String requestId,
  required EvalApprovalDecision decision,
  String? selectedOptionId,
  String reason = '',
}) {
  final option = selectedOptionId?.trim();
  return {
    'action': 'saas_approval.decide',
    'request_id': requestId.trim(),
    'decision': decision.name,
    'review_note': reason.trim(),
    if (option != null && option.isNotEmpty) 'selected_option_id': option,
    'execute': decision == EvalApprovalDecision.approved,
  };
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) return <String, dynamic>{};
  return Map<String, dynamic>.from(value);
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
