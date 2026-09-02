import 'package:flutter/material.dart';

import '../models/agent_memory_entry.dart';
import '../models/agent_message.dart';
import '../models/agent_profile.dart';
import '../models/agent_relationship.dart';
import '../models/agent_task.dart';
import '../services/agent_org_service.dart';
import '../services/lrm_self_correction_planner_service.dart';
import '../services/manus_like_task_service.dart';
import '../services/task_clarity_service.dart';
import '../widgets/agent_gpa_badge.dart';
import '../widgets/task_clarity_badge.dart';
import '../widgets/task_clarity_dialog.dart';

class AgentTaskTemplate {
  final String id;
  final String label;
  final String title;
  final String description;

  const AgentTaskTemplate({
    required this.id,
    required this.label,
    required this.title,
    required this.description,
  });
}

class AgentBoardReactionOption {
  final String id;
  final String emoji;

  const AgentBoardReactionOption({
    required this.id,
    required this.emoji,
  });
}

class AgentOrgPage extends StatefulWidget {
  final AgentOrgService service;
  final TaskClarityEvaluator clarityEvaluator;

  AgentOrgPage({
    super.key,
    AgentOrgService? service,
    TaskClarityEvaluator? clarityEvaluator,
  })  : service = service ?? AgentOrgService(),
        clarityEvaluator = clarityEvaluator ?? const TaskClarityService();

  @override
  State<AgentOrgPage> createState() => _AgentOrgPageState();
}

class _AgentOrgPageState extends State<AgentOrgPage> {
  static const List<AgentTaskTemplate> _taskTemplates = <AgentTaskTemplate>[
    AgentTaskTemplate(
      id: 'call-report',
      label: 'Call Report',
      title: 'Capture incoming call follow-up',
      description:
          'Summarize the caller request, owner, response deadline, and next action so the team can close the loop quickly.',
    ),
    AgentTaskTemplate(
      id: 'estimate-request',
      label: 'Estimate Request',
      title: 'Prepare estimate response',
      description:
          'Outline scope, pricing assumptions, open questions, and a proposed response plan for the customer.',
    ),
    AgentTaskTemplate(
      id: 'meeting-followup',
      label: 'Meeting Follow-up',
      title: 'Execute post-meeting follow-up',
      description:
          'List decisions, owners, deadlines, and the communication needed after the meeting.',
    ),
    AgentTaskTemplate(
      id: 'material-request',
      label: 'Material Request',
      title: 'Collect requested materials',
      description:
          'Gather the requested documents, confirm gaps, and return a ready-to-share package with context.',
    ),
    AgentTaskTemplate(
      id: 'purchase-request',
      label: 'Purchase Request',
      title: 'Review purchase request',
      description:
          'Validate the need, budget impact, approval path, and recommended next step for the purchase.',
    ),
  ];

  static const List<AgentBoardReactionOption> _quickReactionOptions =
      <AgentBoardReactionOption>[
    AgentBoardReactionOption(id: 'thumbs_up', emoji: '👍'),
    AgentBoardReactionOption(id: 'eyes', emoji: '👀'),
    AgentBoardReactionOption(id: 'check', emoji: '✅'),
  ];

  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskDescriptionController =
      TextEditingController();
  final TextEditingController _boardMessageController = TextEditingController();

  AgentOrgSnapshot _snapshot = const AgentOrgSnapshot.empty();
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isPostingBoardMessage = false;
  String? _selectedAssigneeId;
  String? _selectedTaskTemplateId;
  String? _selectedBoardAuthorId;
  String _selectedBoardChannel = AgentOrgService.boardChannels.first.id;
  String? _errorText;
  final Set<String> _reactionRequestsInFlight = <String>{};
  final TextEditingController _secretaryController = TextEditingController();
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _manusObjectiveController =
      TextEditingController();
  final TextEditingController _gpaRequestController = TextEditingController();
  bool _isTalkingToSecretary = false;
  bool _isSettingGoal = false;
  bool _isRunningManusPlan = false;
  bool _isRunningGpaPlan = false;
  String? _secretaryReply;
  ManusLikeTaskPlan? _latestManusPlan;
  LrmSelfCorrectionPlan? _latestGpaPlan;

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _taskDescriptionController.dispose();
    _boardMessageController.dispose();
    _secretaryController.dispose();
    _goalController.dispose();
    _manusObjectiveController.dispose();
    _gpaRequestController.dispose();
    super.dispose();
  }

  List<AgentProfile> get _delegableAgents => _snapshot.agents
      .where(
        (agent) => agent.slug != 'ceo' && agent.isActive,
      )
      .toList();

  List<AgentProfile> get _boardAuthors =>
      _snapshot.agents.where((agent) => agent.isActive).toList();

  AgentProfile? get _ceoAgent {
    for (final agent in _snapshot.agents) {
      if (agent.slug == 'ceo') {
        return agent;
      }
    }
    return null;
  }

  AgentTaskTemplate? get _selectedTaskTemplate {
    for (final template in _taskTemplates) {
      if (template.id == _selectedTaskTemplateId) {
        return template;
      }
    }
    return null;
  }

  AgentProfile? _findAgentBySlug(String slug) {
    for (final agent in _snapshot.agents) {
      if (agent.slug == slug) return agent;
    }
    return null;
  }

  List<String> _getPersonalityTraits(AgentProfile agent) {
    final meta = agent.metadata;
    final metaPersonality = meta['personality'];
    if (metaPersonality is List) {
      return metaPersonality.whereType<String>().toList();
    }
    if (metaPersonality is String && metaPersonality.isNotEmpty) {
      return [metaPersonality];
    }
    const slugTraits = <String, List<String>>{
      'ceo': ['決断力', '大局観', 'リーダーシップ'],
      'secretary': ['正確性', '段取り力', '気配り'],
      'cfo': ['慎重', '数字重視', '分析的'],
      'accountant': ['正確性', '期限厳守', '几帳面'],
      'cmo': ['創造的', '前向き', '行動力'],
      'ad-planner': ['ROI志向', 'クリエイティブ', 'データ分析'],
      'cho': ['共感的', '継続重視', '丁寧'],
      'chro': ['体系的', '公平', '規律重視'],
      'recruiter': ['人材発掘', '選考力', 'コミュニケーション'],
      'planning-director': ['構想力', '市場感覚', '実行計画'],
      'product-manager': ['ユーザー視点', '優先順位付け', '調整力'],
      'cto': ['技術力', '設計思考', '品質重視'],
      'frontend-dev': ['UI感覚', '実装力', 'パフォーマンス'],
      'backend-dev': ['堅牢性', 'DB設計', 'セキュリティ'],
      'sales-director': ['数字コミット', '交渉力', '開拓精神'],
      'inside-sales': ['効率的', 'リード管理', '粘り強さ'],
      'cs-director': ['傾聴力', '問題解決', '顧客志向'],
      'legal-director': ['慎重', 'リスク管理', '論理的'],
      'pr-director': ['発信力', 'メディア感覚', 'ブランド意識'],
      'procurement-director': ['交渉力', 'コスト意識', '調達戦略'],
    };
    return slugTraits[agent.slug] ?? const <String>[];
  }

  AgentProfile? _findBestAgentForInput(String text) {
    final lower = text.toLowerCase();
    const departmentKeywords = <String, List<String>>{
      'cfo': [
        '費用',
        'コスト',
        '予算',
        '収入',
        '節約',
        '固定費',
        '支出',
        'お金',
        '資金',
        '財務',
        '経理',
      ],
      'cmo': [
        '流入',
        '登録',
        'sns',
        '宣伝',
        'マーケ',
        'lp',
        'ツイート',
        '認知',
        '広告',
        'キャンペーン',
      ],
      'cho': ['体調', '睡眠', '運動', '食事', '健康', '休息', '生活', '疲れ'],
      'chro': ['習慣', '評価', '報酬', 'ルール', '制度', '継続', '人事', '採用'],
      'planning-director': ['企画', '新規事業', 'ロードマップ', '市場調査', '戦略'],
      'cto': ['開発', 'コード', 'バグ', '技術', 'アーキテクチャ', 'デプロイ', 'flutter'],
      'sales-director': ['売上', '営業', '受注', '商談', '顧客開拓', 'リード'],
      'cs-director': ['サポート', 'チケット', '問い合わせ', '顧客満足', 'cs', 'カスタマー'],
      'legal-director': ['法務', '契約', '利用規約', 'プライバシー', 'コンプライアンス', '知的財産'],
      'pr-director': ['広報', 'プレスリリース', 'メディア', 'ブランド', '取材'],
      'procurement-director': ['調達', 'ベンダー', 'ツール選定', '外注', '契約管理'],
    };
    for (final entry in departmentKeywords.entries) {
      for (final keyword in entry.value) {
        if (lower.contains(keyword)) {
          return _findAgentBySlug(entry.key);
        }
      }
    }
    return null;
  }

  String? _defaultBoardAuthorIdForSnapshot(AgentOrgSnapshot snapshot) {
    for (final agent in snapshot.agents) {
      if (agent.slug == 'ceo' && agent.isActive) {
        return agent.id;
      }
    }
    for (final agent in snapshot.agents) {
      if (agent.isActive) {
        return agent.id;
      }
    }
    return null;
  }

  AgentBoardChannel get _selectedBoardChannelConfig {
    for (final channel in AgentOrgService.boardChannels) {
      if (channel.id == _selectedBoardChannel) {
        return channel;
      }
    }
    return AgentOrgService.boardChannels.first;
  }

  String? _boardChannelFor(AgentMessage message) {
    final raw = message.metadata['channel']?.toString().trim().toLowerCase();
    if (!AgentOrgService.isSupportedBoardChannel(raw)) {
      return null;
    }
    return raw;
  }

  List<AgentMessage> get _boardMessages => _snapshot.recentMessages
      .where((message) => message.messageKind == 'board')
      .toList();

  List<AgentMessage> get _directMessages => _snapshot.recentMessages
      .where((message) => message.messageKind != 'board')
      .toList();

  Map<String, int> get _boardMessageCounts {
    final counts = <String, int>{};
    for (final message in _boardMessages) {
      final channel = _boardChannelFor(message);
      if (channel == null) {
        continue;
      }
      counts[channel] = (counts[channel] ?? 0) + 1;
    }
    return counts;
  }

  List<AgentMessage> get _selectedBoardMessages => _boardMessages
      .where((message) => _boardChannelFor(message) == _selectedBoardChannel)
      .toList();

  Future<void> _loadSnapshot() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final snapshot = await widget.service.loadSnapshot();
      if (!mounted) {
        return;
      }
      final delegable = snapshot.agents
          .where(
            (agent) => agent.slug != 'ceo' && agent.isActive,
          )
          .toList();
      setState(() {
        _snapshot = snapshot;
        _selectedAssigneeId =
            delegable.any((agent) => agent.id == _selectedAssigneeId)
                ? _selectedAssigneeId
                : (delegable.isNotEmpty ? delegable.first.id : null);
        _selectedBoardAuthorId = snapshot.agents.any(
          (agent) => agent.isActive && agent.id == _selectedBoardAuthorId,
        )
            ? _selectedBoardAuthorId
            : _defaultBoardAuthorIdForSnapshot(snapshot);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = 'AI組織の初期化に失敗しました: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitDelegation() async {
    final ceoAgent = _ceoAgent;
    final assigneeId = _selectedAssigneeId;
    if (ceoAgent == null || assigneeId == null) {
      return;
    }

    final title = _taskTitleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('委任タスクのタイトルを入力してください。')),
      );
      return;
    }

    final description = _taskDescriptionController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final evaluation = await widget.clarityEvaluator.evaluate(
        title: title,
        description: description,
      );
      final task = await widget.service.delegateTask(
        supervisorAgentId: ceoAgent.id,
        assigneeAgentId: assigneeId,
        title: title,
        description: description,
        metadata: <String, dynamic>{
          'clarity': evaluation.toMetadata(),
        },
      );
      if (!mounted) {
        return;
      }

      String? clarityWarning;
      if (evaluation.needsClarification) {
        final answers = await showTaskClarityDialog(
          context: context,
          evaluation: evaluation,
        );
        if (!mounted) {
          return;
        }
        if (answers != null) {
          try {
            await widget.service.updateTaskClarity(
              taskId: task.id,
              clarity: evaluation.toMetadata(answers: answers),
            );
          } catch (error) {
            clarityWarning = 'タスクは作成されましたが、明確化回答の保存に失敗しました: $error';
          }
        }
      }

      if (!mounted) {
        return;
      }

      _taskTitleController.clear();
      _taskDescriptionController.clear();
      setState(() => _selectedTaskTemplateId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CEOから役員へタスクを委任しました。')),
      );
      if (clarityWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(clarityWarning)),
        );
      }
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('委任に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _setTaskStatus(AgentTask task, String status) async {
    try {
      await widget.service.updateTaskStatus(taskId: task.id, status: status);
      if (!mounted) {
        return;
      }
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('タスク更新に失敗しました: $error')),
      );
    }
  }

  Future<void> _toggleAgentStatus(AgentProfile agent) async {
    try {
      await widget.service.setAgentStatus(
        agentId: agent.id,
        enabled: !agent.isActive,
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エージェント状態の更新に失敗しました: $error')),
      );
    }
  }

  Future<void> _openMemoryDialog(AgentProfile agent) async {
    final controller = TextEditingController();
    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('${agent.displayName} の記憶を追加'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '引き継ぎ・判断基準・注意事項',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );

      if (submitted != true) {
        return;
      }
      await widget.service.appendMemoryEntry(
        agentId: agent.id,
        content: controller.text.trim(),
        memoryLayer: 'state',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${agent.displayName} の記憶を保存しました。')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('記憶の保存に失敗しました: $error')),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _postBoardMessage() async {
    final authorId = _selectedBoardAuthorId;
    final message = _boardMessageController.text.trim();
    if (authorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose an active agent before posting.')),
      );
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a board update before posting.')),
      );
      return;
    }

    setState(() => _isPostingBoardMessage = true);
    try {
      await widget.service.postBoardMessage(
        fromAgentId: authorId,
        channel: _selectedBoardChannel,
        summary: message,
      );
      if (!mounted) {
        return;
      }
      _boardMessageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Posted to #${_selectedBoardChannelConfig.label}.',
          ),
        ),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Board post failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isPostingBoardMessage = false);
      }
    }
  }

  Future<void> _talkToSecretary() async {
    final text = _secretaryController.text.trim();
    if (text.isEmpty) return;
    final ceoAgent = _ceoAgent;
    if (ceoAgent == null) return;

    setState(() => _isTalkingToSecretary = true);
    try {
      final bestAgent = _findBestAgentForInput(text) ?? ceoAgent;
      await widget.service.delegateTask(
        supervisorAgentId: ceoAgent.id,
        assigneeAgentId: bestAgent.id,
        title: text.length > 40 ? '${text.substring(0, 40)}…' : text,
        description: text,
      );
      await widget.service.appendMemoryEntry(
        agentId: ceoAgent.id,
        content: 'ユーザーの発言: $text',
        memoryLayer: 'episodes',
      );
      if (!mounted) return;
      setState(() {
        _secretaryReply = bestAgent.id == ceoAgent.id
            ? 'CEOが受け付けました'
            : '${bestAgent.displayName}（${bestAgent.department}）に委任しました';
      });
      _secretaryController.clear();
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('秘書エラー: $error')),
      );
    } finally {
      if (mounted) setState(() => _isTalkingToSecretary = false);
    }
  }

  Future<void> _setProjectGoal() async {
    final goal = _goalController.text.trim();
    if (goal.isEmpty) return;
    final ceoAgent = _ceoAgent;
    if (ceoAgent == null) return;

    setState(() => _isSettingGoal = true);
    try {
      await widget.service.postBoardMessage(
        fromAgentId: ceoAgent.id,
        channel: 'executive',
        summary: '【プロジェクトゴール】$goal',
      );
      final assignments = <Map<String, String>>[
        {'slug': 'secretary', 'title': 'ゴール進捗の全社共有スケジュール策定'},
        {'slug': 'cfo', 'title': '財務観点での実現可能性分析・予算確保'},
        {'slug': 'cmo', 'title': 'ゴール達成のための広報・流入施策立案'},
        {'slug': 'cho', 'title': '持続的に取り組むための健康維持計画'},
        {'slug': 'chro', 'title': 'ゴール達成に向けた習慣・評価制度設計'},
        {'slug': 'planning-director', 'title': 'ゴールに基づく事業企画・ロードマップ策定'},
        {'slug': 'cto', 'title': 'ゴール達成に必要な技術要件の洗い出し・開発計画'},
        {'slug': 'sales-director', 'title': 'ゴール達成に向けた営業戦略・売上計画立案'},
        {'slug': 'cs-director', 'title': 'ゴール達成に伴う顧客サポート体制の整備'},
        {'slug': 'legal-director', 'title': 'ゴール達成に必要な法務リスク確認・規約整備'},
        {'slug': 'pr-director', 'title': 'ゴール達成を社外に発信する広報戦略策定'},
        {'slug': 'procurement-director', 'title': 'ゴール達成に必要なツール・リソースの調達計画'},
      ];
      for (final assignment in assignments) {
        final slug = assignment['slug']!;
        final taskTitle = assignment['title']!;
        final agent = _findAgentBySlug(slug);
        if (agent == null) continue;
        await widget.service.delegateTask(
          supervisorAgentId: ceoAgent.id,
          assigneeAgentId: agent.id,
          title: taskTitle,
          description: 'プロジェクトゴール「$goal」達成に向けた${agent.department}部門の取り組み',
        );
      }
      if (!mounted) return;
      _goalController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ゴールを設定し、全部署に展開しました')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ゴール設定エラー: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSettingGoal = false);
    }
  }

  Future<void> _runManusLikePlan() async {
    final objective = _manusObjectiveController.text.trim();
    if (objective.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manusに任せる目的を入力してください。')),
      );
      return;
    }
    final ceoAgent = _ceoAgent;
    if (ceoAgent == null) return;

    final plan = ManusLikeTaskService.buildPlan(
      objective: objective,
      availableAgentSlugs: _snapshot.agents
          .where((agent) => agent.isActive)
          .map(
            (agent) => agent.slug,
          )
          .toSet(),
    );

    setState(() => _isRunningManusPlan = true);
    try {
      await widget.service.postBoardMessage(
        fromAgentId: ceoAgent.id,
        channel: 'executive',
        summary: '【Manus-like実行開始】\n${plan.executionSummary}',
      );

      for (final step in plan.steps) {
        final assignee = _findAgentBySlug(step.agentSlug);
        if (assignee == null || !assignee.isActive) continue;
        await widget.service.delegateTask(
          supervisorAgentId: ceoAgent.id,
          assigneeAgentId: assignee.id,
          title: step.title,
          description: [
            step.description,
            '',
            '期待成果: ${step.expectedOutput}',
            if (step.dependsOn.isNotEmpty)
              '依存ステップ: ${step.dependsOn.join(', ')}',
            'レビューゲート: ${plan.reviewGate}',
          ].join('\n'),
          priority: step.priority,
          taskType: 'manus_like_step',
          source: 'manus_like_autopilot',
        );
      }

      await widget.service.appendMemoryEntry(
        agentId: ceoAgent.id,
        content: 'Manus-like自動実行を開始: ${plan.objective}',
        memoryLayer: 'episodes',
      );

      if (!mounted) return;
      _manusObjectiveController.clear();
      setState(() => _latestManusPlan = plan);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manus-like計画を部門タスクへ自動展開しました。')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Manus-like実行に失敗しました: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRunningManusPlan = false);
    }
  }

  Future<void> _runGpaPlan() async {
    final request = _gpaRequestController.text.trim();
    if (request.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a CEO request for GPA planning.')),
      );
      return;
    }
    final ceoAgent = _ceoAgent;
    if (ceoAgent == null) return;

    final plan = LrmSelfCorrectionPlannerService.buildPlan(
      request: request,
      availableAgentSlugs: _snapshot.agents
          .where((agent) => agent.isActive)
          .map((agent) => agent.slug)
          .toSet(),
    );

    setState(() => _isRunningGpaPlan = true);
    try {
      await widget.service.postBoardMessage(
        fromAgentId: ceoAgent.id,
        channel: 'executive',
        summary: '[LRM GPA draft]\n${plan.executionSummary}',
        payload: plan.toJson(),
      );

      for (final action
          in plan.actions.where((action) => action.kind == 'app_task')) {
        final assignee = _findAgentBySlug(action.ownerAgentSlug);
        if (assignee == null || !assignee.isActive) continue;
        await widget.service.delegateTask(
          supervisorAgentId: ceoAgent.id,
          assigneeAgentId: assignee.id,
          title: action.title,
          description: [
            'Goal: ${plan.goal.title}',
            'Next action: ${action.nextAction}',
            '',
            'Acceptance criteria:',
            ...action.acceptanceCriteria.map((item) => '- $item'),
            '',
            'Self-review requires approval: ${plan.requiresApproval}',
            if (plan.selfReview.missingInfo.isNotEmpty) ...[
              'Missing info:',
              ...plan.selfReview.missingInfo.map((item) => '- $item'),
            ],
            if (plan.selfReview.scopeWarnings.isNotEmpty) ...[
              'Scope warnings:',
              ...plan.selfReview.scopeWarnings.map((item) => '- $item'),
            ],
          ].join('\n'),
          priority: plan.requiresApproval ? 'medium' : 'high',
          taskType: 'lrm_gpa_action',
          source: 'lrm_self_correction_planner',
        );
      }

      await widget.service.appendMemoryEntry(
        agentId: ceoAgent.id,
        content: 'LRM GPA plan generated: ${plan.request}',
        memoryLayer: 'episodes',
        metadata: plan.toJson(),
      );

      if (!mounted) return;
      _gpaRequestController.clear();
      setState(() => _latestGpaPlan = plan);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LRM GPA plan generated.')),
      );
      await _loadSnapshot();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LRM GPA planning failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRunningGpaPlan = false);
    }
  }

  void _applyTaskTemplate(AgentTaskTemplate template) {
    _taskTitleController.text = template.title;
    _taskDescriptionController.text = template.description;
    setState(() => _selectedTaskTemplateId = template.id);
  }

  void _clearTaskTemplate() {
    _taskTitleController.clear();
    _taskDescriptionController.clear();
    setState(() => _selectedTaskTemplateId = null);
  }

  Map<String, List<String>> _reactionActorsFor(AgentMessage message) {
    final reactionActors = <String, List<String>>{};
    final raw = message.metadata['reaction_actor_ids'];
    if (raw is! Map) {
      return reactionActors;
    }
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is! List) {
        continue;
      }
      final actors = value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
      reactionActors[key] = actors;
    }
    return reactionActors;
  }

  int _reactionCountFor(AgentMessage message, String emoji) {
    final actors = _reactionActorsFor(message)[emoji];
    return actors?.length ?? 0;
  }

  bool _isReactionSelected(AgentMessage message, String emoji) {
    final actorId = _selectedBoardAuthorId;
    if (actorId == null) {
      return false;
    }
    final actors = _reactionActorsFor(message)[emoji];
    return actors?.contains(actorId) ?? false;
  }

  void _replaceMessageInSnapshot(AgentMessage updatedMessage) {
    final nextMessages = _snapshot.recentMessages
        .map(
          (message) =>
              message.id == updatedMessage.id ? updatedMessage : message,
        )
        .toList();
    setState(() {
      _snapshot = AgentOrgSnapshot(
        agents: _snapshot.agents,
        tasks: _snapshot.tasks,
        recentMemories: _snapshot.recentMemories,
        relationships: _snapshot.relationships,
        recentMessages: nextMessages,
        openTaskCountsByAgent: _snapshot.openTaskCountsByAgent,
        memoryCountsByAgent: _snapshot.memoryCountsByAgent,
      );
    });
  }

  Future<void> _toggleBoardReaction(
    AgentMessage message,
    AgentBoardReactionOption option,
  ) async {
    final actorId = _selectedBoardAuthorId;
    if (actorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an active agent before reacting.'),
        ),
      );
      return;
    }
    final requestKey = '${message.id}:${option.id}';
    if (_reactionRequestsInFlight.contains(requestKey)) {
      return;
    }

    setState(() => _reactionRequestsInFlight.add(requestKey));
    try {
      final updatedMessage = await widget.service.toggleBoardReaction(
        messageId: message.id,
        emoji: option.emoji,
        actorAgentId: actorId,
      );
      if (!mounted) {
        return;
      }
      if (updatedMessage != null) {
        _replaceMessageInSnapshot(updatedMessage);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reaction failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _reactionRequestsInFlight.remove(requestKey));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAgents =
        _snapshot.agents.where((agent) => agent.isActive).length;
    final unclearTasks =
        _snapshot.tasks.where((task) => task.needsClarification).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI組織OS'),
        backgroundColor: const Color(0xFF3D5AFE),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorText != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSnapshot,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _buildSummaryChip(
                                label: '稼働役員',
                                value:
                                    '$activeAgents / ${_snapshot.agents.length}',
                                color: Colors.green,
                              ),
                              _buildSummaryChip(
                                label: '未完了タスク',
                                value: '${_snapshot.tasks.length}',
                                color: const Color(0xFF3D5AFE),
                              ),
                              _buildSummaryChip(
                                label: '要明確化',
                                value: '$unclearTasks',
                                color: const Color(0xFFD84315),
                              ),
                              _buildSummaryChip(
                                label: '記憶ログ',
                                value: '${_snapshot.recentMemories.length}',
                                color: const Color(0xFF3D5AFE),
                              ),
                              _buildSummaryChip(
                                label: '通信ログ',
                                value: '${_snapshot.recentMessages.length}',
                                color: const Color(0xFFFF6B35),
                              ),
                              _buildSummaryChip(
                                label: '関係マップ',
                                value: '${_snapshot.relationships.length}',
                                color: const Color(0xFF009688),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSecretarySection(),
                      const SizedBox(height: 16),
                      _buildGoalSection(),
                      const SizedBox(height: 16),
                      _buildGpaPlannerSection(),
                      const SizedBox(height: 16),
                      _buildManusLikeSection(),
                      const SizedBox(height: 16),
                      _buildDelegationComposer(),
                      const SizedBox(height: 24),
                      _buildBoardSection(),
                      const SizedBox(height: 24),
                      const Text(
                        'Agent Registry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._snapshot.agents.map(_buildAgentCard),
                      const SizedBox(height: 24),
                      const Text(
                        'agent_tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.tasks.isEmpty)
                        _buildEmptyCard('未完了タスクはありません。')
                      else
                        ..._snapshot.tasks.map(_buildTaskCard),
                      const SizedBox(height: 24),
                      const Text(
                        'agent_relationships',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.relationships.isEmpty)
                        _buildEmptyCard('関係マップはありません。')
                      else
                        ..._snapshot.relationships
                            .take(12)
                            .map(_buildRelationshipCard),
                      const SizedBox(height: 24),
                      const Text(
                        'agent_messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_directMessages.isEmpty)
                        _buildEmptyCard('通信ログはありません。')
                      else
                        ..._directMessages
                            .take(12)
                            .map(_buildStructuredMessageCard),
                      const SizedBox(height: 24),
                      const Text(
                        'Memory Stack (recent)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_snapshot.recentMemories.isEmpty)
                        _buildEmptyCard('まだ記憶ログはありません。')
                      else
                        ..._snapshot.recentMemories
                            .take(8)
                            .map(_buildMemoryCard),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDelegationComposer() {
    final selectedTemplate = _selectedTaskTemplate;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CEO -> 12部署20人 タスク委任',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ここから永続エージェントへタスクを委任します。委任内容は agent_tasks と記憶ログに保存されます。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chatwork-style task templates',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pick a reusable request pattern, then adjust the details before delegating.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _taskTemplates.map((template) {
                return ChoiceChip(
                  key: Key('agent_org_task_template_${template.id}'),
                  label: Text(template.label),
                  selected: _selectedTaskTemplateId == template.id,
                  onSelected: _isSubmitting
                      ? null
                      : (selected) {
                          if (selected) {
                            _applyTaskTemplate(template);
                            return;
                          }
                          _clearTaskTemplate();
                        },
                );
              }).toList(),
            ),
            if (selectedTemplate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selected template: ${selectedTemplate.label}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('agent_org_task_template_clear_button'),
                    onPressed: _isSubmitting ? null : _clearTaskTemplate,
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedAssigneeId),
              initialValue: _selectedAssigneeId,
              decoration: const InputDecoration(
                labelText: '委任先',
                border: OutlineInputBorder(),
              ),
              items: _delegableAgents
                  .map(
                    (agent) => DropdownMenuItem<String>(
                      value: agent.id,
                      child: Text('${agent.displayName} (${agent.department})'),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) => setState(() => _selectedAssigneeId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('agent_org_task_title_field'),
              controller: _taskTitleController,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: '委任タスク',
                hintText: '例: 今日の登録率改善プランを作る',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('agent_org_task_description_field'),
              controller: _taskDescriptionController,
              enabled: !_isSubmitting,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '補足指示',
                hintText: '例: LPの体験導線と認証摩擦を優先で見る',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('agent_org_delegation_submit_button'),
                onPressed: _isSubmitting ? null : _submitDelegation,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('delegateTask を実行'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoardSection() {
    final boardAuthors = _boardAuthors;
    final boardCounts = _boardMessageCounts;

    return Card(
      key: const Key('agent_org_board_section'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Board Channels',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AnimaWorks-style shared channels for cross-team coordination.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AgentOrgService.boardChannels.map((channel) {
                final count = boardCounts[channel.id] ?? 0;
                return ChoiceChip(
                  key: Key('agent_org_board_channel_${channel.id}'),
                  label: Text('#${channel.label} ($count)'),
                  selected: _selectedBoardChannel == channel.id,
                  onSelected: (selected) {
                    if (!selected) {
                      return;
                    }
                    setState(() => _selectedBoardChannel = channel.id);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedBoardChannelConfig.description,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('agent_org_board_author_field'),
              initialValue: _selectedBoardAuthorId,
              decoration: const InputDecoration(
                labelText: 'Speaker',
                border: OutlineInputBorder(),
              ),
              items: boardAuthors
                  .map(
                    (agent) => DropdownMenuItem<String>(
                      value: agent.id,
                      child: Text('${agent.displayName} (${agent.department})'),
                    ),
                  )
                  .toList(),
              onChanged: _isPostingBoardMessage
                  ? null
                  : (value) => setState(() => _selectedBoardAuthorId = value),
            ),
            const SizedBox(height: 8),
            Text(
              'Slack-style quick reactions will use the selected Speaker.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('agent_org_board_message_field'),
              controller: _boardMessageController,
              enabled: !_isPostingBoardMessage,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Post to #${_selectedBoardChannelConfig.label}',
                hintText:
                    'Share blockers, updates, or asks for the whole channel.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('agent_org_board_post_button'),
                onPressed: _isPostingBoardMessage ? null : _postBoardMessage,
                icon: _isPostingBoardMessage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: Text('Post to #${_selectedBoardChannelConfig.label}'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Channel Timeline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            if (_selectedBoardMessages.isEmpty)
              _buildEmptyCard(
                'No posts yet in #${_selectedBoardChannelConfig.label}.',
              )
            else
              ..._selectedBoardMessages.take(10).map(_buildBoardMessageCard),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(AgentProfile agent) {
    final taskCount = _snapshot.openTaskCountsByAgent[agent.id] ?? 0;
    final memoryCount = _snapshot.memoryCountsByAgent[agent.id] ?? 0;
    final cardColor = agent.isActive
        ? const Color(0xFF3D5AFE)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cardColor.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: cardColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${agent.displayName} (${agent.roleTitle})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        agent.department,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    agent.isActive ? '稼働中' : '停止中',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cardColor,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              agent.identityPrompt,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _getPersonalityTraits(agent)
                  .map(
                    (trait) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: cardColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        trait,
                        style: TextStyle(
                          fontSize: 11,
                          color: cardColor,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            Text(
              '権限: ${agent.permissionsSummary}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniTag(
                  icon: Icons.assignment_late_outlined,
                  label: '未完了 $taskCount',
                  color: const Color(0xFF3D5AFE),
                ),
                _buildMiniTag(
                  icon: Icons.memory,
                  label: '記憶 $memoryCount',
                  color: const Color(0xFF3D5AFE),
                ),
                if (agent.lastActiveAt != null)
                  _buildMiniTag(
                    icon: Icons.schedule,
                    label:
                        '最終稼働 ${agent.lastActiveAt!.month}/${agent.lastActiveAt!.day} ${agent.lastActiveAt!.hour.toString().padLeft(2, '0')}:${agent.lastActiveAt!.minute.toString().padLeft(2, '0')}',
                    color: const Color(0xFF009688),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openMemoryDialog(agent),
                  icon: const Icon(Icons.note_add),
                  label: const Text('記憶を追加'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _toggleAgentStatus(agent),
                  icon: Icon(
                    agent.isActive
                        ? Icons.pause_circle_outline
                        : Icons.play_arrow,
                  ),
                  label: Text(agent.isActive ? '休止' : '再開'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(AgentTask task) {
    AgentProfile? assignee;
    for (final agent in _snapshot.agents) {
      if (agent.id == task.assigneeAgentId) {
        assignee = agent;
        break;
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
                _buildStatusBadge(task.status),
              ],
            ),
            if (assignee != null) ...[
              const SizedBox(height: 6),
              Text(
                '担当: ${assignee.displayName} (${assignee.department})',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                task.description,
                style: const TextStyle(
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniTag(
                  icon: Icons.flag_outlined,
                  label: '優先度 ${task.priority}',
                  color: const Color(0xFFFF6B35),
                ),
                _buildMiniTag(
                  icon: Icons.inventory_2_outlined,
                  label: task.taskType,
                  color: const Color(0xFF3D5AFE),
                ),
                TaskClarityBadge(task: task),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (task.isQueued)
                  FilledButton.tonalIcon(
                    onPressed: () => _setTaskStatus(task, 'in_progress'),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('着手'),
                  ),
                if (!task.isCompleted)
                  FilledButton.icon(
                    onPressed: () => _setTaskStatus(task, 'completed'),
                    icon: const Icon(Icons.check),
                    label: const Text('完了'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AgentProfile? _findAgentById(String id) {
    for (final agent in _snapshot.agents) {
      if (agent.id == id) {
        return agent;
      }
    }
    return null;
  }

  Widget _buildRelationshipCard(AgentRelationship relationship) {
    final from = _findAgentById(relationship.fromAgentId);
    final to = _findAgentById(relationship.toAgentId);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.alt_route, color: Color(0xFF009688)),
        title: Text(
          '${from?.displayName ?? relationship.fromAgentId} -> ${to?.displayName ?? relationship.toAgentId}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          '${relationship.relationshipType} / ${relationship.communicationProtocol}',
          style: const TextStyle(height: 1.4),
        ),
        trailing: _buildStatusBadge(relationship.status),
      ),
    );
  }

  Widget _buildBoardMessageCard(AgentMessage message) {
    final from = _findAgentById(message.fromAgentId);
    final channelId = _boardChannelFor(message) ?? _selectedBoardChannel;
    final channel = AgentOrgService.boardChannels.firstWhere(
      (item) => item.id == channelId,
      orElse: () => _selectedBoardChannelConfig,
    );
    final createdAt = message.createdAt;
    final timestamp =
        '${createdAt.month}/${createdAt.day} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    from?.displayName ?? message.fromAgentId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                AgentGpaBadge(
                  sourceType: 'executive_chat',
                  sourceId: message.id,
                ),
                const SizedBox(width: 8),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMiniTag(
                  icon: Icons.tag,
                  label: '#${channel.label}',
                  color: const Color(0xFF3D5AFE),
                ),
                _buildMiniTag(
                  icon: Icons.forum_outlined,
                  label: message.status,
                  color: const Color(0xFFFF6B35),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.summary,
              style: const TextStyle(height: 1.45),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickReactionOptions.map((option) {
                final isSelected = _isReactionSelected(message, option.emoji);
                final count = _reactionCountFor(message, option.emoji);
                final requestKey = '${message.id}:${option.id}';
                final isBusy = _reactionRequestsInFlight.contains(requestKey);
                final label =
                    count > 0 ? '${option.emoji} $count' : option.emoji;
                return FilterChip(
                  key: Key(
                    'agent_org_board_reaction_${message.id}_${option.id}',
                  ),
                  label: Text(label),
                  selected: isSelected,
                  onSelected: isBusy
                      ? null
                      : (_) => _toggleBoardReaction(message, option),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredMessageCard(AgentMessage message) {
    if (message.messageKind == 'board') {
      return _buildBoardMessageCard(message);
    }
    final from = _findAgentById(message.fromAgentId);
    final to = _findAgentById(message.toAgentId);
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${from?.displayName ?? message.fromAgentId} -> ${to?.displayName ?? message.toAgentId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                AgentGpaBadge(
                  sourceType: 'executive_chat',
                  sourceId: message.id,
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(message.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${message.messageKind}: ${message.summary}',
              style: const TextStyle(height: 1.4),
            ),
            if (message.linkedTaskId != null &&
                message.linkedTaskId!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'task: ${message.linkedTaskId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryCard(AgentMemoryEntry memory) {
    AgentProfile? owner;
    for (final agent in _snapshot.agents) {
      if (agent.id == memory.agentId) {
        owner = agent;
        break;
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.memory, color: Color(0xFF3D5AFE)),
        title: Text(
          owner == null
              ? memory.memoryLayer
              : '${owner.displayName} / ${memory.memoryLayer}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            memory.content,
            style: const TextStyle(height: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final Color color;
    switch (status) {
      case 'active':
      case 'sent':
        color = const Color(0xFF009688);
        break;
      case 'completed':
      case 'resolved':
        color = Colors.green;
        break;
      case 'acknowledged':
      case 'in_progress':
        color = const Color(0xFF3D5AFE);
        break;
      default:
        color = const Color(0xFFFF6B35);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecretarySection() {
    return Card(
      elevation: 2,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFE8EAF6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.support_agent, color: Color(0xFF3D5AFE)),
                SizedBox(width: 8),
                Text(
                  '秘書に話しかける',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '自然な言葉で伝えると、秘書が最適な担当エージェントへタスクを振り分けます。会話は記憶ログに保存されます。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _secretaryController,
              enabled: !_isTalkingToSecretary,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '例: 今月の固定費を10%減らしたい',
                hintText: '財務・広報・健康・人事など、何でも話しかけてください',
                border: OutlineInputBorder(),
              ),
            ),
            if (_secretaryReply != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC5CAE9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF3D5AFE),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _secretaryReply!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF3D5AFE),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isTalkingToSecretary ? null : _talkToSecretary,
                icon: _isTalkingToSecretary
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('秘書に送る'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpaPlannerSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = _latestGpaPlan;
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF15211A) : const Color(0xFFEAF7EE),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.fact_check, color: Color(0xFF047857)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LRM Goal-Plan-Action',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gpaRequestController,
              enabled: !_isRunningGpaPlan,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'CEO request',
                hintText: 'Reduce cloud cost by 20% before the May review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRunningGpaPlan ? null : _runGpaPlan,
                icon: _isRunningGpaPlan
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.schema),
                label: const Text('Generate GPA plan'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                ),
              ),
            ),
            if (plan != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF06140D) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF047857).withValues(alpha: 0.28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.strategyLabel,
                      style: const TextStyle(
                        color: Color(0xFF047857),
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      initiallyExpanded: true,
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Goal'),
                      subtitle: Text(plan.goal.title),
                      children: [
                        _buildGpaBulletList(
                          'Success',
                          plan.goal.successCriteria,
                        ),
                        _buildGpaBulletList(
                          'Constraints',
                          plan.goal.constraints,
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree_outlined),
                      title: const Text('Plan'),
                      children: plan.plan
                          .map(
                            (step) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    const Color(0xFF047857).withValues(
                                  alpha: 0.12,
                                ),
                                child: Text(
                                  '${step.stepNumber}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              title: Text(step.title),
                              subtitle: Text(
                                '${step.phase} / ${step.agentSlug}\n${step.doneWhen}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.task_alt_outlined),
                      title: const Text('Action drafts'),
                      children: plan.actions
                          .map(
                            (action) => ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(action.title),
                              subtitle: Text(
                                '${action.kind} / ${action.ownerAgentSlug}\n${action.nextAction}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      leading: Icon(
                        plan.requiresApproval
                            ? Icons.lock_outline
                            : Icons.verified_user_outlined,
                        color: plan.requiresApproval
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF047857),
                      ),
                      title: Text(
                        plan.requiresApproval
                            ? 'Self-review: approval required'
                            : 'Self-review: ready for internal draft',
                      ),
                      children: [
                        _buildGpaBulletList(
                          'Missing info',
                          plan.selfReview.missingInfo.isEmpty
                              ? const <String>['None flagged']
                              : plan.selfReview.missingInfo,
                        ),
                        _buildGpaBulletList(
                          'Scope warnings',
                          plan.selfReview.scopeWarnings.isEmpty
                              ? const <String>['None flagged']
                              : plan.selfReview.scopeWarnings,
                        ),
                        _buildGpaBulletList(
                          'Safety',
                          plan.selfReview.safetyChecks,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGpaBulletList(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '- $item',
                style: const TextStyle(fontSize: 12, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManusLikeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = _latestManusPlan;
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome_motion, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manus-like マルチステップ自動実行',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '目的を1つ入れると、要件整理、KGI/CSF/KPI設計、主担当案、専門レビュー、CEO確認までを部門タスクに分解します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manusObjectiveController,
              enabled: !_isRunningManusPlan,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Manusに任せる目的',
                hintText: '例: AI大学の離脱率を下げる改善案を今日中に実行可能な形にする',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isRunningManusPlan ? null : _runManusLikePlan,
                icon: _isRunningManusPlan
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check_circle),
                label: const Text('部門タスクへ自動展開'),
              ),
            ),
            if (plan != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0C1A2A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1D3A6A)
                        : const Color(0xFFBFDBFE),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.strategyLabel,
                      style: const TextStyle(
                        color: Color(0xFF1D4ED8),
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...plan.steps.map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${step.stepNumber}. ${step.agentSlug} / ${step.title}',
                          style: const TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ),
                    ),
                    Text(
                      plan.reviewGate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGoalSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF2A1F0A) : const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flag, color: Color(0xFFFF6B35)),
                SizedBox(width: 8),
                Text(
                  'プロジェクトゴール展開',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ゴールを1つ入力するとCEOが全部署に役割分担して展開します。部署間で内容が被らないよう自動設計します。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              enabled: !_isSettingGoal,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'ゴール',
                hintText: '例: 今月中に新規登録者100人達成',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildDeptTag('CEO室', 'CEO', const Color(0xFFFFC107)),
                _buildDeptTag('CFO室', 'CFO', const Color(0xFF3D5AFE)),
                _buildDeptTag('CMO室', 'CMO', Colors.green),
                _buildDeptTag('CHO室', 'CHO', Colors.red),
                _buildDeptTag('CHRO室', 'CHRO', const Color(0xFF3D5AFE)),
                _buildDeptTag('企画部', '企画', const Color(0xFF009688)),
                _buildDeptTag('開発部', 'CTO', const Color(0xFF3D5AFE)),
                _buildDeptTag('営業部', '営業', const Color(0xFFFF6B35)),
                _buildDeptTag('CS部', 'CS', const Color(0xFF00BCD4)),
                _buildDeptTag('法務部', '法務', const Color(0xFF795548)),
                _buildDeptTag('広報部', '広報', const Color(0xFFFF6B35)),
                _buildDeptTag('調達部', '調達', const Color(0xFF9CA3AF)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSettingGoal ? null : _setProjectGoal,
                icon: _isSettingGoal
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rocket_launch),
                label: const Text('全部署に展開'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptTag(String dept, String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$role ($dept)',
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
