/// 仮想AI組織のエージェントモデル。
///
/// `ai-hub` の `org.get` (`{success, org: {agents: [hub_data 行],
/// departments: [部署名]}}`) を解析する純データモデル。実フィールドは
/// `metadata.name` / `metadata.role` / `metadata.department` /
/// `metadata.personality` / `metadata.status`。旧実装は flat キー
/// (`row['name']` 等) を読んでいたため、登録済みでも全行が
/// 「Agent N / 役割なし」に化けていた。
library;

import 'hub_data_parsing.dart';

class VirtualOrgAgent {
  const VirtualOrgAgent({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.personality,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String role;
  final String department;

  /// 性格メモ。EF 既定値は `{}` (Map) なので文字列以外は空文字に落とす。
  final String personality;
  final String status;
  final String createdAt;

  /// 一覧の副題: '部署 • 役割' (片方だけならその値)。
  String get affiliationLabel =>
      [department, role].where((v) => v.isNotEmpty).join(' • ');

  factory VirtualOrgAgent.fromRow(Map<String, dynamic> raw) {
    final personality = hubField(raw, 'personality');
    return VirtualOrgAgent(
      id: hubString(raw['id']),
      name: hubString(hubField(raw, 'name')),
      role: hubString(hubField(raw, 'role')),
      department: hubString(hubField(raw, 'department')),
      personality: personality is String ? personality.trim() : '',
      status: hubString(hubField(raw, 'status')),
      createdAt: hubString(raw['created_at']),
    );
  }
}

/// `org.get` レスポンス全体。
class VirtualOrganization {
  const VirtualOrganization({required this.departments, required this.agents});

  static const VirtualOrganization empty = VirtualOrganization(
    departments: <String>[],
    agents: <VirtualOrgAgent>[],
  );

  final List<String> departments;
  final List<VirtualOrgAgent> agents;

  /// 部署に所属するエージェント数 (実データから数える — 固定値にしない)。
  int agentCountOf(String department) =>
      agents.where((a) => a.department == department).length;

  factory VirtualOrganization.fromResponse(dynamic data) {
    final org = data is Map ? data['org'] : null;
    if (org is! Map) return empty;
    final rawDepartments = org['departments'];
    final departments = <String>[];
    if (rawDepartments is List) {
      for (final d in rawDepartments) {
        final name = hubString(d is Map ? d['name'] : d);
        if (name.isNotEmpty) departments.add(name);
      }
    }
    return VirtualOrganization(
      departments: departments,
      agents: hubRowsFromResponse(
        org,
        'agents',
      ).map(VirtualOrgAgent.fromRow).toList(),
    );
  }
}

/// `agent.create` へ送る入力。EF 側は無検証で hub_data に保存するため、
/// 必須項目と長さはここで弾く (名無しの行を一覧に残さない)。
class VirtualOrgAgentDraft {
  const VirtualOrgAgentDraft({
    required this.name,
    required this.department,
    this.role = '',
    this.personality = '',
  });

  static const int maxNameLength = 40;
  static const int maxRoleLength = 60;
  static const int maxPersonalityLength = 200;

  final String name;
  final String department;
  final String role;
  final String personality;

  /// 入力エラー文言。問題なければ null。
  String? validate() {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return 'エージェント名を入力してください';
    if (trimmedName.length > maxNameLength) {
      return 'エージェント名は$maxNameLength文字以内で入力してください';
    }
    if (department.trim().isEmpty) return '部署を選択してください';
    if (role.trim().length > maxRoleLength) {
      return '役割は$maxRoleLength文字以内で入力してください';
    }
    if (personality.trim().length > maxPersonalityLength) {
      return '性格メモは$maxPersonalityLength文字以内で入力してください';
    }
    return null;
  }

  /// `ai-hub` へ渡す body。役割が空なら EF 既定値 (`assistant`) に任せる。
  Map<String, dynamic> toRequestBody() {
    final trimmedRole = role.trim();
    return {
      'action': 'agent.create',
      'name': name.trim(),
      'department': department.trim(),
      if (trimmedRole.isNotEmpty) 'role': trimmedRole,
      'personality': personality.trim(),
    };
  }
}
