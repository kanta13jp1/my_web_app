class AgentRelationship {
  final String id;
  final String userId;
  final String fromAgentId;
  final String toAgentId;
  final String relationshipType;
  final String communicationProtocol;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  AgentRelationship({
    required this.id,
    required this.userId,
    required this.fromAgentId,
    required this.toAgentId,
    required this.relationshipType,
    required this.communicationProtocol,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AgentRelationship.fromJson(Map<String, dynamic> json) {
    return AgentRelationship(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fromAgentId: json['from_agent_id']?.toString() ?? '',
      toAgentId: json['to_agent_id']?.toString() ?? '',
      relationshipType: json['relationship_type']?.toString() ?? 'supervises',
      communicationProtocol:
          json['communication_protocol']?.toString() ?? 'structured_brief',
      status: json['status']?.toString() ?? 'active',
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
      'relationship_type': relationshipType,
      'communication_protocol': communicationProtocol,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isActive => status == 'active';
}
