import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 登録から7日以内のユーザーにのみ表示するウェルカムカード。
/// 最初の3アクションへのクイックリンクを提供し、アクティベーション率を高める。
class WelcomeNewUserCard extends StatelessWidget {
  const WelcomeNewUserCard({super.key});

  static bool shouldShow() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final createdAt = DateTime.tryParse(user.createdAt);
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt).inDays < 7;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Supabase.instance.client.auth.currentUser;
    final createdAt = DateTime.tryParse(user?.createdAt ?? '');
    final daysAgo =
        createdAt != null ? DateTime.now().difference(createdAt).inDays : 0;
    final dayLabel = daysAgo == 0 ? '今日' : '$daysAgo日前';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.4 : 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.waving_hand,
                color: Color(0xFFFFC107),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ようこそ！自分株式会社へ ($dayLabel 就任)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'まず最初の4アクションから始めましょう',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionChip(
                icon: Icons.wb_sunny_outlined,
                label: 'モーニングブリーフィング',
                onTap: () =>
                    Navigator.of(context).pushNamed('/morning-briefing'),
              ),
              _QuickActionChip(
                icon: Icons.edit_note,
                label: '最初のメモを書く',
                onTap: () => Navigator.of(context).pushNamed('/note-editor'),
              ),
              _QuickActionChip(
                icon: Icons.account_tree,
                label: 'AI組織OS を初期化',
                onTap: () => Navigator.of(context).pushNamed('/agents'),
              ),
              _QuickActionChip(
                icon: Icons.upload_file,
                label: 'Notionからインポート',
                onTap: () => Navigator.of(context).pushNamed('/import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
