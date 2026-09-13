import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/agent_org_service.dart';
import 'package:my_web_app/services/emergency_meeting_pdca_service.dart';
import 'package:my_web_app/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../widgets/agent_gpa_badge.dart';

enum MeetingFocus {
  balanced,
  continuation,
  abstinence,
}

class EmergencyMeetingPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;
  final BoardMeetingLog? initialLog;
  final List<String> initialContinuationPlan;
  final List<String> initialAbstinenceRules;
  final EmergencyMeetingPdcaMetrics? initialMetrics;

  const EmergencyMeetingPage({
    super.key,
    this.supabaseClient,
    this.initialLog,
    this.initialContinuationPlan = const <String>[],
    this.initialAbstinenceRules = const <String>[],
    this.initialMetrics,
  });

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  static const List<String> _boardMeetingSupportedModels = <String>[
    'claude-sonnet-4-6',
    'gpt-5.4',
    'gpt-4o-mini',
    'claude-3-haiku-20240307',
    'gemini-2.5-flash',
    'gemma-3n-e2b-it',
    'deepseek-chat',
  ];

  static List<Map<String, dynamic>> _defaultBoardMeetingModels() {
    return _boardMeetingSupportedModels
        .map(
          (name) => <String, dynamic>{
            'name': name,
            'methods': const <String>['hold_board_meeting'],
          },
        )
        .toList();
  }

  final ScrollController _scrollController = ScrollController();
  final AgentOrgService _agentOrgService = AgentOrgService();
  final EmergencyMeetingBiReportService _meetingReportService =
      EmergencyMeetingBiReportService();
  BoardMeetingLog? _currentLog;
  bool _isLoading = false;
  String _loadingStatus = '';

  String _selectedModel = _boardMeetingSupportedModels.first;
  MeetingFocus _selectedFocus = MeetingFocus.balanced;
  List<String> _continuationPlan = <String>[];
  List<String> _abstinenceRules = <String>[];
  List<bool> _continuationChecks = <bool>[];
  List<bool> _abstinenceChecks = <bool>[];
  String? _riskAlert;
  String? _decodeNotice;
  List<String> _executionHubLogs = <String>[];
  String? _executionHubError;
  int _abstinenceViolationCount = 0;
  int _abstinenceNoViolationDays = 0;
  int _lastContinuationCompletionRate = 0;
  int _continuationPriorityDeclaredCount = 0;
  int _continuationQuickStartCount = 0;
  int _continuationFocusSprint25Count = 0;
  int _continuationTimeBlockReservedCount = 0;
  int _continuationProgressLogCount = 0;
  int _deepWorkSessionCount = 0;
  int _weeklyPriorityReviewCount = 0;
  int _accountabilityShareCount = 0;
  int _abstinenceRecoveryActionCount = 0;
  int _abstinenceRecoveredWithin10mCount = 0;
  int _abstinenceRecoveryWindowMissedCount = 0;
  int _deterrenceStrictModeBlockCount = 0;
  int _deterrenceDisableAttemptBlockedCount = 0;
  int _abstinenceRecoveryReminderScheduledCount = 0;
  bool _dailyReminderEnabled = false;
  bool _lockImpulsePurchase = false;
  bool _lockNewProjects = false;
  bool _lockSubscriptionAdditions = false;
  int _selectedContinuationPriorityIndex = -1;
  DateTime? _abstinenceRecoveryDueAt;
  DateTime? _lastReviewAt;
  List<Map<String, dynamic>> _selectableModels = _defaultBoardMeetingModels();
  static const EmergencyMeetingPdcaGuardrails _pdcaGuardrails =
      EmergencyMeetingPdcaGuardrails();
  final String _customPromptInstructions = _defaultPromptInstructions;
  static const String _prefsAbstinenceViolationCount =
      'emergency_abstinence_violation_count';
  static const String _prefsAbstinenceNoViolationDays =
      'emergency_abstinence_no_violation_days';
  static const String _prefsContinuationCompletionRate =
      'emergency_continuation_completion_rate';
  static const String _prefsContinuationPriorityDeclaredCount =
      'emergency_continuation_priority_declared_count';
  static const String _prefsContinuationQuickStartCount =
      'emergency_continuation_quick_start_count';
  static const String _prefsContinuationFocusSprint25Count =
      'emergency_continuation_focus_sprint_25_count';
  static const String _prefsContinuationTimeBlockReservedCount =
      'emergency_continuation_time_block_reserved_count';
  static const String _prefsContinuationProgressLogCount =
      'emergency_continuation_progress_log_count';
  static const String _prefsDeepWorkSessionCount =
      'emergency_deep_work_session_count';
  static const String _prefsWeeklyPriorityReviewCount =
      'emergency_weekly_priority_review_count';
  static const String _prefsAccountabilityShareCount =
      'emergency_accountability_share_count';
  static const String _prefsAbstinenceRecoveryActionCount =
      'emergency_abstinence_recovery_action_count';
  static const String _prefsAbstinenceRecoveredWithin10mCount =
      'emergency_abstinence_recovered_within_10m_count';
  static const String _prefsAbstinenceRecoveryWindowMissedCount =
      'emergency_abstinence_recovery_window_missed_count';
  static const String _prefsDeterrenceStrictModeBlockCount =
      'emergency_deterrence_strict_mode_block_count';
  static const String _prefsDeterrenceDisableAttemptBlockedCount =
      'emergency_deterrence_disable_attempt_blocked_count';
  static const String _prefsAbstinenceRecoveryReminderScheduledCount =
      'emergency_abstinence_recovery_reminder_scheduled_count';
  static const String _prefsAbstinenceRecoveryDueAt =
      'emergency_abstinence_recovery_due_at';
  static const String _prefsDailyReminderEnabled =
      'emergency_daily_reminder_enabled';
  static const String _prefsLockImpulsePurchase = 'emergency_lock_impulse';
  static const String _prefsLockNewProjects = 'emergency_lock_new_projects';
  static const String _prefsLockSubscriptionAdditions =
      'emergency_lock_subscription_additions';
  static const String _prefsSelectedContinuationPriorityIndex =
      'emergency_selected_continuation_priority_index';
  static const String _prefsLastReviewAt = 'emergency_last_review_at';
  static const String _defaultPromptInstructions =
      'あなたは「自分株式会社」の緊急役員会議ファシリテーターです。\n'
      'テーマは必ず「継続」と「禁欲」。感情論ではなく、実行しやすい行動に落とし込んでください。\n\n'
      '【会議フォーカス】\n'
      '- focusTheme: {focusTheme}\n'
      '- focusInstruction: {focusInstruction}\n\n'
      '【現状データ】\n'
      '- userId: {userId}\n'
      '- noteCount: {noteCount}\n'
      '- subCount: {subCount}\n'
      '- points: {points}\n'
      '- level: {level}\n'
      '- currentStreak: {currentStreak}\n'
      '- danshariCount: {danshariCount}\n'
      '- continuationCompletionRate: {continuationCompletionRate}\n'
      '- abstinenceViolationCount: {abstinenceViolationCount}\n'
      '- abstinenceNoViolationDays: {abstinenceNoViolationDays}\n'
      '- abstinenceRuleCompletionRate: {abstinenceRuleCompletionRate}\n'
      '- deepWorkSessionCount: {deepWorkSessionCount}\n'
      '- continuationQuickStartCount: {continuationQuickStartCount}\n'
      '- continuationTimeBlockReservedCount: {continuationTimeBlockReservedCount}\n'
      '- continuationProgressLogCount: {continuationProgressLogCount}\n'
      '- weeklyPriorityReviewCount: {weeklyPriorityReviewCount}\n'
      '- accountabilityShareCount: {accountabilityShareCount}\n'
      '- abstinenceRecoveryActionCount: {abstinenceRecoveryActionCount}\n'
      '- abstinenceRecoveredWithin10mCount: {abstinenceRecoveredWithin10mCount}\n'
      '- abstinenceRecoveryWindowMissedCount: {abstinenceRecoveryWindowMissedCount}\n'
      '- deterrenceLockEnabledCount: {deterrenceLockEnabledCount}\n'
      '- deterrenceStrictModeBlockCount: {deterrenceStrictModeBlockCount}\n'
      '- deterrenceLockCoveragePercent: {deterrenceLockCoveragePercent}\n'
      '- activeDeterrenceLocks: {activeDeterrenceLocks}\n'
      '- healthData: "データ未連携"\n'
      '- marketData: "データ未連携"\n'
      '- importUsed: "未確認"\n\n'
      '【役員構成】\n'
      '- CFO: 支出とサブスクの最適化\n'
      '- CMO: 流入、登録率、導線改善\n'
      '- CHRO: 習慣維持とモチベーション管理\n'
      '- CEO: 全体戦略と実行計画の統合\n\n'
      '【出力ルール】\n'
      '1. messages は3〜5件。CFO / CMO / CHRO の提言を必ず含める。\n'
      '2. continuation_plan は「48時間以内に実行する継続アクション」を3件。\n'
      '3. abstinence_rules は「誘惑を断つ禁欲ルール」を3件。\n'
      '4. risk_alert は最大リスクを1文で示す。\n'
      '5. conclusion は CEO が今週やる最優先アクションを1〜2文で示す。\n'
      '6. next_meeting_metrics に以下を必ず含める: continuation_priority_declared_count, '
      'continuation_quick_start_count, continuation_focus_sprint_25_count, '
      'abstinence_rule_completion_rate_percent, abstinence_recovery_action_count, '
      'deterrence_lock_enabled_count, deterrence_disable_attempt_blocked_count, '
      'continuation_time_block_reserved_count, abstinence_recovered_within_10m_count, '
      'abstinence_recovery_window_missed_count, abstinence_recovery_reminder_scheduled_count。\n'
      '7. 返答はJSONのみ。Markdownや説明文は不要。\n\n'
      '{\n'
      '  "messages": [\n'
      '    {"role":"CFO","speaker_name":"AI CFO","content":"..."},\n'
      '    {"role":"CMO","speaker_name":"AI CMO","content":"..."},\n'
      '    {"role":"CHRO","speaker_name":"AI CHRO","content":"..."},\n'
      '    {"role":"CEO","speaker_name":"AI CEO","content":"..."}\n'
      '  ],\n'
      '  "continuation_plan": ["...", "...", "..."],\n'
      '  "abstinence_rules": ["...", "...", "..."],\n'
      '  "risk_alert": "...",\n'
      '  "conclusion": "...",\n'
      '  "next_meeting_metrics": {\n'
      '    "continuation_priority_declared_count": 0,\n'
      '    "continuation_quick_start_count": 0,\n'
      '    "continuation_focus_sprint_25_count": 0,\n'
      '    "continuation_time_block_reserved_count": 0,\n'
      '    "abstinence_rule_completion_rate_percent": 0,\n'
      '    "abstinence_recovery_action_count": 0,\n'
      '    "abstinence_recovered_within_10m_count": 0,\n'
      '    "abstinence_recovery_window_missed_count": 0,\n'
      '    "deterrence_strict_mode_block_count": 0,\n'
      '    "deterrence_disable_attempt_blocked_count": 0,\n'
      '    "deterrence_lock_enabled_count": 0,\n'
      '    "deterrence_lock_coverage_percent": 0,\n'
      '    "abstinence_recovery_reminder_scheduled_count": 0\n'
      '  }\n'
      '}';

  // Supabase client getter
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    assert(_defaultPromptInstructions.isNotEmpty);
    assert(_focusLabel(MeetingFocus.balanced).isNotEmpty);
    assert(_focusShortLabel(MeetingFocus.balanced).isNotEmpty);
    assert(_focusInstruction(MeetingFocus.balanced).isNotEmpty);
    assert(() {
      _conveneBoard;
      return true;
    }());
    _loadSettings(); // Changed from _fetchModels
    _loadPdcaState();
  }

  // --- Start of new functions ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedModel = prefs.getString('gemini_model_emergency_meeting') ??
        prefs.getString('gemini_model');
    final normalizedModel = _normalizeBoardMeetingModel(savedModel);
    if (mounted) {
      setState(() {
        _selectedModel = normalizedModel;
        _selectableModels = _defaultBoardMeetingModels();
      });
    }
    if (savedModel != normalizedModel) {
      await prefs.setString('gemini_model_emergency_meeting', normalizedModel);
    }
  }

  String _normalizeBoardMeetingModel(String? model) {
    final normalized = model?.trim() ?? '';
    if (_boardMeetingSupportedModels.contains(normalized)) {
      return normalized;
    }
    return _boardMeetingSupportedModels.first;
  }

  Future<void> _loadPdcaState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedReviewAt = prefs.getString(_prefsLastReviewAt);
    final savedRecoveryDueAt = prefs.getString(_prefsAbstinenceRecoveryDueAt);
    final seedMetrics = widget.initialMetrics;
    final seedLog = widget.initialLog;
    final seedContinuationPlan = widget.initialContinuationPlan;
    final seedAbstinenceRules = widget.initialAbstinenceRules;
    if (!mounted) return;

    setState(() {
      _abstinenceViolationCount =
          prefs.getInt(_prefsAbstinenceViolationCount) ?? 0;
      _abstinenceNoViolationDays =
          prefs.getInt(_prefsAbstinenceNoViolationDays) ?? 0;
      _lastContinuationCompletionRate =
          prefs.getInt(_prefsContinuationCompletionRate) ?? 0;
      _continuationPriorityDeclaredCount =
          prefs.getInt(_prefsContinuationPriorityDeclaredCount) ?? 0;
      _continuationQuickStartCount =
          prefs.getInt(_prefsContinuationQuickStartCount) ?? 0;
      _continuationFocusSprint25Count =
          prefs.getInt(_prefsContinuationFocusSprint25Count) ?? 0;
      _continuationTimeBlockReservedCount =
          prefs.getInt(_prefsContinuationTimeBlockReservedCount) ?? 0;
      _continuationProgressLogCount =
          prefs.getInt(_prefsContinuationProgressLogCount) ?? 0;
      _deepWorkSessionCount = prefs.getInt(_prefsDeepWorkSessionCount) ?? 0;
      _weeklyPriorityReviewCount =
          prefs.getInt(_prefsWeeklyPriorityReviewCount) ?? 0;
      _accountabilityShareCount =
          prefs.getInt(_prefsAccountabilityShareCount) ?? 0;
      _abstinenceRecoveryActionCount =
          prefs.getInt(_prefsAbstinenceRecoveryActionCount) ?? 0;
      _abstinenceRecoveredWithin10mCount =
          prefs.getInt(_prefsAbstinenceRecoveredWithin10mCount) ?? 0;
      _abstinenceRecoveryWindowMissedCount =
          prefs.getInt(_prefsAbstinenceRecoveryWindowMissedCount) ?? 0;
      _deterrenceStrictModeBlockCount =
          prefs.getInt(_prefsDeterrenceStrictModeBlockCount) ?? 0;
      _deterrenceDisableAttemptBlockedCount =
          prefs.getInt(_prefsDeterrenceDisableAttemptBlockedCount) ?? 0;
      _abstinenceRecoveryReminderScheduledCount =
          prefs.getInt(_prefsAbstinenceRecoveryReminderScheduledCount) ?? 0;
      _dailyReminderEnabled =
          prefs.getBool(_prefsDailyReminderEnabled) ?? false;
      _lockImpulsePurchase = prefs.getBool(_prefsLockImpulsePurchase) ?? false;
      _lockNewProjects = prefs.getBool(_prefsLockNewProjects) ?? false;
      _lockSubscriptionAdditions =
          prefs.getBool(_prefsLockSubscriptionAdditions) ?? false;
      _selectedContinuationPriorityIndex =
          prefs.getInt(_prefsSelectedContinuationPriorityIndex) ?? -1;
      _abstinenceRecoveryDueAt = savedRecoveryDueAt == null
          ? null
          : DateTime.tryParse(savedRecoveryDueAt);
      _lastReviewAt =
          savedReviewAt == null ? null : DateTime.tryParse(savedReviewAt);
      if (seedLog != null) {
        _currentLog = seedLog;
        _continuationPlan = List<String>.from(seedContinuationPlan);
        _abstinenceRules = List<String>.from(seedAbstinenceRules);
        _continuationChecks =
            List<bool>.filled(_continuationPlan.length, false);
        _abstinenceChecks = List<bool>.filled(_abstinenceRules.length, false);
        _selectedContinuationPriorityIndex = _continuationPlan.isEmpty ? -1 : 0;
      }
      if (seedMetrics != null) {
        _applyNextMeetingMetrics(seedMetrics.toJson());
      }
    });
  }

  Future<void> _persistPdcaState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefsAbstinenceViolationCount,
      _abstinenceViolationCount,
    );
    await prefs.setInt(
      _prefsAbstinenceNoViolationDays,
      _abstinenceNoViolationDays,
    );
    await prefs.setInt(
      _prefsContinuationCompletionRate,
      _lastContinuationCompletionRate,
    );
    await prefs.setInt(
      _prefsContinuationPriorityDeclaredCount,
      _continuationPriorityDeclaredCount,
    );
    await prefs.setInt(
      _prefsContinuationQuickStartCount,
      _continuationQuickStartCount,
    );
    await prefs.setInt(
      _prefsContinuationFocusSprint25Count,
      _continuationFocusSprint25Count,
    );
    await prefs.setInt(
      _prefsContinuationTimeBlockReservedCount,
      _continuationTimeBlockReservedCount,
    );
    await prefs.setInt(
      _prefsContinuationProgressLogCount,
      _continuationProgressLogCount,
    );
    await prefs.setInt(_prefsDeepWorkSessionCount, _deepWorkSessionCount);
    await prefs.setInt(
      _prefsWeeklyPriorityReviewCount,
      _weeklyPriorityReviewCount,
    );
    await prefs.setInt(
      _prefsAccountabilityShareCount,
      _accountabilityShareCount,
    );
    await prefs.setInt(
      _prefsAbstinenceRecoveryActionCount,
      _abstinenceRecoveryActionCount,
    );
    await prefs.setInt(
      _prefsAbstinenceRecoveredWithin10mCount,
      _abstinenceRecoveredWithin10mCount,
    );
    await prefs.setInt(
      _prefsAbstinenceRecoveryWindowMissedCount,
      _abstinenceRecoveryWindowMissedCount,
    );
    await prefs.setInt(
      _prefsDeterrenceStrictModeBlockCount,
      _deterrenceStrictModeBlockCount,
    );
    await prefs.setInt(
      _prefsDeterrenceDisableAttemptBlockedCount,
      _deterrenceDisableAttemptBlockedCount,
    );
    await prefs.setInt(
      _prefsAbstinenceRecoveryReminderScheduledCount,
      _abstinenceRecoveryReminderScheduledCount,
    );
    await prefs.setBool(_prefsDailyReminderEnabled, _dailyReminderEnabled);
    await prefs.setBool(_prefsLockImpulsePurchase, _lockImpulsePurchase);
    await prefs.setBool(_prefsLockNewProjects, _lockNewProjects);
    await prefs.setBool(
      _prefsLockSubscriptionAdditions,
      _lockSubscriptionAdditions,
    );
    await prefs.setInt(
      _prefsSelectedContinuationPriorityIndex,
      _selectedContinuationPriorityIndex,
    );
    if (_abstinenceRecoveryDueAt != null) {
      await prefs.setString(
        _prefsAbstinenceRecoveryDueAt,
        _abstinenceRecoveryDueAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_prefsAbstinenceRecoveryDueAt);
    }
    if (_lastReviewAt != null) {
      await prefs.setString(
        _prefsLastReviewAt,
        _lastReviewAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_prefsLastReviewAt);
    }
  }

  Future<String?> _loadBoardStartupContext() async {
    try {
      final workspaces = await Future.wait<AgentWorkspaceSnapshot?>([
        _agentOrgService.loadWorkspaceBySlug('ceo'),
        _agentOrgService.loadWorkspaceBySlug('cfo'),
        _agentOrgService.loadWorkspaceBySlug('cmo'),
        _agentOrgService.loadWorkspaceBySlug('cho'),
        _agentOrgService.loadWorkspaceBySlug('chro'),
      ]);

      final sections = <String>[];
      for (final workspace in workspaces.whereType<AgentWorkspaceSnapshot>()) {
        final startupPrompt = workspace.startupPrompt.trim();
        if (startupPrompt.isEmpty) {
          continue;
        }
        sections.add('### ${workspace.agent.displayName}\n$startupPrompt');
      }

      if (sections.isEmpty) {
        return null;
      }

      return <String>[
        '【AI組織の継続記憶】',
        ...sections,
      ].join('\n\n');
    } catch (error) {
      debugPrint('Failed to load board startup context: $error');
      return null;
    }
  }

  String _injectStartupContext({
    required String prompt,
    String? startupContext,
  }) {
    final normalizedStartupContext = startupContext?.trim();
    if (normalizedStartupContext == null || normalizedStartupContext.isEmpty) {
      return prompt;
    }
    return '$normalizedStartupContext\n\n[Board Meeting Request]\n$prompt';
  }

  String? _normalizeRoleSlug(String role) {
    final normalized = role.trim().toUpperCase();
    switch (normalized) {
      case 'CEO':
        return 'ceo';
      case 'CFO':
        return 'cfo';
      case 'CMO':
      case 'CKO':
      case 'CSO':
        return 'cmo';
      case 'CHRO':
        return 'chro';
      case 'CHO':
        return 'cho';
      default:
        return null;
    }
  }

  String _taskTitleForRole(String roleSlug, String seed) {
    final normalizedSeed = seed.trim().isEmpty ? '48時間実行プランを開始する' : seed.trim();
    switch (roleSlug) {
      case 'cfo':
        return '財務実行: $normalizedSeed';
      case 'cmo':
        return '流入実行: $normalizedSeed';
      case 'chro':
        return '習慣実行: $normalizedSeed';
      default:
        return normalizedSeed;
    }
  }

  String _buildExecutionDescription({
    required String roleLabel,
    required String meetingConclusion,
    required String continuationAction,
    required String abstinenceGuard,
    String? roleBrief,
  }) {
    final lines = <String>[
      'Role: $roleLabel',
      'CEO conclusion: $meetingConclusion',
      '48h action: $continuationAction',
      'Guardrail: $abstinenceGuard',
    ];
    final normalizedRoleBrief = roleBrief?.trim() ?? '';
    if (normalizedRoleBrief.isNotEmpty) {
      lines.add('Role brief: $normalizedRoleBrief');
    }
    return lines.join('\n');
  }

  Future<List<String>> _dispatchExecutionHub({
    required BoardMeetingLog log,
    required List<String> continuationPlan,
    required List<String> abstinenceRules,
  }) async {
    final agentMap = await _agentOrgService.loadExecutiveAgentMap();
    final ceo = agentMap['ceo'];
    if (ceo == null) {
      return <String>['CEO agent is not available.'];
    }

    final roleBriefBySlug = <String, String>{};
    for (final message in log.messages) {
      final slug = _normalizeRoleSlug(message.role);
      if (slug == null) {
        continue;
      }
      final text = message.content.trim();
      if (text.isEmpty) {
        continue;
      }
      roleBriefBySlug[slug] = roleBriefBySlug.containsKey(slug)
          ? '${roleBriefBySlug[slug]}\n$text'
          : text;
    }

    final continuationAction =
        continuationPlan.isNotEmpty ? continuationPlan.first : log.conclusion;
    final abstinenceGuard =
        abstinenceRules.isNotEmpty ? abstinenceRules.first : '誘惑トリガーを1つ遮断する。';
    final executionLogs = <String>[];

    for (final roleSlug in const <String>['cfo', 'cmo', 'chro']) {
      final assignee = agentMap[roleSlug];
      if (assignee == null) {
        executionLogs.add('$roleSlug: agent not found');
        continue;
      }

      final title = _taskTitleForRole(roleSlug, continuationAction);
      final description = _buildExecutionDescription(
        roleLabel: assignee.displayName,
        meetingConclusion: log.conclusion,
        continuationAction: continuationAction,
        abstinenceGuard: abstinenceGuard,
        roleBrief: roleBriefBySlug[roleSlug],
      );

      final delegatedTask = await _agentOrgService.delegateTask(
        supervisorAgentId: ceo.id,
        assigneeAgentId: assignee.id,
        title: title,
        description: description,
        priority: 'high',
        taskType: 'meeting_execution',
        source: 'emergency_hub',
        conversationId: log.id,
        messageKind: 'directive',
      );

      await _agentOrgService.consolidateMemory(
        agentId: assignee.id,
        summary: 'Emergency hub assigned: ${delegatedTask.title}',
        source: 'emergency_hub',
      );

      executionLogs.add('${assignee.displayName}: ${delegatedTask.title}');
    }

    await _agentOrgService.consolidateMemory(
      agentId: ceo.id,
      summary:
          'Emergency meeting dispatched\nConclusion: ${log.conclusion}\nAssignments:\n${executionLogs.join('\n')}',
      source: 'emergency_hub',
    );
    await _agentOrgService.registerForgettingDecision(
      agentId: ceo.id,
      forgottenItem: '曖昧な優先順位',
      reason: '会議結果をもとに48時間の実行順序を固定するため。',
      source: 'emergency_hub',
    );
    await _agentOrgService.resolveMemoryContradiction(
      agentId: ceo.id,
      contradiction: '短期成果を急ぐ行動と禁欲ルールが競合する。',
      resolution: '継続アクションを先に実行し、禁欲ルールで暴発を抑制する。',
      source: 'emergency_hub',
    );

    return executionLogs;
  }

  int _currentContinuationRatePercent() {
    if (_continuationChecks.isEmpty) return _lastContinuationCompletionRate;
    final completed = _continuationChecks.where((isDone) => isDone).length;
    return ((completed / _continuationChecks.length) * 100).round();
  }

  int _currentAbstinenceCompletedCount() {
    return _abstinenceChecks.where((isDone) => isDone).length;
  }

  int _currentAbstinenceRuleRatePercent() {
    if (_abstinenceChecks.isEmpty) return 0;
    final completed = _currentAbstinenceCompletedCount();
    return ((completed / _abstinenceChecks.length) * 100).round();
  }

  int _nextPendingContinuationIndex() {
    return _pdcaGuardrails.nextPendingContinuationIndex(_continuationChecks);
  }

  int _currentPriorityContinuationIndex() {
    return _pdcaGuardrails.currentPriorityContinuationIndex(
      selectedIndex: _selectedContinuationPriorityIndex,
      continuationChecks: _continuationChecks,
    );
  }

  Future<void> _pinContinuationAction(
    int index, {
    bool countDeclaration = true,
  }) async {
    if (index < 0 || index >= _continuationPlan.length) {
      return;
    }
    final shouldIncrement =
        countDeclaration && _selectedContinuationPriorityIndex != index;
    setState(() {
      _selectedContinuationPriorityIndex = index;
      if (shouldIncrement) {
        _continuationPriorityDeclaredCount += 1;
      }
    });
    await _persistPdcaState();
  }

  Future<void> _pinNextContinuationPriority() async {
    final nextIndex = _nextPendingContinuationIndex();
    if (nextIndex < 0) return;
    await _pinContinuationAction(nextIndex);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('今日の最重要1件を固定しました: ${_continuationPlan[nextIndex]}'),
      ),
    );
  }

  List<String> _activeDeterrenceLocks() {
    final locks = <String>[];
    if (_lockImpulsePurchase) locks.add('SNS制限ロック');
    if (_lockNewProjects) locks.add('90分タイムボックス');
    if (_lockSubscriptionAdditions) locks.add('週次共有リマインド');
    return locks;
  }

  int _currentDeterrenceLockCoveragePercent() {
    final activeLockCount = _activeDeterrenceLocks().length;
    final percent = ((activeLockCount / 3) * 100).round();
    if (percent < 0) return 0;
    if (percent > 100) return 100;
    return percent;
  }

  int _deterrenceReadinessPercent() {
    return _pdcaGuardrails.deterrenceReadinessPercent(
      reminderEnabled: _dailyReminderEnabled,
      activeLockCount: _activeDeterrenceLocks().length,
      hasPendingRecoveryWindow: _hasPendingRecoveryWindow(),
    );
  }

  Future<void> _recordDeterrenceRelaxationBlocked(String message) async {
    setState(() {
      _deterrenceStrictModeBlockCount += 1;
      _deterrenceDisableAttemptBlockedCount += 1;
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _hasPendingRecoveryWindow() {
    final dueAt = _abstinenceRecoveryDueAt;
    if (dueAt == null) return false;
    return !DateTime.now().isAfter(dueAt);
  }

  Duration? _remainingRecoveryWindow() {
    final dueAt = _abstinenceRecoveryDueAt;
    if (dueAt == null) return null;
    final remaining = dueAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return const Duration(seconds: 0);
    }
    return remaining;
  }

  Future<void> _flushExpiredRecoveryWindowIfNeeded() async {
    final dueAt = _abstinenceRecoveryDueAt;
    if (dueAt == null || !DateTime.now().isAfter(dueAt)) {
      return;
    }
    setState(() {
      _abstinenceRecoveryWindowMissedCount += 1;
      _abstinenceRecoveryDueAt = null;
    });
    try {
      final notificationService = context.read<NotificationService>();
      await notificationService.cancelAbstinenceRecoveryReminder();
    } catch (_) {
      // Notification bridge is optional.
    }
    await _persistPdcaState();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _toBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  void _applyNextMeetingMetrics(Map<String, dynamic> nextMetrics) {
    _abstinenceViolationCount = _toInt(
      nextMetrics['abstinence_violation_count'],
      fallback: _abstinenceViolationCount,
    );
    _abstinenceNoViolationDays = _toInt(
      nextMetrics['abstinence_no_violation_days'],
      fallback: _abstinenceNoViolationDays,
    );
    _lastContinuationCompletionRate = _toInt(
      nextMetrics['continuation_completion_rate_percent'],
      fallback: _lastContinuationCompletionRate,
    );
    _continuationPriorityDeclaredCount = _toInt(
      nextMetrics['continuation_priority_declared_count'],
      fallback: _continuationPriorityDeclaredCount,
    );
    _continuationQuickStartCount = _toInt(
      nextMetrics['continuation_quick_start_count'],
      fallback: _continuationQuickStartCount,
    );
    _continuationFocusSprint25Count = _toInt(
      nextMetrics['continuation_focus_sprint_25_count'],
      fallback: _continuationFocusSprint25Count,
    );
    _continuationTimeBlockReservedCount = _toInt(
      nextMetrics['continuation_time_block_reserved_count'],
      fallback: _continuationTimeBlockReservedCount,
    );
    _continuationProgressLogCount = _toInt(
      nextMetrics['continuation_progress_log_count'],
      fallback: _continuationProgressLogCount,
    );
    _dailyReminderEnabled = _toBool(
      nextMetrics['reminder_enabled'],
      fallback: _dailyReminderEnabled,
    );

    final parsedLocks =
        _extractStringList(nextMetrics['active_deterrence_locks']);
    if (nextMetrics.containsKey('active_deterrence_locks')) {
      final normalizedLocks =
          parsedLocks.map((item) => item.toLowerCase()).toList();
      _lockImpulsePurchase = normalizedLocks.any(
        (item) =>
            item.contains('impulse') ||
            item.contains('purchase') ||
            item.contains('買'),
      );
      _lockNewProjects = normalizedLocks.any(
        (item) => item.contains('project') || item.contains('新規'),
      );
      _lockSubscriptionAdditions = normalizedLocks.any(
        (item) =>
            item.contains('subscription') ||
            item.contains('subscr') ||
            item.contains('サブ'),
      );
    }

    _deepWorkSessionCount = _toInt(
      nextMetrics['deep_work_session_count'],
      fallback: _deepWorkSessionCount,
    );
    _weeklyPriorityReviewCount = _toInt(
      nextMetrics['weekly_priority_review_count'],
      fallback: _weeklyPriorityReviewCount,
    );
    _accountabilityShareCount = _toInt(
      nextMetrics['accountability_share_count'],
      fallback: _accountabilityShareCount,
    );
    _abstinenceRecoveryActionCount = _toInt(
      nextMetrics['abstinence_recovery_action_count'],
      fallback: _abstinenceRecoveryActionCount,
    );
    _abstinenceRecoveredWithin10mCount = _toInt(
      nextMetrics['abstinence_recovered_within_10m_count'],
      fallback: _abstinenceRecoveredWithin10mCount,
    );
    _abstinenceRecoveryWindowMissedCount = _toInt(
      nextMetrics['abstinence_recovery_window_missed_count'],
      fallback: _abstinenceRecoveryWindowMissedCount,
    );
    _deterrenceStrictModeBlockCount = _toInt(
      nextMetrics['deterrence_strict_mode_block_count'],
      fallback: _deterrenceStrictModeBlockCount,
    );
    _deterrenceDisableAttemptBlockedCount = _toInt(
      nextMetrics['deterrence_disable_attempt_blocked_count'],
      fallback: _deterrenceDisableAttemptBlockedCount,
    );
    _abstinenceRecoveryReminderScheduledCount = _toInt(
      nextMetrics['abstinence_recovery_reminder_scheduled_count'],
      fallback: _abstinenceRecoveryReminderScheduledCount,
    );

    final parsedReviewAt = _toDateTime(nextMetrics['last_review_at']);
    _lastReviewAt = parsedReviewAt ?? _lastReviewAt;
    if (nextMetrics.containsKey('abstinence_recovery_due_at')) {
      _abstinenceRecoveryDueAt =
          _toDateTime(nextMetrics['abstinence_recovery_due_at']);
    }
  }

  EmergencyMeetingPdcaMetrics _buildPdcaMetrics() {
    final continuationTotal = _continuationChecks.isEmpty
        ? _continuationPlan.length
        : _continuationChecks.length;
    final continuationCompleted =
        _continuationChecks.where((isDone) => isDone).length;
    final abstinenceTotal = _abstinenceChecks.length;
    final abstinenceCompleted = _currentAbstinenceCompletedCount();
    final activeLocks = _activeDeterrenceLocks();
    return EmergencyMeetingPdcaMetrics(
      continuationCompletedCount: continuationCompleted,
      continuationTotalCount: continuationTotal,
      continuationCompletionRatePercent: _currentContinuationRatePercent(),
      continuationPriorityDeclaredCount: _continuationPriorityDeclaredCount,
      continuationQuickStartCount: _continuationQuickStartCount,
      continuationFocusSprint25Count: _continuationFocusSprint25Count,
      continuationTimeBlockReservedCount: _continuationTimeBlockReservedCount,
      continuationProgressLogCount: _continuationProgressLogCount,
      abstinenceViolationCount: _abstinenceViolationCount,
      abstinenceNoViolationDays: _abstinenceNoViolationDays,
      abstinenceRuleCompletedCount: abstinenceCompleted,
      abstinenceRuleTotalCount: abstinenceTotal,
      abstinenceRuleCompletionRatePercent: _currentAbstinenceRuleRatePercent(),
      abstinenceRecoveredWithin10mCount: _abstinenceRecoveredWithin10mCount,
      abstinenceRecoveryWindowMissedCount: _abstinenceRecoveryWindowMissedCount,
      deepWorkSessionCount: _deepWorkSessionCount,
      weeklyPriorityReviewCount: _weeklyPriorityReviewCount,
      accountabilityShareCount: _accountabilityShareCount,
      abstinenceRecoveryActionCount: _abstinenceRecoveryActionCount,
      reminderEnabled: _dailyReminderEnabled,
      deterrenceLockEnabledCount: activeLocks.length,
      deterrenceStrictModeBlockCount: _deterrenceStrictModeBlockCount,
      deterrenceDisableAttemptBlockedCount:
          _deterrenceDisableAttemptBlockedCount,
      deterrenceLockCoveragePercent: _currentDeterrenceLockCoveragePercent(),
      abstinenceRecoveryReminderScheduledCount:
          _abstinenceRecoveryReminderScheduledCount,
      abstinenceRecoveryDueAt: _abstinenceRecoveryDueAt,
      activeDeterrenceLocks: activeLocks,
      lastReviewAt: _lastReviewAt,
    );
  }

  void _toggleContinuationCheck(int index, bool? value) {
    if (index < 0 || index >= _continuationChecks.length || value == null) {
      return;
    }
    setState(() {
      _continuationChecks[index] = value;
      if (value && _selectedContinuationPriorityIndex == index) {
        _selectedContinuationPriorityIndex = _nextPendingContinuationIndex();
      }
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
    });
    _persistPdcaState();
  }

  Future<void> _markContinuationQuickStart() async {
    final targetIndex = _currentPriorityContinuationIndex();
    if (targetIndex < 0) return;
    setState(() {
      if (_selectedContinuationPriorityIndex != targetIndex) {
        _selectedContinuationPriorityIndex = targetIndex;
        _continuationPriorityDeclaredCount += 1;
      }
      _continuationQuickStartCount += 1;
      _continuationFocusSprint25Count += 1;
      _lastReviewAt = DateTime.now();
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '25分着手を開始しました: ${_continuationPlan[targetIndex]}',
        ),
      ),
    );
  }

  Future<void> _completeNextContinuationAction() async {
    final targetIndex = _currentPriorityContinuationIndex();
    if (targetIndex < 0) return;
    setState(() {
      _continuationChecks[targetIndex] = true;
      if (_selectedContinuationPriorityIndex == targetIndex) {
        _selectedContinuationPriorityIndex = _nextPendingContinuationIndex();
      }
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
    });
    await _persistPdcaState();
  }

  Future<void> _quickStartAndCompleteNextContinuationAction() async {
    final targetIndex = _currentPriorityContinuationIndex();
    if (targetIndex < 0) return;
    setState(() {
      if (_selectedContinuationPriorityIndex != targetIndex) {
        _selectedContinuationPriorityIndex = targetIndex;
        _continuationPriorityDeclaredCount += 1;
      }
      _continuationQuickStartCount += 1;
      _continuationFocusSprint25Count += 1;
      _continuationChecks[targetIndex] = true;
      _selectedContinuationPriorityIndex = _nextPendingContinuationIndex();
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
      _lastReviewAt = DateTime.now();
    });
    await _persistPdcaState();
  }

  Future<void> _reserveContinuationTimeBlock() async {
    setState(() {
      _continuationTimeBlockReservedCount += 1;
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('明朝の15分ブロックを予約しました。'),
      ),
    );
  }

  Future<void> _recordContinuationProgressLog() async {
    setState(() {
      _continuationProgressLogCount += 1;
      _lastReviewAt = DateTime.now();
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('48時間の進捗ログを記録しました。'),
      ),
    );
  }

  void _toggleAbstinenceCheck(int index, bool? value) {
    if (index < 0 || index >= _abstinenceChecks.length || value == null) return;
    setState(() => _abstinenceChecks[index] = value);
    _persistPdcaState();
  }

  void _setDeterrenceLock({
    required bool value,
    required void Function(bool) setter,
  }) {
    setState(() => setter(value));
    _persistPdcaState();
  }

  Future<void> _toggleImpulsePurchaseLock(bool enabled) async {
    final shouldBlock = _pdcaGuardrails.shouldBlockDeterrenceRelaxation(
      hasPendingRecoveryWindow: _hasPendingRecoveryWindow(),
      nextImpulsePurchase: enabled,
      nextNewProjects: _lockNewProjects,
      nextSubscriptionAdditions: _lockSubscriptionAdditions,
      nextReminderEnabled: _dailyReminderEnabled,
    );
    if (!enabled && shouldBlock) {
      await _recordDeterrenceRelaxationBlocked(
        _hasPendingRecoveryWindow()
            ? '回復ウィンドウ中はロックを解除できません。先に即時リカバリーを完了してください。'
            : '通知かロックのどちらかは必ず維持してください。',
      );
      return;
    }
    _setDeterrenceLock(
      value: enabled,
      setter: (value) => _lockImpulsePurchase = value,
    );
  }

  Future<void> _toggleNewProjectsLock(bool enabled) async {
    final shouldBlock = _pdcaGuardrails.shouldBlockDeterrenceRelaxation(
      hasPendingRecoveryWindow: _hasPendingRecoveryWindow(),
      nextImpulsePurchase: _lockImpulsePurchase,
      nextNewProjects: enabled,
      nextSubscriptionAdditions: _lockSubscriptionAdditions,
      nextReminderEnabled: _dailyReminderEnabled,
    );
    if (!enabled && shouldBlock) {
      await _recordDeterrenceRelaxationBlocked(
        _hasPendingRecoveryWindow()
            ? '回復ウィンドウ中はロックを解除できません。先に即時リカバリーを完了してください。'
            : '通知かロックのどちらかは必ず維持してください。',
      );
      return;
    }
    _setDeterrenceLock(
      value: enabled,
      setter: (value) => _lockNewProjects = value,
    );
  }

  Future<void> _toggleSubscriptionAdditionsLock(bool enabled) async {
    final shouldBlock = _pdcaGuardrails.shouldBlockDeterrenceRelaxation(
      hasPendingRecoveryWindow: _hasPendingRecoveryWindow(),
      nextImpulsePurchase: _lockImpulsePurchase,
      nextNewProjects: _lockNewProjects,
      nextSubscriptionAdditions: enabled,
      nextReminderEnabled: _dailyReminderEnabled,
    );
    if (!enabled && shouldBlock) {
      await _recordDeterrenceRelaxationBlocked(
        _hasPendingRecoveryWindow()
            ? '回復ウィンドウ中はロックを解除できません。先に即時リカバリーを完了してください。'
            : '通知かロックのどちらかは必ず維持してください。',
      );
      return;
    }
    _setDeterrenceLock(
      value: enabled,
      setter: (value) => _lockSubscriptionAdditions = value,
    );
  }

  Future<void> _toggleDailyReminder(bool enabled) async {
    setState(() => _dailyReminderEnabled = enabled);
    await _persistPdcaState();
    if (!mounted) return;

    try {
      final notificationService = context.read<NotificationService>();
      if (enabled) {
        await notificationService.scheduleDailyAbstinenceReminder();
      } else {
        await notificationService.cancelAbstinenceReminder();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? '通知サービスに接続できないため、リマインドは保存のみ行いました。'
                : '通知サービスに接続できないため、設定のみ更新しました。',
          ),
        ),
      );
    }
  }

  Future<void> _attemptToggleDailyReminder(bool enabled) async {
    final shouldBlock = _pdcaGuardrails.shouldBlockDeterrenceRelaxation(
      hasPendingRecoveryWindow: _hasPendingRecoveryWindow(),
      nextImpulsePurchase: _lockImpulsePurchase,
      nextNewProjects: _lockNewProjects,
      nextSubscriptionAdditions: _lockSubscriptionAdditions,
      nextReminderEnabled: enabled,
    );
    if (!enabled && shouldBlock) {
      await _recordDeterrenceRelaxationBlocked(
        _hasPendingRecoveryWindow()
            ? '回復ウィンドウ中は通知を止められません。先に即時リカバリーを完了してください。'
            : '通知かロックのどちらかは必ず維持してください。',
      );
      return;
    }
    await _toggleDailyReminder(enabled);
  }

  Future<void> _recordAbstinenceViolation() async {
    final notificationService = context.read<NotificationService>();
    await _flushExpiredRecoveryWindowIfNeeded();
    final dueAt = DateTime.now().add(const Duration(minutes: 10));
    if (!mounted) return;
    setState(() {
      _abstinenceViolationCount += 1;
      _abstinenceNoViolationDays = 0;
      _abstinenceRecoveryDueAt = dueAt;
      if (_activeDeterrenceLocks().isEmpty) {
        _lockImpulsePurchase = true;
      }
    });
    if (!_dailyReminderEnabled) {
      await _toggleDailyReminder(true);
    }
    try {
      await notificationService.scheduleAbstinenceRecoveryReminder(
        dueAt: dueAt,
      );
      if (!mounted) return;
      setState(() {
        _abstinenceRecoveryReminderScheduledCount += 1;
      });
    } catch (_) {
      // Reminder scheduling is best effort.
    }
    await _persistPdcaState();
  }

  Future<void> _recordAbstinenceCleanDay() async {
    await _flushExpiredRecoveryWindowIfNeeded();
    if (_hasPendingRecoveryWindow()) {
      if (!mounted) return;
      setState(() {
        _deterrenceStrictModeBlockCount += 1;
      });
      await _persistPdcaState();
      if (!mounted) return;
      final remainingSeconds =
          _remainingRecoveryWindow()?.inSeconds.clamp(0, 600) ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '先に10分以内リカバリーを実行してください。残り ${remainingSeconds}s',
          ),
        ),
      );
      return;
    }
    setState(() => _abstinenceNoViolationDays += 1);
    await _persistPdcaState();
  }

  Future<void> _recordDeepWorkSession() async {
    setState(() => _deepWorkSessionCount += 1);
    await _persistPdcaState();
  }

  Future<void> _recordPriorityReview() async {
    setState(() => _weeklyPriorityReviewCount += 1);
    await _persistPdcaState();
  }

  Future<void> _recordAccountabilityShare() async {
    setState(() => _accountabilityShareCount += 1);
    await _persistPdcaState();
  }

  Future<void> _recordAbstinenceRecoveryAction() async {
    final notificationService = context.read<NotificationService>();
    await _flushExpiredRecoveryWindowIfNeeded();
    final dueAt = _abstinenceRecoveryDueAt;
    final recoveredWithinWindow =
        dueAt != null && !DateTime.now().isAfter(dueAt);
    setState(() {
      _abstinenceRecoveryActionCount += 1;
      if (recoveredWithinWindow) {
        _abstinenceRecoveredWithin10mCount += 1;
      }
      _abstinenceRecoveryDueAt = null;
    });
    try {
      await notificationService.cancelAbstinenceRecoveryReminder();
    } catch (_) {
      // Notification bridge is optional in tests and web.
    }
    await _persistPdcaState();
  }

  Future<void> _enableEmergencyDeterrenceMode() async {
    setState(() {
      _lockImpulsePurchase = true;
      _lockNewProjects = true;
      _lockSubscriptionAdditions = true;
      _dailyReminderEnabled = true;
    });
    await _persistPdcaState();
    if (!mounted) return;

    try {
      final notificationService = context.read<NotificationService>();
      await notificationService.scheduleDailyAbstinenceReminder();
    } catch (_) {
      // Save the state even if the notification bridge is unavailable.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('衝動遮断モードを有効化しました。なんとなくやりたい行動を先に塞ぎます。'),
      ),
    );
  }

  Future<void> _recordPdcaReview() async {
    setState(() {
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
      _lastReviewAt = DateTime.now();
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('次回会議の検証指標を保存しました。')),
    );
  }

  Future<List<Map<String, dynamic>>> fetchGeminiModels() async {
    try {
      final response = await _supabase.functions.invoke(
        'ai-hub',
        body: const {'action': 'provider.models'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return (data['models'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map>()
          .map((model) => Map<String, dynamic>.from(model))
          .where((model) => model['provider'] == 'google')
          .where((model) {
            final methods = model['supportedGenerationMethods'];
            return methods is List && methods.contains('generateContent');
          })
          .map<Map<String, dynamic>>(
            (model) => <String, dynamic>{
              'name': model['name']?.toString() ?? '',
              'methods': List<String>.from(
                model['supportedGenerationMethods'] as List,
              ),
            },
          )
          .where((model) => (model['name'] as String).isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _ensureSelectedModelIsAvailable() async {
    final current = _selectedModel;
    final next = _normalizeBoardMeetingModel(current);

    if (!mounted) return;
    setState(() {
      _selectableModels = _defaultBoardMeetingModels();
      _selectedModel = next;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_model_emergency_meeting', next);

    if (next != current && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '選択モデル「$current」が利用不可のため「$next」に切り替えました。',
          ),
        ),
      );
    }
  }

  Future<void> showSettingsDialog() async {
    String tempSelectedModel = _selectedModel;
    bool isFetchingModels = false;
    List<Map<String, dynamic>> currentSelectableModels =
        List.from(_selectableModels);

    if (!currentSelectableModels.any((m) => m['name'] == tempSelectedModel)) {
      currentSelectableModels.add({
        'name': tempSelectedModel,
        'methods': ['generateContent'],
      });
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('AIモデル設定'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI認証情報はサーバーで管理されています。ここでは利用モデルのみ選択できます。',
                  ),
                  const SizedBox(height: 8),
                  if (isFetchingModels)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          setDialogState(() => isFetchingModels = true);
                          final models = await fetchGeminiModels();
                          setDialogState(() {
                            isFetchingModels = false;
                            if (models.isNotEmpty) {
                              currentSelectableModels = models;
                              if (!currentSelectableModels
                                  .any((m) => m['name'] == tempSelectedModel)) {
                                tempSelectedModel =
                                    models.first['name'] as String;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${models.length}個のモデルを取得しました'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('モデルの取得に失敗しました'),
                                ),
                              );
                            }
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('利用可能なモデル一覧を取得'),
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: tempSelectedModel,
                    decoration: const InputDecoration(
                      labelText: '使用モデル',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: currentSelectableModels.map((m) {
                      final name = m['name'] as String;
                      return DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => tempSelectedModel = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '現在のモデル: ',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                tempSelectedModel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  height: 1.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          '利用可能なモデル一覧 (サポートメソッド):',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentSelectableModels.map((m) {
                            final name = m['name'] as String;
                            final methods =
                                (m['methods'] as List? ?? []).join(', ');
                            return '$name ($methods)';
                          }).join('\n'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final normalizedSelectedModel =
                      _normalizeBoardMeetingModel(tempSelectedModel);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'gemini_model_emergency_meeting',
                    normalizedSelectedModel,
                  );
                  if (mounted) {
                    setState(() {
                      _selectedModel = normalizedSelectedModel;
                      _selectableModels = _defaultBoardMeetingModels();
                    });
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _errorMessage;

  String _focusLabel(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '継続 + 禁欲（両立）';
      case MeetingFocus.continuation:
        return '継続強化';
      case MeetingFocus.abstinence:
        return '禁欲強化';
    }
  }

  String _focusShortLabel(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '両立';
      case MeetingFocus.continuation:
        return '継続';
      case MeetingFocus.abstinence:
        return '禁欲';
    }
  }

  String _focusInstruction(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return '継続と禁欲のバランスを重視し、両方の改善策を同じ優先度で提案する。';
      case MeetingFocus.continuation:
        return '継続率の改善を最優先。習慣化・再開しやすさ・反復設計に集中する。';
      case MeetingFocus.abstinence:
        return '禁欲の成功率を最優先。誘惑遮断・トリガー回避・事前ルール化に集中する。';
    }
  }

  Color _focusColor(MeetingFocus focus) {
    switch (focus) {
      case MeetingFocus.balanced:
        return const Color(0xFF607D8B);
      case MeetingFocus.continuation:
        return const Color(0xFF3D5AFE);
      case MeetingFocus.abstinence:
        return const Color(0xFFE53935);
    }
  }

  String _resolvedFocusLabel(MeetingFocus focus) {
    return switch (focus) {
      MeetingFocus.balanced => '継続と禁欲の両面を見る',
      MeetingFocus.continuation => '継続実行を最優先',
      MeetingFocus.abstinence => '禁欲と回復を最優先',
    };
  }

  String _resolvedFocusShortLabel(MeetingFocus focus) {
    return switch (focus) {
      MeetingFocus.balanced => '両面',
      MeetingFocus.continuation => '継続',
      MeetingFocus.abstinence => '禁欲',
    };
  }

  String _resolvedFocusInstruction(MeetingFocus focus) {
    return switch (focus) {
      MeetingFocus.balanced => '継続実行と禁欲リスクを同時に確認し、48時間以内の実行策を決めます。',
      MeetingFocus.continuation => '重要案件の着手、時間確保、進捗ログを最優先で見直します。',
      MeetingFocus.abstinence => '誘惑の兆候、回復行動、ロック運用を最優先で点検します。',
    };
  }

  List<String> _extractStringList(dynamic value) {
    if (value is! List) return <String>[];
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _extractFirstJsonObject(String text) {
    final trimmed = text.trim();
    final firstBrace = trimmed.indexOf('{');
    if (firstBrace == -1) return trimmed;

    var inString = false;
    var isEscaped = false;
    var depth = 0;
    var startIndex = firstBrace;

    for (var i = firstBrace; i < trimmed.length; i++) {
      final char = trimmed[i];

      if (inString) {
        if (isEscaped) {
          isEscaped = false;
        } else if (char == r'\') {
          isEscaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == '{') {
        if (depth == 0) {
          startIndex = i;
        }
        depth++;
        continue;
      }
      if (char == '}') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(startIndex, i + 1);
        }
      }
    }

    return trimmed.substring(startIndex);
  }

  String _repairJsonCandidate(String input) {
    var fixed = input.trim();

    // Smart quotes -> plain quotes
    fixed = fixed
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'");

    // Strip markdown fences if they remain
    fixed = fixed.replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '');
    fixed = fixed.replaceAll(RegExp(r'\s*```$', multiLine: true), '');

    // Common comma fixes
    fixed = fixed.replaceAll(RegExp(r'}\s*{'), '},{');
    fixed = fixed.replaceAll(RegExp(r'"\s*\n\s*"'), '",\n"');
    fixed = fixed.replaceAll(RegExp(r',\s*([\]}])'), r'$1');
    fixed = _escapeBrokenJsonStringContent(fixed);

    return fixed;
  }

  String? _nextNonWhitespaceChar(String text, int startIndex) {
    for (var i = startIndex; i < text.length; i++) {
      final char = text[i];
      if (char.trim().isEmpty) continue;
      return char;
    }
    return null;
  }

  String _escapeBrokenJsonStringContent(String input) {
    final buffer = StringBuffer();
    var inString = false;
    var isEscaped = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (!inString) {
        if (char == '"') {
          inString = true;
        }
        buffer.write(char);
        continue;
      }

      if (isEscaped) {
        buffer.write(char);
        isEscaped = false;
        continue;
      }

      if (char == r'\') {
        buffer.write(char);
        isEscaped = true;
        continue;
      }

      if (char == '"') {
        final next = _nextNonWhitespaceChar(input, i + 1);
        final canClose = next == null ||
            next == ',' ||
            next == '}' ||
            next == ']' ||
            next == ':';
        if (canClose) {
          inString = false;
          buffer.write(char);
        } else {
          buffer.write(r'\"');
        }
        continue;
      }

      if (char == '\n') {
        buffer.write(r'\n');
        continue;
      }
      if (char == '\r') {
        buffer.write(r'\r');
        continue;
      }
      if (char == '\t') {
        buffer.write(r'\t');
        continue;
      }

      final codeUnit = char.codeUnitAt(0);
      if (codeUnit < 0x20) {
        buffer.write(' ');
        continue;
      }

      buffer.write(char);
    }

    if (inString) {
      buffer.write('"');
    }

    return buffer.toString();
  }

  String _decodeJsonStringFragment(String value) {
    return value
        .replaceAll(r'\"', '"')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\/', '/')
        .replaceAll(r'\n', ' ')
        .replaceAll(r'\r', ' ')
        .replaceAll(r'\t', ' ')
        .trim();
  }

  String? _extractBracketedField(
    String source,
    String fieldName, {
    required String openChar,
    required String closeChar,
  }) {
    final fieldPattern = RegExp(
      '"$fieldName"\\s*:\\s*${RegExp.escape(openChar)}',
      dotAll: true,
    );
    final match = fieldPattern.firstMatch(source);
    if (match == null) return null;

    final startIndex = match.end - 1;
    var depth = 0;
    var inString = false;
    var isEscaped = false;

    for (var i = startIndex; i < source.length; i++) {
      final char = source[i];

      if (inString) {
        if (isEscaped) {
          isEscaped = false;
        } else if (char == r'\') {
          isEscaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        continue;
      }
      if (char == openChar) {
        depth++;
        continue;
      }
      if (char == closeChar) {
        depth--;
        if (depth == 0) {
          return source.substring(startIndex, i + 1);
        }
      }
    }

    return source.substring(startIndex);
  }

  List<String> _extractQuotedArrayItems(String source, String fieldName) {
    final fieldPattern = RegExp(
      '"$fieldName"\\s*:\\s*\\[(.*?)\\]',
      dotAll: true,
    );
    final fieldMatch = fieldPattern.firstMatch(source);
    if (fieldMatch == null) return const <String>[];

    final body = fieldMatch.group(1) ?? '';
    final itemPattern = RegExp(r'"((?:\\.|[^"\\])*)"');
    return itemPattern
        .allMatches(body)
        .map((m) => _decodeJsonStringFragment(m.group(1) ?? ''))
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String? _extractQuotedFieldValue(String source, String fieldName) {
    final pattern = RegExp(
      '"$fieldName"\\s*:\\s*"((?:\\\\.|[^"\\\\])*)"',
      dotAll: true,
    );
    final match = pattern.firstMatch(source);
    if (match == null) return null;
    final value = _decodeJsonStringFragment(match.group(1) ?? '');
    return value.isEmpty ? null : value;
  }

  int? _extractIntFieldValue(String source, String fieldName) {
    final pattern = RegExp('"$fieldName"\\s*:\\s*(-?\\d+)');
    final match = pattern.firstMatch(source);
    if (match == null) return null;
    return int.tryParse(match.group(1) ?? '');
  }

  bool? _extractBoolFieldValue(String source, String fieldName) {
    final pattern = RegExp('"$fieldName"\\s*:\\s*(true|false)');
    final match = pattern.firstMatch(source);
    if (match == null) return null;
    return match.group(1) == 'true';
  }

  List<Map<String, String>> _extractTolerantMessages(String source) {
    final messageSource = _extractBracketedField(
          source,
          'messages',
          openChar: '[',
          closeChar: ']',
        ) ??
        source;
    final objectPattern = RegExp(r'\{[^{}]*\}', dotAll: true);
    final recovered = <Map<String, String>>[];

    for (final match in objectPattern.allMatches(messageSource)) {
      final objectText = match.group(0);
      if (objectText == null) continue;
      final role = _extractQuotedFieldValue(objectText, 'role');
      final speakerName = _extractQuotedFieldValue(objectText, 'speaker_name');
      final content = _extractQuotedFieldValue(objectText, 'content');
      if (content == null || content.isEmpty) continue;
      recovered.add(<String, String>{
        'role': (role == null || role.isEmpty) ? 'Advisor' : role,
        'speaker_name':
            (speakerName == null || speakerName.isEmpty) ? 'AI' : speakerName,
        'content': _truncateText(content, maxChars: 180),
      });
    }

    return recovered;
  }

  Map<String, dynamic>? _extractTolerantNextMeetingMetrics(String source) {
    final metricsSource = _extractBracketedField(
      source,
      'next_meeting_metrics',
      openChar: '{',
      closeChar: '}',
    );
    if (metricsSource == null || metricsSource.trim().isEmpty) {
      return null;
    }

    final decodeCandidates = <String>{
      metricsSource,
      _repairJsonCandidate(metricsSource),
      _escapeBrokenJsonStringContent(metricsSource),
      _escapeBrokenJsonStringContent(_repairJsonCandidate(metricsSource)),
    }.where((candidate) => candidate.trim().isNotEmpty);

    for (final candidate in decodeCandidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException {
        // Fall through to field-by-field salvage.
      }
    }

    final recovered = <String, dynamic>{};
    const intFields = <String>[
      'continuation_completed_count',
      'continuation_total_count',
      'continuation_completion_rate_percent',
      'abstinence_violation_count',
      'abstinence_no_violation_days',
      'deep_work_session_count',
      'weekly_priority_review_count',
      'accountability_share_count',
      'continuation_priority_declared_count',
      'continuation_quick_start_count',
      'continuation_focus_sprint_25_count',
      'continuation_time_block_reserved_count',
      'continuation_progress_log_count',
      'abstinence_rule_completed_count',
      'abstinence_rule_total_count',
      'abstinence_rule_completion_rate_percent',
      'abstinence_recovery_action_count',
      'abstinence_recovered_within_10m_count',
      'abstinence_recovery_window_missed_count',
      'deterrence_lock_enabled_count',
      'deterrence_strict_mode_block_count',
      'deterrence_disable_attempt_blocked_count',
      'deterrence_lock_coverage_percent',
      'abstinence_recovery_reminder_scheduled_count',
    ];

    for (final fieldName in intFields) {
      final value = _extractIntFieldValue(metricsSource, fieldName);
      if (value != null) {
        recovered[fieldName] = value;
      }
    }

    final reminderEnabled =
        _extractBoolFieldValue(metricsSource, 'reminder_enabled');
    if (reminderEnabled != null) {
      recovered['reminder_enabled'] = reminderEnabled;
    }

    final activeLocks = _extractQuotedArrayItems(
      metricsSource,
      'active_deterrence_locks',
    );
    if (activeLocks.isNotEmpty) {
      recovered['active_deterrence_locks'] = activeLocks;
    }

    final lastReviewAt =
        _extractQuotedFieldValue(metricsSource, 'last_review_at');
    if (lastReviewAt != null && lastReviewAt.isNotEmpty) {
      recovered['last_review_at'] = lastReviewAt;
    }

    final abstinenceRecoveryDueAt =
        _extractQuotedFieldValue(metricsSource, 'abstinence_recovery_due_at');
    if (abstinenceRecoveryDueAt != null && abstinenceRecoveryDueAt.isNotEmpty) {
      recovered['abstinence_recovery_due_at'] = abstinenceRecoveryDueAt;
    }

    return recovered.isEmpty ? null : recovered;
  }

  String _truncateText(String text, {int maxChars = 140}) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) return normalized;
    return '${normalized.substring(0, maxChars)}...';
  }

  Map<String, dynamic> _buildFallbackMeetingResponseJson(String responseText) {
    final normalized = responseText
        .replaceAll('\u201c', '"')
        .replaceAll('\u201d', '"')
        .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    final continuationPlan =
        _extractQuotedArrayItems(normalized, 'continuation_plan');
    final abstinenceRules =
        _extractQuotedArrayItems(normalized, 'abstinence_rules');
    final recoveredMessages = _extractTolerantMessages(normalized);
    final extractedConclusion =
        _extractQuotedFieldValue(normalized, 'conclusion');
    final extractedMessage = _extractQuotedFieldValue(normalized, 'content');
    final extractedRiskAlert =
        _extractQuotedFieldValue(normalized, 'risk_alert');
    final extractedMetrics = _extractTolerantNextMeetingMetrics(normalized);

    final fallbackSeed = extractedConclusion ??
        extractedMessage ??
        normalized.replaceAll(RegExp(r'[\{\}\[\]"]'), ' ');
    final fallbackConclusion = _truncateText(
      fallbackSeed.isEmpty ? '継続と禁欲の両立を最優先し、48時間の再建プランを実行する。' : fallbackSeed,
      maxChars: 140,
    );
    final recoveredRiskAlert =
        extractedRiskAlert ?? '継続と禁欲のバランスが崩れると、実行率と回復速度が同時に落ちる。';
    final shouldShowDecodeNotice = recoveredMessages.length < 3 ||
        continuationPlan.isEmpty ||
        abstinenceRules.isEmpty ||
        extractedConclusion == null ||
        extractedMetrics == null;

    return <String, dynamic>{
      'messages': recoveredMessages.isNotEmpty
          ? recoveredMessages
          : <Map<String, String>>[
              <String, String>{
                'role': 'CMO',
                'speaker_name': 'AI CMO',
                'content':
                    extractedMessage != null && extractedMessage.isNotEmpty
                        ? _truncateText(extractedMessage, maxChars: 180)
                        : fallbackConclusion,
              },
            ],
      'continuation_plan': continuationPlan.isNotEmpty
          ? continuationPlan
          : const <String>[
              '今日中に継続タスクを1件だけ完了する。',
              '明朝の実行時間を15分ブロックで先に予約する。',
              '48時間後に進捗を記録して次の改善点を1つ決める。',
            ],
      'abstinence_rules': abstinenceRules.isNotEmpty
          ? abstinenceRules
          : const <String>[
              '誘惑トリガーを1つ遮断する。',
              '代替行動を1つ先に決める。',
              '逸脱したら10分以内に再設定する。',
            ],
      'risk_alert': recoveredRiskAlert,
      'conclusion': fallbackConclusion,
      if (extractedMetrics != null) 'next_meeting_metrics': extractedMetrics,
      if (shouldShowDecodeNotice)
        '_decode_notice': 'AI応答のJSONを一部自動補正しました。復元結果を確認してください。',
    };
  }

  Map<String, dynamic> _decodeMeetingResponseJson(String responseText) {
    final raw = responseText.trim();
    final extracted = _extractFirstJsonObject(raw);
    final repaired = _repairJsonCandidate(extracted);
    final escapedExtracted = _escapeBrokenJsonStringContent(extracted);
    final escapedRepaired = _escapeBrokenJsonStringContent(repaired);
    final candidates = <String>{
      extracted,
      repaired,
      escapedExtracted,
      escapedRepaired,
    }.where((candidate) => candidate.trim().isNotEmpty).toList();

    FormatException? lastError;
    for (final candidate in candidates) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      } on FormatException catch (e) {
        lastError = e;
      }
    }

    debugPrint(
      'Meeting JSON decode failed. Falling back to tolerant parser. '
      '${lastError?.message ?? 'unknown format error'}',
    );
    return _buildFallbackMeetingResponseJson(raw);
  }

  String _buildCodexCopyText() {
    final log = _currentLog;
    if (log == null) return '';
    return EmergencyMeetingCodexFormatter.formatForCodex(
      log: log,
      focusLabel: _resolvedFocusLabel(_selectedFocus),
      model: _selectedModel,
      continuationPlan: _continuationPlan,
      abstinenceRules: _abstinenceRules,
      riskAlert: _riskAlert,
      metrics: _buildPdcaMetrics(),
    );
  }

  Future<void> _copyMeetingForCodex() async {
    if (_currentLog == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コピーする会議結果がありません。')));
      return;
    }

    await Clipboard.setData(ClipboardData(text: _buildCodexCopyText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('会議結果をCodex貼り付け形式でコピーしました。')),
    );
  }

  // ... (initState and _fetchModels remain the same)

  Future<void> _conveneBoard() async {
    await _ensureSelectedModelIsAvailable();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingStatus = '継続と禁欲に関するデータを収集中...';
      _errorMessage = null;
      _continuationPlan = <String>[];
      _abstinenceRules = <String>[];
      _continuationChecks = <bool>[];
      _abstinenceChecks = <bool>[];
      _selectedContinuationPriorityIndex = -1;
      _riskAlert = null;
      _decodeNotice = null;
      _executionHubLogs = <String>[];
      _executionHubError = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in.');
      }

// ▼ 修正: テーブルが存在しない(404)場合などにクラッシュさせず、0やnullを返すように catchError を追加
      final results = await Future.wait<dynamic>([
        _supabase
            .from('notes')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す
        _supabase
            .from('subscriptions')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle()
            .catchError((_) => null), // エラー時はnullを返す
        _supabase
            .from('danshari_items')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0), // エラー時は0を返す（今回の原因）
      ]);

      final noteCount = results[0] as int;
      final subCount = results[1] as int;
      final userStats = results[2] as Map<String, dynamic>?;
      final danshariCount = results[3] as int;
      final points = userStats?['total_points'] ?? 0;
      final level = userStats?['current_level'] ?? 1;
      final currentStreak = userStats?['current_streak'] ?? 0;
      final currentMetrics = _buildPdcaMetrics();
      final activeLocksText = currentMetrics.activeDeterrenceLocks.isEmpty
          ? 'なし'
          : currentMetrics.activeDeterrenceLocks.join(', ');

      final basePrompt = _customPromptInstructions
          .replaceFirst('{userId}', userId)
          .replaceFirst('{noteCount}', noteCount.toString())
          .replaceFirst('{subCount}', subCount.toString())
          .replaceFirst('{points}', points.toString())
          .replaceFirst('{level}', level.toString())
          .replaceFirst('{currentStreak}', currentStreak.toString())
          .replaceFirst('{danshariCount}', danshariCount.toString())
          .replaceFirst(
            '{continuationCompletionRate}',
            currentMetrics.continuationCompletionRatePercent.toString(),
          )
          .replaceFirst(
            '{abstinenceViolationCount}',
            currentMetrics.abstinenceViolationCount.toString(),
          )
          .replaceFirst(
            '{abstinenceNoViolationDays}',
            currentMetrics.abstinenceNoViolationDays.toString(),
          )
          .replaceFirst(
            '{abstinenceRuleCompletionRate}',
            currentMetrics.abstinenceRuleCompletionRatePercent.toString(),
          )
          .replaceFirst(
            '{deepWorkSessionCount}',
            currentMetrics.deepWorkSessionCount.toString(),
          )
          .replaceFirst(
            '{continuationQuickStartCount}',
            currentMetrics.continuationQuickStartCount.toString(),
          )
          .replaceFirst(
            '{continuationTimeBlockReservedCount}',
            currentMetrics.continuationTimeBlockReservedCount.toString(),
          )
          .replaceFirst(
            '{continuationProgressLogCount}',
            currentMetrics.continuationProgressLogCount.toString(),
          )
          .replaceFirst(
            '{weeklyPriorityReviewCount}',
            currentMetrics.weeklyPriorityReviewCount.toString(),
          )
          .replaceFirst(
            '{accountabilityShareCount}',
            currentMetrics.accountabilityShareCount.toString(),
          )
          .replaceFirst(
            '{abstinenceRecoveryActionCount}',
            currentMetrics.abstinenceRecoveryActionCount.toString(),
          )
          .replaceFirst(
            '{abstinenceRecoveredWithin10mCount}',
            currentMetrics.abstinenceRecoveredWithin10mCount.toString(),
          )
          .replaceFirst(
            '{abstinenceRecoveryWindowMissedCount}',
            currentMetrics.abstinenceRecoveryWindowMissedCount.toString(),
          )
          .replaceFirst(
            '{deterrenceLockEnabledCount}',
            currentMetrics.deterrenceLockEnabledCount.toString(),
          )
          .replaceFirst(
            '{deterrenceStrictModeBlockCount}',
            currentMetrics.deterrenceStrictModeBlockCount.toString(),
          )
          .replaceFirst(
            '{deterrenceLockCoveragePercent}',
            currentMetrics.deterrenceLockCoveragePercent.toString(),
          )
          .replaceFirst('{activeDeterrenceLocks}', activeLocksText)
          .replaceFirst('{focusTheme}', _resolvedFocusLabel(_selectedFocus))
          .replaceFirst(
            '{focusInstruction}',
            _resolvedFocusInstruction(_selectedFocus),
          );

      setState(() => _loadingStatus = 'AI役員が継続・禁欲の改善策を議論中...');

      final startupContext = await _loadBoardStartupContext();
      final contextPrompt = _injectStartupContext(
        prompt: basePrompt,
        startupContext: startupContext,
      );

      final aiService = AIService();
      String? responseText;
      try {
        responseText = await aiService.generateContent(
          model: _selectedModel,
          prompt: contextPrompt,
        );
      } catch (e) {
        final err = e.toString();
        final hasModel404 =
            err.contains('404') && err.contains(':generateContent');
        if (!hasModel404) rethrow;

        final latestModels = await fetchGeminiModels();
        final candidateSource =
            latestModels.isNotEmpty ? latestModels : _selectableModels;

        String? fallbackModel;
        for (final item in candidateSource) {
          final candidate = item['name']?.toString() ?? '';
          if (candidate.trim().isEmpty || candidate == _selectedModel) continue;
          fallbackModel = candidate;
          break;
        }

        if (fallbackModel == null) rethrow;

        if (mounted) {
          setState(() {
            _selectedModel = fallbackModel!;
            if (latestModels.isNotEmpty) {
              _selectableModels = latestModels;
            }
          });
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gemini_model_emergency_meeting', fallbackModel);

        responseText = await aiService.generateContent(
          model: fallbackModel,
          prompt: contextPrompt,
        );
      }

      if (responseText == null) {
        throw Exception('AIからの応答がありません。');
      }

      setState(() => _loadingStatus = '会議結果を統合中...');

      final decoded = _decodeMeetingResponseJson(responseText);
      final messageListRaw = decoded['messages'];
      if (messageListRaw is! List) {
        throw const FormatException('messages が配列ではありません');
      }
      final messageList = messageListRaw;
      final conclusion = (decoded['conclusion'] ?? '').toString().trim();
      if (conclusion.isEmpty) {
        throw const FormatException('conclusion が空です');
      }
      final continuationPlan = _extractStringList(decoded['continuation_plan']);
      final abstinenceRules = _extractStringList(decoded['abstinence_rules']);
      final riskAlert = decoded['risk_alert']?.toString();
      final normalizedRiskAlert = riskAlert?.trim();
      final decodeNotice = decoded['_decode_notice']?.toString().trim();
      final rawNextMetrics = decoded['next_meeting_metrics'];
      final nextMetrics = rawNextMetrics is Map<String, dynamic>
          ? rawNextMetrics
          : (rawNextMetrics is Map
              ? Map<String, dynamic>.from(rawNextMetrics)
              : null);

      final messages = messageList
          .whereType<Map>()
          .map((item) {
            final msg = Map<String, dynamic>.from(item);
            return BoardMessage(
              id: const Uuid().v4(),
              speakerName: (msg['speaker_name'] ?? 'AI').toString(),
              role: (msg['role'] ?? 'Advisor').toString(),
              content: (msg['content'] ?? '').toString(),
              timestamp: DateTime.now(),
            );
          })
          .where((msg) => msg.content.trim().isNotEmpty)
          .toList();

      if (messages.isEmpty) {
        throw const FormatException('messages が空です');
      }

      final log = BoardMeetingLog(
        id: const Uuid().v4(),
        userId: userId,
        topic: '緊急役員会議（${_resolvedFocusLabel(_selectedFocus)}）',
        conclusion: conclusion,
        messages: messages,
        createdAt: DateTime.now(),
      );

      List<String> executionHubLogs = const <String>[];
      String? executionHubError;
      try {
        executionHubLogs = await _dispatchExecutionHub(
          log: log,
          continuationPlan: continuationPlan,
          abstinenceRules: abstinenceRules,
        );
      } catch (error) {
        executionHubError = error.toString();
        debugPrint('Failed to dispatch execution hub: $error');
      }

      setState(() {
        _currentLog = log;
        _continuationPlan = continuationPlan;
        _abstinenceRules = abstinenceRules;
        _continuationChecks = List<bool>.filled(continuationPlan.length, false);
        _abstinenceChecks = List<bool>.filled(abstinenceRules.length, false);
        _selectedContinuationPriorityIndex = continuationPlan.isEmpty ? -1 : 0;
        _riskAlert =
            (normalizedRiskAlert == null || normalizedRiskAlert.isEmpty)
                ? null
                : normalizedRiskAlert;
        _decodeNotice = (decodeNotice == null || decodeNotice.isEmpty)
            ? null
            : decodeNotice;
        _executionHubLogs = executionHubLogs;
        _executionHubError = executionHubError;
        if (nextMetrics != null) {
          _applyNextMeetingMetrics(nextMetrics);
        }
      });
      await _persistPdcaState();
      await _saveMeetingToDb(log);
    } catch (e, s) {
      if (mounted) {
        final errString = e.toString();
        debugPrint('Failed to convene board: $e');
        debugPrint('Stack trace: $s');

        if (errString.contains('503') || errString.contains('UNAVAILABLE')) {
          _errorMessage = 'AIモデルが現在高負荷です。しばらくしてから再試行してください。';
        } else if (errString.contains('429') ||
            errString.contains('Quota') ||
            errString.contains('rate limit')) {
          _errorMessage = '「$_selectedModel」は利用上限に達しました。別のモデルを試してください。';
        } else if (errString.contains('FormatException')) {
          _errorMessage = 'AI応答のJSON形式が崩れていました。再試行するか、別モデルに切り替えてください。';
        } else if (errString.contains('400') &&
            errString.contains('API key not valid')) {
          _errorMessage = 'サーバーのAI認証設定を確認してください。';
        } else {
          _errorMessage = '会議エラー: $errString';
        }
        setState(() {}); // Update UI to show error
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runBoardMeetingBiReport() async {
    await _ensureSelectedModelIsAvailable();

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadingStatus = '役員会議のデータを集計中...';
      _errorMessage = null;
      _continuationPlan = <String>[];
      _abstinenceRules = <String>[];
      _continuationChecks = <bool>[];
      _abstinenceChecks = <bool>[];
      _selectedContinuationPriorityIndex = -1;
      _riskAlert = null;
      _decodeNotice = null;
      _executionHubLogs = <String>[];
      _executionHubError = null;
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in.');
      }

      final results = await Future.wait<dynamic>([
        _supabase
            .from('notes')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0),
        _supabase
            .from('subscriptions')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0),
        _supabase
            .from('user_stats')
            .select()
            .eq('user_id', userId)
            .maybeSingle()
            .catchError((_) => null),
        _supabase
            .from('danshari_items')
            .count(CountOption.exact)
            .eq('user_id', userId)
            .catchError((_) => 0),
      ]);

      final noteCount = results[0] as int;
      final subCount = results[1] as int;
      final userStats = results[2] as Map<String, dynamic>?;
      final danshariCount = results[3] as int;
      final points = _toInt(userStats?['total_points']);
      final level = _toInt(userStats?['current_level'], fallback: 1);
      final currentStreak = _toInt(userStats?['current_streak']);
      final currentMetrics = _buildPdcaMetrics();
      final startupContext = await _loadBoardStartupContext();
      final reportContext = EmergencyMeetingReportContext(
        userId: userId,
        noteCount: noteCount,
        subscriptionCount: subCount,
        points: points,
        level: level,
        currentStreak: currentStreak,
        danshariCount: danshariCount,
        focusLabel: _resolvedFocusLabel(_selectedFocus),
        focusInstruction: _resolvedFocusInstruction(_selectedFocus),
        metrics: currentMetrics,
        startupContext: startupContext,
      );

      setState(() {
        _loadingStatus = 'BIレポートを生成中...';
      });

      final prompt = _meetingReportService.buildPrompt(reportContext);
      final aiService = AIService(_supabase);
      final rawResult = await aiService.holdBoardMeeting(
        context: prompt,
        model: _selectedModel,
      );
      final report = _meetingReportService.normalizeReport(
        rawResult: rawResult,
        context: reportContext,
      );

      setState(() {
        _loadingStatus = '役員アクションを展開中...';
      });

      final now = DateTime.now();
      final log = BoardMeetingLog(
        id: const Uuid().v4(),
        userId: userId,
        topic: '緊急役員会議（${_resolvedFocusLabel(_selectedFocus)}）',
        conclusion: report.conclusion,
        messages: report.messages,
        createdAt: now,
      );

      List<String> executionHubLogs = const <String>[];
      String? executionHubError;
      try {
        executionHubLogs = await _dispatchExecutionHub(
          log: log,
          continuationPlan: report.continuationPlan,
          abstinenceRules: report.abstinenceRules,
        );
      } catch (error) {
        executionHubError = error.toString();
        debugPrint('Failed to dispatch execution hub: $error');
      }

      setState(() {
        _currentLog = log;
        _continuationPlan = report.continuationPlan;
        _abstinenceRules = report.abstinenceRules;
        _continuationChecks =
            List<bool>.filled(report.continuationPlan.length, false);
        _abstinenceChecks =
            List<bool>.filled(report.abstinenceRules.length, false);
        _selectedContinuationPriorityIndex =
            report.continuationPlan.isEmpty ? -1 : 0;
        _riskAlert = report.riskAlert;
        _decodeNotice = report.decodeNotice;
        _executionHubLogs = executionHubLogs;
        _executionHubError = executionHubError;
        _applyNextMeetingMetrics(report.nextMeetingMetrics);
      });
      await _persistPdcaState();
      await _saveMeetingToDb(log);
    } catch (e, s) {
      debugPrint('Failed to run BI board meeting: $e');
      debugPrint('Stack trace: $s');
      if (mounted) {
        final errString = e.toString();
        setState(() {
          if (errString.contains('503') || errString.contains('UNAVAILABLE')) {
            _errorMessage = 'AI モデルが一時的に利用できません。少し待ってから再試行してください。';
          } else if (errString.contains('429') ||
              errString.contains('Quota') ||
              errString.contains('rate limit')) {
            _errorMessage = 'AI 利用が混み合っています。モデルを変えるか、時間をおいて再試行してください。';
          } else {
            _errorMessage = '緊急役員会議の生成に失敗しました: $errString';
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveMeetingToDb(BoardMeetingLog log) async {
    try {
      final dynamic inserted = await _supabase.from('board_meetings').insert({
        'id': log.id,
        'user_id': log.userId,
        'topic': log.topic,
        'conclusion': log.conclusion,
        'created_at': log.createdAt.toIso8601String(),
      }).select('id');

      String meetingId = log.id;
      if (inserted is List && inserted.isNotEmpty) {
        final first = inserted.first;
        if (first is Map && first['id'] != null) {
          meetingId = first['id'].toString();
        }
      } else if (inserted is Map && inserted['id'] != null) {
        meetingId = inserted['id'].toString();
      }

      final messagesToInsert = log.messages.map((msg) {
        return {
          'meeting_id': meetingId,
          'speaker_name': msg.speakerName,
          'role': msg.role,
          'content': msg.content,
          'created_at': msg.timestamp.toIso8601String(),
        };
      }).toList();

      if (messagesToInsert.isNotEmpty) {
        await _supabase.from('board_messages').insert(messagesToInsert);
      }
    } catch (e) {
      debugPrint('Failed to save meeting log: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('emergency_meeting_page_scaffold'),
      appBar: AppBar(
        title: const Text(
          '緊急役員会議 (継続・禁欲)',
          key: Key('emergency_meeting_page_title'),
        ),
        backgroundColor: Colors.red[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: (_isLoading || _currentLog == null)
                ? null
                : _copyMeetingForCodex,
            tooltip: 'Codex用にコピー',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: showSettingsDialog,
            tooltip: 'AIモデル設定',
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          if (_currentLog == null && !_isLoading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emergency_share,
                        size: 80,
                        color: Color(0xFFE53935),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '衝動を止めて、嫌な必須行動に切り替えますか？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'なんとなくやりたいことへの逃避を先に塞ぎ、'
                        'なんとなくやりたくない必須行動へ戻すための48時間プランを提示します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '会議フォーカス: ${_resolvedFocusLabel(_selectedFocus)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: MeetingFocus.values.map((focus) {
                          final isSelected = _selectedFocus == focus;
                          final chipColor = _focusColor(focus);
                          return ChoiceChip(
                            key: Key('emergency_meeting_focus_${focus.name}'),
                            label: Text(_resolvedFocusShortLabel(focus)),
                            selected: isSelected,
                            selectedColor: chipColor.withValues(alpha: 0.18),
                            side: BorderSide(
                              color: isSelected
                                  ? chipColor
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? chipColor
                                  : Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _selectedFocus = focus);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _resolvedFocusInstruction(_selectedFocus),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '使用モデル: ',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _selectedModel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // --- Error Message Display ---
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // --- Convene Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _runBoardMeetingBiReport,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text(
                            '衝動を止めて、嫌な必須行動へ戻す',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            disabledBackgroundColor: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoading)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFE53935)),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '継続と禁欲の打ち手を組み立てています...',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: (_currentLog?.messages.length ?? 0) + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Center(
                        child: Text(
                          '${_currentLog!.createdAt.year}年${_currentLog!.createdAt.month}月${_currentLog!.createdAt.day}日 臨時取締役会',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    );
                  }
                  if (index == _currentLog!.messages.length + 1) {
                    return _buildConclusionCard();
                  }
                  final msg = _currentLog!.messages[index - 1];
                  return _buildMessageCard(msg);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(BoardMessage msg) {
    final isCeo = msg.role == 'CEO';
    final isCso = msg.role == 'CSO';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCso ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCso
            ? const BorderSide(color: Color(0xFFFF6B35), width: 2)
            : BorderSide.none,
      ),
      color: isCeo
          ? (isDark ? const Color(0xFF1A2533) : const Color(0xFFE3F2FD))
          : (isDark ? const Color(0xFF1A1A1A) : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getRoleColor(msg.role),
                  child: Icon(
                    _getRoleIcon(msg.role),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.speakerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        msg.role,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AgentGpaBadge(
                  sourceType: 'executive_meeting',
                  sourceId: _currentLog?.id,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              msg.content,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConclusionCard() {
    if (_currentLog?.conclusion == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt, color: Colors.lightGreenAccent),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '継続・禁欲 EXECUTION PLAN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: _copyMeetingForCodex,
                tooltip: '会議結果をコピー',
                icon: const Icon(
                  Icons.content_copy,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          _buildDopamineDisasterPanel(),
          const SizedBox(height: 14),
          if (_riskAlert != null) ...[
            _buildAlertChip(_riskAlert!),
            const SizedBox(height: 14),
          ],
          if (_decodeNotice != null) ...[
            _buildRecoveryNoticeChip(_decodeNotice!),
            const SizedBox(height: 14),
          ],
          if (_executionHubLogs.isNotEmpty || _executionHubError != null) ...[
            _buildExecutionHubPanel(),
            const SizedBox(height: 14),
          ],
          if (_continuationPlan.isNotEmpty) ...[
            _buildContinuationExecutionPanel(),
            const SizedBox(height: 14),
          ],
          if (_abstinenceRules.isNotEmpty) ...[
            _buildAbstinenceGuardPanel(),
            const SizedBox(height: 14),
          ],
          _buildNextMeetingMetricsPanel(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _recordPdcaReview,
                  icon: const Icon(Icons.fact_check),
                  label: const Text('指標を保存'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyMeetingForCodex,
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Codexにコピー'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            '最終決定',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentLog!.conclusion,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copyMeetingForCodex,
              icon: const Icon(Icons.copy_all),
              label: const Text('Codexに貼り付ける結果をコピー'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionHubPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.lightGreenAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.lightGreenAccent.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub, color: Colors.lightGreenAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Execution Hub',
                style: TextStyle(
                  color: Colors.lightGreenAccent,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_executionHubError != null)
            Text(
              'Dispatch warning: $_executionHubError',
              style: const TextStyle(color: Color(0xFFFF6B35), height: 1.4),
            ),
          if (_executionHubLogs.isNotEmpty)
            ..._executionHubLogs.map(
              (line) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '- $line',
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDopamineDisasterPanel() {
    final nextIndex = _nextPendingContinuationIndex();
    final hasPending = nextIndex >= 0 && nextIndex < _continuationPlan.length;
    final nextAction = hasPending
        ? _continuationPlan[nextIndex]
        : '未完了の必須行動はありません。現状維持を続けてください。';
    final activeLockCount = _activeDeterrenceLocks().length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x33FF5252), Color(0x229C27B0)],
        ),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gpp_bad, color: Color(0xFFE53935), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ドーパミン災害モード',
                  style: TextStyle(
                    color: Color(0xFFE53935),
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '「なんとなくやりたいこと」に逃げるのを先に止めて、'
            '「なんとなくやりたくない必須行動」を先に実行する。',
            style: TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 8),
          Text(
            '今すぐやるべき嫌な1件: $nextAction',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '現在の衝動遮断ロック: $activeLockCount/3件',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _enableEmergencyDeterrenceMode,
                  icon: const Icon(Icons.lock),
                  label: const Text('衝動遮断を強制ON'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (hasPending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _markContinuationQuickStart,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('嫌な1件に着手'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _completeNextContinuationAction,
                    icon: const Icon(Icons.done_all),
                    label: const Text('嫌な1件を完了'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContinuationExecutionPanel() {
    final completed = _continuationChecks.where((isDone) => isDone).length;
    final total = _continuationChecks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final priorityIndex = _currentPriorityContinuationIndex();
    final hasPending =
        priorityIndex >= 0 && priorityIndex < _continuationPlan.length;
    final nextActionText =
        hasPending ? _continuationPlan[priorityIndex] : '全タスク完了';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF3D5AFE).withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Color(0xFF3D5AFE),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'なんとなくやりたくないことをやる（48時間）',
                  style: TextStyle(
                    color: Color(0xFF3D5AFE),
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFF3D5AFE),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '15分ブロック予約: $_continuationTimeBlockReservedCount回 / 48h進捗ログ: $_continuationProgressLogCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '30分深掘り実施: $_deepWorkSessionCount回 / 週次優先レビュー: $_weeklyPriorityReviewCount回 / '
            'クイック着手: $_continuationQuickStartCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '最重要宣言: $_continuationPriorityDeclaredCount回 / 25分着手: $_continuationFocusSprint25Count回 / '
            '共有宣言: $_accountabilityShareCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3D5AFE).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3D5AFE).withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '今日の最重要1件',
                  style: TextStyle(
                    color: Color(0xFF3D5AFE),
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextActionText,
                  style: TextStyle(
                    color: hasPending ? Colors.white : Colors.white70,
                    height: 1.35,
                  ),
                ),
                if (hasPending) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const Key('continuation_pin_priority_button'),
                          onPressed: _pinNextContinuationPriority,
                          icon: const Icon(Icons.push_pin),
                          label: const Text('最重要に固定'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('continuation_focus_sprint_25_button'),
                          onPressed: _markContinuationQuickStart,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('25分だけ着手'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('continuation_accountability_button'),
                          onPressed: _recordAccountabilityShare,
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('共有を宣言'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: _completeNextContinuationAction,
                          icon: const Icon(Icons.check),
                          label: const Text('固定1件を完了'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('continuation_execute_now_button'),
                      onPressed: _quickStartAndCompleteNextContinuationAction,
                      icon: const Icon(Icons.bolt),
                      label: const Text('今すぐ1件を実行して完了'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _recordDeepWorkSession,
                  icon: const Icon(Icons.timer),
                  label: const Text('30分深掘り完了'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _recordPriorityReview,
                  icon: const Icon(Icons.event_available),
                  label: const Text('優先レビュー完了'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('continuation_reserve_time_block_button'),
                  onPressed: _reserveContinuationTimeBlock,
                  icon: const Icon(Icons.schedule),
                  label: const Text('明朝15分ブロック予約'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('continuation_log_48h_progress_button'),
                  onPressed: _recordContinuationProgressLog,
                  icon: const Icon(Icons.history_toggle_off),
                  label: const Text('48h進捗ログ記録'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _continuationPlan.length; i++)
            CheckboxListTile(
              value: i < _continuationChecks.length && _continuationChecks[i],
              onChanged: (value) => _toggleContinuationCheck(i, value),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFF3D5AFE),
              checkColor: Colors.black,
              secondary: IconButton(
                key: Key('continuation_pin_action_$i'),
                onPressed: () => _pinContinuationAction(i),
                icon: Icon(
                  i == _selectedContinuationPriorityIndex
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: i == _selectedContinuationPriorityIndex
                      ? const Color(0xFFFFD740)
                      : Colors.white54,
                ),
                tooltip: '今日の最重要1件に固定',
              ),
              title: Text(
                i == _selectedContinuationPriorityIndex
                    ? '最重要: ${_continuationPlan[i]}'
                    : _continuationPlan[i],
                style: TextStyle(
                  color: Colors.white,
                  height: 1.35,
                  fontWeight: i == _selectedContinuationPriorityIndex
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAbstinenceGuardPanel() {
    final abstinenceCompleted = _currentAbstinenceCompletedCount();
    final abstinenceTotal = _abstinenceChecks.length;
    final abstinenceRatePercent = _currentAbstinenceRuleRatePercent();
    final abstinenceProgress =
        abstinenceTotal == 0 ? 0.0 : abstinenceCompleted / abstinenceTotal;
    final activeLockCount = _activeDeterrenceLocks().length;
    final lockCoverage = activeLockCount / 3;
    final deterrenceScore =
        (_abstinenceNoViolationDays - _abstinenceViolationCount)
            .clamp(0, 10)
            .toDouble();
    final deterrenceProgress = deterrenceScore / 10;
    final hasPendingRecoveryWindow = _hasPendingRecoveryWindow();
    final recoveryWindowRemaining = _remainingRecoveryWindow();
    final remainingRecoverySeconds =
        recoveryWindowRemaining?.inSeconds.clamp(0, 600) ?? 0;
    final recoveryActionTotal = _abstinenceRecoveryActionCount;
    final recoveryWithinRatePercent = recoveryActionTotal == 0
        ? 0
        : ((_abstinenceRecoveredWithin10mCount / recoveryActionTotal) * 100)
            .round();
    final deterrenceReadinessPercent = _deterrenceReadinessPercent();

    if (_abstinenceRecoveryDueAt != null && !hasPendingRecoveryWindow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _flushExpiredRecoveryWindowIfNeeded();
      });
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block, color: Color(0xFFFF6B35), size: 18),
              SizedBox(width: 8),
              Text(
                'なんとなくやりたい衝動を止める',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '違反: $_abstinenceViolationCount回 / 連続無違反: $_abstinenceNoViolationDays日',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: deterrenceProgress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 8),
          Text(
            '禁欲ルール実行率: $abstinenceRatePercent% '
            '($abstinenceCompleted/$abstinenceTotal)',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: abstinenceProgress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 8),
          Text(
            'ロック有効率: ${(lockCoverage * 100).round()}% ($activeLockCount/3)',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: lockCoverage,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
          const SizedBox(height: 8),
          Text(
            '抑止準備度: $deterrenceReadinessPercent% / 回復通知予約: $_abstinenceRecoveryReminderScheduledCount回 / '
            '緩和ブロック: $_deterrenceDisableAttemptBlockedCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDeterrenceStatusChip(
                label: '通知',
                ready: _dailyReminderEnabled,
              ),
              _buildDeterrenceStatusChip(
                label: 'ロック1件',
                ready: activeLockCount > 0,
              ),
              _buildDeterrenceStatusChip(
                label: '10分回復',
                ready: !hasPendingRecoveryWindow,
              ),
            ],
          ),
          if (hasPendingRecoveryWindow) ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('abstinence_pending_recovery_window_banner'),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935).withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.8),
                ),
              ),
              child: Text(
                '厳格モード: 逸脱後10分以内の再設定が未実施です。残り ${remainingRecoverySeconds}s 以内に「即時リカバリー」を実行してください。',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (activeLockCount < 2) ...[
            const SizedBox(height: 6),
            const Text(
              '抑止力が弱めです。ロックを2つ以上ONにして再発を防止してください。',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('SNS制限ロック'),
                selected: _lockImpulsePurchase,
                onSelected: _toggleImpulsePurchaseLock,
                selectedColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
              ),
              FilterChip(
                label: const Text('90分タイムボックス'),
                selected: _lockNewProjects,
                onSelected: _toggleNewProjectsLock,
                selectedColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
              ),
              FilterChip(
                label: const Text('週次共有リマインド'),
                selected: _lockSubscriptionAdditions,
                onSelected: _toggleSubscriptionAdditionsLock,
                selectedColor: const Color(0xFFFF6B35).withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _dailyReminderEnabled,
            onChanged: _attemptToggleDailyReminder,
            title: const Text(
              '毎日21:00に禁欲チェック通知',
              style: TextStyle(
                color: Colors.white,
                height: 1.5,
              ),
            ),
            subtitle: const Text(
              '通知で衝動行動を先回り抑止',
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            activeThumbColor: const Color(0xFFFF6B35),
            activeTrackColor: const Color(0xFFFF6B35).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            '進捗共有記録: $_accountabilityShareCount回 / 即時リカバリー: $_abstinenceRecoveryActionCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '10分内リカバリー成功: $_abstinenceRecoveredWithin10mCount回 / 10分超過: $_abstinenceRecoveryWindowMissedCount回 '
            '(成功率 $recoveryWithinRatePercent%)',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '厳格モード抑止発生: $_deterrenceStrictModeBlockCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '通知先回り: $_abstinenceRecoveryReminderScheduledCount回 / ロック・通知の緩和ブロック: $_deterrenceDisableAttemptBlockedCount回',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('abstinence_record_violation_button'),
                  onPressed: _recordAbstinenceViolation,
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('違反を記録'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('abstinence_record_clean_day_button'),
                  onPressed: _recordAbstinenceCleanDay,
                  icon: const Icon(Icons.verified),
                  label: const Text('本日違反なし'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('abstinence_record_accountability_button'),
              onPressed: _recordAccountabilityShare,
              icon: const Icon(Icons.group),
              label: const Text('週次共有を記録'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('abstinence_immediate_recovery_button'),
              onPressed: _recordAbstinenceRecoveryAction,
              icon: const Icon(Icons.restart_alt),
              label: const Text('違反後の即時リカバリーを記録'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < _abstinenceRules.length; i++)
            CheckboxListTile(
              value: i < _abstinenceChecks.length && _abstinenceChecks[i],
              onChanged: (value) => _toggleAbstinenceCheck(i, value),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFFF6B35),
              checkColor: Colors.black,
              title: Text(
                _abstinenceRules[i],
                style: const TextStyle(color: Colors.white, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNextMeetingMetricsPanel() {
    final metrics = _buildPdcaMetrics();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.query_stats, color: Color(0xFFFFC107), size: 18),
              SizedBox(width: 8),
              Text(
                '次回会議の検証指標',
                style: TextStyle(
                  color: Color(0xFFFFC107),
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '追加PDCA指標: 最重要宣言 ${metrics.continuationPriorityDeclaredCount} / 25分着手 ${metrics.continuationFocusSprint25Count} / '
            '15分予約 ${metrics.continuationTimeBlockReservedCount} / 48h進捗ログ ${metrics.continuationProgressLogCount} / '
            '10分内回復 ${metrics.abstinenceRecoveredWithin10mCount} / 10分超過 ${metrics.abstinenceRecoveryWindowMissedCount} / '
            '回復通知 ${metrics.abstinenceRecoveryReminderScheduledCount} / 緩和ブロック ${metrics.deterrenceDisableAttemptBlockedCount} / '
            '厳格抑止 ${metrics.deterrenceStrictModeBlockCount} / ロック網羅率 ${metrics.deterrenceLockCoveragePercent}%',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '継続完了率: ${metrics.continuationCompletionRatePercent}% '
            '(${metrics.continuationCompletedCount}/${metrics.continuationTotalCount})',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲違反回数: ${metrics.abstinenceViolationCount} / 連続無違反日数: ${metrics.abstinenceNoViolationDays}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲ルール実行率: ${metrics.abstinenceRuleCompletionRatePercent}% '
            '(${metrics.abstinenceRuleCompletedCount}/${metrics.abstinenceRuleTotalCount})',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '深掘り実施回数: ${metrics.deepWorkSessionCount} / 優先レビュー回数: ${metrics.weeklyPriorityReviewCount}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'クイック着手回数: ${metrics.continuationQuickStartCount} / 25分着手回数: ${metrics.continuationFocusSprint25Count}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '進捗共有回数: ${metrics.accountabilityShareCount}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '即時リカバリー回数: ${metrics.abstinenceRecoveryActionCount} / 回復通知予約: ${metrics.abstinenceRecoveryReminderScheduledCount}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲チェック通知: ${metrics.reminderEnabled ? '有効' : '無効'}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '有効ロック: ${metrics.deterrenceLockEnabledCount}件'
            ' (${metrics.activeDeterrenceLocks.isEmpty ? 'なし' : metrics.activeDeterrenceLocks.join(', ')})',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '緩和ブロック回数: ${metrics.deterrenceDisableAttemptBlockedCount}',
            style: const TextStyle(
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '最終指標保存: ${metrics.lastReviewAt?.toIso8601String() ?? '未保存'}',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeterrenceStatusChip({
    required String label,
    required bool ready,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ready
            ? Colors.greenAccent.withValues(alpha: 0.16)
            : const Color(0xFFFF6B35).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: ready
              ? Colors.greenAccent.withValues(alpha: 0.55)
              : const Color(0xFFFF6B35).withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        ready ? '$label OK' : '$label 要対応',
        style: TextStyle(
          color: ready ? Colors.greenAccent : const Color(0xFFFF6B35),
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildAlertChip(String alertText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF6B35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFFF6B35),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alertText,
              style: const TextStyle(
                color: Colors.white,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryNoticeChip(String noticeText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF607D8B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90A4AE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.build_circle_outlined,
            color: Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              noticeText,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return const Color(0xFF3D5AFE);
      case 'CSO':
        return const Color(0xFFEF6C00);
      case 'CFO':
        return const Color(0xFF388E3C);
      case 'CKO':
        return const Color(0xFF3D5AFE);
      case 'CMO':
        return const Color(0xFFFF6B35);
      case 'CHO':
        return const Color(0xFF009688);
      case 'CHRO':
        return const Color(0xFF3D5AFE);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'CEO':
        return Icons.person;
      case 'CSO':
        return Icons.flag;
      case 'CFO':
        return Icons.attach_money;
      case 'CKO':
        return Icons.school;
      case 'CMO':
        return Icons.analytics;
      case 'CHO':
        return Icons.favorite;
      case 'CHRO':
        return Icons.diversity_3;
      default:
        return Icons.smart_toy;
    }
  }
}

// Add the BoardMeetingLog and BoardMessage models if they are not in a separate file.
// For the purpose of this file, I'm assuming they might look something like this.
// NOTE: I'm getting an error that BoardMeetingLog is not defined. I will define it.
