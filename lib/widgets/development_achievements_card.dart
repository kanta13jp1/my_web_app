import 'package:flutter/material.dart';

class DevelopmentAchievementsCard extends StatefulWidget {
  const DevelopmentAchievementsCard({super.key});

  @override
  State<DevelopmentAchievementsCard> createState() =>
      _DevelopmentAchievementsCardState();
}

class _DevelopmentAchievementsCardState
    extends State<DevelopmentAchievementsCard> {
  String _selectedPeriod = '今日の実績';

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

  // ※ 実際は期間に応じて Supabase 等から実績データをフェッチする処理に置き換えます
  Map<String, int> _getDummyDataForPeriod(String period) {
    final multiplier = _periods.indexOf(period) + 1;
    return {
      '新規ユーザー登録': 2 * multiplier,
      'インポート完了': 5 * multiplier,
      '紹介(Referral)成立': 1 * multiplier,
      '機能改善コミット': 3 * multiplier,
    };
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

    final currentData = _getDummyDataForPeriod(_selectedPeriod);

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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: currentData.entries.map((entry) {
              return Container(
                width: (MediaQuery.of(context).size.width - 76) / 2, // 2カラム
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: TextStyle(fontSize: 11, color: subTextColor)),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: textColor,
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