import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_memo.dart';
import '../services/public_memo_service.dart';

class PublicMemoDirectoryPage extends StatefulWidget {
  final PublicMemoService? publicMemoService;

  const PublicMemoDirectoryPage({
    super.key,
    this.publicMemoService,
  });

  @override
  State<PublicMemoDirectoryPage> createState() =>
      _PublicMemoDirectoryPageState();
}

class _PublicMemoDirectoryPageState extends State<PublicMemoDirectoryPage> {
  late final PublicMemoService _publicMemoService;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _selectedCategory;
  List<PublicMemo> _memos = const <PublicMemo>[];
  List<Map<String, dynamic>> _popularCategories =
      const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _publicMemoService =
        widget.publicMemoService ?? PublicMemoService(Supabase.instance.client);
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _publicMemoService.getPublicMemos(
          limit: 30,
          category: _selectedCategory,
          searchQuery: _searchController.text,
        ),
        _publicMemoService.getPopularCategories(limit: 12),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _memos = results[0] as List<PublicMemo>;
        _popularCategories = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy/MM/dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('公開メモ'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '公開メモから流入を増やす',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'アプリ内で公開したメモを一覧で見られるページです。検索とカテゴリ絞り込みで、外部流入や内部回遊の入口として使えます。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'タイトル / 本文 / カテゴリで検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _reload(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('すべて'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                    _reload();
                  },
                ),
                ..._popularCategories.map((item) {
                  final category = item['category']?.toString() ?? '';
                  return ChoiceChip(
                    label: Text('$category (${item['count']})'),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() => _selectedCategory = category);
                      _reload();
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_memos.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    '公開メモはまだありません。まずはメモ一覧から 1 件公開してみてください。',
                  ),
                ),
              )
            else
              ..._memos.map(
                (memo) => Card(
                  child: ListTile(
                    title: Text(memo.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text(
                          memo.content ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${formatter.format(memo.publishedAt.toLocal())} ・ ${memo.category ?? 'カテゴリなし'} ・ ${memo.viewCount} views ・ ${memo.likeCount} likes',
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/public-memo?id=${memo.id}'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
