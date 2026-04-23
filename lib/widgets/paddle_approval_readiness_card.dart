import 'package:flutter/material.dart';

import '../services/paddle_approval_readiness_service.dart';

class PaddleApprovalReadinessCard extends StatelessWidget {
  const PaddleApprovalReadinessCard({
    super.key,
    this.compact = false,
    this.touchesRegulatedData = false,
    this.onOpenLegalPage,
  });

  final bool compact;
  final bool touchesRegulatedData;
  final VoidCallback? onOpenLegalPage;

  @override
  Widget build(BuildContext context) {
    final report = const PaddleApprovalReadinessService().buildReport(
      touchesRegulatedData: touchesRegulatedData,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paddle 審査レディネス',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'コードより公開面の説明不足で止まりやすい項目を先に潰します。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              report.summary,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF334155),
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SummaryChip(
                  label: '総項目 ${report.totalItems}',
                  color: const Color(0xFF2563EB),
                ),
                _SummaryChip(
                  label: '必須 ${report.criticalItems}',
                  color: const Color(0xFFDC2626),
                ),
                _SummaryChip(
                  label: 'docs外 ${report.hiddenItems}',
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
            if (report.regulatedDataWarning != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.regulatedDataWarning!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF92400E),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '先に片付ける3項目',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            ...report.primaryActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 8),
              ...report.sections
                  .map((section) => _SectionCard(section: section)),
            ],
            if (onOpenLegalPage != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onOpenLegalPage,
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('法務ページで詳細を確認'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final PaddleApprovalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                paddleApprovalIconFor(section.kind),
                size: 18,
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(width: 8),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            section.description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: item.critical
                          ? const Color(0xFFFEE2E2)
                          : item.hiddenReviewFactor
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      item.critical
                          ? Icons.priority_high
                          : item.hiddenReviewFactor
                              ? Icons.visibility_outlined
                              : Icons.check,
                      size: 12,
                      color: item.critical
                          ? const Color(0xFFDC2626)
                          : item.hiddenReviewFactor
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.detail,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.4,
        ),
      ),
    );
  }
}
