import 'package:flutter/material.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_evidence_section.dart';

class ComparisonHeroSection extends StatelessWidget {
  const ComparisonHeroSection({
    super.key,
    required this.competitorName,
    required this.emoji,
    required this.searchKeyword,
    required this.accentColor,
    required this.hasImportSupport,
    required this.evidenceStatus,
    required this.verifiedEvidenceCount,
    required this.withheldLegacyClaimCount,
    required this.primaryButton,
    required this.secondaryButton,
  });

  static const sectionKey = Key('comparison-hero-section');

  static const Color _pageBackground = Color(0xFF0A0D14);
  static const Color _surfacePrimary = Color(0xFF141821);
  static const Color _surfaceSecondary = Color(0xFF1A202C);
  static const Color _surfaceMuted = Color(0xFF222A3A);
  static const Color _borderColor = Color(0xFF283042);
  static const Color _textPrimary = Color(0xFFF5F7FB);
  static const Color _textSecondary = Color(0xFFA8B3C7);
  static const Color _textMuted = Color(0xFF7B889E);
  static const Color _indigo = Color(0xFF3D5AFE);
  static const Color _orange = Color(0xFFFF6B35);

  final String competitorName;
  final String emoji;
  final String searchKeyword;
  final Color accentColor;
  final bool hasImportSupport;
  final ComparisonEvidenceStatus evidenceStatus;
  final int verifiedEvidenceCount;
  final int withheldLegacyClaimCount;
  final Widget primaryButton;
  final Widget secondaryButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: sectionKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Container(
            decoration: BoxDecoration(
              color: _surfacePrimary,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.26),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.15),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _TagPill(
                          icon: Icons.compare_arrows_rounded,
                          label: '294社比較',
                          backgroundColor: accentColor.withValues(alpha: 0.18),
                          foregroundColor: _textPrimary,
                        ),
                        _TagPill(
                          icon: Icons.search_rounded,
                          label: searchKeyword,
                          backgroundColor: _surfaceMuted,
                          foregroundColor: _textSecondary,
                        ),
                        if (hasImportSupport)
                          _TagPill(
                            icon: Icons.publish_rounded,
                            label: 'インポート対応',
                            backgroundColor: _orange.withValues(alpha: 0.18),
                            foregroundColor: _textPrimary,
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      '$emoji $competitorName の代わりに\n自分株式会社を使う',
                      style: const TextStyle(
                        fontFamily: 'NotoSansJP',
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.96,
                        color: _textPrimary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '公開する比較情報は、根拠URLと確認日を持つ項目だけに限定しています。',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textSecondary,
                        height: 1.75,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ComparisonEvidenceStatusBanner(
                      status: evidenceStatus,
                      verifiedCount: verifiedEvidenceCount,
                      withheldLegacyClaimCount: withheldLegacyClaimCount,
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: [
                        _MetricCard(
                          icon: Icons.verified_rounded,
                          label: '根拠確認済み',
                          value: '$verifiedEvidenceCount件',
                          accent: accentColor,
                        ),
                        _MetricCard(
                          icon: Icons.visibility_off_rounded,
                          label: '旧比較文の公開保留',
                          value: '$withheldLegacyClaimCount件',
                          accent: _indigo,
                        ),
                        _MetricCard(
                          icon: hasImportSupport
                              ? Icons.move_down_rounded
                              : Icons.timer_rounded,
                          label: hasImportSupport ? '移行方法' : '開始時間',
                          value: hasImportSupport ? 'データ引継ぎ可' : '30秒で開始',
                          accent: _orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (compact)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          primaryButton,
                          const SizedBox(height: 12),
                          secondaryButton,
                        ],
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          primaryButton,
                          secondaryButton,
                        ],
                      ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _surfaceSecondary,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _borderColor),
                      ),
                      child: const Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _BenefitPill(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'タスク・ノート・習慣を横断',
                          ),
                          _BenefitPill(
                            icon: Icons.savings_outlined,
                            label: '無料で比較しながら移行',
                          ),
                          _BenefitPill(
                            icon: Icons.psychology_alt_outlined,
                            label: 'AIが今日の最優先を整理',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 170),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ComparisonHeroSection._surfaceSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: ComparisonHeroSection._textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ComparisonHeroSection._textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitPill extends StatelessWidget {
  const _BenefitPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ComparisonHeroSection._pageBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ComparisonHeroSection._borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: ComparisonHeroSection._textSecondary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: ComparisonHeroSection._textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
