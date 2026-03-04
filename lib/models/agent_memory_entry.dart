class AgentMemoryEntry {
  final String id;
  final String userId;
  final String agentId;
  final String memoryLayer;
  final String content;
  final String source;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  AgentMemoryEntry({
    required this.id,
    required this.userId,
    required this.agentId,
    required this.memoryLayer,
    required this.content,
    required this.source,
    required this.createdAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AgentMemoryEntry.fromJson(Map<String, dynamic> json) {
    return AgentMemoryEntry(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      agentId: json['agent_id']?.toString() ?? '',
      memoryLayer: json['memory_layer']?.toString() ?? 'episode',
      content: json['content']?.toString() ?? '',
      source: json['source']?.toString() ?? 'manual_note',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const <String, dynamic>{},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'agent_id': agentId,
      'memory_layer': memoryLayer,
      'content': content,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }
}
