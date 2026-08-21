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

class _Composer extends StatelessWidget {
  const _Composer({required this.viewModel});

  final VideoStudioViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final model = viewModel.selectedModel!;
    return _Panel(
      title: '動画をつくる',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(model.description, style: _secondaryStyle),
          const SizedBox(height: DesignTokens.space16),
          TextField(
            key: const Key('video-studio-prompt'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('完成動画を開けませんでした。')),
      );
    }
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
