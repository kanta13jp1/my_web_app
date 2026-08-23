import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
  const TigerReviewLaneStatusPage({super.key, required this.kind, this.loader});

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
                          const SizedBox(height: 18),
                          _SectionHeading(
                            title: 'レビュー履歴',
                            count: status.history.length,
                            emptyLabel: '公開済みのレビュー履歴はありません。',
                          ),
                        ],
                      ),
                    ),
                    if (status.history.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: SliverList.builder(
                          itemCount: status.history.length,
                          itemBuilder: (context, index) => _HistoryReviewCard(
                            kind: kind,
                            review: status.history[index],
                          ),
                        ),
                      ),
                    if (status.entries.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          18,
                          horizontalPadding,
                          8,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            _entriesTitle(kind),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
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

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.count,
    required this.emptyLabel,
  });

  final String title;
  final int count;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Chip(label: Text('全$count件')),
          ],
        ),
        if (count == 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(emptyLabel),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }
}

class _HistoryReviewCard extends StatelessWidget {
  const _HistoryReviewCard({required this.kind, required this.review});

  final TigerReviewLane kind;
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final subject = _asMap(review['subject']);
    final reviewer = _asMap(review['reviewer']);
    final countermeasure = _asMap(review['countermeasure']);
    final findings = _asMapList(review['findings']);
    final resolvedIds = (countermeasure['resolved_finding_ids'] as List?)
            ?.map((value) => value.toString())
            .toSet() ??
        <String>{};
    final state = countermeasure['state']?.toString() ??
        review['status']?.toString() ??
        'unverified';
    final cycleId = review['cycle_id']?.toString() ?? 'unknown';
    final title = subject['title']?.toString().trim();
    final subjectLabel = title == null || title.isEmpty
        ? subject['id']?.toString() ?? '対象不明'
        : title;
    final reviewerName = reviewer['name']?.toString() ?? '担当虎不明';
    final seat = reviewer['seat'];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: Key('tiger-history-${kind.lane}-$cycleId'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        title: Text(
          subjectLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(_formatTimestamp(review['started_at'])),
              Text('$reviewerName${seat == null ? '' : '（席 $seat）'}'),
              _TraceBadge(state: state, label: countermeasure['label']),
            ],
          ),
        ),
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: _HistoryDetails(
              cycleId: cycleId,
              review: review,
              countermeasure: countermeasure,
              findings: findings,
              resolvedIds: resolvedIds,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetails extends StatelessWidget {
  const _HistoryDetails({
    required this.cycleId,
    required this.review,
    required this.countermeasure,
    required this.findings,
    required this.resolvedIds,
  });

  final String cycleId;
  final Map<String, dynamic> review;
  final Map<String, dynamic> countermeasure;
  final List<Map<String, dynamic>> findings;
  final Set<String> resolvedIds;

  @override
  Widget build(BuildContext context) {
    final issue = _asMap(countermeasure['issue']);
    final issueUrl = Uri.tryParse(issue['url']?.toString() ?? '');
    final files = (countermeasure['files'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final validationMessages = (countermeasure['validation_messages'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final state = countermeasure['state']?.toString() ?? 'unverified';
    final issueRequired = state == 'issue_required' || state == 'missing_issue';
    final requiresFollowUp = <String>{
      'follow_up_issued',
      'issue_tracking',
      'issue_closed',
      'issue_required',
      'missing_issue',
    }.contains(state);
    final implementation = _asMap(countermeasure['implementation']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        Text('レビューID: $cycleId'),
        Text('レビュー結果: ${review['review_status'] ?? '—'}'),
        Text('検証: ${review['validation_status'] ?? '—'}'),
        if ((countermeasure['detail']?.toString() ?? '')
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(countermeasure['detail'].toString()),
        ],
        if ((countermeasure['summary']?.toString() ?? '')
            .isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('対策記録: ${countermeasure['summary']}'),
        ],
        if (files.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('変更ファイル: ${files.join('、')}'),
        ],
        if (validationMessages.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('検証記録: ${validationMessages.join(' / ')}'),
        ],
        if (implementation.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text('本番反映コミット: ${implementation['commit_sha'] ?? '—'}'),
          Text('リリース検証: ${implementation['release_status'] ?? '—'}'),
          if ((implementation['workflow_run']?.toString() ?? '').isNotEmpty)
            Text('Workflow: ${implementation['workflow_run']}'),
          if ((implementation['production_url']?.toString() ?? '').isNotEmpty)
            Text('公開先: ${implementation['production_url']}'),
        ],
        const SizedBox(height: 14),
        Text(
          '指摘と対策状況',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (findings.isEmpty)
          const Text('有効な指摘は記録されていません。')
        else
          for (final finding in findings)
            _FindingTrace(
              finding: finding,
              implemented: resolvedIds.contains(
                finding['finding_id']?.toString(),
              ),
              requiresFollowUp: requiresFollowUp,
            ),
        const SizedBox(height: 12),
        if (issueUrl != null && issueUrl.isAbsolute)
          FilledButton.tonalIcon(
            key: Key('tiger-history-issue-$cycleId'),
            onPressed: () => unawaited(
              launchUrl(issueUrl, mode: LaunchMode.externalApplication),
            ),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              '対応Issue #${issue['number'] ?? ''}を開く'
              '${issue['github_state'] == 'CLOSED' ? '（終了）' : ''}',
            ),
          )
        else if (issueRequired)
          Text(
            'Issue未発行（公開データ不整合）',
            key: Key('tiger-history-issue-missing-$cycleId'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }
}

class _FindingTrace extends StatelessWidget {
  const _FindingTrace({
    required this.finding,
    required this.implemented,
    required this.requiresFollowUp,
  });

  final Map<String, dynamic> finding;
  final bool implemented;
  final bool requiresFollowUp;

  @override
  Widget build(BuildContext context) {
    final action = finding['suggested_action']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            implemented ? Icons.check_circle_outline : Icons.pending_actions,
            size: 20,
            color: implemented
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(finding['summary']?.toString() ?? '指摘内容なし'),
                if (action.isNotEmpty)
                  Text(
                    '推奨対策: $action',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  implemented
                      ? '対策実施済み'
                      : requiresFollowUp
                          ? '未対策'
                          : '個別対策の紐付けなし',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceBadge extends StatelessWidget {
  const _TraceBadge({required this.state, required this.label});

  final String state;
  final Object? label;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (state) {
      'production_verified' || 'implemented' => (
          Colors.green.shade100,
          Colors.green.shade900
        ),
      'partially_implemented' => (
          Colors.orange.shade100,
          Colors.orange.shade900,
        ),
      'follow_up_issued' || 'issue_tracking' => (
          Colors.amber.shade100,
          Colors.amber.shade900
        ),
      'issue_closed' => (Colors.blue.shade100, Colors.blue.shade900),
      'issue_required' || 'missing_issue' => (
          Theme.of(context).colorScheme.errorContainer,
          Theme.of(context).colorScheme.onErrorContainer,
        ),
      _ => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label?.toString() ?? state,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

String _formatTimestamp(Object? value) {
  final raw = value?.toString() ?? '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw.isEmpty ? '日時不明' : raw;
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
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
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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

List<Map<String, dynamic>> _asMapList(Object? value) {
  return value is List
      ? value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
}
