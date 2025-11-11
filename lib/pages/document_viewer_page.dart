import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kDebugMode用
import '../models/document.dart';
import '../services/document_service.dart';
import '../widgets/markdown_preview.dart';

class DocumentViewerPage extends StatefulWidget {
  final DocumentItem document;

  const DocumentViewerPage({
    super.key,
    required this.document,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  String? _content;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (kDebugMode) {
        print('📄 [DocumentViewerPage] Starting document load');
        print('📄 [DocumentViewerPage] Document ID: ${widget.document.id}');
        print('📄 [DocumentViewerPage] Document title: ${widget.document.title}');
        print('📄 [DocumentViewerPage] Document path: ${widget.document.path}');
        print('📄 [DocumentViewerPage] Document category: ${widget.document.category}');
      }

      final content = await DocumentService.loadDocument(widget.document.path);

      if (kDebugMode) {
        print('✅ [DocumentViewerPage] Document content loaded successfully');
      }
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ [DocumentViewerPage] Failed to load document');
        print('❌ [DocumentViewerPage] Error: $e');
        print('❌ [DocumentViewerPage] Error type: ${e.runtimeType}');
        print('❌ [DocumentViewerPage] Stack trace: $stackTrace');
      }

      setState(() {
        _error = 'ドキュメントの読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.document.title),
        elevation: 0,
        actions: [
          // カテゴリバッジ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.document.categoryIcon,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.document.categoryDisplayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadDocument,
                        icon: const Icon(Icons.refresh),
                        label: const Text('再読み込み'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 900),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ドキュメントヘッダー
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.document.categoryIcon,
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.document.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          widget.document.categoryDisplayName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Divider(color: Colors.grey[300]),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.insert_drive_file,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.document.path,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ドキュメント内容
                        if (_content != null)
                          MarkdownPreview(
                            data: _content!,
                            selectable: true,
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
