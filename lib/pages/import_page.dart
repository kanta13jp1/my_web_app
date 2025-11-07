import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/import_service.dart';
import '../models/category.dart';
import '../utils/app_logger.dart';
import 'dart:convert';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _supabase = Supabase.instance.client;
  late final ImportService _importService;

  List<Category> _categories = [];
  String? _selectedCategoryId;
  bool _isLoading = false;
  bool _isImporting = false;

  String? _fileName;
  List<Map<String, dynamic>>? _parsedNotes;

  @override
  void initState() {
    super.initState();
    _importService = ImportService(_supabase);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('categories')
          .select()
          .eq('user_id', _supabase.auth.currentUser!.id)
          .order('name', ascending: true);

      setState(() {
        _categories = (response as List)
            .map((category) => Category.fromJson(category))
            .toList();
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      AppLogger.error('Error loading categories', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile(String type) async {
    try {
      FilePickerResult? result;

      switch (type) {
        case 'notion':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );
          break;
        case 'evernote':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['enex', 'xml'],
          );
          break;
        case 'markdown':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['md', 'txt'],
          );
          break;
      }

      if (result != null && result.files.single.bytes != null) {
        final fileName = result.files.single.name;
        final bytes = result.files.single.bytes!;
        final content = utf8.decode(bytes);

        setState(() {
          _fileName = fileName;
          _parsedNotes = null;
        });

        await _parseFile(type, content);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error picking file', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイル選択エラー: $e')),
        );
      }
    }
  }

  Future<void> _parseFile(String type, String content) async {
    try {
      setState(() => _isLoading = true);

      List<Map<String, dynamic>> notes;

      switch (type) {
        case 'notion':
          notes = await _importService.parseNotionCsv(content);
          break;
        case 'evernote':
          notes = await _importService.parseEvernoteEnex(content);
          break;
        case 'markdown':
          notes = await _importService.parseMarkdown(content);
          break;
        default:
          throw Exception('Unknown import type: $type');
      }

      setState(() {
        _parsedNotes = notes;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${notes.length}件のメモを検出しました')),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing file', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイル解析エラー: $e')),
        );
      }
    }
  }

  Future<void> _importNotes() async {
    if (_parsedNotes == null || _parsedNotes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('インポートするメモがありません')),
      );
      return;
    }

    try {
      setState(() => _isImporting = true);

      final userId = _supabase.auth.currentUser!.id;
      final importedCount = await _importService.importNotes(
        userId: userId,
        notes: _parsedNotes!,
        categoryId: _selectedCategoryId,
      );

      setState(() {
        _isImporting = false;
        _parsedNotes = null;
        _fileName = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$importedCount件のメモをインポートしました！'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // ホーム画面に戻る
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error importing notes', error: e, stackTrace: stackTrace);
      setState(() => _isImporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモのインポート'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 説明
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                'Notion/Evernoteから簡単移行',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '既存のメモアプリからマイメモへ移行できます。インポート数に応じてボーナスポイントを獲得！',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // インポート元の選択
                  Text(
                    'インポート元を選択',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Notion
                  _buildImportCard(
                    title: 'Notion',
                    description: 'CSVファイル形式でエクスポートしたデータをインポート',
                    icon: Icons.language,
                    color: Colors.black,
                    onTap: () => _pickFile('notion'),
                  ),
                  const SizedBox(height: 12),

                  // Evernote
                  _buildImportCard(
                    title: 'Evernote',
                    description: 'ENEX形式でエクスポートしたデータをインポート',
                    icon: Icons.note,
                    color: Colors.green,
                    onTap: () => _pickFile('evernote'),
                  ),
                  const SizedBox(height: 12),

                  // Markdown
                  _buildImportCard(
                    title: 'Markdown',
                    description: 'Markdownファイル（.md）をインポート',
                    icon: Icons.description,
                    color: Colors.blue,
                    onTap: () => _pickFile('markdown'),
                  ),
                  const SizedBox(height: 24),

                  // プレビュー
                  if (_fileName != null) ...[
                    Text(
                      'プレビュー',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.file_present, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _fileName!,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (_parsedNotes != null) ...[
                              const SizedBox(height: 12),
                              Text('検出されたメモ: ${_parsedNotes!.length}件'),
                              const SizedBox(height: 16),

                              // カテゴリ選択
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'インポート先カテゴリ（任意）',
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedCategoryId,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('カテゴリなし'),
                                  ),
                                  ..._categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category.id,
                                      child: Text(category.name),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCategoryId = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),

                              // インポートボタン
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isImporting ? null : _importNotes,
                                  icon: _isImporting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.upload),
                                  label: Text(
                                    _isImporting
                                        ? 'インポート中...'
                                        : 'インポート開始',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildImportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
