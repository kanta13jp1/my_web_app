import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/design_tokens.dart';
import '../domain/video_studio_models.dart';
import '../view_models/video_studio_view_model.dart';

class VideoStudioPage extends StatelessWidget {
  const VideoStudioPage({super.key});

  static const double _wideBreakpoint = 980;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<VideoStudioViewModel>();
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        title: const Text('AI動画スタジオ'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: () => viewModel.load(currentUri: Uri.base),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return switch (viewModel.loadStatus) {
              VideoStudioLoadStatus.initial ||
              VideoStudioLoadStatus.loading =>
                const Center(
                  child: CircularProgressIndicator(color: DesignTokens.orange),
                ),
              VideoStudioLoadStatus.failure => _LoadFailure(
                  viewModel: viewModel,
                ),
              VideoStudioLoadStatus.ready => LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= _wideBreakpoint;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(DesignTokens.space20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _Hero(),
                              const SizedBox(height: DesignTokens.space16),
                              if (viewModel.noticeMessage != null)
                                _Notice(
                                  key: const Key('video-studio-notice'),
                                  message: viewModel.noticeMessage!,
                                  color: DesignTokens.green,
                                ),
                              if (viewModel.errorMessage != null)
                                _Notice(
                                  key: const Key('video-studio-error'),
                                  message: viewModel.errorMessage!,
                                  color: DesignTokens.red,
                                ),
                              if (wide)
                                Row(
                                  key: const Key('video-studio-wide'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _Composer(viewModel: viewModel),
                                    ),
                                    const SizedBox(width: DesignTokens.space16),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        children: [
                                          _BalanceAndPacks(
                                            viewModel: viewModel,
                                          ),
                                          const SizedBox(
                                            height: DesignTokens.space16,
                                          ),
                                          _JobsPanel(viewModel: viewModel),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  key: const Key('video-studio-compact'),
                                  children: [
                                    _BalanceAndPacks(viewModel: viewModel),
                                    const SizedBox(
                                      height: DesignTokens.space16,
                                    ),
                                    _Composer(viewModel: viewModel),
                                    const SizedBox(
                                      height: DesignTokens.space16,
                                    ),
                                    _JobsPanel(viewModel: viewModel),
                                  ],
                                ),
                              const SizedBox(height: DesignTokens.space20),
                              const _LegalLinks(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            };
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1838), Color(0xFF14234A)],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: .45)),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.movie_creation_outlined,
            color: DesignTokens.orange,
            size: 44,
          ),
          SizedBox(width: DesignTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '外部生成APIを使わない、当サイト運営の動画生成',
                  style: TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: DesignTokens.space8),
                Text(
                  '専用GPUでテキストから5秒・720pの動画を生成。失敗時はクレジットを自動返却し、完成物は期限付きリンクでお渡しします。',
                  style: TextStyle(color: DesignTokens.textOnDark, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.viewModel.prompt);
  }

  @override
  void didUpdateWidget(covariant _Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final prompt = widget.viewModel.prompt;
    if (_promptController.text != prompt) {
      _promptController.value = TextEditingValue(
        text: prompt,
        selection: TextSelection.collapsed(offset: prompt.length),
      );
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = widget.viewModel;
    final model = viewModel.selectedModel!;
    return _Panel(
      title: '動画をつくる',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(model.description, style: _secondaryStyle),
          if (viewModel.hasAppliedImprovement) ...[
            const SizedBox(height: DesignTokens.space12),
            Container(
              key: const Key('video-improvement-applied'),
              padding: const EdgeInsets.all(DesignTokens.space12),
              decoration: BoxDecoration(
                color: DesignTokens.indigo.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                border: Border.all(
                  color: DesignTokens.indigoLight.withValues(alpha: .7),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.loop, color: DesignTokens.indigoLight),
                  const SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: Text(
                      'レビュー「${viewModel.appliedImprovementTitle ?? '前回動画'}」の改善案を反映中',
                      style: const TextStyle(color: DesignTokens.textOnDark),
                    ),
                  ),
                  IconButton(
                    key: const Key('video-improvement-clear'),
                    tooltip: '改善履歴の関連付けを外す',
                    onPressed: viewModel.clearAppliedImprovement,
                    icon: const Icon(
                      Icons.close,
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.space16),
          TextField(
            key: const Key('video-studio-prompt'),
            controller: _promptController,
            minLines: 5,
            maxLines: 9,
            maxLength: 1000,
            onChanged: viewModel.setPrompt,
            style: const TextStyle(color: DesignTokens.textPrimary),
            decoration: _inputDecoration('映像の内容、背景、動き、カメラ、光を具体的に入力してください'),
          ),
          const SizedBox(height: DesignTokens.space8),
          _ChoiceRow<int>(
            label: '長さ',
            values: model.durations,
            selected: viewModel.durationSeconds,
            display: (value) => '$value秒',
            onSelected: viewModel.setDuration,
          ),
          const SizedBox(height: DesignTokens.space12),
          _ChoiceRow<String>(
            label: '縦横比',
            values: model.aspectRatios,
            selected: viewModel.aspectRatio,
            display: (value) => value,
            onSelected: viewModel.setAspectRatio,
          ),
          const SizedBox(height: DesignTokens.space12),
          _ChoiceRow<String>(
            label: '解像度',
            values: model.resolutions,
            selected: viewModel.resolution,
            display: (value) => value,
            onSelected: viewModel.setResolution,
          ),
          const SizedBox(height: DesignTokens.space16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: DesignTokens.orange,
            value: viewModel.rightsConfirmed,
            onChanged: (value) => viewModel.setRightsConfirmed(value ?? false),
            title: const Text(
              '入力内容に必要な権利・許諾を保有しています',
              style: TextStyle(color: DesignTokens.textOnDark),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: DesignTokens.orange,
            value: viewModel.adultConfirmed,
            onChanged: (value) => viewModel.setAdultConfirmed(value ?? false),
            title: const Text(
              '18歳以上で、利用規約と禁止事項に同意します',
              style: TextStyle(color: DesignTokens.textOnDark),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (viewModel.hasAppliedImprovement ||
              viewModel.activeAuthorization != null) ...[
            const SizedBox(height: DesignTokens.space12),
            _ImprovementAuthorizationCard(viewModel: viewModel),
          ],
          const SizedBox(height: DesignTokens.space12),
          Container(
            padding: const EdgeInsets.all(DesignTokens.space12),
            decoration: BoxDecoration(
              color: DesignTokens.surface3,
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Row(
              children: [
                const Icon(Icons.toll, color: DesignTokens.gold),
                const SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: Text(
                    '必要 ${viewModel.requiredCredits} クレジット  •  残高 ${viewModel.balance.availableCredits}',
                    style: const TextStyle(
                      color: DesignTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!viewModel.hasEnoughCredits)
            const Padding(
              padding: EdgeInsets.only(top: DesignTokens.space8),
              child: Text(
                '残高が不足しています。右側のパックを購入してください。',
                style: TextStyle(color: DesignTokens.amber),
              ),
            ),
          const SizedBox(height: DesignTokens.space16),
          FilledButton.icon(
            key: const Key('video-studio-generate'),
            onPressed: viewModel.canGenerate
                ? () => unawaited(viewModel.generate())
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: DesignTokens.orange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: viewModel.isGenerating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(viewModel.isGenerating ? '生成を開始しています…' : '動画を生成'),
          ),
        ],
      ),
    );
  }
}

class _ImprovementAuthorizationCard extends StatelessWidget {
  const _ImprovementAuthorizationCard({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final matching = viewModel.matchingActiveAuthorization;
    final active = matching ?? viewModel.activeAuthorization;
    return Container(
      key: const Key('video-improvement-authorization'),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: DesignTokens.indigo.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(
          color: DesignTokens.indigoLight.withValues(alpha: .55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '改善ループの継続承認',
            style: TextStyle(
              color: DesignTokens.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          if (active != null) ...[
            Text(
              '承認ID ${active.id}\n'
              '状態 ${_authorizationStatusLabel(active)}\n'
              '有効期限 ${_formatAuthorizationDate(active.validUntil)}\n'
              '残り ${active.remainingRegenerations}回・${active.remainingCredits} credits',
              key: const Key('video-authorization-status'),
              style: _secondaryStyle,
            ),
            const SizedBox(height: DesignTokens.space8),
            if (matching != null && viewModel.hasAppliedImprovement)
              FilledButton.icon(
                key: const Key('video-run-existing-authorization'),
                onPressed: viewModel.canRunAuthorizedImprovement
                    ? () => unawaited(viewModel.runAuthorizedImprovement())
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.indigoLight,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.loop),
                label: Text(
                  viewModel.isAuthorizingImprovement
                      ? '改善生成を開始しています…'
                      : '既存承認で300 creditsの改善生成を実行',
                ),
              ),
            TextButton.icon(
              key: const Key('video-revoke-authorization'),
              onPressed: viewModel.revokingAuthorizationId == null
                  ? () => unawaited(viewModel.revokeAuthorization(active.id))
                  : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('今後の自動改善を停止'),
            ),
          ] else if (viewModel.hasAppliedImprovement) ...[
            const Text(
              '期限と反復上限を選ぶと承認IDを保存します。残高・最新レビュー・生成枠が揃えば最初の300 creditsを同時予約し、揃わない場合は理由付きで保留して後から同じ承認IDで再開します。',
              style: _secondaryStyle,
            ),
            const SizedBox(height: DesignTokens.space12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('video-authorization-expiry'),
                    initialValue: viewModel.authorizationValidityHours,
                    dropdownColor: DesignTokens.surface2,
                    decoration: _inputDecoration('有効期限'),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text('24時間')),
                      DropdownMenuItem(value: 168, child: Text('7日間')),
                      DropdownMenuItem(value: 720, child: Text('30日間')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        viewModel.setAuthorizationValidityHours(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.space8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: const Key('video-authorization-iterations'),
                    initialValue: viewModel.authorizationRegenerations,
                    dropdownColor: DesignTokens.surface2,
                    decoration: _inputDecoration('最大反復'),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1回')),
                      DropdownMenuItem(value: 2, child: Text('2回')),
                      DropdownMenuItem(value: 3, child: Text('3回')),
                      DropdownMenuItem(value: 5, child: Text('5回')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        viewModel.setAuthorizationRegenerations(value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space8),
            Text(
              '1回上限 ${viewModel.requiredCredits} credits・総上限 '
              '${viewModel.authorizationTotalCredits} credits・自動購入 0円',
              key: const Key('video-authorization-limits'),
              style: const TextStyle(color: DesignTokens.amber),
            ),
            const SizedBox(height: DesignTokens.space8),
            FilledButton.icon(
              key: const Key('video-authorize-and-run'),
              onPressed: viewModel.canAuthorizeImprovement
                  ? () => unawaited(viewModel.authorizeAndGenerateImprovement())
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.orange,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.play_circle_outline),
              label: Text(
                viewModel.isAuthorizingImprovement
                    ? '承認と生成を開始しています…'
                    : '継続承認を保存して最初の300 creditsを実行',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatAuthorizationDate(DateTime value) {
  final local = value.toLocal().toString();
  return local.length >= 16 ? local.substring(0, 16) : local;
}

String _authorizationStatusLabel(VideoImprovementAuthorization value) {
  return switch (value.status) {
    'active' => '実行可能',
    'pending_review' => 'レビュー待ち',
    'pending_funding' => '残高待ち',
    'pending_execution' => '生成枠待ち',
    'exhausted' => '上限到達',
    'expired' => '期限切れ',
    'revoked' => '停止済み',
    _ => value.status,
  };
}

class _BalanceAndPacks extends StatelessWidget {
  const _BalanceAndPacks({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '動画クレジット',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: DesignTokens.space12,
            runSpacing: DesignTokens.space8,
            children: [
              _Metric(label: '利用可能', value: viewModel.balance.availableCredits),
              _Metric(label: '生成中', value: viewModel.balance.reservedCredits),
              if (viewModel.balance.creditDebt > 0)
                _Metric(label: '返金相殺', value: viewModel.balance.creditDebt),
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          ...viewModel.catalog!.creditPacks.map(
            (pack) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space8),
              child: OutlinedButton(
                key: Key('video-credit-pack-${pack.key}'),
                onPressed: viewModel.isOpeningCheckout
                    ? null
                    : () => unawaited(_openCheckout(context, pack)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DesignTokens.textPrimary,
                  side: const BorderSide(color: DesignTokens.indigoLight),
                  padding: const EdgeInsets.all(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${pack.name}  ${pack.credits} credits',
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Text('¥${pack.amountJpy}'),
                  ],
                ),
              ),
            ),
          ),
          const Text('1回払い・自動更新なし。月額Pro/Teamとは別料金です。', style: _secondaryStyle),
        ],
      ),
    );
  }

  Future<void> _openCheckout(
    BuildContext context,
    VideoCreditPackOption pack,
  ) async {
    final returnUri = Uri.base.replace(path: '/video-studio', query: '');
    final checkout = await viewModel.createCheckout(
      pack.key,
      returnUri.toString(),
    );
    if (checkout == null || !context.mounted) return;
    final opened = await launchUrl(
      checkout,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stripe決済画面を開けませんでした。')));
    }
  }
}

class _JobsPanel extends StatelessWidget {
  const _JobsPanel({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: '生成履歴',
      trailing: viewModel.activeJob != null && !viewModel.activeJob!.isTerminal
          ? IconButton(
              tooltip: '生成状況を更新',
              onPressed: viewModel.isRefreshing
                  ? null
                  : () => unawaited(viewModel.refreshActiveJob()),
              icon: const Icon(Icons.sync, color: DesignTokens.orange),
            )
          : null,
      child: viewModel.jobs.isEmpty
          ? const Text('まだ動画はありません。', style: _secondaryStyle)
          : Column(
              children: viewModel.jobs.take(8).map((job) {
                final active = viewModel.activeJob?.id == job.id
                    ? viewModel.activeJob!
                    : job;
                return _JobCard(job: active, viewModel: viewModel);
              }).toList(growable: false),
            ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.viewModel});

  final VideoGenerationJob job;
  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final color = switch (job.status) {
      'succeeded' => DesignTokens.green,
      'failed' || 'cancelled' => DesignTokens.red,
      _ => DesignTokens.amber,
    };
    final label = switch (job.status) {
      'queued' => '待機中',
      'in_progress' => '生成中',
      'succeeded' => '完成',
      'failed' => '失敗・返却済み',
      'cancelled' => 'キャンセル',
      _ => job.status,
    };
    final activity = switch (job.status) {
      'queued' => '専用GPUを起動・準備しています。初回は3分前後かかります。',
      'in_progress' => '専用GPUで推論中です。720p動画は十数分かかる場合があります。画面を閉じても処理は継続します。',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space8),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: DesignTokens.surface3,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: DesignTokens.space8),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${job.durationSeconds}秒 • ${job.aspectRatio}',
                style: _secondaryStyle,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            job.prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: DesignTokens.textOnDark),
          ),
          if (activity != null) ...[
            const SizedBox(height: DesignTokens.space12),
            LinearProgressIndicator(
              key: Key('video-progress-${job.id}'),
              minHeight: 4,
              color: DesignTokens.orange,
              backgroundColor: DesignTokens.surface2,
            ),
            const SizedBox(height: DesignTokens.space8),
            Text(activity, style: _secondaryStyle),
            if (job.updatedAt != null) ...[
              const SizedBox(height: DesignTokens.space4),
              Text(
                '最終処理確認 ${_clock(job.updatedAt!)}'
                '${job.startedAt == null ? '' : '・生成開始 ${_clock(job.startedAt!)}'}',
                style: _secondaryStyle,
              ),
            ],
          ],
          if (job.isSuccessful) ...[
            const SizedBox(height: DesignTokens.space8),
            FilledButton.icon(
              key: Key('video-output-${job.id}'),
              onPressed: viewModel.openingOutputJobId == null
                  ? () => unawaited(_openOutput(context))
                  : null,
              icon: viewModel.openingOutputJobId == job.id
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new),
              label: Text(
                viewModel.openingOutputJobId == job.id
                    ? 'リンクを準備中…'
                    : '動画を開く・保存',
              ),
            ),
            if (job.artifact != null) ...[
              const SizedBox(height: DesignTokens.space8),
              _ArtifactStatus(artifact: job.artifact!),
              const SizedBox(height: DesignTokens.space8),
              OutlinedButton.icon(
                key: Key('video-review-${job.id}'),
                onPressed: viewModel.reviewingArtifactId == null
                    ? () => unawaited(_openReview(context))
                    : null,
                icon: viewModel.reviewingArtifactId == job.artifact!.id
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rate_review_outlined),
                label: Text(
                  job.artifact!.latestReview == null
                      ? 'レビューして次回を改善'
                      : 'レビューを追加して改善',
                ),
              ),
            ] else ...[
              const SizedBox(height: DesignTokens.space8),
              const Text('素材台帳への保存を確認中です。', style: _secondaryStyle),
            ],
          ],
        ],
      ),
    );
  }

  String _clock(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  Future<void> _openOutput(BuildContext context) async {
    final output = await viewModel.loadOutputUrl(job);
    if (output == null || !context.mounted) return;
    final opened = await launchUrl(
      output,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('完成動画を開けませんでした。')));
    }
  }

  Future<void> _openReview(BuildContext context) async {
    final artifact = job.artifact;
    if (artifact == null) return;
    final review = await showDialog<VideoArtifactReviewDraft>(
      context: context,
      builder: (context) =>
          _VideoArtifactReviewDialog(job: job, artifact: artifact),
    );
    if (review == null || !context.mounted) return;
    await viewModel.reviewArtifact(
      job,
      review,
      applyToNextGeneration: review.decision == 'improve',
    );
  }
}

class _ArtifactStatus extends StatelessWidget {
  const _ArtifactStatus({required this.artifact});

  final VideoArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final review = artifact.latestReview;
    return Wrap(
      key: Key('video-artifact-${artifact.id}'),
      spacing: DesignTokens.space8,
      runSpacing: DesignTokens.space8,
      children: [
        const _ArtifactBadge(
          icon: Icons.inventory_2_outlined,
          label: '素材として保存済み',
          color: DesignTokens.green,
        ),
        if (artifact.isSaleCandidate)
          const _ArtifactBadge(
            icon: Icons.storefront_outlined,
            label: '販売候補',
            color: DesignTokens.orange,
          ),
        if (artifact.needsRightsReview)
          const _ArtifactBadge(
            icon: Icons.fact_check_outlined,
            label: '権利・プライバシー確認待ち',
            color: DesignTokens.amber,
          ),
        if (review != null)
          _ArtifactBadge(
            icon: Icons.star_outline,
            label: 'レビュー${review.iteration}回・品質${review.qualityScore}/5',
            color: DesignTokens.indigoLight,
          ),
      ],
    );
  }
}

class _ArtifactBadge extends StatelessWidget {
  const _ArtifactBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoArtifactReviewDialog extends StatefulWidget {
  const _VideoArtifactReviewDialog({required this.job, required this.artifact});

  final VideoGenerationJob job;
  final VideoArtifact artifact;

  @override
  State<_VideoArtifactReviewDialog> createState() =>
      _VideoArtifactReviewDialogState();
}

class _VideoArtifactReviewDialogState
    extends State<_VideoArtifactReviewDialog> {
  late int _quality;
  late int _alignment;
  late int _motion;
  late int _commercial;
  late String _decision;
  late bool _rightsCleared;
  late bool _privacyCleared;
  late final TextEditingController _strengths;
  late final TextEditingController _improvement;
  late final TextEditingController _suggestedPrompt;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final previous = widget.artifact.latestReview;
    _quality = previous?.qualityScore ?? 3;
    _alignment = previous?.promptAlignmentScore ?? 3;
    _motion = previous?.motionQualityScore ?? 3;
    _commercial = previous?.commercialValueScore ?? 3;
    _decision = previous?.decision ?? 'improve';
    _rightsCleared = widget.artifact.rightsStatus == 'allowed';
    _privacyCleared = widget.artifact.privacyStatus == 'cleared';
    _strengths = TextEditingController(text: previous?.strengths ?? '');
    _improvement = TextEditingController(
      text: previous?.improvementRequest ?? '',
    );
    _suggestedPrompt = TextEditingController(
      text: previous?.suggestedPrompt ?? widget.job.prompt,
    );
    _notes = TextEditingController(text: previous?.notes ?? '');
  }

  @override
  void dispose() {
    _strengths.dispose();
    _improvement.dispose();
    _suggestedPrompt.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('video-artifact-review-dialog'),
      backgroundColor: DesignTokens.surface1,
      title: const Text(
        '動画レビューと次回改善',
        style: TextStyle(color: DesignTokens.textPrimary),
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '原本は変更せず保存されます。評価と改善案は履歴として追加され、改善判定では次回プロンプトへ反映されます。',
                style: _secondaryStyle,
              ),
              const SizedBox(height: DesignTokens.space12),
              Wrap(
                spacing: DesignTokens.space12,
                runSpacing: DesignTokens.space12,
                children: [
                  _ReviewScoreField(
                    label: '映像品質',
                    value: _quality,
                    onChanged: (value) => setState(() => _quality = value),
                  ),
                  _ReviewScoreField(
                    label: '指示との一致',
                    value: _alignment,
                    onChanged: (value) => setState(() => _alignment = value),
                  ),
                  _ReviewScoreField(
                    label: '動きの自然さ',
                    value: _motion,
                    onChanged: (value) => setState(() => _motion = value),
                  ),
                  _ReviewScoreField(
                    label: '販売価値',
                    value: _commercial,
                    onChanged: (value) => setState(() => _commercial = value),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              DropdownButtonFormField<String>(
                key: const Key('video-review-decision'),
                initialValue: _decision,
                dropdownColor: DesignTokens.surface2,
                decoration: _inputDecoration('判定'),
                style: const TextStyle(color: DesignTokens.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'keep', child: Text('採用・保持')),
                  DropdownMenuItem(value: 'improve', child: Text('改善して再生成')),
                  DropdownMenuItem(value: 'reject', child: Text('不採用')),
                ],
                onChanged: (value) =>
                    setState(() => _decision = value ?? 'improve'),
              ),
              const SizedBox(height: DesignTokens.space12),
              TextField(
                controller: _strengths,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: DesignTokens.textPrimary),
                decoration: _inputDecoration('良かった点'),
              ),
              TextField(
                key: const Key('video-review-improvement'),
                controller: _improvement,
                maxLength: 1500,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: DesignTokens.textPrimary),
                decoration: _inputDecoration('改善したい点'),
              ),
              TextField(
                key: const Key('video-review-suggested-prompt'),
                controller: _suggestedPrompt,
                onChanged: (_) => setState(() {}),
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                style: const TextStyle(color: DesignTokens.textPrimary),
                decoration: _inputDecoration('次回生成に使う改善版プロンプト'),
              ),
              TextField(
                controller: _notes,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                style: const TextStyle(color: DesignTokens.textPrimary),
                decoration: _inputDecoration('販売・編集メモ（任意）'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _rightsCleared,
                activeColor: DesignTokens.orange,
                onChanged: (value) =>
                    setState(() => _rightsCleared = value ?? false),
                title: const Text(
                  '販売に必要な権利・許諾を確認しました',
                  style: TextStyle(color: DesignTokens.textOnDark),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _privacyCleared,
                activeColor: DesignTokens.orange,
                onChanged: (value) =>
                    setState(() => _privacyCleared = value ?? false),
                title: const Text(
                  '人物・個人情報・プライバシーを確認しました',
                  style: TextStyle(color: DesignTokens.textOnDark),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('video-review-save'),
          onPressed: _suggestedPrompt.text.trim().length >= 3 ? _save : null,
          icon: const Icon(Icons.save_outlined),
          label: Text(_decision == 'improve' ? '保存して次回へ反映' : 'レビューを保存'),
        ),
      ],
    );
  }

  void _save() {
    Navigator.of(context).pop(
      VideoArtifactReviewDraft(
        qualityScore: _quality,
        promptAlignmentScore: _alignment,
        motionQualityScore: _motion,
        commercialValueScore: _commercial,
        decision: _decision,
        strengths: _strengths.text.trim(),
        improvementRequest: _improvement.text.trim(),
        suggestedPrompt: _suggestedPrompt.text.trim(),
        notes: _notes.text.trim(),
        rightsStatus: _rightsCleared ? 'allowed' : 'review_required',
        privacyStatus: _privacyCleared ? 'cleared' : 'review_required',
      ),
    );
  }
}

class _ReviewScoreField extends StatelessWidget {
  const _ReviewScoreField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: DropdownButtonFormField<int>(
        isExpanded: true,
        initialValue: value,
        dropdownColor: DesignTokens.surface2,
        decoration: _inputDecoration(label),
        style: const TextStyle(color: DesignTokens.textPrimary),
        items: List.generate(
          5,
          (index) => DropdownMenuItem(
            value: index + 1,
            child: Text('${index + 1} / 5'),
          ),
        ),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.display,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) display;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: _secondaryStyle),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space8,
            children: values
                .map(
                  (value) => ChoiceChip(
                    label: Text(display(value)),
                    selected: selected == value,
                    onSelected: (_) => onSelected(value),
                    selectedColor: DesignTokens.indigo,
                    backgroundColor: DesignTokens.surface3,
                    labelStyle: const TextStyle(
                      color: DesignTokens.textPrimary,
                    ),
                    side: BorderSide.none,
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.surface3,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _secondaryStyle),
          Text(
            '$value',
            style: const TextStyle(
              color: DesignTokens.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space16),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: DesignTokens.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: DesignTokens.space16),
          child,
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DesignTokens.space16),
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .6)),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              color: DesignTokens.orange,
              size: 48,
            ),
            const SizedBox(height: DesignTokens.space12),
            Text(
              viewModel.errorMessage ?? '読み込みに失敗しました。',
              textAlign: TextAlign.center,
              style: const TextStyle(color: DesignTokens.textOnDark),
            ),
            const SizedBox(height: DesignTokens.space16),
            if (viewModel.authenticationRequired) ...[
              FilledButton.icon(
                key: const Key('video-studio-login'),
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                icon: const Icon(Icons.login),
                label: const Text('ログインする'),
              ),
              const SizedBox(height: DesignTokens.space8),
              TextButton(
                onPressed: () => viewModel.load(currentUri: Uri.base),
                child: const Text('ログイン済みなら再読み込み'),
              ),
            ] else
              FilledButton(
                onPressed: () => viewModel.load(currentUri: Uri.base),
                child: const Text('再試行'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: DesignTokens.space8,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/terms'),
          child: const Text('利用規約'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/privacy'),
          child: const Text('プライバシー'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushNamed('/tokusho'),
          child: const Text('特定商取引法に基づく表記'),
        ),
      ],
    );
  }
}

const _secondaryStyle = TextStyle(
  color: DesignTokens.textSecondary,
  fontSize: 13,
  height: 1.5,
);

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: DesignTokens.textTertiary),
    filled: true,
    fillColor: DesignTokens.surface3,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      borderSide: const BorderSide(color: DesignTokens.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      borderSide: const BorderSide(color: DesignTokens.indigoLight, width: 2),
    ),
  );
}
