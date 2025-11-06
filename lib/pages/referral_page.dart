import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../services/referral_service.dart';
import '../models/referral_code.dart';
import '../utils/app_logger.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final _supabase = Supabase.instance.client;
  late ReferralService _referralService;

  ReferralCode? _myReferralCode;
  List<Map<String, dynamic>> _myReferrals = [];
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _referralService = ReferralService(_supabase);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final code = await _referralService.getUserReferralCode(userId);
      final referrals = await _referralService.getUserReferrals(userId);
      final leaderboard = await _referralService.getReferralLeaderboard();

      setState(() {
        _myReferralCode = code;
        _myReferrals = referrals;
        _leaderboard = leaderboard;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load referral data', e, stackTrace);
      setState(() => _isLoading = false);
    }
  }

  void _copyReferralCode() {
    if (_myReferralCode != null) {
      Clipboard.setData(ClipboardData(text: _myReferralCode!.referralCode));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('紹介コードをコピーしました')),
      );
    }
  }

  void _shareReferralLink() {
    if (_myReferralCode != null) {
      final link = _referralService.generateReferralLink(
        _myReferralCode!.referralCode,
        'https://my-web-app-b67f4.web.app',
      );
      final message = '「マイメモ」に招待します！\n'
          '紹介コード: ${_myReferralCode!.referralCode}\n'
          'または以下のリンクから登録してください:\n$link';

      Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('紹介プログラム'),
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
                    // My referral code section
                    _buildMyReferralCodeCard(theme),
                    const SizedBox(height: 24),

                    // Stats section
                    _buildStatsSection(theme),
                    const SizedBox(height: 24),

                    // My referrals section
                    Text(
                      'あなたの紹介 (${_myReferrals.length}人)',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _buildMyReferralsList(),
                    const SizedBox(height: 24),

                    // Leaderboard section
                    Text(
                      '紹介ランキング',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _buildLeaderboard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMyReferralCodeCard(ThemeData theme) {
    if (_myReferralCode == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('紹介コードの読み込みに失敗しました'),
        ),
      );
    }

    return Card(
      elevation: 4,
      color: theme.primaryColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'あなたの紹介コード',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primaryColor, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _myReferralCode!.referralCode,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: _copyReferralCode,
                        tooltip: 'コピー',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: _shareReferralLink,
                        tooltip: '共有',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '友達を招待して、1人につき100ポイント獲得！',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(ThemeData theme) {
    if (_myReferralCode == null) return const SizedBox();

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: '紹介人数',
            value: _myReferralCode!.totalReferrals.toString(),
            icon: Icons.people,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '成功',
            value: _myReferralCode!.successfulReferrals.toString(),
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: '獲得P',
            value: _myReferralCode!.bonusPointsEarned.toString(),
            icon: Icons.star,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyReferralsList() {
    if (_myReferrals.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('まだ誰も紹介していません'),
          ),
        ),
      );
    }

    return Column(
      children: _myReferrals.map((referral) {
        final status = referral['status'] as String;
        final createdAt = DateTime.parse(referral['created_at'] as String);
        final completedAt = referral['completed_at'] != null
            ? DateTime.parse(referral['completed_at'] as String)
            : null;

        IconData statusIcon;
        Color statusColor;
        String statusText;

        switch (status) {
          case 'completed':
            statusIcon = Icons.check_circle;
            statusColor = Colors.green;
            statusText = '完了';
            break;
          case 'pending':
            statusIcon = Icons.hourglass_empty;
            statusColor = Colors.orange;
            statusText = '保留中';
            break;
          default:
            statusIcon = Icons.cancel;
            statusColor = Colors.red;
            statusText = '期限切れ';
        }

        return Card(
          child: ListTile(
            leading: Icon(statusIcon, color: statusColor),
            title: Text(statusText),
            subtitle: Text(
              '登録日: ${createdAt.year}/${createdAt.month}/${createdAt.day}',
            ),
            trailing: completedAt != null
                ? Text(
                    '+${referral['bonus_points']}P',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLeaderboard() {
    if (_leaderboard.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('ランキングデータがありません'),
          ),
        ),
      );
    }

    return Column(
      children: _leaderboard.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final rank = index + 1;

        IconData? medalIcon;
        Color? medalColor;

        if (rank == 1) {
          medalIcon = Icons.emoji_events;
          medalColor = Colors.amber;
        } else if (rank == 2) {
          medalIcon = Icons.emoji_events;
          medalColor = Colors.grey[400];
        } else if (rank == 3) {
          medalIcon = Icons.emoji_events;
          medalColor = Colors.brown[300];
        }

        final isCurrentUser = item['user_id'] == _supabase.auth.currentUser?.id;

        return Card(
          color: isCurrentUser ? Colors.blue[50] : null,
          child: ListTile(
            leading: SizedBox(
              width: 40,
              child: Row(
                children: [
                  Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (medalIcon != null) ...[
                    const SizedBox(width: 4),
                    Icon(medalIcon, color: medalColor, size: 20),
                  ],
                ],
              ),
            ),
            title: Text(
              isCurrentUser ? 'あなた' : 'ユーザー ${item['user_id'].substring(0, 8)}',
              style: TextStyle(
                fontWeight: isCurrentUser ? FontWeight.bold : null,
              ),
            ),
            subtitle: Text('${item['successful_referrals']}人紹介'),
            trailing: Text(
              '${item['bonus_points_earned']}P',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
