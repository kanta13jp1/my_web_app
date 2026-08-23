import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tiger_review_lane_status.dart';

typedef TigerLaneStatusLoader = Future<TigerReviewLaneStatus> Function();

enum TigerReviewLane {
  reviewers(
    lane: 'reviewer_league',
    route: '/tiger-reviewers',
    asset: 'assets/data/tiger_reviewer_league_status.json',
    title: '虎レビュアー成績',
    subtitle: '125名のレビュー効用・所属部・選出可否',
    icon: Icons.groups_2_outlined,
  ),
  site(
    lane: 'site_review',
    route: '/tiger-site-reviews',
    asset: 'assets/data/tiger_site_review_status.json',
    title: 'サイト全体の虎レビュー',
    subtitle: '選出虎1名による事業全体の評価と指摘',
    icon: Icons.public_outlined,
  ),
  courses(
    lane: 'course_review',
    route: '/tiger-course-reviews',
    asset: 'assets/data/tiger_course_review_status.json',
    title: 'AI大学講座の虎レビュー',
    subtitle: '選出虎1名による講座評価と1〜5部リーグ',
    icon: Icons.school_outlined,
  ),
  features(
    lane: 'feature_review',
    route: '/tiger-feature-reviews',
    asset: 'assets/data/tiger_feature_review_status.json',
    title: '機能の虎レビュー',
    subtitle: '選出虎1名による機能評価と1〜5部リーグ',
    icon: Icons.extension_outlined,
  );

  const TigerReviewLane({
    required this.lane,
    required this.route,
    required this.asset,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String lane;
  final String route;
  final String asset;
  final String title;
  final String subtitle;
  final IconData icon;
}

class TigerReviewHubPage extends StatelessWidget {
  const TigerReviewHubPage({super.key});

  static const routeName = '/tiger-review-status';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('令和の虎レビューセンター')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Text(
            '4系統は独立して実行・集計・公開されます',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          const Text('各レビューは125名から現在の状況に合う虎1名だけを選出します。'),
          const SizedBox(height: 20),
          for (final lane in TigerReviewLane.values)
            Card(
              child: ListTile(
                key: Key('tiger-lane-${lane.lane}'),
                leading: Icon(lane.icon),
                title: Text(lane.title),
                subtitle: Text(lane.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(lane.route),
              ),
            ),
        ],
      ),
    );
  }
}

class TigerReviewLaneStatusPage extends StatefulWidget {
  const TigerReviewLaneStatusPage({
    super.key,
    required this.kind,
    this.loader,
  });

  final TigerReviewLane kind;
  final TigerLaneStatusLoader? loader;

  @override
  State<TigerReviewLaneStatusPage> createState() =>
      _TigerReviewLaneStatusPageState();
}

class _TigerReviewLaneStatusPageState extends State<TigerReviewLaneStatusPage> {
  late Future<TigerReviewLaneStatus> _status;

  @override
  void initState() {
    super.initState();
    _status = _load();
  }

  Future<TigerReviewLaneStatus> _load() {
    if (widget.loader != null) return widget.loader!();
    return rootBundle
        .loadString(widget.kind.asset)
        .then(TigerReviewLaneStatus.fromJsonString);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _status = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.title),
        actions: <Widget>[
          IconButton(
            key: Key('tiger-lane-refresh-${widget.kind.lane}'),
            tooltip: '公開状況を再読み込み',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<TigerReviewLaneStatus>(
        future: _status,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('読み込み直す'),
              ),
            );
          }
          final status = snapshot.requireData;
          if (status.lane != widget.kind.lane) {
            return const Center(child: Text('公開データの系統が一致しません。'));
          }
          return _LaneContent(
            kind: widget.kind,
            status: status,
            onRefresh: _reload,
          );
        },
      ),
    );
  }
}

class _LaneContent extends StatelessWidget {
  const _LaneContent({
    required this.kind,
    required this.status,
    required this.onRefresh,
  });

  final TigerReviewLane kind;
  final TigerReviewLaneStatus status;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 720 ? 24.0 : 12.0;
        return SelectionArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: CustomScrollView(
                  key: Key('tiger-lane-content-${kind.lane}'),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        16,
                        horizontalPadding,
                        0,
                      ),
                      sliver: SliverList.list(
                        children: <Widget>[
                          _Hero(kind: kind, status: status),
                          const SizedBox(height: 12),
                          if (status.pool.isNotEmpty)
                            _PoolCard(pool: status.pool),
                          if (status.pool.isNotEmpty)
                            const SizedBox(height: 12),
                          _LatestCard(kind: kind, latest: status.latest),
                          if (status.entries.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 18),
                            Text(
                              _entriesTitle(kind),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    if (status.entries.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: SliverList.builder(
                          itemCount: status.entries.length,
                          itemBuilder: (context, index) => _StandingTile(
                            kind: kind,
                            entry: status.entries[index],
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        status.disclaimer.isEmpty ? 8 : 16,
                        horizontalPadding,
                        24,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: status.disclaimer.isEmpty
                            ? const SizedBox.shrink()
                            : Text(
                                status.disclaimer,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.kind, required this.status});

  final TigerReviewLane kind;
  final TigerReviewLaneStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status.automation.status == 'ACTIVE';
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(kind.icon, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    kind.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                Chip(label: Text(active ? '稼働中' : status.automation.status)),
              ],
            ),
            const SizedBox(height: 8),
            Text(kind.subtitle),
            const SizedBox(height: 10),
            Text(status.automation.schedule),
          ],
        ),
      ),
    );
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.pool});

  final Map<String, dynamic> pool;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 12,
          children: <Widget>[
            _Metric(label: '総数', value: pool['total']),
            _Metric(label: '選出可能', value: pool['eligible']),
            for (var division = 1; division <= 5; division++)
              _Metric(label: '$division部', value: pool['division_$division']),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value?.toString() ?? '—',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _LatestCard extends StatelessWidget {
  const _LatestCard({required this.kind, required this.latest});

  final TigerReviewLane kind;
  final Map<String, dynamic>? latest;

  @override
  Widget build(BuildContext context) {
    if (latest == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text('最初のレビュー結果を待っています。'),
        ),
      );
    }
    final reviewer = _asMap(latest!['reviewer']);
    final subject = switch (kind) {
      TigerReviewLane.courses => _asMap(latest!['course'])['title'],
      TigerReviewLane.features => _asMap(latest!['feature'])['title'],
      _ => _asMap(latest!['surface'])['slug'],
    };
    final findings = latest!['top_findings'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '最新の結果',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (subject != null) Text('対象: $subject'),
            if (reviewer.isNotEmpty)
              Text('担当虎: ${reviewer['name']}（席 ${reviewer['seat']}）'),
            Text('結果: ${latest!['status'] ?? latest!['validation'] ?? '—'}'),
            if (findings is List && findings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              for (final finding in findings.whereType<Map>().take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• ${finding['summary'] ?? ''}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.kind, required this.entry});

  final TigerReviewLane kind;
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final title = switch (kind) {
      TigerReviewLane.reviewers => entry['name'],
      TigerReviewLane.courses => entry['title'],
      TigerReviewLane.features => entry['title'],
      TigerReviewLane.site => '',
    };
    final detail = switch (kind) {
      TigerReviewLane.reviewers =>
        '席 ${entry['seat']}・担当 ${entry['completed_cycles']}回',
      TigerReviewLane.courses =>
        '${entry['provider']}・レビュー ${entry['completed_cycles']}回',
      TigerReviewLane.features =>
        '${entry['kind']}・レビュー ${entry['completed_cycles']}回',
      TigerReviewLane.site => '',
    };
    return Card(
      child: ListTile(
        key: Key(
          'tiger-${kind.lane}-${entry['seat'] ?? entry['content_id'] ?? entry['slug']}',
        ),
        title: Text(title?.toString() ?? ''),
        subtitle: Text(detail),
        leading: CircleAvatar(child: Text('${entry['division'] ?? 3}')),
        trailing: Text(
          entry['eligible'] == false
              ? '選出外'
              : '${entry['utility_score'] ?? '暫定'}点',
        ),
      ),
    );
  }
}

String _entriesTitle(TigerReviewLane kind) => switch (kind) {
      TigerReviewLane.reviewers => '虎レビュアー 1〜5部',
      TigerReviewLane.courses => 'AI大学講座 1〜5部',
      TigerReviewLane.features => '機能 1〜5部',
      TigerReviewLane.site => '',
    };

Map<String, dynamic> _asMap(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}
