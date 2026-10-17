import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/landing_page.dart';
import '../services/business_csv_import_service.dart';
import '../services/external_format_service.dart';
import '../services/evernote_cloud_stage_service.dart';
import '../services/evernote_migration_ledger_service.dart';
import '../services/evernote_migration_commit_service.dart';
import '../services/evernote_note_history_migration_service.dart';
import '../services/gamification_service.dart';
import '../services/growth_acquisition_service.dart';
import '../services/import_service.dart';
import '../utils/web_image_downloader.dart';
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
  final BusinessCsvImportService _businessCsvService =
      const BusinessCsvImportService();
  BusinessCsvDryRunResult? _businessCsvPreview;
  EvernoteCloudStageResult? _evernoteCloudStageResult;
  EvernoteCloudStageProgress? _evernoteCloudStageProgress;
  EvernoteMigrationTransferProgress? _evernoteTransferProgress;
  ImportExecutionResult? _lastImportResult;
  BusinessCsvCommitResult? _lastBusinessCsvCommitResult;
  String? _selectedSource;
  bool _rollbackOnBusinessCsvErrors = true;
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
        '取込前の確認結果は保持されていますが、移行台帳を保存できませんでした：'
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
      _showMessage('クラウドに一時保管するENEXファイルを選ぶ前に、ログインしてください。');
      return;
    }
    setState(() {
      _isLoading = true;
      _selectedSource = sourceType;
      _preview = null;
      _businessCsvPreview = null;
      _lastBusinessCsvCommitResult = null;
      _lastImportResult = null;
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
          throw StateError('選択したENEXファイルを開けませんでした。');
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
        throw Exception('選択したファイルを読み込めませんでした。');
      }

      if (sourceType == 'business_csv') {
        final preview = await _businessCsvService.previewCsvBytes(
          fileName: file.name,
          bytes: bytes,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _preview = null;
          _businessCsvPreview = preview;
          _lastImportResult = null;
          _lastBusinessCsvCommitResult = null;
        });
        return;
      }

      final preview = await _importService.buildPreview(
        sourceType: sourceType,
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _businessCsvPreview = null;
        _lastBusinessCsvCommitResult = null;
      });
      await _recordEvernotePreview(preview);
      unawaited(_acquisitionService.recordImportPreview(sourceType));
    } catch (error) {
      if (!mounted) return;
      _showMessage('取込前の確認に失敗しました：$error');
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
          title: const Text('Notionとの直接連携'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notion インテグレーションのトークンを入力してください。\n'
                'Notionの「設定」→「インテグレーション」から発行できます。ページ本文、入れ子のブロック、データベース項目を直接確認します。',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notionTokenController,
                decoration: const InputDecoration(
                  labelText: '連携用トークン（secret_xxxで始まる値）',
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
        _businessCsvPreview = null;
        _lastBusinessCsvCommitResult = null;
      });
      unawaited(_acquisitionService.recordImportPreview('notion_api'));
    } catch (error) {
      if (!mounted) return;
      _showMessage('Notionとの直接連携による取込前の確認に失敗しました：$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importPreview() async {
    final preview = _preview;
    final user = Supabase.instance.client.auth.currentUser;
    if (preview == null) return;
    if (user == null) {
      _showMessage('ノートを取り込む前に、ログインしてください。');
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
          throw StateError('クラウドに一時保管するENEXファイルをもう一度選択してください。');
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
        '${result.insertedCount}件のノートを取り込みました。処理方法：'
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
          '取込に失敗しましたが、確認済みの非公開バックアップはクラウドに保持されています。'
          'ENEXファイルを選び直さずに再試行できます：$error',
        );
        unawaited(_loadEvernoteMigrationLedger());
      } else {
        _showMessage('取込に失敗しました：$error');
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _commitBusinessCsvPreview() async {
    final preview = _businessCsvPreview;
    final user = Supabase.instance.client.auth.currentUser;
    if (preview == null) {
      return;
    }
    if (user == null) {
      _showMessage('業務用CSVを取り込む前に、ログインしてください。');
      return;
    }
    if (preview.validRows.isEmpty) {
      _showMessage('保存できる正常なCSV行がありません。');
      return;
    }

    setState(() => _isImporting = true);
    try {
      final result = await _businessCsvService.commitRows(
        fileName: preview.fileName,
        rows: preview.rows.isEmpty ? preview.validRows : preview.rows,
        mode: _rollbackOnBusinessCsvErrors
            ? BusinessCsvCommitMode.allOrRollback
            : BusinessCsvCommitMode.validRowsOnly,
      );
      if (!mounted) {
        return;
      }
      final message = result.rolledBack
          ? '${result.dryRun.errorCount}行に問題があるため、CSVの保存をすべて取り消しました。'
          : '正常なCSVデータを${result.insertedCount}行取り込みました。';
      _showMessage(message);
      setState(() {
        _lastBusinessCsvCommitResult = result;
        _businessCsvPreview = result.rolledBack ? result.dryRun : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage('業務用CSVの保存に失敗しました：$error');
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _downloadBusinessCsvErrors() {
    final preview = _businessCsvPreview;
    if (preview == null || preview.errorRows.isEmpty) {
      return;
    }
    final baseName = preview.fileName.trim().isEmpty
        ? 'business-csv-errors'
        : preview.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    downloadCsvFile(preview.errorCsv, '$baseName-errors.csv');
    _showMessage('修正が必要な行の一覧を保存しました。');
  }

  Future<void> _copyBusinessCsvErrors() async {
    final preview = _businessCsvPreview;
    if (preview == null || preview.errorRows.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: preview.errorCsv));
    if (!mounted) {
      return;
    }
    _showMessage('修正が必要な行の一覧をコピーしました。');
  }

  void _setEvernoteSourceContextDefaults(String fileName) {
    final normalized = fileName.replaceAll('\\', '/');
    final leaf = normalized.split('/').last.trim();
    final dotIndex = leaf.lastIndexOf('.');
    final inferredNotebook =
        (dotIndex > 0 ? leaf.substring(0, dotIndex) : leaf).trim();
    _evernoteNotebookNameController.text =
        inferredNotebook.isEmpty ? 'Evernoteからの取込' : inferredNotebook;
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
      case 'business_csv':
        return const <String>['csv'];
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
    final businessCsvPreview = _businessCsvPreview;
    final currentUser = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('データ取込')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Notion・Evernoteからノートを移す',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ノートを取り込む前に、内容を確認できます。通常版ではクラウドで確認処理を行い、利用できない場合だけ端末内で処理します。この架空データ版では外部サービスに接続しません。',
          ),
          const SizedBox(height: 8),
          const Text(
            '通常版では、大量のノートもブラウザーだけに負担をかけず、クラウド側で順番に取り込みます。この画面は確認用のため、実際の取込は行いません。',
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
                title: 'Notionの書き出しファイル（CSV）',
                subtitle:
                    '書き出したCSVの内容を確認し、タイトル・本文・タグを移します。',
                icon: Icons.table_chart,
              ),
              _sourceCard(
                sourceType: 'evernote',
                title: 'Evernoteの書き出しファイル（ENEX）',
                subtitle:
                    'ENEXのバックアップを保管し、ノートと添付ファイルを取り込みます。移行元を削除する前に、データが一致しているか確認します。',
                icon: Icons.note_alt,
              ),
              _sourceCard(
                sourceType: 'markdown',
                title: 'マークダウン',
                subtitle:
                    'マークダウン形式のファイルを、ノートとして取り込む前に確認します。',
                icon: Icons.description,
              ),
              _sourceCard(
                sourceType: 'xlsx',
                title: 'Excelの表計算ファイル（XLSX）',
                subtitle: 'Notionの表エクスポート等を行ごと・列見出し対応でノート化。',
                icon: Icons.grid_on,
              ),
              _sourceCard(
                sourceType: 'docx',
                title: 'Wordの文書ファイル（DOCX）',
                subtitle: 'Word文書の段落を1つのノートとして取り込みます。',
                icon: Icons.article_outlined,
              ),
              _sourceCard(
                sourceType: 'business_csv',
                title: '業務用CSV',
                subtitle:
                    '保存せずに各行を検査します。問題のある行だけ書き出し、正常な行を保存するか、まとめて取り消すかを選べます。',
                icon: Icons.rule_folder_outlined,
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
          if (_lastBusinessCsvCommitResult != null) ...[
            _buildBusinessCsvCommitResultCard(_lastBusinessCsvCommitResult!),
            const SizedBox(height: 16),
          ],
          if (businessCsvPreview != null) ...[
            _buildBusinessCsvPreviewCard(
              preview: businessCsvPreview,
              currentUser: currentUser,
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
                          '${preview.sourceLabel}：取込前の確認',
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
                    Text('ファイル名：${preview.fileName}'),
                    const SizedBox(height: 4),
                    Text('取込可能なノート：${preview.notes.length}件'),
                    if (preview.sourceExportSha256 != null) ...[
                      const SizedBox(height: 4),
                      Text('添付ファイル：${preview.resourceCount}件'),
                      const SizedBox(height: 4),
                      SelectableText(
                        '書き出しデータの照合用ハッシュ値：${preview.sourceExportSha256}',
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
                        '内容を確認できました。通常版で全件取り込むには、案内ページでログインまたはアカウントを作成し、この画面に戻ってください。',
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Text(
                        preview.sourceType == 'evernote'
                            ? '復旧用のENEXバックアップを非公開で保管し、ノートと添付ファイルを一緒に保存します。保存後のデータを取り出して元と照合してから、確認済みとします。'
                            : '通常版では、取込の確定後に全件をクラウドで処理し、必要な場合だけ端末内の処理に切り替えます。',
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
                            ? '取込中…'
                            : !preview.canCommit
                                ? '移行の安全確認が未完了です'
                                : currentUser == null
                                    ? '取込に必要なアカウントを作成'
                                    : 'このノートを取り込む',
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
                                        ? 'データベースの項目'
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
                  'このほかに${preview.notes.length - 12}件の取込可能なノートがあります。',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBusinessCsvPreviewCard({
    required BusinessCsvDryRunResult preview,
    required User? currentUser,
  }) {
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
                const Text(
                  '業務用CSVの保存前チェック',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                Chip(
                  avatar: Icon(
                    preview.usedServerDryRun
                        ? Icons.storage_outlined
                        : Icons.computer,
                    size: 18,
                  ),
                  label: Text(
                    preview.usedServerDryRun ? 'データベース側で検査' : '端末内で検査',
                  ),
                ),
                Chip(label: Text('正常：${preview.validCount}行')),
                Chip(
                  label: Text('要修正：${preview.errorCount}行'),
                  backgroundColor: preview.hasErrors
                      ? Theme.of(context).colorScheme.errorContainer
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('ファイル名：${preview.fileName}'),
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...preview.warnings.map(
                (warning) => Text(
                  '- $warning',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('問題のある行が1行でもあれば、全件の保存を取り消す'),
              value: _rollbackOnBusinessCsvErrors,
              onChanged: (value) {
                setState(() => _rollbackOnBusinessCsvErrors = value);
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isImporting || preview.validRows.isEmpty
                      ? null
                      : currentUser == null
                          ? _openLandingPage
                          : _commitBusinessCsvPreview,
                  icon: Icon(
                    currentUser == null
                        ? Icons.login
                        : Icons.download_done_outlined,
                  ),
                  label: Text(
                    _isImporting
                        ? '保存中…'
                        : currentUser == null
                            ? '保存に必要なアカウントを作成'
                            : 'CSVのデータを保存',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: preview.errorRows.isEmpty
                      ? null
                      : _downloadBusinessCsvErrors,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('要修正の行をCSVで保存'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      preview.errorRows.isEmpty ? null : _copyBusinessCsvErrors,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('要修正の行をCSVでコピー'),
                ),
              ],
            ),
            if (preview.errorRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '修正が必要な行',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('行番号')),
                    DataColumn(label: Text('タイトル')),
                    DataColumn(label: Text('問題の内容')),
                  ],
                  rows: preview.errorRows.take(8).map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row.rowNumber.toString())),
                        DataCell(Text(row.title.isEmpty ? '-' : row.title)),
                        DataCell(Text(row.reasonText)),
                      ],
                    );
                  }).toList(),
                ),
              ),
              if (preview.errorRows.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'CSVには、このほかに${preview.errorRows.length - 8}行の要修正データが含まれます。',
                  ),
                ),
            ],
            if (preview.validRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '正常な行',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('行番号')),
                    DataColumn(label: Text('タイトル')),
                    DataColumn(label: Text('タグ')),
                  ],
                  rows: preview.validRows.take(6).map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row.rowNumber.toString())),
                        DataCell(Text(row.title)),
                        DataCell(Text(row.tags.join(', '))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessCsvCommitResultCard(BusinessCsvCommitResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: result.rolledBack
          ? colorScheme.errorContainer
          : colorScheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              result.rolledBack
                  ? Icons.assignment_return_outlined
                  : Icons.check_circle_outline,
              color:
                  result.rolledBack ? colorScheme.error : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.rolledBack
                    ? 'CSVの保存を取り消しました。${result.dryRun.errorCount}行を修正してください。'
                    : '業務用CSVを${result.insertedCount}行取り込みました。',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: result.rolledBack
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
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
                  Chip(label: Text('${preview.rows.length}行')),
                  Chip(label: Text('${preview.outputFields.length}項目')),
                  if (preview.warnings.isNotEmpty)
                    Chip(label: Text('注意：${preview.warnings.length}件')),
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
                    'Evernoteの移行台帳',
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
                    tooltip: '移行台帳を更新',
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
                '通常版ではログインすると、Evernoteの取込単位ごとの進捗と確認状況を保存できます。',
              )
            else ...[
              LinearProgressIndicator(value: progress.overallFraction),
              const SizedBox(height: 8),
              Text(
                '全体の進捗：${progress.overallPercent}%（書き出し内容の確認・取込・照合・移行元の削除）',
                key: const Key('evernote-migration-overall-progress'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _migrationStageChip('書き出し・内容確認', hasPreview),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('データ取込', hasImported),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('データ照合', hasVerified),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip(
                    'Evernoteの移行元を削除',
                    hasSourceDeleted,
                  ),
                  const Icon(Icons.arrow_forward, size: 16),
                  _migrationStageChip('有料契約を解約', false),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text('取込単位：${progress.batchCount}件'),
                  Text('内容確認済み：${progress.sourceNoteCount}件'),
                  Text('添付ファイル：${progress.sourceResourceCount}件'),
                  Text('取込済み：${progress.importedNoteCount}件'),
                  Text('照合済み：${progress.verifiedNoteCount}件'),
                  Text(
                    'Evernoteから削除済み：'
                    '${progress.sourceDeletedNoteCount}',
                  ),
                ],
              ),
            ],
            if (_migrationLedgerError != null) ...[
              const SizedBox(height: 12),
              Text(
                '移行台帳を読み込めませんでした：$_migrationLedgerError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Evernote側のノートを削除できるのは、対応する取込データについて、本文・添付ファイル・付随情報・復旧方法・階層・変更履歴の確認がすべて完了した後だけです。',
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
      'markdown' => 'マークダウン',
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
