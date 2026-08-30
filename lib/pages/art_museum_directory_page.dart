import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repositories/art_museum_repository.dart';
import '../data/services/art_museum_catalog_service.dart';
import '../domain/models/art_museum.dart';
import '../theme/design_tokens.dart';
import '../view_models/art_museum_directory_view_model.dart';

typedef ArtMuseumUrlLauncher = Future<bool> Function(Uri uri);

class ArtMuseumDirectoryPage extends StatefulWidget {
  const ArtMuseumDirectoryPage({super.key, this.viewModel, this.urlLauncher});

  final ArtMuseumDirectoryViewModel? viewModel;
  final ArtMuseumUrlLauncher? urlLauncher;

  @override
  State<ArtMuseumDirectoryPage> createState() => _ArtMuseumDirectoryPageState();
}

class _ArtMuseumDirectoryPageState extends State<ArtMuseumDirectoryPage> {
  static const double _wideLayoutBreakpoint = 760;

  late final ArtMuseumDirectoryViewModel _viewModel;
  late final bool _ownsViewModel;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ??
        ArtMuseumDirectoryViewModel(
          repository: AssetArtMuseumRepository(
            catalogService: ArtMuseumCatalogService(),
          ),
        );
    unawaited(_viewModel.load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全国の美術館')),
      body: ListenableBuilder(
        listenable: _viewModel,
        builder: (context, _) {
          if (_viewModel.catalog == null) {
            return _buildInitialState(context);
          }
          return LayoutBuilder(
            builder: (context, constraints) =>
                _buildDirectory(context, constraints),
          );
        },
      ),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    if (_viewModel.status == ArtMuseumDirectoryStatus.error) {
      return Center(
        key: const Key('museum-load-error'),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: DesignTokens.space16),
              Text(
                _viewModel.errorMessage ?? '美術館データを読み込めませんでした。',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DesignTokens.space16),
              FilledButton.icon(
                onPressed: _viewModel.load,
                icon: const Icon(Icons.refresh),
                label: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(
      key: Key('museum-loading'),
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildDirectory(BuildContext context, BoxConstraints constraints) {
    final catalog = _viewModel.catalog!;
    final museums = _viewModel.visibleMuseums;
    final isWide = constraints.maxWidth >= _wideLayoutBreakpoint;
    final horizontalPadding =
        isWide ? DesignTokens.space24 : DesignTokens.space16;

    return RefreshIndicator(
      onRefresh: _viewModel.load,
      child: CustomScrollView(
        key: const Key('museum-directory-scroll'),
        slivers: [
          if (_viewModel.status == ArtMuseumDirectoryStatus.loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    DesignTokens.space24,
                    horizontalPadding,
                    DesignTokens.space16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_viewModel.status ==
                          ArtMuseumDirectoryStatus.error) ...[
                        _RefreshErrorBanner(
                          message:
                              _viewModel.errorMessage ?? '美術館データを更新できませんでした。',
                          onRetry: _viewModel.load,
                        ),
                        const SizedBox(height: DesignTokens.space16),
                      ],
                      _DirectoryHero(
                        totalCount: catalog.museums.length,
                        prefectureCount: catalog.prefectureCount,
                        asOf: catalog.asOf,
                        sourceLabel: catalog.sourceLabel,
                        onOpenSource: () => _openUrl(catalog.sourceUrl),
                      ),
                      const SizedBox(height: DesignTokens.space20),
                      _buildFilters(context),
                      const SizedBox(height: DesignTokens.space20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '検索結果 ${museums.length}館',
                              key: const Key('museum-result-count'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (_viewModel.hasActiveFilters)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.filter_alt_off_outlined),
                              label: const Text('条件をクリア'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (museums.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            )
          else if (isWide)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                DesignTokens.space32,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 420,
                  mainAxisExtent: 250,
                  crossAxisSpacing: DesignTokens.space16,
                  mainAxisSpacing: DesignTokens.space16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MuseumCard(
                    museum: museums[index],
                    onTap: () => _showMuseumDetails(museums[index]),
                    onOpenOfficialSite: museums[index].officialUrl == null
                        ? null
                        : () => _openUrl(museums[index].officialUrl!),
                  ),
                  childCount: museums.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                DesignTokens.space32,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) {
                      return const SizedBox(height: DesignTokens.space12);
                    }
                    final museum = museums[index ~/ 2];
                    return _MuseumCard(
                      museum: museum,
                      onTap: () => _showMuseumDetails(museum),
                      onOpenOfficialSite: museum.officialUrl == null
                          ? null
                          : () => _openUrl(museum.officialUrl!),
                    );
                  },
                  childCount: museums.length * 2 - 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('museum-search-field'),
              controller: _searchController,
              onChanged: _viewModel.updateQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '美術館名・地域・設置者から検索',
                hintText: '例：現代美術、金沢、市区町村立',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _viewModel.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '検索語を消去',
                        onPressed: () {
                          _searchController.clear();
                          _viewModel.updateQuery('');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              '地域',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: DesignTokens.space8),
            Wrap(
              spacing: DesignTokens.space8,
              runSpacing: DesignTokens.space8,
              children: JapanRegion.values
                  .map(
                    (region) => ChoiceChip(
                      key: Key('museum-region-${region.name}'),
                      label: Text(region.label),
                      selected: _viewModel.selectedRegion == region,
                      onSelected: (_) => _viewModel.selectRegion(region),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: DesignTokens.space16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: '都道府県',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('museum-prefecture-filter'),
                  value: _viewModel.selectedPrefecture ?? '',
                  isExpanded: true,
                  isDense: true,
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('すべての都道府県'),
                    ),
                    ..._viewModel.availablePrefectures.map(
                      (prefecture) => DropdownMenuItem<String>(
                        value: prefecture,
                        child: Text(prefecture),
                      ),
                    ),
                  ],
                  onChanged: (value) => _viewModel.selectPrefecture(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      key: const Key('museum-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: DesignTokens.space16),
            Text(
              '条件に一致する美術館がありません',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text('検索語や地域を変えてお試しください。'),
            const SizedBox(height: DesignTokens.space16),
            OutlinedButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('すべて表示'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    _viewModel.clearFilters();
  }

  Future<void> _showMuseumDetails(ArtMuseum museum) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          key: const Key('museum-detail-sheet'),
          padding: const EdgeInsets.fromLTRB(
            DesignTokens.space24,
            0,
            DesignTokens.space24,
            DesignTokens.space24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          sheetContext,
                        ).colorScheme.primaryContainer,
                        child: const Icon(Icons.museum_outlined),
                      ),
                      const SizedBox(width: DesignTokens.space12),
                      Expanded(
                        child: Text(
                          museum.name,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.space24),
                  _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: '所在地',
                    value: museum.locationLabel,
                  ),
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: '登録区分',
                    value: museum.registrationStatus,
                  ),
                  _DetailRow(
                    icon: Icons.account_balance_outlined,
                    label: '設置者',
                    value: museum.operatorName,
                  ),
                  const SizedBox(height: DesignTokens.space16),
                  FilledButton.icon(
                    onPressed: museum.officialUrl == null
                        ? null
                        : () => _openUrl(museum.officialUrl!),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      museum.officialUrl == null ? '公式サイト情報なし' : '公式サイトを開く',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(Uri uri) async {
    final launcher = widget.urlLauncher;
    final opened = launcher == null
        ? await launchUrl(uri, mode: LaunchMode.externalApplication)
        : await launcher(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('リンクを開けませんでした。')));
    }
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  const _RefreshErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('museum-refresh-error'),
      color: colorScheme.errorContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          children: [
            Icon(
              Icons.sync_problem_outlined,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            const SizedBox(width: DesignTokens.space8),
            TextButton(onPressed: onRetry, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }
}

class _DirectoryHero extends StatelessWidget {
  const _DirectoryHero({
    required this.totalCount,
    required this.prefectureCount,
    required this.asOf,
    required this.sourceLabel,
    required this.onOpenSource,
  });

  final int totalCount;
  final int prefectureCount;
  final String asOf;
  final String sourceLabel;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.tertiaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.museum_outlined,
              size: 42,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: DesignTokens.space12),
            Text(
              '日本全国の美術館を探す',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: DesignTokens.space8),
            Text(
              '名称や地域から検索して、気になる館の公式情報へすぐ移動できます。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: DesignTokens.space16),
            Wrap(
              spacing: DesignTokens.space8,
              runSpacing: DesignTokens.space8,
              children: [
                _HeroStat(label: '$totalCount館'),
                _HeroStat(label: '$prefectureCount都道府県'),
                _HeroStat(label: '${asOf.replaceAll('-', '/')}時点'),
              ],
            ),
            const SizedBox(height: DesignTokens.space12),
            TextButton.icon(
              onPressed: onOpenSource,
              icon: const Icon(Icons.source_outlined),
              label: Text('出典：$sourceLabel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space8,
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _MuseumCard extends StatelessWidget {
  const _MuseumCard({
    required this.museum,
    required this.onTap,
    required this.onOpenOfficialSite,
  });

  final ArtMuseum museum;
  final VoidCallback onTap;
  final VoidCallback? onOpenOfficialSite;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('museum-card-${museum.prefecture}-${museum.name}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        DesignTokens.radiusSmall,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.space8),
                      child: Icon(
                        Icons.account_balance_outlined,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.space12),
                  Expanded(
                    child: Text(
                      museum.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: DesignTokens.space4),
                  Expanded(
                    child: Text(
                      museum.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              Wrap(
                spacing: DesignTokens.space8,
                runSpacing: DesignTokens.space8,
                children: [
                  _MuseumBadge(label: museum.registrationStatus),
                  _MuseumBadge(label: museum.operatorName),
                ],
              ),
              const SizedBox(height: DesignTokens.space12),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onOpenOfficialSite,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        onOpenOfficialSite == null ? '公式URL未掲載' : '公式サイト',
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
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

class _MuseumBadge extends StatelessWidget {
  const _MuseumBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space8,
          vertical: DesignTokens.space4,
        ),
        child: Text(
          label.isEmpty ? '区分未掲載' : label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: DesignTokens.space4),
                Text(value.isEmpty ? '情報なし' : value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
