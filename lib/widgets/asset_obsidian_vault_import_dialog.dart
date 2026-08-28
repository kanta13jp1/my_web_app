import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_web_app/models/asset_obsidian_vault_import.dart';
import 'package:my_web_app/services/asset_obsidian_vault_import_service.dart';
import 'package:my_web_app/utils/asset_obsidian_vault_picker.dart';

typedef AssetObsidianVaultPicker = Future<AssetObsidianVaultSelection?>
    Function();

class AssetObsidianVaultImportDialog extends StatefulWidget {
  const AssetObsidianVaultImportDialog({
    super.key,
    required this.existingBalances,
    this.existingSubscriptions = const <AssetObsidianExistingSubscription>[],
    required this.onApply,
    this.importService = const AssetObsidianVaultImportService(),
    this.pickVault = pickAssetObsidianVault,
    this.pickerSupported,
  });

  final List<AssetObsidianExistingBalance> existingBalances;
  final List<AssetObsidianExistingSubscription> existingSubscriptions;
  final Future<void> Function(AssetObsidianApplySelection selection) onApply;
  final AssetObsidianVaultImportService importService;
  final AssetObsidianVaultPicker pickVault;
  final bool? pickerSupported;

  @override
  State<AssetObsidianVaultImportDialog> createState() =>
      _AssetObsidianVaultImportDialogState();
}

class _AssetObsidianVaultImportDialogState
    extends State<AssetObsidianVaultImportDialog> {
  AssetObsidianVaultSelection? _selection;
  AssetObsidianImportPreview? _preview;
  Set<String> _selectedBalanceIds = <String>{};
  Set<String> _selectedCancellationIds = <String>{};
  bool _isSelecting = false;
  bool _isApplying = false;
  String? _error;

  bool get _isPickerSupported =>
      widget.pickerSupported ?? isAssetObsidianVaultPickerSupported;

  List<AssetObsidianImportCandidate> get _selectedCandidates {
    final preview = _preview;
    if (preview == null) return const <AssetObsidianImportCandidate>[];
    return preview.candidates
        .where((candidate) => _selectedBalanceIds.contains(candidate.id))
        .toList(growable: false);
  }

  List<AssetObsidianSubscriptionCancellationCandidate>
      get _selectedSubscriptionCancellations {
    final preview = _preview;
    if (preview == null) {
      return const <AssetObsidianSubscriptionCancellationCandidate>[];
    }
    return preview.subscriptionCancellations
        .where(
          (candidate) =>
              candidate.isDeletable &&
              _selectedCancellationIds.contains(candidate.id),
        )
        .toList(growable: false);
  }

  Future<void> _selectVault() async {
    setState(() {
      _isSelecting = true;
      _error = null;
    });
    try {
      final selection = await widget.pickVault();
      if (selection == null || !mounted) return;
      final preview = widget.importService.preview(
        files: selection.files,
        existingBalances: widget.existingBalances,
        existingSubscriptions: widget.existingSubscriptions,
      );
      setState(() {
        _selection = selection;
        _preview = preview;
        _selectedBalanceIds =
            preview.initiallySelected.map((candidate) => candidate.id).toSet();
        _selectedCancellationIds = preview
            .initiallySelectedSubscriptionCancellations
            .map((candidate) => candidate.id)
            .toSet();
      });
    } on AssetObsidianVaultPickerException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '保管庫を読み込めませんでした。ファイル構成を確認して再試行してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  Future<void> _confirmAndApply() async {
    final selectedBalances = _selectedCandidates;
    final selectedCancellations = _selectedSubscriptionCancellations;
    final selection = AssetObsidianApplySelection(
      balances: selectedBalances,
      subscriptionCancellations: selectedCancellations,
    );
    if (selection.totalCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_confirmationTitle(selection)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '残高は反映時点の値として保存し、使途不明金は自動生成しません。'
                  '解約済みサブスクは現在の定期固定費から削除しますが、過去の月次履歴・取引履歴は残します。',
                ),
                if (selectedBalances.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '残高',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
                for (final candidate in selectedBalances)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '・${candidate.accountName}: ${_formatYen(candidate.amount)}',
                    ),
                  ),
                if (selectedCancellations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    '削除するサブスク',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
                for (final candidate in selectedCancellations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '・${candidate.matchedSubscriptionName}: '
                      '${_formatYen(candidate.matchedMonthlyAmount ?? 0)}/月',
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('この内容で反映'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isApplying = true;
      _error = null;
    });
    try {
      await widget.onApply(selection);
      if (mounted) Navigator.of(context).pop(selection);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '選択内容の反映に失敗しました。通信状態を確認して再試行してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  String _confirmationTitle(AssetObsidianApplySelection selection) {
    final parts = <String>[
      if (selection.balances.isNotEmpty) '残高${selection.balances.length}件',
      if (selection.subscriptionCancellations.isNotEmpty)
        'サブスク${selection.subscriptionCancellations.length}件',
    ];
    return '${parts.join('・')}を反映しますか？';
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final selectedCount =
        _selectedCandidates.length + _selectedSubscriptionCancellations.length;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.folder_open, color: Color(0xFF7C3AED)),
          SizedBox(width: 10),
          Expanded(child: Text('Obsidian保管庫から資産情報を取込')),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
        child: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPrivacyNotice(),
                const SizedBox(height: 14),
                if (!_isPickerSupported)
                  const Text('この機能はChromeなどのWebブラウザ版で利用できます。')
                else
                  OutlinedButton.icon(
                    onPressed:
                        _isSelecting || _isApplying ? null : _selectVault,
                    icon: _isSelecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.create_new_folder_outlined),
                    label: Text(
                      _selection == null ? 'Obsidian保管庫を選択' : '別の保管庫を選択',
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildMessageBox(
                    icon: Icons.error_outline,
                    color: const Color(0xFFB91C1C),
                    text: _error!,
                  ),
                ],
                if (preview != null) ...[
                  const SizedBox(height: 16),
                  _buildPreviewHeader(preview),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (final warning in preview.warnings)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildMessageBox(
                          icon: Icons.info_outline,
                          color: const Color(0xFFB45309),
                          text: warning,
                        ),
                      ),
                  ],
                  const SizedBox(height: 12),
                  if (preview.candidates.isNotEmpty) ...[
                    const _PreviewSectionTitle(
                      icon: Icons.account_balance_wallet_outlined,
                      label: '残高の反映候補',
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          for (final candidate in preview.candidates)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildCandidate(
                                candidate,
                                compact: constraints.maxWidth < 680,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (preview.subscriptionCancellations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _PreviewSectionTitle(
                      icon: Icons.unsubscribe_outlined,
                      label: '解約済みサブスクの削除候補',
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) => Column(
                        children: [
                          for (final candidate
                              in preview.subscriptionCancellations)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildSubscriptionCancellationCandidate(
                                candidate,
                                compact: constraints.maxWidth < 680,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (preview.candidates.isEmpty &&
                      preview.subscriptionCancellations.isEmpty)
                    const Text('取込候補はありません。'),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isApplying ? null : () => Navigator.of(context).pop(),
          child: const Text('閉じる'),
        ),
        if (preview != null)
          FilledButton.icon(
            onPressed:
                selectedCount == 0 || _isApplying ? null : _confirmAndApply,
            icon: _isApplying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.preview_outlined),
            label: Text('選択した$selectedCount件を確認'),
          ),
      ],
    );
  }

  Widget _buildPrivacyNotice() => _buildMessageBox(
        icon: Icons.shield_outlined,
        color: const Color(0xFF047857),
        text: 'Markdown本文はこのブラウザ内だけで解析します。確認後に選択した口座名と残高、'
            'または照合済みサブスクIDだけを反映し、本文とローカルパスは保存しません。',
      );

  Widget _buildPreviewHeader(AssetObsidianImportPreview preview) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          Text(
            _selection?.vaultName ?? '選択した保管庫',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('Markdown ${preview.scannedFileCount}件'),
          Text('残高表 ${preview.recognizedFileCount}件'),
          Text('解約表 ${preview.recognizedCancellationFileCount}件'),
          Text('残高候補 ${preview.candidates.length}件'),
          Text('解約候補 ${preview.subscriptionCancellations.length}件'),
        ],
      ),
    );
  }

  Widget _buildCandidate(
    AssetObsidianImportCandidate candidate, {
    required bool compact,
  }) {
    final selected = _selectedBalanceIds.contains(candidate.id);
    final details = _candidateDetails(candidate);
    final checkbox = Checkbox(
      value: selected,
      onChanged: candidate.isImportable && !_isApplying
          ? (value) {
              setState(() {
                value == true
                    ? _selectedBalanceIds.add(candidate.id)
                    : _selectedBalanceIds.remove(candidate.id);
              });
            }
          : null,
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          candidate.accountName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (candidate.sourceAccountName != candidate.accountName)
          Text(
            '保管庫表記: ${candidate.sourceAccountName}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
      ],
    );
    final amount = Text(
      _formatYen(candidate.amount),
      textAlign: TextAlign.right,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        color: candidate.amount < 0
            ? const Color(0xFFB91C1C)
            : const Color(0xFF047857),
      ),
    );

    return Container(
      key: ValueKey('obsidian-candidate-${candidate.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: candidate.isImportable ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                checkbox,
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      name,
                      const SizedBox(height: 6),
                      amount,
                      const SizedBox(height: 5),
                      _buildStatus(candidate.status),
                      const SizedBox(height: 5),
                      Text(details, style: _detailStyle),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                checkbox,
                const SizedBox(width: 4),
                Expanded(flex: 4, child: name),
                Expanded(flex: 2, child: amount),
                const SizedBox(width: 12),
                _buildStatus(candidate.status),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: Text(details, style: _detailStyle)),
              ],
            ),
    );
  }

  Widget _buildSubscriptionCancellationCandidate(
    AssetObsidianSubscriptionCancellationCandidate candidate, {
    required bool compact,
  }) {
    final selected = _selectedCancellationIds.contains(candidate.id);
    final checkbox = Checkbox(
      value: selected,
      onChanged: candidate.isDeletable && !_isApplying
          ? (value) {
              setState(() {
                value == true
                    ? _selectedCancellationIds.add(candidate.id)
                    : _selectedCancellationIds.remove(candidate.id);
              });
            }
          : null,
    );
    final name = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          candidate.sourceSubscriptionName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        if (candidate.matchedSubscriptionName != null &&
            candidate.matchedSubscriptionName !=
                candidate.sourceSubscriptionName)
          Text(
            '登録名: ${candidate.matchedSubscriptionName}',
            style: _detailStyle,
          ),
      ],
    );
    final amount = candidate.matchedMonthlyAmount == null
        ? const SizedBox.shrink()
        : Text(
            '${_formatYen(candidate.matchedMonthlyAmount!)}/月',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w900,
            ),
          );
    final details = _subscriptionCancellationDetails(candidate);
    final status = _buildSubscriptionCancellationStatus(candidate.status);

    return Semantics(
      label: '${candidate.sourceSubscriptionName}、$details',
      child: Container(
        key: ValueKey('obsidian-cancellation-${candidate.id}'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: candidate.isDeletable
              ? const Color(0xFFFFFBEB)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            checkbox,
            const SizedBox(width: 4),
            Expanded(
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        name,
                        const SizedBox(height: 6),
                        amount,
                        const SizedBox(height: 5),
                        status,
                        const SizedBox(height: 5),
                        Text(details, style: _detailStyle),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(flex: 4, child: name),
                        Expanded(flex: 2, child: amount),
                        const SizedBox(width: 12),
                        status,
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: Text(details, style: _detailStyle),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _detailStyle =>
      const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4);

  Widget _buildStatus(AssetObsidianImportStatus status) {
    final (label, color) = switch (status) {
      AssetObsidianImportStatus.newAccount => ('新規', const Color(0xFF2563EB)),
      AssetObsidianImportStatus.update => ('更新', const Color(0xFF047857)),
      AssetObsidianImportStatus.unchanged => ('同額', const Color(0xFF64748B)),
      AssetObsidianImportStatus.stale => ('古い', const Color(0xFFB45309)),
      AssetObsidianImportStatus.conflict => ('競合', const Color(0xFFB91C1C)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSubscriptionCancellationStatus(
    AssetObsidianSubscriptionCancellationStatus status,
  ) {
    final (label, color) = switch (status) {
      AssetObsidianSubscriptionCancellationStatus.matched => (
          '削除候補',
          const Color(0xFFB45309),
        ),
      AssetObsidianSubscriptionCancellationStatus.notRegistered => (
          '未登録',
          const Color(0xFF64748B),
        ),
      AssetObsidianSubscriptionCancellationStatus.conflict => (
          '競合',
          const Color(0xFFB91C1C),
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  String _subscriptionCancellationDetails(
    AssetObsidianSubscriptionCancellationCandidate candidate,
  ) {
    final source = candidate.endedAt == null
        ? '保管庫: ${candidate.sourceStatus}'
        : '保管庫: ${candidate.sourceStatus} / ${candidate.endedAt}';
    if (candidate.status ==
        AssetObsidianSubscriptionCancellationStatus.notRegistered) {
      return '$source / 現在の登録なし（変更しません）';
    }
    if (candidate.status ==
        AssetObsidianSubscriptionCancellationStatus.conflict) {
      return '$source / 同名登録が複数: '
          '${candidate.conflictingSubscriptionNames.join(' / ')}';
    }
    return '$source / 過去履歴は保持';
  }

  String _candidateDetails(AssetObsidianImportCandidate candidate) {
    final date = DateFormat('yyyy/MM/dd').format(candidate.observedDate);
    if (candidate.status == AssetObsidianImportStatus.conflict) {
      return '$date に異なる残高: '
          '${candidate.conflictingAmounts.map(_formatYen).join(' / ')}';
    }
    if (candidate.existingAmount == null) return '保管庫確認日 $date';
    final currentDate = candidate.existingObservedDate == null
        ? ''
        : DateFormat('yyyy/MM/dd').format(candidate.existingObservedDate!);
    return '保管庫 $date / 現在 $currentDate '
        '${_formatYen(candidate.existingAmount!)}';
  }

  Widget _buildMessageBox({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}

class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

String _formatYen(double amount) =>
    '${amount < 0 ? '-' : ''}¥${NumberFormat('#,##0').format(amount.abs().round())}';
