class AgentMessage {
  final String id;
  final String userId;
  final String fromAgentId;
  final String toAgentId;
  final String? linkedTaskId;
  final String? conversationId;
  final String messageKind;
  final String summary;
  final Map<String, dynamic> payload;
  final String status;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  AgentMessage({
    required this.id,
    required this.userId,
    required this.fromAgentId,
    required this.toAgentId,
    required this.messageKind,
    required this.summary,
    required this.payload,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.linkedTaskId,
    this.conversationId,
    this.acknowledgedAt,
    this.resolvedAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) {
    return AgentMessage(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fromAgentId: json['from_agent_id']?.toString() ?? '',
      toAgentId: json['to_agent_id']?.toString() ?? '',
      linkedTaskId: json['linked_task_id']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      messageKind: json['message_kind']?.toString() ?? 'directive',
      summary: json['summary']?.toString() ?? '',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const <String, dynamic>{},
      status: json['status']?.toString() ?? 'sent',
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'].toString())
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'from_agent_id': fromAgentId,
      'to_agent_id': toAgentId,
      'linked_task_id': linkedTaskId,
      'conversation_id': conversationId,
      'message_kind': messageKind,
      'summary': summary,
      'payload': payload,
      'status': status,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isSent => status == 'sent';
  bool get isAcknowledged => status == 'acknowledged';
  bool get isResolved => status == 'resolved';
}
