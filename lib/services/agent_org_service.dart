import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agent_memory_entry.dart';
import '../models/agent_message.dart';
import '../models/agent_profile.dart';
import '../models/agent_relationship.dart';
import '../models/agent_task.dart';

class AgentOrgSnapshot {
  final List<AgentProfile> agents;
  final List<AgentTask> tasks;
  final List<AgentMemoryEntry> recentMemories;
  final List<AgentRelationship> relationships;
  final List<AgentMessage> recentMessages;
  final Map<String, int> openTaskCountsByAgent;
  final Map<String, int> memoryCountsByAgent;

  const AgentOrgSnapshot({
    required this.agents,
    required this.tasks,
    required this.recentMemories,
    required this.relationships,
    required this.recentMessages,
    required this.openTaskCountsByAgent,
    required this.memoryCountsByAgent,
  });

  const AgentOrgSnapshot.empty()
      : agents = const <AgentProfile>[],
        tasks = const <AgentTask>[],
        recentMemories = const <AgentMemoryEntry>[],
        relationships = const <AgentRelationship>[],
        recentMessages = const <AgentMessage>[],
        openTaskCountsByAgent = const <String, int>{},
        memoryCountsByAgent = const <String, int>{};
}

class AgentWorkspaceSnapshot {
  final AgentProfile agent;
  final List<AgentTask> tasks;
  final List<AgentMemoryEntry> recentMemories;
  final String startupPrompt;

  const AgentWorkspaceSnapshot({
    required this.agent,
    required this.tasks,
    required this.recentMemories,
    required this.startupPrompt,
  });
}

class AgentBoardChannel {
  final String id;
  final String label;
  final String description;

  const AgentBoardChannel({
    required this.id,
    required this.label,
    required this.description,
  });
}

class AgentOrgService {
  final SupabaseClient _supabase;

  AgentOrgService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  static const List<String> memoryLayerOrder = <String>[
    'state',
    'knowledge',
    'procedures',
    'skills',
    'episodes',
    'activity_log',
  ];

  static const List<AgentBoardChannel> boardChannels = <AgentBoardChannel>[
    AgentBoardChannel(
      id: 'executive',
      label: 'executive',
      description: '経営層の全社横断アップデートとアラインメント',
    ),
    AgentBoardChannel(
      id: 'finance',
      label: 'finance',
      description: '予算・収益・キャッシュフローの調整',
    ),
    AgentBoardChannel(
      id: 'marketing',
      label: 'marketing',
      description: 'キャンペーン・ローンチ・顧客獲得',
    ),
    AgentBoardChannel(
      id: 'health',
      label: 'health',
      description: '心身の健康・リスク管理・持続可能なペース',
    ),
    AgentBoardChannel(
      id: 'people',
      label: 'people',
      description: '採用・人事制度・チームサポート',
    ),
    AgentBoardChannel(
      id: 'planning',
      label: 'planning',
      description: '企画・新規事業・プロダクトロードマップ',
    ),
    AgentBoardChannel(
      id: 'engineering',
      label: 'engineering',
      description: '技術戦略・開発進捗・アーキテクチャ',
    ),
    AgentBoardChannel(
      id: 'sales',
      label: 'sales',
      description: '売上目標・営業戦略・顧客開拓',
    ),
    AgentBoardChannel(
      id: 'cs',
      label: 'cs',
      description: 'カスタマーサクセス・サポート品質・顧客満足度',
    ),
    AgentBoardChannel(
      id: 'legal',
      label: 'legal',
      description: '法務・コンプライアンス・契約管理',
    ),
    AgentBoardChannel(
      id: 'pr',
      label: 'pr',
      description: '広報・メディア対応・ブランド管理',
    ),
    AgentBoardChannel(
      id: 'procurement',
      label: 'procurement',
      description: '調達・ベンダー管理・コスト交渉',
    ),
  ];

  static const Set<String> _allowedTaskStatuses = <String>{
    'queued',
    'in_progress',
    'completed',
    'cancelled',
  };

  static const Set<String> _dangerousFragments = <String>{
    'drop table',
    'truncate table',
    'delete from',
    'rm -rf',
    'sudo ',
    'powershell -',
    'cmd /c',
    '<script',
    'javascript:',
    'system(',
  };

  static const int _maxGuardPayloadLength = 8000;

  static bool isSupportedBoardChannel(String? channelId) {
    if (channelId == null) {
      return false;
    }
    for (final channel in boardChannels) {
      if (channel.id == channelId) {
        return true;
      }
    }
    return false;
  }

  static const List<AgentBlueprint> defaultExecutiveBlueprints = [
    // ── CEO室 (2) ──
    AgentBlueprint(
      slug: 'ceo',
      displayName: 'CEO（社長）',
      roleTitle: '代表取締役社長',
      department: 'CEO室',
      identityPrompt:
          'あなたは自分株式会社のCEO（社長）です。全社方針を決め、最優先課題を定義し、各部門長に委任します。経営判断のスピードと正確さを重視し、12部署20人の仮想組織を統括します。',
      permissionsSummary: '全社方針の決定 / 部門長への委任 / 優先順位の最終判断 / 組織全体の統括',
    ),
    AgentBlueprint(
      slug: 'secretary',
      displayName: '秘書AI',
      roleTitle: 'エグゼクティブ秘書',
      department: 'CEO室',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたはCEO直属の秘書AIです。スケジュール管理、議事録作成、社内連絡の取りまとめ、各部署への伝達を担当します。正確で抜け漏れのない情報整理が得意です。',
      permissionsSummary: 'スケジュール管理 / 議事録作成 / 社内連絡調整 / CEO補佐',
    ),
    // ── CFO室 (2) ──
    AgentBlueprint(
      slug: 'cfo',
      displayName: 'CFO（財務部長）',
      roleTitle: '最高財務責任者',
      department: 'CFO室',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCFO（財務部長）です。資産管理、支出最適化、投資判断、予算策定を統括します。数字に基づく冷静な分析で経営を支えます。',
      permissionsSummary: '資金繰り / 固定費レビュー / 支出最適化 / 財務報告 / 予算策定',
    ),
    AgentBlueprint(
      slug: 'accountant',
      displayName: '経理担当',
      roleTitle: '経理担当者',
      department: 'CFO室',
      supervisorSlug: 'cfo',
      identityPrompt:
          'あなたはCFO直属の経理担当です。日々の収支記録、請求書管理、経費精算、月次決算の補助を行います。正確さと期限厳守を大切にします。',
      permissionsSummary: '収支記録 / 請求書管理 / 経費精算 / 月次決算補助',
    ),
    // ── CMO室 (2) ──
    AgentBlueprint(
      slug: 'cmo',
      displayName: 'CMO（マーケティング部長）',
      roleTitle: '最高マーケティング責任者',
      department: 'CMO室',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCMO（マーケティング部長）です。ブランド戦略、流入改善、登録率向上、認知拡大を統括します。データドリブンかつクリエイティブな施策を推進します。',
      permissionsSummary: '流入改善 / LP訴求改善 / SNSシェア / 登録導線改善 / ブランド戦略',
    ),
    AgentBlueprint(
      slug: 'ad-planner',
      displayName: '広告担当',
      roleTitle: '広告プランナー',
      department: 'CMO室',
      supervisorSlug: 'cmo',
      identityPrompt:
          'あなたはCMO直属の広告担当です。広告キャンペーンの企画・運用、クリエイティブ制作のディレクション、効果測定と改善を行います。ROIを常に意識した施策実行が得意です。',
      permissionsSummary: '広告企画・運用 / クリエイティブ管理 / 効果測定 / 予算配分',
    ),
    // ── CHO室 (1) ──
    AgentBlueprint(
      slug: 'cho',
      displayName: 'CHO（健康管理部長）',
      roleTitle: '最高健康責任者',
      department: 'CHO室',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCHO（健康管理部長）です。社長の心身の健康管理、生活リズム最適化、体調モニタリング、休息・回復計画を担当します。持続可能な働き方を追求します。',
      permissionsSummary: '健康記録 / 休息計画 / 生活習慣レビュー / 体調モニタリング',
    ),
    // ── CHRO室 (2) ──
    AgentBlueprint(
      slug: 'chro',
      displayName: 'CHRO（人事部長）',
      roleTitle: '最高人事責任者',
      department: 'CHRO室',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCHRO（人事部長）です。評価制度設計、報酬管理、組織文化醸成、習慣設計を統括します。公平で体系的な人事施策を推進します。',
      permissionsSummary: '評価整理 / 報酬設計 / ルール整備 / 継続支援 / 組織文化',
    ),
    AgentBlueprint(
      slug: 'recruiter',
      displayName: '採用担当',
      roleTitle: '採用リクルーター',
      department: 'CHRO室',
      supervisorSlug: 'chro',
      identityPrompt:
          'あなたはCHRO直属の採用担当です。新規エージェントの採用要件定義、候補者スクリーニング、オンボーディング計画の策定を行います。組織拡大に必要な人材像を的確に把握します。',
      permissionsSummary: '採用要件定義 / 候補者評価 / オンボーディング / 組織拡大計画',
    ),
    // ── 企画部 (2) ──
    AgentBlueprint(
      slug: 'planning-director',
      displayName: '企画部長',
      roleTitle: '企画部長',
      department: '企画部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社の企画部長です。新規事業企画、プロダクトロードマップの策定、市場調査に基づく戦略立案を担当します。アイデアを実行可能な計画に落とし込む力が強みです。',
      permissionsSummary: '新規事業企画 / ロードマップ策定 / 市場調査 / 戦略立案',
    ),
    AgentBlueprint(
      slug: 'product-manager',
      displayName: 'プロダクトマネージャー',
      roleTitle: 'プロダクトマネージャー',
      department: '企画部',
      supervisorSlug: 'planning-director',
      identityPrompt:
          'あなたは企画部のプロダクトマネージャーです。ユーザーニーズの分析、機能優先順位の決定、開発チームとの連携、リリース管理を行います。ユーザー価値とビジネス価値の両立を重視します。',
      permissionsSummary: 'ユーザーニーズ分析 / 機能優先順位決定 / リリース管理 / 開発連携',
    ),
    // ── 開発部 (2) ──
    AgentBlueprint(
      slug: 'cto',
      displayName: 'CTO（開発部長）',
      roleTitle: '最高技術責任者',
      department: '開発部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCTO（開発部長）です。技術戦略、アーキテクチャ設計、コードレビュー、技術的負債の管理を統括します。品質とスピードのバランスを取る判断力が強みです。',
      permissionsSummary: '技術戦略 / アーキテクチャ設計 / コードレビュー / 技術負債管理',
    ),
    AgentBlueprint(
      slug: 'frontend-dev',
      displayName: 'フロントエンド開発者',
      roleTitle: 'フロントエンドエンジニア',
      department: '開発部',
      supervisorSlug: 'cto',
      identityPrompt:
          'あなたは開発部のフロントエンド開発者です。Flutter Web のUI実装、UX改善、パフォーマンス最適化、レスポンシブ対応を担当します。ユーザーが直感的に使えるインターフェースを追求します。',
      permissionsSummary: 'UI実装 / UX改善 / パフォーマンス最適化 / レスポンシブ対応',
    ),
    AgentBlueprint(
      slug: 'backend-dev',
      displayName: 'バックエンド開発者',
      roleTitle: 'バックエンドエンジニア',
      department: '開発部',
      supervisorSlug: 'cto',
      identityPrompt:
          'あなたは開発部のバックエンド開発者です。Supabase Edge Functions の実装、データベース設計・最適化、API設計、セキュリティ対策を担当します。信頼性の高いインフラとデータ処理を支えます。',
      permissionsSummary: 'Edge Functions実装 / DB設計 / API設計 / セキュリティ対策',
    ),
    // ── 営業部 (2) ──
    AgentBlueprint(
      slug: 'sales-director',
      displayName: '営業部長',
      roleTitle: '営業部長',
      department: '営業部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社の営業部長です。売上目標の設定、営業戦略の立案、顧客開拓、パートナーシップ構築を統括します。数字にコミットし、チームを牽引するリーダーシップが強みです。',
      permissionsSummary: '売上目標管理 / 営業戦略立案 / 顧客開拓 / パートナーシップ構築',
    ),
    AgentBlueprint(
      slug: 'inside-sales',
      displayName: 'インサイドセールス',
      roleTitle: 'インサイドセールス担当',
      department: '営業部',
      supervisorSlug: 'sales-director',
      identityPrompt:
          'あなたは営業部のインサイドセールス担当です。リード獲得、見込み顧客へのアプローチ、商談化率の向上、CRMデータ管理を行います。効率的なセールスプロセスの構築が得意です。',
      permissionsSummary: 'リード獲得 / 見込み顧客アプローチ / 商談化率改善 / CRM管理',
    ),
    // ── CS部 (1) ──
    AgentBlueprint(
      slug: 'cs-director',
      displayName: 'CS部長',
      roleTitle: 'カスタマーサクセス部長',
      department: 'CS部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社のCS部長です。顧客満足度向上、サポート品質管理、チャーン率低減、ユーザーオンボーディング最適化を担当します。ユーザーの声を経営に届ける橋渡し役です。',
      permissionsSummary: '顧客満足度管理 / サポート品質 / チャーン率低減 / オンボーディング',
    ),
    // ── 法務部 (1) ──
    AgentBlueprint(
      slug: 'legal-director',
      displayName: '法務部長',
      roleTitle: '法務部長',
      department: '法務部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社の法務部長です。利用規約・プライバシーポリシーの管理、契約書レビュー、コンプライアンス管理、知的財産保護を担当します。リスクを未然に防ぐ慎重さが強みです。',
      permissionsSummary: '利用規約管理 / 契約レビュー / コンプライアンス / 知的財産保護',
    ),
    // ── 広報部 (1) ──
    AgentBlueprint(
      slug: 'pr-director',
      displayName: '広報部長',
      roleTitle: '広報部長',
      department: '広報部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社の広報部長です。プレスリリース作成、メディアリレーション、社外コミュニケーション戦略、ブランドイメージ管理を担当します。企業価値を社会に伝える発信力が強みです。',
      permissionsSummary: 'プレスリリース / メディア対応 / 社外広報 / ブランド管理',
    ),
    // ── 調達部 (1) ──
    AgentBlueprint(
      slug: 'procurement-director',
      displayName: '調達部長',
      roleTitle: '調達部長',
      department: '調達部',
      supervisorSlug: 'ceo',
      identityPrompt:
          'あなたは自分株式会社の調達部長です。外部サービス・ツールの選定、ベンダー管理、コスト交渉、契約管理を担当します。最適な調達でコストパフォーマンスを最大化します。',
      permissionsSummary: 'ツール選定 / ベンダー管理 / コスト交渉 / 契約管理',
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

    // R31: agent_memories は user_id に索引が無く (索引は
    // idx_agent_memories_agent_created(agent_id, created_at DESC) のみ)、
    // user_id 単独で絞ると追記専用ログの全表走査になり本番で statement timeout
    // (500 / 57014) を起こしていた。自分の agent_id 群で絞れば既存索引に載る。
    // 本番実測: agent_id 経由 122ms vs user_id 単独 7929ms(閾値8s付近で500と往復)。
    // agent_memories.agent_id は agents(id) への NOT NULL FK で agents は本ユーザー
    // の全件 (ensureExecutiveAgents→_loadAgentsForUser) のため取得行は同一。
    // user_id 条件も RLS と意図明示のため残す (索引で絞った少数行への評価で安価)。
    final agentIds = agents.map((agent) => agent.id).toList();
    final dynamic memoryRows = await _supabase
        .from('agent_memories')
        .select()
        .eq('user_id', userId)
        .inFilter('agent_id', agentIds)
        .order('created_at', ascending: false)
        .limit(40);
    final memories = (memoryRows as List)
        .whereType<Map>()
        .map(
          (row) => AgentMemoryEntry.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();

    List<AgentRelationship> relationships = const <AgentRelationship>[];
    try {
      final dynamic relationshipRows = await _supabase
          .from('agent_relationships')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(80);
      relationships = (relationshipRows as List)
          .whereType<Map>()
          .map(
            (row) => AgentRelationship.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList();
    } catch (_) {
      relationships = const <AgentRelationship>[];
    }

    List<AgentMessage> messages = const <AgentMessage>[];
    try {
      final dynamic messageRows = await _supabase
          .from('agent_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(40);
      messages = (messageRows as List)
          .whereType<Map>()
          .map((row) => AgentMessage.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      messages = const <AgentMessage>[];
    }

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
      relationships: relationships,
      recentMessages: messages,
      openTaskCountsByAgent: taskCounts,
      memoryCountsByAgent: memoryCounts,
    );
  }

  Future<AgentWorkspaceSnapshot?> loadWorkspaceBySlug(
    String slug, {
    int taskLimit = 8,
    int memoryLimit = 16,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }

    final agents = await ensureExecutiveAgents();
    AgentProfile? targetAgent;
    for (final agent in agents) {
      if (agent.slug == slug) {
        targetAgent = agent;
        break;
      }
    }
    if (targetAgent == null) {
      return null;
    }

    final dynamic taskRows = await _supabase
        .from('agent_tasks')
        .select()
        .eq('user_id', userId)
        .eq('assignee_agent_id', targetAgent.id)
        .neq('status', 'completed')
        .order('created_at', ascending: false)
        .limit(taskLimit);
    final tasks = (taskRows as List)
        .whereType<Map>()
        .map((row) => AgentTask.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    final dynamic memoryRows = await _supabase
        .from('agent_memories')
        .select()
        .eq('user_id', userId)
        .eq('agent_id', targetAgent.id)
        .order('created_at', ascending: false)
        .limit(memoryLimit);
    final memories = (memoryRows as List)
        .whereType<Map>()
        .map(
          (row) => AgentMemoryEntry.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();

    return AgentWorkspaceSnapshot(
      agent: targetAgent,
      tasks: tasks,
      recentMemories: memories,
      startupPrompt: AgentOrgService.composeStartupPrompt(
        agent: targetAgent,
        recentMemories: memories,
        openTasks: tasks,
      ),
    );
  }

  Future<Map<String, AgentProfile>> loadExecutiveAgentMap() async {
    final agents = await ensureExecutiveAgents();
    return <String, AgentProfile>{
      for (final agent in agents) agent.slug: agent,
    };
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

    for (final blueprint in defaultExecutiveBlueprints) {
      if (blueprint.supervisorSlug == null) {
        continue;
      }
      final agent = refreshedBySlug[blueprint.slug];
      final supervisor = refreshedBySlug[blueprint.supervisorSlug];
      if (agent == null || supervisor == null) {
        continue;
      }
      if (agent.supervisorAgentId == supervisor.id) {
        continue;
      }
      await _supabase
          .from('agents')
          .update({'supervisor_agent_id': supervisor.id})
          .eq('id', agent.id)
          .eq('user_id', userId);
    }

    final finalAgents = await _loadAgentsForUser(userId);
    await _ensureDefaultRelationships(userId, finalAgents);
    return finalAgents;
  }

  // ignore: unused_element
  Future<AgentTask> _delegateTaskLegacy({
    required String supervisorAgentId,
    required String assigneeAgentId,
    required String title,
    String description = '',
    String priority = 'high',
    String taskType = 'delegated_action',
    String source = 'manual_delegate',
    String messageKind = 'directive',
    String? conversationId,
    bool createMessage = true,
  }) async {
    final userId = _requireUserId();
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Task title is required.');
    }

    final dynamic insertedTask = await _supabase
        .from('agent_tasks')
        .insert({
          'user_id': userId,
          'supervisor_agent_id': supervisorAgentId,
          'assignee_agent_id': assigneeAgentId,
          'title': normalizedTitle,
          'description': normalizedDescription,
          'status': 'queued',
          'priority': priority,
          'task_type': taskType,
          'source': source,
          'metadata': <String, dynamic>{
            'delegated_at': DateTime.now().toIso8601String(),
          },
        })
        .select()
        .single();

    final task = AgentTask.fromJson(
      Map<String, dynamic>.from(insertedTask as Map),
    );

    await _supabase
        .from('agents')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', assigneeAgentId)
        .eq('user_id', userId);

    await _supabase.from('agent_memories').insert([
      {
        'user_id': userId,
        'agent_id': supervisorAgentId,
        'memory_layer': 'episodes',
        'content': '委任: $normalizedTitle',
        'source': 'delegate_task',
      },
      {
        'user_id': userId,
        'agent_id': assigneeAgentId,
        'memory_layer': 'activity_log',
        'content': normalizedDescription.isEmpty
            ? 'CEOからの新規委任: $normalizedTitle'
            : 'CEOからの新規委任: $normalizedTitle\n$normalizedDescription',
        'source': 'delegate_task',
      },
    ]);

    if (createMessage) {
      await sendStructuredMessage(
        fromAgentId: supervisorAgentId,
        toAgentId: assigneeAgentId,
        summary: normalizedTitle,
        messageKind: messageKind,
        linkedTaskId: task.id,
        conversationId: conversationId,
        payload: <String, dynamic>{
          'task_id': task.id,
          'task_type': task.taskType,
          'description': normalizedDescription,
          'priority': priority,
        },
        source: source,
      );
    }

    return task;
  }

  Future<AgentTask> delegateTask({
    required String supervisorAgentId,
    required String assigneeAgentId,
    required String title,
    String description = '',
    String priority = 'high',
    String taskType = 'delegated_action',
    String source = 'manual_delegate',
    String messageKind = 'directive',
    String? conversationId,
    bool createMessage = true,
    String? actorAgentId,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final userId = _requireUserId();
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Task title is required.');
    }

    final actorId = actorAgentId ?? supervisorAgentId;
    if (actorId != supervisorAgentId) {
      throw StateError(
        'Fail-close: actor must match supervisor when delegating tasks.',
      );
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'delegate_task',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'supervisor_agent_id': supervisorAgentId,
        'assignee_agent_id': assigneeAgentId,
        'title': normalizedTitle,
        'description': normalizedDescription,
        'priority': priority,
        'task_type': taskType,
        'source': source,
      },
      permissionCheck: () async {
        final supervisor = await _loadAgentById(supervisorAgentId);
        final assignee = await _loadAgentById(assigneeAgentId);
        if (supervisor == null || assignee == null) {
          return 'Agent not found.';
        }
        if (!supervisor.isActive) {
          return 'Supervisor is not active.';
        }
        if (assignee.supervisorAgentId != supervisor.id) {
          return 'Supervisor cannot delegate to non-subordinate agent.';
        }
        return null;
      },
    );

    final dynamic insertedTask = await _supabase
        .from('agent_tasks')
        .insert({
          'user_id': userId,
          'supervisor_agent_id': supervisorAgentId,
          'assignee_agent_id': assigneeAgentId,
          'title': normalizedTitle,
          'description': normalizedDescription,
          'status': 'queued',
          'priority': priority,
          'task_type': taskType,
          'source': source,
          'metadata': <String, dynamic>{
            ...metadata,
            'delegated_at': DateTime.now().toIso8601String(),
          },
        })
        .select()
        .single();

    final task = AgentTask.fromJson(
      Map<String, dynamic>.from(insertedTask as Map),
    );

    await _supabase
        .from('agents')
        .update({'last_active_at': DateTime.now().toIso8601String()})
        .eq('id', assigneeAgentId)
        .eq('user_id', userId);

    await _supabase.from('agent_memories').insert([
      {
        'user_id': userId,
        'agent_id': supervisorAgentId,
        'memory_layer': 'activity_log',
        'content': 'Delegated task: $normalizedTitle',
        'source': 'delegate_task',
      },
      {
        'user_id': userId,
        'agent_id': assigneeAgentId,
        'memory_layer': 'activity_log',
        'content': normalizedDescription.isEmpty
            ? 'Received delegated task: $normalizedTitle'
            : 'Received delegated task: $normalizedTitle\n$normalizedDescription',
        'source': 'delegate_task',
      },
    ]);

    if (createMessage) {
      await sendStructuredMessage(
        actorAgentId: actorId,
        fromAgentId: supervisorAgentId,
        toAgentId: assigneeAgentId,
        summary: normalizedTitle,
        messageKind: messageKind,
        linkedTaskId: task.id,
        conversationId: conversationId,
        payload: <String, dynamic>{
          'task_id': task.id,
          'task_type': task.taskType,
          'description': normalizedDescription,
          'priority': priority,
        },
        source: source,
      );
    }

    return task;
  }

  Future<AgentTask> updateTaskClarity({
    required String taskId,
    required Map<String, dynamic> clarity,
  }) async {
    final userId = _requireUserId();
    final task = await _loadTaskById(taskId);
    if (task == null) {
      throw StateError('Task not found.');
    }

    final dynamic updatedTask = await _supabase
        .from('agent_tasks')
        .update({
          'metadata': <String, dynamic>{
            ...task.metadata,
            'clarity': clarity,
          },
        })
        .eq('id', taskId)
        .eq('user_id', userId)
        .select()
        .single();

    return AgentTask.fromJson(
      Map<String, dynamic>.from(updatedTask as Map),
    );
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    if (!_allowedTaskStatuses.contains(status)) {
      throw ArgumentError('Unsupported task status: $status');
    }

    final task = await _loadTaskById(taskId);
    if (task == null) {
      throw StateError('Task not found.');
    }
    if (!_isValidTaskTransition(from: task.status, to: status)) {
      throw StateError(
        'Fail-close: invalid task transition ${task.status} -> $status.',
      );
    }
    final actorId = actorAgentId ?? task.supervisorAgentId;

    await _guardToolExecution(
      userId: userId,
      toolName: 'update_task_status',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'task_id': task.id,
        'task_status': status,
      },
      permissionCheck: () async {
        if (actorId != task.assigneeAgentId &&
            actorId != task.supervisorAgentId) {
          return 'Only assignee or supervisor can update task status.';
        }
        return null;
      },
    );

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

  Future<AgentMessage?> sendStructuredMessage({
    required String fromAgentId,
    required String toAgentId,
    required String summary,
    String messageKind = 'directive',
    String status = 'sent',
    String? linkedTaskId,
    String? conversationId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String source = 'agent_message',
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final normalizedSummary = summary.trim();
    if (normalizedSummary.isEmpty) {
      return null;
    }
    final actorId = actorAgentId ?? fromAgentId;

    await _guardToolExecution(
      userId: userId,
      toolName: 'send_message',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'from_agent_id': fromAgentId,
        'to_agent_id': toAgentId,
        'message_kind': messageKind,
        'summary': normalizedSummary,
        'source': source,
        'payload': payload,
        'metadata': metadata,
      },
      permissionCheck: () async {
        if (actorId != fromAgentId) {
          return 'Actor must match message sender.';
        }
        if (fromAgentId == toAgentId) {
          return null;
        }
        final hasForwardRelationship = await _hasActiveRelationship(
          userId: userId,
          fromAgentId: fromAgentId,
          toAgentId: toAgentId,
        );
        if (!hasForwardRelationship) {
          return 'No active relationship between sender and receiver.';
        }
        return null;
      },
    );

    dynamic inserted;
    try {
      inserted = await _supabase
          .from('agent_messages')
          .insert({
            'user_id': userId,
            'from_agent_id': fromAgentId,
            'to_agent_id': toAgentId,
            'linked_task_id': linkedTaskId,
            'conversation_id': conversationId,
            'message_kind': messageKind,
            'summary': normalizedSummary,
            'payload': payload,
            'status': status,
            'metadata': <String, dynamic>{
              'source': source,
              'sent_at': DateTime.now().toIso8601String(),
              ...metadata,
            },
          })
          .select()
          .maybeSingle();

      await _supabase
          .from('agents')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', fromAgentId)
          .eq('user_id', userId);
      await _supabase
          .from('agents')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', toAgentId)
          .eq('user_id', userId);
    } catch (_) {
      return null;
    }

    if (inserted is! Map) {
      return null;
    }
    return AgentMessage.fromJson(Map<String, dynamic>.from(inserted));
  }

  Future<AgentMessage?> postBoardMessage({
    required String fromAgentId,
    required String channel,
    required String summary,
    String status = 'sent',
    Map<String, dynamic> payload = const <String, dynamic>{},
    String? actorAgentId,
  }) async {
    final normalizedChannel = channel.trim().toLowerCase();
    if (!isSupportedBoardChannel(normalizedChannel)) {
      throw ArgumentError('Unsupported board channel: $channel');
    }

    return sendStructuredMessage(
      fromAgentId: fromAgentId,
      toAgentId: fromAgentId,
      summary: summary,
      messageKind: 'board',
      status: status,
      conversationId: 'board:$normalizedChannel',
      payload: payload,
      metadata: <String, dynamic>{
        'channel': normalizedChannel,
      },
      source: 'board_channel',
      actorAgentId: actorAgentId,
    );
  }

  Future<AgentMessage?> toggleBoardReaction({
    required String messageId,
    required String emoji,
    required String actorAgentId,
  }) async {
    final userId = _requireUserId();
    final normalizedEmoji = emoji.trim();
    if (messageId.trim().isEmpty) {
      throw ArgumentError('Message id is required.');
    }
    if (normalizedEmoji.isEmpty) {
      throw ArgumentError('Emoji is required.');
    }

    AgentProfile? actor;
    AgentMessage? currentMessage;

    await _guardToolExecution(
      userId: userId,
      toolName: 'toggle_board_reaction',
      actorAgentId: actorAgentId,
      payload: <String, dynamic>{
        'message_id': messageId,
        'emoji': normalizedEmoji,
      },
      permissionCheck: () async {
        actor = await _loadAgentById(actorAgentId);
        currentMessage = await _loadMessageById(messageId);
        if (actor == null) {
          return 'Actor not found.';
        }
        if (!actor!.isActive) {
          return 'Actor is not active.';
        }
        if (currentMessage == null) {
          return 'Message not found.';
        }
        if (currentMessage!.messageKind != 'board') {
          return 'Only board messages support reactions.';
        }
        return null;
      },
    );

    final message = currentMessage;
    if (message == null || message.messageKind != 'board') {
      return null;
    }

    final nextMetadata = _toggleReactionMetadata(
      metadata: message.metadata,
      emoji: normalizedEmoji,
      actorAgentId: actorAgentId,
    );

    try {
      final dynamic updated = await _supabase
          .from('agent_messages')
          .update({
            'metadata': nextMetadata,
          })
          .eq('id', message.id)
          .eq('user_id', userId)
          .select()
          .single();

      await _supabase
          .from('agents')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', actorAgentId)
          .eq('user_id', userId);

      if (updated is! Map) {
        return null;
      }
      return AgentMessage.fromJson(Map<String, dynamic>.from(updated));
    } catch (_) {
      return null;
    }
  }

  Future<void> consolidateMemory({
    required String agentId,
    required String summary,
    String source = 'memory_consolidation',
    String? actorAgentId,
  }) async {
    await appendMemoryEntry(
      agentId: agentId,
      content: summary,
      memoryLayer: 'knowledge',
      source: source,
      actorAgentId: actorAgentId ?? agentId,
    );
  }

  Future<void> registerForgettingDecision({
    required String agentId,
    required String forgottenItem,
    required String reason,
    String source = 'memory_forgetting',
    String? actorAgentId,
  }) async {
    await appendMemoryEntry(
      agentId: agentId,
      content: 'Forget: $forgottenItem\nReason: $reason',
      memoryLayer: 'activity_log',
      source: source,
      actorAgentId: actorAgentId ?? agentId,
    );
  }

  Future<void> resolveMemoryContradiction({
    required String agentId,
    required String contradiction,
    required String resolution,
    String source = 'memory_contradiction',
    String? actorAgentId,
  }) async {
    await appendMemoryEntry(
      agentId: agentId,
      content: 'Contradiction: $contradiction\nResolution: $resolution',
      memoryLayer: 'state',
      source: source,
      actorAgentId: actorAgentId ?? agentId,
    );
  }

  Future<void> appendMemoryEntry({
    required String agentId,
    required String content,
    String memoryLayer = 'episodes',
    String source = 'manual_note',
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      throw ArgumentError('Memory content is required.');
    }
    if (!memoryLayerOrder.contains(memoryLayer)) {
      throw ArgumentError('Unsupported memory layer: $memoryLayer');
    }
    final actorId = actorAgentId ?? agentId;
    await _guardToolExecution(
      userId: userId,
      toolName: 'append_memory',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'target_agent_id': agentId,
        'memory_layer': memoryLayer,
        'source': source,
        'metadata': metadata,
        'content': normalizedContent,
      },
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        final target = await _loadAgentById(agentId);
        if (actor == null || target == null) {
          return 'Agent not found.';
        }
        if (actor.id == target.id) {
          return null;
        }
        if (target.supervisorAgentId == actor.id || actor.slug == 'ceo') {
          return null;
        }
        return 'Actor cannot write memory for another agent.';
      },
    );
    await _supabase.from('agent_memories').insert({
      'user_id': userId,
      'agent_id': agentId,
      'memory_layer': memoryLayer,
      'content': normalizedContent,
      'source': source,
      'metadata': metadata,
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
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final actorId = actorAgentId ?? await _findAgentIdBySlug('ceo');
    if (actorId == null) {
      throw StateError(
        'Fail-close: actor agent is required for status change.',
      );
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'set_agent_status',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'target_agent_id': agentId,
        'enabled': enabled,
      },
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        final target = await _loadAgentById(agentId);
        if (actor == null || target == null) {
          return 'Agent not found.';
        }
        if (actor.id == target.id) {
          return null;
        }
        if (target.supervisorAgentId == actor.id || actor.slug == 'ceo') {
          return null;
        }
        return 'Actor cannot change target agent status.';
      },
    );

    await _supabase
        .from('agents')
        .update({'status': enabled ? 'active' : 'paused'})
        .eq('id', agentId)
        .eq('user_id', userId);
  }

  Future<void> processTask({
    required AgentTask task,
    required String status,
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    if (!_allowedTaskStatuses.contains(status)) {
      throw ArgumentError('Unsupported task status: $status');
    }
    if (!_isValidTaskTransition(from: task.status, to: status)) {
      throw StateError(
        'Fail-close: invalid task transition ${task.status} -> $status.',
      );
    }

    final actorId = actorAgentId ?? task.assigneeAgentId;
    await _guardToolExecution(
      userId: userId,
      toolName: 'process_task',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'task_id': task.id,
        'task_type': task.taskType,
        'current_status': task.status,
        'next_status': status,
      },
      permissionCheck: () async {
        if (actorId != task.assigneeAgentId) {
          return 'Only assignee can process delegated tasks.';
        }
        return null;
      },
    );

    await _supabase
        .from('agent_tasks')
        .update({
          'status': status,
          'completed_at':
              status == 'completed' ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', task.id)
        .eq('user_id', userId);

    final memoryText = switch (status) {
      'in_progress' => '着手: ${task.title}',
      'completed' => '完了: ${task.title}',
      'cancelled' => '中止: ${task.title}',
      _ => '状態更新($status): ${task.title}',
    };

    await appendMemoryEntry(
      agentId: task.assigneeAgentId,
      content: memoryText,
      memoryLayer: 'episodes',
      source: 'task_status',
      actorAgentId: actorId,
    );

    await sendStructuredMessage(
      actorAgentId: actorId,
      fromAgentId: task.assigneeAgentId,
      toAgentId: task.supervisorAgentId,
      summary: memoryText,
      messageKind: 'status',
      linkedTaskId: task.id,
      payload: <String, dynamic>{
        'task_id': task.id,
        'task_title': task.title,
        'task_status': status,
      },
      source: 'task_status',
    );
  }

  Future<int> runHeartbeat({
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final actorId = actorAgentId ?? await _findAgentIdBySlug('ceo');
    if (actorId == null) {
      throw StateError('Fail-close: actor agent is required for heartbeat.');
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'run_heartbeat',
      actorAgentId: actorId,
      payload: const <String, dynamic>{},
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        if (actor == null || actor.slug != 'ceo') {
          return 'Only CEO can execute heartbeat manually.';
        }
        return null;
      },
    );

    final dynamic response = await _supabase
        .rpc('run_agent_heartbeat', params: {'p_user_id': userId});
    if (response is int) {
      return response;
    }
    return int.tryParse(response?.toString() ?? '0') ?? 0;
  }

  Future<int> runNightlyConsolidation({
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final actorId = actorAgentId ?? await _findAgentIdBySlug('ceo');
    if (actorId == null) {
      throw StateError(
        'Fail-close: actor agent is required for nightly consolidation.',
      );
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'run_nightly_consolidation',
      actorAgentId: actorId,
      payload: const <String, dynamic>{},
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        if (actor == null || actor.slug != 'ceo') {
          return 'Only CEO can execute nightly consolidation manually.';
        }
        return null;
      },
    );

    final dynamic response = await _supabase
        .rpc('run_agent_nightly_consolidation', params: {'p_user_id': userId});
    if (response is int) {
      return response;
    }
    return int.tryParse(response?.toString() ?? '0') ?? 0;
  }

  Future<int> runForgettingCycle({
    int retentionDays = 30,
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final actorId = actorAgentId ?? await _findAgentIdBySlug('ceo');
    if (actorId == null) {
      throw StateError('Fail-close: actor agent is required for forgetting.');
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'run_forgetting',
      actorAgentId: actorId,
      payload: <String, dynamic>{'retention_days': retentionDays},
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        if (actor == null || actor.slug != 'ceo') {
          return 'Only CEO can execute forgetting manually.';
        }
        return null;
      },
    );

    final dynamic response = await _supabase.rpc(
      'run_agent_memory_forgetting',
      params: {
        'p_user_id': userId,
        'p_retention_days': retentionDays,
      },
    );
    if (response is int) {
      return response;
    }
    return int.tryParse(response?.toString() ?? '0') ?? 0;
  }

  Future<Map<String, dynamic>> runRuntimeCycle({
    bool runNightly = false,
    bool runForgetting = false,
    String? actorAgentId,
  }) async {
    final userId = _requireUserId();
    final actorId = actorAgentId ?? await _findAgentIdBySlug('ceo');
    if (actorId == null) {
      throw StateError(
        'Fail-close: actor agent is required for runtime cycle.',
      );
    }

    await _guardToolExecution(
      userId: userId,
      toolName: 'run_runtime_cycle',
      actorAgentId: actorId,
      payload: <String, dynamic>{
        'run_nightly': runNightly,
        'run_forgetting': runForgetting,
      },
      permissionCheck: () async {
        final actor = await _loadAgentById(actorId);
        if (actor == null || actor.slug != 'ceo') {
          return 'Only CEO can execute runtime cycle manually.';
        }
        return null;
      },
    );

    final dynamic response = await _supabase.rpc(
      'run_agent_runtime_cycle',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_run_nightly': runNightly,
        'p_run_forgetting': runForgetting,
      },
    );
    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return <String, dynamic>{
      'heartbeat_agents': 0,
      'nightly_agents': 0,
      'forgetting_agents': 0,
      'run_nightly': runNightly,
      'run_forgetting': runForgetting,
    };
  }

  static bool _isValidTaskTransition({
    required String from,
    required String to,
  }) {
    if (from == to) {
      return true;
    }
    switch (from) {
      case 'queued':
        return to == 'in_progress' || to == 'completed' || to == 'cancelled';
      case 'in_progress':
        return to == 'completed' || to == 'cancelled';
      case 'completed':
      case 'cancelled':
        return false;
      default:
        return false;
    }
  }

  // ignore: unused_element
  static String _composeStartupPromptLegacy({
    required AgentProfile agent,
    required List<AgentMemoryEntry> recentMemories,
    required List<AgentTask> openTasks,
  }) {
    List<AgentMemoryEntry> byLayer(String layer) {
      return recentMemories
          .where((memory) => memory.memoryLayer == layer)
          .toList();
    }

    final primingStack = <AgentMemoryEntry>[
      ...byLayer('state'),
    ];
    final operationalStack = <AgentMemoryEntry>[
      ...byLayer('knowledge'),
      ...byLayer('activity_log'),
      ...byLayer('episodes'),
    ];
    final consolidationStack = byLayer('procedures');
    final contradictionStack = byLayer('skills');
    final forgettingStack = byLayer('activity_log');

    final buffer = StringBuffer()
      ..writeln('あなたは ${agent.displayName} (${agent.roleTitle}) です。')
      ..writeln('所属: ${agent.department}')
      ..writeln('状態: ${agent.isActive ? 'active' : 'paused'}')
      ..writeln()
      ..writeln('【Identity】')
      ..writeln(agent.identityPrompt)
      ..writeln()
      ..writeln('【Permissions】')
      ..writeln(agent.permissionsSummary);

    if (primingStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Priming】');
      for (final memory in primingStack.take(2)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (operationalStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Operational Memory (knowledge / activity_log / episodes)】');
      for (final memory in operationalStack.take(6)) {
        buffer.writeln('- [${memory.memoryLayer}] ${memory.content}');
      }
    }

    if (consolidationStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Consolidation】');
      for (final memory in consolidationStack.take(3)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (contradictionStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Contradiction Resolution】');
      for (final memory in contradictionStack.take(2)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (forgettingStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Forgetting Decisions】');
      for (final memory in forgettingStack.take(2)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (openTasks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('【Open Tasks】');
      for (final task in openTasks.take(5)) {
        buffer.writeln('- (${task.priority}/${task.status}) ${task.title}');
      }
    }

    buffer
      ..writeln()
      ..writeln('この前提を維持し、自分の権限内で判断してください。');
    return buffer.toString().trim();
  }

  static String composeStartupPrompt({
    required AgentProfile agent,
    required List<AgentMemoryEntry> recentMemories,
    required List<AgentTask> openTasks,
  }) {
    List<AgentMemoryEntry> byLayer(String layer) {
      return recentMemories
          .where((memory) => memory.memoryLayer == layer)
          .toList();
    }

    final stateStack = byLayer('state');
    final knowledgeStack = byLayer('knowledge');
    final procedureStack = byLayer('procedures');
    final skillsStack = byLayer('skills');
    final episodeStack = byLayer('episodes');
    final activityLogStack = byLayer('activity_log');

    final buffer = StringBuffer()
      ..writeln('You are ${agent.displayName} (${agent.roleTitle}).')
      ..writeln('Department: ${agent.department}')
      ..writeln('Status: ${agent.isActive ? 'active' : 'paused'}')
      ..writeln()
      ..writeln('[Identity]')
      ..writeln(agent.identityPrompt)
      ..writeln()
      ..writeln('[Permissions]')
      ..writeln(agent.permissionsSummary);

    if (stateStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[State]');
      for (final memory in stateStack.take(3)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (knowledgeStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Knowledge]');
      for (final memory in knowledgeStack.take(4)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (procedureStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Procedures]');
      for (final memory in procedureStack.take(3)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (skillsStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Skills]');
      for (final memory in skillsStack.take(3)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (episodeStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Episodes]');
      for (final memory in episodeStack.take(5)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (activityLogStack.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Activity Log]');
      for (final memory in activityLogStack.take(4)) {
        buffer.writeln('- ${memory.content}');
      }
    }

    if (openTasks.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('[Open Tasks]');
      for (final task in openTasks.take(5)) {
        buffer.writeln('- (${task.priority}/${task.status}) ${task.title}');
      }
    }

    buffer
      ..writeln()
      ..writeln(
        'Use this context to execute your role with strict permission boundaries.',
      );
    return buffer.toString().trim();
  }

  Future<void> _ensureDefaultRelationships(
    String userId,
    List<AgentProfile> agents,
  ) async {
    final bySlug = <String, AgentProfile>{
      for (final agent in agents) agent.slug: agent,
    };
    final ceo = bySlug['ceo'];
    if (ceo == null) {
      return;
    }

    final rows = <Map<String, dynamic>>[];
    for (final blueprint in defaultExecutiveBlueprints) {
      if (blueprint.supervisorSlug == null) {
        continue;
      }
      final subordinate = bySlug[blueprint.slug];
      final supervisor = bySlug[blueprint.supervisorSlug];
      if (subordinate == null || supervisor == null) {
        continue;
      }
      rows.add(<String, dynamic>{
        'user_id': userId,
        'from_agent_id': supervisor.id,
        'to_agent_id': subordinate.id,
        'relationship_type': 'supervises',
        'communication_protocol': 'directive_then_report',
        'status': 'active',
        'metadata': <String, dynamic>{'source': 'registry_sync'},
      });
      rows.add(<String, dynamic>{
        'user_id': userId,
        'from_agent_id': subordinate.id,
        'to_agent_id': supervisor.id,
        'relationship_type': 'reports_to',
        'communication_protocol': 'status_update',
        'status': 'active',
        'metadata': <String, dynamic>{'source': 'registry_sync'},
      });
    }

    if (rows.isEmpty) {
      return;
    }
    try {
      await _supabase.from('agent_relationships').upsert(
            rows,
            onConflict: 'user_id,from_agent_id,to_agent_id,relationship_type',
          );
    } catch (_) {
      // Keep agent registry usable even before migration is applied.
    }
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

  Future<AgentProfile?> _loadAgentById(String agentId) async {
    final userId = _requireUserId();
    if (agentId.trim().isEmpty) {
      return null;
    }
    final dynamic row = await _supabase
        .from('agents')
        .select()
        .eq('user_id', userId)
        .eq('id', agentId)
        .maybeSingle();
    if (row is! Map) {
      return null;
    }
    return AgentProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AgentTask?> _loadTaskById(String taskId) async {
    final userId = _requireUserId();
    if (taskId.trim().isEmpty) {
      return null;
    }
    final dynamic row = await _supabase
        .from('agent_tasks')
        .select()
        .eq('user_id', userId)
        .eq('id', taskId)
        .maybeSingle();
    if (row is! Map) {
      return null;
    }
    return AgentTask.fromJson(Map<String, dynamic>.from(row));
  }

  Future<AgentMessage?> _loadMessageById(String messageId) async {
    final userId = _requireUserId();
    if (messageId.trim().isEmpty) {
      return null;
    }
    final dynamic row = await _supabase
        .from('agent_messages')
        .select()
        .eq('user_id', userId)
        .eq('id', messageId)
        .maybeSingle();
    if (row is! Map) {
      return null;
    }
    return AgentMessage.fromJson(Map<String, dynamic>.from(row));
  }

  Future<String?> _findAgentIdBySlug(String slug) async {
    final userId = _requireUserId();
    final dynamic row = await _supabase
        .from('agents')
        .select('id')
        .eq('user_id', userId)
        .eq('slug', slug)
        .maybeSingle();
    if (row is! Map) {
      return null;
    }
    return row['id']?.toString();
  }

  Future<bool> _hasActiveRelationship({
    required String userId,
    required String fromAgentId,
    required String toAgentId,
  }) async {
    if (fromAgentId == toAgentId) {
      return true;
    }
    final dynamic row = await _supabase
        .from('agent_relationships')
        .select('id')
        .eq('user_id', userId)
        .eq('from_agent_id', fromAgentId)
        .eq('to_agent_id', toAgentId)
        .eq('status', 'active')
        .limit(1)
        .maybeSingle();
    return row is Map;
  }

  Map<String, dynamic> _toggleReactionMetadata({
    required Map<String, dynamic> metadata,
    required String emoji,
    required String actorAgentId,
  }) {
    final nextMetadata = Map<String, dynamic>.from(metadata);
    final reactionActorIds = <String, List<String>>{};
    final rawReactionActorIds = metadata['reaction_actor_ids'];
    if (rawReactionActorIds is Map) {
      for (final entry in rawReactionActorIds.entries) {
        reactionActorIds[entry.key.toString()] = _coerceStringList(entry.value);
      }
    }

    final nextActors = List<String>.from(reactionActorIds[emoji] ?? const []);
    if (nextActors.contains(actorAgentId)) {
      nextActors.remove(actorAgentId);
    } else {
      nextActors.add(actorAgentId);
      nextActors.sort();
    }

    if (nextActors.isEmpty) {
      reactionActorIds.remove(emoji);
    } else {
      reactionActorIds[emoji] = nextActors;
    }

    if (reactionActorIds.isEmpty) {
      nextMetadata.remove('reaction_actor_ids');
      nextMetadata.remove('reaction_updated_at');
    } else {
      nextMetadata['reaction_actor_ids'] = reactionActorIds;
      nextMetadata['reaction_updated_at'] = DateTime.now().toIso8601String();
    }
    return nextMetadata;
  }

  List<String> _coerceStringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _guardToolExecution({
    required String userId,
    required String toolName,
    required String actorAgentId,
    required Map<String, dynamic> payload,
    required Future<String?> Function() permissionCheck,
  }) async {
    if (actorAgentId.trim().isEmpty) {
      await _logToolExecution(
        userId: userId,
        actorAgentId: null,
        toolName: toolName,
        payload: payload,
        allowed: false,
        blockedReason: 'Missing actor agent id.',
      );
      throw StateError('Fail-close: missing actor agent id for $toolName.');
    }

    final dangerousReason = _detectDangerousPayload(payload);
    if (dangerousReason != null) {
      await _logToolExecution(
        userId: userId,
        actorAgentId: actorAgentId,
        toolName: toolName,
        payload: payload,
        allowed: false,
        blockedReason: dangerousReason,
      );
      throw StateError('Fail-close: $dangerousReason');
    }

    final permissionDeniedReason = await permissionCheck();
    if (permissionDeniedReason != null) {
      await _logToolExecution(
        userId: userId,
        actorAgentId: actorAgentId,
        toolName: toolName,
        payload: payload,
        allowed: false,
        blockedReason: permissionDeniedReason,
      );
      throw StateError('Fail-close: $permissionDeniedReason');
    }

    await _logToolExecution(
      userId: userId,
      actorAgentId: actorAgentId,
      toolName: toolName,
      payload: payload,
      allowed: true,
      blockedReason: null,
    );
  }

  String? _detectDangerousPayload(Map<String, dynamic> payload) {
    final serialized = jsonEncode(payload).toLowerCase();
    if (serialized.length > _maxGuardPayloadLength) {
      return 'Payload is too large.';
    }
    for (final fragment in _dangerousFragments) {
      if (serialized.contains(fragment)) {
        return 'Dangerous payload fragment detected: $fragment';
      }
    }
    return null;
  }

  Future<void> _logToolExecution({
    required String userId,
    required String? actorAgentId,
    required String toolName,
    required Map<String, dynamic> payload,
    required bool allowed,
    required String? blockedReason,
  }) async {
    try {
      await _supabase.from('agent_tool_execution_logs').insert({
        'user_id': userId,
        'actor_agent_id': actorAgentId,
        'tool_name': toolName,
        'allowed': allowed,
        'blocked_reason': blockedReason,
        'payload': payload,
      });
    } catch (_) {
      // Keep fail-close behavior even before migration is applied.
    }
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
