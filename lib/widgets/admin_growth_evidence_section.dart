import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_growth_evidence.dart';

class AdminGrowthEvidenceSection extends StatelessWidget {
  final List<AdminAcquisitionCohortEvidence> acquisitionEvidence;
  final List<AdminPlanEconomics> planEconomics;

  const AdminGrowthEvidenceSection({
    super.key,
    this.acquisitionEvidence = const [],
    this.planEconomics = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AcquisitionCohortCard(evidence: acquisitionEvidence),
        const SizedBox(height: 16),
        _PlanEconomicsCard(plans: planEconomics),
      ],
    );
  }
}

class _AcquisitionCohortCard extends StatelessWidget {
  final List<AdminAcquisitionCohortEvidence> evidence;

  const _AcquisitionCohortCard({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('acquisition_cohort_evidence_card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '獲得元別コホート判断証拠',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'D7・D30継続率と有料転換率は、獲得元を同意済みユーザーに結び付けた集計だけで判断します。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (evidence.isEmpty)
              const _MissingEvidenceNotice(
                key: Key('acquisition_evidence_empty'),
                title: '判断保留：獲得元の集計信号がありません',
                detail: '必要入力：獲得元、獲得ユーザー、D7/D30対象・継続、有料転換ユーザー',
              )
            else ...[
              for (final row in evidence) ...[
                _AcquisitionEvidenceRow(evidence: row),
                if (row != evidence.last) const Divider(height: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AcquisitionEvidenceRow extends StatelessWidget {
  final AdminAcquisitionCohortEvidence evidence;

  const _AcquisitionEvidenceRow({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('acquisition_evidence_${evidence.source}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              evidence.source,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (evidence.aggregateSignalCount != null)
              _EvidencePill(
                label: '集計信号',
                value: '${evidence.aggregateSignalCount}',
              ),
            _EvidencePill(
              label: 'D7',
              value: _formatPercent(evidence.day7RetentionRate),
            ),
            _EvidencePill(
              label: 'D30',
              value: _formatPercent(evidence.day30RetentionRate),
            ),
            _EvidencePill(
              label: '有料転換',
              value: _formatPercent(evidence.paidConversionRate),
            ),
          ],
        ),
        if (!evidence.hasCompleteDecisionEvidence) ...[
          const SizedBox(height: 6),
          Text(
            '未取得：${evidence.missingInputs.join('、')}。集計信号はユーザーコホート人数として扱いません。',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanEconomicsCard extends StatelessWidget {
  final List<AdminPlanEconomics> plans;

  const _PlanEconomicsCard({required this.plans});

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('plan_economics_evidence_card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プラン別ユニットエコノミクス',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'AI・その他変動費、粗利、CAC、回収月数、解約率、LTVを実測入力だけで算出します。',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const _MissingEvidenceNotice(
                key: Key('plan_economics_empty'),
                title: '判断保留：プラン別の費用・顧客集計が未取得です',
                detail: '必要入力：プラン別MRR、課金顧客数、AI・その他変動費、獲得費、新規・月初・解約顧客数',
              )
            else ...[
              for (final plan in plans) ...[
                _PlanEconomicsRow(plan: plan),
                if (plan != plans.last) const Divider(height: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanEconomicsRow extends StatelessWidget {
  final AdminPlanEconomics plan;

  const _PlanEconomicsRow({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('plan_economics_${plan.planName}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.planName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _EvidencePill(
              label: 'AI変動費',
              value: _formatYen(plan.monthlyAiVariableCostYen),
            ),
            _EvidencePill(
              label: 'その他変動費',
              value: _formatYen(plan.monthlyOtherVariableCostYen),
            ),
            _EvidencePill(label: '粗利', value: _formatYen(plan.grossMarginYen)),
            _EvidencePill(
              label: '粗利率',
              value: _formatPercent(plan.grossMarginRate),
            ),
            _EvidencePill(
              label: 'CAC',
              value: _formatYen(plan.customerAcquisitionCostYen),
            ),
            _EvidencePill(
              label: '回収月数',
              value: _formatMonths(plan.paybackMonths),
            ),
            _EvidencePill(
              label: '月次解約率',
              value: _formatPercent(plan.monthlyChurnRate),
            ),
            _EvidencePill(
              label: 'LTV',
              value: _formatYen(plan.lifetimeValueYen),
            ),
          ],
        ),
        if (!plan.hasCompleteDecisionEvidence) ...[
          const SizedBox(height: 6),
          Text(
            plan.missingInputs.isEmpty
                ? '算出保留：0件または整合しない分母を確認してください。'
                : '未取得：${plan.missingInputs.join('、')}',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidencePill extends StatelessWidget {
  final String label;
  final String value;

  const _EvidencePill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MissingEvidenceNotice extends StatelessWidget {
  final String title;
  final String detail;

  const _MissingEvidenceNotice({
    super.key,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPercent(double? value) =>
    value == null ? '—' : '${(value * 100).toStringAsFixed(1)}%';

String _formatYen(double? value) => value == null
    ? '—'
    : NumberFormat.currency(
        locale: 'ja_JP',
        symbol: '¥',
        decimalDigits: 0,
      ).format(value);

String _formatMonths(double? value) =>
    value == null ? '—' : '${value.toStringAsFixed(1)}か月';
