import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TaskItem {
  final String title;
  final String description;
  final String dateStr; // "(YYYY-MM-DD HH:MM:SS 追加)"
  final DateTime? completedAt;
  _TaskItem({
    required this.title,
    required this.description,
    required this.dateStr,
    this.completedAt,
  });
}

class DevelopmentAchievementsCard extends StatefulWidget {
  const DevelopmentAchievementsCard({super.key});

  @override
  State<DevelopmentAchievementsCard> createState() =>
      _DevelopmentAchievementsCardState();
}

class _DevelopmentAchievementsCardState
    extends State<DevelopmentAchievementsCard> {
  String _selectedPeriod = '今日の実績';
  bool _isLoading = false;
  List<_TaskItem> _currentTasks = [];

  static const List<String> _periods = [
    '今日の実績',
    '今週の実績',
    '直近2週間の実績',
    '今月の実績',
    '直近2ヶ月の実績',
    '直近3ヶ月の実績',
    '直近半年の実績',
    '直近1年の実績',
    '直近2年の実績',
    '直近3年の実績',
    '直近5年の実績',
    '直近10年の実績',
    'すべての実績',
  ];

  @override
  void initState() {
    super.initState();
    _fetchTasks(_selectedPeriod);
  }

  Future<void> _fetchTasks(String period) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'core-hub',
        body: {'action': 'achievements.list', 'period': period},
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      final achievements = (data['achievements'] as List<dynamic>?) ?? [];

      final list = achievements.map((e) {
        final map = e as Map<String, dynamic>;
        final title = map['title']?.toString() ?? '';
        final description = map['description']?.toString() ?? '';
        final completedAtStr = map['completed_at']?.toString();
        String dateStr = '';
        DateTime? completedAt;
        if (completedAtStr != null && completedAtStr.isNotEmpty) {
          completedAt = DateTime.tryParse(completedAtStr)?.toLocal();
          if (completedAt != null) {
            final y = completedAt.year;
            final mo = completedAt.month.toString().padLeft(2, '0');
            final d = completedAt.day.toString().padLeft(2, '0');
            final h = completedAt.hour.toString().padLeft(2, '0');
            final mi = completedAt.minute.toString().padLeft(2, '0');
            final s = completedAt.second.toString().padLeft(2, '0');
            dateStr = '($y-$mo-$d $h:$mi:$s 追加)';
          }
        }
        return _TaskItem(
          title: title,
          description: description,
          dateStr: dateStr,
          completedAt: completedAt,
        );
      }).toList();

      // 時系列順 (新しい順)
      list.sort((a, b) {
        if (a.completedAt == null && b.completedAt == null) return 0;
        if (a.completedAt == null) return 1;
        if (b.completedAt == null) return -1;
        return b.completedAt!.compareTo(a.completedAt!);
      });

      if (mounted) {
        setState(() {
          _currentTasks = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      if (mounted) {
        setState(() {
          _currentTasks = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddAchievementDialog(BuildContext context) async {
    final titleController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('開発実績の追加', style: TextStyle(fontSize: 16)),
              content: TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '実績内容 (例: ホーム画面に機能を追加)',
                  hintText: '入力してください',
                ),
                autofocus: true,
                maxLines: 2,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final text = titleController.text.trim();
                          if (text.isEmpty) return;
                          setStateDialog(() => isSubmitting = true);
                          try {
                            await Supabase.instance.client.functions.invoke(
                              'core-hub',
                              body: {
                                'action': 'achievements.add',
                                'title': text,
                              },
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop(true);
                            }
                          } catch (e) {
                            debugPrint('Error inserting achievement: $e');
                            setStateDialog(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('追加'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result == true) {
        _fetchTasks(_selectedPeriod);
      }
    });
  }

  void _showDetailDialog(BuildContext context, _TaskItem task) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) ...[
              const Text(
                '詳細',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                task.description,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  task.dateStr.isNotEmpty ? task.dateStr : '日時不明',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (task.description.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                '詳細説明はまだ登録されていません。',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? Color(0xFF1A2233) : Color(0xFFFFFFFF);
    final borderColor =
        isDark ? Color(0xFF2A3A55) : Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : Color(0xFF1E293B);
    final subTextColor =
        isDark ? Color(0xFF94A3B8) : Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              const Text(
                '開発・成長実績',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF10B981),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: Color(0xFF10B981),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '実績を追加',
                onPressed: () => _showAddAchievementDialog(context),
              ),
              const SizedBox(width: 12),
              // 期間セレクター
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Color(0xFF0F172A)
                      : Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: subTextColor,
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    dropdownColor: cardColor,
                    items: _periods.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedPeriod = newValue);
                        _fetchTasks(newValue);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          // 件数バッジ
          if (!_isLoading && _currentTasks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${_currentTasks.length}件  ※タップで詳細表示',
              style: TextStyle(fontSize: 11, color: subTextColor),
            ),
          ],
          const SizedBox(height: 12),
          // コンテンツ
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_currentTasks.isEmpty)
            Text(
              'この期間の実績はまだありません',
              style: TextStyle(fontSize: 12, color: subTextColor),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _currentTasks.asMap().entries.map((entry) {
                final index = entry.key;
                final task = entry.value;
                return InkWell(
                  onTap: () => _showDetailDialog(context, task),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 順番バッジ
                        Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 1, right: 8),
                          decoration: BoxDecoration(
                            color:
                                Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    task.dateStr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: subTextColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (task.description.isNotEmpty)
                                    Icon(
                                      Icons.info_outline,
                                      size: 12,
                                      color:
                                          subTextColor.withValues(alpha: 0.6),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: subTextColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
