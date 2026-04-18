import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ニュース・RSSアグリゲーターページ
/// tools-hub Edge Function (rss.*) と連携してニュースフィードを提供
class NewsRssAggregatorPage extends StatefulWidget {
  const NewsRssAggregatorPage({super.key});

  @override
  State<NewsRssAggregatorPage> createState() => _NewsRssAggregatorPageState();
}

class _NewsRssAggregatorPageState extends State<NewsRssAggregatorPage> {
  final _supabase = Supabase.instance.client;
  final _urlCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isAdding = false;
  String? _errorMessage;
  List<dynamic> _feeds = [];

  @override
  void initState() {
    super.initState();
    _fetchFeeds();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchFeeds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'rss.list_feeds'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['feeds'] is List) {
        setState(() => _feeds = data['feeds'] as List);
      } else {
        setState(() => _feeds = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'フィード取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFeed() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'rss.add_feed', 'url': url, 'title': url},
      );
      _urlCtrl.clear();
      await _fetchFeeds();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('追加失敗: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ニュース・RSS'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchFeeds,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      hintText: 'RSS フィード URL を追加...',
                      prefixIcon: Icon(Icons.rss_feed),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _addFeed(),
                  ),
                ),
                const SizedBox(width: 8),
                _isAdding
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _addFeed,
                        tooltip: '追加',
                      ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _feeds.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rss_feed,
                                size: 48, color: Color(0xFF9CA3AF)),
                            SizedBox(height: 8),
                            Text(
                              'RSSフィードがありません\n上のフォームからURLを追加してください',
                              style: TextStyle(color: Color(0xFF9CA3AF)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _feeds.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = _feeds[i] as Map<String, dynamic>;
                          final meta =
                              item['metadata'] as Map<String, dynamic>?;
                          final title = meta?['title']?.toString() ??
                              item['title']?.toString() ??
                              '(無題)';
                          final url = meta?['url']?.toString() ??
                              item['url']?.toString() ??
                              '';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withAlpha(30),
                              child: const Icon(
                                Icons.rss_feed,
                                color: Colors.orange,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: url.isNotEmpty
                                ? Text(
                                    url,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
