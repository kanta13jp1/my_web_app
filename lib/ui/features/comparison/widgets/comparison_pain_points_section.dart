import 'package:flutter/material.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:my_web_app/ui/features/comparison/widgets/comparison_evidence_section.dart';

class ComparisonPainPointsSection extends StatelessWidget {
  const ComparisonPainPointsSection({
    super.key,
    required this.competitorName,
    required this.painPoints,
    required this.showLegacyClaims,
    required this.evidenceStatus,
    required this.otherEvidence,
  });

  static const sectionKey = Key('comparison-pain-points-section');

  static const Color _surfacePrimary = Color(0xFF141821);
  static const Color _borderColor = Color(0xFF283042);
  static const Color _textPrimary = Color(0xFFF5F7FB);
  static const Color _textSecondary = Color(0xFFA8B3C7);

  final String competitorName;
  final List<String> painPoints;
  final bool showLegacyClaims;
  final ComparisonEvidenceStatus evidenceStatus;
  final List<CompetitorClaimEvidence> otherEvidence;

  @override
  Widget build(BuildContext context) {
    if (!showLegacyClaims) {
      return ComparisonEvidenceSection(
        key: sectionKey,
        title: '根拠確認済みの比較情報',
        status: evidenceStatus,
        claims: otherEvidence,
      );
    }

    return Padding(
      key: sectionKey,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$competitorName を使っていて詰まりやすいポイント',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.72,
                  color: _textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '今のツールで十分そうに見えても、日々の運用ではここがボトルネックになりがちです。',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final items = <Widget>[
                    for (var i = 0; i < painPoints.length; i++)
                      Container(
                        width: compact ? double.infinity : null,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _surfacePrimary,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          '${i + 1}. ${painPoints[i]}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textSecondary,
                            height: 1.7,
                          ),
                        ),
                      ),
                  ];

                  if (compact) {
                    return Column(
                      children: items
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: item,
                            ),
                          )
                          .toList(),
                    );
                  }

                  return Row(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        Expanded(child: items[i]),
                        if (i != items.length - 1) const SizedBox(width: 12),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
