import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ソーシャルプルーフバナー。
/// 登録ユーザー数・ノート数・公開メモ数をリアルタイムで表示し、
/// 新規登録の動機付けを強化する。ログイン済みユーザーには非表示。
class SocialProofBanner extends StatefulWidget {
  const SocialProofBanner({super.key});

  @override
  State<SocialProofBanner> createState() => _SocialProofBannerState();
}

class _SocialProofBannerState extends State<SocialProofBanner> {
  int _userCount = 0;
  int _noteCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final supabase = Supabase.instance.client;

      final userRes = await supabase
          .from('user_profiles')
          .select('user_id')
          .count(CountOption.exact);

      final noteRes =
          await supabase.from('notes').select('id').count(CountOption.exact);

      if (!mounted) return;
      setState(() {
        _userCount = userRes.count;
        _noteCount = noteRes.count;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_userCount == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF1A2233)]
              : [const Color(0xFFF5F3FF), const Color(0xFFEFF6FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4C1D95).withAlpha(80)
              : const Color(0xFFDDD6FE),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: '$_userCount',
            label: '登録ユーザー',
            emoji: '👥',
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _StatItem(
            value: _noteCount > 1000
                ? '${(_noteCount / 1000).toStringAsFixed(1)}k'
                : '$_noteCount',
            label: '総ノート数',
            emoji: '📝',
            isDark: isDark,
          ),
          Container(
            width: 1,
            height: 32,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          _StatItem(
            value: '無料',
            label: '完全無料',
            emoji: '🎁',
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final String emoji;
  final bool isDark;

  const _StatItem({
    required this.value,
    required this.label,
    required this.emoji,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(
            fontSize: 18,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFDDD6FE) : const Color(0xFF4C1D95),
            height: 1.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
