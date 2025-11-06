import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/public_memo_service.dart';
import '../models/public_memo.dart';
import '../utils/app_logger.dart';

class MemoGalleryPage extends StatefulWidget {
  const MemoGalleryPage({super.key});

  @override
  State<MemoGalleryPage> createState() => _MemoGalleryPageState();
}

class _MemoGalleryPageState extends State<MemoGalleryPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late PublicMemoService _memoService;
  late TabController _tabController;

  List<PublicMemo> _recentMemos = [];
  List<PublicMemo> _trendingMemos = [];
  List<PublicMemo> _popularMemos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _memoService = PublicMemoService(_supabase);
    _tabController = TabController(length: 3, vsync: this);
    _loadMemos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMemos() async {
    setState(() => _isLoading = true);

    try {
      final recent = await _memoService.getPublicMemos(
        limit: 20,
        sortBy: 'published_at',
      );
      final trending = await _memoService.getTrendingMemos(limit: 20);
      final popular = await _memoService.getPublicMemos(
        limit: 20,
        sortBy: 'like_count',
      );

      setState(() {
        _recentMemos = recent;
        _trendingMemos = trending;
        _popularMemos = popular;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load memos', e, stackTrace);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(PublicMemo memo) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしてください')),
      );
      return;
    }

    try {
      final hasLiked = await _memoService.hasUserLikedMemo(memo.id, userId);

      if (hasLiked) {
        await _memoService.unlikeMemo(memo.id, userId);
      } else {
        await _memoService.likeMemo(memo.id, userId);
      }

      _loadMemos(); // Reload to update counts
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle like', e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモギャラリー'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '最新'),
            Tab(text: 'トレンド'),
            Tab(text: '人気'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMemoList(_recentMemos, '最新のメモはありません'),
                _buildMemoList(_trendingMemos, 'トレンドメモはありません'),
                _buildMemoList(_popularMemos, '人気のメモはありません'),
              ],
            ),
    );
  }

  Widget _buildMemoList(List<PublicMemo> memos, String emptyMessage) {
    if (memos.isEmpty) {
      return Center(child: Text(emptyMessage));
    }

    return RefreshIndicator(
      onRefresh: _loadMemos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: memos.length,
        itemBuilder: (context, index) => _buildMemoCard(memos[index]),
      ),
    );
  }

  Widget _buildMemoCard(PublicMemo memo) {
    final userId = _supabase.auth.currentUser?.id;
    final isLoggedIn = userId != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewMemoDetails(memo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (memo.category != null && memo.category!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        memo.category!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _formatDate(memo.publishedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                memo.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (memo.content != null && memo.content!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  memo.content!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: Colors.red[400],
                      size: 20,
                    ),
                    onPressed: isLoggedIn ? () => _toggleLike(memo) : null,
                    tooltip: 'いいね',
                  ),
                  Text(
                    '${memo.likeCount}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.visibility, size: 20, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${memo.viewCount}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}分前';
      }
      return '${difference.inHours}時間前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  void _viewMemoDetails(PublicMemo memo) async {
    // Increment view count
    await _memoService.incrementViewCount(memo.id);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(memo.title),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (memo.category != null) ...[
                  Text(
                    'カテゴリー: ${memo.category}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(memo.content ?? 'コンテンツがありません'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.favorite, size: 16, color: Colors.red[400]),
                    const SizedBox(width: 4),
                    Text('${memo.likeCount}'),
                    const SizedBox(width: 16),
                    Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('${memo.viewCount}'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }
}
