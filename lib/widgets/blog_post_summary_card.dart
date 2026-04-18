import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// ホーム画面に表示するブログ投稿状況のサマリーカード。
/// 今日どのプラットフォームに投稿したか、連続投稿日数を表示する。
class BlogPostSummaryCard extends StatefulWidget {
  const BlogPostSummaryCard({super.key});

  @override
  State<BlogPostSummaryCard> createState() => _BlogPostSummaryCardState();
}

class _BlogPostSummaryCardState extends State<BlogPostSummaryCard> {
  bool _loading = true;
  int _todayCount = 0;
  int _weekCount = 0;
  int _streak = 0;
  List<_PlatformStatus> _platforms = [];

  static const _platformDefs = [
    ('zenn', 'Zenn', Color(0xFF3EA8FF)),
    ('qiita', 'Qiita', Color(0xFF55C500)),
    ('hatena', 'はてな', Color(0xFF00A4DE)),
    ('note', 'note', Color(0xFF41C9B4)),
    ('medium', 'Medium', Color(0xFF000000)),
    ('devto', 'dev.to', Color(0xFF0A0A0A)),
    ('hashnode', 'Hashnode', Color(0xFF2962FF)),
    ('substack', 'Substack', Color(0xFFFF6719)),
    ('github_pages', 'GitHub', Color(0xFF24292E)),
    ('notion', 'NOTION', Color(0xFF37352F)),
    ('x_article', 'X', Color(0xFF000000)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final weekAgo = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 7)),
      );

      final results = await Future.wait([
        Supabase.instance.client
            .from('tech_blog_posts')
            .select('platform, posted_at')
            .eq('user_id', userId)
            .eq('posted_at', today),
        Supabase.instance.client
            .from('tech_blog_posts')
            .select('platform, posted_at')
            .eq('user_id', userId)
            .gte('posted_at', weekAgo)
            .order('posted_at', ascending: false),
      ]);

      final todayPosts = List<Map<String, dynamic>>.from(results[0] as List);
      final weekPosts = List<Map<String, dynamic>>.from(results[1] as List);

      // 連続投稿日数を計算
      final postedDates = <String>{};
      for (final p in weekPosts) {
        final d = p['posted_at']?.toString();
        if (d != null) postedDates.add(d);
      }
      int streak = 0;
      var checkDate = DateTime.now();
      for (int i = 0; i < 30; i++) {
        final ds = DateFormat('yyyy-MM-dd').format(checkDate);
        if (postedDates.contains(ds) || (i == 0 && todayPosts.isNotEmpty)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else if (i == 0) {
          // 今日まだ投稿してない場合、昨日からカウント
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      // プラットフォーム別の今日の投稿状況
      final todayPlatformIds =
          todayPosts.map((p) => p['platform']?.toString()).toSet();
      final platforms = _platformDefs.map((def) {
        return _PlatformStatus(
          id: def.$1,
          name: def.$2,
          color: def.$3,
          posted: todayPlatformIds.contains(def.$1),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _todayCount = todayPosts.length;
        _weekCount = weekPosts.length;
        _streak = streak;
        _platforms = platforms;
        _loading = false;
      });
    } catch (e) {
      debugPrint('BlogPostSummaryCard error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: const Color(0xFFB0B0B0).withAlpha(40)),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed('/tech-blog-tracker'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.article_outlined,
                    size: 20,
                    color: Color(0xFF4338CA),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '技術ブログ投稿',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🔥 $_streak日連続',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ),
                ],
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildMetric('今日', '$_todayCount件'),
                    const SizedBox(width: 16),
                    _buildMetric('今週', '$_weekCount件'),
                    const Spacer(),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: Color(0xFFB0B0B0),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _platforms.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: p.posted
                            ? p.color.withAlpha(25)
                            : const Color(0xFFB0B0B0).withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: p.posted
                              ? p.color.withAlpha(80)
                              : const Color(0xFFB0B0B0).withAlpha(30),
                        ),
                      ),
                      child: Text(
                        p.posted ? '✓ ${p.name}' : p.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              p.posted ? FontWeight.w700 : FontWeight.normal,
                          color: p.posted ? p.color : const Color(0xFFB0B0B0),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlatformStatus {
  final String id;
  final String name;
  final Color color;
  final bool posted;
  const _PlatformStatus({
    required this.id,
    required this.name,
    required this.color,
    required this.posted,
  });
}
