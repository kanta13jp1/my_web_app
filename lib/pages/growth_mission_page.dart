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
  GrowthMissionDashboard _dashboard = GrowthMissionDashboard.empty();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final dashboard = await widget.growthService.loadDashboard();
    if (!mounted) {
      return;
    }
    setState(() {
      _dashboard = dashboard;
      _isLoading = false;
    });
  }

  Future<void> _copyInviteLink() async {
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      _showMessage('ログインすると招待リンクを発行できます。');
      return;
    }

    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) {
      return;
    }
    _showMessage('招待リンクをコピーしました。');
  }

  Future<void> _copyInviteMessage() async {
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl;
    if (inviteUrl == null || inviteUrl.isEmpty) {
      _showMessage('ログインすると招待文をコピーできます。');
      return;
    }

    final message = GrowthMissionService.buildInviteCopyText(
      inviteUrl: inviteUrl,
      totalRegisteredUsers: _dashboard.totalRegisteredUsers,
      liveViewers: _dashboard.liveViewers,
    );
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) {
      return;
    }
    _showMessage('招待文をコピーしました。');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.decimalPattern('ja');
    final referralCode =
        _dashboard.referralSnapshot.referralCode ?? 'ログインで発行';
    final inviteUrl = _dashboard.referralSnapshot.inviteUrl ?? '--';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Growth Mission'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
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
              title: '登録者数を増やすライブ指標',
              subtitle: '流入・登録・ライブ閲覧をひとつの面で追います。',
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '現在地と勝ち筋',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '2026年3月23日時点の公開ベンチマークでは、Notion は 100M+、Evernote は 250M+ が計画の最低ラインです。まずは LP 流入、登録、紹介の 3 つを毎日改善し、公開メモ・共有・移行導線で中長期の獲得を広げます。',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _summaryStat(
                          '今日のLP閲覧',
                          numberFormat.format(_dashboard.todayLandingViews),
                          Icons.trending_up,
                        ),
                        _summaryStat(
                          '今日の登録',
                          numberFormat.format(_dashboard.todayRegistrations),
                          Icons.person_add,
                        ),
                        _summaryStat(
                          '今日のシェア',
                          numberFormat.format(_dashboard.todayShares),
                          Icons.ios_share,
                        ),
                        _summaryStat(
                          'アクティブ登録者',
                          numberFormat.format(_dashboard.activeUsersToday),
                          Icons.groups,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LandingPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.language),
                          label: const Text('LP を開く'),
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
                          label: const Text('管理分析を見る'),
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
                      '紹介プログラム',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '登録者数を最短で増やすには、共有リンクではなく「誰が誰を連れてきたか」が見える紹介ループを回す必要があります。',
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      'あなたの紹介コード: $referralCode',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    SelectableText('招待リンク: $inviteUrl'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _summaryStat(
                          '紹介数',
                          numberFormat.format(
                            _dashboard.referralSnapshot.totalReferrals,
                          ),
                          Icons.share,
                        ),
                        _summaryStat(
                          '成立数',
                          numberFormat.format(
                            _dashboard.referralSnapshot.successfulReferrals,
                          ),
                          Icons.verified,
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
                          label: const Text('招待リンクをコピー'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _copyInviteMessage,
                          icon: const Icon(Icons.copy_all),
                          label: const Text('招待文をコピー'),
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
                      '実装済みの獲得施策',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _implementedItem(
                      'ライブ成長メーター',
                      '登録者数、ログイン中、ゲスト閲覧、LP閲覧を更新しながら見える化',
                    ),
                    _implementedItem(
                      '紹介コードと招待リンク',
                      'ユーザーごとの referral code を発行し、招待リンクをコピー可能',
                    ),
                    _implementedItem(
                      'LP シェア計測',
                      'X / LINE / Facebook / コピー導線と、その後の流入を計測',
                    ),
                    _implementedItem(
                      'Notion / Evernote 超えの目標管理',
                      '100M+ / 250M+ を基準に毎日の差分を確認',
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
                      '短中長期の開発計画',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'docs/NOTION_EVERNOTE_SURPASS_PLAN_2026-03-23.md に、Notion / Evernote を上回るための逆算計画を保存しています。',
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading) const LinearProgressIndicator(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(String label, String value, IconData icon) {
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
}
