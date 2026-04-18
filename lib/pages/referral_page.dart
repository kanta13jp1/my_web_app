import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 紹介プログラムページ
///
/// ユーザーの紹介コードを表示し、SNS シェアで友達を誘う導線を提供する。
/// `growth-hub` Edge Function (action: referral.list/create) でコードを取得・生成する。
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _referralCode;
  int _referralCount = 0;
  String? _error;

  static const _siteUrl = 'https://my-web-app-b67f4.web.app';

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
      final resp = await _supabase.functions.invoke(
        'growth-hub',
        body: {'action': 'referral.list'},
      );
      final data = resp.data as Map<String, dynamic>?;
      if (data != null && data['success'] == true) {
        final items = (data['items'] as List<dynamic>?) ?? [];
        if (items.isNotEmpty) {
          final meta = (items.first as Map<String, dynamic>)['metadata']
                  as Map<String, dynamic>? ??
              {};
          setState(() {
            _referralCode = meta['code']?.toString();
            _referralCount = items.length;
          });
        } else {
          // コードなし → ユーザーIDから生成
          final uid = _supabase.auth.currentUser?.id;
          if (uid != null) {
            setState(() => _referralCode = uid.substring(0, 8).toUpperCase());
          }
        }
      }
    } catch (e) {
      // Edge Function が未実装 or 失敗の場合はユーザーIDからコードを生成
      final uid = _supabase.auth.currentUser?.id;
      if (uid != null) {
        setState(() {
          _referralCode = uid.substring(0, 8).toUpperCase();
        });
      } else {
        setState(() => _error = '紹介コードの取得に失敗しました');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _referralLink => '$_siteUrl/?ref=${_referralCode ?? ''}';

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: _referralLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('紹介リンクをコピーしました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('友達を招待'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: '更新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ヒーローバナー
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.people_alt,
                              size: 48,
                              color: Colors.white,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '友達を誘って一緒に使おう',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Notion・Evernote・MoneyForwardを\n1つに統合した AI ライフマネジメントを体験',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 紹介実績
                      if (_referralCount > 0) ...[
                        Card(
                          color: isDark
                              ? const Color(0xFF022C22).withAlpha(180)
                              : const Color(0xFFECFDF5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: Color(0xFF059669),
                                  size: 32,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_referralCount 人を招待済み！',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                    const Text(
                                      'ありがとうございます 🎉',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 紹介リンク
                      Text(
                        'あなたの紹介リンク',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey[850]
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF374151)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _referralLink,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: isDark
                                      ? const Color(0xFFD1D5DB)
                                      : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 18),
                              onPressed: _copyLink,
                              tooltip: 'コピー',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_referralCode != null) ...[
                        Text(
                          '招待コード: $_referralCode',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // シェアボタン
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('リンクをコピー'),
                          onPressed: _copyLink,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3ステップ説明
                      Text(
                        'かんたん3ステップ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStep(
                        1,
                        '紹介リンクを送る',
                        'LINEやXで友達に送るだけ',
                        Icons.send,
                        const Color(0xFF6366F1),
                        isDark,
                      ),
                      _buildStep(
                        2,
                        '友達が登録する',
                        'リンクから無料で登録',
                        Icons.person_add,
                        const Color(0xFF8B5CF6),
                        isDark,
                      ),
                      _buildStep(
                        3,
                        '一緒に使い始める',
                        'メモ・資産管理・AI機能が全部無料',
                        Icons.check_circle,
                        const Color(0xFF10B981),
                        isDark,
                      ),
                      const SizedBox(height: 24),

                      // 特徴ハイライト
                      Text(
                        '自分株式会社でできること',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFeatureChip(
                            '📝 Notionライクなメモ',
                            isDark,
                          ),
                          _buildFeatureChip('💰 資産管理', isDark),
                          _buildFeatureChip('🤖 AI秘書', isDark),
                          _buildFeatureChip('📋 テンプレート17種', isDark),
                          _buildFeatureChip('📈 競合進捗バー', isDark),
                          _buildFeatureChip('🔗 公開メモシェア', isDark),
                          _buildFeatureChip('📚 習慣トラッカー', isDark),
                          _buildFeatureChip('🏆 ストリーク記録', isDark),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStep(
    int step,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFFE5E7EB) : Colors.black87,
        ),
      ),
    );
  }
}
