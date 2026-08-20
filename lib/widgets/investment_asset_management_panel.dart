import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/investment_asset.dart';
import '../models/investment_portfolio_history.dart';
import '../services/csv_bytes_decoder.dart';
import '../services/investment_asset_repository.dart';
import '../services/investment_csv_import_service.dart';
import '../services/investment_portfolio_history_service.dart';
import '../services/investment_valuation_service.dart';
import 'investment_portfolio_history_chart.dart';

typedef InvestmentCsvBytesPicker = Future<Uint8List?> Function();

/// 投資資産の登録・一覧・編集・削除をまとめたダッシュボードパネル。
class InvestmentAssetManagementPanel extends StatefulWidget {
  const InvestmentAssetManagementPanel({
    super.key,
    required this.repository,
    required this.userId,
    this.valuationService = const InvestmentValuationService(),
    this.historyService = const InvestmentPortfolioHistoryService(),
    this.currencyFormatter,
    this.now,
    this.csvBytesPicker,
    this.csvBytesDecoder = const CsvBytesDecoder(),
    this.csvImportService = const InvestmentCsvImportService(),
  });

  final InvestmentAssetRepository repository;
  final String? userId;
  final InvestmentValuationService valuationService;
  final InvestmentPortfolioHistoryService historyService;
  final String Function(double value)? currencyFormatter;
  final DateTime Function()? now;
  final InvestmentCsvBytesPicker? csvBytesPicker;
  final CsvBytesDecoder csvBytesDecoder;
  final InvestmentCsvImportService csvImportService;

  @override
  State<InvestmentAssetManagementPanel> createState() =>
      _InvestmentAssetManagementPanelState();
}

class _InvestmentAssetManagementPanelState
    extends State<InvestmentAssetManagementPanel> {
  static const Color _accent = Color(0xFF2563EB);
  static const Color _positive = Color(0xFF0D7A70);
  static const Color _negative = Color(0xFFB91C1C);
  static const Color _muted = Color(0xFF6B7280);

  final NumberFormat _yenFormat = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );
  final NumberFormat _quantityFormat = NumberFormat('#,##0.########');

  List<InvestmentAsset> _assets = const <InvestmentAsset>[];
  List<InvestmentPortfolioHistoryPoint> _history =
      const <InvestmentPortfolioHistoryPoint>[];
  Object? _loadError;
  Object? _historyLoadError;
  bool _loading = false;
  bool _historyLoading = false;
  bool _saving = false;
  bool _importingCsv = false;
  int _loadSequence = 0;
  int _historyLoadSequence = 0;
  InvestmentHistoryPeriod _historyPeriod = InvestmentHistoryPeriod.oneYear;

  String? get _normalizedUserId {
    final value = widget.userId?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    _loading = _normalizedUserId != null;
    _historyLoading = _normalizedUserId != null;
    unawaited(_load(showLoading: false));
  }

  @override
  void didUpdateWidget(covariant InvestmentAssetManagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId?.trim() != widget.userId?.trim() ||
        !identical(oldWidget.repository, widget.repository)) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool showLoading = true}) async {
    final sequence = ++_loadSequence;
    final userId = _normalizedUserId;
    if (userId == null) {
      _historyLoadSequence++;
      if (!mounted) return;
      setState(() {
        _assets = const <InvestmentAsset>[];
        _history = const <InvestmentPortfolioHistoryPoint>[];
        _loadError = null;
        _historyLoadError = null;
        _loading = false;
        _historyLoading = false;
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
        _historyLoading = true;
        _historyLoadError = null;
      });
    }
    try {
      final assets = await widget.repository.fetchByUser(userId: userId);
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _assets = _sorted(assets);
        _loadError = null;
        _loading = false;
      });
      await _loadHistory(userId, parentSequence: sequence);
    } catch (error) {
      if (!mounted || sequence != _loadSequence) return;
      setState(() {
        _loadError = error;
        _loading = false;
        _historyLoading = false;
      });
    }
  }

  Future<void> _loadHistory(String userId, {int? parentSequence}) async {
    final sequence = ++_historyLoadSequence;
    if (mounted) {
      setState(() {
        _historyLoading = true;
        _historyLoadError = null;
      });
    }
    try {
      final history = await widget.repository.fetchPortfolioHistory(
        userId: userId,
      );
      if (!mounted ||
          sequence != _historyLoadSequence ||
          (parentSequence != null && parentSequence != _loadSequence)) {
        return;
      }
      setState(() {
        _history = history;
        _historyLoadError = null;
        _historyLoading = false;
      });
    } catch (error) {
      if (!mounted || sequence != _historyLoadSequence) return;
      setState(() {
        _historyLoadError = error;
        _historyLoading = false;
      });
    }
  }

  Future<Uint8List?> _pickCsvBytes() async {
    final picker = widget.csvBytesPicker;
    if (picker != null) return picker();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv'],
      allowMultiple: false,
      withData: true,
    );
    return result?.files.single.bytes;
  }

  Future<void> _openCsvImport() async {
    final userId = _normalizedUserId;
    if (userId == null || _saving || _importingCsv) return;

    setState(() => _importingCsv = true);
    try {
      final bytes = await _pickCsvBytes();
      if (bytes == null || bytes.isEmpty || !mounted) return;
      final text = widget.csvBytesDecoder.decode(
        bytes,
        looksValid: InvestmentCsvImportService.looksLikeCsv,
        formatName: '投資資産CSV',
      );
      final parsed = widget.csvImportService.parse(text);
      final policy = await showDialog<InvestmentCsvDuplicatePolicy>(
        context: context,
        builder: (context) => InvestmentCsvImportPreviewDialog(
          parsed: parsed,
          existingAssets: _assets,
          importService: widget.csvImportService,
        ),
      );
      if (policy == null || !mounted || _normalizedUserId != userId) return;

      final plan = widget.csvImportService.buildPlan(
        parsed: parsed,
        existingAssets: _assets,
        duplicatePolicy: policy,
      );
      if (plan.writeCount == 0) {
        _showMessage('取り込む銘柄はありませんでした。');
        return;
      }

      setState(() => _saving = true);
      final saved = <InvestmentAsset>[];
      for (final update in plan.updates) {
        saved.add(
          await widget.repository.update(
            userId: userId,
            assetId: update.asset.id,
            draft: update.draft,
          ),
        );
      }
      for (final draft in plan.creates) {
        saved.add(await widget.repository.create(userId: userId, draft: draft));
      }
      if (!mounted) return;
      final updatedIds = plan.updates.map((item) => item.asset.id).toSet();
      setState(() {
        _assets = _sorted(<InvestmentAsset>[
          for (final asset in _assets)
            if (!updatedIds.contains(asset.id)) asset,
          ...saved,
        ]);
      });
      unawaited(_loadHistory(userId));
      _showMessage(
        '${plan.creates.length}件追加・${plan.updates.length}件更新・'
        '${plan.skippedDuplicates}件スキップしました。',
      );
    } catch (error, stackTrace) {
      debugPrint('Investment CSV import failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final detail = error is FormatException ? error.message : null;
      _showMessage(
        detail == null ? '投資資産CSVを取り込めませんでした。' : '投資資産CSVを取り込めませんでした: $detail',
      );
      unawaited(_load(showLoading: false));
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _importingCsv = false;
        });
      }
    }
  }

  Future<void> _openEditor([InvestmentAsset? asset]) async {
    final userId = _normalizedUserId;
    if (userId == null || _saving) return;

    final draft = await showDialog<InvestmentAssetDraft>(
      context: context,
      builder: (context) => InvestmentAssetEditorDialog(asset: asset),
    );
    if (draft == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final saved = asset == null
          ? await widget.repository.create(userId: userId, draft: draft)
          : await widget.repository.update(
              userId: userId,
              assetId: asset.id,
              draft: draft,
            );
      if (!mounted) return;
      setState(() {
        final next = <InvestmentAsset>[
          for (final current in _assets)
            if (current.id != saved.id) current,
          saved,
        ];
        _assets = _sorted(next);
      });
      unawaited(_loadHistory(userId));
      _showMessage(
        asset == null ? '${saved.ticker}を追加しました。' : '${saved.ticker}を更新しました。',
      );
    } catch (error, stackTrace) {
      debugPrint('Investment asset save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showMessage('投資資産を保存できませんでした。時間をおいて再試行してください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(InvestmentAsset asset) async {
    final userId = _normalizedUserId;
    if (userId == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('投資資産を削除'),
        content: Text('${asset.ticker}を一覧から削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            key: const Key('investment_asset_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('削除'),
            style: FilledButton.styleFrom(backgroundColor: _negative),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repository.delete(userId: userId, assetId: asset.id);
      if (!mounted) return;
      setState(() {
        _assets = <InvestmentAsset>[
          for (final current in _assets)
            if (current.id != asset.id) current,
        ];
      });
      unawaited(_loadHistory(userId));
      _showMessage('${asset.ticker}を削除しました。');
    } catch (error, stackTrace) {
      debugPrint('Investment asset delete failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      _showMessage('投資資産を削除できませんでした。時間をおいて再試行してください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<InvestmentAsset> _sorted(Iterable<InvestmentAsset> assets) {
    final sorted = assets.toList()
      ..sort((a, b) {
        final typeOrder = a.assetType.index.compareTo(b.assetType.index);
        return typeOrder != 0 ? typeOrder : a.ticker.compareTo(b.ticker);
      });
    return List<InvestmentAsset>.unmodifiable(sorted);
  }

  String _yen(double value) {
    final formatter = widget.currencyFormatter;
    return formatter == null ? _yenFormat.format(value) : formatter(value);
  }

  String _signedYen(double value) {
    return '${value >= 0 ? '+' : '-'}${_yen(value.abs())}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('investment_asset_management_panel'),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '投資資産',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('investment_asset_csv_import'),
                  tooltip: '証券CSVを取り込む',
                  onPressed:
                      _normalizedUserId == null || _saving || _importingCsv
                          ? null
                          : _openCsvImport,
                  icon: _importingCsv
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                ),
                IconButton(
                  key: const Key('investment_asset_add'),
                  tooltip: '銘柄を追加',
                  onPressed:
                      _normalizedUserId == null || _saving ? null : _openEditor,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '株式・暗号資産・REIT・ETF',
              style: theme.textTheme.bodySmall?.copyWith(color: _muted),
            ),
            const SizedBox(height: 12),
            _buildBody(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_normalizedUserId == null) {
      return Text(
        'ログインすると投資資産を登録できます。',
        key: const Key('investment_asset_logged_out'),
        style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
      );
    }
    if (_loading) {
      return const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Row(
        key: const Key('investment_asset_load_error'),
        children: [
          const Expanded(child: Text('投資資産を読み込めませんでした。')),
          IconButton(
            tooltip: '再読み込み',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }
    if (_assets.isEmpty) {
      return Text(
        '登録済みの銘柄はありません。',
        key: const Key('investment_asset_empty'),
        style: theme.textTheme.bodyMedium?.copyWith(color: _muted),
      );
    }

    final portfolio = widget.valuationService.summarize(_assets);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPortfolioSummary(portfolio),
        const SizedBox(height: 20),
        _buildHistory(theme),
        const SizedBox(height: 12),
        for (var index = 0; index < portfolio.items.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          _buildAssetRow(theme, portfolio.items[index]),
        ],
      ],
    );
  }

  Widget _buildHistory(ThemeData theme) {
    if (_historyLoading) {
      return const SizedBox(
        key: Key('investment_history_loading'),
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_historyLoadError != null) {
      return Row(
        key: const Key('investment_history_load_error'),
        children: [
          const Expanded(child: Text('投資資産の推移を読み込めませんでした。')),
          IconButton(
            tooltip: '推移を再読み込み',
            onPressed: () {
              final userId = _normalizedUserId;
              if (userId != null) unawaited(_loadHistory(userId));
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
    }

    final points = widget.historyService.selectForChart(
      _history,
      period: _historyPeriod,
      now: widget.now?.call() ?? DateTime.now(),
    );
    return InvestmentPortfolioHistoryChart(
      points: points,
      period: _historyPeriod,
      onPeriodChanged: (period) => setState(() => _historyPeriod = period),
      currencyFormatter: widget.currencyFormatter,
    );
  }

  Widget _buildPortfolioSummary(InvestmentPortfolioValuation portfolio) {
    final pricedCount = portfolio.items.length - portfolio.unpricedAssetCount;
    final pricedText =
        pricedCount == 0 ? '未取得' : _yen(portfolio.pricedMarketValueJpy);
    final acquisitionLabel = portfolio.unpricedAssetCount > 0 && pricedCount > 0
        ? '取得額（評価済）'
        : '取得額';
    final acquisitionValue = pricedCount > 0
        ? portfolio.pricedAcquisitionCostJpy
        : portfolio.totalAcquisitionCostJpy;
    return Wrap(
      key: const Key('investment_asset_portfolio_summary'),
      spacing: 20,
      runSpacing: 8,
      children: [
        _Metric(label: '評価額', value: pricedText),
        _Metric(label: acquisitionLabel, value: _yen(acquisitionValue)),
        _Metric(label: '銘柄数', value: '${portfolio.items.length}'),
        if (portfolio.unpricedAssetCount > 0)
          _Metric(label: '価格未取得', value: '${portfolio.unpricedAssetCount}件'),
      ],
    );
  }

  Widget _buildAssetRow(ThemeData theme, InvestmentAssetValuation valuation) {
    final asset = valuation.asset;
    final gainLoss = valuation.unrealizedGainLossJpy;
    final gainRate = valuation.unrealizedGainLossRate;
    final valueColor = gainLoss == null
        ? null
        : gainLoss >= 0
            ? _positive
            : _negative;
    final date = asset.buyDate;
    final purchaseDate = date == null
        ? '取得日未入力'
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/'
            '${date.day.toString().padLeft(2, '0')}';

    return Column(
      key: ValueKey<String>('investment_asset_${asset.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    asset.ticker,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _assetTypeLabel(asset.assetType),
                    style: theme.textTheme.labelSmall?.copyWith(color: _muted),
                  ),
                ],
              ),
            ),
            IconButton(
              key: ValueKey<String>('investment_asset_edit_${asset.id}'),
              tooltip: '${asset.ticker}を編集',
              onPressed: _saving ? null : () => _openEditor(asset),
              icon: const Icon(Icons.edit_outlined),
              iconSize: 20,
            ),
            IconButton(
              key: ValueKey<String>('investment_asset_delete_${asset.id}'),
              tooltip: '${asset.ticker}を削除',
              onPressed: _saving ? null : () => _confirmDelete(asset),
              icon: const Icon(Icons.delete_outline),
              iconSize: 20,
            ),
          ],
        ),
        Text(
          '${_quantityFormat.format(asset.quantity)} × '
          '${_yen(asset.buyPriceJpy)} / $purchaseDate',
          style: theme.textTheme.bodySmall?.copyWith(color: _muted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _Metric(
              label: '評価額',
              value: valuation.marketValueJpy == null
                  ? '未取得'
                  : _yen(valuation.marketValueJpy!),
            ),
            _Metric(
              label: '損益',
              value: gainLoss == null ? '未取得' : _signedYen(gainLoss),
              valueColor: valueColor,
            ),
            _Metric(
              label: '比率',
              value: gainRate == null
                  ? '未取得'
                  : '${gainRate >= 0 ? '+' : ''}'
                      '${(gainRate * 100).toStringAsFixed(1)}%',
              valueColor: valueColor,
            ),
          ],
        ),
      ],
    );
  }
}

class InvestmentCsvImportPreviewDialog extends StatefulWidget {
  const InvestmentCsvImportPreviewDialog({
    super.key,
    required this.parsed,
    required this.existingAssets,
    required this.importService,
  });

  final InvestmentCsvParseResult parsed;
  final List<InvestmentAsset> existingAssets;
  final InvestmentCsvImportService importService;

  @override
  State<InvestmentCsvImportPreviewDialog> createState() =>
      _InvestmentCsvImportPreviewDialogState();
}

class _InvestmentCsvImportPreviewDialogState
    extends State<InvestmentCsvImportPreviewDialog> {
  InvestmentCsvDuplicatePolicy _policy = InvestmentCsvDuplicatePolicy.skip;

  @override
  Widget build(BuildContext context) {
    final plan = widget.importService.buildPlan(
      parsed: widget.parsed,
      existingAssets: widget.existingAssets,
      duplicatePolicy: _policy,
    );
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('investment_csv_preview_dialog'),
      title: Text('${widget.parsed.broker.label} CSVプレビュー'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.parsed.rows.length}銘柄を検出 '
                '（新規${plan.creates.length}・更新${plan.updates.length}・'
                'スキップ${plan.skippedDuplicates}・'
                '読込不可${plan.invalidRows}）',
                key: const Key('investment_csv_preview_summary'),
              ),
              const SizedBox(height: 12),
              Text('重複ticker', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<InvestmentCsvDuplicatePolicy>(
                key: const Key('investment_csv_duplicate_policy'),
                segments: const <ButtonSegment<InvestmentCsvDuplicatePolicy>>[
                  ButtonSegment<InvestmentCsvDuplicatePolicy>(
                    value: InvestmentCsvDuplicatePolicy.skip,
                    label: Text('スキップ'),
                    icon: Icon(Icons.skip_next_outlined),
                  ),
                  ButtonSegment<InvestmentCsvDuplicatePolicy>(
                    value: InvestmentCsvDuplicatePolicy.update,
                    label: Text('更新'),
                    icon: Icon(Icons.update_outlined),
                  ),
                ],
                selected: <InvestmentCsvDuplicatePolicy>{_policy},
                onSelectionChanged: (selection) {
                  setState(() => _policy = selection.single);
                },
              ),
              const SizedBox(height: 12),
              for (final row in widget.parsed.rows.take(20))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.draft.normalizedTicker),
                  subtitle: Text(
                    '数量 ${row.draft.quantity} / '
                    '取得単価 ¥${row.draft.buyPriceJpy.toStringAsFixed(2)}'
                    '${row.mergedRowCount > 1 ? ' / ${row.mergedRowCount}行統合' : ''}',
                  ),
                ),
              if (widget.parsed.rows.length > 20)
                Text('ほか ${widget.parsed.rows.length - 20}銘柄'),
              if (widget.parsed.issues.isNotEmpty) ...[
                const Divider(),
                Text(
                  '読み込めない行',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                for (final issue in widget.parsed.issues.take(5))
                  Text('行${issue.lineNumber}: ${issue.message}'),
                if (widget.parsed.issues.length > 5)
                  Text('ほか ${widget.parsed.issues.length - 5}行'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('investment_csv_import_confirm'),
          onPressed: plan.writeCount == 0
              ? null
              : () => Navigator.of(context).pop(_policy),
          icon: const Icon(Icons.upload_file_outlined),
          label: Text('${plan.writeCount}件を取り込む'),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class InvestmentAssetEditorDialog extends StatefulWidget {
  const InvestmentAssetEditorDialog({super.key, this.asset});

  final InvestmentAsset? asset;

  @override
  State<InvestmentAssetEditorDialog> createState() =>
      _InvestmentAssetEditorDialogState();
}

class _InvestmentAssetEditorDialogState
    extends State<InvestmentAssetEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late InvestmentAssetType _assetType;
  late final TextEditingController _tickerController;
  late final TextEditingController _quantityController;
  late final TextEditingController _buyPriceController;
  late final TextEditingController _buyDateController;
  DateTime? _buyDate;

  @override
  void initState() {
    super.initState();
    final asset = widget.asset;
    _assetType = asset?.assetType ?? InvestmentAssetType.stock;
    _tickerController = TextEditingController(text: asset?.ticker ?? '');
    _quantityController = TextEditingController(
      text: asset == null ? '' : _plainNumber(asset.quantity),
    );
    _buyPriceController = TextEditingController(
      text: asset == null ? '' : _plainNumber(asset.buyPriceJpy),
    );
    _buyDate = asset?.buyDate;
    _buyDateController = TextEditingController(text: _formatDate(_buyDate));
  }

  @override
  void dispose() {
    _tickerController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _buyDateController.dispose();
    super.dispose();
  }

  Future<void> _pickBuyDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _buyDate ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null && mounted) {
      setState(() {
        _buyDate = selected;
        _buyDateController.text = _formatDate(selected);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final ticker = _tickerController.text.trim().toUpperCase();
    final asset = widget.asset;
    final keepsPriceCache = asset != null &&
        asset.assetType == _assetType &&
        asset.ticker.trim().toUpperCase() == ticker;
    Navigator.of(context).pop(
      InvestmentAssetDraft(
        assetType: _assetType,
        ticker: ticker,
        existingTicker: asset?.ticker,
        quantity: _parseNumber(_quantityController.text)!,
        buyPriceJpy: _parseNumber(_buyPriceController.text)!,
        buyDate: _buyDate,
        currentPriceJpy: keepsPriceCache ? asset.currentPriceJpy : null,
        lastPricedAt: keepsPriceCache ? asset.lastPricedAt : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.asset == null ? '銘柄を追加' : '銘柄を編集'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<InvestmentAssetType>(
                key: const Key('investment_asset_type_field'),
                initialValue: _assetType,
                decoration: const InputDecoration(
                  labelText: '種別',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final type in InvestmentAssetType.values)
                    DropdownMenuItem(
                      value: type,
                      child: Text(_assetTypeLabel(type)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _assetType = value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('investment_asset_ticker_field'),
                controller: _tickerController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '銘柄コード',
                  hintText: '例: AAPL / BTC',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => _tickerValidationMessage(
                  value,
                  existingTicker: widget.asset?.ticker,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('investment_asset_quantity_field'),
                controller: _quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final number = _parseNumber(value);
                  return number == null || !number.isFinite || number <= 0
                      ? '0より大きい数量を入力してください。'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('investment_asset_buy_price_field'),
                controller: _buyPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '取得価格（1単位・円）',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final number = _parseNumber(value);
                  return number == null || !number.isFinite || number < 0
                      ? '0以上の取得価格を入力してください。'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('investment_asset_buy_date_field'),
                readOnly: true,
                onTap: _pickBuyDate,
                controller: _buyDateController,
                decoration: InputDecoration(
                  labelText: '取得日（任意）',
                  hintText: _buyDate == null ? '未入力' : null,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '取得日を選択',
                    onPressed: _pickBuyDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('investment_asset_save'),
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: const Text('保存'),
        ),
      ],
    );
  }
}

String _assetTypeLabel(InvestmentAssetType type) {
  return switch (type) {
    InvestmentAssetType.stock => '株式',
    InvestmentAssetType.crypto => '暗号資産',
    InvestmentAssetType.reit => 'REIT',
    InvestmentAssetType.etf => 'ETF',
  };
}

String? _tickerValidationMessage(String? value, {String? existingTicker}) {
  return switch (investmentTickerValidationError(
    value,
    existingTicker: existingTicker,
  )) {
    InvestmentTickerValidationError.empty => '銘柄コードを入力してください。',
    InvestmentTickerValidationError.invalidFormat =>
      '銘柄コードは半角英数字と . _ : - を1〜32文字で入力してください。',
    null => null,
  };
}

double? _parseNumber(String? value) {
  if (value == null) return null;
  return double.tryParse(value.replaceAll(',', '').trim());
}

String _plainNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

String _formatDate(DateTime? value) {
  if (value == null) return '';
  return '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}
