import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// ホーム画面に表示する「時間溶かし防止」クイックアクションウィジェット。
///
/// X、YouTube、コーヒー、煙草など時間を溶かす行為を
/// ワンタップで「今やめる」宣言し、代替行動を提示する。
class TimeWasteGuardWidget extends StatefulWidget {
  const TimeWasteGuardWidget({super.key});

  @override
  State<TimeWasteGuardWidget> createState() => _TimeWasteGuardWidgetState();
}

class _TimeWasteGuardWidgetState extends State<TimeWasteGuardWidget> {
  final Map<String, bool> _activeGuards = {};
  final Map<String, int> _todaySlips = {};
  bool _isExpanded = false;

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
    _loadState();
  }

  String get _todayKey => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final guards = <String, bool>{};
    final slips = <String, int>{};
    for (final item in _items) {
      guards[item.id] =
          prefs.getBool('twg_active_${_todayKey}_${item.id}') ?? false;
      slips[item.id] =
          prefs.getInt('twg_slips_${_todayKey}_${item.id}') ?? 0;
    }
    if (mounted) {
      setState(() {
        _activeGuards.addAll(guards);
        _todaySlips.addAll(slips);
      });
    }
  }

  Future<void> _activateGuard(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('twg_active_${_todayKey}_$itemId', true);
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
    final activeCount =
        _activeGuards.values.where((v) => v).length;
    final totalSlips =
        _todaySlips.values.fold(0, (sum, v) => sum + v);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: totalSlips > 0
              ? Colors.red.shade200
              : Colors.indigo.shade100,
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
                      totalSlips > 0
                          ? Icons.warning_amber
                          : Icons.shield,
                      color: totalSlips > 0
                          ? Colors.red
                          : const Color(0xFF4338CA),
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
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Wrap(
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
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? item.color.withAlpha(80)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isActive ? item.color : Colors.grey[700],
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
