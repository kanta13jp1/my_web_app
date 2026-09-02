import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tiger_review_status.dart';

typedef TigerReviewStatusLoader = Future<TigerReviewStatusSnapshot> Function();

class TigerReviewStatusPage extends StatefulWidget {
  const TigerReviewStatusPage({super.key, this.loader});

  static const routeName = '/tiger-review-status';
  static const assetPath = 'assets/data/tiger_review_status.json';

  final TigerReviewStatusLoader? loader;

  @override
  State<TigerReviewStatusPage> createState() => _TigerReviewStatusPageState();
}

class _TigerReviewStatusPageState extends State<TigerReviewStatusPage> {
  late Future<TigerReviewStatusSnapshot> _snapshot;
  String _divisionFilter = 'all';

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  Future<TigerReviewStatusSnapshot> _load() {
    if (widget.loader != null) return widget.loader!();
    return rootBundle
        .loadString(TigerReviewStatusPage.assetPath)
        .then(TigerReviewStatusSnapshot.fromJsonString);
  }

  Future<void> _reload() async {
    final nextSnapshot = _load();
    setState(() {
      _snapshot = nextSnapshot;
    });
    await nextSnapshot;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('機能・講座・虎 5部リーグ'),
        actions: <Widget>[
          IconButton(
            key: const Key('tiger-review-refresh'),
            tooltip: '公開状況を再読み込み',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<TigerReviewStatusSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(onRetry: _reload);
          }
          return _content(context, snapshot.requireData);
        },
      ),
    );
  }

  Widget _content(BuildContext context, TigerReviewStatusSnapshot snapshot) {
    final reviewers = snapshot.reviewers.where((reviewer) {
      return switch (_divisionFilter) {
        'eligible' => reviewer.eligible,
        'division_1' => reviewer.division == 1,
        'division_2' => reviewer.division == 2,
        'division_3' => reviewer.division == 3,
        'division_4' => reviewer.division == 4,
        'division_5' => reviewer.division == 5,
        _ => true,
      };
    }).toList(growable: false);

    return SelectionArea(
      child: RefreshIndicator(
        onRefresh: _reload,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth < 560 ? 12.0 : 24.0;
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _bounded(
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 20, padding, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _Hero(snapshot: snapshot),
                          const SizedBox(height: 16),
                          _metricGrid(constraints, snapshot),
                          const SizedBox(height: 16),
                          _LatestCycleCard(cycle: snapshot.latestCycle),
                          const SizedBox(height: 16),
                          _PolicyCard(
                            reviewerPool: snapshot.pool,
                            featurePool: snapshot.featurePool,
                          ),
                          const SizedBox(height: 20),
                          _FeatureLeague(
                            features: snapshot.features,
                            pool: snapshot.featurePool,
                          ),
                          const SizedBox(height: 20),
                          _CourseLeague(
                            courses: snapshot.courses,
                            pool: snapshot.coursePool,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'レビュー担当の虎 1〜5部',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '実績2回未満は暫定3部です。5部になった虎は次回の選出候補から外れます。',
                          ),
                          const SizedBox(height: 12),
                          _TierFilters(
                            selected: _divisionFilter,
                            onSelected: (value) {
                              setState(() => _divisionFilter = value);
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${reviewers.length}名を表示',
                            key: const Key('tiger-review-visible-count'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (reviewers.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('この条件に該当する虎はいません。')),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding, 0, padding, 12),
                    sliver: SliverList.builder(
                      itemCount: reviewers.length,
                      itemBuilder: (context, index) => _bounded(
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ReviewerCard(reviewer: reviewers[index]),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _bounded(
                    Padding(
                      padding: EdgeInsets.fromLTRB(padding, 6, padding, 28),
                      child: Text(
                        snapshot.disclaimer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metricGrid(
    BoxConstraints constraints,
    TigerReviewStatusSnapshot snapshot,
  ) {
    final width = constraints.maxWidth - (constraints.maxWidth < 560 ? 24 : 48);
    final columns = width >= 900
        ? 4
        : width >= 520
            ? 2
            : 1;
    const gap = 12.0;
    final cardWidth = (width - gap * (columns - 1)) / columns;
    final metrics = <_Metric>[
      _Metric(
        '1部',
        snapshot.pool.division1,
        Icons.workspace_premium_outlined,
        _divisionColor(1),
      ),
      _Metric(
        '2部',
        snapshot.pool.division2,
        Icons.trending_up,
        _divisionColor(2),
      ),
      _Metric('3部', snapshot.pool.division3, Icons.balance, _divisionColor(3)),
      _Metric(
        '4部',
        snapshot.pool.division4,
        Icons.warning_amber,
        _divisionColor(4),
      ),
      _Metric(
        '5部',
        snapshot.pool.division5,
        Icons.person_off_outlined,
        _divisionColor(5),
      ),
    ];
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: metrics
          .map(
            (item) => SizedBox(
              width: cardWidth,
              child: _MetricCard(metric: item),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _bounded(Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: child,
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.snapshot});

  final TigerReviewStatusSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final generatedAt = snapshot.generatedAt?.toLocal();
    return Semantics(
      container: true,
      label: '虎レビュー自動化の現在状況',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF111827), Color(0xFF1F2937)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _DarkBadge(
                  icon: Icons.schedule,
                  label: snapshot.automation.schedule,
                ),
                _DarkBadge(
                  icon: Icons.circle,
                  iconColor: const Color(0xFF34D399),
                  label: snapshot.automation.status,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'サイト機能も、AI講座も、担当する虎も、成果で1〜5部へ。',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              '1時間ごとに機能1件・講座1件・虎1名をレビューし、有用性を実績で採点。'
              '実績2回から所属を確定し、5部は次回レビュー候補から外れます。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.55,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              generatedAt == null
                  ? '公開スナップショット時刻: 未取得'
                  : '公開スナップショット: ${_date(generatedAt)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.62)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: metric.color.withValues(alpha: 0.12),
              foregroundColor: metric.color,
              child: Icon(metric.icon),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(metric.label),
                Text(
                  '${metric.value}名',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: metric.color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestCycleCard extends StatelessWidget {
  const _LatestCycleCard({required this.cycle});

  final TigerReviewCycle? cycle;

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return const Card(
        key: Key('tiger-review-waiting'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Icon(Icons.hourglass_empty)),
            title: Text('初回レビュー待ち'),
            subtitle: Text('最初のレビュー完了後、担当虎と指摘状況がここに表示されます。'),
          ),
        ),
      );
    }
    return Card(
      key: const Key('tiger-review-latest-cycle'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.rate_review_outlined),
                const SizedBox(width: 8),
                Text(
                  '最新レビュー',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Chip(label: Text(_statusLabel(cycle!.status))),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final facts = <Widget>[
                  _Fact(
                    label: '担当虎',
                    value: '${cycle!.reviewerName}（席${cycle!.reviewerSeat}）',
                    detail:
                        '${cycle!.division}部 / 選出 ${_score(cycle!.selectionScore)} / 今回効用 ${_score(cycle!.cycleUtility)}',
                  ),
                  _Fact(
                    label: '対象',
                    value:
                        cycle!.surfaceSlug.isEmpty ? '不明' : cycle!.surfaceSlug,
                    detail:
                        '指摘 ${cycle!.findingCount}件 / 検証 ${cycle!.validation}',
                  ),
                ];
                if (constraints.maxWidth >= 720) {
                  return Row(
                    children: <Widget>[
                      Expanded(child: facts[0]),
                      const SizedBox(width: 12),
                      Expanded(child: facts[1]),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[
                    facts[0],
                    const SizedBox(height: 12),
                    facts[1],
                  ],
                );
              },
            ),
            if (cycle!.topFindings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              const Text('上位指摘', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...cycle!.topFindings.map(
                (finding) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('・${finding.summary}'),
                ),
              ),
            ],
            if (cycle!.featureReview != null) ...<Widget>[
              const SizedBox(height: 14),
              _FeatureCycleCard(feature: cycle!.featureReview!),
            ],
            if (cycle!.courseReview != null) ...<Widget>[
              const SizedBox(height: 14),
              _CourseCycleCard(course: cycle!.courseReview!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _FeatureCycleCard extends StatelessWidget {
  const _FeatureCycleCard({required this.feature});

  final TigerFeatureReviewCycle feature;

  @override
  Widget build(BuildContext context) {
    final color = _divisionColor(feature.division);
    return Container(
      key: const Key('tiger-review-latest-feature'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('対象機能', style: TextStyle(fontWeight: FontWeight.w800)),
              _DivisionBadge(division: feature.division, provisional: false),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            feature.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            '今回効用 ${_score(feature.cycleUtility)} / '
            '累積 ${_score(feature.aggregateUtility)}',
          ),
          if (feature.reason.isNotEmpty) Text(feature.reason),
        ],
      ),
    );
  }
}

class _CourseCycleCard extends StatelessWidget {
  const _CourseCycleCard({required this.course});

  final TigerCourseReviewCycle course;

  @override
  Widget build(BuildContext context) {
    final color = _divisionColor(course.division);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text('対象講座', style: TextStyle(fontWeight: FontWeight.w800)),
              _DivisionBadge(division: course.division, provisional: false),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            course.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text('${course.provider} / 今回効用 ${_score(course.cycleUtility)}'),
          if (course.reason.isNotEmpty) Text(course.reason),
        ],
      ),
    );
  }
}

class _FeatureLeague extends StatelessWidget {
  const _FeatureLeague({required this.features, required this.pool});

  final List<TigerReviewedFeature> features;
  final TigerReviewPool pool;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'サイト機能 1〜5部',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          '毎時1機能を採点し、実績2回から所属を確定します。'
          '5部は次回レビュー対象外となり、停止・統合・再設計の候補になります。',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (var division = 1; division <= 5; division += 1)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: _divisionColor(division),
                  foregroundColor: Colors.white,
                  child: Text('$division'),
                ),
                label: Text('${_divisionCount(pool, division)}機能'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          key: const Key('tiger-review-feature-league'),
          margin: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (final feature in features)
                ListTile(
                  key: Key('tiger-reviewed-feature-${feature.slug}'),
                  leading: CircleAvatar(
                    backgroundColor: _divisionColor(feature.division)
                        .withValues(alpha: 0.12),
                    foregroundColor: _divisionColor(feature.division),
                    child: Text('${feature.division}'),
                  ),
                  title: Text(_featureLabel(feature)),
                  subtitle: Text(
                    '${_featureKind(feature.kind)} / ${feature.reason}',
                  ),
                  trailing: Text(_score(feature.utilityScore)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CourseLeague extends StatelessWidget {
  const _CourseLeague({required this.courses, required this.pool});

  final List<TigerReviewedCourse> courses;
  final TigerReviewPool pool;

  @override
  Widget build(BuildContext context) {
    final visible = courses.take(12).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'AI大学講座 1〜5部',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text('毎時1講座を採点し、実績2回から所属を確定します。5部は改訂・停止候補です。'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (var division = 1; division <= 5; division += 1)
              Chip(
                avatar: CircleAvatar(
                  backgroundColor: _divisionColor(division),
                  foregroundColor: Colors.white,
                  child: Text('$division'),
                ),
                label: Text('${_divisionCount(pool, division)}講座'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const Card(
            key: Key('tiger-review-course-waiting'),
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.school_outlined),
              title: Text('初回の講座レビュー待ち'),
              subtitle: Text('最初の時間レビュー後、講座名・担当虎・有用性が表示されます。'),
            ),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (final course in visible)
                  ListTile(
                    key: Key('tiger-reviewed-course-${course.contentId}'),
                    leading: CircleAvatar(
                      backgroundColor: _divisionColor(course.division)
                          .withValues(alpha: 0.12),
                      foregroundColor: _divisionColor(course.division),
                      child: Text('${course.division}'),
                    ),
                    title: Text(course.title),
                    subtitle: Text('${course.provider} / ${course.reason}'),
                    trailing: Text(_score(course.utilityScore)),
                  ),
                if (courses.length > visible.length)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('レビュー済み${pool.total}講座のうち上位12件を表示'),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

int _divisionCount(TigerReviewPool pool, int division) => switch (division) {
      1 => pool.division1,
      2 => pool.division2,
      3 => pool.division3,
      4 => pool.division4,
      _ => pool.division5,
    };

class _PolicyCard extends StatelessWidget {
  const _PolicyCard({required this.reviewerPool, required this.featurePool});

  final TigerReviewPool reviewerPool;
  final TigerReviewPool featurePool;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '1〜5部の配属ルール',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '実績2回から、効用80点以上=1部、65点以上=2部、50点以上=3部、'
              '35点以上=4部、35点未満=5部です。実績2回未満は暫定3部です。',
            ),
            const SizedBox(height: 8),
            Text(
              '現在は${featurePool.eligible}/${featurePool.total}機能と、'
              '${reviewerPool.eligible}/${reviewerPool.total}名の虎が選出可能です。'
              '虎の候補枯渇を防ぐ安全下限は${reviewerPool.minimumEligiblePool}名です。',
            ),
            const SizedBox(height: 8),
            const Text('5部入りだけで機能を自動削除せず、停止・統合は別途レビューします。'),
          ],
        ),
      ),
    );
  }
}

class _TierFilters extends StatelessWidget {
  const _TierFilters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <(String, String)>[
      ('all', '全員'),
      ('eligible', '選出可能'),
      ('division_1', '1部'),
      ('division_2', '2部'),
      ('division_3', '3部'),
      ('division_4', '4部'),
      ('division_5', '5部'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (option) => ChoiceChip(
              key: Key('tiger-review-filter-${option.$1}'),
              label: Text(option.$2),
              selected: selected == option.$1,
              onSelected: (_) => onSelected(option.$1),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ReviewerCard extends StatelessWidget {
  const _ReviewerCard({required this.reviewer});

  final TigerReviewerStanding reviewer;

  @override
  Widget build(BuildContext context) {
    final color = _divisionColor(reviewer.division);
    return Card(
      key: Key('tiger-reviewer-${reviewer.seat}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Text('${reviewer.seat}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        reviewer.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      _DivisionBadge(
                        division: reviewer.division,
                        provisional: reviewer.provisional,
                      ),
                      if (reviewer.floorProtected)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('下限保護'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    reviewer.reason,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  reviewer.utilityScore == null
                      ? '未評価'
                      : '${reviewer.utilityScore!.toStringAsFixed(1)}点',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                Text(
                  '担当${reviewer.completedCycles}回',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkBadge extends StatelessWidget {
  const _DarkBadge({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DivisionBadge extends StatelessWidget {
  const _DivisionBadge({required this.division, required this.provisional});

  final int division;
  final bool provisional;

  @override
  Widget build(BuildContext context) {
    final color = _divisionColor(division);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        provisional ? '暫定$division部' : '$division部',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          const Text('虎レビュー状況を読み込めませんでした。'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('再試行'),
          ),
        ],
      ),
    );
  }
}

Color _divisionColor(int division) => switch (division) {
      1 => const Color(0xFF7C3AED),
      2 => const Color(0xFF2563EB),
      3 => const Color(0xFF0F766E),
      4 => const Color(0xFFD97706),
      _ => const Color(0xFFB91C1C),
    };

String _statusLabel(String status) => switch (status) {
      'fixed' => '修正済み',
      'review_only' => '指摘のみ',
      'blocked' => '停止',
      _ => status,
    };

String _featureLabel(TigerReviewedFeature feature) {
  if (feature.title.isNotEmpty && feature.title != feature.slug) {
    return feature.title;
  }
  return feature.slug.replaceAll('_', ' ');
}

String _featureKind(String kind) => switch (kind) {
      'page' => '公開ページ',
      'edge_function' => 'バックエンド機能',
      _ => kind,
    };

String _score(double? value) =>
    value == null ? '未評価' : '${value.toStringAsFixed(1)}点';

String _date(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}/${two(value.month)}/${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}
