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
  bool _digestLoading = true;
  GrowthMissionDashboard _dashboard = GrowthMissionDashboard.empty();
  GrowthCommandCenterBrief _commandCenter = GrowthCommandCenterBrief.empty();
  WeeklyDigestSnapshot _weeklyDigest = const WeeklyDigestSnapshot.empty();

  static const List<_PublishingChannel> _publishingChannels =
      <_PublishingChannel>[
    _PublishingChannel(
      name: 'note',
      audience: 'Japanese general knowledge workers and founders',
      cadence: 'Weekly founder memo',
      angle: 'Story-driven launch updates and product lessons.',
      cta: 'Invite readers to try the landing page and public memos.',
    ),
    _PublishingChannel(
      name: 'Qiita',
      audience: 'Japanese engineers',
      cadence: '1 technical post per shipped growth slice',
      angle:
          'Supabase Edge Functions, Flutter architecture, and migration flows.',
      cta: 'Show the import pipeline and developer-facing product depth.',
    ),
    _PublishingChannel(
      name: 'Zenn',
      audience: 'Japanese developers and indie builders',
      cadence: 'Biweekly deep dive',
      angle:
          'Implementation detail, product reasoning, and technical tradeoffs.',
      cta: 'Turn shipped features into recurring search traffic.',
    ),
    _PublishingChannel(
      name: 'Medium',
      audience: 'Global product and engineering readers',
      cadence: 'Monthly narrative post',
      angle: 'Replacing fragmented note workflows with AI-first execution.',
      cta: 'Push English discovery beyond Japan.',
    ),
    _PublishingChannel(
      name: 'dev.to',
      audience: 'Global developers',
      cadence: 'Per launch or architecture milestone',
      angle: 'Practical engineering writeups with code and lessons learned.',
      cta: 'Attract technical early adopters and contributors.',
    ),
    _PublishingChannel(
      name: 'Hashnode',
      audience: 'Developer communities and startup engineers',
      cadence: 'Monthly migration or AI workflow article',
      angle: 'Build-in-public posts tied to the product roadmap.',
      cta:
          'Create long-tail search entry points around migration and AI workflows.',
    ),
    _PublishingChannel(
      name: 'Substack',
      audience: 'Founder and operator subscribers',
      cadence: 'Weekly growth letter',
      angle:
          'Cross-functional operating notes, growth experiments, and user stories.',
      cta: 'Build a durable audience that compounds launches and referrals.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final results = await Future.wait<dynamic>([
      widget.growthService.loadDashboard(),
      widget.growthService.loadWeeklyDigest(),
    ]);
    final dashboard = results[0] as GrowthMissionDashboard;
    final digest = results[1] as WeeklyDigestSnapshot;
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
      _weeklyDigest = digest;
      _digestLoading = false;
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

    final message = GrowthMissionService.buildReferralInviteMessage(
      inviteUrl: inviteUrl,
      totalRegisteredUsers: _dashboard.totalRegisteredUsers,
      liveViewers: _dashboard.liveViewers,
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) {
      return;
    }
    _showMessage('Referral message copied.');
  }

  Future<void> _copyPublishingBrief(_PublishingChannel channel) async {
    final brief = '''
Channel: ${channel.name}
Audience: ${channel.audience}
Cadence: ${channel.cadence}
Angle: ${channel.angle}

Suggested outline:
1. Start with the Notion / Evernote workflow pain.
2. Show the shipped 自分株式会社 feature or growth experiment.
3. Explain why the backend-first architecture matters.
4. Add one screenshot, metric, or before/after example.
5. Close with this CTA: ${channel.cta}

Current proof points:
- Registered users: ${_dashboard.totalRegisteredUsers}
- Today landing views: ${_dashboard.todayLandingViews}
- Today shares: ${_dashboard.todayShares}
- Referral completions: ${_dashboard.referralSnapshot.successfulReferrals}

Roadmap source:
docs/GROWTH_STRATEGY_ROADMAP.md
''';
    await Clipboard.setData(ClipboardData(text: brief));
    if (!mounted) {
      return;
    }
    _showMessage('${channel.name} publishing brief copied.');
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
                        height: 1.5,
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
                      'Publishing engine',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Turn every shipped growth slice into channel-ready content for note, Qiita, Zenn, Medium, dev.to, Hashnode, and Substack. This keeps PR, marketing, and founder distribution tied to the roadmap instead of ad-hoc posting.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _publishingChannels
                          .map(_publishingChannelCard)
                          .toList(),
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
                        height: 1.5,
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
                        height: 1.5,
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
                      'Verified public benchmark references on 2026/03/24: Notion says "Over 100M users worldwide" on its product page, and Evernote says it serves "more than 250 million customers" in its official acquisition announcement.',
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
                      'Acquisition instrumentation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last ${_dashboard.acquisitionSnapshot.windowDays} days. This backend-first report uses touchpoint and sign-up submit signals as an assisted-conversion proxy while full registration joins keep maturing.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statTile(
                          label: 'Tracked touches',
                          value: numberFormat.format(
                            _dashboard.acquisitionSnapshot.totalTouches,
                          ),
                          icon: Icons.ads_click,
                        ),
                        _statTile(
                          label: 'Sign-up submits',
                          value: numberFormat.format(
                            _dashboard.acquisitionSnapshot.totalSignupSubmits,
                          ),
                          icon: Icons.person_add_alt,
                        ),
                        _statTile(
                          label: 'Import CTA clicks',
                          value: numberFormat.format(
                            _dashboard.acquisitionSnapshot.importSignupCtaCount,
                          ),
                          icon: Icons.file_upload,
                        ),
                        _statTile(
                          label: 'Public memo CTA clicks',
                          value: numberFormat.format(
                            _dashboard
                                .acquisitionSnapshot.publicMemoSignupCtaCount,
                          ),
                          icon: Icons.public,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ..._dashboard.acquisitionSnapshot.touchpoints.map(
                      (touchpoint) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _acquisitionTouchpointRow(
                          label: touchpoint.label,
                          touches: numberFormat.format(touchpoint.touchCount),
                          signupSubmits:
                              numberFormat.format(touchpoint.signupSubmitCount),
                          rate: touchpoint.signupSubmitRate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _dashboard.acquisitionSnapshot.importPreviews
                          .map(
                            (preview) => _statTile(
                              label: preview.label,
                              value: numberFormat.format(preview.previewCount),
                              icon: Icons.visibility_outlined,
                            ),
                          )
                          .toList(),
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
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Keep the invitation loop simple: generate a personal code, copy a ready-made invite, and measure how many completed registrations came from it.',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'Referral code: $referralCode',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
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
                        height: 1.5,
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
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Weekly digest',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (_digestLoading)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    if (_weeklyDigest.currentWeekStart.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_weeklyDigest.currentWeekStart} – ${_weeklyDigest.currentWeekEnd}',
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          height: 1.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_weeklyDigest.channels.isEmpty && !_digestLoading)
                      const Text('No data yet for this week.')
                    else
                      ..._weeklyDigest.channels.map(_weeklyDigestChannelRow),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _statTile(
                          label: 'Sign-up submits',
                          value:
                              '${_weeklyDigest.signupSubmitTotal}${_weeklyDigest.signupSubmitDelta >= 0 ? ' (+${_weeklyDigest.signupSubmitDelta})' : ' (${_weeklyDigest.signupSubmitDelta})'}',
                          icon: Icons.how_to_reg,
                        ),
                        _statTile(
                          label: 'Referrals completed',
                          value:
                              '${_weeklyDigest.referralsCompleted}${_weeklyDigest.referralsDelta >= 0 ? ' (+${_weeklyDigest.referralsDelta})' : ' (${_weeklyDigest.referralsDelta})'}',
                          icon: Icons.verified,
                        ),
                        _statTile(
                          label: 'Import CTA clicks',
                          value: '${_weeklyDigest.importCtaClicks}',
                          icon: Icons.upload_file,
                        ),
                        _statTile(
                          label: 'Public memo CTA',
                          value: '${_weeklyDigest.publicMemoCtaClicks}',
                          icon: Icons.public,
                        ),
                      ],
                    ),
                    if (_weeklyDigest.brief.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_weeklyDigest.brief),
                      ),
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
                      'Roadmap discipline',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The active execution source is docs/GROWTH_STRATEGY_ROADMAP.md. This slice updates the roadmap with backend-first acquisition tracking, sign-up attribution, publishing-channel execution, and the remaining backend migration work.',
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
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
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
        const SizedBox(height: 6),
        Text('${percent.toStringAsFixed(6)}% - $detail'),
      ],
    );
  }

  Widget _weeklyDigestChannelRow(WeeklyDigestChannelMetrics channel) {
    final deltaSign = channel.touchesDelta >= 0 ? '+' : '';
    final submitDeltaSign = channel.signupSubmitsDelta >= 0 ? '+' : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              channel.label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'touches: ${channel.touches} ($deltaSign${channel.touchesDelta})  '
              'sign-ups: ${channel.signupSubmits} ($submitDeltaSign${channel.signupSubmitsDelta})  '
              'CVR: ${channel.cvr}%',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _acquisitionTouchpointRow({
    required String label,
    required String touches,
    required String signupSubmits,
    required double rate,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text('Touches: $touches'),
          Text('Sign-up submits: $signupSubmits'),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: rate.clamp(0.0, 1.0)),
          const SizedBox(height: 6),
          Text(
            'Touch-to-submit rate: ${(rate * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
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

  Widget _publishingChannelCard(_PublishingChannel channel) {
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
            Text(
              channel.name,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text('Audience: ${channel.audience}'),
            const SizedBox(height: 8),
            Text('Cadence: ${channel.cadence}'),
            const SizedBox(height: 8),
            Text(channel.angle),
            const SizedBox(height: 8),
            Text(
              'CTA: ${channel.cta}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _copyPublishingBrief(channel),
              icon: const Icon(Icons.content_copy),
              label: const Text('Copy publishing brief'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishingChannel {
  final String name;
  final String audience;
  final String cadence;
  final String angle;
  final String cta;

  const _PublishingChannel({
    required this.name,
    required this.audience,
    required this.cadence,
    required this.angle,
    required this.cta,
  });
}
