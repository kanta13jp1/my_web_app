import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/landing_page.dart';
import '../services/external_format_service.dart';
import '../services/evernote_cloud_stage_service.dart';
import '../services/evernote_migration_ledger_service.dart';
import '../services/evernote_migration_commit_service.dart';
import '../services/evernote_note_history_migration_service.dart';
import '../services/gamification_service.dart';
import '../services/growth_acquisition_service.dart';
import '../services/import_service.dart';
import '../widgets/evernote_cloud_migration_controls.dart';
import '../widgets/evernote_history_review_panel.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _isLoading = false;
  bool _isImporting = false;
  final GrowthAcquisitionService _acquisitionService =
      const GrowthAcquisitionService();
  late ImportService _importService;
  late EvernoteMigrationLedgerService _evernoteMigrationLedgerService;
  late EvernoteMigrationCommitService _evernoteMigrationCommitService;
  late EvernoteNoteHistoryMigrationService _evernoteNoteHistoryMigrationService;
  late EvernoteCloudStageService _evernoteCloudStageService;
  bool _migrationLedgerInitialized = false;
  bool _isMigrationLedgerLoading = false;
  String? _migrationLedgerError;
  List<EvernoteMigrationBatch> _evernoteMigrationBatches =
      const <EvernoteMigrationBatch>[];
  List<EvernoteMigrationItem> _evernoteMigrationItems =
      const <EvernoteMigrationItem>[];
  int? _evernoteHistoryBusyItemId;
  EvernoteCloudStageProgress? _evernoteHistoryStageProgress;
  ImportPreviewResult? _preview;
  EvernoteCloudStageResult? _evernoteCloudStageResult;
  EvernoteCloudStageProgress? _evernoteCloudStageProgress;
  EvernoteMigrationTransferProgress? _evernoteTransferProgress;
  ImportExecutionResult? _lastImportResult;
  String? _selectedSource;
  final TextEditingController _notionTokenController = TextEditingController();
  final TextEditingController _evernoteNotebookNameController =
      TextEditingController();
  final TextEditingController _evernoteStackNameController =
      TextEditingController();
  final TextEditingController _evernoteSpaceNameController =
      TextEditingController();
  final TextEditingController _externalFormatInputController =
      TextEditingController(
    text: ExternalFormatService.sampleText('ssim'),
  );
  final ExternalFormatService _externalFormatService =
      const ExternalFormatService();
  ExternalFormatProfile _externalFormatProfile =
      ExternalFormatService.defaultProfile('ssim');
  ExternalFormatTransformResult? _externalFormatPreview;
  String _externalFormatId = 'ssim';
  String? _externalFormatExport;
  bool _isSavingExternalMapping = false;

  @override
  void dispose() {
    _notionTokenController.dispose();
    _evernoteNotebookNameController.dispose();
    _evernoteStackNameController.dispose();
    _evernoteSpaceNameController.dispose();
    _externalFormatInputController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gamificationService = Provider.of<GamificationService>(
      context,
      listen: false,
    );
    _importService = ImportService(gamificationService);
    _evernoteCloudStageService = EvernoteCloudStageService.supabase(
      client: Supabase.instance.client,
      importService: _importService,
    );
    _evernoteMigrationCommitService =
        EvernoteMigrationCommitService.supabase(Supabase.instance.client);
    _evernoteNoteHistoryMigrationService =
        EvernoteNoteHistoryMigrationService.supabase(
      Supabase.instance.client,
    );
    if (!_migrationLedgerInitialized) {
      _migrationLedgerInitialized = true;
      _evernoteMigrationLedgerService = EvernoteMigrationLedgerService();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_loadEvernoteMigrationLedger());
      });
    }
  }

  Future<void> _loadEvernoteMigrationLedger() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (mounted) {
      setState(() {
        _isMigrationLedgerLoading = true;
        _migrationLedgerError = null;
      });
    }
    try {
      final batchesFuture = _evernoteMigrationLedgerService.loadBatches(
        userId: user.id,
      );
      final itemsFuture = _evernoteMigrationLedgerService.loadItems(
        userId: user.id,
      );
      final batches = await batchesFuture;
      final items = await itemsFuture;
      if (!mounted) return;
      setState(() {
        _evernoteMigrationBatches = batches;
        _evernoteMigrationItems = items;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _migrationLedgerError = error.toString());
    } finally {
      if (mounted) setState(() => _isMigrationLedgerLoading = false);
    }
  }

  Future<void> _recordEvernotePreview(ImportPreviewResult preview) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || preview.sourceType != 'evernote') return;
    try {
      await _evernoteMigrationLedgerService.recordPreview(
        userId: user.id,
        preview: preview,
      );
      await _loadEvernoteMigrationLedger();
    } catch (error) {
      if (!mounted) return;
      setState(() => _migrationLedgerError = error.toString());
      _showMessage(
        'ENEX preview is safe, but the migration ledger could not be saved: '
        '$error',
      );
    }
  }

  Future<void> _reviewEvernoteHistoryInventory(
    EvernoteMigrationItem item,
    int sourceVersionCount,
  ) async {
    setState(() {
      _evernoteHistoryBusyItemId = item.id;
      _migrationLedgerError = null;
    });
    try {
      await _evernoteNoteHistoryMigrationService.reviewInventory(
        batchId: item.batchId,
        sourceItemKey: item.sourceItemKey,
        sourceVersionCount: sourceVersionCount,
      );
      await _loadEvernoteMigrationLedger();
      if (!mounted) return;
      _showMessage(
        sourceVersionCount == 0
            ? 'このノートはEvernote履歴なしとして確認しました。'
            : 'Evernote履歴 $sourceVersionCount 件を移行対象として登録しました。',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _migrationLedgerError = error.toString());
      _showMessage('履歴件数の登録に失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() => _evernoteHistoryBusyItemId = null);
      }
    }
  }

  Future<void> _pickEvernoteHistoryRevision(
    EvernoteMigrationItem item,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _showMessage('履歴を取り込む前にログインしてください。');
      return;
    }
    if (item.sourceHistoryVersionCount <= 0) {
      _showMessage('先にEvernote上の履歴件数を確認してください。');
      return;
    }

    setState(() {
      _evernoteHistoryBusyItemId = item.id;
      _evernoteHistoryStageProgress = null;
      _migrationLedgerError = null;
    });
    try {
      final selection = await FilePicker.pickFiles(
        withData: false,
        withReadStream: true,
        type: FileType.custom,
        allowedExtensions: const <String>['enex', 'xml'],
      );
      if (selection == null || selection.files.isEmpty) return;
      final file = selection.files.single;
      final source = file.readStream;
      if (source == null) {
        throw StateError('選択した履歴ENEXのストリームを開けませんでした。');
      }

      final staged = await _evernoteCloudStageService.stage(
        userId: user.id,
        fileName: file.name,
        source: source,
        totalBytes: file.size,
        historyRevision: true,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _evernoteHistoryStageProgress = progress);
        },
      );
      final archiveHash = staged.preview.sourceExportSha256;
      if (archiveHash == null) {
        throw StateError('履歴ENEXのSHA-256を確認できませんでした。');
      }
      await _evernoteNoteHistoryMigrationService.migrateFromArchive(
        userId: user.id,
        batchId: item.batchId,
        sourceItemKey: item.sourceItemKey,
        archiveBytes: staged.totalBytes,
        archiveSha256: archiveHash,
      );
      await _loadEvernoteMigrationLedger();
      if (!mounted) return;
      _showMessage(
        '履歴ENEXをクラウド保管し、本文・日時・添付のハッシュを検証しました。',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _migrationLedgerError = error.toString());
      _showMessage(
        '履歴の取り込みに失敗しました。クラウド上の復旧用ENEXは保持されます: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _evernoteHistoryBusyItemId = null);
      }
    }
  }

  Future<void> _pickFile(String sourceType) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (sourceType == 'evernote' && currentUser == null) {
      _showMessage('Log in before selecting an ENEX batch for cloud staging.');
      return;
    }
    setState(() {
      _isLoading = true;
      _selectedSource = sourceType;
      _preview = null;
      _evernoteCloudStageResult = null;
      _evernoteCloudStageProgress = null;
      _evernoteTransferProgress = null;
    });

    try {
      final isEvernote = sourceType == 'evernote';
      final result = await FilePicker.pickFiles(
        withData: !isEvernote,
        withReadStream: isEvernote,
        type: FileType.custom,
        allowedExtensions: _extensionsFor(sourceType),
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      if (isEvernote) {
        final readStream = file.readStream;
        if (readStream == null) {
          throw StateError('The selected ENEX stream could not be opened.');
        }
        final staged = await _evernoteCloudStageService.stage(
          userId: currentUser!.id,
          fileName: file.name,
          source: readStream,
          totalBytes: file.size,
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _evernoteCloudStageProgress = progress);
          },
        );
        if (!mounted) return;
        _setEvernoteSourceContextDefaults(file.name);
        setState(() {
          _preview = staged.preview;
          _evernoteCloudStageResult = staged;
        });
        await _recordEvernotePreview(staged.preview);
        unawaited(_acquisitionService.recordImportPreview(sourceType));
        return;
      }

      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('The selected file could not be read.');
      }
      final preview = await _importService.buildPreview(
        sourceType: sourceType,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
      });
      await _recordEvernotePreview(preview);
      unawaited(_acquisitionService.recordImportPreview(sourceType));
    } catch (error) {
      if (!mounted) return;
      _showMessage('Import preview failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNotionApi() async {
    _notionTokenController.clear();
    int dialogPageLimit = 10;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) => AlertDialog(
          title: const Text('Notion API 連携'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notion インテグレーションのトークンを入力してください。\n'
                'Notion → Settings → Integrations から発行できます。ページ本文、ネストしたブロック、データベース項目を直接プレビューします。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notionTokenController,
                decoration: const InputDecoration(
                  labelText: 'Integration Token (secret_xxx)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('取得件数:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: dialogPageLimit,
                    items: const [
                      DropdownMenuItem(value: 5, child: Text('5件')),
                      DropdownMenuItem(value: 10, child: Text('10件')),
                      DropdownMenuItem(value: 20, child: Text('20件')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => dialogPageLimit = v);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('取得'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final token = _notionTokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _isLoading = true;
      _selectedSource = 'notion_api';
    });
    try {
      final preview = await _importService.buildNotionApiPreview(
        notionToken: token,
        pageLimit: dialogPageLimit,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
      });
      unawaited(_acquisitionService.recordImportPreview('notion_api'));
    } catch (error) {
      if (!mounted) return;
      _showMessage('Notion API preview failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importPreview() async {
    final preview = _preview;
    final user = Supabase.instance.client.auth.currentUser;
    if (preview == null) return;
    if (user == null) {
      _showMessage('Log in before importing notes.');
      return;
    }

    setState(() {
      _isImporting = true;
      _evernoteTransferProgress = null;
    });
    try {
      final ImportExecutionResult result;
      if (preview.sourceType == 'evernote') {
        final staged = _evernoteCloudStageResult;
        if (staged == null) {
          throw StateError('Select the ENEX batch again for cloud staging.');
        }
        final evernoteResult =
            await _evernoteMigrationCommitService.commitFromArchive(
          userId: user.id,
          archiveBytes: staged.totalBytes,
          preview: preview,
          sourceContext: EvernoteMigrationSourceContext(
            notebookName: _evernoteNotebookNameController.text,
            stackName: _evernoteStackNameController.text,
            spaceName: _evernoteSpaceNameController.text,
          ),
          onTransferProgress: (progress) {
            if (!mounted) return;
            setState(() => _evernoteTransferProgress = progress);
          },
        );
        result = ImportExecutionResult(
          insertedCount: evernoteResult.importedNoteCount,
          importMode: 'evernote-lossless',
        );
        await _loadEvernoteMigrationLedger();
      } else {
        result = await _importService.importNotes(
          userId: user.id,
          notes: preview.notes,
        );
      }
      if (!mounted) return;
      _showMessage(
        'Imported ${result.insertedCount} notes via '
        '${result.importModeLabel.toLowerCase()}.',
      );
      setState(() {
        _preview = null;
        _evernoteCloudStageResult = null;
        _evernoteCloudStageProgress = null;
        _evernoteTransferProgress = null;
        _lastImportResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      if (preview.sourceType == 'evernote') {
        _showMessage(
          'Import failed, but the verified private cloud archive was kept. '
          'You can retry without selecting the ENEX again: $error',
        );
        unawaited(_loadEvernoteMigrationLedger());
      } else {
        _showMessage('Import failed: $error');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _setEvernoteSourceContextDefaults(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final leaf = normalized.split('/').last.trim();
    final dotIndex = leaf.lastIndexOf('.');
    final inferredNotebook =
        (dotIndex > 0 ? leaf.substring(0, dotIndex) : leaf).trim();
    _evernoteNotebookNameController.text =
        inferredNotebook.isEmpty ? 'Evernote import' : inferredNotebook;
    _evernoteStackNameController.clear();
    _evernoteSpaceNameController.clear();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openLandingPage() async {
    await _acquisitionService.recordImportSignUpCta();
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/'),
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
      case 'xlsx':
        return const <String>['xlsx'];
      case 'docx':
        return const <String>['docx'];
      default:
        return const <String>[];
    }
  }

  void _selectExternalFormat(String? formatId) {
    final nextFormatId = formatId ?? 'ssim';
    setState(() {
      _externalFormatId = nextFormatId;
      _externalFormatProfile =
          ExternalFormatService.defaultProfile(nextFormatId);
      _externalFormatInputController.text =
          ExternalFormatService.sampleText(nextFormatId);
      _externalFormatPreview = null;
      _externalFormatExport = null;
    });
  }

  void _updateExternalMapping(
    int index,
    ExternalFieldMapping Function(ExternalFieldMapping mapping) update,
  ) {
    final mappings = List<ExternalFieldMapping>.from(
      _externalFormatProfile.mappings,
    );
    mappings[index] = update(mappings[index]);
    setState(() {
      _externalFormatProfile = _externalFormatProfile.copyWith(
        mappings: mappings,
      );
      _externalFormatPreview = null;
      _externalFormatExport = null;
    });
  }

  void _previewExternalFormat() {
    final result = _externalFormatService.transform(
      inputText: _externalFormatInputController.text,
      profile: _externalFormatProfile,
    );
    setState(() {
      _externalFormatPreview = result;
      _externalFormatExport = _externalFormatService.exportDelimited(
        result,
        _externalFormatProfile.delimiter,
      );
    });
  }

  Future<void> _copyExternalExport() async {
    final exportText = _externalFormatExport;
    if (exportText == null || exportText.trim().isEmpty) {
      _previewExternalFormat();
    }
    final text = _externalFormatExport;
    if (text == null || text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _showMessage('出力CSVをコピーしました。');
  }

  Future<void> _saveExternalMappingProfile() async {
    setState(() => _isSavingExternalMapping = true);
    try {
      await _externalFormatService.saveProfile(_externalFormatProfile);
      if (!mounted) return;
      _showMessage('外部連携マッピングを保存しました。');
    } catch (error) {
      if (!mounted) return;
      _showMessage('マッピング保存に失敗しました: $error');
    } finally {
      if (mounted) setState(() => _isSavingExternalMapping = false);
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
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This page is part of the growth roadmap. Preview parsing now runs on a Supabase Edge Function first, with a local fallback only when the function is unavailable.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Full note import now also runs on a Supabase Edge Function first, so larger competitor migrations do not depend entirely on browser-side batching.',
          ),
          const SizedBox(height: 20),
          _buildEvernoteMigrationProgressPanel(currentUser),
          const SizedBox(height: 20),
          EvernoteHistoryReviewPanel(
            items: _evernoteMigrationItems,
            isLoading: _isMigrationLedgerLoading,
            busyItemId: _evernoteHistoryBusyItemId,
            error: _migrationLedgerError,
            stageProgress: _evernoteHistoryStageProgress,
            onRefresh: _loadEvernoteMigrationLedger,
            onReviewInventory: _reviewEvernoteHistoryInventory,
            onImportRevision: _pickEvernoteHistoryRevision,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _notionApiCard(),
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
                    'Archive ENEX, import notes and attachments, then verify hashes before source deletion.',
                icon: Icons.note_alt,
              ),
              _sourceCard(
                sourceType: 'markdown',
                title: 'Markdown',
                subtitle:
                    'Preview a Markdown file as a note before importing it.',
                icon: Icons.description,
              ),
              _sourceCard(
                sourceType: 'xlsx',
                title: 'Excel (XLSX)',
                subtitle: 'Notionの表エクスポート等を行ごと・列見出し対応でノート化。',
                icon: Icons.grid_on,
              ),
              _sourceCard(
                sourceType: 'docx',
                title: 'Word (DOCX)',
                subtitle: 'Word文書の段落を1つのノートとして取り込みます。',
                icon: Icons.article_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _externalFormatPanel(),
          const SizedBox(height: 24),
          if (_isLoading) const LinearProgressIndicator(),
          if (_evernoteCloudStageProgress != null) ...[
            const SizedBox(height: 8),
            EvernoteCloudStageStatus(
              progress: _evernoteCloudStageProgress!,
            ),
          ],
          if (_lastImportResult != null) ...[
            _buildImportSuccessOnboarding(
              result: _lastImportResult!,
              currentUser: currentUser,
              sourceType: _selectedSource,
            ),
            const SizedBox(height: 16),
          ],
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
                            height: 1.5,
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
                    if (preview.sourceExportSha256 != null) ...[
                      const SizedBox(height: 4),
                      Text('Attachments detected: ${preview.resourceCount}'),
                      const SizedBox(height: 4),
                      SelectableText(
                        'Export SHA-256: ${preview.sourceExportSha256}',
                      ),
                    ],
                    if (!preview.canCommit) ...[
                      const SizedBox(height: 12),
                      Text(
                        preview.commitBlockedReason!,
                        key: const Key('import-commit-safety-gate'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ] else if (currentUser == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Preview is ready. Sign in or create an account from the landing page, then come back to import the full batch.',
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        preview.sourceType == 'evernote'
                            ? 'Import stores a private ENEX recovery archive, commits each note with all attachments, and verifies downloaded hashes before marking the batch verified.'
                            : 'When you confirm import, the full batch will use the Edge Function pipeline first and fall back locally only if needed.',
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
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (preview.sourceType == 'evernote') ...[
                      const SizedBox(height: 16),
                      EvernoteSourceContextFields(
                        notebookController: _evernoteNotebookNameController,
                        stackController: _evernoteStackNameController,
                        spaceController: _evernoteSpaceNameController,
                        onChanged: () => setState(() {}),
                      ),
                      if (_evernoteTransferProgress != null) ...[
                        const SizedBox(height: 12),
                        EvernoteCloudTransferStatus(
                          progress: _evernoteTransferProgress!,
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isImporting ||
                              preview.notes.isEmpty ||
                              !preview.canCommit ||
                              (preview.sourceType == 'evernote' &&
                                  (_evernoteCloudStageResult == null ||
                                      _evernoteNotebookNameController.text
                                          .trim()
                                          .isEmpty))
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
                            : !preview.canCommit
                                ? 'Migration safety gate active'
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  note.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (note.source == 'notion_database' ||
                                  note.source == 'notion_page') ...[
                                const SizedBox(width: 8),
                                Chip(
                                  label: Text(
                                    note.source == 'notion_database'
                                        ? 'DB entry'
                                        : 'Page',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.5,
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ],
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

  Widget _externalFormatPanel() {
    final preview = _externalFormatPreview;
    final exportText = _externalFormatExport;
    return Card(
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
                const Icon(Icons.hub_outlined),
                const Text(
                  '外部標準フォーマット連携',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.rule, size: 18),
                  label: Text(_externalFormatProfile.label),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'SSIM/AIDX 風の連携ファイルを取り込み、連携先ごとに必要な項目だけを動的にマッピングして、正規化済みデータとして出力します。',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _externalFormatId,
              decoration: const InputDecoration(
                labelText: 'フォーマット定義',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'ssim', child: Text('SSIMスケジュール')),
                DropdownMenuItem(value: 'aidx', child: Text('AIDX運航イベント')),
              ],
              onChanged: _selectExternalFormat,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _externalFormatInputController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: '受信CSV / 標準テキスト',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '項目マッピング',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            ..._externalFormatProfile.mappings.asMap().entries.map(
                  (entry) => _externalMappingRow(entry.key, entry.value),
                ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _previewExternalFormat,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('マッピング結果を確認'),
                ),
                OutlinedButton.icon(
                  onPressed: preview == null ? null : _copyExternalExport,
                  icon: const Icon(Icons.copy),
                  label: const Text('出力CSVをコピー'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSavingExternalMapping
                      ? null
                      : _saveExternalMappingProfile,
                  icon: _isSavingExternalMapping
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSavingExternalMapping ? '保存中...' : 'マッピングを保存',
                  ),
                ),
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('${preview.rows.length} rows')),
                  Chip(label: Text('${preview.outputFields.length} fields')),
                  if (preview.warnings.isNotEmpty)
                    Chip(label: Text('${preview.warnings.length} warnings')),
                ],
              ),
              if (preview.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...preview.warnings.map(
                  (warning) => Text(
                    '- $warning',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: preview.outputFields
                      .map((field) => DataColumn(label: Text(field)))
                      .toList(),
                  rows: preview.rows.take(5).map((row) {
                    return DataRow(
                      cells: preview.outputFields
                          .map((field) => DataCell(Text(row[field] ?? '')))
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
              if (exportText != null && exportText.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(
                  exportText,
                  maxLines: 6,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _externalMappingRow(int index, ExternalFieldMapping mapping) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text('送信'),
            selected: mapping.include,
            onSelected: (value) => _updateExternalMapping(
              index,
              (current) => current.copyWith(include: value),
            ),
          ),
          FilterChip(
            label: const Text('必須'),
            selected: mapping.requiredField,
            onSelected: (value) => _updateExternalMapping(
              index,
              (current) => current.copyWith(requiredField: value),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextFormField(
              key: ValueKey('external-source-$_externalFormatId-$index'),
              initialValue: mapping.sourceField,
              decoration: const InputDecoration(
                labelText: '元項目',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => _updateExternalMapping(
                index,
                (current) => current.copyWith(sourceField: value),
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextFormField(
              key: ValueKey('external-target-$_externalFormatId-$index'),
              initialValue: mapping.targetField,
              decoration: const InputDecoration(
                labelText: '出力項目',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => _updateExternalMapping(
                index,
                (current) => current.copyWith(targetField: value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvernoteMigrationProgressPanel(User? currentUser) {
    final progress = EvernoteMigrationProgress.fromBatches(
      _evernoteMigrationBatches,
    );
    final hasPreview = progress.sourceNoteCount > 0;
    final hasImported = progress.importedNoteCount > 0;
    final hasVerified = progress.verifiedNoteCount > 0;
    final hasSourceDeleted = progress.sourceDeletedNoteCount > 0;

    return Card(
      key: const Key('evernote-migration-progress-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Evernote migration ledger',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
                    ),
                  ),
                ),
                if (_isMigrationLedgerLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    tooltip: 'Refresh migration ledger',
                    onPressed: currentUser == null
                        ? null
                        : _loadEvernoteMigrationLedger,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (currentUser == null)
              const Text(
                'Sign in to save staged Evernote migration batches and their verification state.',
              )
            else ...[
              LinearProgressIndicator(value: progress.overallFraction),
              const SizedBox(height: 8),
              Text(
                '${progress.overallPercent}% across export preview, import, verification, and Evernote source deletion',
                key: const Key('evernote-migration-overall-progress'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _migrationStageChip('ENEX export + preview', hasPreview),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('Import', hasImported),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('Verify', hasVerified),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip(
                    'Delete from Evernote',
                    hasSourceDeleted,
                  ),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('Cancel subscription', false),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('Batches: ${progress.batchCount}'),
                  Text('Previewed: ${progress.sourceNoteCount} notes'),
                  Text('Attachments: ${progress.sourceResourceCount}'),
                  Text('Imported: ${progress.importedNoteCount}'),
                  Text('Verified: ${progress.verifiedNoteCount}'),
                  Text(
                    'Deleted from Evernote: '
                    '${progress.sourceDeletedNoteCount}',
                  ),
                ],
              ),
            ],
            if (_migrationLedgerError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Migration ledger unavailable: $_migrationLedgerError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Evernote notes are deleted only after the matching imported batch passes note, attachment, metadata, recovery, hierarchy, and note-history checks.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _migrationStageChip(String label, bool completed) {
    return Chip(
      avatar: Icon(
        completed ? Icons.check_circle : Icons.schedule,
        size: 18,
        color: completed ? Colors.green : null,
      ),
      label: Text(label),
    );
  }

  Widget _notionApiCard() {
    final isSelected = _selectedSource == 'notion_api';
    return SizedBox(
      width: 280,
      child: Card(
        shape: isSelected
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              )
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _isLoading ? null : _fetchNotionApi,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.api),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Notion (API直接連携)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'インテグレーショントークンでページ本文とデータベース項目を直接取得します。ファイルエクスポート不要。',
                ),
              ],
            ),
          ),
        ),
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
                      const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
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

  Widget _buildImportSuccessOnboarding({
    required ImportExecutionResult result,
    required User? currentUser,
    String? sourceType,
  }) {
    final sourceName = switch (sourceType) {
      'notion' || 'notion_api' => 'Notion',
      'evernote' => 'Evernote',
      'markdown' => 'Markdown',
      'xlsx' => 'Excel',
      'docx' => 'Word',
      _ => '競合ツール',
    };
    final count = result.insertedCount;
    final isSignedIn = currentUser != null;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$sourceName から $count 件のノートを移行しました',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.importModeLabel,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            if (!isSignedIn) ...[
              Text(
                'ノートを永続的に保存するには無料アカウントを作成してください。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AI による整理・検索・要約機能も無料で使えます。',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openLandingPage,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('無料アカウントを作成してノートを保存'),
              ),
            ] else ...[
              Text(
                '次は AI でノートを整理してみましょう。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed('/notes'),
                icon: const Icon(Icons.notes_outlined),
                label: const Text('インポートしたノートを見る'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
