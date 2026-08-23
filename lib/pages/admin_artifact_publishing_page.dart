import 'package:flutter/material.dart';

import '../models/artifact_publishing.dart';
import '../services/artifact_publishing_service.dart';
import '../view_models/artifact_publishing_view_model.dart';

class AdminArtifactPublishingPage extends StatefulWidget {
  const AdminArtifactPublishingPage({super.key, this.gateway});

  final ArtifactPublishingGateway? gateway;

  @override
  State<AdminArtifactPublishingPage> createState() =>
      _AdminArtifactPublishingPageState();
}

class _AdminArtifactPublishingPageState
    extends State<AdminArtifactPublishingPage> {
  late final ArtifactPublishingViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ArtifactPublishingViewModel(
      gateway: widget.gateway ?? ArtifactPublishingService(),
    )..addListener(_onChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI成果物 公開ループ'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _viewModel.loading ? null : _viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_viewModel.loading && !_viewModel.accessChecked) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_viewModel.authorized) {
      return _AccessDenied(error: _viewModel.error);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth >= 720 ? 32.0 : 16.0;
        return RefreshIndicator(
          onRefresh: _viewModel.load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 48),
            children: [
              const _SafetyBanner(),
              const SizedBox(height: 20),
              const _PublishingLoopDiagram(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text(
                    '候補成果物',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const Spacer(),
                  Text('${_viewModel.candidates.length}件'),
                ],
              ),
              if (_viewModel.error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: _viewModel.error!),
              ],
              const SizedBox(height: 12),
              if (_viewModel.candidates.isEmpty)
                const _EmptyCandidates()
              else
                ..._viewModel.candidates.map(
                  (candidate) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CandidateCard(
                      candidate: candidate,
                      working: _viewModel.workingCandidateId == candidate.id,
                      onTransition: (target) => _transition(candidate, target),
                      onReviewCheck: (check, status) =>
                          _reviewCheck(candidate, check, status),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _transition(
    ArtifactCandidate candidate,
    ArtifactStage target,
  ) async {
    String? rejectionReason;
    String? humanContributionSummary;
    _StageProductInput? stageProduct;
    if (target == ArtifactStage.rejected) {
      rejectionReason = await _textDecisionDialog(
        title: '候補を却下',
        message: '監査記録に残す却下理由を10文字以上で入力してください。',
        confirmLabel: '却下を記録',
        destructive: true,
        minimumLength: 10,
      );
      if (rejectionReason == null) return;
    } else if (target == ArtifactStage.approved) {
      humanContributionSummary = await _textDecisionDialog(
        title: '人手承認を記録',
        message: '構成・選択・編集・検証など、人間が加えた創作的な寄与を20文字以上で記録してください。'
            'この操作だけでは商品を公開しません。',
        confirmLabel: '寄与を記録して承認',
        minimumLength: 20,
        initialValue: candidate.humanContributionSummary,
      );
      if (humanContributionSummary == null) return;
    } else if (target == ArtifactStage.staged &&
        candidate.stage == ArtifactStage.approved) {
      stageProduct = await _stageProductDialog(candidate);
      if (stageProduct == null) return;
    } else if (target == ArtifactStage.published && !candidate.productActive) {
      _showMessage('商品を外部の承認済み手順で有効化した後に公開済みへ進めます。');
      return;
    }

    final succeeded = await _viewModel.transition(
      candidate,
      target,
      rejectionReason: rejectionReason,
      humanContributionSummary: humanContributionSummary,
      productId: stageProduct?.productId,
      intendedPriceJpy: stageProduct?.intendedPriceJpy,
      proposedStoragePath: stageProduct?.storagePath,
    );
    if (!mounted) return;
    _showMessage(succeeded ? 'ステージを更新しました。' : 'ステージ更新に失敗しました。');
  }

  Future<void> _reviewCheck(
    ArtifactCandidate candidate,
    ArtifactCheck check,
    ArtifactCheckStatus status,
  ) async {
    String? evidence;
    if (status != ArtifactCheckStatus.pending) {
      evidence = await _textDecisionDialog(
        title: '${check.labelJa}: ${status.labelJa}',
        message: '秘密値や個人情報そのものは貼らず、確認方法と根拠だけを記録してください。',
        confirmLabel: '検査結果を記録',
        minimumLength: 3,
      );
      if (evidence == null) return;
    }
    final succeeded = await _viewModel.reviewCheck(
      candidate,
      check,
      status,
      evidenceSummary: evidence,
    );
    if (!mounted) return;
    _showMessage(succeeded ? '検査結果を更新しました。' : '検査結果の更新に失敗しました。');
  }

  Future<String?> _textDecisionDialog({
    required String title,
    required String message,
    required String confirmLabel,
    required int minimumLength,
    bool destructive = false,
    String initialValue = '',
  }) =>
      showDialog<String>(
        context: context,
        builder: (_) => _TextDecisionDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          minimumLength: minimumLength,
          destructive: destructive,
          initialValue: initialValue,
        ),
      );

  Future<_StageProductInput?> _stageProductDialog(
    ArtifactCandidate candidate,
  ) =>
      showDialog<_StageProductInput>(
        context: context,
        builder: (_) => _StageProductDialog(candidate: candidate),
      );

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PublishingLoopDiagram extends StatelessWidget {
  const _PublishingLoopDiagram();

  static const _steps = [
    (Icons.file_open_outlined, '明示取込', 'ローカルでhash・リスク検査'),
    (Icons.rule_folder_outlined, '自動ゲート', '秘密情報・PIIをブロック'),
    (Icons.fact_check_outlined, '人手レビュー', '権利・同意・寄与を確認'),
    (Icons.inventory_2_outlined, '安全なステージ', '非公開Storage・価格を照合'),
    (Icons.publish_outlined, '明示公開', '別手順の承認後のみ有効化'),
    (Icons.history_outlined, '監査・改善', 'イベントを残し再取込へ'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: '明示取込、自動ゲート、人手レビュー、安全なステージ、明示公開、監査改善の循環',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('公開ループ', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '自動化は準備まで。公開権限と販売権限は人間が保持します。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    _LoopStep(step: _steps[index]),
                    if (index < _steps.length - 1)
                      Icon(Icons.arrow_forward, color: colors.primary),
                  ],
                  Icon(Icons.replay, color: colors.tertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoopStep extends StatelessWidget {
  const _LoopStep({required this.step});

  final (IconData, String, String) step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 152,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.$1, color: colors.primary),
          const SizedBox(height: 8),
          Text(step.$2, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(
            step.$3,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.working,
    required this.onTransition,
    required this.onReviewCheck,
  });

  final ArtifactCandidate candidate;
  final bool working;
  final ValueChanged<ArtifactStage> onTransition;
  final void Function(ArtifactCheck, ArtifactCheckStatus) onReviewCheck;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  candidate.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(label: Text(candidate.stage.labelJa)),
                Chip(
                  avatar: Icon(
                    candidate.allHardGatesSatisfied
                        ? Icons.verified_outlined
                        : Icons.pending_actions_outlined,
                    size: 18,
                  ),
                  label: Text(
                    '必須 ${candidate.satisfiedHardGateCount}/${candidate.hardGateCount}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${candidate.kind} • ${candidate.mimeType} • '
              '${_formatBytes(candidate.fileSizeBytes)}',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            SelectableText(
              'SHA-256 ${candidate.sha256}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 2),
            Text(
              '出所: ${candidate.sourceTools.isEmpty ? '未登録' : candidate.sourceTools.join(', ')}'
              ' / 商品: ${candidate.productName ?? candidate.productId ?? '未連携'}'
              '${candidate.productActive ? '（有効）' : ''}',
            ),
            if (candidate.humanContributionSummary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('人間の寄与: ${candidate.humanContributionSummary}'),
            ],
            if (candidate.proposedStoragePath != null) ...[
              const SizedBox(height: 4),
              Text(
                'ステージ: ¥${candidate.intendedPriceJpy ?? '-'} / '
                '${candidate.proposedStorageBucket}/${candidate.proposedStoragePath}',
              ),
            ],
            const SizedBox(height: 14),
            Text('必須チェック', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: candidate.checks
                  .map(
                    (check) => _CheckMenu(
                      check: check,
                      enabled: !working && check.canEditAt(candidate.stage),
                      onSelected: (status) => onReviewCheck(check, status),
                    ),
                  )
                  .toList(growable: false),
            ),
            if (candidate.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '却下理由: ${candidate.rejectionReason}',
                style: TextStyle(color: colors.error),
              ),
            ],
            const SizedBox(height: 16),
            if (working)
              const LinearProgressIndicator()
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in candidate.stage.transitionTargets)
                    target.index > candidate.stage.index ||
                            candidate.stage == ArtifactStage.rejected
                        ? FilledButton.tonalIcon(
                            onPressed: () => onTransition(target),
                            icon: Icon(
                              target == ArtifactStage.intake
                                  ? Icons.replay
                                  : Icons.arrow_forward,
                            ),
                            label: Text(
                              _transitionLabel(candidate.stage, target),
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () => onTransition(target),
                            icon: const Icon(Icons.undo),
                            label: Text('${target.labelJa}へ戻す'),
                          ),
                  if (candidate.stage.canReject)
                    TextButton.icon(
                      onPressed: () => onTransition(ArtifactStage.rejected),
                      icon: const Icon(Icons.block),
                      label: const Text('却下'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _transitionLabel(ArtifactStage from, ArtifactStage target) {
    if (from == ArtifactStage.humanReview && target == ArtifactStage.approved) {
      return '人手承認を記録';
    }
    if (from == ArtifactStage.rejected && target == ArtifactStage.intake) {
      return '再取込して再試行';
    }
    return '${target.labelJa}へ進む';
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }
}

class _CheckMenu extends StatelessWidget {
  const _CheckMenu({
    required this.check,
    required this.enabled,
    required this.onSelected,
  });

  final ArtifactCheck check;
  final bool enabled;
  final ValueChanged<ArtifactCheckStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (check.status) {
      ArtifactCheckStatus.pending => colors.outline,
      ArtifactCheckStatus.passed => colors.primary,
      ArtifactCheckStatus.failed => colors.error,
      ArtifactCheckStatus.notApplicable => colors.tertiary,
    };
    return PopupMenuButton<ArtifactCheckStatus>(
      enabled: enabled,
      tooltip: '${check.labelJa}の結果を記録',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final status in ArtifactCheckStatus.values)
          if (status != ArtifactCheckStatus.notApplicable ||
              check.allowsNotApplicable)
            PopupMenuItem(value: status, child: Text(status.labelJa)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('${check.labelJa}: ${check.status.labelJa}'),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '管理者専用。ここでは候補・検査・ステージだけを更新します。'
              '料金作成、課金、Storageアップロード、商品削除、is_active=true、'
              'デプロイは実行しません。',
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                '管理者のみ利用できます',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Text(message),
      );
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '候補はありません。ローカル取込ヘルパーでmanifestを作成し、'
            '承認済みの管理手順で取り込んでください。',
          ),
        ),
      );
}

class _TextDecisionDialog extends StatefulWidget {
  const _TextDecisionDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.minimumLength,
    required this.destructive,
    required this.initialValue,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final int minimumLength;
  final bool destructive;
  final String initialValue;

  @override
  State<_TextDecisionDialog> createState() => _TextDecisionDialogState();
}

class _TextDecisionDialogState extends State<_TextDecisionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('decision-evidence'),
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '根拠・説明',
                  helperText: '${widget.minimumLength}文字以上',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          onPressed: value.length >= widget.minimumLength
              ? () => Navigator.pop(context, value)
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _StageProductDialog extends StatefulWidget {
  const _StageProductDialog({required this.candidate});

  final ArtifactCandidate candidate;

  @override
  State<_StageProductDialog> createState() => _StageProductDialogState();
}

class _StageProductDialogState extends State<_StageProductDialog> {
  late final TextEditingController _productIdController;
  late final TextEditingController _priceController;
  late final TextEditingController _pathController;

  @override
  void initState() {
    super.initState();
    _productIdController = TextEditingController(
      text: widget.candidate.productId ?? '',
    );
    _priceController = TextEditingController(
      text: widget.candidate.intendedPriceJpy?.toString() ?? '',
    );
    _pathController = TextEditingController(
      text: widget.candidate.proposedStoragePath ?? '',
    );
  }

  @override
  void dispose() {
    _productIdController.dispose();
    _priceController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productId = _productIdController.text.trim();
    final price = int.tryParse(_priceController.text.trim());
    final storagePath = _pathController.text.trim();
    final pathSegments = storagePath.split('/');
    final validPath = storagePath.isNotEmpty &&
        !storagePath.startsWith('/') &&
        !storagePath.endsWith('/') &&
        !pathSegments.contains('..');
    final valid =
        productId.isNotEmpty && price != null && price >= 50 && validPath;

    return AlertDialog(
      title: const Text('非公開の商品をステージ'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '既に作成済みで is_active=false の商品IDと、価格・非公開Storageの'
                '照合値を入力します。この画面から商品作成や公開は行いません。',
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('stage-product-id'),
                controller: _productIdController,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '商品ID',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('stage-price-jpy'),
                controller: _priceController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '販売価格（円）',
                  helperText: '50円以上',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('stage-storage-path'),
                controller: _pathController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '非公開Storageパス',
                  prefixText: 'product-downloads/',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                    context,
                    _StageProductInput(
                      productId: productId,
                      intendedPriceJpy: price,
                      storagePath: storagePath,
                    ),
                  )
              : null,
          child: const Text('照合情報を保存してステージ'),
        ),
      ],
    );
  }
}

class _StageProductInput {
  const _StageProductInput({
    required this.productId,
    required this.intendedPriceJpy,
    required this.storagePath,
  });

  final String productId;
  final int intendedPriceJpy;
  final String storagePath;
}
