import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/landing_page.dart';
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
        throw Exception('The selected file could not be read.');
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
      _showMessage('Import preview failed: $error');
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
      _showMessage('Log in before importing notes.');
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
      _showMessage('Imported $importedCount notes.');
      setState(() {
        _preview = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('Import failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openLandingPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LandingPage(),
      ),
    );
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
    final preview = _preview;
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Import')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Switch from Notion or Evernote',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'This page is part of the growth roadmap. Preview parsing now runs on a Supabase Edge Function first, with a local fallback only when the function is unavailable.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _sourceCard(
                sourceType: 'notion',
                title: 'Notion (CSV)',
                subtitle:
                    'Preview exported CSV files and migrate titles, text, and tags.',
                icon: Icons.table_chart,
              ),
              _sourceCard(
                sourceType: 'evernote',
                title: 'Evernote (ENEX)',
                subtitle:
                    'Preview ENEX exports and convert them into plain-text notes.',
                icon: Icons.note_alt,
              ),
              _sourceCard(
                sourceType: 'markdown',
                title: 'Markdown',
                subtitle:
                    'Preview a Markdown file as a note before importing it.',
                icon: Icons.description,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading) const LinearProgressIndicator(),
          if (preview != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${preview.sourceLabel} preview',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Chip(
                          avatar: Icon(
                            preview.usedEdgeFunction
                                ? Icons.cloud_done
                                : Icons.computer,
                            size: 18,
                          ),
                          label: Text(preview.previewModeLabel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('File: ${preview.fileName}'),
                    const SizedBox(height: 4),
                    Text('Notes ready to import: ${preview.notes.length}'),
                    if (currentUser == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Preview is ready. Sign in or create an account from the landing page, then come back to import the full batch.',
                      ),
                    ],
                    if (preview.warnings.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...preview.warnings.map(
                        (warning) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '- $warning',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isImporting || preview.notes.isEmpty
                          ? null
                          : currentUser == null
                              ? _openLandingPage
                              : _importPreview,
                      icon: Icon(
                        currentUser == null ? Icons.login : Icons.download_done,
                      ),
                      label: Text(
                        _isImporting
                            ? 'Importing...'
                            : currentUser == null
                                ? 'Open sign-up to import'
                                : 'Import these notes',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...preview.notes.take(12).map(
                  (note) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (note.tags.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: note.tags
                                  .map((tag) => Chip(label: Text(tag)))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            if (preview.notes.length > 12)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${preview.notes.length - 12} more notes are ready in this batch.',
                ),
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
      width: 280,
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
