import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/local_business_reference.dart';
import '../../../../domain/models/statistical_area_boundary.dart';
import '../../../../theme/design_tokens.dart';
import '../view_models/local_business_map_view_model.dart';

typedef LocalBusinessMapBuilder = Widget Function(
  BuildContext context,
  LocalBusinessReferenceSnapshot snapshot,
  String? selectedBusinessId,
  ValueChanged<String> onSelect,
  VoidCallback onOpenAttribution,
);

class LocalBusinessMapPage extends StatelessWidget {
  const LocalBusinessMapPage({super.key, this.mapBuilder});

  final LocalBusinessMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LocalBusinessMapViewModel>();
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.surface1,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        title: const Text(
          '地域事業者マップ',
          style: TextStyle(
            color: DesignTokens.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('local-business-refresh-button'),
            tooltip: '町丁境界と公開参考情報を再取得',
            onPressed: viewModel.isLoading ? null : viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.maxWidth >= 980
                ? _WideBusinessMapLayout(
                    viewModel: viewModel,
                    mapBuilder: mapBuilder,
                  )
                : _CompactBusinessMapLayout(
                    viewModel: viewModel,
                    mapBuilder: mapBuilder,
                  );
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WideBusinessMapLayout extends StatelessWidget {
  const _WideBusinessMapLayout({required this.viewModel, this.mapBuilder});

  final LocalBusinessMapViewModel viewModel;
  final LocalBusinessMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageIntroduction(viewModel: viewModel),
          const SizedBox(height: DesignTokens.space12),
          _AreaSelectorCard(viewModel: viewModel),
          const SizedBox(height: DesignTokens.space12),
          _OfficialAggregateCard(viewModel: viewModel),
          const SizedBox(height: DesignTokens.space16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _MapPanel(
                    viewModel: viewModel,
                    mapBuilder: mapBuilder,
                  ),
                ),
                const SizedBox(width: DesignTokens.space16),
                Expanded(
                  flex: 2,
                  child: _ReferenceListPanel(viewModel: viewModel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactBusinessMapLayout extends StatelessWidget {
  const _CompactBusinessMapLayout({required this.viewModel, this.mapBuilder});

  final LocalBusinessMapViewModel viewModel;
  final LocalBusinessMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('local-business-compact-layout'),
      padding: const EdgeInsets.all(DesignTokens.space12),
      children: [
        _PageIntroduction(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space12),
        _AreaSelectorCard(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space12),
        _OfficialAggregateCard(viewModel: viewModel),
        const SizedBox(height: DesignTokens.space12),
        SizedBox(
          height: 330,
          child: _MapPanel(viewModel: viewModel, mapBuilder: mapBuilder),
        ),
        const SizedBox(height: DesignTokens.space12),
        _ReferenceListPanel(viewModel: viewModel, shrinkWrap: true),
      ],
    );
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction({required this.viewModel});

  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF211A18), Color(0xFF161A24)],
        ),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.orange.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_city,
              color: DesignTokens.orange,
              size: 28,
            ),
            const SizedBox(width: DesignTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.selectedRegionHeading,
                    key: const Key('selected-statistical-area-heading'),
                    style: const TextStyle(
                      color: DesignTokens.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    viewModel.hasOfficialAggregateForSelectedArea
                        ? '公式統計の集計値と、公開地図上の参考事業者を分けて表示します。'
                            'オレンジ線は統計上の町丁境界、青円は公開情報の300m範囲です。'
                            '公開一覧を「個人経営20件」とは扱いません。'
                        : '${viewModel.selectedScope.label}の境界を切り替えて確認できます。'
                            'オレンジ線が選択中の境界です。'
                            'この地域の事業所統計と公開参考一覧は現在未連携で、件数は推測しません。',
                    style: const TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: 13,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaSelectorCard extends StatelessWidget {
  const _AreaSelectorCard({required this.viewModel});

  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('fuchu-area-selector-card'),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(
          color: DesignTokens.orange.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space8,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scopeSelector = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '表示範囲（府中 → 東京 → 関東 → 日本）',
                  style: TextStyle(
                    color: DesignTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: DesignTokens.space8),
                Wrap(
                  key: const Key('statistical-boundary-scope-selector'),
                  spacing: DesignTokens.space8,
                  runSpacing: DesignTokens.space8,
                  children: [
                    for (final scope in viewModel.availableScopes)
                      ChoiceChip(
                        key: Key('boundary-scope-${scope.name}'),
                        label: Text(scope.label),
                        selected: viewModel.selectedScope == scope,
                        onSelected: (_) => viewModel.selectScope(scope),
                      ),
                  ],
                ),
              ],
            );
            final selector = KeyedSubtree(
              key: ValueKey(
                'area-selector-state-${viewModel.selectedScope.name}-'
                '${viewModel.selectedAreaCode}',
              ),
              child: DropdownButtonFormField<String>(
                key: const Key('fuchu-area-selector'),
                initialValue: viewModel.selectedAreaCode,
                isExpanded: true,
                menuMaxHeight: 420,
                dropdownColor: DesignTokens.surface2,
                decoration: InputDecoration(
                  labelText: viewModel.selectedScope.selectorLabel,
                  prefixIcon: const Icon(
                    Icons.map_outlined,
                    color: DesignTokens.orange,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusSmall,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      DesignTokens.radiusSmall,
                    ),
                    borderSide: const BorderSide(color: DesignTokens.divider),
                  ),
                ),
                items: [
                  for (final area in viewModel.availableAreas)
                    DropdownMenuItem<String>(
                      value: area.code,
                      child: Text(
                        area.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) viewModel.selectArea(value);
                },
              ),
            );
            final status = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (viewModel.isBoundaryLoading) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: DesignTokens.space8),
                ],
                Flexible(
                  child: Text(
                    viewModel.isBoundaryLoading
                        ? '${viewModel.selectedScope.label}の境界を読み込み中'
                        : viewModel.boundaryCountLabel,
                    key: const Key('fuchu-area-count-label'),
                    style: const TextStyle(
                      color: DesignTokens.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            );
            final errorMessage = viewModel.boundaryErrorMessage;
            final body = constraints.maxWidth >= 620
                ? Row(
                    children: [
                      Expanded(child: selector),
                      const SizedBox(width: DesignTokens.space12),
                      status,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      selector,
                      const SizedBox(height: DesignTokens.space8),
                      status,
                    ],
                  );
            final combinedBody = constraints.maxWidth >= 900
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: scopeSelector),
                      const SizedBox(width: DesignTokens.space16),
                      Expanded(flex: 4, child: selector),
                      const SizedBox(width: DesignTokens.space12),
                      status,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      scopeSelector,
                      const SizedBox(height: DesignTokens.space12),
                      body,
                    ],
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                combinedBody,
                if (errorMessage != null) ...[
                  const SizedBox(height: DesignTokens.space8),
                  Text(
                    errorMessage,
                    style: const TextStyle(
                      color: DesignTokens.orangeLight,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OfficialAggregateCard extends StatelessWidget {
  const _OfficialAggregateCard({required this.viewModel});

  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final aggregate = viewModel.snapshot.officialAggregate;
    if (!viewModel.hasOfficialAggregateForSelectedArea) {
      return DecoratedBox(
        key: const Key('official-business-aggregate-card'),
        decoration: BoxDecoration(
          color: DesignTokens.surface1,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(
            color: DesignTokens.indigo.withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.query_stats_outlined,
                color: DesignTokens.indigoLight,
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${viewModel.selectedArea.name}の公式事業所統計',
                      style: const TextStyle(
                        color: DesignTokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space4),
                    const Text(
                      '現在、事業所数・従業者数は本町一丁目のみ連携済みです。'
                      '選択した町丁の値を本町一丁目の値で補完・推測することはありません。',
                      key: Key('official-aggregate-unavailable-note'),
                      style: TextStyle(
                        color: DesignTokens.textSecondary,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      key: const Key('official-business-aggregate-card'),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.indigo.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: DesignTokens.space8,
              runSpacing: DesignTokens.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '公式集計',
                  style: TextStyle(
                    color: DesignTokens.indigoLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  aggregate.surveyName,
                  style: const TextStyle(
                    color: DesignTokens.textOnDark,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.space12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final metricWidth = compact
                    ? (constraints.maxWidth - DesignTokens.space8) / 2
                    : (constraints.maxWidth - DesignTokens.space24) / 4;
                return Wrap(
                  spacing: DesignTokens.space8,
                  runSpacing: DesignTokens.space8,
                  children: [
                    _MetricTile(
                      width: metricWidth,
                      label: '全事業所',
                      value: '${aggregate.totalEstablishments}',
                      unit: '事業所',
                    ),
                    _MetricTile(
                      width: metricWidth,
                      label: '全従業者',
                      value: '${aggregate.totalEmployees}',
                      unit: '人',
                    ),
                    _MetricTile(
                      key: const Key('sole-proprietor-count-metric'),
                      width: metricWidth,
                      label: '個人経営',
                      value: '${aggregate.soleProprietorEstablishments}',
                      unit: '事業所',
                      accent: DesignTokens.orange,
                    ),
                    _MetricTile(
                      width: metricWidth,
                      label: '個人経営の従業者',
                      value: '${aggregate.soleProprietorEmployees}',
                      unit: '人',
                      accent: DesignTokens.orange,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: DesignTokens.space12),
            Text(
              aggregate.disclosureNote,
              style: const TextStyle(
                color: DesignTokens.textSecondary,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('official-business-source-link'),
                onPressed: () =>
                    _openWithFeedback(context, viewModel.openOfficialSource()),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: DesignTokens.orange,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(aggregate.sourceLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    required this.unit,
    this.accent = DesignTokens.indigoLight,
  });

  final double width;
  final String label;
  final String value;
  final String unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DesignTokens.surface2,
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DesignTokens.space4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        color: accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: const TextStyle(
                        color: DesignTokens.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.viewModel, this.mapBuilder});

  final LocalBusinessMapViewModel viewModel;
  final LocalBusinessMapBuilder? mapBuilder;

  @override
  Widget build(BuildContext context) {
    final builder = mapBuilder ??
        (
          context,
          snapshot,
          selectedBusinessId,
          onSelect,
          onOpenAttribution,
        ) =>
            buildLocalBusinessReferenceMap(
              context,
              snapshot,
              selectedBusinessId,
              onSelect,
              onOpenAttribution,
            );
    return ClipRRect(
      key: const Key('local-business-map-panel'),
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: Stack(
        children: [
          Positioned.fill(
            child: builder(
              context,
              viewModel.snapshot,
              viewModel.selectedBusinessId,
              viewModel.selectBusiness,
              () => _openWithFeedback(context, viewModel.openPublicSource()),
            ),
          ),
          Positioned(
            left: DesignTokens.space8,
            top: DesignTokens.space8,
            child: _StatisticalBoundaryLegend(viewModel: viewModel),
          ),
        ],
      ),
    );
  }
}

class _StatisticalBoundaryLegend extends StatelessWidget {
  const _StatisticalBoundaryLegend({required this.viewModel});

  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final boundarySet = viewModel.snapshot.statisticalBoundarySet;
    return Tooltip(
      message: '${boundarySet.boundaryNote}\n${boundarySet.simplificationNote}',
      child: Material(
        color: DesignTokens.surface1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        child: InkWell(
          key: const Key('statistical-boundary-source-link'),
          onTap: () =>
              _openWithFeedback(context, viewModel.openBoundarySource()),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, maxWidth: 240),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DesignTokens.space8,
                vertical: DesignTokens.space4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.crop_square,
                    size: 22,
                    color: DesignTokens.orange,
                  ),
                  const SizedBox(width: DesignTokens.space8),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${boundarySet.target.name}｜'
                          '${boundarySet.scope == StatisticalBoundaryScope.fuchuCity ? '統計上の境界' : '行政区域境界'}',
                          style: const TextStyle(
                            color: DesignTokens.orangeLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          '${boundarySet.sourceLabel}（${boundarySet.license}）',
                          key: const Key('statistical-boundary-dataset-label'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          boundarySet.scope ==
                                  StatisticalBoundaryScope.fuchuCity
                              ? '統計境界・簡略表示（詳細はタップ）'
                              : '2023年時点・簡略境界（詳細はタップ）',
                          key: const Key('statistical-boundary-caveat'),
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                        Text(
                          viewModel.hasOfficialAggregateForSelectedArea
                              ? '青円：公開情報の300m範囲'
                              : '公開情報：この地域は未連携',
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 10,
                            height: 1.5,
                          ),
                        ),
                      ],
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
}

double _initialZoomFor(
  StatisticalAreaBoundary area,
  StatisticalBoundaryScope scope,
) {
  final points = area.allPoints.toList(growable: false);
  if (points.isEmpty) {
    return switch (scope) {
      StatisticalBoundaryScope.fuchuCity => 13,
      StatisticalBoundaryScope.tokyo => 9,
      StatisticalBoundaryScope.kanto => 7,
      StatisticalBoundaryScope.japan => 5,
    };
  }
  var minimumLatitude = points.first.latitude;
  var maximumLatitude = minimumLatitude;
  var minimumLongitude = points.first.longitude;
  var maximumLongitude = minimumLongitude;
  for (final point in points.skip(1)) {
    if (point.latitude < minimumLatitude) minimumLatitude = point.latitude;
    if (point.latitude > maximumLatitude) maximumLatitude = point.latitude;
    if (point.longitude < minimumLongitude) minimumLongitude = point.longitude;
    if (point.longitude > maximumLongitude) maximumLongitude = point.longitude;
  }
  final span = (maximumLatitude - minimumLatitude) >
          (maximumLongitude - minimumLongitude)
      ? maximumLatitude - minimumLatitude
      : maximumLongitude - minimumLongitude;
  if (span > 10) return 4;
  if (span > 5) return 5;
  if (span > 2) return 6;
  if (span > 1) return 7;
  if (span > 0.5) return 8;
  if (span > 0.2) return 9;
  if (span > 0.08) return 10;
  if (span > 0.04) return 12.4;
  if (span > 0.025) return 13;
  if (span > 0.014) return 13.7;
  if (span > 0.008) return 14.3;
  if (span > 0.004) return 15;
  return 15.7;
}

@visibleForTesting
class StatisticalBoundaryMapViewport {
  const StatisticalBoundaryMapViewport({
    required this.center,
    required this.initialZoom,
    required this.maximumZoom,
    this.scopeBounds,
  });

  final LatLng center;
  final double initialZoom;
  final double maximumZoom;
  final LatLngBounds? scopeBounds;
}

@visibleForTesting
StatisticalBoundaryMapViewport statisticalBoundaryMapViewportFor(
  StatisticalAreaBoundarySet boundarySet,
  LatLng selectedCenter,
) {
  if (boundarySet.scope == StatisticalBoundaryScope.fuchuCity) {
    return StatisticalBoundaryMapViewport(
      center: selectedCenter,
      initialZoom: _initialZoomFor(
        boundarySet.target,
        boundarySet.scope,
      ),
      maximumZoom: 18,
    );
  }

  final coordinates = <LatLng>[
    for (final area in boundarySet.areas)
      for (final point in area.allPoints)
        LatLng(point.latitude, point.longitude),
  ];
  final fallbackBounds = switch (boundarySet.scope) {
    StatisticalBoundaryScope.tokyo => LatLngBounds(
        const LatLng(20, 136),
        const LatLng(36, 154),
      ),
    StatisticalBoundaryScope.kanto => LatLngBounds(
        const LatLng(20, 136),
        const LatLng(38, 154),
      ),
    StatisticalBoundaryScope.japan => LatLngBounds(
        const LatLng(20, 122),
        const LatLng(46, 154),
      ),
    StatisticalBoundaryScope.fuchuCity => throw StateError('unreachable'),
  };
  final bounds = coordinates.isEmpty
      ? fallbackBounds
      : LatLngBounds.fromPoints(coordinates);
  final maximumZoom = switch (boundarySet.scope) {
    StatisticalBoundaryScope.tokyo => 7.5,
    StatisticalBoundaryScope.kanto => 6.5,
    StatisticalBoundaryScope.japan => 4.5,
    StatisticalBoundaryScope.fuchuCity => 18.0,
  };
  return StatisticalBoundaryMapViewport(
    center: bounds.center,
    initialZoom: maximumZoom,
    maximumZoom: maximumZoom,
    scopeBounds: bounds,
  );
}

@visibleForTesting
Widget buildLocalBusinessReferenceMap(
  BuildContext context,
  LocalBusinessReferenceSnapshot snapshot,
  String? selectedBusinessId,
  ValueChanged<String> onSelect,
  VoidCallback onOpenAttribution, {
  bool includeBaseTiles = true,
}) {
  final referenceCenter = LatLng(
    snapshot.centerLatitude,
    snapshot.centerLongitude,
  );
  final boundarySet = snapshot.statisticalBoundarySet;
  final viewport = statisticalBoundaryMapViewportFor(
    boundarySet,
    referenceCenter,
  );
  final boundaryAreas = [
    ...boundarySet.areas.where((area) => !area.isTarget),
    boundarySet.target,
  ];
  return Stack(
    fit: StackFit.expand,
    children: [
      FlutterMap(
        key: ValueKey(
          'statistical-area-map-${boundarySet.scope.name}-'
          '${boundarySet.target.code}',
        ),
        options: MapOptions(
          initialCenter: viewport.center,
          initialZoom: viewport.initialZoom,
          initialCameraFit: viewport.scopeBounds == null
              ? null
              : CameraFit.bounds(
                  bounds: viewport.scopeBounds!,
                  padding: const EdgeInsets.all(28),
                  maxZoom: viewport.maximumZoom,
                ),
        ),
        children: [
          if (includeBaseTiles)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'jp.jibun_inc.my_web_app',
            ),
          PolygonLayer<String>(
            key: const Key('statistical-boundary-polygon-layer'),
            drawLabelsLast: true,
            polygons: [
              for (final area in boundaryAreas)
                for (final polygon in <List<StatisticalAreaBoundaryPoint>>[
                  area.points,
                  ...area.additionalPolygons,
                ])
                  if (polygon.length >= 3)
                    Polygon<String>(
                      points: [
                        for (final point in polygon)
                          LatLng(point.latitude, point.longitude),
                      ],
                      color: area.isTarget
                          ? DesignTokens.orange.withValues(alpha: 0.14)
                          : Colors.transparent,
                      borderStrokeWidth: area.isTarget ? 3 : 1,
                      borderColor: area.isTarget
                          ? DesignTokens.orange
                          : DesignTokens.textOnDark.withValues(alpha: 0.46),
                      label: area.isTarget && identical(polygon, area.points)
                          ? area.name
                          : null,
                      labelStyle: const TextStyle(
                        color: DesignTokens.orangeLight,
                        backgroundColor: Color(0xCC1A1A1A),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                      hitValue: area.code,
                    ),
            ],
          ),
          if (snapshot.radiusMeters > 0)
            CircleLayer(
              key: const Key('public-reference-radius-layer'),
              circles: [
                CircleMarker(
                  point: referenceCenter,
                  radius: snapshot.radiusMeters.toDouble(),
                  useRadiusInMeter: true,
                  color: DesignTokens.indigo.withValues(alpha: 0.06),
                  borderColor: DesignTokens.indigo.withValues(alpha: 0.82),
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (final business in snapshot.businesses)
                Marker(
                  point: LatLng(business.latitude, business.longitude),
                  width: 42,
                  height: 42,
                  child: Semantics(
                    label: '${business.name}、${business.category}',
                    button: true,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => onSelect(business.id),
                      icon: Icon(
                        Icons.location_on,
                        size: selectedBusinessId == business.id ? 40 : 34,
                        color: selectedBusinessId == business.id
                            ? DesignTokens.orange
                            : DesignTokens.indigo,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      Positioned(
        right: DesignTokens.space8,
        bottom: DesignTokens.space8,
        child: Material(
          color: DesignTokens.surface1.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          child: InkWell(
            onTap: onOpenAttribution,
            borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Center(
                  child: Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      color: DesignTokens.textOnDark,
                      fontSize: 10,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _ReferenceListPanel extends StatelessWidget {
  const _ReferenceListPanel({required this.viewModel, this.shrinkWrap = false});

  final LocalBusinessMapViewModel viewModel;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final snapshot = viewModel.snapshot;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      children: [
        _ReferenceListHeader(viewModel: viewModel),
        if (viewModel.isLoading) ...[
          const SizedBox(height: DesignTokens.space12),
          const LinearProgressIndicator(color: DesignTokens.orange),
        ],
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: DesignTokens.space12),
          _ErrorNotice(message: viewModel.errorMessage!),
        ],
        const SizedBox(height: DesignTokens.space12),
        if (snapshot.businesses.isEmpty && !viewModel.isLoading)
          const _EmptyReferenceList()
        else if (shrinkWrap)
          for (var index = 0; index < snapshot.businesses.length; index++) ...[
            _BusinessReferenceTile(
              index: index,
              business: snapshot.businesses[index],
              selected:
                  snapshot.businesses[index].id == viewModel.selectedBusinessId,
              viewModel: viewModel,
            ),
            if (index < snapshot.businesses.length - 1)
              const SizedBox(height: DesignTokens.space8),
          ]
        else
          Expanded(
            child: ListView.separated(
              itemCount: snapshot.businesses.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: DesignTokens.space8),
              itemBuilder: (context, index) {
                final business = snapshot.businesses[index];
                return _BusinessReferenceTile(
                  index: index,
                  business: business,
                  selected: business.id == viewModel.selectedBusinessId,
                  viewModel: viewModel,
                );
              },
            ),
          ),
      ],
    );
    return DecoratedBox(
      key: const Key('public-business-reference-panel'),
      decoration: BoxDecoration(
        color: DesignTokens.surface1,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space16),
        child: content,
      ),
    );
  }
}

class _ReferenceListHeader extends StatelessWidget {
  const _ReferenceListHeader({required this.viewModel});

  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final snapshot = viewModel.snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: DesignTokens.space8,
          runSpacing: DesignTokens.space4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              '公開情報の参考一覧',
              style: TextStyle(
                color: DesignTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DesignTokens.orange.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(DesignTokens.radiusCircle),
              ),
              child: Text(
                '${snapshot.businesses.length}件',
                key: const Key('public-business-reference-count'),
                style: const TextStyle(
                  color: DesignTokens.orangeLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.space8),
        Text(
          snapshot.coverageNote,
          style: const TextStyle(
            color: DesignTokens.textSecondary,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        const SizedBox(height: DesignTokens.space4),
        Text(
          snapshot.ownershipNote,
          style: const TextStyle(
            color: DesignTokens.orangeLight,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.6,
          ),
        ),
        TextButton.icon(
          key: const Key('public-business-source-link'),
          onPressed: () =>
              _openWithFeedback(context, viewModel.openPublicSource()),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            foregroundColor: DesignTokens.orange,
          ),
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text('${snapshot.publicSourceLabel}（${snapshot.license}）'),
        ),
      ],
    );
  }
}

class _BusinessReferenceTile extends StatelessWidget {
  const _BusinessReferenceTile({
    required this.index,
    required this.business,
    required this.selected,
    required this.viewModel,
  });

  final int index;
  final PublicBusinessReference business;
  final bool selected;
  final LocalBusinessMapViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? DesignTokens.orange : DesignTokens.indigo;
    return Material(
      key: Key('public-business-reference-$index'),
      color: selected ? const Color(0xFF211A18) : DesignTokens.surface2,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: InkWell(
        onTap: () => viewModel.selectBusiness(business.id),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.storefront, color: accent, size: 22),
                  const SizedBox(width: DesignTokens.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.name,
                          style: const TextStyle(
                            color: DesignTokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          '${business.category}・中心点から約${business.distanceMeters}m',
                          style: const TextStyle(
                            color: DesignTokens.textSecondary,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space8),
              Wrap(
                spacing: DesignTokens.space8,
                runSpacing: DesignTokens.space4,
                children: [
                  _ReferenceChip(
                    label: business.ownershipLabel,
                    color: DesignTokens.orange,
                  ),
                  _ReferenceChip(
                    label: business.sourceLabel,
                    color: DesignTokens.indigoLight,
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.space8),
              Text(
                business.address,
                style: const TextStyle(
                  color: DesignTokens.textSecondary,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: Key('public-business-source-$index'),
                  onPressed: () => _openWithFeedback(
                    context,
                    viewModel.openBusinessSource(business.id),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: DesignTokens.orange,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 15),
                  label: const Text('OSMで確認'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceChip extends StatelessWidget {
  const _ReferenceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, height: 1.5),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DesignTokens.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
        border: Border.all(color: DesignTokens.red.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space12),
        child: Text(
          message,
          style: const TextStyle(
            color: DesignTokens.textOnDark,
            fontSize: 12,
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _EmptyReferenceList extends StatelessWidget {
  const _EmptyReferenceList();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: DesignTokens.space24),
      child: Column(
        children: [
          Icon(Icons.map_outlined, color: DesignTokens.orange, size: 48),
          SizedBox(height: DesignTokens.space12),
          Text(
            '公開参考情報はまだありません',
            style: TextStyle(
              color: DesignTokens.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openWithFeedback(
  BuildContext context,
  Future<bool> action,
) async {
  final opened = await action;
  if (!context.mounted || opened) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('出典リンクを開けませんでした。'),
      backgroundColor: DesignTokens.red,
    ),
  );
}
