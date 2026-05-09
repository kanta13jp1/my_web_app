import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// ホーム画面に表示する「時間溶かし防止」クイックアクションウィジェット。
///
/// X、YouTube、コーヒー、煙草など時間を溶かす行為を
/// ワンタップで「今やめる」宣言し、代替行動を提示する。
class TimeWasteGuardWidget extends StatefulWidget {
  const TimeWasteGuardWidget({super.key});

  static const int continuousUseReminderMinutes = 120;

  static const List<String> guardItemIds = <String>[
    'x_twitter',
    'youtube',
    'coffee',
    'smoking',
    'sns_general',
    'manga_anime',
    'game',
    'snacking',
  ];

  static String dateKeyFor(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static String refreshActionCountKeyFor(DateTime date) =>
      'twg_refresh_actions_${dateKeyFor(date)}';

  static String refreshActionLastKeyFor(DateTime date) =>
      'twg_refresh_last_action_${dateKeyFor(date)}';

  static Future<int> loadSlipCountFor(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateKey = dateKeyFor(date);
    var total = 0;
    for (final itemId in guardItemIds) {
      total += prefs.getInt('twg_slips_${dateKey}_$itemId') ?? 0;
    }
    return total;
  }

  static Future<int> loadRefreshActionCountFor(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(refreshActionCountKeyFor(date)) ?? 0;
  }

  static Future<String?> loadLastRefreshActionFor(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(refreshActionLastKeyFor(date));
  }

  static Future<void> recordRefreshAction({
    required DateTime date,
    required String action,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final countKey = refreshActionCountKeyFor(date);
    final nextCount = (prefs.getInt(countKey) ?? 0) + 1;
    await prefs.setInt(countKey, nextCount);
    await prefs.setString(refreshActionLastKeyFor(date), action);
  }

  @override
  State<TimeWasteGuardWidget> createState() => _TimeWasteGuardWidgetState();
}

class _TimeWasteGuardWidgetState extends State<TimeWasteGuardWidget> {
  final Map<String, bool> _activeGuards = {};
  final Map<String, int> _todaySlips = {};
  final math.Random _random = math.Random();
  bool _isExpanded = false;
  Timer? _sessionReminderTimer;
  DateTime? _sessionStartedAt;
  int _refreshActionCount = 0;
  String? _lastRefreshAction;

  static const List<String> _refreshActionSuggestions = <String>[
    '10分だけ外を歩く',
    '画面から離れて本を1ページ読む',
    '肩と首を3分ストレッチする',
    '水を飲んで窓際で立つ',
    '次の具体的な作業を紙に1行書く',
  ];

  static const _items = [
    _GuardItem(
      id: 'x_twitter',
      label: 'X (Twitter)',
      emoji: '🐦',
      color: Color(0xFF1DA1F2),
      stopAction: 'アプリを閉じてログアウト。通知OFF。',
      doInstead: '→ 代わりに: 今日のタスクを1つ片付ける',
    ),
    _GuardItem(
      id: 'youtube',
      label: 'YouTube',
      emoji: '📺',
      color: Color(0xFFFF0000),
      stopAction: 'タブを閉じる。おすすめを見ない。',
      doInstead: '→ 代わりに: 5分だけ本を読む',
    ),
    _GuardItem(
      id: 'coffee',
      label: 'コーヒー',
      emoji: '☕',
      color: Color(0xFF795548),
      stopAction: '水を飲む。カフェイン摂取は1日2杯まで。',
      doInstead: '→ 代わりに: 水を1杯飲む',
    ),
    _GuardItem(
      id: 'smoking',
      label: '煙草',
      emoji: '🚬',
      color: Color(0xFF607D8B),
      stopAction: '深呼吸3回。ライターを引き出しにしまう。',
      doInstead: '→ 代わりに: 3分間歩く or 深呼吸',
    ),
    _GuardItem(
      id: 'sns_general',
      label: 'SNS全般',
      emoji: '📱',
      color: Color(0xFF9C27B0),
      stopAction: 'スマホを裏返す。別室に置く。',
      doInstead: '→ 代わりに: 紙に次の行動を1行書く',
    ),
    _GuardItem(
      id: 'manga_anime',
      label: '漫画・アニメ',
      emoji: '📖',
      color: Color(0xFFFF9800),
      stopAction: 'アプリを閉じる。夜の自由時間へ送る。',
      doInstead: '→ 代わりに: 衝動をメモして後で',
    ),
    _GuardItem(
      id: 'game',
      label: 'ゲーム',
      emoji: '🎮',
      color: Color(0xFF4CAF50),
      stopAction: 'アプリをホーム画面から外す。',
      doInstead: '→ 代わりに: 5分だけ単純作業を片付ける',
    ),
    _GuardItem(
      id: 'snacking',
      label: '間食',
      emoji: '🍪',
      color: Color(0xFFE91E63),
      stopAction: '水を飲む。空腹でないなら衝動だけ。',
      doInstead: '→ 代わりに: 水を飲んで5分待つ',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    _loadState();
    _startSessionReminderTimer();
  }

  @override
  void dispose() {
    _sessionReminderTimer?.cancel();
    super.dispose();
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final guards = <String, bool>{};
    final slips = <String, int>{};
    for (final item in _items) {
      guards[item.id] =
          prefs.getBool('twg_active_${_todayKey}_${item.id}') ?? false;
      slips[item.id] = prefs.getInt('twg_slips_${_todayKey}_${item.id}') ?? 0;
    }
    final today = DateTime.now();
    final refreshActionCount =
        prefs.getInt(TimeWasteGuardWidget.refreshActionCountKeyFor(today)) ?? 0;
    final lastRefreshAction =
        prefs.getString(TimeWasteGuardWidget.refreshActionLastKeyFor(today));
    if (mounted) {
      setState(() {
        _activeGuards.addAll(guards);
        _todaySlips.addAll(slips);
        _refreshActionCount = refreshActionCount;
        _lastRefreshAction = lastRefreshAction;
      });
    }
  }

  void _startSessionReminderTimer() {
    _sessionReminderTimer?.cancel();
    _sessionReminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _maybeShowContinuousUseReminder(),
    );
  }

  String _pickRefreshAction() {
    final index = _random.nextInt(_refreshActionSuggestions.length);
    return _refreshActionSuggestions[index];
  }

  Future<void> _maybeShowContinuousUseReminder() async {
    final startedAt = _sessionStartedAt;
    if (!mounted || startedAt == null) return;

    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed.inMinutes < TimeWasteGuardWidget.continuousUseReminderMinutes) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final reminderKey =
        'twg_session_reminded_${_todayKey}_${startedAt.millisecondsSinceEpoch}';
    if (prefs.getBool(reminderKey) ?? false) return;
    await prefs.setBool(reminderKey, true);

    final action = _pickRefreshAction();
    if (!mounted) return;
    final completed = await _showRefreshReminderDialog(action);
    if (completed == true) {
      await _recordRefreshAction(action);
    }
    if (!mounted) return;
    setState(() {
      _sessionStartedAt = DateTime.now();
    });
  }

  Future<bool?> _showRefreshReminderDialog(String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('リフレッシュの時間です'),
          content: Text(
            '約2時間連続で利用しています。短く画面から離れてください。\n\n提案アクション:\n$action',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('後で'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: const Text('実行した'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _recordRefreshAction(String action) async {
    final today = DateTime.now();
    await TimeWasteGuardWidget.recordRefreshAction(
      date: today,
      action: action,
    );
    final refreshActionCount =
        await TimeWasteGuardWidget.loadRefreshActionCountFor(today);
    final lastRefreshAction =
        await TimeWasteGuardWidget.loadLastRefreshActionFor(today);
    if (!mounted) return;
    setState(() {
      _refreshActionCount = refreshActionCount;
      _lastRefreshAction = lastRefreshAction;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('リフレッシュ行動を記録しました: $action'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _activateGuard(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('twg_active_${_todayKey}_$itemId', true);
    if (!mounted) return;
    if (mounted) setState(() => _activeGuards[itemId] = true);

    final item = _items.firstWhere((i) => i.id == itemId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛡️ ${item.label}ガードON: ${item.stopAction}'),
          backgroundColor: item.color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _recordSlip(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = _todaySlips[itemId] ?? 0;
    final newCount = current + 1;
    await prefs.setInt('twg_slips_${_todayKey}_$itemId', newCount);
    if (!mounted) return;
    if (mounted) setState(() => _todaySlips[itemId] = newCount);

    final item = _items.firstWhere((i) => i.id == itemId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ ${item.label}: 今日$newCount回目の逸脱。${item.doInstead}',
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeGuards.values.where((v) => v).length;
    final totalSlips = _todaySlips.values.fold(0, (sum, v) => sum + v);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: totalSlips > 0 ? Colors.red.shade200 : const Color(0xFFC5CAE9),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: totalSlips > 0
                          ? Colors.red.shade50
                          : const Color(0xFFEDE7F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      totalSlips > 0 ? Icons.warning_amber : Icons.shield,
                      color:
                          totalSlips > 0 ? Colors.red : const Color(0xFF4338CA),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🛡️ 時間溶かし防止ガード',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          totalSlips > 0
                              ? '今日の逸脱: $totalSlips回 | ガード: $activeCount個'
                              : 'ガード: $activeCount個 ON',
                          style: TextStyle(
                            fontSize: 11,
                            color: totalSlips > 0
                                ? Colors.red
                                : const Color(0xFF757575),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFFB0B0B0),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRefreshActionPanel(),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _items.map((item) {
                      final isActive = _activeGuards[item.id] ?? false;
                      final slips = _todaySlips[item.id] ?? 0;

                      return GestureDetector(
                        onTap: () {
                          if (isActive) {
                            _recordSlip(item.id);
                          } else {
                            _activateGuard(item.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? item.color.withAlpha(20)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? item.color.withAlpha(80)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.emoji,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: isActive
                                      ? item.color
                                      : Theme.of(context).colorScheme.onSurface,
                                  height: 1.5,
                                ),
                              ),
                              if (slips > 0) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$slips',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRefreshActionPanel() {
    return Container(
      key: const Key('time_waste_refresh_action_panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF009688).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF009688).withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.directions_walk,
            color: Color(0xFF009688),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今日のリフレッシュ: $_refreshActionCount回',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00796B),
                    height: 1.5,
                  ),
                ),
                if (_lastRefreshAction != null)
                  Text(
                    '直近: $_lastRefreshAction',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF00796B),
                      height: 1.5,
                    ),
                  ),
              ],
            ),
          ),
          TextButton.icon(
            key: const Key('time_waste_log_refresh_action'),
            onPressed: () => _recordRefreshAction(_pickRefreshAction()),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('記録'),
          ),
        ],
      ),
    );
  }
}

class _GuardItem {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final String stopAction;
  final String doInstead;

  const _GuardItem({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.stopAction,
    required this.doInstead,
  });
}
