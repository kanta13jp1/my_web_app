import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_feed_post.dart';

/// ソーシャルフィードページ
/// social-feed Edge Function と連携してユーザーの投稿フィードを表示
class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<SocialFeedPost> _posts = [];
  String _feedType = 'public';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-commerce-hub',
        body: {'action': 'feed.timeline', 'type': _feedType, 'limit': 30},
      );
      setState(() => _posts = SocialFeedPost.listFromResponse(response.data));
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フィード取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ソーシャルフィード'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'public',
                  label: Text('パブリック'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: 'following',
                  label: Text('フォロー中'),
                  icon: Icon(Icons.people),
                ),
                ButtonSegment(
                  value: 'trending',
                  label: Text('トレンド'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: {_feedType},
              onSelectionChanged: (s) {
                setState(() => _feedType = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFE53935),
                            height: 1.5,
                          ),
                        ),
                      )
                    : _posts.isEmpty
                        ? const Center(child: Text('投稿がありません'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _posts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final post = _posts[i];
                              final createdLabel = post.createdAt.length >= 10
                                  ? post.createdAt.substring(0, 10)
                                  : post.createdAt;
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor:
                                                const Color(0xFF009688)
                                                    .withAlpha(30),
                                            child: const Icon(
                                              Icons.person,
                                              size: 18,
                                              color: Color(0xFF009688),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            '自分の投稿',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              height: 1.5,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (createdLabel.isNotEmpty)
                                            Text(
                                              createdLabel,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
                                                height: 1.5,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(post.content),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.favorite_border,
                                            size: 14,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            post.likes.toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(
                                            Icons.comment_outlined,
                                            size: 14,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            post.comments.toString(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
