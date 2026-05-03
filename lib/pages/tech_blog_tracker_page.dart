import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/heygen_blog_video_service.dart';
import '../services/blog_publish_service.dart';

/// テック技術ブログ投稿管理ページ
/// Qiita/dev.to への自動公開 + 9 プラットフォームの手動トラッキング。
/// blog_posts テーブル (drafts/posted) の CRUD を UI から操作可能。
class TechBlogTrackerPage extends StatefulWidget {
  const TechBlogTrackerPage({super.key});

  @override
  State<TechBlogTrackerPage> createState() => _TechBlogTrackerPageState();
}

class _TechBlogTrackerPageState extends State<TechBlogTrackerPage> {
  final _supabase = Supabase.instance.client;

  // 🤖 自動公開対象プラットフォーム (schedule-hub blog.publish_post)
  static const _autoPlatforms = [
    _Platform('qiita', 'Qiita', '🟢', Color(0xFF55C500)),
    _Platform('devto', 'dev.to', '⬛', Color(0xFF0A0A0A)),
  ];

  // ✍️ 手動トラッキング対象プラットフォーム
  static const _manualPlatforms = [
    _Platform('zenn', 'Zenn', '📝', Color(0xFF3EA8FF)),
    _Platform('hatena', 'はてなブログ', '🔵', Color(0xFF00A4DE)),
    _Platform('note', 'note', '🔴', Color(0xFF41C9B4)),
    _Platform('medium', 'Medium', '⚫', Color(0xFF000000)),
    _Platform('hashnode', 'Hashnode', '💙', Color(0xFF2962FF)),
    _Platform('substack', 'Substack', '🟠', Color(0xFFFF6719)),
    _Platform('github_pages', 'GitHub Pages', '🐙', Color(0xFF24292E)),
    _Platform('notion', 'NOTION', '⬜', Color(0xFF37352F)),
    _Platform('x_article', 'X Article', '𝕏', Color(0xFF000000)),
  ];

  static List<_Platform> get _allPlatforms =>
      [..._autoPlatforms, ..._manualPlatforms];

  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _todayPosts = [];
  List<Map<String, dynamic>> _recentPosts = [];
  List<Map<String, dynamic>> _scheduleDrafts = [];
  bool _loading = true;
  bool _publishing = false;
  String? _draftLoadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _draftLoadError = null;
    });
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

      // Win版#132 part 124: T-1 dispatch 済の posted blog metadata を schedule-hub
      // EF (= blog.recent_posted action / public read / hub_data 由来) から取得.
      // 旧実装は blog_posts テーブルを直接 select していたが、実際の dispatch は
      // hub_data (source='blog_post' / user_id='system') に書き込まれるため空 list だった.
      List<Map<String, dynamic>> drafts = [];
      try {
        final response = await _supabase.functions.invoke(
          'schedule-hub',
          body: {'action': 'blog.recent_posted', 'days': 30, 'limit': 200},
        );
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final items = data['items'];
          if (items is List) {
            drafts = items
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }
      } catch (_) {
        // EF call 失敗時は空リスト (= 既存挙動と同じ動作 / degrade safe)
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

  String _normalizePlatformId(String raw) =>
      raw.toLowerCase().replaceAll('-', '_');

  List<String> _autoPostedPlatformsToday() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final platforms = <String>{};
    for (final draft in _scheduleDrafts) {
      if (draft['status'] != 'posted') continue;
      final postedAt = (draft['posted_at'] ?? '').toString();
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
    final platformLabel = _allPlatforms
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

  // ─── CRUD actions for blog_posts (drafts) ────────────────────────────────

  Future<void> _publishDraft(Map<String, dynamic> draft) async {
    final id = draft['id']?.toString();
    if (id == null) return;

    final content = draft['content']?.toString() ?? '';
    if (content.trim().isEmpty) {
      if (!mounted) return;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('コンテンツが空です'),
          content: const Text('このドラフトにはコンテンツがありません。編集してから公開することをお勧めします。このまま公開しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('このまま公開'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        await _showEditDraftDialog(draft);
        return;
      }
    }

    setState(() => _publishing = true);
    try {
      final result = await BlogPublishService.publishPost(id: id);
      if (!mounted) return;
      final qiitaUrl = result['qiita_url']?.toString();
      final devtoUrl = result['devto_url']?.toString();
      final urlText = [
        if (qiitaUrl != null) 'Qiita: $qiitaUrl',
        if (devtoUrl != null) 'dev.to: $devtoUrl',
      ].join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(urlText.isNotEmpty ? '公開しました！\n$urlText' : '公開しました！'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 6),
          action: qiitaUrl != null
              ? SnackBarAction(
                  label: 'Qiita で開く',
                  onPressed: () => launchUrl(Uri.parse(qiitaUrl)),
                )
              : null,
        ),
      );
      await _load();
    } catch (e) {
      debugPrint('_publishDraft error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('公開に失敗しました: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _showEditDraftDialog(Map<String, dynamic> draft) async {
    final id = draft['id']?.toString();
    if (id == null) return;

    final titleCtrl =
        TextEditingController(text: draft['title']?.toString() ?? '');
    final contentCtrl =
        TextEditingController(text: draft['content']?.toString() ?? '');
    final notesCtrl =
        TextEditingController(text: draft['notes']?.toString() ?? '');
    final platforms = draft['target_platforms'];
    final selectedPlatforms = (platforms is List)
        ? platforms.map((p) => p.toString()).toList()
        : ['qiita', 'devto'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ドラフトを編集'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'コンテンツ (Markdown)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    try {
      await BlogPublishService.updatePost(
        id,
        title: titleCtrl.text,
        content: contentCtrl.text,
        notes: notesCtrl.text,
        targetPlatforms: selectedPlatforms,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ドラフトを更新しました'),
            backgroundColor: Color(0xFF26A69A),
          ),
        );
      }
      await _load();
    } catch (e) {
      debugPrint('_showEditDraftDialog error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showNewDraftDialog() async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規ドラフトを作成'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'タイトル *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                decoration: const InputDecoration(
                  labelText: 'コンテンツ (Markdown、任意)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );

    if (saved != true || titleCtrl.text.trim().isEmpty) return;
    try {
      await BlogPublishService.insertPost(
        title: titleCtrl.text.trim(),
        content: contentCtrl.text,
        notes: notesCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ドラフトを作成しました'),
            backgroundColor: Color(0xFF26A69A),
          ),
        );
      }
      await _load();
    } catch (e) {
      debugPrint('_showNewDraftDialog error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('作成に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteDraft(Map<String, dynamic> draft) async {
    final id = draft['id']?.toString();
    if (id == null) return;
    final title = draft['title']?.toString() ?? '(タイトルなし)';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ドラフトを削除'),
        content: Text('「$title」を削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await BlogPublishService.deletePost(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ドラフトを削除しました'),
            backgroundColor: Color(0xFF26A69A),
          ),
        );
      }
      await _load();
    } catch (e) {
      debugPrint('_deleteDraft error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Streak / count helpers ───────────────────────────────────────────────

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

  int get _totalPostedDays {
    final days = <String>{};
    for (final p in _recentPosts) {
      days.add(p['posted_at']?.toString() ?? '');
    }
    days.addAll(_autoPostedDays());
    days.remove('');
    return days.length;
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

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final manualPlatforms =
        _todayPosts.map((p) => p['platform']?.toString() ?? '').toSet();
    final autoPlatformsToday = _autoPostedPlatformsToday().toSet();
    final todayCount =
        ({...manualPlatforms, ...autoPlatformsToday}..remove('')).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('技術ブログ投稿管理'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新規ドラフト',
            onPressed: _showNewDraftDialog,
          ),
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
                  _buildAutoPlatformSection(isDark),
                  const SizedBox(height: 16),
                  _buildManualPlatformSection(isDark),
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
                firstDate: DateTime(2024, 1, 1),
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

  Widget _buildAutoPlatformSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_toy, size: 16, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            const Text(
              '🤖 自動公開プラットフォーム',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'schedule-hub が Qiita / dev.to に自動公開します',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...(_autoPlatforms.map((platform) => _buildPlatformTile(platform))),
      ],
    );
  }

  Widget _buildManualPlatformSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit, size: 16, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 6),
            const Text(
              '✍️ 手動トラッキング',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'タップして投稿記録を手動で登録',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        ...(_manualPlatforms.map((platform) => _buildPlatformTile(platform))),
      ],
    );
  }

  Widget _buildPlatformTile(_Platform platform) {
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
              style: const TextStyle(fontSize: 16, height: 1.5),
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
                style: const TextStyle(fontSize: 11, height: 1.5),
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
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: posted
                ? platform.color.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: posted
                  ? platform.color.withValues(alpha: 0.4)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                posted ? Icons.check_circle : Icons.circle_outlined,
                size: 14,
                color: posted ? platform.color : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                posted ? '投稿済' : '未投稿',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: posted ? platform.color : const Color(0xFF9CA3AF),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleDrafts(bool isDark) {
    final draftCount =
        _scheduleDrafts.where((d) => d['status'] == 'draft').length;
    final postedCount =
        _scheduleDrafts.where((d) => d['status'] == 'posted').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF6366F1)),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'ブログ下書き管理',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ),
            Text(
              '下書き $draftCount / 投稿済 $postedCount',
              style: TextStyle(
                fontSize: 12,
                color:
                    isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _showNewDraftDialog,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新規', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_draftLoadError != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'blog_posts の取得に失敗: $_draftLoadError',
                    style: const TextStyle(color: Colors.red, fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'blog_posts テーブル — 下書きを公開・編集・削除できます',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF6B7280),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        if (_scheduleDrafts.isEmpty && _draftLoadError == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.inbox, color: Color(0xFF6B7280), size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'ドラフトがありません。「新規」ボタンで作成するか、docs/blog-drafts/ に .md ファイルを push してください。',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...(_scheduleDrafts.map((draft) => _buildDraftCard(draft, isDark))),
      ],
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft, bool isDark) {
    final status = draft['status']?.toString() ?? 'draft';
    final title = draft['title']?.toString() ?? '(タイトルなし)';
    final platforms = draft['target_platforms'];
    final targetPlatformLabels = (platforms is List)
        ? platforms
            .map<String>((p) {
              final match = _allPlatforms.where((pl) => pl.id == p);
              return match.isNotEmpty ? match.first.label : p.toString();
            })
            .where((label) => label.trim().isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final platformLabels = targetPlatformLabels.join(', ');
    final createdAt =
        DateTime.tryParse(draft['created_at']?.toString() ?? '');
    final dateLabel =
        createdAt != null ? DateFormat('MM/dd HH:mm').format(createdAt) : '';
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
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        leading: Icon(
          isPosted ? Icons.check_circle : Icons.edit_note,
          color:
              isPosted ? const Color(0xFF4CAF50) : const Color(0xFF6366F1),
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
        trailing: isPosted
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '投稿済',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4CAF50),
                    height: 1.5,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_publishing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.rocket_launch,
                          size: 18, color: Color(0xFF4CAF50)),
                      tooltip: '今すぐ公開 (Qiita / dev.to)',
                      onPressed: () => _publishDraft(draft),
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit,
                        size: 18, color: Color(0xFF6366F1)),
                    tooltip: '編集',
                    onPressed: () => _showEditDraftDialog(draft),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFF9CA3AF)),
                    tooltip: '削除',
                    onPressed: () => _deleteDraft(draft),
                  ),
                ],
              ),
        children: [_buildHeyGenBlogVideoPlan(plan, isDark)],
      ),
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
                      final platform = _allPlatforms.firstWhere(
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
