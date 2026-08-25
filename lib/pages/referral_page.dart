import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/referral_benefit_copy.dart';
import '../services/growth_mission_service.dart';

/// 紹介プログラムページ
///
/// 紹介コード・紹介実績・招待リンクを `GrowthMissionService` に集約し、
/// landing/referral/growth dashboard と同じ紹介データを表示する。
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final GrowthMissionService _growthService = const GrowthMissionService();

  bool _loading = true;
  String? _error;
  String? _pendingReferralCode;
  ReferralGrowthSnapshot _snapshot = const ReferralGrowthSnapshot.empty();

  bool get _isSignedIn => Supabase.instance.client.auth.currentUser != null;

  String? get _inviteUrl => _snapshot.inviteUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _growthService.capturePendingReferralFromUri();
      if (_isSignedIn) {
        await _growthService.applyPendingReferralIfPossible();
      }

      final pendingCode = await _growthService.loadPendingReferralCode();
      final snapshot = await _growthService.loadReferralSnapshot();
      if (!mounted) return;
      setState(() {
        _pendingReferralCode = pendingCode;
        _snapshot = snapshot;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '紹介情報の取得に失敗しました: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyInviteLink() async {
    final inviteUrl = _inviteUrl;
    if (inviteUrl == null) return;
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('紹介リンクをコピーしました')),
    );
  }

  Future<void> _shareInvite() async {
    final inviteUrl = _inviteUrl;
    if (inviteUrl == null) return;
    final text = ReferralBenefitCopy.buildShareText(inviteUrl);
    await SharePlus.instance.share(
      ShareParams(
        subject: '自分株式会社への招待',
        text: text,
      ),
    );
  }

  void _goToLanding() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('友達を招待'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHero(colorScheme),
                    const SizedBox(height: 18),
                    if (!_isSignedIn) ...[
                      _buildGuestInviteNotice(colorScheme),
                      const SizedBox(height: 18),
                    ] else ...[
                      _buildStats(colorScheme),
                      const SizedBox(height: 18),
                      _buildInviteLink(colorScheme),
                      const SizedBox(height: 18),
                    ],
                    _buildSteps(colorScheme),
                    const SizedBox(height: 18),
                    _buildRewards(colorScheme),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFE53935)),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.group_add_outlined,
            size: 36,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 14),
          Text(
            ReferralBenefitCopy.headline,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '招待リンクには紹介コードとUTMを付与します。${ReferralBenefitCopy.detail}',
            style: TextStyle(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestInviteNotice(ColorScheme colorScheme) {
    final pendingCode = _pendingReferralCode;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pendingCode == null ? 'ログインすると紹介コードを発行できます' : '招待コードを受け取りました',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pendingCode == null
                ? 'Magic Linkでログインすると、あなた専用の紹介リンクと紹介実績が表示されます。'
                : 'コード $pendingCode は保存済みです。ログイン後に紹介経由登録として自動反映します。',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _goToLanding,
            icon: const Icon(Icons.login),
            label: const Text('無料で始める'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            colorScheme,
            label: '招待合計',
            value: '${_snapshot.totalReferrals}',
            icon: Icons.people_alt_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            colorScheme,
            label: '特典成立',
            value: '${_snapshot.successfulReferrals}',
            icon: Icons.verified_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ColorScheme colorScheme, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteLink(ColorScheme colorScheme) {
    final inviteUrl = _inviteUrl;
    final code = _snapshot.referralCode;
    if (inviteUrl == null || code == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '紹介コードを生成できませんでした。更新してもう一度お試しください。',
          style: TextStyle(color: colorScheme.onErrorContainer),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'あなたの紹介リンク',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    inviteUrl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _copyInviteLink,
                  icon: const Icon(Icons.copy),
                  tooltip: 'コピー',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '招待コード: $code',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _copyInviteLink,
                  icon: const Icon(Icons.copy),
                  label: const Text('コピー'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareInvite,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('共有'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSteps(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '紹介フロー',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 10),
        _buildStep(colorScheme, 1, 'リンクを送る', 'LINE・X・Slackなどで招待リンクを共有します。'),
        _buildStep(colorScheme, 2, '友達が登録する', '紹介コードは端末に保存され、ログイン後に紐づきます。'),
        _buildStep(
          colorScheme,
          3,
          'Pro課金で特典成立',
          '登録だけでは報酬を付与せず、友達のPro課金が確認できた時点で2人分のクレジットを一度だけ付与します。',
        ),
      ],
    );
  }

  Widget _buildStep(
    ColorScheme colorScheme,
    int index,
    String title,
    String body,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              '$index',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewards(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.workspace_premium_outlined, color: colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ReferralBenefitCopy.detail,
              style: TextStyle(
                color: colorScheme.onSecondaryContainer,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
