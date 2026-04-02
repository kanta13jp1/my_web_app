import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ニュース・RSSアグリゲーターページ
/// news-rss-aggregator Edge Function と連携してニュースフィードを提供
class NewsRssAggregatorPage extends StatefulWidget {
  const NewsRssAggregatorPage({super.key});

  @override
  State<NewsRssAggregatorPage> createState() => _NewsRssAggregatorPageState();
}

class _NewsRssAggregatorPageState extends State<NewsRssAggregatorPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _articles = [];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'news-rss-aggregator',
        body: {'action': 'list', 'limit': 30},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['articles'] is List) {
        setState(() => _articles = data['articles'] as List);
      } else if (data is Map<String, dynamic> && data['items'] is List) {
        setState(() => _articles = data['items'] as List);
      } else if (data is List) {
        setState(() => _articles = data);
      } else {
        setState(() => _articles = []);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'ニュース取得に失敗しました: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
            onPressed: _isLoading ? null : _fetchNews,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchNews,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _articles.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.newspaper, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            '記事がありません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _articles.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final item = _articles[i] as Map<String, dynamic>;
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
                            item['title']?.toString() ?? '(無題)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            item['source']?.toString() ??
                                item['feed']?.toString() ??
                                item['published_at']?.toString() ??
                                '',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
    );
  }
}
