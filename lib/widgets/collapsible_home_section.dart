// lib/widgets/collapsible_home_section.dart
//
// ホーム画面の縦長カードをアコーディオン形式で折り畳み可能にするラッパー。
// Windowsアプリ版#90 (2026-04-18): ユーザー要望「GROWTH ROADMAP など長い
// セクションを閉じられるようにしたい」への対応。
//
// 折り畳み状態は SharedPreferences に保存し、次回アクセス時も維持される。

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CollapsibleHomeSection extends StatefulWidget {
  /// 折り畳み状態の永続化キー。セクション毎にユニークにする。
  /// 例: 'home_section_growth_roadmap'
  final String storageKey;

  /// タイトル表示 (AppBar 風のヘッダー部に出す)
  final String title;

  /// 展開時に表示する子 widget (既存のカード等)
  final Widget child;

  /// 左側のアイコン (オプション)
  final IconData? icon;
  final Color? iconColor;

  /// 初期表示時の展開状態 (SharedPreferences に記録がない場合のみ適用)
  final bool initiallyExpanded;

  const CollapsibleHomeSection({
    super.key,
    required this.storageKey,
    required this.title,
    required this.child,
    this.icon,
    this.iconColor,
    this.initiallyExpanded = true,
  });

  @override
  State<CollapsibleHomeSection> createState() => _CollapsibleHomeSectionState();
}

class _CollapsibleHomeSectionState extends State<CollapsibleHomeSection>
    with SingleTickerProviderStateMixin {
  bool? _expanded;
  late final AnimationController _anim;

  String get _effectiveTitle {
    return switch (widget.storageKey) {
      'home_tier_recent' => '最近使った機能',
      'home_tier_popular' => '人気の機能',
      'home_tier_system' => '基本機能',
      'home_tier_pinned' => 'お気に入り（ピン止め）',
      'home_tier_new' => '最近追加された機能',
      'home_tier_recommend' => 'AIおすすめ機能',
      _ => widget.title,
    };
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(widget.storageKey);
    final initial = stored ?? widget.initiallyExpanded;
    if (!mounted) return;
    setState(() => _expanded = initial);
    if (initial) {
      _anim.value = 1.0;
    } else {
      _anim.value = 0.0;
    }
  }

  Future<void> _toggle() async {
    final current = _expanded ?? widget.initiallyExpanded;
    final next = !current;
    setState(() => _expanded = next);
    if (next) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.storageKey, next);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded ?? widget.initiallyExpanded;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.iconColor ?? const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _effectiveTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ),
                  RotationTransition(
                    turns: Tween<double>(begin: 0, end: 0.5).animate(_anim),
                    child: Icon(
                      Icons.expand_more,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, c) {
                return SizeTransition(
                  sizeFactor: _anim,
                  axisAlignment: -1,
                  child: c,
                );
              },
              child: Visibility(
                visible: expanded,
                maintainState: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
