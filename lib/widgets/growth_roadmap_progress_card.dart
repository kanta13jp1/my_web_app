import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _PlanItem {
  final String label;
  final String? deadline; // 'yyyy年MM月dd日'
  final int target;
  const _PlanItem({
    required this.label,
    this.deadline,
    required this.target,
  });
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// ホーム画面最上部に表示する開発ロードマップ進捗カード。
///
/// 登録ユーザー数を `user_profiles` テーブルから取得し、
/// 短期・中期・長期計画および競合比較の進捗をプログレスバーで表示する。
class GrowthRoadmapProgressCard extends StatefulWidget {
  /// テスト用にクライアントを注入できるようにする
  final SupabaseClient? supabaseClient;

  const GrowthRoadmapProgressCard({super.key, this.supabaseClient});

  @override
  State<GrowthRoadmapProgressCard> createState() =>
      _GrowthRoadmapProgressCardState();
}

class _GrowthRoadmapProgressCardState
    extends State<GrowthRoadmapProgressCard> {
  static const _plans = [
    _PlanItem(
      label: '短期計画',
      deadline: '2026年06月30日',
      target: 100,
    ),
    _PlanItem(
      label: '中期計画',
      deadline: '2027年03月25日',
      target: 10000,
    ),
    _PlanItem(
      label: '長期計画',
      deadline: '2029年03月25日',
      target: 100000000,
    ),
    _PlanItem(
      label: 'vs NOTION',
      target: 100000000,
    ),
    _PlanItem(
      label: 'vs EverNote',
      target: 250000000,
    ),
  ];

  int _userCount = 0;
  bool _isLoading = true;

  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadUserCount();
  }

  Future<void> _loadUserCount() async {
    try {
      final response = await _supabase
          .from('user_profiles')
          .select('user_id')
          .count(CountOption.exact);
      if (!mounted) return;
      setState(() {
        _userCount = response.count;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
      key: const Key('growth_roadmap_progress_card'),
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
          Row(
            children: [
              const Icon(Icons.flag_outlined, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              const Text(
                'GROWTH ROADMAP',
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
                )
              else
                Text(
                  '現在 $_userCount 人',
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._plans.map(
            (plan) => _PlanProgressRow(
              plan: plan,
              currentCount: _userCount,
              textColor: textColor,
              subTextColor: subTextColor,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single plan row
// ---------------------------------------------------------------------------

class _PlanProgressRow extends StatelessWidget {
  final _PlanItem plan;
  final int currentCount;
  final Color textColor;
  final Color subTextColor;
  final bool isDark;

  const _PlanProgressRow({
    required this.plan,
    required this.currentCount,
    required this.textColor,
    required this.subTextColor,
    required this.isDark,
  });

  static const int _barSegments = 10;

  @override
  Widget build(BuildContext context) {
    final ratio =
        plan.target > 0 ? (currentCount / plan.target).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).toStringAsFixed(ratio >= 0.01 ? 1 : 2);
    final filledSegments = (ratio * _barSegments).round();
    final barText = _buildBarText(filledSegments);

    // Format numbers with commas
    final currentStr = _fmt(currentCount);
    final targetStr = _fmt(plan.target);

    // Colour: green when achieved, indigo otherwise
    final barColor = ratio >= 1.0
        ? const Color(0xFF22C55E)
        : const Color(0xFF6366F1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              if (plan.deadline != null)
                Text(
                  '目標期日 ${plan.deadline}',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '($currentStr / $targetStr ユーザー完了)',
                  style: TextStyle(fontSize: 11, color: subTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _SegmentedBar(
            filledSegments: filledSegments,
            totalSegments: _barSegments,
            filledColor: barColor,
            emptyColor: isDark
                ? const Color(0xFF2D3748)
                : const Color(0xFFE2E8F0),
            barText: barText,
            textColor: textColor,
          ),
        ],
      ),
    );
  }

  String _buildBarText(int filled) {
    const filled_ = '■';
    const empty_ = '□';
    return List.generate(
      _barSegments,
      (i) => i < filled ? filled_ : empty_,
    ).join();
  }

  String _fmt(int n) {
    if (n >= 100000000) {
      return '${(n / 100000000).toStringAsFixed(n % 100000000 == 0 ? 0 : 1)}億';
    }
    if (n >= 10000) {
      return '${(n / 10000).toStringAsFixed(n % 10000 == 0 ? 0 : 1)}万';
    }
    // Add comma separators for numbers < 10000
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// Segmented progress bar (visual + text fallback)
// ---------------------------------------------------------------------------

class _SegmentedBar extends StatelessWidget {
  final int filledSegments;
  final int totalSegments;
  final Color filledColor;
  final Color emptyColor;
  final String barText;
  final Color textColor;

  const _SegmentedBar({
    required this.filledSegments,
    required this.totalSegments,
    required this.filledColor,
    required this.emptyColor,
    required this.barText,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Visual segmented bar
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 10,
              child: Row(
                children: List.generate(totalSegments, (i) {
                  final isFilled = i < filledSegments;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: isFilled ? filledColor : emptyColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Text fallback (■□ style as requested)
        Text(
          barText,
          style: TextStyle(
            fontSize: 11,
            color: filledSegments > 0 ? filledColor : emptyColor,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
