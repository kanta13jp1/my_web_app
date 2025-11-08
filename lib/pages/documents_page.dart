import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import 'document_viewer_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String? _selectedCategory;
  final Map<String, List<DocumentItem>> _documentsByCategory =
      DocumentService.getDocumentsByCategory();

  List<String> get _categories => [
    'root',
    'roadmaps',
    'user-docs',
    'session-summaries',
    'technical',
    'release-notes',
  ];

  List<DocumentItem> get _displayedDocuments {
    if (_selectedCategory == null) {
      return DocumentService.getAllDocuments();
    }
    return _documentsByCategory[_selectedCategory] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ドキュメント'),
        elevation: 0,
      ),
      body: Row(
        children: [
          // サイドバー（カテゴリフィルター）
          Container(
            width: 250,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'カテゴリ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                ListTile(
                  leading: const Text('📁', style: TextStyle(fontSize: 20)),
                  title: const Text('すべて'),
                  selected: _selectedCategory == null,
                  onTap: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                ),
                const Divider(),
                ..._categories.map((category) {
                  final count = _documentsByCategory[category]?.length ?? 0;
                  if (count == 0 && category != 'root') return const SizedBox.shrink();

                  return ListTile(
                    leading: Text(
                      DocumentService.getCategoryIcon(category),
                      style: const TextStyle(fontSize: 20),
                    ),
                    title: Text(DocumentService.getCategoryDisplayName(category)),
                    trailing: count > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    selected: _selectedCategory == category,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                }),
              ],
            ),
          ),
          // メインコンテンツエリア
          Expanded(
            child: _displayedDocuments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ドキュメントがありません',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _displayedDocuments.length,
                    itemBuilder: (context, index) {
                      final doc = _displayedDocuments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.1),
                            child: Text(
                              doc.categoryIcon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            doc.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              doc.categoryDisplayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DocumentViewerPage(
                                  document: doc,
                                ),
                              ),
                            );
                          },
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
