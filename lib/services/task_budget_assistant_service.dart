import 'package:supabase_flutter/supabase_flutter.dart';

typedef TaskBudgetAssistantInvoker = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);

class TaskBudgetAssistantDocument {
  const TaskBudgetAssistantDocument({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  Map<String, dynamic> toJson() => {'title': title, 'content': content};
}

class TaskBudgetAssistantStep {
  const TaskBudgetAssistantStep({
    required this.stepIndex,
    required this.title,
    required this.status,
    required this.inputTokens,
    required this.outputTokens,
    required this.notes,
  });

  final int stepIndex;
  final String title;
  final String status;
  final int inputTokens;
  final int outputTokens;
  final String notes;

  int get totalTokens => inputTokens + outputTokens;

  factory TaskBudgetAssistantStep.fromMap(Map<String, dynamic> map) {
    return TaskBudgetAssistantStep(
      stepIndex: _asInt(map['step_index']),
      title: (map['title'] ?? '').toString(),
      status: (map['status'] ?? '').toString(),
      inputTokens: _asInt(map['input_tokens']),
      outputTokens: _asInt(map['output_tokens']),
      notes: (map['notes'] ?? '').toString(),
    );
  }
}

class TaskBudgetAssistantJob {
  const TaskBudgetAssistantJob({
    required this.id,
    required this.title,
    required this.objective,
    required this.budgetTokens,
    required this.consumedTokens,
    required this.effort,
    required this.status,
    required this.progressPercent,
    required this.documentCount,
    required this.summary,
    required this.artifact,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;
  final String title;
  final String objective;
  final int budgetTokens;
  final int consumedTokens;
  final String effort;
  final String status;
  final int progressPercent;
  final int documentCount;
  final String summary;
  final Map<String, dynamic> artifact;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  double get usageRatio =>
      budgetTokens <= 0 ? 0 : (consumedTokens / budgetTokens).clamp(0, 1);

  bool get stoppedSafely => status == 'budget_safed';
  bool get isFinished =>
      status == 'completed' || status == 'budget_safed' || status == 'failed';

  factory TaskBudgetAssistantJob.fromMap(Map<String, dynamic> map) {
    final artifact = map['artifact'];
    return TaskBudgetAssistantJob(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      objective: (map['objective'] ?? '').toString(),
      budgetTokens: _asInt(map['budget_tokens']),
      consumedTokens: _asInt(map['consumed_tokens']),
      effort: (map['effort'] ?? 'medium').toString(),
      status: (map['status'] ?? 'queued').toString(),
      progressPercent: _asInt(map['progress_percent']),
      documentCount: _asInt(map['document_count']),
      summary: (map['summary'] ?? '').toString(),
      artifact: artifact is Map<String, dynamic>
          ? artifact
          : artifact is Map
              ? Map<String, dynamic>.from(artifact)
              : <String, dynamic>{},
      createdAt: _asDate(map['created_at']),
      updatedAt: _asDate(map['updated_at']),
      completedAt: _asDate(map['completed_at']),
    );
  }
}

class TaskBudgetAssistantDetail {
  const TaskBudgetAssistantDetail({required this.job, required this.steps});

  final TaskBudgetAssistantJob job;
  final List<TaskBudgetAssistantStep> steps;
}

class TaskBudgetAssistantService {
  const TaskBudgetAssistantService({
    SupabaseClient? supabaseClient,
    TaskBudgetAssistantInvoker? invoker,
  })  : _supabaseClient = supabaseClient,
        _invoker = invoker;

  final SupabaseClient? _supabaseClient;
  final TaskBudgetAssistantInvoker? _invoker;

  Future<List<TaskBudgetAssistantJob>> listJobs({int limit = 20}) async {
    final data = await _invoke({
      'action': 'task_budget_assistant.job.list',
      'limit': limit,
    });
    _throwIfError(data);
    return ((data['jobs'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              TaskBudgetAssistantJob.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<TaskBudgetAssistantDetail> createJob({
    required String title,
    required String objective,
    required int budgetTokens,
    required String effort,
    required List<TaskBudgetAssistantDocument> documents,
  }) async {
    final data = await _invoke({
      'action': 'task_budget_assistant.job.create',
      'title': title,
      'objective': objective,
      'budget_tokens': budgetTokens,
      'effort': effort,
      'documents': documents.map((doc) => doc.toJson()).toList(),
    });
    _throwIfError(data);
    return _detailFromResponse(data);
  }

  Future<TaskBudgetAssistantDetail> loadJob(String id) async {
    final data = await _invoke({
      'action': 'task_budget_assistant.job.get',
      'id': id,
    });
    _throwIfError(data);
    return _detailFromResponse(data);
  }

  Future<TaskBudgetAssistantJob?> cancelJob(String id) async {
    final data = await _invoke({
      'action': 'task_budget_assistant.job.cancel',
      'id': id,
    });
    _throwIfError(data);
    final job = data['job'];
    if (job is Map<String, dynamic>) return TaskBudgetAssistantJob.fromMap(job);
    if (job is Map) {
      return TaskBudgetAssistantJob.fromMap(Map<String, dynamic>.from(job));
    }
    return null;
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> body) async {
    final invoker = _invoker;
    if (invoker != null) return invoker(body);
    final client = _supabaseClient ?? Supabase.instance.client;
    final response = await client.functions.invoke('admin-hub', body: body);
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'success': false, 'error': data?.toString() ?? 'empty response'};
  }
}

TaskBudgetAssistantDetail _detailFromResponse(Map<String, dynamic> data) {
  final job = data['job'];
  if (job is! Map) {
    throw StateError('admin-hub returned no job');
  }
  return TaskBudgetAssistantDetail(
    job: TaskBudgetAssistantJob.fromMap(Map<String, dynamic>.from(job)),
    steps: ((data['steps'] as List?) ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              TaskBudgetAssistantStep.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false),
  );
}

void _throwIfError(Map<String, dynamic> data) {
  if (data['success'] == true) return;
  final message =
      (data['error'] ?? data['message'] ?? 'admin-hub failed').toString();
  throw StateError(message);
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDate(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
