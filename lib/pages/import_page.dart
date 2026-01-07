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
      AppLogger.error(
        'Error loading categories',
        error: e,
        stackTrace: stackTrace,
      );
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
          SnackBar(content: Text('資産ファイル選択エラー: $e')),
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
          SnackBar(content: Text('${notes.length}件の知的財産を検出しました')),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error parsing file', error: e, stackTrace: stackTrace);
      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('デューデリジェンス（解析）エラー: $e')),
        );
      }
    }
  }

  Future<void> _importNotes() async {
    if (_parsedNotes == null || _parsedNotes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('統合する資産がありません')),
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
            content: Text('M&A完了: $importedCount件の資産を統合しました。'),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 3),
          ),
        );

        // ホーム画面に戻る
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Error importing notes',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() => _isImporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('統合プロセスエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M&A (データ統合)'),
        backgroundColor: const Color(0xFF0F172A), // Navy
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 説明
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                      ), // Gold hint
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.domain_add, color: Color(0xFF0F172A)),
                              SizedBox(width: 8),
                              Text(
                                '外部事業の買収統合',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '他社（Notion/Evernote等）に眠る知的財産を「自分株式会社」へ統合します。買収規模（インポート数）に応じて、特別配当（Pt）が付与されます。',
                            style:
                                TextStyle(color: Colors.grey[700], height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // インポート元の選択
                  Text(
                    '買収対象企業の選定',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notion
                  _buildImportCard(
                    title: 'Notion',
                    description: 'CSV形式の経営資源を取り込む',
                    icon: Icons.language, // Notionぽいアイコンがないため代替
                    color: Colors.black,
                    onTap: () => _pickFile('notion'),
                  ),
                  const SizedBox(height: 12),

                  // Evernote
                  _buildImportCard(
                    title: 'Evernote',
                    description: 'ENEX形式のアーカイブを吸収',
                    icon: Icons.inventory_2, // 象の代わりにアーカイブっぽいもの
                    color: Colors.green,
                    onTap: () => _pickFile('evernote'),
                  ),
                  const SizedBox(height: 12),

                  // Markdown
                  _buildImportCard(
                    title: 'Markdown / Text',
                    description: '標準規格のドキュメントを統合',
                    icon: Icons.description,
                    color: Colors.blueGrey,
                    onTap: () => _pickFile('markdown'),
                  ),
                  const SizedBox(height: 24),

                  // プレビュー
                  if (_fileName != null) ...[
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'デューデリジェンス (資産査定)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.grey[100],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.folder_open,
                                  color: Color(0xFF0F172A),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _fileName!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_parsedNotes != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                '検出された資産: ${_parsedNotes!.length} 件',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // カテゴリ選択
                              DropdownButtonFormField<String?>(
                                decoration: const InputDecoration(
                                  labelText: '統合先事業部（カテゴリ選択）',
                                  border: OutlineInputBorder(),
                                ),
                                initialValue: _selectedCategoryId,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('事業部指定なし (未分類)'),
                                  ),
                                  ..._categories.map((category) {
                                    return DropdownMenuItem<String>(
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
                              const SizedBox(height: 24),

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
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.merge_type),
                                  label: Text(
                                    _isImporting
                                        ? '統合プロセス実行中...'
                                        : '買収を執行する (インポート)',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF0F172A), // Navy
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.all(16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  color: color.withValues(alpha: 0.1),
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
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
