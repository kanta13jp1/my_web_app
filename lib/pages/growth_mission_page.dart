import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../pages/admin_analytics_page.dart';
import '../pages/landing_page.dart';
import '../services/growth_mission_service.dart';
import '../widgets/live_growth_banner.dart';

class GrowthMissionPage extends StatefulWidget {
  final GrowthMissionService growthService;

  const GrowthMissionPage({
    super.key,
    this.growthService = const GrowthMissionService(),
  });

  @override
  State<GrowthMissionPage> createState() => _GrowthMissionPageState();
}

class _GrowthMissionPageState extends State<GrowthMissionPage> {
  bool _isLoading = true;
  bool _briefLoading = true;
  GrowthMissionDashboard _dashboard = GrowthMissionDashboard.empty();
  GrowthCommandCenterBrief _commandCenter = GrowthCommandCenterBrief.empty();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dashboard = await widget.growthService.loadDashboard();
    final commandCenter =
        await widget.growthService.loadCommandCenterBrief(dashboard);
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboard = dashboard;
      _isLoading = false;
      _commandCenter = commandCenter;
      _briefLoading = false;
    });
  }

  Future<void> _copyInviteLink() async {
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      _showMessage('Generate your referral link by signing in first.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) {
      return;
    }
    _showMessage('Referral link copied.');
  }

  Future<void> _copyInviteMessage() async {
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      _showMessage('Generate your referral link by signing in first.');
      return;
    }

    final message = '''
Trying to grow this note app past Notion and Evernote takes real users, not just plans.

Current snapshot:
- Registered users: ${_dashboard.totalRegisteredUsers}
- Live viewers: ${_dashboard.liveViewers}

Join from this invite:
$inviteUrl
''';
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) {
      return;
    }
    _showMessage('Referral message copied.');
  }

  void _openLandingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LandingPage(),
      ),
    );
  }

  Future<void> _handleDepartmentAction(String departmentId) async {
    switch (departmentId) {
      case 'development':
        await Navigator.of(context).pushNamed('/import');
        return;
      case 'product':
        await Navigator.of(context).pushNamed('/behavior-review');
        return;
      case 'advertising':
        _openLandingPage();
        return;
      case 'pr':
      case 'marketing':
        await Navigator.of(context).pushNamed('/public-memos');
        return;
      case 'sales':
        await Navigator.of(context).pushNamed('/import');
        return;
      case 'finance':
      case 'procurement':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminAnalyticsPage(),
          ),
        );
        return;
      case 'hr':
      case 'business-planning':
        await Clipboard.setData(
          const ClipboardData(text: 'docs/GROWTH_STRATEGY_ROADMAP.md'),
        );
        if (!mounted) {
          return;
        }
        _showMessage('Roadmap path copied for the next operating review.');
        return;
    }
  }

  String _departmentActionLabel(String departmentId) {
    switch (departmentId) {
      case 'development':
        return 'Open import pipeline';
      case 'product':
        return 'Open product review';
      case 'advertising':
        return 'Open landing page';
      case 'pr':
        return 'Open public memos';
      case 'sales':
        return 'Open import demo';
      case 'marketing':
        return 'Open SEO memos';
      case 'finance':
        return 'Open analytics';
      case 'procurement':
        return 'Open vendor metrics';
      case 'hr':
        return 'Copy hiring roadmap';
      case 'business-planning':
        return 'Copy roadmap path';
      default:
        return 'Open next step';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  double _progress(double value) {
    return math.max(0, math.min(100, value * 100));
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('ja');
    final referralCode =
        _dashboard.referralSnapshot.referralCode ?? 'Sign in to generate one';
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl ?? '--';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Growth Mission'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LiveGrowthBanner(
              growthService: widget.growthService,
              title: 'Live growth counter',
              subtitle:
                  'Track registered users, active viewers, and referral momentum in real time.',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'North-star metrics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Target: build past the user floors we set for Notion and Evernote, while keeping the dashboard and roadmap honest about where we are today.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statTile(
                          label: 'Registered users',
                          value: numberFormat.format(
                            _dashboard.totalRegisteredUsers,
                          ),
                          icon: Icons.groups,
                        ),
                        _statTile(
                          label: 'Today registrations',
                          value: numberFormat.format(
                            _dashboard.todayRegistrations,
                          ),
                          icon: Icons.person_add,
                        ),
                        _statTile(
                          label: 'Today landing views',
                          value: numberFormat.format(
                            _dashboard.todayLandingViews,
                          ),
                          icon: Icons.trending_up,
                        ),
                        _statTile(
                          label: 'Live viewers',
                          value: numberFormat.format(_dashboard.liveViewers),
                          icon: Icons.visibility,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Refreshed: ${DateFormat('yyyy/MM/dd HH:mm').format(_dashboard.refreshedAt)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cross-functional command center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stage: ${_commandCenter.stageLabel} - ${_commandCenter.stageReason}',
                    ),
                    const SizedBox(height: 12),
                    if (_commandCenter.focusTags.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _commandCenter.focusTags
                            .map((tag) => Chip(label: Text(tag)))
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _commandCenter.departments
                          .map(_departmentCard)
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Brief generated: ${DateFormat('yyyy/MM/dd HH:mm').format(_commandCenter.generatedAt)}',
                    ),
                    if (_briefLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Competitor gap',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _progressRow(
                      label: 'Beat Notion floor',
                      progress: _dashboard.progressToBeatNotion,
                      detail:
                          '${numberFormat.format(_dashboard.gapToBeatNotion)} users to go',
                    ),
                    const SizedBox(height: 12),
                    _progressRow(
                      label: 'Beat Evernote floor',
                      progress: _dashboard.progressToBeatEvernote,
                      detail:
                          '${numberFormat.format(_dashboard.gapToBeatEvernote)} users to go',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statTile(
                          label: 'Notion floor',
                          value: numberFormat.format(
                            GrowthBenchmarks.beatNotionTarget,
                          ),
                          icon: Icons.flag,
                        ),
                        _statTile(
                          label: 'Evernote floor',
                          value: numberFormat.format(
                            GrowthBenchmarks.beatEvernoteTarget,
                          ),
                          icon: Icons.flag_circle,
                        ),
                        _statTile(
                          label: 'Month landing views',
                          value: numberFormat.format(
                            _dashboard.monthLandingViews,
                          ),
                          icon: Icons.calendar_month,
                        ),
                        _statTile(
                          label: 'Today shares',
                          value: numberFormat.format(_dashboard.todayShares),
                          icon: Icons.share,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Verified public benchmark references on 2026/03/23: Notion says "Over 100M users worldwide" on its homepage, and Evernote says it serves "more than 250 million customers" in its official acquisition announcement.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Referral engine',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep the invitation loop simple: generate a personal code, copy a ready-made invite, and measure how many completed registrations came from it.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Referral code: $referralCode',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SelectableText('Invite URL: $inviteUrl'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statTile(
                          label: 'Total referrals',
                          value: numberFormat.format(
                            _dashboard.referralSnapshot.totalReferrals,
                          ),
                          icon: Icons.outbound,
                        ),
                        _statTile(
                          label: 'Completed referrals',
                          value: numberFormat.format(
                            _dashboard.referralSnapshot.successfulReferrals,
                          ),
                          icon: Icons.verified,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _copyInviteLink,
                          icon: const Icon(Icons.link),
                          label: const Text('Copy invite link'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _copyInviteMessage,
                          icon: const Icon(Icons.copy_all),
                          label: const Text('Copy invite message'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acquisition engines shipped',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _implementedItem(
                      'Public memo SEO loop',
                      'Visitors can browse public memos and now share memo detail links directly from the detail page.',
                    ),
                    _implementedItem(
                      'Edge-backed import preview',
                      'Notion / Evernote / Markdown preview parsing now runs on a Supabase Edge Function first, which keeps browser code thinner and backend logic reusable.',
                    ),
                    _implementedItem(
                      'Referral attribution',
                      'Referral codes, pending referral capture, and completion tracking are active in the growth dashboard.',
                    ),
                    _implementedItem(
                      'Live counters',
                      'Presence-based viewer counts and dashboard counters refresh from Supabase-backed metrics.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            _openLandingPage();
                          },
                          icon: const Icon(Icons.language),
                          label: const Text('Open landing page'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/import');
                          },
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Open import'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/public-memos');
                          },
                          icon: const Icon(Icons.public),
                          label: const Text('Open public memos'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminAnalyticsPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.analytics),
                          label: const Text('Open analytics'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Roadmap discipline',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The active execution source is docs/GROWTH_STRATEGY_ROADMAP.md. This slice updates the roadmap with the new backend import preview, public memo sharing, and the remaining backend migration work.',
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label),
        ],
      ),
    );
  }

  Widget _progressRow({
    required String label,
    required double progress,
    required String detail,
  }) {
    final percent = _progress(progress);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
        const SizedBox(height: 6),
        Text('${percent.toStringAsFixed(6)}% - $detail'),
      ],
    );
  }

  Widget _implementedItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.check_circle, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _departmentCard(GrowthDepartmentBrief department) {
    return SizedBox(
      width: 320,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    department.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(department.priority)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Owner: ${department.owner}'),
            const SizedBox(height: 10),
            Text(department.objective),
            const SizedBox(height: 10),
            ...department.actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('- $action'),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.tonalIcon(
              onPressed: () => _handleDepartmentAction(department.id),
              icon: const Icon(Icons.arrow_forward),
              label: Text(_departmentActionLabel(department.id)),
            ),
          ],
        ),
      ),
    );
  }
}
