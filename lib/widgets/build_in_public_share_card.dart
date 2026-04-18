import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// 「Build in Public」X シェアカード。
///
/// ユーザーの使用状況（ログイン日数・メモ数・ストリーク）を集計し、
/// X (Twitter) に使用感をシェアするボタンを提供する。
/// ユーザーのシェアで新規流入を増やすバイラル戦略の中核。
class BuildInPublicShareCard extends StatefulWidget {
  const BuildInPublicShareCard({super.key});

  @override
  State<BuildInPublicShareCard> createState() => _BuildInPublicShareCardState();
}

class _BuildInPublicShareCardState extends State<BuildInPublicShareCard> {
  bool _loading = true;
  int _noteCount = 0;
  int _streakDays = 0;
  int _daysUsing = 0;

  static const _appUrl = 'https://my-web-app-b67f4.web.app';
  static const _appName = '自分株式会社';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final notesFuture = client.from('notes').select('id').eq('user_id', uid);
      final statsFuture = client
          .from('user_stats')
          .select('current_streak, created_at')
          .eq('user_id', uid)
          .maybeSingle();

      final notes = await notesFuture;
      final stats = await statsFuture;

      final noteCount = notes.length;
      final streak = (stats?['current_streak'] as num?)?.toInt() ?? 0;
      int days = 0;
      if (stats?['created_at'] != null) {
        final createdAt = DateTime.tryParse(stats!['created_at'].toString());
        if (createdAt != null) {
          days = DateTime.now().difference(createdAt).inDays + 1;
        }
      }

      if (mounted) {
        setState(() {
          _noteCount = noteCount;
          _streakDays = streak;
          _daysUsing = days;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _shareToX() async {
    final streakText = _streakDays > 0 ? '$_streakDays日連続ログイン中🔥' : '';
    final daysText = _daysUsing > 0 ? '使用$_daysUsing日目' : '';
    final noteText = _noteCount > 0 ? 'メモ$_noteCount件作成' : '';

    final parts = [daysText, streakText, noteText].where((s) => s.isNotEmpty);
    final statsLine = parts.isNotEmpty ? parts.join(' / ') : '';

    final tweetText = '$_appName を試しています！$statsLine\n\n'
        'Notion・MoneyForward を1アプリに統合した AI ライフマネジメント。'
        '無料で使えます 👇\n$_appUrl\n\n'
        '#buildinpublic #自分株式会社 #FlutterWeb';

    final encoded = Uri.encodeComponent(tweetText);
    final url = Uri.parse('https://twitter.com/intent/tweet?text=$encoded');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return const SizedBox.shrink();
    if (_loading) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Color(0xFF1A2233), Color(0xFF0D1424)]
              : [Color(0xFFF0F9FF), Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Color(0xFF1D4ED8).withAlpha(80)
              : Color(0xFF7DD3FC),
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
                  color: Colors.black.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('𝕏', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Build in Public でシェア',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Color(0xFF0C4A6E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          if (_noteCount > 0 || _streakDays > 0 || _daysUsing > 0)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_daysUsing > 0)
                  _StatChip(
                    label: '使用$_daysUsing日目',
                    icon: Icons.calendar_today,
                    isDark: isDark,
                  ),
                if (_streakDays > 0)
                  _StatChip(
                    label: '$_streakDays日連続🔥',
                    icon: Icons.local_fire_department,
                    isDark: isDark,
                  ),
                if (_noteCount > 0)
                  _StatChip(
                    label: 'メモ$_noteCount件',
                    icon: Icons.note_alt,
                    isDark: isDark,
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Text(
            '使用状況を X でシェアして仲間を増やしましょう！',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Color(0xFF94A3B8) : Color(0xFF0369A1),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _shareToX,
              icon: const Text('𝕏', style: TextStyle(fontSize: 14)),
              label: const Text('X (Twitter) でシェア'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? Colors.white : Color(0xFF0C4A6E),
                side: BorderSide(
                  color: isDark
                      ? Color(0xFF1D4ED8).withAlpha(150)
                      : Color(0xFF38BDF8),
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withAlpha(15) : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(30) : Color(0xFFBAE6FD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: isDark ? Colors.white70 : Color(0xFF0369A1),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Color(0xFF0369A1),
            ),
          ),
        ],
      ),
    );
  }
}
