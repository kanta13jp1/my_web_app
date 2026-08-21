import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/asset_liability_workbook.dart';
import '../models/asset_subscription_statement_scan.dart';
import '../view_models/asset_subscription_statement_scan_view_model.dart';

class AssetSubscriptionStatementScanDialog extends StatefulWidget {
  const AssetSubscriptionStatementScanDialog({
    super.key,
    required this.viewModel,
    required this.sourceAccountNames,
    required this.onImport,
  });

  final AssetSubscriptionStatementScanViewModel viewModel;
  final Map<String, String> sourceAccountNames;
  final void Function(List<AssetRecurringFixedCost> costs) onImport;

  @override
  State<AssetSubscriptionStatementScanDialog> createState() =>
      _AssetSubscriptionStatementScanDialogState();
}

class _AssetSubscriptionStatementScanDialogState
    extends State<AssetSubscriptionStatementScanDialog> {
  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  void _importSelected() {
    final costs = widget.viewModel.buildSelectedCosts();
    if (costs.isEmpty) return;
    widget.onImport(costs);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: media.height - 32,
          minHeight: media.height < 640 ? media.height - 32 : 560,
        ),
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                fileName: widget.viewModel.analyzedFileName,
                onClose: widget.viewModel.isAnalyzing
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(context)),
              const Divider(height: 1),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final vm = widget.viewModel;
    if (vm.isAnalyzing) {
      return const _AnalyzingState();
    }
    if (!vm.hasResults) {
      return _UploadState(
        errorMessage: vm.errorMessage,
        onPick: vm.pickAndAnalyze,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final summary = _SummaryPanel(
          viewModel: vm,
          sourceAccountNames: widget.sourceAccountNames,
        );
        final candidates = _CandidateList(viewModel: vm);
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 280, child: summary),
              const VerticalDivider(width: 1),
              Expanded(child: candidates),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summary,
            const Divider(height: 1),
            Expanded(child: candidates),
          ],
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    final vm = widget.viewModel;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          if (vm.hasResults)
            TextButton.icon(
              key: const Key('subscription_statement_rescan'),
              onPressed: vm.isAnalyzing ? null : vm.pickAndAnalyze,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('別の画像を解析'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          if (vm.hasResults)
            FilledButton.icon(
              key: const Key('subscription_statement_import'),
              onPressed: vm.selectedCount == 0 ? null : _importSelected,
              icon: const Icon(Icons.playlist_add_check),
              label: Text('${vm.selectedCount}件を棚卸しに追加'),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.fileName, required this.onClose});

  final String? fileName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Icon(
            Icons.document_scanner_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'カード明細からサブスク棚卸し',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (fileName != null)
                  Text(
                    fileName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '閉じる',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _UploadState extends StatelessWidget {
  const _UploadState({required this.errorMessage, required this.onPick});

  final String? errorMessage;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 44,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '支払い明細のキャプチャーを1枚選ぶだけ',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'サービス名・金額・請求周期を抽出し、月額換算と年間合計を作ります。'
                '利用頻度は明細だけでは分からないため、残す／保留／解約候補は自分で確認します。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Material(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('subscription_statement_pick'),
                onPressed: onPick,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('明細画像を選んで解析'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'PNG・JPEG・WebP / 4MB以下。画像はAI解析時だけ送信し、アプリのStorageやDBには保存しません。'
                      'カード番号・名義・住所・生のOCR全文も保存しません。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyzingState extends StatelessWidget {
  const _AnalyzingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(),
              const SizedBox(height: 20),
              Text('サブスク候補を抽出しています', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                '金額や周期は解析後に確認・修正できます。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.viewModel,
    required this.sourceAccountNames,
  });

  final AssetSubscriptionStatementScanViewModel viewModel;
  final Map<String, String> sourceAccountNames;
  static final NumberFormat _yen = NumberFormat('#,##0');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '集計',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _Metric(label: '選択中', value: '${viewModel.selectedCount}件'),
          _Metric(
            label: '月額換算',
            value: '¥${_yen.format(viewModel.selectedMonthlyTotal)}',
          ),
          _Metric(
            label: '年間合計',
            value: '¥${_yen.format(viewModel.selectedAnnualTotal)}',
          ),
          if (viewModel.cancelCandidateMonthlySavings > 0)
            _Metric(
              label: '解約候補の月額',
              value: '¥${_yen.format(viewModel.cancelCandidateMonthlySavings)}',
              valueColor: scheme.error,
            ),
          if (viewModel.duplicateCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '登録済み ${viewModel.duplicateCount}件は選択から外しました。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text('支払い元（任意）', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            key: ValueKey(viewModel.sourceAccountId),
            initialValue: viewModel.sourceAccountId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('あとで設定'),
              ),
              for (final entry in sourceAccountNames.entries)
                DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: viewModel.setSourceAccountId,
          ),
          const SizedBox(height: 12),
          Text(
            '年払いは請求額を12分割した月額換算で登録します。実際の更新日は登録後に編集できます。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({required this.viewModel});

  final AssetSubscriptionStatementScanViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('subscription_statement_candidates'),
      padding: const EdgeInsets.all(12),
      itemCount: viewModel.reviews.length,
      itemBuilder: (context, index) => _CandidateCard(
        review: viewModel.reviews[index],
        onSelected: (value) =>
            viewModel.setSelected(viewModel.reviews[index].candidate.id, value),
        onDecision: (value) =>
            viewModel.setDecision(viewModel.reviews[index].candidate.id, value),
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.review,
    required this.onSelected,
    required this.onDecision,
  });

  final AssetSubscriptionStatementCandidateReview review;
  final ValueChanged<bool> onSelected;
  final ValueChanged<AssetSubscriptionReviewDecision> onDecision;
  static final NumberFormat _yen = NumberFormat('#,##0');

  String _cycleLabel(AssetSubscriptionBillingCycle cycle) => switch (cycle) {
        AssetSubscriptionBillingCycle.monthly => '月払い',
        AssetSubscriptionBillingCycle.annual => '年払い',
        AssetSubscriptionBillingCycle.unknown => '周期要確認',
      };

  @override
  Widget build(BuildContext context) {
    final candidate = review.candidate;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: Key('subscription_statement_candidate_${candidate.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: review.selected,
              onChanged: review.alreadyRegistered
                  ? null
                  : (value) => onSelected(value ?? false),
              title: Text(
                candidate.serviceName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${_cycleLabel(candidate.billingCycle)}・請求 ¥${_yen.format(candidate.chargedAmountJpy)}'
                '・月額換算 ¥${_yen.format(candidate.monthlyEquivalentJpy)}',
              ),
              secondary: review.alreadyRegistered
                  ? const Chip(label: Text('登録済み'))
                  : null,
            ),
            if (candidate.evidence.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40, bottom: 8),
                child: Text(
                  candidate.evidence,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: DropdownButtonFormField<AssetSubscriptionReviewDecision>(
                key: ValueKey('${candidate.id}_${review.decision.name}'),
                initialValue: review.decision,
                decoration: const InputDecoration(
                  labelText: '棚卸し判定',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: AssetSubscriptionReviewDecision.keep,
                    child: Text('残す'),
                  ),
                  DropdownMenuItem(
                    value: AssetSubscriptionReviewDecision.hold,
                    child: Text('保留'),
                  ),
                  DropdownMenuItem(
                    value: AssetSubscriptionReviewDecision.cancelCandidate,
                    child: Text('解約候補'),
                  ),
                ],
                onChanged: review.alreadyRegistered
                    ? null
                    : (value) {
                        if (value != null) onDecision(value);
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
