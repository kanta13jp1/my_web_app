import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/tiger_review_lane_status.dart';
import '../models/tiger_reviewer_profile.dart';

typedef TigerLaneStatusLoader = Future<TigerReviewLaneStatus> Function();
typedef TigerReviewerProfileLoader = Future<TigerReviewerProfileCatalog>
    Function();

@visibleForTesting
const int tigerReviewerProfileSchemaVersion = 3;

@visibleForTesting
const int tigerReviewStatusSchemaVersion = 4;

@visibleForTesting
Uri buildTigerReviewAssetUri(
  Uri base,
  String asset, {
  required int schemaVersion,
}) =>
    base.resolve('assets/$asset?review_status_schema=$schemaVersion');

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
  const TigerReviewLaneStatusPage({
    super.key,
    required this.kind,
    this.loader,
    this.profileLoader,
  });

  final TigerReviewLane kind;
  final TigerLaneStatusLoader? loader;
  final TigerReviewerProfileLoader? profileLoader;

  @override
  State<TigerReviewLaneStatusPage> createState() =>
      _TigerReviewLaneStatusPageState();
}

class _TigerReviewLaneStatusPageState extends State<TigerReviewLaneStatusPage> {
  late Future<_TigerLanePageData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_TigerLanePageData> _load() async {
    final statusFuture = widget.loader != null
        ? widget.loader!()
        : _loadAsset(
            widget.kind.asset,
            schemaVersion: tigerReviewStatusSchemaVersion,
          ).then(TigerReviewLaneStatus.fromJsonString);
    final profilesFuture = widget.kind == TigerReviewLane.reviewers
        ? (widget.profileLoader?.call() ??
            _loadAsset(
              'assets/data/tiger_reviewer_profiles.json',
              schemaVersion: tigerReviewerProfileSchemaVersion,
            ).then(TigerReviewerProfileCatalog.fromJsonString))
        : Future<TigerReviewerProfileCatalog?>.value();
    final status = await statusFuture;
    final profiles = await profilesFuture;
    return _TigerLanePageData(status: status, profiles: profiles);
  }

  Future<String> _loadAsset(String asset, {required int schemaVersion}) async {
    if (!kIsWeb) return rootBundle.loadString(asset);

    // These JSON snapshots are refreshed by independent review automations.
    // Do not reuse a browser's previous asset response after a new release.
    final uri = buildTigerReviewAssetUri(
      Uri.base,
      asset,
      schemaVersion: schemaVersion,
    );
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FlutterError(
        'Failed to load Tiger review asset '
        '(${response.statusCode}): $uri',
      );
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() {
      _data = next;
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
      body: FutureBuilder<_TigerLanePageData>(
        future: _data,
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
          final data = snapshot.requireData;
          final status = data.status;
          if (status.lane != widget.kind.lane) {
            return const Center(child: Text('公開データの系統が一致しません。'));
          }
          return _LaneContent(
            kind: widget.kind,
            status: status,
            profiles: data.profiles,
            onRefresh: _reload,
          );
        },
      ),
    );
  }
}

class _TigerLanePageData {
  const _TigerLanePageData({required this.status, required this.profiles});

  final TigerReviewLaneStatus status;
  final TigerReviewerProfileCatalog? profiles;
}

class _LaneContent extends StatelessWidget {
  const _LaneContent({
    required this.kind,
    required this.status,
    required this.profiles,
    required this.onRefresh,
  });

  final TigerReviewLane kind;
  final TigerReviewLaneStatus status;
  final TigerReviewerProfileCatalog? profiles;
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
                          if (status.history.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 18),
                            _HistorySection(history: status.history),
                          ],
                          if (kind == TigerReviewLane.reviewers &&
                              profiles != null &&
                              profiles!.enrichmentRound > 0) ...<Widget>[
                            const SizedBox(height: 18),
                            _ProfileEnrichmentCard(catalog: profiles!),
                          ],
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
                            profile: profiles
                                ?.profilesBySeat[status.entries[index]['seat']],
                            profileSnapshotDate: profiles?.snapshotDate,
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        status.disclaimer.isEmpty &&
                                (profiles?.disclaimer.isEmpty ?? true)
                            ? 8
                            : 16,
                        horizontalPadding,
                        24,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: status.disclaimer.isEmpty &&
                                (profiles?.disclaimer.isEmpty ?? true)
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if (status.disclaimer.isNotEmpty)
                                    Text(
                                      status.disclaimer,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if (profiles?.disclaimer case final text?)
                                    if (text.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        text,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                ],
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

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.history});

  final List<TigerReviewHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'レビュー履歴・対策トレース',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('過去 ${history.length} 件。各指摘と、実施・検証の記録を確認できます。'),
            const SizedBox(height: 8),
            for (var index = 0; index < history.length; index++)
              _HistoryEntry(
                entry: history[index],
                initiallyExpanded: index == 0,
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry, required this.initiallyExpanded});

  final TigerReviewHistoryEntry entry;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final subject =
        entry.subject.title.isNotEmpty ? entry.subject.title : entry.subject.id;
    final reviewer = entry.reviewer.name.isEmpty
        ? '担当虎の記録なし'
        : '${entry.reviewer.name}（席 ${entry.reviewer.seat ?? '—'}）';
    final trace = entry.countermeasure;
    return ExpansionTile(
      key: Key('tiger-history-entry-${entry.cycleId}'),
      initiallyExpanded: initiallyExpanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(
        '${_historyDate(entry.startedAt)} ${subject.isEmpty ? 'レビュー' : subject}',
      ),
      subtitle: Text('${trace.label}・$reviewer'),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _TraceBadge(trace: trace),
              const SizedBox(height: 8),
              Text(
                'レビュー結果: ${entry.reviewStatus.isEmpty ? '—' : entry.reviewStatus} / 検証: ${entry.validationStatus.isEmpty ? '—' : entry.validationStatus}',
              ),
              if (trace.summary.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text('実施内容: ${trace.summary}'),
              ],
              if (trace.files.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text('変更ファイル: ${trace.files.join('、')}'),
              ],
              if (trace.implementation case final implementation?) ...<Widget>[
                if (implementation.prNumber case final prNumber?) ...<Widget>[
                  const SizedBox(height: 6),
                  Text('対策PR: #$prNumber'),
                ],
                if (implementation.commitSha.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '${_releasePrefix(trace)}コミット: ${implementation.commitSha}',
                  ),
                ],
                if (implementation.workflowRun.isNotEmpty)
                  Text(
                    '${_releasePrefix(trace)}workflow: ${implementation.workflowRun}',
                  ),
              ],
              if (trace.issue case final issue?) ...<Widget>[
                const SizedBox(height: 8),
                _IssueLink(issue: issue),
              ],
              if (entry.findings.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '指摘',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                for (final finding in entry.findings) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    '• ${finding.severity.toUpperCase()} ${finding.summary}',
                  ),
                  if (finding.suggestedAction.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 2),
                      child: Text('対応案: ${finding.suggestedAction}'),
                    ),
                ],
              ],
              if (trace.findingsWithoutIndividualTrace.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '個別の対応状況が未記録: ${trace.findingsWithoutIndividualTrace.join('、')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (trace.validationMessages.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  '検証記録',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                for (final message in trace.validationMessages)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('• $message'),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _releasePrefix(TigerCountermeasureTrace trace) {
  return trace.state == 'implemented' || trace.state == 'production_verified'
      ? '対策反映'
      : 'レビュー公開';
}

class _TraceBadge extends StatelessWidget {
  const _TraceBadge({required this.trace});

  final TigerCountermeasureTrace trace;

  @override
  Widget build(BuildContext context) {
    final color = switch (trace.state) {
      'production_verified' => Colors.green,
      'implemented' => Colors.green,
      'remediation_in_progress' => Colors.blue,
      'issue_tracking' || 'follow_up_issued' => Colors.orange,
      'issue_superseded' => Colors.blueGrey,
      'remediation_needs_attention' => Colors.red,
      'missing_issue' || 'issue_required' => Colors.red,
      'blocked' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Chip(
          avatar: Icon(Icons.track_changes_outlined, color: color),
          label: Text(trace.label),
        ),
        if (trace.detail.isNotEmpty) Text(trace.detail),
      ],
    );
  }
}

class _IssueLink extends StatelessWidget {
  const _IssueLink({required this.issue});

  final TigerFollowUpIssue issue;

  @override
  Widget build(BuildContext context) {
    final number = issue.number;
    final url = issue.url;
    if (number == null || url == null || !url.hasScheme) {
      return const Text('Issue情報の形式を確認できません。');
    }
    final stateLabel = switch (issue.remediationState) {
      'production_verified' => '対策済み・本番検証済み',
      'in_progress' => '対策中',
      'queued' => '対策待ち',
      'needs_attention' => '要確認',
      'closed_pending_proof' => '終了・反映証拠確認待ち',
      'superseded' => '重複統合済み・修正完了ではありません',
      _ when issue.isOpen => '未対策・追跡中',
      _ when issue.isClosed => '終了・対策確認待ち',
      _ => '状態確認待ち',
    };
    return OutlinedButton.icon(
      key: Key('tiger-review-issue-$number'),
      onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text('Issue #$numberを開く（$stateLabel）'),
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
  const _StandingTile({
    required this.kind,
    required this.entry,
    required this.profile,
    required this.profileSnapshotDate,
  });

  final TigerReviewLane kind;
  final Map<String, dynamic> entry;
  final TigerReviewerProfile? profile;
  final DateTime? profileSnapshotDate;

  @override
  Widget build(BuildContext context) {
    if (kind == TigerReviewLane.reviewers) {
      return _ReviewerStandingTile(
        entry: entry,
        profile: profile,
        profileSnapshotDate: profileSnapshotDate,
      );
    }
    final title = switch (kind) {
      TigerReviewLane.reviewers => '',
      TigerReviewLane.courses => entry['title'],
      TigerReviewLane.features => entry['title'],
      TigerReviewLane.site => '',
    };
    final detail = switch (kind) {
      TigerReviewLane.reviewers => '',
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

class _ReviewerStandingTile extends StatelessWidget {
  const _ReviewerStandingTile({
    required this.entry,
    required this.profile,
    required this.profileSnapshotDate,
  });

  final Map<String, dynamic> entry;
  final TigerReviewerProfile? profile;
  final DateTime? profileSnapshotDate;

  @override
  Widget build(BuildContext context) {
    final seat = entry['seat'];
    final score = entry['eligible'] == false
        ? '選出外'
        : '${entry['utility_score'] ?? '暫定'}点';
    return Card(
      child: ExpansionTile(
        key: Key('tiger-reviewer_league-$seat'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        leading: CircleAvatar(child: Text('${entry['division'] ?? 3}')),
        title: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                entry['name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(score, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        subtitle: Text('席 $seat・担当 ${entry['completed_cycles']}回'),
        children: <Widget>[
          if (profile == null)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('公開プロフィール情報を確認できません。'),
            )
          else
            _ReviewerProfileDetails(
              profile: profile!,
              snapshotDate: profileSnapshotDate,
            ),
        ],
      ),
    );
  }
}

class _ProfileEnrichmentCard extends StatelessWidget {
  const _ProfileEnrichmentCard({required this.catalog});

  final TigerReviewerProfileCatalog catalog;

  @override
  Widget build(BuildContext context) {
    final nextBatch = catalog.nextBatchNames;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'プロフィール拡充ループ 第${catalog.enrichmentRound}回',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: <Widget>[
                Text(
                  '平均充実度 ${catalog.averageProfileCompletenessPercent.toStringAsFixed(1)}%',
                ),
                Text(
                  '平均レビュー反映度 ${catalog.averageReviewReflectionPercent.toStringAsFixed(1)}%',
                ),
                Text('生年月日確認済み ${catalog.verifiedBirthDates}名'),
              ],
            ),
            if (nextBatch.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('次回の優先調査: ${nextBatch.join('、')}'),
            ],
            const SizedBox(height: 6),
            const Text('一次公開情報が増えるほど、虎固有の重点観点をレビューへ段階的に反映します。'),
          ],
        ),
      ),
    );
  }
}

class _ReviewerProfileDetails extends StatelessWidget {
  const _ReviewerProfileDetails({
    required this.profile,
    required this.snapshotDate,
  });

  final TigerReviewerProfile profile;
  final DateTime? snapshotDate;

  @override
  Widget build(BuildContext context) {
    final profileUrl = profile.profileUrl;
    final evidenceLinks = profile.evidenceLinks.toList(growable: true);
    if (evidenceLinks.isEmpty && profileUrl != null && profileUrl.hasScheme) {
      evidenceLinks.add(
        TigerReviewerEvidenceLink(label: '公開プロフィール', url: profileUrl),
      );
    }
    final birthSource = profile.birthDateSourceUrl;
    if (birthSource != null &&
        birthSource.hasScheme &&
        !evidenceLinks.any((link) => link.url == birthSource)) {
      evidenceLinks.add(
        TigerReviewerEvidenceLink(label: '生年月日', url: birthSource),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        _ProfileFact(label: '年齢', value: profile.ageLabel(snapshotDate)),
        _ProfileFact(
          label: '肩書き',
          value: profile.companyRole.isEmpty ? '公開情報未確認' : profile.companyRole,
        ),
        _ProfileFact(
          label: '事業内容',
          value: profile.businessSummary.isEmpty
              ? '公開情報未確認'
              : profile.businessSummary,
        ),
        _ProfileFact(
          label: '出演実績',
          value: '出演 ${profile.appearances}回・出資 ${profile.investmentCount}回',
        ),
        _ProfileFact(
          label: '在籍区分',
          value: profile.rosterStatus == 'current' ? '現役虎' : '歴代虎',
        ),
        _ProfileFact(
          label: '充実度',
          value: '${profile.profileCompletenessPercent}%',
        ),
        _ProfileFact(
          label: 'レビュー反映',
          value:
              '${profile.reviewReflectionPercent}%（${profile.reviewReflectionLabel}）',
        ),
        if (profile.reviewFocusLabels.isNotEmpty)
          _ProfileFact(
            label: '重点確認',
            value: profile.reviewFocusLabels.join('・'),
          ),
        if (profile.reviewApplicationRule.isNotEmpty)
          _ProfileFact(label: '適用ルール', value: profile.reviewApplicationRule),
        if (profile.reviewQuestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('レビュー質問例', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final question in profile.reviewQuestions.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $question'),
            ),
        ],
        if (profile.nextResearchTargets.isNotEmpty)
          _ProfileFact(
            label: '次回調査',
            value: profile.nextResearchTargets.join('・'),
          ),
        if (profile.businessDomains.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('事業分野', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: <Widget>[
              for (final domain in profile.businessDomains)
                Chip(visualDensity: VisualDensity.compact, label: Text(domain)),
            ],
          ),
        ],
        if (profile.publicViewpointSummary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          _ProfileFact(label: '審査姿勢', value: profile.publicViewpointSummary),
        ],
        if (evidenceLinks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text('根拠URL', style: Theme.of(context).textTheme.labelLarge),
          for (final (index, link) in evidenceLinks.indexed)
            TextButton.icon(
              key: Key(
                index == 0
                    ? 'tiger-profile-source-${profile.seat}'
                    : 'tiger-profile-source-${profile.seat}-$index',
              ),
              onPressed: () =>
                  launchUrl(link.url, mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('${link.label}の根拠を開く'),
            ),
        ],
      ],
    );
  }
}

class _ProfileFact extends StatelessWidget {
  const _ProfileFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
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

String _historyDate(DateTime? value) {
  if (value == null) return '日時不明';
  final local = value.toLocal();
  return '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
