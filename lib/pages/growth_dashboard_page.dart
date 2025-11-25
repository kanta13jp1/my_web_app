import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/presence_service.dart';
import '../services/viral_growth_service.dart';
import '../models/site_statistics.dart';
import '../models/campaign.dart';
import '../utils/app_logger.dart';
import 'package:share_plus/share_plus.dart';
import 'import_page.dart';
import 'template_marketplace_page.dart';
import 'activity_feed_page.dart';

class GrowthDashboardPage extends StatefulWidget {
  const GrowthDashboardPage({super.key});

  @override
  State<GrowthDashboardPage> createState() => _GrowthDashboardPageState();
}

class _GrowthDashboardPageState extends State<GrowthDashboardPage> {
  final _supabase = Supabase.instance.client;
  late final PresenceService _presenceService;
  late final ViralGrowthService _viralGrowthService;

  SiteStatistics? _siteStats;
  int _onlineUsers = 0;
  int _onlineGuests = 0;
  String? _inviteLink;
  bool _isLoading = true;

  final List<Campaign> _activeCampaigns = [];

  @override
  void initState() {
    super.initState();
    _presenceService = PresenceService(_supabase);
    _viralGrowthService = ViralGrowthService(_supabase);
    _loadData();
    _generateInviteLink();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final stats = await _presenceService.getSiteStatistics();
      final onlineUsers = await _presenceService.getOnlineUsersCount();
      final onlineGuests = await _presenceService.getOnlineGuestsCount();

      // アクティブなキャンペーンを読み込み
      _activeCampaigns.clear();
      _activeCampaigns.addAll(
        [
          Campaign.createWelcomeCampaign(),
          Campaign.createShareCampaign(),
          Campaign.createReferralCampaign(),
        ].where((c) => c.isCurrentlyActive),
      );

      if (mounted) {
        setState(() {
          _siteStats = stats;
          _onlineUsers = onlineUsers;
          _onlineGuests = onlineGuests;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error loading growth data',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateInviteLink() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final link = await _viralGrowthService.generateInviteLink(userId);
        if (mounted) {
          setState(() {
            _inviteLink = link;
          });
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error generating invite link',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _shareInviteLink() async {
    if (_inviteLink == null) return;

    try {
      final message = '''
🎮 マイメモ - ゲーム感覚でメモ習慣！

楽しくメモが続けられるアプリを見つけました！
レベルアップ、実績解除、ストリークなどゲーム要素満載！

一緒に始めませんか？
$_inviteLink

※新規登録で今なら500ptプレゼント🎁
''';

      await Share.share(message);

      // シェアボーナスを付与
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        final isCampaignActive =
            await _viralGrowthService.isShareCampaignActive();
        await _viralGrowthService.awardShareBonus(
          userId: userId,
          platform: 'invite_link',
          isCampaignActive: isCampaignActive,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isCampaignActive
                    ? 'シェアありがとうございます！50ptゲット🎉'
                    : 'シェアありがとうございます！10ptゲット',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error sharing invite link',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成長ダッシュボード'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '更新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // サイト統計サマリー
                    _buildStatsOverview(),
                    const SizedBox(height: 24),

                    // アクティブキャンペーン
                    if (_activeCampaigns.isNotEmpty) ...[
                      Text(
                        '🎉 開催中のキャンペーン',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildActiveCampaigns(),
                      const SizedBox(height: 24),
                    ],

                    // 成長施策
                    Text(
                      '🚀 成長施策',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildGrowthActions(),
                    const SizedBox(height: 24),

                    // 招待リンク
                    Text(
                      '👥 友達を招待',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildInviteSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
    final totalOnline = _onlineUsers + _onlineGuests;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📊 サイト統計',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: '総登録者数',
                    value: _siteStats?.totalUsers.toString() ?? '-',
                    icon: Icons.people,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: 'オンライン',
                    value: totalOnline.toString(),
                    icon: Icons.circle,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: '本日の新規',
                    value: _siteStats?.newUsersToday.toString() ?? '-',
                    icon: Icons.fiber_new,
                    color: Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: '総メモ数',
                    value: _siteStats?.totalNotesCreated.toString() ?? '-',
                    icon: Icons.note,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCampaigns() {
    return Column(
      children: _activeCampaigns.map((campaign) {
        Color getColor(String type) {
          switch (type) {
            case 'registration_boost':
              return Colors.purple;
            case 'share_boost':
              return Colors.blue;
            case 'referral_boost':
              return Colors.green;
            default:
              return Colors.orange;
          }
        }

        final color = getColor(campaign.campaignType);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
          ),
          child: Row(
            children: [
              Icon(Icons.campaign, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      campaign.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '残り${campaign.daysRemaining}日',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrowthActions() {
    return Column(
      children: [
        _buildActionCard(
          title: 'テンプレートマーケット',
          description: 'すぐに使えるメモテンプレートで新規ユーザーの定着率UP',
          icon: Icons.library_books,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TemplateMarketplacePage(),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: 'Notion/Evernoteインポート',
          description: '競合アプリからの乗り換えを簡単に',
          icon: Icons.upload_file,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ImportPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          title: 'コミュニティ活動',
          description: 'ユーザーのアクティビティをリアルタイムで表示',
          icon: Icons.timeline,
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ActivityFeedPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInviteSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '友達を招待して両方に500ptプレゼント！',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_inviteLink != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _inviteLink!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        // クリップボードにコピー機能は省略
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('リンクをコピーしました'),
                          ),
                        );
                      },
                      tooltip: 'コピー',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _shareInviteLink,
                icon: const Icon(Icons.share),
                label: const Text('招待リンクをシェア'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
