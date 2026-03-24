import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _TaskItem {
  final String title;
  final String dateStr;
  _TaskItem({required this.title, required this.dateStr});
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
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'growth-achievement-summary',
        body: {'period': period},
      );
      final data = res.data as Map<String, dynamic>;
      final list = (data['achievements'] as List?)?.map((e) {
            final map = e as Map<String, dynamic>;
            return _TaskItem(
              title: map['title']?.toString() ?? '',
              dateStr: map['dateStr']?.toString() ?? '',
            );
          }).toList() ?? [];
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
          _currentTasks = [_TaskItem(title: '実績の取得に失敗しました', dateStr: '')];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor =
        isDark ? const Color(0xFF1A2233) : const Color(0xFFFFFFFF);
    final borderColor =
        isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

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
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPeriod,
                    icon: Icon(Icons.arrow_drop_down, size: 16, color: subTextColor),
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
                        setState(() {
                          _selectedPeriod = newValue;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            Text('この期間の実績はまだありません', style: TextStyle(fontSize: 12, color: subTextColor))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _currentTasks.map((task) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('・ ', style: TextStyle(color: subTextColor, fontSize: 13)),
                      Expanded(
                        child: Text(
                          task,
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withValues(alpha: 0.8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}