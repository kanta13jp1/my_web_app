import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../services/heygen_blog_video_service.dart';

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

      // Schedule blog-draft タスクが生成した下書き + 自動 dispatch 済 (status='posted') を取得.
      // 直近 30 日 (= streak/today カウント用) は全件 / それ以前の draft は新着 10 件のみ.
      List<Map<String, dynamic>> drafts = [];
      try {
        final draftData = await _supabase
            .from('blog_posts')
            .select(
              'id, title, status, target_platforms, draft_path, posted_at, url, created_at',
            )
            .inFilter('status', ['draft', 'posted'])
            .or(
              'posted_at.gte.${DateFormat('yyyy-MM-dd').format(thirtyDaysAgo)},'
              'created_at.gte.${DateFormat('yyyy-MM-dd').format(thirtyDaysAgo)}',
            )
            .order('created_at', ascending: false)
            .limit(200);
        drafts = List<Map<String, dynamic>>.from(draftData as List);
      } catch (_) {
        // blog_posts テーブルが未作成 or 権限不足の場合は空リスト (= 既存挙動を維持)
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

  /// blog_posts.target_platforms (= 'github-pages' / 'x-article' 等の dash 表記)
  /// を tech_blog_posts.platform (= 'github_pages' / 'x_article' 等の underscore 表記) に正規化.
  String _normalizePlatformId(String raw) =>
      raw.toLowerCase().replaceAll('-', '_');

  /// 自動 dispatch (= T-1 / blog_posts.status='posted') された当日投稿の
  /// platform 一覧を flat 化.
  /// blog_posts は 1 row に複数 target_platforms を持つため expand する.
  List<String> _autoPostedPlatformsToday() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final platforms = <String>{};
    for (final draft in _scheduleDrafts) {
      if (draft['status'] != 'posted') continue;
      final postedAt = (draft['posted_at'] ?? '').toString();
      // posted_at は timestamptz なので yyyy-MM-dd で前方一致判定
      if (!postedAt.startsWith(dateStr)) continue;
      final targets = draft['target_platforms'];
      if (targets is List) {
        for (final t in targets) {
          if (t == null) continue;
          platforms.add(_normalizePlatformId(t.toString()));
        }
      }
    }
    return platforms.toList();
  }

  /// 自動 dispatch (= blog_posts.status='posted') の posted_at を yyyy-MM-dd
  /// 単位で重複排除.
  Set<String> _autoPostedDays() {
    final days = <String>{};
    for (final draft in _scheduleDrafts) {
      if (draft['status'] != 'posted') continue;
      final postedAt = (draft['posted_at'] ?? '').toString();
      if (postedAt.length >= 10) {
        days.add(postedAt.substring(0, 10));
      }
    }
    return days;
  }

  bool _isPostedToday(String platform) {
    if (_todayPosts.any((p) => p['platform'] == platform)) return true;
    return _autoPostedPlatformsToday().contains(platform);
  }

  Map<String, dynamic>? _getTodayPost(String platform) {
    try {
      return _todayPosts.firstWhere((p) => p['platform'] == platform);
    } catch (_) {
      // 自動 dispatch 由来の場合は blog_posts draft を返す (= UI で URL 抽出に使える)
      try {
        return _scheduleDrafts.firstWhere((d) {
          if (d['status'] != 'posted') return false;
          final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          if (!(d['posted_at'] ?? '').toString().startsWith(dateStr)) {
            return false;
          }
          final targets = d['target_platforms'];
          if (targets is! List) return false;
          return targets.any(
            (t) => t != null && _normalizePlatformId(t.toString()) == platform,
          );
        });
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _togglePost(String platform) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ログインが必要です'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      final existing = _getTodayPost(platform);
      if (existing != null) {
        await _supabase
            .from('tech_blog_posts')
            .delete()
            .eq('id', existing['id'] as String);
      } else {
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$platform への投稿を記録しました'),
              backgroundColor: const Color(0xFF26A69A),
            ),
          );
        }
      }
      await _load();
    } catch (e) {
      debugPrint('_togglePost error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _showAddDialog(String platform) async {
    final platformLabel = _platforms
        .firstWhere(
          (p) => p.id == platform,
          orElse: () => const _Platform('', '', '', Color(0xFF9CA3AF)),
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

  /// 直近30日の投稿数を集計（連続投稿ストリーク計算用）.
  /// tech_blog_posts (= 手動記録) + blog_posts (= 自動 dispatch / status='posted') を統合判定.
  int get _currentStreak {
    int streak = 0;
    DateTime check = DateTime.now();
    final autoDays = _autoPostedDays();
    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(check);
      final hasManual = _recentPosts.any((p) => p['posted_at'] == dateStr);
      final hasAuto = autoDays.contains(dateStr);
      if (!hasManual && !hasAuto) break;
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _copyHeyGenBlogVideoPlan(HeyGenBlogVideoPlan plan) async {
    await Clipboard.setData(ClipboardData(text: plan.clipboardText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('HeyGenブログ動画化ブリーフをコピーしました'),
        backgroundColor: Color(0xFF26A69A),
      ),
    );
  }

  int get _totalPostedDays {
    final days = <String>{};
    for (final p in _recentPosts) {
      days.add(p['posted_at']?.toString() ?? '');
    }
    days.addAll(_autoPostedDays());
    days.remove('');
    return days.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // tech_blog_posts (手動) + blog_posts (自動 dispatch) を unique platform 集計.
    final manualPlatforms =
        _todayPosts.map((p) => p['platform']?.toString() ?? '').toSet();
    final autoPlatforms = _autoPostedPlatformsToday().toSet();
    final todayCount =
        ({...manualPlatforms, ...autoPlatforms}..remove('')).length;

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
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '直近30日: $totalDays日投稿 / 本日: $todayCount プラットフォーム',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
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
                height: 1.5,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                DateFormat('yyyy年MM月dd日 (E)', 'ja').format(_selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...(_platforms.map((platform) {
          final posted = _isPostedToday(platform.id);
          final post = _getTodayPost(platform.id);
          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              onTap: () => _togglePost(platform.id),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (posted ? platform.color : const Color(0xFF9CA3AF))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    platform.emoji,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              title: Text(
                platform.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: posted ? platform.color : null,
                  height: 1.5,
                ),
              ),
              subtitle: posted && post != null
                  ? Text(
                      post['title']?.toString().isNotEmpty == true
                          ? post['title'].toString()
                          : '投稿済み',
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : Text(
                      '未投稿',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.outlineVariant,
                        height: 1.5,
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
                        color:
                            posted ? platform.color : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        posted ? '投稿済' : '未投稿',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              posted ? platform.color : const Color(0xFF9CA3AF),
                          height: 1.5,
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            Text(
              '${_scheduleDrafts.length}件',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'blog-draft タスクが自動生成した下書き（blog_posts テーブル）',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...(_scheduleDrafts.map((draft) {
          final status = draft['status']?.toString() ?? 'draft';
          final title = draft['title']?.toString() ?? '(タイトルなし)';
          final platforms = draft['target_platforms'];
          final targetPlatformLabels = (platforms is List)
              ? platforms
                  .map<String>((p) {
                    final match = _platforms.where((pl) => pl.id == p);
                    return match.isNotEmpty ? match.first.label : p.toString();
                  })
                  .where((label) => label.trim().isNotEmpty)
                  .toList(
                    growable: false,
                  )
              : const <String>[];
          final platformLabels = targetPlatformLabels.join(', ');
          final createdAt = DateTime.tryParse(
            draft['created_at']?.toString() ?? '',
          );
          final dateLabel = createdAt != null
              ? DateFormat('MM/dd HH:mm').format(createdAt)
              : '';
          final isPosted = status == 'posted';
          final plan = HeyGenBlogVideoService.buildPlan(
            title: title,
            draftPath: draft['draft_path']?.toString(),
            sourceUrl: draft['url']?.toString(),
            targetPlatforms: targetPlatformLabels,
          );

          return Card(
            color: const Color(0xFF1E1E1E),
            margin: const EdgeInsets.only(bottom: 6),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              leading: Icon(
                isPosted ? Icons.check_circle : Icons.edit_note,
                color: isPosted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF6366F1),
                size: 22,
              ),
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$dateLabel  |  $platformLabels  |  ${isPosted ? '投稿済み' : '下書き'}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF4B5563),
                  height: 1.5,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPosted
                      ? const Color(0xFF4CAF50).withAlpha(20)
                      : const Color(0xFF6366F1).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPosted ? '投稿済' : '下書き',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPosted
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFF6366F1),
                    height: 1.5,
                  ),
                ),
              ),
              children: [_buildHeyGenBlogVideoPlan(plan, isDark)],
            ),
          );
        })),
      ],
    );
  }

  Widget _buildHeyGenBlogVideoPlan(HeyGenBlogVideoPlan plan, bool isDark) {
    final foreground = isDark ? Colors.white : const Color(0xFFE5E7EB);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFFC7D2FE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_camera_front, color: Color(0xFF38BDF8)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'HeyGenブログ動画化',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _copyHeyGenBlogVideoPlan(plan),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('コピー'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.productionBrief,
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          ...plan.scenes.map(
            (scene) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scene.label,
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scene.narration,
                    style: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Caption: ${scene.caption}',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: plan.reuseChecklist
                .map(
                  (item) => Chip(
                    label: Text(item),
                    labelStyle: const TextStyle(
                      color: Color(0xFFE5E7EB),
                      fontSize: 11,
                    ),
                    backgroundColor: const Color(0xFF1E293B),
                    side: const BorderSide(color: Color(0xFF334155)),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
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
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
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
                      height: 1.5,
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
                          Color(0xFF9CA3AF),
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
                              height: 1.5,
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
