class AgentProfile {
  final String id;
  final String userId;
  final String slug;
  final String displayName;
  final String roleTitle;
  final String department;
  final String status;
  final String identityPrompt;
  final String permissionsSummary;
  final String? supervisorAgentId;
  final DateTime? lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  AgentProfile({
    required this.id,
    required this.userId,
    required this.slug,
    required this.displayName,
    required this.roleTitle,
    required this.department,
    required this.status,
    required this.identityPrompt,
    required this.permissionsSummary,
    required this.createdAt,
    required this.updatedAt,
    this.supervisorAgentId,
    this.lastActiveAt,
    this.metadata = const <String, dynamic>{},
  });

  factory AgentProfile.fromJson(Map<String, dynamic> json) {
    return AgentProfile(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      roleTitle: json['role_title']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      identityPrompt: json['identity_prompt']?.toString() ?? '',
      permissionsSummary: json['permissions_summary']?.toString() ?? '',
      supervisorAgentId: json['supervisor_agent_id']?.toString(),
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString())
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
    return {
      'id': id,
      'user_id': userId,
      'slug': slug,
      'display_name': displayName,
      'role_title': roleTitle,
      'department': department,
      'status': status,
      'identity_prompt': identityPrompt,
      'permissions_summary': permissionsSummary,
      'supervisor_agent_id': supervisorAgentId,
      'last_active_at': lastActiveAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
}
