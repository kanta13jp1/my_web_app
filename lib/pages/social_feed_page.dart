import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<dynamic> _posts = [];
  String _feedType = 'public';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'social-feed',
        body: {'type': _feedType, 'limit': 30},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['posts'] is List) {
        setState(() => _posts = data['posts'] as List);
      } else if (data is List) {
        setState(() => _posts = data);
      }
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
        backgroundColor: Colors.teal,
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
                          style: const TextStyle(color: Colors.red),
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
                              final post =
                                  _posts[i] as Map<String, dynamic>;
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
                                                Colors.teal.withAlpha(30),
                                            child: Text(
                                              (post['username']
                                                          ?.toString()
                                                          .isNotEmpty ==
                                                      true
                                                  ? post['username']
                                                      .toString()[0]
                                                      .toUpperCase()
                                                  : '?'),
                                              style: const TextStyle(
                                                color: Colors.teal,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            post['username']?.toString() ??
                                                '匿名',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (post['created_at'] != null)
                                            Text(
                                              post['created_at']
                                                  .toString()
                                                  .substring(0, 10),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        post['content']?.toString() ?? '',
                                      ),
                                      if (post['likes'] != null ||
                                          post['comments'] != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (post['likes'] != null) ...[
                                              const Icon(
                                                Icons.favorite_border,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                post['likes'].toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                            ],
                                            if (post['comments'] != null) ...[
                                              const Icon(
                                                Icons.comment_outlined,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                post['comments'].toString(),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
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
