import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/models/palm_reading_image.dart';
import '../../../../data/repositories/palm_reading_repository.dart';
import '../../../../data/services/palm_reading_image_picker.dart';
import '../../../../domain/models/palm_reading.dart';
import '../view_models/palm_reading_view_model.dart';

class PalmReadingPage extends StatefulWidget {
  const PalmReadingPage({super.key, this.viewModel, this.isSignedIn});

  final PalmReadingViewModel? viewModel;
  final bool? isSignedIn;

  @override
  State<PalmReadingPage> createState() => _PalmReadingPageState();
}

class _PalmReadingPageState extends State<PalmReadingPage>
    with SingleTickerProviderStateMixin {
  late final PalmReadingViewModel _viewModel;
  late final bool _ownsViewModel;
  late final bool _isSignedIn;
  late final TabController _tabController;
  PalmHandSide? _historyFilter;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        PalmReadingViewModel(
          repository: SupabasePalmReadingRepository(),
          imagePicker: ImagePickerPalmReadingImagePicker(),
        );
    _isSignedIn =
        widget.isSignedIn ?? Supabase.instance.client.auth.currentUser != null;
    _tabController = TabController(length: 2, vsync: this);
    if (_isSignedIn) unawaited(_viewModel.initialize());
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('手相AI占い'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const <Tab>[
                Tab(icon: Icon(Icons.back_hand_outlined), text: '新しく占う'),
                Tab(icon: Icon(Icons.timeline_outlined), text: '履歴・変化'),
              ],
            ),
            actions: <Widget>[
              if (_isSignedIn)
                IconButton(
                  tooltip: '履歴を更新',
                  onPressed: _viewModel.isLoadingHistory
                      ? null
                      : _viewModel.reloadHistory,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
          body: _isSignedIn
              ? TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildNewReadingTab(context),
                    _buildHistoryTab(context),
                  ],
                )
              : const _LoginPrompt(),
        );
      },
    );
  }

  Widget _buildNewReadingTab(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final capture = _CapturePanel(viewModel: _viewModel);
        final result = _viewModel.currentReading == null
            ? const _WaitingForReadingCard()
            : PalmReadingResultView(reading: _viewModel.currentReading!);
        final error = _viewModel.errorMessage == null
            ? null
            : _ErrorBanner(
                message: _viewModel.errorMessage!,
                onDismiss: _viewModel.clearError,
              );

        if (constraints.maxWidth >= 960) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1240),
                child: Column(
                  children: <Widget>[
                    if (error != null) ...<Widget>[
                      error,
                      const SizedBox(height: 16),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(width: 430, child: capture),
                        const SizedBox(width: 24),
                        Expanded(child: result),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (error != null) ...<Widget>[error, const SizedBox(height: 12)],
            capture,
            const SizedBox(height: 16),
            result,
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildHistoryTab(BuildContext context) {
    final filtered = _viewModel.history
        .where(
          (reading) =>
              _historyFilter == null || reading.handSide == _historyFilter,
        )
        .toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '手相の変化を振り返る',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '同じ手の直前データと比較します。線の見え方は光・角度・ピントでも変わるため、変化は参考情報として表示します。',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('すべて'),
                              selected: _historyFilter == null,
                              onSelected: (_) =>
                                  setState(() => _historyFilter = null),
                            ),
                            for (final handSide in PalmHandSide.values)
                              ChoiceChip(
                                label: Text(handSide.label),
                                selected: _historyFilter == handSide,
                                onSelected: (_) =>
                                    setState(() => _historyFilter = handSide),
                              ),
                          ],
                        ),
                        if (_viewModel.errorMessage != null) ...<Widget>[
                          const SizedBox(height: 12),
                          _ErrorBanner(
                            message: _viewModel.errorMessage!,
                            onDismiss: _viewModel.clearError,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_viewModel.isLoadingHistory && _viewModel.history.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyHistory(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: constraints.maxWidth >= 900
                    ? SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 560,
                          mainAxisExtent: 310,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _HistoryCard(
                            reading: filtered[index],
                            deleting: _viewModel.isDeleting(filtered[index].id),
                            onDelete: () => _confirmDelete(filtered[index]),
                          ),
                          childCount: filtered.length,
                        ),
                      )
                    : SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _HistoryCard(
                            reading: filtered[index],
                            deleting: _viewModel.isDeleting(filtered[index].id),
                            onDelete: () => _confirmDelete(filtered[index]),
                          ),
                        ),
                      ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(PalmReading reading) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('鑑定履歴を削除しますか？'),
        content: Text(
          '${reading.handSide.label}の鑑定結果と非公開写真を削除します。この操作は元に戻せません。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final deleted = await _viewModel.deleteReading(reading.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? '鑑定履歴を削除しました' : '鑑定履歴を削除できませんでした')),
    );
  }
}

class _CapturePanel extends StatelessWidget {
  const _CapturePanel({required this.viewModel});

  final PalmReadingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = viewModel.selectedImage;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Icon(Icons.auto_awesome, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '手のひらを撮影',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Text('左右を選び、ガイドに沿って1枚撮影します'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SegmentedButton<PalmHandSide>(
              key: const Key('palm_hand_selector'),
              segments: <ButtonSegment<PalmHandSide>>[
                for (final handSide in PalmHandSide.values)
                  ButtonSegment<PalmHandSide>(
                    value: handSide,
                    label: Text(handSide.label),
                    icon: const Icon(Icons.back_hand_outlined),
                  ),
              ],
              selected: <PalmHandSide>{viewModel.handSide},
              onSelectionChanged: viewModel.isAnalyzing
                  ? null
                  : (selection) => viewModel.selectHand(selection.first),
            ),
            const SizedBox(height: 6),
            Text(
              viewModel.handSide.meaning,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            const _PhotoGuide(),
            const SizedBox(height: 18),
            if (image == null)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      Icon(Icons.add_a_photo_outlined, size: 42),
                      SizedBox(height: 8),
                      Text('写真はまだ選択されていません'),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.memory(
                        image.bytes,
                        key: const Key('palm_photo_preview'),
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      tooltip: '写真を取り消す',
                      onPressed: viewModel.clearSelectedImage,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                if (ImagePickerPalmReadingImagePicker.cameraSupported)
                  FilledButton.tonalIcon(
                    key: const Key('palm_camera_button'),
                    onPressed: viewModel.isPickingImage || viewModel.isAnalyzing
                        ? null
                        : () => viewModel.pickImage(PalmImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('カメラで撮影'),
                  ),
                OutlinedButton.icon(
                  key: const Key('palm_gallery_button'),
                  onPressed: viewModel.isPickingImage || viewModel.isAnalyzing
                      ? null
                      : () => viewModel.pickImage(PalmImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('写真を選ぶ'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('palm_privacy_consent'),
              value: viewModel.privacyConsent,
              onChanged: viewModel.isAnalyzing
                  ? null
                  : (value) => viewModel.setPrivacyConsent(value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('写真をAI解析し、本人限定の履歴へ保存することに同意します'),
              subtitle: const Text('写真は非公開で保存され、履歴から結果と一緒に削除できます。'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('palm_analyze_button'),
              onPressed: viewModel.canAnalyze ? viewModel.analyze : null,
              icon: viewModel.isAnalyzing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(viewModel.isAnalyzing ? 'AIが主要線を確認中…' : 'AIで手相を占う'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoGuide extends StatelessWidget {
  const _PhotoGuide();

  static const List<(IconData, String)> _steps = <(IconData, String)>[
    (Icons.light_mode_outlined, '明るい場所で影と反射を避ける'),
    (Icons.pan_tool_alt_outlined, '指を自然に開き、手首まで写す'),
    (Icons.center_focus_strong_outlined, '手のひらへ正面からピントを合わせる'),
    (Icons.filter_none_outlined, '無地の背景で、片手ずつ撮る'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'きれいに読み取る4つのコツ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < _steps.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(radius: 14, child: Text('${index + 1}')),
                const SizedBox(width: 10),
                Icon(_steps[index].$1, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_steps[index].$2)),
              ],
            ),
          ),
      ],
    );
  }
}

class PalmReadingResultView extends StatelessWidget {
  const PalmReadingResultView({super.key, required this.reading});

  final PalmReading reading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('palm_reading_result'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  '${reading.handSide.label}の鑑定結果',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Chip(
                  avatar: const Icon(Icons.high_quality_outlined, size: 18),
                  label: Text('写真品質 ${reading.quality.score}/100'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                reading.overall,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 16,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 18),
            _ReadingTextSection(
              icon: Icons.psychology_alt_outlined,
              title: '性格・資質',
              text: reading.traits,
            ),
            _ReadingTextSection(
              icon: Icons.favorite_border,
              title: '恋愛・人間関係',
              text: reading.love,
            ),
            _ReadingTextSection(
              icon: Icons.work_outline,
              title: '仕事・取り組み方',
              text: reading.work,
            ),
            const Divider(height: 30),
            Text(
              '主要線',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            for (final line in reading.lines) _PalmLineCard(line: line),
            if (reading.advice.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '今回のヒント',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final advice in reading.advice)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(advice)),
                    ],
                  ),
                ),
            ],
            if (reading.comparison.hasPrevious) ...<Widget>[
              const SizedBox(height: 18),
              _ComparisonCard(comparison: reading.comparison),
            ],
            const SizedBox(height: 18),
            Text(
              '※ 手相占いは科学的・医学的な診断ではありません。結果は娯楽と自己対話のきっかけとしてお楽しみください。',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingTextSection extends StatelessWidget {
  const _ReadingTextSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(text, style: const TextStyle(height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PalmLineCard extends StatelessWidget {
  const _PalmLineCard({required this.line});

  final PalmLineReading line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      line.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text('明瞭度 ${line.visibility}%'),
                ],
              ),
              const SizedBox(height: 7),
              LinearProgressIndicator(value: line.visibility / 100),
              const SizedBox(height: 8),
              Text(
                line.shape,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(line.interpretation, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 6),
              Text(
                '見た目の強さ ${line.strength}% ・ 連続性 ${line.continuity}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final PalmReadingComparison comparison;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.compare_arrows, color: colors.onSecondaryContainer),
              const SizedBox(width: 8),
              Text(
                '前回からの見え方',
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text('確度: ${comparison.confidence == 'medium' ? '中' : '低'}'),
            ],
          ),
          const SizedBox(height: 10),
          Text(comparison.summary, style: const TextStyle(height: 1.5)),
          if (comparison.changes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final change in comparison.changes)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Chip(
                      label: Text('${change.label}: ${change.direction.label}'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(change.detail),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            comparison.caution,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.reading,
    required this.deleting,
    required this.onDelete,
  });

  final PalmReading reading;
  final bool deleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy/MM/dd HH:mm').format(reading.createdAt);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _HistoryThumbnail(reading: reading),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${reading.handSide.label}・$date',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reading.overall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '履歴と写真を削除',
                  onPressed: deleting ? null : onDelete,
                  icon: deleting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Chip(label: Text('写真品質 ${reading.quality.score}')),
                if (reading.comparison.hasPrevious)
                  const Chip(label: Text('前回比較あり')),
              ],
            ),
            if (reading.comparison.hasPrevious) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                reading.comparison.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('鑑定の詳細を見る'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(12),
          child: PalmReadingResultView(reading: reading),
        ),
      ),
    );
  }
}

class _HistoryThumbnail extends StatelessWidget {
  const _HistoryThumbnail({required this.reading});

  final PalmReading reading;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: const Center(child: Icon(Icons.back_hand_outlined)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: 72,
        child: reading.imageUrl == null
            ? fallback
            : Image.network(
                reading.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _WaitingForReadingCard extends StatelessWidget {
  const _WaitingForReadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.back_hand_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '鑑定結果はここに表示されます',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '主要4線を構造化して保存し、次回から同じ手の見え方を比較します。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.timeline_outlined,
              size: 58,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            const Text('まだ鑑定履歴がありません'),
            const SizedBox(height: 4),
            const Text('最初の鑑定が、今後の変化を比べる基準になります。'),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            IconButton(
              tooltip: '閉じる',
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_outline, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    '手相AI占いにはログインが必要です',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '写真と鑑定履歴を本人だけに安全に保存するため、ログイン後にご利用ください。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    icon: const Icon(Icons.login),
                    label: const Text('ログインへ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
