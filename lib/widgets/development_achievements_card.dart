import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Period definitions
// ---------------------------------------------------------------------------

class _Period {
  final String label;
  final DateTime Function() sinceProvider;

  const _Period(this.label, this.sinceProvider);

  String get sinceIso => sinceProvider().toUtc().toIso8601String();
}

DateTime _todayMidnight() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final _periods = [
  const _Period('今日', _todayMidnight),
  _Period('今週', () => DateTime.now().subtract(const Duration(days: 7))),
  _Period('直近2週間', () => DateTime.now().subtract(const Duration(days: 14))),
  _Period('今月', () {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }),
  _Period('直近2ヶ月', () => DateTime.now().subtract(const Duration(days: 60))),
  _Period('直近3ヶ月', () => DateTime.now().subtract(const Duration(days: 90))),
  _Period('直近半年', () => DateTime.now().subtract(const Duration(days: 180))),
  _Period('直近1年', () => DateTime.now().subtract(const Duration(days: 365))),
  _Period('直近2年', () => DateTime.now().subtract(const Duration(days: 730))),
  _Period('直近3年', () => DateTime.now().subtract(const Duration(days: 1095))),
  _Period('直近5年', () => DateTime.now().subtract(const Duration(days: 1825))),
  _Period('直近10年', () => DateTime.now().subtract(const Duration(days: 3650))),
  _Period('すべて', () => DateTime(2020)),
];

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _AchievementData {
  final int newUsers;
  final int totalUsersEver;
  final int acquisitionSignals;
  final int referralsCompleted;
  final int importPreviews;

  const _AchievementData({
    required this.newUsers,
    required this.totalUsersEver,
    required this.acquisitionSignals,
    required this.referralsCompleted,
    required this.importPreviews,
  });

  static const zero = _AchievementData(
    newUsers: 0,
    totalUsersEver: 0,
    acquisitionSignals: 0,
    referralsCompleted: 0,
    importPreviews: 0,
  );
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// ホーム画面に表示する開発実績カード。
/// 期間セレクターで 今日〜すべて の13区間を切り替えられる。
class DevelopmentAchievementsCard extends StatefulWidget {
  final SupabaseClient? supabaseClient;

  const DevelopmentAchievementsCard({super.key, this.supabaseClient});

  @override
  State<DevelopmentAchievementsCard> createState() =>
      _DevelopmentAchievementsCardState();
}

class _DevelopmentAchievementsCardState
    extends State<DevelopmentAchievementsCard> {
  int _selectedPeriodIndex = 0; // 今日
  _AchievementData _data = _AchievementData.zero;
  bool _isLoading = true;
  String? _error;

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final period = _periods[_selectedPeriodIndex];
      final sinceStr = period.sinceIso;
      final session = _supabase.auth.currentSession;

      if (session == null) {
        setState(() {
          _data = _AchievementData.zero;
          _isLoading = false;
        });
        return;
      }

      final response = await _supabase.functions.invoke(
        'growth-achievement-summary',
        body: {'since': sinceStr, 'label': period.label},
      );

      if (response.status != 200) {
        throw Exception('HTTP ${response.status}');
      }

      final json = response.data as Map<String, dynamic>?;
      if (json == null || json['success'] != true) {
        throw Exception(json?['error'] ?? 'Unknown error');
      }

      if (!mounted) return;
      setState(() {
        _data = _AchievementData(
          newUsers: (json['newUsers'] as num?)?.toInt() ?? 0,
          totalUsersEver: (json['totalUsersEver'] as num?)?.toInt() ?? 0,
          acquisitionSignals:
              (json['acquisitionSignals'] as num?)?.toInt() ?? 0,
          referralsCompleted:
              (json['referralsCompleted'] as num?)?.toInt() ?? 0,
          importPreviews: (json['importPreviews'] as num?)?.toInt() ?? 0,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      key: const Key('development_achievements_card'),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: Color(0xFF6366F1),
              ),
              const SizedBox(width: 8),
              const Text(
                '開発実績',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF6366F1),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Period selector
          _PeriodSelector(
            selectedIndex: _selectedPeriodIndex,
            onChanged: (i) {
              setState(() => _selectedPeriodIndex = i);
              _load();
            },
            subColor: subColor,
          ),
          const SizedBox(height: 12),
          // Error state
          if (_error != null)
            Text(
              '読み込みエラー: $_error',
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            )
          else ...[
            // Metric grid
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _MetricTile(
                  label: '新規ユーザー',
                  value: _data.newUsers,
                  icon: Icons.person_add_outlined,
                  color: const Color(0xFF22C55E),
                  sublabel:
                      '累計 ${_data.totalUsersEver} 人',
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
                _MetricTile(
                  label: '成長シグナル',
                  value: _data.acquisitionSignals,
                  icon: Icons.trending_up,
                  color: const Color(0xFF6366F1),
                  sublabel: '獲得イベント数',
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
                _MetricTile(
                  label: '紹介成立',
                  value: _data.referralsCompleted,
                  icon: Icons.card_giftcard_outlined,
                  color: const Color(0xFFEC4899),
                  sublabel: 'referral 完了',
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
                _MetricTile(
                  label: 'インポート',
                  value: _data.importPreviews,
                  icon: Icons.upload_file_outlined,
                  color: const Color(0xFF14B8A6),
                  sublabel: 'プレビュー実行数',
                  textColor: textColor,
                  subColor: subColor,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Period selector — scrollable chips
// ---------------------------------------------------------------------------

class _PeriodSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color subColor;

  const _PeriodSelector({
    required this.selectedIndex,
    required this.onChanged,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_periods.length, (i) {
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF6366F1).withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _periods[i].label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : subColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metric tile
// ---------------------------------------------------------------------------

class _MetricTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String sublabel;
  final Color textColor;
  final Color subColor;
  final bool isDark;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sublabel,
    required this.textColor,
    required this.subColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: subColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '+$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            style: TextStyle(fontSize: 10, color: subColor),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
