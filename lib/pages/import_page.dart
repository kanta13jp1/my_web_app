import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/gamification_service.dart';
import '../services/import_service.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _isLoading = false;
  bool _isImporting = false;
  late ImportService _importService;
  ImportPreviewResult? _preview;
  String? _selectedSource;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gamificationService = Provider.of<GamificationService>(
      context,
      listen: false,
    );
    _importService = ImportService(gamificationService);
  }

  Future<void> _pickFile(String sourceType) async {
    setState(() {
      _isLoading = true;
      _selectedSource = sourceType;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: _extensionsFor(sourceType),
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('ファイルの読み込みに失敗しました。');
      }

      final preview = await _importService.buildPreview(
        sourceType: sourceType,
        fileName: file.name,
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポート解析に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _importPreview() async {
    final preview = _preview;
    final user = Supabase.instance.client.auth.currentUser;
    if (preview == null) {
      return;
    }
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('インポートにはログインが必要です。')),
      );
      return;
    }

    setState(() => _isImporting = true);
    try {
      final importedCount = await _importService.importNotes(
        userId: user.id,
        notes: preview.notes,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$importedCount 件のメモを取り込みました。')),
      );
      setState(() {
        _preview = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートに失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  List<String> _extensionsFor(String sourceType) {
    switch (sourceType) {
      case 'notion':
        return const <String>['csv'];
      case 'evernote':
        return const <String>['enex', 'xml'];
      case 'markdown':
        return const <String>['md', 'markdown', 'txt'];
      default:
        return const <String>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メモのインポート')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Notion / Evernote import',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Notion の CSV と Evernote の ENEX を読み込み、取り込み前に preview できます。MVP では title / content / tags を優先して移行します。',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _sourceCard(
                sourceType: 'notion',
                title: 'Notion (CSV)',
                subtitle: 'Notion export の CSV を preview して取り込みます',
                icon: Icons.table_chart,
              ),
              _sourceCard(
                sourceType: 'evernote',
                title: 'Evernote (ENEX)',
                subtitle: 'Evernote export の ENEX を note 単位で取り込みます',
                icon: Icons.note_alt,
              ),
              _sourceCard(
                sourceType: 'markdown',
                title: 'Markdown',
                subtitle: '1 ファイル単位の Markdown を note に変換します',
                icon: Icons.description,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading) const LinearProgressIndicator(),
          if (_preview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_preview!.sourceLabel} プレビュー',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ファイル: ${_preview!.fileName}'),
                    const SizedBox(height: 4),
                    Text('取り込み対象: ${_preview!.notes.length} 件'),
                    if (_preview!.warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ..._preview!.warnings.map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '・ $warning',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isImporting || _preview!.notes.isEmpty
                          ? null
                          : _importPreview,
                      icon: const Icon(Icons.download_done),
                      label: Text(
                        _isImporting ? '取り込み中...' : 'この preview をインポート',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ..._preview!.notes.take(12).map(
                  (note) => Card(
                    child: ListTile(
                      title: Text(note.title),
                      subtitle: Text(
                        note.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: note.tags.isEmpty
                          ? null
                          : SizedBox(
                              width: 140,
                              child: Text(
                                note.tags.join(', '),
                                textAlign: TextAlign.right,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ),
                ),
            if (_preview!.notes.length > 12)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('ほか ${_preview!.notes.length - 12} 件あります。'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _sourceCard({
    required String sourceType,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedSource == sourceType;

    return SizedBox(
      width: 260,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : () => _pickFile(sourceType),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
