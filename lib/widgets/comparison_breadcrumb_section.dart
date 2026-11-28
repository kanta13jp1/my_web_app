import 'package:flutter/material.dart';

/// 競合比較ページ上部のパンくずナビゲーションセクション。
class ComparisonBreadcrumbSection extends StatelessWidget {
  const ComparisonBreadcrumbSection({
    super.key,
    required this.emoji,
    required this.name,
    this.onHomeTap,
    this.onCompetitorsTap,
  });

  final String emoji;
  final String name;
  final VoidCallback? onHomeTap;
  final VoidCallback? onCompetitorsTap;

  static const Color _textSecondary = Color(0xFFB2BDD3);
  static const Color _textMuted = Color(0xFF7E8AA6);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: onHomeTap ?? () => Navigator.of(context).pushNamed('/'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '自分株式会社',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const Text(
                '/',
                style: TextStyle(fontSize: 12, color: _textMuted, height: 1.5),
              ),
              InkWell(
                onTap: onCompetitorsTap ??
                    () => Navigator.of(context).pushNamed('/competitors'),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '競合比較',
                    style: TextStyle(
                      fontSize: 12,
                      color: _textMuted,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const Text(
                '/',
                style: TextStyle(fontSize: 12, color: _textMuted, height: 1.5),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '$emoji $name',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
