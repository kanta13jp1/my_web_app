import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

/// テック技術ブログ投稿管理ページ
/// Zenn/Qiita/はてなブログ/note/Medium/dev.to/Hashnode/Substack/GitHub Pages/NOTION/X Article への
/// 毎日の投稿状況を管理・記録するページ。
class TechBlogTrackerPage extends StatefulWidget {
  const TechBlogTrackerPage({super.key});

  @override
  State<TechBlogTrackerPage> createState() => _TechBlogTrackerPageState();
}

class _TechBlogTrackerPageState extends State<TechBlogTrackerPage> {
  final _supabase = Supabase.instance.client;

  static const _platforms = [
    _Platform('zenn', 'Zenn', '📝', Color(0xFF3EA8FF)),
    _Platform('qiita', 'Qiita', '🟢', Color(0xFF55C500)),
    _Platform('hatena', 'はてなブログ', '🔵', Color(0xFF00A4DE)),
    _Platform('note', 'note', '🔴', Color(0xFF41C9B4)),
    _Platform('medium', 'Medium', '⚫', Color(0xFF000000)),
    _Platform('devto', 'dev.to', '⬛', Color(0xFF0A0A0A)),
    _Platform('hashnode', 'Hashnode', '💙', Color(0xFF2962FF)),
    _Platform('substack', 'Substack', '🟠', Color(0xFFFF6719)),
    _Platform('github_pages', 'GitHub Pages', '🐙', Color(0xFF24292E)),
    _Platform('notion', 'NOTION', '⬜', Color(0xFF37352F)),
    _Platform('x_article', 'X Article', '𝕏', Color(0xFF000000)),
  ];

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _todayPosts = [];
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _scheduleDrafts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final thirtyDaysAgo = _selectedDate.subtract(const Duration(days: 30));

      final results = await Future.wait([
        _supabase
            .from('tech_blog_posts')
            .select()
            .eq('user_id', userId)
            .eq('posted_at', dateStr)
            .order('created_at'),
        _supabase
            .from('tech_blog_posts')
            .select()
            .eq('user_id', userId)
            .gte('posted_at', DateFormat('yyyy-MM-dd').format(thirtyDaysAgo))
            .order('posted_at', ascending: false),
      ]);

      // Schedule blog-draft タスクが生成した下書きを取得
      List<Map<String, dynamic>> drafts = [];
      try {
        final draftData = await _supabase
            .from('blog_posts')
            .select(
              'id, title, status, target_platforms, draft_path, posted_at, url, created_at',
            )
            .inFilter('status', ['draft', 'posted'])
            .order('created_at', ascending: false)
            .limit(10);
        drafts = List<Map<String, dynamic>>.from(draftData as List);
      } catch (_) {
        // blog_posts テーブルが未作成の場合は空リスト
      }

      if (!mounted) return;
      setState(() {
        _todayPosts = List<Map<String, dynamic>>.from(results[0] as List);
        _recentPosts = List<Map<String, dynamic>>.from(results[1] as List);
        _scheduleDrafts = drafts;
        _loading = false;
      });
    } catch (e) {
      debugPrint('TechBlogTrackerPage load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isPostedToday(String platform) {
    return _todayPosts.any((p) => p['platform'] == platform);
  }

  Map<String, dynamic>? _getTodayPost(String platform) {
    try {
      return _todayPosts.firstWhere((p) => p['platform'] == platform);
    } catch (_) {
      return null;
    }
  }

  Future<void> _togglePost(String platform) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existing = _getTodayPost(platform);
    if (existing != null) {
      // 削除
      await _supabase.from('tech_blog_posts').delete().eq('id', existing['id']);
    } else {
      // 追加ダイアログ
      final result = await _showAddDialog(platform);
      if (result == null) return;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await _supabase.from('tech_blog_posts').insert({
        'user_id': userId,
        'platform': platform,
        'title': result['title'] ?? '',
        'url': result['url'] ?? '',
        'notes': result['notes'] ?? '',
        'posted_at': dateStr,
      });
    }
    await _load();
  }

  Future<Map<String, String>?> _showAddDialog(String platform) async {
    final platformLabel = _platforms
        .firstWhere(
          (p) => p.id == platform,
          orElse: () => const _Platform('', '', '', Colors.grey),
        )
        .label;
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$platformLabel に投稿を記録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '記事タイトル',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'URL（任意）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': titleCtrl.text,
              'url': urlCtrl.text,
              'notes': notesCtrl.text,
            }),
            child: const Text('記録する'),
          ),
        ],
      ),
    );
  }

  /// 直近30日の投稿数を集計（連続投稿ストリーク計算用）
  int get _currentStreak {
    int streak = 0;
    DateTime check = DateTime.now();
    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(check);
      final hasPost = _recentPosts.any((p) => p['posted_at'] == dateStr);
      if (!hasPost) break;
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int get _totalPostedDays {
    final days = <String>{};
    for (final p in _recentPosts) {
      days.add(p['posted_at']?.toString() ?? '');
    }
    return days.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayCount = _todayPosts.map((p) => p['platform']).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('技術ブログ投稿管理'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStreakCard(isDark, todayCount),
                  const SizedBox(height: 16),
                  _buildDateSelector(),
                  const SizedBox(height: 16),
                  _buildPlatformList(isDark),
                  const SizedBox(height: 24),
                  _buildScheduleDrafts(isDark),
                  const SizedBox(height: 24),
                  _buildRecentHistory(isDark),
                ],
              ),
            ),
    );
  }

  Widget _buildStreakCard(bool isDark, int todayCount) {
    final streak = _currentStreak;
    final totalDays = _totalPostedDays;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF3F51B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🔥 $streak日連続投稿中',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '直近30日: $totalDays日投稿 / 本日: $todayCount プラットフォーム',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$streak',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(
              () => _selectedDate =
                  _selectedDate.subtract(const Duration(days: 1)),
            );
            _load();
          },
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2026, 1, 1),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _load();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _selectedDate.isBefore(DateTime.now())
              ? () {
                  setState(
                    () => _selectedDate =
                        _selectedDate.add(const Duration(days: 1)),
                  );
                  _load();
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPlatformList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '投稿プラットフォーム',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...(_platforms.map((platform) {
          final posted = _isPostedToday(platform.id);
          final post = _getTodayPost(platform.id);
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (posted ? platform.color : Colors.grey)
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    platform.emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              title: Text(
                platform.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: posted ? platform.color : null,
                ),
              ),
              subtitle: posted && post != null
                  ? Text(
                      post['title']?.toString().isNotEmpty == true
                          ? post['title'].toString()
                          : '投稿済み',
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      '未投稿',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
              trailing: GestureDetector(
                onTap: () => _togglePost(platform.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: posted
                        ? platform.color.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: posted
                          ? platform.color.withValues(alpha: 0.4)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        posted ? Icons.check_circle : Icons.circle_outlined,
                        size: 14,
                        color: posted ? platform.color : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        posted ? '投稿済' : '未投稿',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: posted ? platform.color : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        })),
      ],
    );
  }

  Widget _buildScheduleDrafts(bool isDark) {
    if (_scheduleDrafts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Schedule 自動生成ドラフト',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            Text(
              '${_scheduleDrafts.length}件',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'blog-draft タスクが自動生成した下書き（blog_posts テーブル）',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey[500] : Colors.grey[500],
          ),
        ),
        const SizedBox(height: 8),
        ...(_scheduleDrafts.map((draft) {
          final status = draft['status']?.toString() ?? 'draft';
          final title = draft['title']?.toString() ?? '(タイトルなし)';
          final platforms = draft['target_platforms'];
          final platformLabels = (platforms is List)
              ? platforms.map((p) {
                  final match = _platforms.where((pl) => pl.id == p);
                  return match.isNotEmpty ? match.first.label : p.toString();
                }).join(', ')
              : '';
          final createdAt = DateTime.tryParse(
            draft['created_at']?.toString() ?? '',
          );
          final dateLabel = createdAt != null
              ? DateFormat('MM/dd HH:mm').format(createdAt)
              : '';
          final isPosted = status == 'posted';

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: Icon(
                isPosted ? Icons.check_circle : Icons.edit_note,
                color: isPosted ? Colors.green : const Color(0xFF6366F1),
                size: 22,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$dateLabel  |  $platformLabels',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPosted
                      ? Colors.green.withAlpha(20)
                      : const Color(0xFF6366F1).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPosted ? '投稿済' : '下書き',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPosted ? Colors.green : const Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          );
        })),
      ],
    );
  }

  Widget _buildRecentHistory(bool isDark) {
    if (_recentPosts.isEmpty) {
      return const SizedBox.shrink();
    }

    // 日付でグループ化
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final post in _recentPosts) {
      final date = post['posted_at']?.toString() ?? '';
      grouped.putIfAbsent(date, () => []).add(post);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '投稿履歴（直近30日）',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...sortedDates.take(14).map((date) {
          final posts = grouped[date]!;
          final dt = DateTime.tryParse(date);
          final label =
              dt != null ? DateFormat('MM/dd (E)', 'ja').format(dt) : date;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: posts.map((post) {
                      final platform = _platforms.firstWhere(
                        (p) => p.id == post['platform'],
                        orElse: () => const _Platform(
                          '',
                          '',
                          '?',
                          Colors.grey,
                        ),
                      );
                      return Tooltip(
                        message: post['title']?.toString().isNotEmpty == true
                            ? post['title'].toString()
                            : platform.label,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: platform.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${platform.emoji} ${platform.label}',
                            style: TextStyle(
                              fontSize: 10,
                              color: platform.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Platform {
  final String id;
  final String label;
  final String emoji;
  final Color color;

  const _Platform(this.id, this.label, this.emoji, this.color);
}
