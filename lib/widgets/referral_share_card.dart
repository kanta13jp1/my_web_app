import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../domain/referral_benefit_copy.dart';
import '../services/growth_mission_service.dart';

/// ホーム画面に表示する友達招待カード。
/// 紹介コードを取得してクリップボードにコピー・Xでシェアできる。
class ReferralShareCard extends StatefulWidget {
  const ReferralShareCard({super.key});

  @override
  State<ReferralShareCard> createState() => _ReferralShareCardState();
}

class _ReferralShareCardState extends State<ReferralShareCard> {
  String? _referralCode;
  bool _loading = true;
  bool _copied = false;

  static const _baseUrl = 'https://my-web-app-b67f4.web.app';

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final service = GrowthMissionService(
        clientOverride: Supabase.instance.client,
      );
      final code = await service.ensureMyReferralCode();
      if (mounted) {
        setState(() {
          _referralCode = code?.referralCode;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _shareUrl => _referralCode != null
      ? GrowthMissionService.buildInviteUrlForCode(_referralCode!)
      : _baseUrl;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (mounted) setState(() => _copied = false);
  }

  void _shareToX() {
    final text = ReferralBenefitCopy.buildShareText(
      _shareUrl,
      includeHashtags: true,
    );
    final intentUrl =
        'https://x.com/intent/tweet?text=${Uri.encodeComponent(text)}';
    web.window.open(intentUrl, '_blank');
  }

  void _nativeShare() {
    try {
      web.window.navigator.share(
        web.ShareData(
          title: '自分株式会社',
          text: ReferralBenefitCopy.shareSummary,
          url: _shareUrl,
        ),
      );
    } catch (_) {
      // Web Share API 非対応ブラウザはフォールバックとしてコピー
      _copyLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ログイン前または読み込み中は非表示
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2A4A), const Color(0xFF1A2233)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3B4A78) : const Color(0xFFC7D2FE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_alt_outlined,
                  color: Color(0xFF6366F1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ReferralBenefitCopy.headline,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      'Pro課金成立で、2人の次回請求に1か月分を自動充当',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_referralCode != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF3B4A78)
                      : const Color(0xFFE0E7FF),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _shareUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              // コピーボタン
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    size: 14,
                  ),
                  label: Text(
                    _copied ? 'コピー済み' : 'リンクコピー',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _copied ? Colors.green : const Color(0xFF6366F1),
                    side: BorderSide(
                      color: _copied ? Colors.green : const Color(0xFF6366F1),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // X (Twitter) シェアボタン
              Expanded(
                child: FilledButton.icon(
                  onPressed: _shareToX,
                  icon: const Icon(Icons.share, size: 14),
                  label: const Text(
                    'Xでシェア',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ネイティブ共有ボタン
              IconButton(
                onPressed: _nativeShare,
                tooltip: 'その他で共有',
                icon: const Icon(
                  Icons.ios_share,
                  size: 20,
                  color: Color(0xFF6366F1),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1).withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
