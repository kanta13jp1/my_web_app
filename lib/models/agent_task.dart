class AgentTask {
  final String id;
  final String userId;
  final String supervisorAgentId;
  final String assigneeAgentId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String taskType;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic> metadata;

  AgentTask({
    required this.id,
    required this.userId,
    required this.supervisorAgentId,
    required this.assigneeAgentId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.taskType,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    return AgentTask(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      supervisorAgentId: json['supervisor_agent_id']?.toString() ?? '',
      assigneeAgentId: json['assignee_agent_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'queued',
      priority: json['priority']?.toString() ?? 'normal',
      taskType: json['task_type']?.toString() ?? 'delegated_action',
      source: json['source']?.toString() ?? 'manual_delegate',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'supervisor_agent_id': supervisorAgentId,
      'assignee_agent_id': assigneeAgentId,
      'title': title,
      'description': description,
      'status': status,
      'priority': priority,
      'task_type': taskType,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isQueued => status == 'queued';
  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> get clarityMetadata {
    final clarity = metadata['clarity'];
    return clarity is Map
        ? Map<String, dynamic>.from(clarity)
        : const <String, dynamic>{};
  }

  int? get clarityScore {
    final value = clarityMetadata['score'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  int get clarityThreshold {
    final value = clarityMetadata['threshold'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 6;
  }

  String get clarityStatus => clarityMetadata['status']?.toString() ?? '';

  bool get needsClarification {
    final score = clarityScore;
    return score != null &&
        clarityStatus != 'clarified' &&
        score <= clarityThreshold;
  }
}
