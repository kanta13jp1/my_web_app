import 'package:flutter/material.dart';

import '../models/asset_income_source_evidence.dart';

/// Read-only source comparison. Decisions affect only the parent's memory session.
class AssetIncomeReconciliationSection extends StatelessWidget {
  const AssetIncomeReconciliationSection({
    super.key,
    required this.projection,
    required this.busy,
    required this.onReload,
    required this.onDecision,
    required this.onClear,
    required this.onPage,
    this.memoryDecisionCount = 0,
  });

  final IncomeEvidenceProjection projection;
  final bool busy;
  final VoidCallback onReload;
  final void Function(
    IncomeSourceRecord,
    IncomeSourceRecord,
    IncomeRelationship,
  ) onDecision;
  final VoidCallback onClear;
  final ValueChanged<int> onPage;
  final int memoryDecisionCount;

  static const sourceLabels = {
    IncomeSourceKind.flow: '収入フロー',
    IncomeSourceKind.receivedPlan: '受取済み計画',
    IncomeSourceKind.payslip: '給与明細',
    IncomeSourceKind.salaryIncome: '給与会計',
  };

  static String issueLabel(IncomeEvidenceProblem problem) => switch (problem) {
        IncomeEvidenceProblem.ownerMismatch => '本人のデータ範囲を確認できない記録があります',
        IncomeEvidenceProblem.currencyMismatch => '通貨が一致していません',
        IncomeEvidenceProblem.missingRecordId => '元の記録IDがありません',
        IncomeEvidenceProblem.invalidDate => '元の日付を確認してください',
        IncomeEvidenceProblem.invalidAmount => '元の金額を確認してください',
        IncomeEvidenceProblem.sameIdConflict => '同じIDの保存値が異なります',
        IncomeEvidenceProblem.missingPayslipTarget => '参照する給与明細が未確認です',
        IncomeEvidenceProblem.eventAmountConflict => '同じ収入として対応する金額が異なります',
        IncomeEvidenceProblem.eventDateConflict => '対応する日付が異なります',
        IncomeEvidenceProblem.eventDatePrecisionConflict => '日付の粒度が異なります',
        IncomeEvidenceProblem.staleDecision => '元記録が変わったため再確認が必要です',
        IncomeEvidenceProblem.contradictoryDecision => '同一・別件の判断が矛盾しています',
        IncomeEvidenceProblem.missingRelationship => '出典間の対応が未記録です',
        IncomeEvidenceProblem.inputLimitExceeded => '対象が多いため期間や出典を絞ってください',
        IncomeEvidenceProblem.readUnconfirmed => '読み取り未確認のため合算は未計算です',
        IncomeEvidenceProblem.readLimitReached => '取得件数の上限に達したため、全体の合算は未計算です',
      };

  Widget recordTile(IncomeSourceRecord record) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '${sourceLabels[record.kind]} / ID: ${record.id ?? '未記録'}\n'
          '${record.date}（${record.datePrecision == IncomeDatePrecision.day ? '日付のみ' : '時刻付き'}） / '
          '${record.currency} ${record.observedAmount ?? record.amount} '
          '${record.evidenceOnly ? '（対応の確認専用・独立加算なし）' : ''}',
        ),
      );

  Future<void> confirm(
    BuildContext context,
    IncomeSourceRecord left,
    IncomeSourceRecord right,
    IncomeRelationship relationship,
  ) async {
    final same = relationship == IncomeRelationship.sameEvent;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(same ? 'この画面で同じ収入として照合' : 'この画面で別件として照合'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              recordTile(left),
              const Divider(),
              recordTile(right),
              const Text(
                'この画面内の記録集計にだけ反映します。金融記録や口座残高、入金確認は変更しません。再起動するとこの照合は失われます。',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('この画面で照合する'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      onDecision(left, right, relationship);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unresolved = projection.issues
        .where(
          (issue) => issue.problem == IncomeEvidenceProblem.missingRelationship,
        )
        .toList();
    final conflicts = projection.issues
        .where(
          (issue) =>
              issue.problem == IncomeEvidenceProblem.contradictoryDecision ||
              issue.problem == IncomeEvidenceProblem.sameIdConflict ||
              issue.problem == IncomeEvidenceProblem.currencyMismatch ||
              issue.problem == IncomeEvidenceProblem.eventAmountConflict ||
              issue.problem == IncomeEvidenceProblem.eventDateConflict ||
              issue.problem == IncomeEvidenceProblem.eventDatePrecisionConflict,
        )
        .length;
    final byKey = {
      for (final record in projection.records)
        if (record.key != null) record.key!: record,
    };
    final ready = !busy &&
        !projection.issues.any(
          (issue) => issue.problem != IncomeEvidenceProblem.missingRelationship,
        );
    return ExpansionTile(
      key: const Key('asset_income_reconciliation'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        projection.combinedRecordedTotal == null ? '収入の照合が必要' : '記録上の収入を照合済み',
      ),
      subtitle: Text(
        '未照合 ${projection.unresolvedRelationshipCount ?? '確認待ち'}組 / 矛盾 $conflicts件',
      ),
      children: [
        const Text('出典別の記録計は互いに重なる場合があるため、足し合わせた確定収入ではありません。'),
        if (memoryDecisionCount > 0)
          Text('この画面で本人確認・未保存 $memoryDecisionCount件'),
        for (final event in projection.matchedEvents.take(20)) ...[
          if (event.evidence.contains(IncomeLinkEvidence.existingPayslipFk))
            const Text('既存明細IDで照合'),
          if (event.evidence.contains(IncomeLinkEvidence.sessionConfirmation))
            const Text('この画面で同じ収入として本人確認・未保存'),
          for (final key in event.recordKeys)
            if (byKey.containsKey(key)) recordTile(byKey[key]!),
        ],
        if (projection.matchedEvents.length > 20)
          Text('照合済み${projection.matchedEvents.length}組のうち先頭20組を表示しています。'),
        for (final entry in projection.sourceRecordedTotals.entries)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${sourceLabels[entry.key]}記録計: ${entry.value == null ? '未計算' : 'JPY ${entry.value}'}',
            ),
          ),
        Text(
          '照合済みイベント小計: ${projection.matchedEventSubtotal == null ? '照合済み対象なし' : 'JPY ${projection.matchedEventSubtotal}（全体計とは限りません）'}',
        ),
        for (final problem in projection.issues
            .map((issue) => issue.problem)
            .where(
              (problem) => problem != IncomeEvidenceProblem.missingRelationship,
            )
            .toSet())
          Text(issueLabel(problem)),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy ? null : onReload,
              child: Text(busy ? '再読込中' : '既存明細を再読込'),
            ),
            TextButton(
              onPressed: busy ? null : onClear,
              child: const Text('この画面の照合を取り消す'),
            ),
          ],
        ),
        for (final issue in unresolved) ...[
          if (issue.recordKeys.every(byKey.containsKey))
            Builder(
              builder: (context) {
                final left = byKey[issue.recordKeys.first]!;
                final leftGroup = projection.matchedEvents
                        .where((event) => event.recordKeys.contains(left.key))
                        .firstOrNull
                        ?.recordKeys
                        .toSet() ??
                    {left.key!};
                final rightKey = issue.recordKeys
                    .where((key) => !leftGroup.contains(key))
                    .firstOrNull;
                if (rightKey == null) return const SizedBox.shrink();
                final right = byKey[rightKey]!;
                final compatible = left.currency == right.currency &&
                    left.amount >= 0 &&
                    left.amount == right.amount &&
                    left.date == right.date &&
                    left.datePrecision == right.datePrecision;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('出典間の対応が未記録です'),
                        for (final key in issue.recordKeys)
                          recordTile(byKey[key]!),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton(
                              onPressed: ready && compatible
                                  ? () => confirm(
                                        context,
                                        left,
                                        right,
                                        IncomeRelationship.sameEvent,
                                      )
                                  : null,
                              child: const Text('同じ収入として照合'),
                            ),
                            OutlinedButton(
                              onPressed: ready
                                  ? () => confirm(
                                        context,
                                        left,
                                        right,
                                        IncomeRelationship.distinctEvents,
                                      )
                                  : null,
                              child: const Text('別件として照合'),
                            ),
                          ],
                        ),
                        if (!compatible)
                          const Text(
                            '金額・通貨・日付が一致しないため、同じ収入として自動合算できません。元の記録を確認してください。',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
        if (projection.unresolvedRelationshipCount != null &&
            projection.unresolvedRelationshipCount! > 0)
          Wrap(
            spacing: 8,
            children: [
              Text(
                '照合対象 ${projection.relationshipPage + 1}ページ / 合計${projection.unresolvedRelationshipCount}組',
              ),
              TextButton(
                onPressed: projection.relationshipPage > 0
                    ? () => onPage(projection.relationshipPage - 1)
                    : null,
                child: const Text('前の照合対象'),
              ),
              TextButton(
                onPressed: (projection.relationshipPage + 1) *
                            projection.relationshipPageSize <
                        projection.unresolvedRelationshipCount!
                    ? () => onPage(projection.relationshipPage + 1)
                    : null,
                child: const Text('次の照合対象'),
              ),
            ],
          ),
        if (unresolved.isEmpty)
          for (final record in projection.records
              .where(
                (record) => !projection.matchedEvents
                    .any((event) => event.recordKeys.contains(record.key)),
              )
              .take(20))
            recordTile(record),
        if (unresolved.isEmpty && projection.records.length > 20)
          Text('元記録${projection.records.length}件のうち先頭20件を表示しています。'),
      ],
    );
  }
}
