import 'package:flutter/material.dart';
import 'package:my_web_app/models/competitor_claim_evidence.dart';
import 'package:my_web_app/ui/features/comparison/view_models/comparison_evidence_view_model.dart';
import 'package:url_launcher/url_launcher.dart';

typedef EvidenceSourceLauncher = Future<bool> Function(Uri uri);

class ComparisonEvidenceStatusBanner extends StatelessWidget {
  const ComparisonEvidenceStatusBanner({
    super.key,
    required this.status,
    required this.verifiedCount,
    required this.withheldLegacyClaimCount,
  });

  final ComparisonEvidenceStatus status;
  final int verifiedCount;
  final int withheldLegacyClaimCount;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, color) = switch (status) {
      ComparisonEvidenceStatus.initial || ComparisonEvidenceStatus.loading => (
          Icons.hourglass_top_rounded,
          '比較根拠を確認中',
          '確認が終わるまで、従来の比較文は公開しません。',
          const Color(0xFF60A5FA),
        ),
      ComparisonEvidenceStatus.loaded when verifiedCount > 0 => (
          Icons.verified_rounded,
          '根拠確認済み $verifiedCount件',
          '根拠URLと確認日がある項目だけを表示しています。旧比較文 $withheldLegacyClaimCount件は公開保留です。',
          const Color(0xFF34D399),
        ),
      ComparisonEvidenceStatus.loaded => (
          Icons.visibility_off_rounded,
          '比較主張を公開保留中',
          '根拠URLと確認日が未登録のため、旧比較文 $withheldLegacyClaimCount件は表示していません。',
          const Color(0xFFFBBF24),
        ),
      ComparisonEvidenceStatus.unavailable => (
          Icons.cloud_off_rounded,
          '根拠データを取得できません',
          '取得失敗時に未検証のフォールバック文へ切り替えず、比較主張を公開保留にしています。',
          const Color(0xFFF87171),
        ),
    };

    return Container(
      key: const Key('comparison-evidence-status'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFFF5F7FB),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFB2BDD3),
                    fontSize: 13,
                    height: 1.6,
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

class ComparisonEvidenceSection extends StatelessWidget {
  const ComparisonEvidenceSection({
    super.key,
    required this.title,
    required this.status,
    required this.claims,
    this.sourceLauncher,
  });

  final String title;
  final ComparisonEvidenceStatus status;
  final List<CompetitorClaimEvidence> claims;
  final EvidenceSourceLauncher? sourceLauncher;

  @override
  Widget build(BuildContext context) {
    final body = switch (status) {
      ComparisonEvidenceStatus.initial ||
      ComparisonEvidenceStatus.loading =>
        const _EvidencePlaceholder(
          key: Key('comparison-evidence-loading'),
          icon: Icons.hourglass_top_rounded,
          message: '根拠を確認しています。確認中の比較主張は表示しません。',
        ),
      ComparisonEvidenceStatus.unavailable => const _EvidencePlaceholder(
          key: Key('comparison-evidence-unavailable'),
          icon: Icons.cloud_off_rounded,
          message: '根拠データを取得できないため、この比較主張は公開保留です。',
        ),
      ComparisonEvidenceStatus.loaded when claims.isEmpty =>
        const _EvidencePlaceholder(
          key: Key('comparison-evidence-empty'),
          icon: Icons.visibility_off_rounded,
          message: '根拠URLと確認日が未登録のため、この比較主張は公開保留です。',
        ),
      ComparisonEvidenceStatus.loaded => Column(
          key: const Key('comparison-evidence-claims'),
          children: [
            for (final claim in claims)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EvidenceClaimCard(
                  claim: claim,
                  sourceLauncher: sourceLauncher,
                ),
              ),
          ],
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF5F7FB),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '表示するすべての項目に参照元と確認日を併記します。確認日時点の記録であり、現在の価格や仕様を保証しません。',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFB2BDD3),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 16),
              body,
            ],
          ),
        ),
      ),
    );
  }
}

class _EvidenceClaimCard extends StatelessWidget {
  const _EvidenceClaimCard({required this.claim, required this.sourceLauncher});

  final CompetitorClaimEvidence claim;
  final EvidenceSourceLauncher? sourceLauncher;

  @override
  Widget build(BuildContext context) {
    final verified = claim.verifiedAt.toLocal();
    final verifiedLabel = '${verified.year.toString().padLeft(4, '0')}-'
        '${verified.month.toString().padLeft(2, '0')}-'
        '${verified.day.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12131E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3044)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            claim.claimText,
            style: const TextStyle(
              color: Color(0xFFF5F7FB),
              fontSize: 14,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '確認日: $verifiedLabel',
                style: const TextStyle(color: Color(0xFFB2BDD3), fontSize: 12),
              ),
              const Text(
                '確認日時点',
                style: TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                key: Key('comparison-evidence-source-${claim.claimKey}'),
                onPressed: () async {
                  final launcher = sourceLauncher ?? _launchSource;
                  await launcher(claim.sourceUri);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text(
                  claim.sourceUri.host,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<bool> _launchSource(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _EvidencePlaceholder extends StatelessWidget {
  const _EvidencePlaceholder({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12131E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3044)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFBBF24), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB2BDD3),
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
