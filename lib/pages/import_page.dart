import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/import_service.dart';
import '../services/gamification_service.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _isLoading = false;
  late ImportService _importService;

  @override
  void initState() {
    super.initState();
    // initStateではProviderにアクセスできないため、didChangeDependenciesで初期化するか
    // ここでは遅延初期化の準備のみ行う
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 正しい依存性を注入
    final gamificationService =
        Provider.of<GamificationService>(context, listen: false);
    _importService = ImportService(gamificationService);
  }

  Future<void> _pickAndImport(String type) async {
    setState(() => _isLoading = true);
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        final File file = File(result.files.single.path!);

        if (type == 'notion') await _importService.parseNotionCsv(file);
        if (type == 'evernote') await _importService.parseEvernoteEnex(file);
        if (type == 'markdown') await _importService.parseMarkdown(file);

        // ダミーデータでのインポート実行呼び出し
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          await _importService.importNotes(
            userId: user.id,
            notes: [], // 解析結果を渡す想定
            categoryId: 'general',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('インポート完了')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('データインポート')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Notion (CSV)'),
                  onTap: () => _pickAndImport('notion'),
                ),
                ListTile(
                  leading: const Icon(Icons.note),
                  title: const Text('Evernote (ENEX)'),
                  onTap: () => _pickAndImport('evernote'),
                ),
                ListTile(
                  leading: const Icon(Icons.text_snippet),
                  title: const Text('Markdown'),
                  onTap: () => _pickAndImport('markdown'),
                ),
              ],
            ),
    );
  }
}
