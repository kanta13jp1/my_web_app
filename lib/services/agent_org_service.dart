import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../models/agent_memory_entry.dart';
import '../models/agent_profile.dart';
import '../models/agent_task.dart';

class AgentOrgSnapshot {
  final List<AgentProfile> agents;
  final List<AgentTask> tasks;
  final List<AgentMemoryEntry> recentMemories;
  final Map<String, int> openTaskCountsByAgent;
  final Map<String, int> memoryCountsByAgent;

  const AgentOrgSnapshot({
    required this.agents,
    required this.tasks,
    required this.recentMemories,
    required this.openTaskCountsByAgent,
    required this.memoryCountsByAgent,
  });

  const AgentOrgSnapshot.empty()
      : agents = const <AgentProfile>[],
        tasks = const <AgentTask>[],
        recentMemories = const <AgentMemoryEntry>[],
        openTaskCountsByAgent = const <String, int>{},
        memoryCountsByAgent = const <String, int>{};
}

class AgentOrgService {
  final SupabaseClient _supabase;

  AgentOrgService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? supabase;

  static const List<AgentBlueprint> defaultExecutiveBlueprints = [
    AgentBlueprint(
      slug: 'ceo',
      displayName: 'CEO',
      roleTitle: 'Chief Executive Officer',
      department: '経営',
      identityPrompt: 'あなたは自分株式会社のCEOです。全社方針を決め、最優先課題を定義し、各役員に委任します。',
      permissionsSummary: '全社方針の決定 / 役員への委任 / 優先順位の最終判断',
    ),
    AgentBlueprint(
      slug: 'cfo',
      displayName: 'CFO',
      roleTitle: 'Chief Financial Officer',
      department: '財務',
      supervisorSlug: 'ceo',
      identityPrompt: 'あなたは財務責任者です。資産、支出、投資判断、固定費最適化を担当します。',
      permissionsSummary: '資金繰り / 固定費レビュー / 支出最適化 / 財務報告',
    ),
    AgentBlueprint(
      slug: 'cmo',
      displayName: 'CMO',
      roleTitle: 'Chief Marketing Officer',
      department: '広報',
      supervisorSlug: 'ceo',
      identityPrompt: 'あなたは広報責任者です。流入、登録率、シェア導線、認知拡大を担当します。',
      permissionsSummary: '流入改善 / LP訴求改善 / SNSシェア / 登録導線改善',
    ),
    AgentBlueprint(
      slug: 'cho',
      displayName: 'CHO',
      roleTitle: 'Chief Health Officer',
      department: '健康',
      supervisorSlug: 'ceo',
      identityPrompt: 'あなたは健康責任者です。継続、生活リズム、体調管理、回復計画を担当します。',
      permissionsSummary: '健康記録 / 休息計画 / 生活習慣レビュー',
    ),
    AgentBlueprint(
      slug: 'chro',
      displayName: 'CHRO',
      roleTitle: 'Chief Human Resources Officer',
      department: '人事',
      supervisorSlug: 'ceo',
      identityPrompt: 'あなたは人事責任者です。評価、報酬、制度、習慣設計を担当します。',
      permissionsSummary: '評価整理 / 報酬設計 / ルール整備 / 継続支援',
    ),
  ];

  Future<AgentOrgSnapshot> loadSnapshot() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const AgentOrgSnapshot.empty();
    }

    final agents = await ensureExecutiveAgents();
    if (agents.isEmpty) {
      return const AgentOrgSnapshot.empty();
    }

    final dynamic taskRows = await _supabase
        .from('agent_tasks')
        .select()
        .eq('user_id', userId)
        .neq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(20);
    final tasks = (taskRows as List)
        .whereType<Map>()
        .map((row) => AgentTask.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    final dynamic memoryRows = await _supabase
        .from('agent_memories')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(40);
    final memories = (memoryRows as List)
        .whereType<Map>()
        .map(
          (row) => AgentMemoryEntry.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();

    final taskCounts = <String, int>{};
    for (final task in tasks) {
      taskCounts[task.assigneeAgentId] =
          (taskCounts[task.assigneeAgentId] ?? 0) + 1;
    }

    final memoryCounts = <String, int>{};
    for (final memory in memories) {
      memoryCounts[memory.agentId] = (memoryCounts[memory.agentId] ?? 0) + 1;
    }

    return AgentOrgSnapshot(
      agents: agents,
      tasks: tasks,
      recentMemories: memories,
      openTaskCountsByAgent: taskCounts,
      memoryCountsByAgent: memoryCounts,
    );
  }

  Future<List<AgentProfile>> ensureExecutiveAgents() async {
    final userId = _currentUserId;
    if (userId == null) {
      return <AgentProfile>[];
    }

    final existing = await _loadAgentsForUser(userId);
    final existingBySlug = {
      for (final agent in existing) agent.slug: agent,
    };

    final missing = defaultExecutiveBlueprints
        .where((blueprint) => !existingBySlug.containsKey(blueprint.slug))
        .map((blueprint) => blueprint.toInsertRow(userId))
        .toList();

    if (missing.isNotEmpty) {
      await _supabase.from('agents').upsert(
            missing,
            onConflict: 'user_id,slug',
          );
    }

    final refreshed = await _loadAgentsForUser(userId);
    final refreshedBySlug = {
      for (final agent in refreshed) agent.slug: agent,
    };
    final ceoId = refreshedBySlug['ceo']?.id;

    if (ceoId != null) {
      for (final blueprint in defaultExecutiveBlueprints) {
        if (blueprint.supervisorSlug == null) {
          continue;
        }
        final agent = refreshedBySlug[blueprint.slug];
        if (agent == null || agent.supervisorAgentId == ceoId) {
          continue;
        }
        await _supabase
            .from('agents')
            .update({'supervisor_agent_id': ceoId})
            .eq('id', agent.id)
            .eq('user_id', userId);
      }
    }

    return _loadAgentsForUser(userId);
  }

  Future<void> delegateTask({
    required String supervisorAgentId,
    required String assigneeAgentId,
    required String title,
    String description = '',
    String priority = 'high',
  }) async {
    final userId = _requireUserId();
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Task title is required.');
    }

    await _supabase.from('agent_tasks').insert({
      'user_id': userId,
      'supervisor_agent_id': supervisorAgentId,
      'assignee_agent_id': assigneeAgentId,
      'title': normalizedTitle,
      'description': normalizedDescription,
      'status': 'queued',
      'priority': priority,
      'task_type': 'delegated_action',
      'source': 'manual_delegate',
      'metadata': <String, dynamic>{
        'delegated_at': DateTime.now().toIso8601String(),
      },
    });

    await _supabase
        .from('agents')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', assigneeAgentId)
        .eq('user_id', userId);

    await _supabase.from('agent_memories').insert([
      {
        'user_id': userId,
        'agent_id': supervisorAgentId,
        'memory_layer': 'episode',
        'content': '委任: $normalizedTitle',
        'source': 'delegate_task',
      },
      {
        'user_id': userId,
        'agent_id': assigneeAgentId,
        'memory_layer': 'handoff',
        'content': normalizedDescription.isEmpty
            ? 'CEOからの新規委任: $normalizedTitle'
            : 'CEOからの新規委任: $normalizedTitle\n$normalizedDescription',
        'source': 'delegate_task',
      },
    ]);
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
  }) async {
    final userId = _requireUserId();
    await _supabase
        .from('agent_tasks')
        .update({
          'status': status,
          'completed_at':
              status == 'completed' ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', taskId)
        .eq('user_id', userId);
  }

  Future<void> appendMemoryEntry({
    required String agentId,
    required String content,
    String memoryLayer = 'episode',
    String source = 'manual_note',
  }) async {
    final userId = _requireUserId();
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError('Memory content is required.');
    }
    await _supabase.from('agent_memories').insert({
      'user_id': userId,
      'agent_id': agentId,
      'memory_layer': memoryLayer,
      'content': normalizedContent,
      'source': source,
    });
    await _supabase
        .from('agents')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', agentId)
        .eq('user_id', userId);
  }

  Future<void> setAgentStatus({
    required String agentId,
    required bool enabled,
  }) async {
    final userId = _requireUserId();
    await _supabase
        .from('agents')
        .update({'status': enabled ? 'active' : 'paused'})
        .eq('id', agentId)
        .eq('user_id', userId);
  }

  Future<List<AgentProfile>> _loadAgentsForUser(String userId) async {
    final dynamic rows = await _supabase
        .from('agents')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    final unsorted = (rows as List)
        .whereType<Map>()
        .map((row) => AgentProfile.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final orderMap = <String, int>{
      for (var i = 0; i < defaultExecutiveBlueprints.length; i++)
        defaultExecutiveBlueprints[i].slug: i,
    };
    unsorted.sort(
      (a, b) => (orderMap[a.slug] ?? 999).compareTo(orderMap[b.slug] ?? 999),
    );
    return unsorted;
  }

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _requireUserId() {
    final userId = _currentUserId;
    if (userId == null) {
      throw StateError('Authenticated user is required.');
    }
    return userId;
  }
}

class AgentBlueprint {
  final String slug;
  final String displayName;
  final String roleTitle;
  final String department;
  final String identityPrompt;
  final String permissionsSummary;
  final String? supervisorSlug;

  const AgentBlueprint({
    required this.slug,
    required this.displayName,
    required this.roleTitle,
    required this.department,
    required this.identityPrompt,
    required this.permissionsSummary,
    this.supervisorSlug,
  });

  Map<String, dynamic> toInsertRow(String userId) {
    return {
      'user_id': userId,
      'slug': slug,
      'display_name': displayName,
      'role_title': roleTitle,
      'department': department,
      'status': 'active',
      'identity_prompt': identityPrompt,
      'permissions_summary': permissionsSummary,
      'metadata': <String, dynamic>{
        'source': 'agent_registry_seed',
      },
    };
  }
}
