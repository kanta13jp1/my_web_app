import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_web_app/models/board_meeting.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/emergency_meeting_pdca_service.dart';
import 'package:my_web_app/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

enum MeetingFocus {
  balanced,
  continuation,
  abstinence,
}

class EmergencyMeetingPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;

  const EmergencyMeetingPage({super.key, this.supabaseClient});

  @override
  State<EmergencyMeetingPage> createState() => _EmergencyMeetingPageState();
}

class _EmergencyMeetingPageState extends State<EmergencyMeetingPage> {
  final ScrollController _scrollController = ScrollController();
  BoardMeetingLog? _currentLog;
  bool _isLoading = false;
  String _loadingStatus = '';

  String? _geminiApiKey;
  String _selectedModel = 'gemma-3-4b-it';
  MeetingFocus _selectedFocus = MeetingFocus.balanced;
  List<String> _continuationPlan = <String>[];
  List<String> _abstinenceRules = <String>[];
  List<bool> _continuationChecks = <bool>[];
  List<bool> _abstinenceChecks = <bool>[];
  String? _riskAlert;
  int _abstinenceViolationCount = 0;
  int _abstinenceNoViolationDays = 0;
  int _lastContinuationCompletionRate = 0;
  int _continuationQuickStartCount = 0;
  int _deepWorkSessionCount = 0;
  int _weeklyPriorityReviewCount = 0;
  int _accountabilityShareCount = 0;
  int _abstinenceRecoveryActionCount = 0;
  bool _dailyReminderEnabled = false;
  bool _lockImpulsePurchase = false;
  bool _lockNewProjects = false;
  bool _lockSubscriptionAdditions = false;
  DateTime? _lastReviewAt;
  List<Map<String, dynamic>> _selectableModels = [
    {
      'name': 'gemma-3-1b-it',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemma-3-4b-it',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-1.5-flash',
      'methods': ['generateContent'],
    },
    {
      'name': 'gemini-1.5-pro',
      'methods': ['generateContent'],
    },
  ];
  final String _customPromptInstructions = _defaultPromptInstructions;
  static const String _prefsAbstinenceViolationCount =
      'emergency_abstinence_violation_count';
  static const String _prefsAbstinenceNoViolationDays =
      'emergency_abstinence_no_violation_days';
  static const String _prefsContinuationCompletionRate =
      'emergency_continuation_completion_rate';
  static const String _prefsContinuationQuickStartCount =
      'emergency_continuation_quick_start_count';
  static const String _prefsDeepWorkSessionCount =
      'emergency_deep_work_session_count';
  static const String _prefsWeeklyPriorityReviewCount =
      'emergency_weekly_priority_review_count';
  static const String _prefsAccountabilityShareCount =
      'emergency_accountability_share_count';
  static const String _prefsAbstinenceRecoveryActionCount =
      'emergency_abstinence_recovery_action_count';
  static const String _prefsDailyReminderEnabled =
      'emergency_daily_reminder_enabled';
  static const String _prefsLockImpulsePurchase = 'emergency_lock_impulse';
  static const String _prefsLockNewProjects = 'emergency_lock_new_projects';
  static const String _prefsLockSubscriptionAdditions =
      'emergency_lock_subscription_additions';
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
      '- weeklyPriorityReviewCount: {weeklyPriorityReviewCount}\n'
      '- accountabilityShareCount: {accountabilityShareCount}\n'
      '- abstinenceRecoveryActionCount: {abstinenceRecoveryActionCount}\n'
      '- deterrenceLockEnabledCount: {deterrenceLockEnabledCount}\n'
      '- activeDeterrenceLocks: {activeDeterrenceLocks}\n'
      '- healthData: "データ未連携"\n'
      '- marketData: "データ未連携"\n'
      '- importUsed: "未確認"\n\n'
      '【役員構成】\n'
      '- CFO: 支出とサブスクの最適化\n'
      '- CKO: 学習と記録の継続設計\n'
      '- CHRO: 習慣維持とモチベーション管理\n'
      '- CSO: 全体戦略と実行計画の統合\n\n'
      '【出力ルール】\n'
      '1. messages は4〜6件。各役員が数字に触れて短く提言する。\n'
      '2. continuation_plan は「48時間以内に実行する継続アクション」を3件。\n'
      '3. abstinence_rules は「誘惑を断つ禁欲ルール」を3件。\n'
      '4. risk_alert は最大リスクを1文で示す。\n'
      '5. conclusion は CEO が今週やる最優先アクションを1〜2文で示す。\n'
      '6. next_meeting_metrics に以下を必ず含める: continuation_quick_start_count, '
      'abstinence_rule_completion_rate_percent, abstinence_recovery_action_count, '
      'deterrence_lock_enabled_count。\n'
      '7. 返答はJSONのみ。Markdownや説明文は不要。\n\n'
      '{\n'
      '  "messages": [\n'
      '    {"role":"CFO","speaker_name":"AI CFO","content":"..."},\n'
      '    {"role":"CKO","speaker_name":"AI CKO","content":"..."},\n'
      '    {"role":"CHRO","speaker_name":"AI CHRO","content":"..."},\n'
      '    {"role":"CSO","speaker_name":"AI CSO","content":"..."}\n'
      '  ],\n'
      '  "continuation_plan": ["...", "...", "..."],\n'
      '  "abstinence_rules": ["...", "...", "..."],\n'
      '  "risk_alert": "...",\n'
      '  "conclusion": "...",\n'
      '  "next_meeting_metrics": {\n'
      '    "continuation_quick_start_count": 0,\n'
      '    "abstinence_rule_completion_rate_percent": 0,\n'
      '    "abstinence_recovery_action_count": 0,\n'
      '    "deterrence_lock_enabled_count": 0\n'
      '  }\n'
      '}';

  // Supabase client getter
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadSettings(); // Changed from _fetchModels
    _loadPdcaState();
  }

  // --- Start of new functions ---

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _geminiApiKey = prefs.getString('gemini_api_key');
        // A model saved for the daily report can be reused here for consistency
        final String? savedModel =
            prefs.getString('gemini_model_emergency_meeting') ??
                prefs.getString('gemini_model');
        if (savedModel != null) {
          _selectedModel = savedModel;
        }
        // Ensure the selected model is in the list, if not, add it.
        if (!_selectableModels.any((m) => m['name'] == _selectedModel)) {
          _selectableModels.insert(0, {
            'name': _selectedModel,
            'methods': ['generateContent'],
          });
        }
      });
    }
  }

  Future<void> _loadPdcaState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedReviewAt = prefs.getString(_prefsLastReviewAt);
    if (!mounted) return;

    setState(() {
      _abstinenceViolationCount =
          prefs.getInt(_prefsAbstinenceViolationCount) ?? 0;
      _abstinenceNoViolationDays =
          prefs.getInt(_prefsAbstinenceNoViolationDays) ?? 0;
      _lastContinuationCompletionRate =
          prefs.getInt(_prefsContinuationCompletionRate) ?? 0;
      _continuationQuickStartCount =
          prefs.getInt(_prefsContinuationQuickStartCount) ?? 0;
      _deepWorkSessionCount = prefs.getInt(_prefsDeepWorkSessionCount) ?? 0;
      _weeklyPriorityReviewCount =
          prefs.getInt(_prefsWeeklyPriorityReviewCount) ?? 0;
      _accountabilityShareCount =
          prefs.getInt(_prefsAccountabilityShareCount) ?? 0;
      _abstinenceRecoveryActionCount =
          prefs.getInt(_prefsAbstinenceRecoveryActionCount) ?? 0;
      _dailyReminderEnabled =
          prefs.getBool(_prefsDailyReminderEnabled) ?? false;
      _lockImpulsePurchase = prefs.getBool(_prefsLockImpulsePurchase) ?? false;
      _lockNewProjects = prefs.getBool(_prefsLockNewProjects) ?? false;
      _lockSubscriptionAdditions =
          prefs.getBool(_prefsLockSubscriptionAdditions) ?? false;
      _lastReviewAt =
          savedReviewAt == null ? null : DateTime.tryParse(savedReviewAt);
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
      _prefsContinuationQuickStartCount,
      _continuationQuickStartCount,
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
    await prefs.setBool(_prefsDailyReminderEnabled, _dailyReminderEnabled);
    await prefs.setBool(_prefsLockImpulsePurchase, _lockImpulsePurchase);
    await prefs.setBool(_prefsLockNewProjects, _lockNewProjects);
    await prefs.setBool(
      _prefsLockSubscriptionAdditions,
      _lockSubscriptionAdditions,
    );
    if (_lastReviewAt != null) {
      await prefs.setString(
        _prefsLastReviewAt,
        _lastReviewAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_prefsLastReviewAt);
    }
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
    for (var i = 0; i < _continuationChecks.length; i++) {
      if (!_continuationChecks[i]) return i;
    }
    return -1;
  }

  List<String> _activeDeterrenceLocks() {
    final locks = <String>[];
    if (_lockImpulsePurchase) locks.add('SNS制限ロック');
    if (_lockNewProjects) locks.add('90分タイムボックス');
    if (_lockSubscriptionAdditions) locks.add('週次共有リマインド');
    return locks;
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
      continuationQuickStartCount: _continuationQuickStartCount,
      abstinenceViolationCount: _abstinenceViolationCount,
      abstinenceNoViolationDays: _abstinenceNoViolationDays,
      abstinenceRuleCompletedCount: abstinenceCompleted,
      abstinenceRuleTotalCount: abstinenceTotal,
      abstinenceRuleCompletionRatePercent: _currentAbstinenceRuleRatePercent(),
      deepWorkSessionCount: _deepWorkSessionCount,
      weeklyPriorityReviewCount: _weeklyPriorityReviewCount,
      accountabilityShareCount: _accountabilityShareCount,
      abstinenceRecoveryActionCount: _abstinenceRecoveryActionCount,
      reminderEnabled: _dailyReminderEnabled,
      deterrenceLockEnabledCount: activeLocks.length,
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
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
    });
    _persistPdcaState();
  }

  Future<void> _markContinuationQuickStart() async {
    final nextIndex = _nextPendingContinuationIndex();
    if (nextIndex < 0) return;
    setState(() {
      _continuationQuickStartCount += 1;
    });
    await _persistPdcaState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '次の1件に着手を記録しました: ${_continuationPlan[nextIndex]}',
        ),
      ),
    );
  }

  Future<void> _completeNextContinuationAction() async {
    final nextIndex = _nextPendingContinuationIndex();
    if (nextIndex < 0) return;
    setState(() {
      _continuationChecks[nextIndex] = true;
      _lastContinuationCompletionRate = _currentContinuationRatePercent();
    });
    await _persistPdcaState();
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

  Future<void> _recordAbstinenceViolation() async {
    setState(() {
      _abstinenceViolationCount += 1;
      _abstinenceNoViolationDays = 0;
    });
    if (!_dailyReminderEnabled) {
      await _toggleDailyReminder(true);
    }
    await _persistPdcaState();
  }

  Future<void> _recordAbstinenceCleanDay() async {
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
    setState(() => _abstinenceRecoveryActionCount += 1);
    await _persistPdcaState();
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

  Future<List<Map<String, dynamic>>> fetchGeminiModels(String apiKey) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            json.decode(response.body) as Map<String, dynamic>;
        final modelsRaw = data['models'];
        if (modelsRaw is List) {
          return modelsRaw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .where((m) {
            final methods = m['supportedGenerationMethods'];
            return methods is List && methods.contains('generateContent');
          }).map<Map<String, dynamic>>((m) {
            final methods = (m['supportedGenerationMethods'] as List)
                .cast<Object>()
                .map((v) => v.toString())
                .toList();
            return {
              'name': (m['name'] ?? '').toString().replaceFirst(
                    'models/',
                    '',
                  ),
              'methods': methods,
            };
          }).where((m) {
            final name = (m['name'] ?? '').toString();
            return !name.contains('tts') && !name.contains('embedding');
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch models: $e');
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _ensureSelectedModelIsAvailable() async {
    final apiKey = _geminiApiKey?.trim();
    if (apiKey == null || apiKey.isEmpty) return;

    final fetchedModels = await fetchGeminiModels(apiKey);
    if (fetchedModels.isEmpty) return;

    final names = fetchedModels
        .map((m) => m['name']?.toString() ?? '')
        .where((name) => name.trim().isNotEmpty)
        .toList();
    if (names.isEmpty) return;

    final current = _selectedModel;
    var next = current;
    if (!names.contains(current)) {
      next = names.first;
    }

    if (!mounted) return;
    setState(() {
      _selectableModels = fetchedModels;
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
    final apiKeyController = TextEditingController(text: _geminiApiKey ?? '');
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
                  TextField(
                    controller: apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(),
                      hintText: 'APIキーを入力してください',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  if (isFetchingModels)
                    const LinearProgressIndicator()
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (apiKeyController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('APIキーを入力してください'),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isFetchingModels = true);
                          final models =
                              await fetchGeminiModels(apiKeyController.text);
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
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '現在のモデル: ',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            Expanded(
                              child: Text(
                                tempSelectedModel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          '利用可能なモデル一覧 (サポートメソッド):',
                          style: TextStyle(color: Colors.grey.shade600),
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
                            color: Colors.grey.shade800,
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
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'gemini_model_emergency_meeting',
                    tempSelectedModel,
                  );
                  if (apiKeyController.text.isNotEmpty) {
                    await prefs.setString(
                      'gemini_api_key',
                      apiKeyController.text,
                    );
                  }
                  if (mounted) {
                    setState(() {
                      _selectedModel = tempSelectedModel;
                      if (apiKeyController.text.isNotEmpty) {
                        _geminiApiKey = apiKeyController.text;
                      }
                      _selectableModels = currentSelectableModels;
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
        return Colors.blueGrey;
      case MeetingFocus.continuation:
        return Colors.blue;
      case MeetingFocus.abstinence:
        return Colors.redAccent;
    }
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
    final extractedConclusion =
        _extractQuotedFieldValue(normalized, 'conclusion');
    final extractedMessage = _extractQuotedFieldValue(normalized, 'content');

    final fallbackSeed = extractedConclusion ??
        extractedMessage ??
        normalized.replaceAll(RegExp(r'[\{\}\[\]"]'), ' ');
    final fallbackConclusion = _truncateText(
      fallbackSeed.isEmpty ? '継続と禁欲の両立を最優先し、48時間の再建プランを実行する。' : fallbackSeed,
      maxChars: 140,
    );

    return <String, dynamic>{
      'messages': <Map<String, String>>[
        <String, String>{
          'role': 'CSO',
          'speaker_name': 'AI CSO',
          'content': extractedMessage != null && extractedMessage.isNotEmpty
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
      'risk_alert': 'AI応答のJSONが崩れていたため、内容を簡易復元しました。',
      'conclusion': fallbackConclusion,
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
      focusLabel: _focusLabel(_selectedFocus),
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
    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini APIキーを設定してください。')),
      );
      await showSettingsDialog();
      if (_geminiApiKey == null || _geminiApiKey!.isEmpty) return;
    }

    await _ensureSelectedModelIsAvailable();

    setState(() {
      _isLoading = true;
      _loadingStatus = '継続と禁欲に関するデータを収集中...';
      _errorMessage = null;
      _continuationPlan = <String>[];
      _abstinenceRules = <String>[];
      _continuationChecks = <bool>[];
      _abstinenceChecks = <bool>[];
      _riskAlert = null;
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

      final contextPrompt = _customPromptInstructions
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
            '{deterrenceLockEnabledCount}',
            currentMetrics.deterrenceLockEnabledCount.toString(),
          )
          .replaceFirst('{activeDeterrenceLocks}', activeLocksText)
          .replaceFirst('{focusTheme}', _focusLabel(_selectedFocus))
          .replaceFirst(
            '{focusInstruction}',
            _focusInstruction(_selectedFocus),
          );

      setState(() => _loadingStatus = 'AI役員が継続・禁欲の改善策を議論中...');

      final aiService = AIService(null, _geminiApiKey);
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

        final apiKey = _geminiApiKey?.trim();
        final latestModels = (apiKey == null || apiKey.isEmpty)
            ? const <Map<String, dynamic>>[]
            : await fetchGeminiModels(apiKey);
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
        topic: '緊急役員会議（${_focusLabel(_selectedFocus)}）',
        conclusion: conclusion,
        messages: messages,
        createdAt: DateTime.now(),
      );

      setState(() {
        _currentLog = log;
        _continuationPlan = continuationPlan;
        _abstinenceRules = abstinenceRules;
        _continuationChecks = List<bool>.filled(continuationPlan.length, false);
        _abstinenceChecks = List<bool>.filled(abstinenceRules.length, false);
        _riskAlert =
            (normalizedRiskAlert == null || normalizedRiskAlert.isEmpty)
                ? null
                : normalizedRiskAlert;
        if (nextMetrics != null) {
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
          _continuationQuickStartCount = _toInt(
            nextMetrics['continuation_quick_start_count'],
            fallback: _continuationQuickStartCount,
          );
          _dailyReminderEnabled = _toBool(
            nextMetrics['reminder_enabled'],
            fallback: _dailyReminderEnabled,
          );

          final parsedLocks = _extractStringList(
            nextMetrics['active_deterrence_locks'],
          );
          if (nextMetrics.containsKey('active_deterrence_locks')) {
            _lockImpulsePurchase = parsedLocks.contains('SNS制限ロック') ||
                parsedLocks.contains('衝動買いロック');
            _lockNewProjects = parsedLocks.contains('90分タイムボックス') ||
                parsedLocks.contains('新規PJ着手ロック');
            _lockSubscriptionAdditions = parsedLocks.contains('週次共有リマインド') ||
                parsedLocks.contains('サブスク追加ロック');
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

          final parsedReviewAt = _toDateTime(nextMetrics['last_review_at']);
          _lastReviewAt = parsedReviewAt ?? _lastReviewAt;
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
          _errorMessage = 'APIキーが無効です。設定を確認してください。';
        } else {
          _errorMessage = '会議エラー: $errString';
        }
        setState(() {}); // Update UI to show error
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: const Text('緊急役員会議 (継続・禁欲)'),
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
      backgroundColor: Colors.grey[100],
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
                        color: Colors.red,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '継続と禁欲を立て直す緊急会議を開始しますか？',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI役員が継続率と誘惑リスクを分析し、48時間で実行できる再建プランを提示します。',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '会議フォーカス: ${_focusLabel(_selectedFocus)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
                            label: Text(_focusShortLabel(focus)),
                            selected: isSelected,
                            selectedColor: chipColor.withValues(alpha: 0.18),
                            side: BorderSide(
                              color:
                                  isSelected ? chipColor : Colors.grey.shade400,
                            ),
                            labelStyle: TextStyle(
                              color:
                                  isSelected ? chipColor : Colors.grey.shade800,
                              fontWeight: FontWeight.w700,
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
                          _focusInstruction(_selectedFocus),
                          style: TextStyle(
                            color: Colors.grey.shade700,
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
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '使用モデル: ',
                              style: TextStyle(color: Colors.black54),
                            ),
                            Flexible(
                              child: Text(
                                _selectedModel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      // --- Convene Button ---
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _conveneBoard,
                          icon: const Icon(Icons.notifications_active),
                          label: const Text(
                            '継続・禁欲プランを作成',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 4,
                            disabledBackgroundColor: Colors.grey,
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
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      _loadingStatus,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '継続と禁欲の打ち手を組み立てています...',
                      style: TextStyle(color: Colors.grey),
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
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isCso ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCso
            ? const BorderSide(color: Colors.orange, width: 2)
            : BorderSide.none,
      ),
      color: isCeo ? Colors.blue[50] : Colors.white,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.speakerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      msg.role,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              msg.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
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
        color: Colors.black87,
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
          if (_riskAlert != null) ...[
            _buildAlertChip(_riskAlert!),
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

  Widget _buildContinuationExecutionPanel() {
    final completed = _continuationChecks.where((isDone) => isDone).length;
    final total = _continuationChecks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final nextIndex = _nextPendingContinuationIndex();
    final hasPending = nextIndex >= 0 && nextIndex < _continuationPlan.length;
    final nextActionText = hasPending ? _continuationPlan[nextIndex] : '全タスク完了';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: Colors.lightBlueAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '継続アクション（48時間）',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$completed / $total',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(
              Colors.lightBlueAccent,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '30分深掘り実施: $_deepWorkSessionCount回 / 週次優先レビュー: $_weeklyPriorityReviewCount回 / '
            'クイック着手: $_continuationQuickStartCount回',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.lightBlueAccent.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '次の1件（最短導線）',
                  style: TextStyle(
                    color: Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
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
                        child: OutlinedButton.icon(
                          onPressed: _markContinuationQuickStart,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('次の1件に着手'),
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
                          label: const Text('次の1件を完了'),
                        ),
                      ),
                    ],
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
          for (var i = 0; i < _continuationPlan.length; i++)
            CheckboxListTile(
              value: i < _continuationChecks.length && _continuationChecks[i],
              onChanged: (value) => _toggleContinuationCheck(i, value),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.lightBlueAccent,
              checkColor: Colors.black,
              title: Text(
                _continuationPlan[i],
                style: const TextStyle(color: Colors.white, height: 1.35),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.block, color: Colors.pinkAccent, size: 18),
              SizedBox(width: 8),
              Text(
                '禁欲ガード（通知・制限・可視化）',
                style: TextStyle(
                  color: Colors.pinkAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '違反: $_abstinenceViolationCount回 / 連続無違反: $_abstinenceNoViolationDays日',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: deterrenceProgress,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
          ),
          const SizedBox(height: 8),
          Text(
            '禁欲ルール実行率: $abstinenceRatePercent% '
            '($abstinenceCompleted/$abstinenceTotal)',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: abstinenceProgress,
            backgroundColor: Colors.white24,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          ),
          const SizedBox(height: 8),
          Text(
            'ロック有効率: ${(lockCoverage * 100).round()}% ($activeLockCount/3)',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: lockCoverage,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
          ),
          if (activeLockCount < 2) ...[
            const SizedBox(height: 6),
            const Text(
              '抑止力が弱めです。ロックを2つ以上ONにして再発を防止してください。',
              style: TextStyle(color: Colors.orangeAccent),
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
                onSelected: (selected) => _setDeterrenceLock(
                  value: selected,
                  setter: (value) => _lockImpulsePurchase = value,
                ),
                selectedColor: Colors.pinkAccent.withValues(alpha: 0.2),
              ),
              FilterChip(
                label: const Text('90分タイムボックス'),
                selected: _lockNewProjects,
                onSelected: (selected) => _setDeterrenceLock(
                  value: selected,
                  setter: (value) => _lockNewProjects = value,
                ),
                selectedColor: Colors.pinkAccent.withValues(alpha: 0.2),
              ),
              FilterChip(
                label: const Text('週次共有リマインド'),
                selected: _lockSubscriptionAdditions,
                onSelected: (selected) => _setDeterrenceLock(
                  value: selected,
                  setter: (value) => _lockSubscriptionAdditions = value,
                ),
                selectedColor: Colors.pinkAccent.withValues(alpha: 0.2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _dailyReminderEnabled,
            onChanged: _toggleDailyReminder,
            title: const Text(
              '毎日21:00に禁欲チェック通知',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              '通知で衝動行動を先回り抑止',
              style: TextStyle(color: Colors.white70),
            ),
            activeThumbColor: Colors.pinkAccent,
            activeTrackColor: Colors.pinkAccent.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 6),
          Text(
            '進捗共有記録: $_accountabilityShareCount回 / 即時リカバリー: $_abstinenceRecoveryActionCount回',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
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
                  onPressed: _recordAbstinenceCleanDay,
                  icon: const Icon(Icons.verified),
                  label: const Text('本日違反なし'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
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
              activeColor: Colors.pinkAccent,
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
        border: Border.all(color: Colors.amber.withValues(alpha: 0.85)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.query_stats, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text(
                '次回会議の検証指標',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '継続完了率: ${metrics.continuationCompletionRatePercent}% '
            '(${metrics.continuationCompletedCount}/${metrics.continuationTotalCount})',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲違反回数: ${metrics.abstinenceViolationCount} / 連続無違反日数: ${metrics.abstinenceNoViolationDays}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲ルール実行率: ${metrics.abstinenceRuleCompletionRatePercent}% '
            '(${metrics.abstinenceRuleCompletedCount}/${metrics.abstinenceRuleTotalCount})',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '深掘り実施回数: ${metrics.deepWorkSessionCount} / 優先レビュー回数: ${metrics.weeklyPriorityReviewCount}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'クイック着手回数: ${metrics.continuationQuickStartCount}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '進捗共有回数: ${metrics.accountabilityShareCount}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '即時リカバリー回数: ${metrics.abstinenceRecoveryActionCount}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '禁欲チェック通知: ${metrics.reminderEnabled ? '有効' : '無効'}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '有効ロック: ${metrics.deterrenceLockEnabledCount}件'
            ' (${metrics.activeDeterrenceLocks.isEmpty ? 'なし' : metrics.activeDeterrenceLocks.join(', ')})',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '最終指標保存: ${metrics.lastReviewAt?.toIso8601String() ?? '未保存'}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertChip(String alertText) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.orangeAccent,
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

  Color _getRoleColor(String role) {
    switch (role) {
      case 'CEO':
        return Colors.blue;
      case 'CSO':
        return Colors.orange[800]!;
      case 'CFO':
        return Colors.green[700]!;
      case 'CKO':
        return Colors.purple;
      case 'CMO':
        return Colors.pink;
      case 'CHO':
        return Colors.teal;
      case 'CHRO':
        return Colors.indigo;
      default:
        return Colors.grey;
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
