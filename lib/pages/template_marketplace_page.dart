import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/note_template.dart';
import '../services/gamification_service.dart';
import 'note_editor_page.dart';
import '../utils/app_logger.dart';

class TemplateMarketplacePage extends StatefulWidget {
  const TemplateMarketplacePage({super.key});

  @override
  State<TemplateMarketplacePage> createState() =>
      _TemplateMarketplacePageState();
}

class _TemplateMarketplacePageState extends State<TemplateMarketplacePage> {
  final _supabase = Supabase.instance.client;
  late final GamificationService _gamificationService;

  List<NoteTemplate> _templates = [];
  List<NoteTemplate> _filteredTemplates = [];
  String _selectedCategory = '全て';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    '全て',
    '仕事',
    '学習',
    '個人',
    'アイデア',
    '健康',
    '旅行',
  ];

  @override
  void initState() {
    super.initState();
    _gamificationService = GamificationService(_supabase);
    _loadTemplates();
    _searchController.addListener(_filterTemplates);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadTemplates() {
    setState(() {
      _templates = NoteTemplate.getDefaultTemplates();
      _filteredTemplates = _templates;
    });
  }

  void _filterTemplates() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredTemplates = _templates.where((template) {
        final matchesCategory = _selectedCategory == '全て' ||
            template.category == _selectedCategory;
        final matchesSearch = query.isEmpty ||
            template.title.toLowerCase().contains(query) ||
            template.description.toLowerCase().contains(query) ||
            template.tags.any((tag) => tag.toLowerCase().contains(query));

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _useTemplate(NoteTemplate template) async {
    try {
      // テンプレート使用ボーナス
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _gamificationService.awardPoints(
          userId,
          5,
          reason: 'テンプレート使用',
        );
      }

      if (mounted) {
        // テンプレートを使用してノート作成画面へ
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteEditorPage(
              initialTitle: template.title,
              initialContent: template.content,
            ),
          ),
        );

        // ホームに戻る
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error using template', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  void _showTemplatePreview(NoteTemplate template) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: Row(
                  children: [
                    if (template.iconEmoji != null) ...[
                      Text(
                        template.iconEmoji!,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            template.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // プレビュー
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // タグ
                      Wrap(
                        spacing: 8,
                        children: template.tags
                            .map((tag) => Chip(
                                  label: Text(tag),
                                  labelStyle: const TextStyle(fontSize: 12),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      // コンテンツプレビュー
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          template.content,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // アクションボタン
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _useTemplate(template);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('使用する'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('テンプレートマーケット'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'テンプレートを検索...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // カテゴリフィルター
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                        _filterTemplates();
                      });
                    },
                  ),
                );
              },
            ),
          ),

          // テンプレート一覧
          Expanded(
            child: _filteredTemplates.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'テンプレートが見つかりません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          MediaQuery.of(context).size.width > 600 ? 3 : 2,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _filteredTemplates.length,
                    itemBuilder: (context, index) {
                      final template = _filteredTemplates[index];
                      return _buildTemplateCard(template);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(NoteTemplate template) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _showTemplatePreview(template),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // アイコン
            Container(
              height: 80,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade100,
                    Colors.purple.shade100,
                  ],
                ),
              ),
              child: Center(
                child: Text(
                  template.iconEmoji ?? '📝',
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),

            // 情報
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // 説明
                    Text(
                      template.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // カテゴリバッジ
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        template.category,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
