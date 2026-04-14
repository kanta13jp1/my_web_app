import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskPriority {
  a,
  b,
  c,
}

class _PhoneDetoxAction {
  final String label;
  final TaskPriority priority;

  const _PhoneDetoxAction({
    required this.label,
    required this.priority,
  });
}

class _CriticalTaskTemplate {
  final String label;
  final TaskPriority priority;

  const _CriticalTaskTemplate({
    required this.label,
    required this.priority,
  });
}

class _CriticalTaskGuide {
  final String label;
  final String purpose;
  final List<String> steps;
  final String doneCriteria;

  const _CriticalTaskGuide({
    required this.label,
    required this.purpose,
    required this.steps,
    required this.doneCriteria,
  });
}

class _TodoFlowNodeData {
  final String id;
  final String title;
  final String? subtitle;
  final Color color;
  final IconData icon;
  final bool isDimmed;
  final Offset position;
  final String? note;

  const _TodoFlowNodeData({
    required this.id,
    required this.title,
    this.subtitle,
    required this.color,
    required this.icon,
    this.isDimmed = false,
    required this.position,
    this.note,
  });
}

const double _todoFlowNodeWidth = 268.0;
const double _todoFlowNodeAnchorY = 44.0;
const double _todoFlowNoteOffsetX = _todoFlowNodeWidth + 18.0;

class _TodoFlowPainter extends CustomPainter {
  final List<_TodoFlowNodeData> nodes;
  final Set<String> links;

  const _TodoFlowPainter({
    required this.nodes,
    required this.links,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodeLookup = <String, _TodoFlowNodeData>{
      for (final node in nodes) node.id: node,
    };
    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.45)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (final link in links) {
      final parts = link.split('=>');
      if (parts.length != 2) continue;
      final from = nodeLookup[parts[0]];
      final to = nodeLookup[parts[1]];
      if (from == null || to == null) continue;

      final start = Offset(
        from.position.dx + _todoFlowNodeWidth,
        from.position.dy + _todoFlowNodeAnchorY,
      );
      final end = Offset(to.position.dx, to.position.dy + _todoFlowNodeAnchorY);
      final controlDx = math.max(48, (end.dx - start.dx).abs() * 0.35);
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + controlDx,
          start.dy,
          end.dx - controlDx,
          end.dy,
          end.dx,
          end.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TodoFlowPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.links != links;
  }
}

class _TaskCompletionLog {
  final String taskId;
  final String title;
  final int hourSlot;
  final DateTime completedAt;

  const _TaskCompletionLog({
    required this.taskId,
    required this.title,
    required this.hourSlot,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'task_id': taskId,
      'title': title,
      'hour_slot': hourSlot,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  static _TaskCompletionLog? fromJson(String taskId, dynamic value) {
    if (value is! Map) return null;

    final title = value['title']?.toString();
    final hourSlot = (value['hour_slot'] as num?)?.toInt();
    final completedAtRaw = value['completed_at']?.toString();
    final completedAt =
        completedAtRaw == null ? null : DateTime.tryParse(completedAtRaw);
    if (title == null || hourSlot == null || completedAt == null) {
      return null;
    }

    return _TaskCompletionLog(
      taskId: taskId,
      title: title,
      hourSlot: hourSlot,
      completedAt: completedAt,
    );
  }
}

class MindlessTaskPage extends StatefulWidget {
  final SupabaseClient? supabaseClient;

  const MindlessTaskPage({super.key, this.supabaseClient});

  @override
  State<MindlessTaskPage> createState() => _MindlessTaskPageState();
}

class _MindlessTaskPageState extends State<MindlessTaskPage> {
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;
  DateTime _selectedDate = DateTime.now();

  // データ構造: { 6: [Task1, Task2], 7: [Task3] } のように時間ごとのリスト
  Map<int, List<Map<String, dynamic>>> _tasksByHour = {};
  bool _isLoading = true;
  Timer? _timeboxTimer;
  bool _isTimeboxRunning = false;
  int _selectedMinutes = 50;
  Duration _timeboxTotal = Duration.zero;
  Duration _timeboxRemaining = Duration.zero;
  String _timeboxMode = '動く';
  String _timeboxGoal = '';
  int _completedTimeboxCount = 0;
  int _completedReadingSessions = 0;
  int _completedWalkBreaks = 0;
  int _phoneSlipCount = 0;
  int _currentReadingStreak = 0;
  bool _phoneShieldEnabled = true;
  TaskPriority _defaultTaskPriority = TaskPriority.c;
  bool _showFlowTodoMap = false;
  bool _todoFlowImmersiveMode = false;
  bool _todoFlowLogMode = false;
  Map<String, Offset> _todoFlowPositions = <String, Offset>{};
  Set<String> _todoFlowLinks = <String>{};
  Map<String, String> _todoFlowNotes = <String, String>{};
  String? _loadedTodoFlowDateKey;
  Map<String, _TaskCompletionLog> _dailyCompletionLogs =
      <String, _TaskCompletionLog>{};
  String? _loadedCompletionLogDateKey;
  List<String> _defenseCheckTargets = List<String>.from(
    _defaultDefenseCheckTargets,
  );
  Set<String> _checkedDefenseTargets = <String>{};
  String? _loadedDefenseCheckDateKey;

  static const List<int> _timeboxPresets = [15, 30, 50, 90];
  static const int _dailyTaskTarget = 100;
  static const int _batchTaskCount = 5;
  static const String _defenseCheckTemplateLabel = '朝10分の防衛チェック（不審リンク/請求/認証）';
  static const List<String> _defaultDefenseCheckTargets = [
    'メール: メイン受信箱',
    'SMS',
    'DM',
  ];
  static const List<_PhoneDetoxAction> _phoneDetoxActions = [
    _PhoneDetoxAction(label: '朝に触らない', priority: TaskPriority.a),
    _PhoneDetoxAction(label: '仕事に没頭する', priority: TaskPriority.a),
    _PhoneDetoxAction(label: 'グレースケール', priority: TaskPriority.c),
    _PhoneDetoxAction(label: 'SNSをPCに移行', priority: TaskPriority.b),
    _PhoneDetoxAction(label: 'スマホなしで散歩', priority: TaskPriority.b),
    _PhoneDetoxAction(label: '連絡をまとめて返す', priority: TaskPriority.b),
    _PhoneDetoxAction(label: 'ゲームのデータ削除', priority: TaskPriority.a),
    _PhoneDetoxAction(label: 'タイムロッキングコンテナ', priority: TaskPriority.a),
  ];
  static const List<_CriticalTaskTemplate> _criticalTaskTemplates = [
    _CriticalTaskTemplate(
      label: _defenseCheckTemplateLabel,
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '今日の最重要タスクを1件完了',
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '1円収益アクションを1件実行',
      priority: TaskPriority.a,
    ),
    _CriticalTaskTemplate(
      label: '終了前に資産・アカウント記録を更新',
      priority: TaskPriority.a,
    ),
  ];
  static const List<_CriticalTaskGuide> _criticalTaskGuides = [
    _CriticalTaskGuide(
      label: _defenseCheckTemplateLabel,
      purpose: '詐欺・不正課金・乗っ取りを朝のうちに早期発見する。',
      steps: [
        '受信整理（3分）: メール/SMS/DMを確認し、未読・不要・怪しい通知を整理',
        '請求確認（3分）: カード明細・Apple/Google課金・銀行引落の直近1日分を確認',
        '認証確認（4分）: 主要アカウントのログイン履歴を確認し、不審端末はログアウト',
      ],
      doneCriteria: '登録したチェック対象をすべて確認し、不明請求なし・不審ログインなしなら完了',
    ),
    _CriticalTaskGuide(
      label: '今日の最重要タスクを1件完了',
      purpose: '今日の成果を最低1つ確定させ、先送りを防ぐ。',
      steps: [
        '今日の成果に直結するタスクを1件だけ選ぶ',
        '25分集中を1〜2セット回して、その1件だけを進める',
        '完了したら成果を一行で記録する（何を終えたか）',
      ],
      doneCriteria: '「最重要タスク1件が完了」し、記録が残っていれば完了',
    ),
    _CriticalTaskGuide(
      label: '1円収益アクションを1件実行',
      purpose: '売上ゼロ日を減らし、毎日の収益行動を習慣化する。',
      steps: [
        '販売・提案・見積・既存客フォローのどれか1件を選ぶ',
        '5分以内に送信/出品/提案を実行して、未送信で止めない',
        '送った証跡（送信先・商品名・提案先）を一行で残す',
      ],
      doneCriteria: '収益につながる行動を1件「実行済み」で記録できたら完了',
    ),
    _CriticalTaskGuide(
      label: '終了前に資産・アカウント記録を更新',
      purpose: '日次のズレを翌日に持ち越さず、意思決定を数字に戻す。',
      steps: [
        '総資産・主要口座残高・保有状況を更新する',
        'ログイン履歴や重要通知の異常有無を確認する',
        '未処理があれば翌日の最初の対応タスクとして1件だけ登録する',
      ],
      doneCriteria: '資産・アカウント記録が当日分に更新され、翌日の初手が1件決まれば完了',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _timeboxTimer?.cancel();
    super.dispose();
  }

  // 日付が変わったら再ロード
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
        _loadedDefenseCheckDateKey = null;
        _loadedTodoFlowDateKey = null;
        _loadedCompletionLogDateKey = null;
      });
      _loadTasks();
    }
  }

  Future<void> _loadTasks() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      final data = await _supabase
          .from('mindless_tasks')
          .select()
          .eq('user_id', userId)
          .eq('task_date', dateStr)
          .order('id', ascending: true);

      final Map<int, List<Map<String, dynamic>>> newTasksByHour = {};
      for (var item in data) {
        final hour = item['hour_slot'] as int;
        if (!newTasksByHour.containsKey(hour)) {
          newTasksByHour[hour] = [];
        }
        newTasksByHour[hour]!.add(item);
      }

      if (mounted) {
        setState(() {
          _tasksByHour = newTasksByHour;
          _isLoading = false;
        });
      }
      await _ensureDailyCompletionLogsLoaded(
        validTaskIds: newTasksByHour.values
            .expand((tasks) => tasks)
            .map((task) => task['id']?.toString())
            .whereType<String>()
            .toSet(),
      );
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  String _defenseTargetsPrefsKey(String userId) =>
      'mindless_defense_targets_$userId';

  String _defenseCheckedPrefsKey(String userId, DateTime date) =>
      'mindless_defense_checked_${_formatDateKey(date)}_$userId';

  Future<void> _ensureDefenseChecklistLoaded() async {
    final dateKey = _formatDateKey(_selectedDate);
    if (_loadedDefenseCheckDateKey == dateKey) {
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    var targets = List<String>.from(_defaultDefenseCheckTargets);
    var checkedTargets = <String>{};

    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      final storedTargets =
          prefs.getStringList(_defenseTargetsPrefsKey(userId));
      if (storedTargets != null && storedTargets.isNotEmpty) {
        targets = storedTargets
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      } else {
        await prefs.setStringList(_defenseTargetsPrefsKey(userId), targets);
      }

      if (targets.isEmpty) {
        targets = List<String>.from(_defaultDefenseCheckTargets);
      }

      checkedTargets = (prefs.getStringList(
                _defenseCheckedPrefsKey(userId, _selectedDate),
              ) ??
              const <String>[])
          .where(targets.contains)
          .toSet();
    }

    if (!mounted) return;
    setState(() {
      _defenseCheckTargets = targets;
      _checkedDefenseTargets = checkedTargets;
      _loadedDefenseCheckDateKey = dateKey;
    });
  }

  Future<void> _persistDefenseChecklist() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _defenseTargetsPrefsKey(userId),
      _defenseCheckTargets,
    );
    await prefs.setStringList(
      _defenseCheckedPrefsKey(userId, _selectedDate),
      _checkedDefenseTargets.toList(),
    );
  }

  Future<void> _toggleDefenseTargetChecked(
    String target,
    bool isChecked,
  ) async {
    setState(() {
      if (isChecked) {
        _checkedDefenseTargets.add(target);
      } else {
        _checkedDefenseTargets.remove(target);
      }
    });
    await _persistDefenseChecklist();
  }

  Future<bool> _addDefenseTarget(String rawValue) async {
    final value = rawValue.trim();
    if (value.isEmpty) return false;

    if (_defenseCheckTargets.contains(value)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('同じチェック対象はすでに登録済みです。')),
        );
      }
      return false;
    }

    setState(() {
      _defenseCheckTargets = <String>[
        ..._defenseCheckTargets,
        value,
      ];
    });
    await _persistDefenseChecklist();
    return true;
  }

  Future<void> _removeDefenseTarget(String target) async {
    setState(() {
      _defenseCheckTargets =
          _defenseCheckTargets.where((item) => item != target).toList();
      _checkedDefenseTargets.remove(target);
    });
    await _persistDefenseChecklist();
  }

  Future<bool> _showAddDefenseTargetDialog() async {
    var draftValue = '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('チェック対象を追加'),
        content: TextField(
          autofocus: true,
          onChanged: (value) => draftValue = value,
          decoration: const InputDecoration(
            hintText: '例: メール: 副業用Gmail',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, draftValue),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (result == null) return false;
    return _addDefenseTarget(result);
  }

  String _taskFlowId(Map<String, dynamic> task) {
    final rawId = task['id'];
    if (rawId != null) {
      return 'task_$rawId';
    }
    final hour = (task['hour_slot'] as int?) ?? 0;
    final content = _stripPriorityTag(task['content'] as String? ?? '');
    return 'task_${hour}_$content';
  }

  String _todoFlowPositionsPrefsKey(String userId, DateTime date) =>
      'mindless_todo_flow_positions_${_formatDateKey(date)}_$userId';

  String _todoFlowLinksPrefsKey(String userId, DateTime date) =>
      'mindless_todo_flow_links_${_formatDateKey(date)}_$userId';

  String _todoFlowNotesPrefsKey(String userId, DateTime date) =>
      'mindless_todo_flow_notes_${_formatDateKey(date)}_$userId';

  Set<String> _buildDefaultTodoFlowLinks(List<Map<String, dynamic>> tasks) {
    final links = <String>{};
    for (final priority in TaskPriority.values) {
      final branch = tasks.where((task) {
        return _parsePriority(task['content'] as String? ?? '') == priority;
      }).toList();
      for (var i = 0; i < branch.length - 1; i++) {
        links.add('${_taskFlowId(branch[i])}=>${_taskFlowId(branch[i + 1])}');
      }
    }
    return links;
  }

  Offset _defaultTodoFlowPositionForTask(
    Map<String, dynamic> task,
    int branchIndex,
    int itemIndex,
  ) {
    const columnSpacing = 392.0;
    const rowSpacing = 156.0;
    final baseX = 80 + (branchIndex * columnSpacing);
    final baseY = 80 + (itemIndex * rowSpacing);
    return Offset(baseX, baseY);
  }

  Offset _defaultTodoFlowPositionForLog(int itemIndex) {
    const columnSpacing = 430.0;
    const rowSpacing = 176.0;
    final columnIndex = itemIndex.isEven ? 0 : 1;
    final rowIndex = itemIndex ~/ 2;
    final baseX =
        96 + (columnIndex * columnSpacing) + (rowIndex.isOdd ? 28.0 : 0.0);
    final baseY = 88 + (rowIndex * rowSpacing);
    return Offset(baseX, baseY);
  }

  Future<void> _persistTodoFlowState() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final positionsPayload = <String, Map<String, double>>{
      for (final entry in _todoFlowPositions.entries)
        entry.key: <String, double>{
          'x': entry.value.dx,
          'y': entry.value.dy,
        },
    };

    await prefs.setString(
      _todoFlowPositionsPrefsKey(userId, _selectedDate),
      jsonEncode(positionsPayload),
    );
    await prefs.setStringList(
      _todoFlowLinksPrefsKey(userId, _selectedDate),
      _todoFlowLinks.toList(),
    );
    await prefs.setString(
      _todoFlowNotesPrefsKey(userId, _selectedDate),
      jsonEncode(_todoFlowNotes),
    );
  }

  Future<void> _ensureTodoFlowStateLoaded() async {
    final dateKey = _formatDateKey(_selectedDate);
    if (_loadedTodoFlowDateKey == dateKey) {
      return;
    }

    final tasks = _sortedTasksForFlow;
    final userId = _supabase.auth.currentUser?.id;
    final positions = <String, Offset>{};
    var links = _buildDefaultTodoFlowLinks(tasks);
    final notes = <String, String>{};

    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();

      final positionsRaw = prefs.getString(
        _todoFlowPositionsPrefsKey(userId, _selectedDate),
      );
      if (positionsRaw != null && positionsRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(positionsRaw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final value = entry.value;
              if (value is Map) {
                final x = (value['x'] as num?)?.toDouble();
                final y = (value['y'] as num?)?.toDouble();
                if (x != null && y != null) {
                  positions[entry.key.toString()] = Offset(x, y);
                }
              }
            }
          }
        } catch (_) {}
      }

      final storedLinks = prefs.getStringList(
        _todoFlowLinksPrefsKey(userId, _selectedDate),
      );
      if (storedLinks != null && storedLinks.isNotEmpty) {
        links = storedLinks.toSet();
      }

      final notesRaw = prefs.getString(
        _todoFlowNotesPrefsKey(userId, _selectedDate),
      );
      if (notesRaw != null && notesRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(notesRaw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final value = entry.value?.toString().trim();
              if (value != null && value.isNotEmpty) {
                notes[entry.key.toString()] = value;
              }
            }
          }
        } catch (_) {}
      }
    }

    for (var branchIndex = 0;
        branchIndex < TaskPriority.values.length;
        branchIndex++) {
      final priority = TaskPriority.values[branchIndex];
      final branchTasks = tasks.where((task) {
        return _parsePriority(task['content'] as String? ?? '') == priority;
      }).toList();
      for (var itemIndex = 0; itemIndex < branchTasks.length; itemIndex++) {
        final task = branchTasks[itemIndex];
        final nodeId = _taskFlowId(task);
        positions.putIfAbsent(
          nodeId,
          () => _defaultTodoFlowPositionForTask(task, branchIndex, itemIndex),
        );
      }
    }

    final validIds = tasks.map(_taskFlowId).toSet();
    positions.removeWhere((key, value) => !validIds.contains(key));
    links = links.where((link) {
      final parts = link.split('=>');
      return parts.length == 2 &&
          validIds.contains(parts[0]) &&
          validIds.contains(parts[1]);
    }).toSet();
    notes.removeWhere((key, value) => !validIds.contains(key));

    if (!mounted) return;
    setState(() {
      _todoFlowPositions = positions;
      _todoFlowLinks = links;
      _todoFlowNotes = notes;
      _loadedTodoFlowDateKey = dateKey;
    });
  }

  Future<void> _resetTodoFlowLayout() async {
    final tasks = _sortedTasksForFlow;
    final nextPositions = <String, Offset>{};

    for (var branchIndex = 0;
        branchIndex < TaskPriority.values.length;
        branchIndex++) {
      final priority = TaskPriority.values[branchIndex];
      final branchTasks = tasks.where((task) {
        return _parsePriority(task['content'] as String? ?? '') == priority;
      }).toList();
      for (var itemIndex = 0; itemIndex < branchTasks.length; itemIndex++) {
        final task = branchTasks[itemIndex];
        nextPositions[_taskFlowId(task)] = _defaultTodoFlowPositionForTask(
          task,
          branchIndex,
          itemIndex,
        );
      }
    }

    setState(() {
      _todoFlowPositions = nextPositions;
      _todoFlowLinks = _buildDefaultTodoFlowLinks(tasks);
    });
    await _persistTodoFlowState();
  }

  Future<void> _showTodoFlowNodeEditor(Map<String, dynamic> task) async {
    await _ensureTodoFlowStateLoaded();
    if (!mounted) return;

    final nodeId = _taskFlowId(task);
    final noteController =
        TextEditingController(text: _todoFlowNotes[nodeId] ?? '');
    final availableTargets = _sortedTasksForFlow
        .where((candidate) => _taskFlowId(candidate) != nodeId)
        .toList();
    final selectedTargets = _todoFlowLinks
        .where((link) => link.startsWith('$nodeId=>'))
        .map((link) => link.split('=>').last)
        .toSet();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '「${_stripPriorityTag(task['content'] as String? ?? '')}」の接続編集',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: '枝メモ',
                          hintText: '例: ここは当日中に処理。別紙メモ参照。',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'このノードからつなぐ先',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (availableTargets.isEmpty)
                        const Text('接続先にできる他タスクはありません。')
                      else
                        ...availableTargets.map((candidate) {
                          final candidateId = _taskFlowId(candidate);
                          final candidateTitle = _stripPriorityTag(
                            candidate['content'] as String? ?? '',
                          );
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: selectedTargets.contains(candidateId),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selectedTargets.add(candidateId);
                                } else {
                                  selectedTargets.remove(candidateId);
                                }
                              });
                            },
                            title: Text(candidateTitle),
                          );
                        }),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final nextNote = noteController.text.trim();
                            final nextLinks = _todoFlowLinks
                                .where((link) => !link.startsWith('$nodeId=>'))
                                .toSet();
                            for (final targetId in selectedTargets) {
                              nextLinks.add('$nodeId=>$targetId');
                            }

                            if (!mounted) return;
                            setState(() {
                              _todoFlowLinks = nextLinks;
                              if (nextNote.isEmpty) {
                                _todoFlowNotes.remove(nodeId);
                              } else {
                                _todoFlowNotes[nodeId] = nextNote;
                              }
                            });
                            await _persistTodoFlowState();
                            if (context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  String _completionLogPrefsKey(String userId, DateTime date) =>
      'mindless_completion_logs_${_formatDateKey(date)}_$userId';

  Future<void> _persistDailyCompletionLogs() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final payload = <String, Map<String, dynamic>>{
      for (final entry in _dailyCompletionLogs.entries)
        entry.key: entry.value.toJson(),
    };
    await prefs.setString(
      _completionLogPrefsKey(userId, _selectedDate),
      jsonEncode(payload),
    );
  }

  Future<void> _ensureDailyCompletionLogsLoaded({
    Set<String>? validTaskIds,
  }) async {
    final dateKey = _formatDateKey(_selectedDate);
    final shouldReload = _loadedCompletionLogDateKey != dateKey;
    if (!shouldReload && validTaskIds == null) {
      return;
    }

    final userId = _supabase.auth.currentUser?.id;
    var logs = shouldReload
        ? <String, _TaskCompletionLog>{}
        : Map<String, _TaskCompletionLog>.from(_dailyCompletionLogs);

    if (userId != null && shouldReload) {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_completionLogPrefsKey(userId, _selectedDate));
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final parsed = <String, _TaskCompletionLog>{};
            for (final entry in decoded.entries) {
              final parsedLog = _TaskCompletionLog.fromJson(
                entry.key.toString(),
                entry.value,
              );
              if (parsedLog != null) {
                parsed[entry.key.toString()] = parsedLog;
              }
            }
            logs = parsed;
          }
        } catch (_) {}
      }
    }

    var didPrune = false;
    if (validTaskIds != null) {
      final beforeCount = logs.length;
      logs.removeWhere((key, value) => !validTaskIds.contains(key));
      didPrune = beforeCount != logs.length;
    }

    if (!mounted) return;
    setState(() {
      _dailyCompletionLogs = logs;
      _loadedCompletionLogDateKey = dateKey;
    });

    if (didPrune) {
      await _persistDailyCompletionLogs();
    }
  }

  List<_TaskCompletionLog> get _dailyCompletionTimeline {
    final timeline = _dailyCompletionLogs.values.toList()
      ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
    return timeline;
  }

  Future<void> _recordCompletionForTask(
    int taskId, {
    required String title,
    required int hourSlot,
  }) async {
    await _ensureDailyCompletionLogsLoaded();
    if (!mounted) return;

    setState(() {
      _dailyCompletionLogs['$taskId'] = _TaskCompletionLog(
        taskId: '$taskId',
        title: title,
        hourSlot: hourSlot,
        completedAt: DateTime.now(),
      );
    });
    await _persistDailyCompletionLogs();
  }

  Future<void> _removeCompletionForTask(int taskId) async {
    await _ensureDailyCompletionLogsLoaded();
    if (!mounted) return;

    if (!_dailyCompletionLogs.containsKey('$taskId')) {
      return;
    }
    setState(() {
      _dailyCompletionLogs.remove('$taskId');
    });
    await _persistDailyCompletionLogs();
  }

  Future<void> _showDailyCompletionOverviewSheet() async {
    await _ensureDailyCompletionLogsLoaded(
      validTaskIds: _allTasks
          .map((task) => task['id']?.toString())
          .whereType<String>()
          .toSet(),
    );
    if (!mounted) return;

    final completedLogs = _dailyCompletionTimeline;
    final pendingTasks =
        _allTasks.where((task) => task['is_completed'] != true).toList()
          ..sort(
            (a, b) => ((a['hour_slot'] as int?) ?? 0).compareTo(
              (b['hour_slot'] as int?) ?? 0,
            ),
          );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '一日の実行ログ俯瞰',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '完了 ${completedLogs.length} 件 / 未完 ${pendingTasks.length} 件',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '完了したタスク',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (completedLogs.isEmpty)
                    const Text('まだ完了記録はありません。')
                  else
                    ...completedLogs.map((log) {
                      final timeText =
                          DateFormat('HH:mm').format(log.completedAt);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(log.title),
                        subtitle: Text('$timeText 完了 / ${log.hourSlot}:00枠'),
                      );
                    }),
                  const SizedBox(height: 12),
                  const Text(
                    'まだ残っているタスク',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (pendingTasks.isEmpty)
                    const Text('未完了タスクはありません。')
                  else
                    ...pendingTasks.take(10).map((task) {
                      final title =
                          _stripPriorityTag(task['content'] as String? ?? '');
                      final hour = (task['hour_slot'] as int?) ?? 0;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.radio_button_unchecked),
                        title: Text(title),
                        subtitle: Text('$hour:00枠'),
                      );
                    }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> get _allTasks {
    return _tasksByHour.values.expand((tasks) => tasks).toList();
  }

  int get _completedTasksToday {
    return _allTasks.where((task) => task['is_completed'] == true).length;
  }

  List<Map<String, dynamic>> get _sortedTasksForFlow {
    final tasks = List<Map<String, dynamic>>.from(_allTasks);
    tasks.sort((a, b) {
      final aDone = a['is_completed'] == true;
      final bDone = b['is_completed'] == true;
      if (aDone != bDone) {
        return aDone ? 1 : -1;
      }

      final priorityCompare = _priorityOrder(
        _parsePriority(a['content'] as String? ?? ''),
      ).compareTo(
        _priorityOrder(
          _parsePriority(b['content'] as String? ?? ''),
        ),
      );
      if (priorityCompare != 0) {
        return priorityCompare;
      }

      final hourA = (a['hour_slot'] as int?) ?? 0;
      final hourB = (b['hour_slot'] as int?) ?? 0;
      return hourA.compareTo(hourB);
    });
    return tasks;
  }

  int get _remainingTasksToTarget {
    final remaining = _dailyTaskTarget - _completedTasksToday;
    return remaining > 0 ? remaining : 0;
  }

  double get _dailyTargetProgress {
    return (_completedTasksToday / _dailyTaskTarget).clamp(0, 1);
  }

  int _priorityOrder(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return 0;
      case TaskPriority.b:
        return 1;
      case TaskPriority.c:
        return 2;
    }
  }

  int _priorityTotal(TaskPriority priority) {
    return _allTasks
        .where(
          (task) =>
              _parsePriority(task['content'] as String? ?? '') == priority,
        )
        .length;
  }

  int _priorityCompleted(TaskPriority priority) {
    return _allTasks
        .where(
          (task) =>
              _parsePriority(task['content'] as String? ?? '') == priority &&
              task['is_completed'] == true,
        )
        .length;
  }

  bool get _aPriorityMinimumDone => _priorityCompleted(TaskPriority.a) >= 3;

  TaskPriority _parsePriority(String content) {
    if (content.startsWith('[A]')) return TaskPriority.a;
    if (content.startsWith('[B]')) return TaskPriority.b;
    return TaskPriority.c;
  }

  String _priorityTag(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return '[A]';
      case TaskPriority.b:
        return '[B]';
      case TaskPriority.c:
        return '[C]';
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return 'A';
      case TaskPriority.b:
        return 'B';
      case TaskPriority.c:
        return 'C';
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.a:
        return Colors.redAccent;
      case TaskPriority.b:
        return Colors.orange;
      case TaskPriority.c:
        return Colors.blueGrey;
    }
  }

  String _stripPriorityTag(String content) {
    return content.replaceFirst(RegExp(r'^\[(A|B|C)\]\s*'), '').trim();
  }

  String _detoxTaskTitle(_PhoneDetoxAction action) {
    return 'スマホ禁欲: ${action.label}';
  }

  bool _isDetoxTask(Map<String, dynamic> task, _PhoneDetoxAction action) {
    final content = _stripPriorityTag(task['content'] as String? ?? '');
    return content == _detoxTaskTitle(action);
  }

  int get _detoxScheduledCount {
    return _phoneDetoxActions.where((action) {
      return _allTasks.any((task) => _isDetoxTask(task, action));
    }).length;
  }

  int get _detoxCompletedCount {
    return _phoneDetoxActions.where((action) {
      return _allTasks.any(
        (task) => _isDetoxTask(task, action) && task['is_completed'] == true,
      );
    }).length;
  }

  String _criticalTaskTitle(_CriticalTaskTemplate template) {
    return '必須: ${template.label}';
  }

  String _normalizeCriticalTitle(String content) {
    return content
        .replaceFirst(RegExp(r'^\[(A|B|C)\]\s*'), '')
        .replaceFirst(RegExp(r'^必須:\s*'), '')
        .trim();
  }

  _CriticalTaskGuide? _criticalGuideForTitle(String content) {
    final normalized = _normalizeCriticalTitle(content);
    for (final guide in _criticalTaskGuides) {
      if (normalized.startsWith(guide.label)) {
        return guide;
      }
    }
    return null;
  }

  List<_CriticalTaskGuide> get _pendingCriticalGuides {
    final seen = <String>{};
    final guides = <_CriticalTaskGuide>[];
    for (final title in _pendingCriticalTitles) {
      final guide = _criticalGuideForTitle(title);
      if (guide == null) continue;
      if (seen.add(guide.label)) {
        guides.add(guide);
      }
    }
    return guides;
  }

  bool _isCriticalTaskRow(Map<String, dynamic> task) {
    final content = _stripPriorityTag(task['content'] as String? ?? '');
    return content.startsWith('必須: ');
  }

  int get _criticalTotalCount {
    return _allTasks.where(_isCriticalTaskRow).length;
  }

  int get _criticalCompletedCount {
    return _allTasks
        .where(
          (task) => _isCriticalTaskRow(task) && task['is_completed'] == true,
        )
        .length;
  }

  int get _criticalRemainingCount {
    final remaining = _criticalTotalCount - _criticalCompletedCount;
    return remaining > 0 ? remaining : 0;
  }

  bool get _isCriticalLockActive {
    return _criticalTotalCount > 0 && _criticalRemainingCount > 0;
  }

  List<String> get _pendingCriticalTitles {
    return _allTasks
        .where(
          (task) => _isCriticalTaskRow(task) && task['is_completed'] != true,
        )
        .map((task) => _stripPriorityTag(task['content'] as String? ?? ''))
        .toList();
  }

  Future<void> _showCriticalTaskGuide(_CriticalTaskGuide guide) async {
    if (guide.label == _defenseCheckTemplateLabel) {
      await _ensureDefenseChecklistLoaded();
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${guide.label} のやり方',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '目的: ${guide.purpose}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(guide.steps.length, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == guide.steps.length - 1 ? 0 : 8,
                          ),
                          child: Text('${index + 1}. ${guide.steps[index]}'),
                        );
                      }),
                      if (guide.label == _defenseCheckTemplateLabel) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blueGrey.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'チェック対象TODO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${_checkedDefenseTargets.length}/${_defenseCheckTargets.length} 完了',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '普段見るメールアカウント、SMS、DMを登録して、朝の確認漏れを防ぐ。',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              if (_defenseCheckTargets.isEmpty)
                                const Text(
                                  'まだチェック対象がありません。先に1件追加してください。',
                                )
                              else
                                ..._defenseCheckTargets.map((target) {
                                  final isChecked =
                                      _checkedDefenseTargets.contains(target);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.blueGrey.withValues(
                                          alpha: 0.14,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isChecked,
                                          onChanged: (value) async {
                                            await _toggleDefenseTargetChecked(
                                              target,
                                              value ?? false,
                                            );
                                            setModalState(() {});
                                          },
                                        ),
                                        Expanded(
                                          child: Text(
                                            target,
                                            style: TextStyle(
                                              decoration: isChecked
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isChecked
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: '削除',
                                          onPressed: () async {
                                            await _removeDefenseTarget(target);
                                            setModalState(() {});
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final added =
                                      await _showAddDefenseTargetDialog();
                                  if (!added) return;
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('チェック対象を追加'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        '完了条件: ${guide.doneCriteria}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatRemaining(Duration duration) {
    final mm = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  double _timeboxProgress() {
    if (_timeboxTotal.inSeconds <= 0) return 0;
    final value =
        1 - (_timeboxRemaining.inSeconds / _timeboxTotal.inSeconds.toDouble());
    return value.clamp(0, 1);
  }

  void _showCompleteCriticalTasksSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('先に必須タスクを完了してください。')),
    );
  }

  bool _canStartOptionalFlow() {
    if (_isCriticalLockActive) {
      _showCompleteCriticalTasksSnackBar();
      return false;
    }
    return true;
  }

  Future<int> _addMissingPhoneDetoxTasks({
    required String userId,
    required int hourSlot,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dynamic existingRowsRaw = await _supabase
        .from('mindless_tasks')
        .select('content')
        .eq('user_id', userId)
        .eq('task_date', dateStr);
    final existingRows =
        existingRowsRaw is List ? existingRowsRaw : const <dynamic>[];

    final existingDetoxTitles = existingRows
        .whereType<Map<String, dynamic>>()
        .map((row) => _stripPriorityTag(row['content'] as String? ?? ''))
        .where((content) => content.startsWith('スマホ禁欲: '))
        .toSet();

    final actionsToInsert = _phoneDetoxActions.where((action) {
      return !existingDetoxTitles.contains(_detoxTaskTitle(action));
    }).toList();

    if (actionsToInsert.isEmpty) {
      return 0;
    }

    final inserts = actionsToInsert.map((action) {
      return <String, dynamic>{
        'user_id': userId,
        'task_date': dateStr,
        'hour_slot': hourSlot,
        'content':
            '${_priorityTag(action.priority)} ${_detoxTaskTitle(action)}',
        'is_completed': false,
      };
    }).toList();

    await _supabase.from('mindless_tasks').insert(inserts);
    return actionsToInsert.length;
  }

  void _startCriticalFocusSprint() {
    if (_isTimeboxRunning) return;
    _startTimebox(
      mode: '必須遂行',
      goal: '今日の必須タスクを進める',
      minutes: 25,
    );
  }

  Future<void> _syncCriticalTasks() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dynamic rowsRaw = await _supabase
          .from('mindless_tasks')
          .select('content')
          .eq('user_id', userId)
          .eq('task_date', dateStr);
      final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];

      final existingTitles = rows
          .whereType<Map<String, dynamic>>()
          .map((row) => _stripPriorityTag(row['content'] as String? ?? ''))
          .toSet();

      final templatesToInsert = _criticalTaskTemplates.where((template) {
        return !existingTitles.contains(_criticalTaskTitle(template));
      }).toList();

      if (templatesToInsert.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('必須タスクは展開済みです。')));
        return;
      }

      final nowHour = DateTime.now().hour;
      final inserts = templatesToInsert.map((template) {
        return <String, dynamic>{
          'user_id': userId,
          'task_date': dateStr,
          'hour_slot': nowHour,
          'content':
              '${_priorityTag(template.priority)} ${_criticalTaskTitle(template)}',
          'is_completed': false,
        };
      }).toList();

      await _supabase.from('mindless_tasks').insert(inserts);
      await _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('必須タスクを${templatesToInsert.length}件追加しました。'),
        ),
      );
    } catch (e) {
      debugPrint('Critical task sync failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('必須タスクの追加に失敗しました。')));
    }
  }

  Future<void> _startTimeboxFlow(String mode) async {
    if (!_canStartOptionalFlow()) return;

    final controller = TextEditingController();
    final goal = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$modeモードを開始'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'この時間でやることを1行で書く',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('開始'),
          ),
        ],
      ),
    );

    if (goal == null || goal.isEmpty) return;
    _startTimebox(mode: mode, goal: goal, minutes: _selectedMinutes);
  }

  void _startTimebox({
    required String mode,
    required String goal,
    required int minutes,
  }) {
    _timeboxTimer?.cancel();
    final total = Duration(minutes: minutes);
    setState(() {
      _isTimeboxRunning = true;
      _timeboxMode = mode;
      _timeboxGoal = goal;
      _timeboxTotal = total;
      _timeboxRemaining = total;
    });

    _timeboxTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timeboxRemaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _isTimeboxRunning = false;
          _timeboxRemaining = Duration.zero;
          _completedTimeboxCount += 1;
          if (_timeboxMode == '読書') {
            _completedReadingSessions += 1;
            _currentReadingStreak += 1;
          } else if (_timeboxMode == '散歩') {
            _completedWalkBreaks += 1;
            _currentReadingStreak = 0;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '時間終了: $_timeboxMode「$_timeboxGoal」',
            ),
          ),
        );
        return;
      }
      setState(() {
        _timeboxRemaining = Duration(seconds: _timeboxRemaining.inSeconds - 1);
      });
    });
  }

  void _startReadingAlbum() {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '読書',
      goal: '読書に没頭（スマホを見ない）',
      minutes: 60,
    );
  }

  void _startWalkBreak(int minutes) {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '散歩',
      goal: '喫茶店を出て歩く',
      minutes: minutes,
    );
  }

  void _logPhoneSlip() {
    if (!_isTimeboxRunning || _timeboxMode != '読書' || !_phoneShieldEnabled) {
      return;
    }
    setState(() {
      _phoneSlipCount += 1;
    });
  }

  void _startFiveTaskSprint() {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    _startTimebox(
      mode: '5件バッチ',
      goal: '15分で5件を終わらせる',
      minutes: 15,
    );
  }

  Future<void> _startPhoneLockFocus() async {
    if (_isTimeboxRunning || !_canStartOptionalFlow()) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final insertedCount = await _addMissingPhoneDetoxTasks(
        userId: userId,
        hourSlot: DateTime.now().hour,
      );

      if (mounted) {
        setState(() {
          _phoneShieldEnabled = true;
        });
      }
      await _loadTasks();
      if (!mounted) return;

      if (insertedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('スマホ禁欲項目を$insertedCount件自動追加しました。'),
          ),
        );
      }

      _startTimebox(
        mode: '物理ロック',
        goal: 'スマホを封印して他のことに没頭する',
        minutes: 90,
      );
    } catch (e) {
      debugPrint('Phone lock start failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('物理ロック開始に失敗しました（通信/認証）')));
    }
  }

  Future<void> _showPhoneDetoxTemplateDialog() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    int selectedHour = DateTime.now().hour;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('スマホ禁欲8項目を追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('今日のタスクとして8項目を一括追加します。'),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedHour,
                  decoration: const InputDecoration(
                    labelText: '配置する時間帯',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(24, (hour) {
                    return DropdownMenuItem<int>(
                      value: hour,
                      child: Text('$hour:00'),
                    );
                  }),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedHour = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    final insertedCount = await _addMissingPhoneDetoxTasks(
                      userId: userId,
                      hourSlot: selectedHour,
                    );

                    if (insertedCount == 0) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('すでに追加済みです。')),
                      );
                      return;
                    }
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    await _loadTasks();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'スマホ禁欲項目を$insertedCount件追加しました。',
                        ),
                      ),
                    );
                  } catch (e) {
                    debugPrint('PhoneDetox insert failed: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('追加に失敗しました（通信/認証）')),
                    );
                  }
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showBatchAddDialog() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final controller = TextEditingController();
    TaskPriority selectedPriority = _defaultTaskPriority;
    int selectedHour = DateTime.now().hour;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('5件バッチを追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'タスクの共通名',
                      hintText: '例: 見積もりメール返信',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('優先度'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TaskPriority.values.map((priority) {
                      final selected = selectedPriority == priority;
                      final color = _priorityColor(priority);
                      return ChoiceChip(
                        label: Text(_priorityLabel(priority)),
                        selected: selected,
                        selectedColor: color.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: selected
                              ? color
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        onSelected: (_) {
                          setDialogState(() => selectedPriority = priority);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedHour,
                    decoration: const InputDecoration(
                      labelText: '配置する時間帯',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(24, (hour) {
                      return DropdownMenuItem<int>(
                        value: hour,
                        child: Text('$hour:00'),
                      );
                    }),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedHour = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () async {
                  final raw = controller.text.trim();
                  if (raw.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('タスク名を入力してください。')),
                    );
                    return;
                  }

                  final base = _stripPriorityTag(raw);
                  final dateStr =
                      DateFormat('yyyy-MM-dd').format(_selectedDate);
                  final tag = _priorityTag(selectedPriority);
                  final inserts = List.generate(_batchTaskCount, (index) {
                    return <String, dynamic>{
                      'user_id': userId,
                      'task_date': dateStr,
                      'hour_slot': selectedHour,
                      'content': '$tag $base ${index + 1}/$_batchTaskCount',
                      'is_completed': false,
                    };
                  });

                  await _supabase.from('mindless_tasks').insert(inserts);
                  if (!mounted) return;
                  setState(() => _defaultTaskPriority = selectedPriority);
                  Navigator.of(context).pop();
                  await _loadTasks();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$_batchTaskCount件のバッチを追加しました（${_priorityLabel(selectedPriority)}）。',
                      ),
                    ),
                  );
                },
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _extendTimebox(int minutes) {
    if (!_isTimeboxRunning) return;
    setState(() {
      final extend = Duration(minutes: minutes);
      _timeboxTotal += extend;
      _timeboxRemaining += extend;
    });
  }

  void _stopTimebox() {
    _timeboxTimer?.cancel();
    setState(() {
      _isTimeboxRunning = false;
      _timeboxRemaining = Duration.zero;
    });
  }

  Future<void> _addTask(int hour) async {
    if (_isCriticalLockActive) {
      _showCompleteCriticalTasksSnackBar();
      return;
    }

    final controller = TextEditingController();
    TaskPriority selectedPriority = _defaultTaskPriority;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('$hour時のタスクを追加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '例: お湯を沸かす'),
                  ),
                  const SizedBox(height: 12),
                  const Text('優先度'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TaskPriority.values.map((priority) {
                      final selected = selectedPriority == priority;
                      final color = _priorityColor(priority);
                      return ChoiceChip(
                        label: Text(_priorityLabel(priority)),
                        selected: selected,
                        selectedColor: color.withValues(alpha: 0.18),
                        side: BorderSide(
                          color: selected
                              ? color
                              : Theme.of(context).colorScheme.outlineVariant,
                        ),
                        onSelected: (_) {
                          setDialogState(() => selectedPriority = priority);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('追加'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final cleanedContent = _stripPriorityTag(result);
      final taggedContent = '${_priorityTag(selectedPriority)} $cleanedContent';

      await _supabase.from('mindless_tasks').insert({
        'user_id': userId,
        'task_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'hour_slot': hour,
        'content': taggedContent,
        'is_completed': false,
      });
      setState(() => _defaultTaskPriority = selectedPriority);
      _loadTasks();
    }
  }

  Widget _buildHundredTaskPanel() {
    final done = _completedTasksToday;
    final ratioText = '$done / $_dailyTaskTarget 完了';
    final remainingText = _remainingTasksToTarget == 0
        ? '今日の100件達成'
        : '残り $_remainingTasksToTarget 件';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.lightBlue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '100タスク量産モード',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                ratioText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: _dailyTargetProgress),
          const SizedBox(height: 6),
          Text(
            remainingText,
            style: TextStyle(
              color: _remainingTasksToTarget == 0
                  ? Colors.green
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPriorityProgressChip(TaskPriority.a),
              _buildPriorityProgressChip(TaskPriority.b),
              _buildPriorityProgressChip(TaskPriority.c),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showBatchAddDialog,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('5件バッチ追加'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTimeboxRunning ? null : _startFiveTaskSprint,
                  icon: const Icon(Icons.timer),
                  label: const Text('15分で5件'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _aPriorityMinimumDone ? 'Aタスク3件以上を達成済み' : 'Aタスクは最低3件を先に完了',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _aPriorityMinimumDone ? Colors.green : Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalLockPanel() {
    final total = _criticalTotalCount;
    final done = _criticalCompletedCount;
    final statusText = total == 0
        ? 'まず「必須タスクを展開」を押して開始'
        : _isCriticalLockActive
            ? 'ロック中: 残り$_criticalRemainingCount件'
            : 'ロック解除: 必須タスク完了';
    final progress =
        total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isCriticalLockActive
              ? Colors.red.shade300
              : Colors.green.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isCriticalLockActive ? Icons.lock : Icons.lock_open,
                color: _isCriticalLockActive ? Colors.redAccent : Colors.green,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  '今日の必須タスク・ロック',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$done/$total',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              color: _isCriticalLockActive ? Colors.redAccent : Colors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_pendingCriticalTitles.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pendingCriticalTitles.take(3).map((title) {
                return Chip(
                  label: Text(
                    title,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          if (_pendingCriticalGuides.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blueGrey.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '未達の必須タスクは手順ガイドを開いて、そのまま実行まで進める。',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _pendingCriticalGuides.take(3).map((guide) {
                return OutlinedButton.icon(
                  onPressed: () => _showCriticalTaskGuide(guide),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: Text('「${guide.label}」の手順'),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncCriticalTasks,
                  icon: const Icon(Icons.fact_check),
                  label: const Text('必須タスクを展開'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isTimeboxRunning ? null : _startCriticalFocusSprint,
                  icon: const Icon(Icons.gpp_good),
                  label: const Text('必須25分集中'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneDetoxPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phonelink_erase, color: Colors.red.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'スマホ禁欲プロトコル',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$_detoxCompletedCount/${_phoneDetoxActions.length}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '物理的に使えなくして、他のことに没頭する。',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _phoneDetoxActions
                .map((action) => _buildDetoxActionChip(action))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPhoneDetoxTemplateDialog,
                  icon: const Icon(Icons.checklist_rtl),
                  label: Text('8項目を追加 ($_detoxScheduledCount済み)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isTimeboxRunning ? null : _startPhoneLockFocus,
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('物理ロック90分'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetoxActionChip(_PhoneDetoxAction action) {
    final scheduled = _allTasks.any((task) => _isDetoxTask(task, action));
    final completed = _allTasks.any(
      (task) => _isDetoxTask(task, action) && task['is_completed'] == true,
    );

    final chipColor = completed
        ? Colors.green
        : scheduled
            ? _priorityColor(action.priority)
            : Colors.grey;
    final icon = completed
        ? Icons.check_circle
        : scheduled
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            action.label,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTask(
    int id,
    bool currentVal, {
    required String title,
    required int hourSlot,
  }) async {
    // 楽観的UI更新（待たずに切り替え）
    setState(() {
      // ローカルデータを無理やり書き換えるのは複雑なので、今回はロードし直す方式で
    });
    final nextValue = !currentVal;
    await _supabase
        .from('mindless_tasks')
        .update({'is_completed': nextValue}).eq('id', id);
    if (nextValue) {
      await _recordCompletionForTask(
        id,
        title: title,
        hourSlot: hourSlot,
      );
    } else {
      await _removeCompletionForTask(id);
    }
    _loadTasks();
  }

  Future<void> _deleteTask(int id) async {
    await _supabase.from('mindless_tasks').delete().eq('id', id);
    await _removeCompletionForTask(id);
    _loadTasks();
  }

  Widget _buildTodoViewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '表示形式',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ChoiceChip(
            label: const Text('時系列リスト'),
            selected: !_showFlowTodoMap,
            onSelected: (_) {
              setState(() {
                _showFlowTodoMap = false;
                _todoFlowImmersiveMode = false;
                _todoFlowLogMode = false;
              });
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('フローチャート'),
            selected: _showFlowTodoMap,
            onSelected: (_) {
              setState(() {
                _showFlowTodoMap = true;
              });
              _ensureTodoFlowStateLoaded();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyOverviewPreview() {
    final logs = _dailyCompletionTimeline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '一日の実行ログ俯瞰',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showDailyCompletionOverviewSheet,
                icon: const Icon(Icons.open_in_full, size: 16),
                label: const Text('全件表示'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (logs.isEmpty)
            Text(
              'まだ完了記録はありません。タスクを完了にすると、ここに時刻つきで残ります。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final log in logs.take(5))
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${DateFormat('HH:mm').format(log.completedAt)} ${log.title}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (logs.length > 5)
                    Text(
                      '他 ${logs.length - 5} 件',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodoFlowStatPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTodoFlowMapView() {
    if (_allTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'タスクを追加すると、ここにフローチャート形式で導線を表示します。',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final tasks = _sortedTasksForFlow;
    final completionTimeline = _dailyCompletionTimeline;
    final completionById = <String, _TaskCompletionLog>{
      for (final log in completionTimeline) log.taskId: log,
    };
    final completedTasksForTimeline = tasks.where((task) {
      final taskId = task['id']?.toString();
      return task['is_completed'] == true &&
          taskId != null &&
          completionById.containsKey(taskId);
    }).toList()
      ..sort((a, b) {
        final aLog = completionById[a['id']?.toString() ?? ''];
        final bLog = completionById[b['id']?.toString() ?? ''];
        if (aLog == null || bLog == null) return 0;
        return aLog.completedAt.compareTo(bLog.completedAt);
      });

    final visibleTasks = _todoFlowLogMode ? completedTasksForTimeline : tasks;
    final nodes = <_TodoFlowNodeData>[
      for (var index = 0; index < visibleTasks.length; index++)
        () {
          final task = visibleTasks[index];
          final taskId = _taskFlowId(task);
          final completionLog = completionById[taskId];
          final isCompleted = task['is_completed'] == true;
          final baseSubtitle = '${(task['hour_slot'] as int?) ?? 0}:00';
          final subtitle = _todoFlowLogMode
              ? completionLog == null
                  ? '$baseSubtitle 完了'
                  : '${DateFormat('HH:mm').format(completionLog.completedAt)} 完了 / $baseSubtitle枠'
              : completionLog != null && isCompleted
                  ? '${DateFormat('HH:mm').format(completionLog.completedAt)} 完了 / $baseSubtitle枠'
                  : '$baseSubtitle ${isCompleted ? '完了済み' : '未完了'}';
          return _TodoFlowNodeData(
            id: taskId,
            title: _stripPriorityTag(task['content'] as String? ?? ''),
            subtitle: subtitle,
            color: _todoFlowLogMode
                ? Colors.indigo
                : isCompleted
                    ? Colors.green
                    : _priorityColor(
                        _parsePriority(task['content'] as String? ?? ''),
                      ),
            icon: _todoFlowLogMode
                ? Icons.schedule
                : isCompleted
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
            isDimmed: !_todoFlowLogMode && isCompleted,
            position: _todoFlowLogMode
                ? _defaultTodoFlowPositionForLog(index)
                : (_todoFlowPositions[taskId] ?? const Offset(80, 80)),
            note: _todoFlowNotes[taskId],
          );
        }(),
    ];
    final links = _todoFlowLogMode
        ? <String>{
            for (var i = 0; i < visibleTasks.length - 1; i++)
              '${_taskFlowId(visibleTasks[i])}=>${_taskFlowId(visibleTasks[i + 1])}',
          }
        : _todoFlowLinks;
    final maxX = nodes.isEmpty
        ? 900.0
        : nodes.map((node) => node.position.dx).reduce(math.max);
    final maxY = nodes.isEmpty
        ? 700.0
        : nodes.map((node) => node.position.dy).reduce(math.max);
    final canvasWidth = math.max(1480.0, maxX + 520);
    final canvasHeight = math.max(960.0, maxY + 320);
    final pendingCount =
        _allTasks.where((task) => task['is_completed'] != true).length;
    final logCount = completionTimeline.length;
    final modeEmpty = _todoFlowLogMode && visibleTasks.isEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: _todoFlowLogMode ? 230 : 210,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub, color: Colors.indigo.shade400),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'フローチャートToDo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () {
                          setState(() {
                            _todoFlowImmersiveMode = !_todoFlowImmersiveMode;
                          });
                        },
                        icon: Icon(
                          _todoFlowImmersiveMode
                              ? Icons.close_fullscreen
                              : Icons.open_in_full,
                          size: 18,
                        ),
                        label: Text(
                          _todoFlowImmersiveMode ? '通常表示' : '広く表示',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _todoFlowImmersiveMode
                        ? 'フローチャートに集中できるよう、上部パネルを折りたたんでいます。'
                        : _todoFlowLogMode
                            ? 'その日に完了したタスクを、完了時刻順に俯瞰表示します。'
                            : 'ノードはドラッグで自由移動、編集で接続先と枝メモを設定できます。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('導線'),
                        selected: !_todoFlowLogMode,
                        onSelected: (_) {
                          setState(() {
                            _todoFlowLogMode = false;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('実行ログ俯瞰'),
                        selected: _todoFlowLogMode,
                        onSelected: (_) {
                          setState(() {
                            _todoFlowLogMode = true;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTodoFlowStatPill(
                        label: '残り',
                        value: '$pendingCount 件',
                        color: Colors.redAccent,
                      ),
                      _buildTodoFlowStatPill(
                        label: '完了',
                        value: '$_completedTasksToday 件',
                        color: Colors.green,
                      ),
                      _buildTodoFlowStatPill(
                        label: 'ログ',
                        value: '$logCount 件',
                        color: Colors.indigo,
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _todoFlowLogMode ? null : _resetTodoFlowLayout,
                        icon: const Icon(Icons.auto_fix_high, size: 16),
                        label: const Text('自動整列'),
                      ),
                    ],
                  ),
                  _buildDailyOverviewPreview(),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: InteractiveViewer(
                constrained: false,
                boundaryMargin: const EdgeInsets.all(120),
                minScale: 0.45,
                maxScale: 2.4,
                child: SizedBox(
                  width: canvasWidth,
                  height: canvasHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TodoFlowPainter(
                            nodes: nodes,
                            links: links,
                          ),
                        ),
                      ),
                      if (modeEmpty)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            constraints: const BoxConstraints(maxWidth: 360),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.indigo.withValues(alpha: 0.14),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timeline,
                                  color: Colors.indigo.shade400,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '実行ログはまだありません',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'タスクを完了にすると、その日の実行ログを時刻順でここに俯瞰表示します。',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final node in nodes)
                        Positioned(
                          left: node.position.dx,
                          top: node.position.dy,
                          child: GestureDetector(
                            onPanUpdate: _todoFlowLogMode
                                ? null
                                : (details) {
                                    final nextPosition = Offset(
                                      (node.position.dx + details.delta.dx)
                                          .clamp(
                                        0.0,
                                        canvasWidth - (_todoFlowNodeWidth + 32),
                                      ),
                                      (node.position.dy + details.delta.dy)
                                          .clamp(
                                        0.0,
                                        canvasHeight - 150,
                                      ),
                                    );
                                    setState(() {
                                      _todoFlowPositions[node.id] =
                                          nextPosition;
                                    });
                                  },
                            onPanEnd: _todoFlowLogMode
                                ? null
                                : (_) {
                                    _persistTodoFlowState();
                                  },
                            child: _buildTodoFlowNode(
                              node,
                              isEditable: !_todoFlowLogMode,
                              onEdit: () {
                                final task = tasks.firstWhere(
                                  (task) => _taskFlowId(task) == node.id,
                                );
                                _showTodoFlowNodeEditor(task);
                              },
                            ),
                          ),
                        ),
                      for (final node in nodes)
                        if (node.note != null && node.note!.isNotEmpty)
                          Positioned(
                            left: node.position.dx + _todoFlowNoteOffsetX,
                            top: node.position.dy + 10,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 240),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                node.note!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.brown.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoFlowNode(
    _TodoFlowNodeData node, {
    required VoidCallback onEdit,
    bool isEditable = true,
  }) {
    final backgroundColor = Color.alphaBlend(
      Colors.white.withValues(alpha: node.isDimmed ? 0.7 : 0.92),
      node.color.withValues(alpha: node.isDimmed ? 0.08 : 0.14),
    );

    return Opacity(
      opacity: node.isDimmed ? 0.72 : 1,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 240,
          maxWidth: _todoFlowNodeWidth,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: node.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: node.color.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: node.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                node.icon,
                size: 18,
                color: node.color,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (node.subtitle != null && node.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      node.subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isEditable)
              IconButton(
                tooltip: '接続とメモを編集',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: node.color,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeboxPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border(
          top: BorderSide(color: Colors.amber.shade200),
          bottom: BorderSide(color: Colors.amber.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_bottom, color: Colors.orange.shade800),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '先に時間制限を決める（1つの手間）',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '完了 $_completedTimeboxCount 回',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '「動く」も「考える」も先に終了時刻を決めると、脱線から戻りやすくなります。',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,),
          ),
          const SizedBox(height: 10),
          _buildCriticalLockPanel(),
          const SizedBox(height: 10),
          _buildHundredTaskPanel(),
          const SizedBox(height: 10),
          _buildPhoneDetoxPanel(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.menu_book, size: 18, color: Colors.brown),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '読書ルーティン（喫茶店 + アルバム）',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'アルバム1枚=60分で読書。2枚集中したら30〜60分散歩して、次の店で繰り返す。',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _isTimeboxRunning ? null : _startReadingAlbum,
                        icon: const Icon(Icons.library_music),
                        label: const Text('アルバム1枚読書'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTimeboxRunning
                            ? null
                            : () => _startWalkBreak(30),
                        icon: const Icon(Icons.directions_walk),
                        label: const Text('散歩30分'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isTimeboxRunning
                            ? null
                            : () => _startWalkBreak(60),
                        icon: const Icon(Icons.route),
                        label: const Text('散歩60分'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isTimeboxRunning ? null : _startReadingAlbum,
                        icon: const Icon(Icons.replay),
                        label: const Text('もう1枚読む'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _phoneShieldEnabled,
                  onChanged: (value) {
                    setState(() => _phoneShieldEnabled = value);
                  },
                  title: const Text('読書中はスマホを見ないモード'),
                ),
                if (_phoneShieldEnabled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_android,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'スマホ逸脱 $phoneSlipLabel',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isTimeboxRunning && _timeboxMode == '読書'
                              ? _logPhoneSlip
                              : null,
                          child: const Text('見てしまった +1'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      icon: Icons.menu_book,
                      label: '読書',
                      value: _completedReadingSessions.toString(),
                    ),
                    _buildMetricChip(
                      icon: Icons.directions_walk,
                      label: '散歩',
                      value: _completedWalkBreaks.toString(),
                    ),
                    _buildMetricChip(
                      icon: Icons.local_fire_department,
                      label: '連続読書',
                      value: _currentReadingStreak.toString(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _timeboxPresets.map((minutes) {
              return ChoiceChip(
                label: Text('$minutes分'),
                selected: _selectedMinutes == minutes,
                onSelected: (_) {
                  setState(() => _selectedMinutes = minutes);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isTimeboxRunning ? null : () => _startTimeboxFlow('動く'),
                  icon: const Icon(Icons.directions_run),
                  label: const Text('動くを開始'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      _isTimeboxRunning ? null : () => _startTimeboxFlow('考える'),
                  icon: const Icon(Icons.psychology),
                  label: const Text('考えるを開始'),
                ),
              ),
            ],
          ),
          if (_isTimeboxRunning || _timeboxRemaining.inSeconds > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_timeboxMode: $_timeboxGoal',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatRemaining(_timeboxRemaining),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: _timeboxProgress()),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTimeboxRunning
                              ? () => _extendTimebox(5)
                              : null,
                          icon: const Icon(Icons.add_alarm),
                          label: const Text('5分延長'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isTimeboxRunning ? _stopTimebox : null,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('終了'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get phoneSlipLabel => '$_phoneSlipCount 回';

  Widget _buildPriorityProgressChip(TaskPriority priority) {
    final total = _priorityTotal(priority);
    final done = _priorityCompleted(priority);
    final color = _priorityColor(priority);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${_priorityLabel(priority)} $done/$total',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueGrey.shade700),
          const SizedBox(width: 4),
          Text(
            '$label $value',
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思考停止脱出ログ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // コンセプトヘッダー
          Container(
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  DateFormat('yyyy/MM/dd (E)', 'ja').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '「脱線したら、時間制限を合図に元の目的へ戻る」',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (!_showFlowTodoMap || !_todoFlowImmersiveMode)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: _showFlowTodoMap
                    ? math.min(
                        MediaQuery.of(context).size.height * 0.22,
                        180,
                      )
                    : MediaQuery.of(context).size.height * 0.38,
              ),
              child: SingleChildScrollView(
                child: _buildTimeboxPanel(),
              ),
            ),
          _buildTodoViewToggle(),

          // タイムライン
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _showFlowTodoMap
                    ? _buildTodoFlowMapView()
                    : ListView.builder(
                        itemCount: 24, // 0時〜23時
                        itemBuilder: (context, hour) {
                          final tasks = _tasksByHour[hour] ?? [];
                          // 現在時刻のハイライト
                          final isCurrentHour =
                              _selectedDate.day == DateTime.now().day &&
                                  _selectedDate.month == DateTime.now().month &&
                                  _selectedDate.year == DateTime.now().year &&
                                  hour == DateTime.now().hour;

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,),
                                left: isCurrentHour
                                    ? const BorderSide(
                                        color: Colors.blue,
                                        width: 4,
                                      )
                                    : BorderSide.none,
                              ),
                              color: isCurrentHour
                                  ? Colors.blue.withValues(alpha: 0.05)
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 時間ラベル
                                Container(
                                  width: 60,
                                  padding: const EdgeInsets.all(12),
                                  alignment: Alignment.topCenter,
                                  child: Text(
                                    '$hour:00',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCurrentHour
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                  ),
                                ),

                                // タスクリストエリア
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (tasks.isEmpty)
                                        InkWell(
                                          onTap: () => _addTask(hour),
                                          child: Container(
                                            height: 40,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '＋ タスクを追加',
                                              style: TextStyle(
                                                color: _isCriticalLockActive
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .outlineVariant,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        ...tasks.map((task) {
                                          final isDone =
                                              task['is_completed'] as bool;
                                          final isCriticalTask =
                                              _isCriticalTaskRow(task);
                                          final isSuppressedByCriticalLock =
                                              _isCriticalLockActive &&
                                                  !isCriticalTask &&
                                                  !isDone;
                                          final rawContent =
                                              task['content'] as String? ?? '';
                                          final priority =
                                              _parsePriority(rawContent);
                                          final displayContent =
                                              _stripPriorityTag(rawContent);
                                          final criticalGuide =
                                              _criticalGuideForTitle(
                                            displayContent,
                                          );
                                          return InkWell(
                                            onLongPress: () =>
                                                _deleteTask(task['id']),
                                            onTap: () {
                                              if (isSuppressedByCriticalLock) {
                                                _showCompleteCriticalTasksSnackBar();
                                                return;
                                              }
                                              _toggleTask(
                                                task['id'],
                                                isDone,
                                                title: displayContent,
                                                hourSlot: (task['hour_slot']
                                                        as int?) ??
                                                    0,
                                              );
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 8,
                                                horizontal: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isSuppressedByCriticalLock
                                                        ? Colors.blueGrey
                                                            .withValues(
                                                            alpha: 0.05,
                                                          )
                                                        : null,
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHigh,
                                                  ),
                                                ),
                                              ),
                                              child: Opacity(
                                                opacity:
                                                    isSuppressedByCriticalLock
                                                        ? 0.46
                                                        : 1,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      isDone
                                                          ? Icons.check_circle
                                                          : isSuppressedByCriticalLock
                                                              ? Icons
                                                                  .lock_outline
                                                              : Icons
                                                                  .circle_outlined,
                                                      color: isDone
                                                          ? Colors.green
                                                          : isSuppressedByCriticalLock
                                                              ? Colors.blueGrey
                                                              : Colors.grey,
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _priorityColor(
                                                          priority,
                                                        ).withValues(
                                                          alpha: 0.14,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          6,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        _priorityLabel(
                                                          priority,
                                                        ),
                                                        style: TextStyle(
                                                          color: _priorityColor(
                                                            priority,
                                                          ),
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        displayContent,
                                                        style: TextStyle(
                                                          decoration: isDone
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                          color: isDone
                                                              ? Colors.grey
                                                              : isSuppressedByCriticalLock
                                                                  ? Colors
                                                                      .black54
                                                                  : Colors
                                                                      .black,
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSuppressedByCriticalLock)
                                                      Container(
                                                        margin: const EdgeInsets
                                                            .only(
                                                          right: 4,
                                                        ),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.blueGrey
                                                              .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            999,
                                                          ),
                                                        ),
                                                        child: const Text(
                                                          '保留',
                                                          style: TextStyle(
                                                            color:
                                                                Colors.blueGrey,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                    if (criticalGuide != null)
                                                      IconButton(
                                                        tooltip: 'やり方を表示',
                                                        onPressed: () =>
                                                            _showCriticalTaskGuide(
                                                          criticalGuide,
                                                        ),
                                                        icon: Icon(
                                                          Icons.help_outline,
                                                          color: Colors.blueGrey
                                                              .shade500,
                                                          size: 18,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      // タスクがある場合も追加ボタンを下部に表示
                                      if (tasks.isNotEmpty)
                                        InkWell(
                                          onTap: () => _addTask(hour),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            alignment: Alignment.centerLeft,
                                            child: Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .outlineVariant,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
