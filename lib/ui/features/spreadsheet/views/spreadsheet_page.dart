import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/spreadsheet_document.dart';
import '../../../../services/auto_save_service.dart';
import '../view_models/spreadsheet_view_model.dart';

class SpreadsheetPage extends StatefulWidget {
  const SpreadsheetPage({super.key});

  @override
  State<SpreadsheetPage> createState() => _SpreadsheetPageState();
}

class _SpreadsheetPageState extends State<SpreadsheetPage> {
  static const double _rowHeaderWidth = 52;
  static const double _cellWidth = 112;
  static const double _cellHeight = 38;

  final TextEditingController _formulaController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _formulaFocus = FocusNode();
  final FocusNode _titleFocus = FocusNode();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _formulaController.dispose();
    _titleController.dispose();
    _formulaFocus.dispose();
    _titleFocus.dispose();
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpreadsheetViewModel>(
      builder: (context, viewModel, _) {
        _syncControllers(viewModel);
        return Scaffold(
          key: const Key('spreadsheet-page'),
          appBar: AppBar(title: const Text('表計算'), centerTitle: false),
          body: switch (viewModel.status) {
            SpreadsheetLoadStatus.initial ||
            SpreadsheetLoadStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            SpreadsheetLoadStatus.failure => _LoadFailure(
                message: viewModel.errorMessage ?? '読み込みに失敗しました。',
                onRetry: viewModel.load,
              ),
            SpreadsheetLoadStatus.ready => _buildReady(context, viewModel),
          },
        );
      },
    );
  }

  Widget _buildReady(BuildContext context, SpreadsheetViewModel viewModel) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          unawaited(viewModel.save());
        },
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            viewModel.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            viewModel.redo,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final editor = _buildEditor(context, viewModel);
            if (constraints.maxWidth >= 960) {
              return Row(
                key: const Key('spreadsheet-wide-layout'),
                children: [
                  SizedBox(
                    width: 236,
                    child: _WorkbookSidebar(
                      viewModel: viewModel,
                      onRename: (sheet) => _showRenameSheetDialog(
                        viewModel,
                        sheet,
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: editor),
                ],
              );
            }
            return KeyedSubtree(
              key: const Key('spreadsheet-compact-layout'),
              child: editor,
            );
          },
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, SpreadsheetViewModel viewModel) {
    return Column(
      children: [
        _buildToolbar(context, viewModel),
        const Divider(height: 1),
        _buildFormulaBar(context, viewModel),
        const Divider(height: 1),
        if (viewModel.errorMessage != null)
          MaterialBanner(
            content: Text(viewModel.errorMessage!),
            actions: [
              TextButton(
                onPressed: viewModel.clearMessages,
                child: const Text('閉じる'),
              ),
            ],
          ),
        if (viewModel.noticeMessage != null)
          MaterialBanner(
            leading: const Icon(Icons.check_circle_outline),
            content: Text(viewModel.noticeMessage!),
            actions: [
              TextButton(
                onPressed: viewModel.clearMessages,
                child: const Text('閉じる'),
              ),
            ],
          ),
        Expanded(child: _buildGrid(context, viewModel)),
        const Divider(height: 1),
        _SheetTabBar(
          viewModel: viewModel,
          onRename: (sheet) => _showRenameSheetDialog(viewModel, sheet),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, SpreadsheetViewModel viewModel) {
    final colors = Theme.of(context).colorScheme;
    final actions = <Widget>[
      _ToolbarButton(
        key: const Key('spreadsheet-undo'),
        icon: Icons.undo,
        tooltip: '元に戻す (Ctrl+Z)',
        onPressed: viewModel.canUndo ? viewModel.undo : null,
      ),
      _ToolbarButton(
        key: const Key('spreadsheet-redo'),
        icon: Icons.redo,
        tooltip: 'やり直す (Ctrl+Y)',
        onPressed: viewModel.canRedo ? viewModel.redo : null,
      ),
      _ToolbarButton(
        key: const Key('spreadsheet-add-row'),
        icon: Icons.table_rows_outlined,
        tooltip: '行を追加',
        onPressed: viewModel.addRow,
      ),
      _ToolbarButton(
        key: const Key('spreadsheet-add-column'),
        icon: Icons.view_column_outlined,
        tooltip: '列を追加',
        onPressed: viewModel.addColumn,
      ),
      _ToolbarButton(
        key: const Key('spreadsheet-import-csv'),
        icon: Icons.file_upload_outlined,
        tooltip: 'CSVを新しいシートとして読み込む',
        onPressed: viewModel.isImporting
            ? null
            : () => unawaited(viewModel.importCsv()),
      ),
      _ToolbarButton(
        key: const Key('spreadsheet-export-csv'),
        icon: Icons.file_download_outlined,
        tooltip: '現在のシートをCSVへ書き出す',
        onPressed: viewModel.isExporting
            ? null
            : () => unawaited(viewModel.exportCsv()),
      ),
      FilledButton.tonalIcon(
        key: const Key('spreadsheet-save'),
        onPressed: viewModel.saveState == SaveState.saving
            ? null
            : () => unawaited(viewModel.save()),
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(_saveLabel(viewModel.saveState)),
      ),
    ];

    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleField = SizedBox(
            width: constraints.maxWidth < 680 ? double.infinity : 280,
            child: TextField(
              key: const Key('spreadsheet-title'),
              controller: _titleController,
              focusNode: _titleFocus,
              maxLines: 1,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: 'ブック名',
              ),
              onSubmitted: viewModel.updateTitle,
              onTapOutside: (_) {
                viewModel.updateTitle(_titleController.text);
                _titleFocus.unfocus();
              },
            ),
          );

          if (constraints.maxWidth < 680) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  titleField,
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: actions),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [titleField, const SizedBox(width: 12), ...actions],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormulaBar(
    BuildContext context,
    SpreadsheetViewModel viewModel,
  ) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                viewModel.selectedCell.label,
                key: const Key('spreadsheet-selected-address'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const VerticalDivider(width: 16),
            const Text(
              'fx',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('spreadsheet-formula-input'),
                controller: _formulaController,
                focusNode: _formulaFocus,
                maxLines: 1,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: '値、または =SUM(A1:A3) のような数式を入力',
                ),
                onChanged: viewModel.updateSelectedCell,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, SpreadsheetViewModel viewModel) {
    final document = viewModel.document!;
    final totalWidth = _rowHeaderWidth + document.columnCount * _cellWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  _buildColumnHeaders(context, document),
                  Expanded(
                    child: Scrollbar(
                      controller: _verticalController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        key: const Key('spreadsheet-grid'),
                        controller: _verticalController,
                        itemCount: document.rowCount,
                        itemExtent: _cellHeight,
                        itemBuilder: (context, row) {
                          return _buildRow(context, viewModel, row);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildColumnHeaders(
    BuildContext context,
    SpreadsheetDocument document,
  ) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: _cellHeight,
      child: Row(
        children: [
          _GridHeaderCell(
            width: _rowHeaderWidth,
            label: '',
            background: colors.surfaceContainerHighest,
          ),
          for (var column = 0; column < document.columnCount; column++)
            _GridHeaderCell(
              width: _cellWidth,
              label: CellAddress.columnLabel(column),
              background: colors.surfaceContainerHighest,
            ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    SpreadsheetViewModel viewModel,
    int row,
  ) {
    final colors = Theme.of(context).colorScheme;
    final document = viewModel.document!;
    return Row(
      children: [
        _GridHeaderCell(
          width: _rowHeaderWidth,
          label: '${row + 1}',
          background: colors.surfaceContainerHighest,
        ),
        for (var column = 0; column < document.columnCount; column++)
          _buildCell(context, viewModel, CellAddress(row: row, column: column)),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    SpreadsheetViewModel viewModel,
    CellAddress address,
  ) {
    final colors = Theme.of(context).colorScheme;
    final evaluation = viewModel.evaluationAt(address);
    final selected = viewModel.selectedCell == address;
    final borderColor = selected ? colors.primary : colors.outlineVariant;
    return Semantics(
      label: '${address.label}: ${evaluation.displayValue}',
      button: true,
      child: GestureDetector(
        key: Key('spreadsheet-cell-${address.label}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectCell(viewModel, address, edit: true),
        child: Container(
          width: _cellWidth,
          height: _cellHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: 0.35)
                : colors.surface,
            border: Border(
              right: BorderSide(color: borderColor, width: selected ? 2 : 1),
              bottom: BorderSide(color: borderColor, width: selected ? 2 : 1),
              left: selected
                  ? BorderSide(color: borderColor, width: 2)
                  : BorderSide.none,
              top: selected
                  ? BorderSide(color: borderColor, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            evaluation.displayValue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: evaluation.isError ? colors.error : colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  void _selectCell(
    SpreadsheetViewModel viewModel,
    CellAddress address, {
    bool edit = false,
  }) {
    viewModel.selectCell(address);
    final input = viewModel.document!.inputAt(address);
    _formulaController.value = TextEditingValue(
      text: input,
      selection: TextSelection.collapsed(offset: input.length),
    );
    if (edit) _formulaFocus.requestFocus();
  }

  Future<void> _showRenameSheetDialog(
    SpreadsheetViewModel viewModel,
    SpreadsheetSheet sheet,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _RenameSheetDialog(initialName: sheet.name),
    );
    if (result != null) viewModel.renameSheet(sheet.id, result);
  }

  void _syncControllers(SpreadsheetViewModel viewModel) {
    final document = viewModel.document;
    if (document == null) return;
    final input = document.inputAt(viewModel.selectedCell);
    if (_formulaController.text != input) {
      _formulaController.value = TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      );
    }
    if (!_titleFocus.hasFocus && _titleController.text != document.title) {
      _titleController.value = TextEditingValue(
        text: document.title,
        selection: TextSelection.collapsed(offset: document.title.length),
      );
    }
  }

  String _saveLabel(SaveState state) {
    return switch (state) {
      SaveState.saved => '保存済み',
      SaveState.saving => '保存中…',
      SaveState.modified => '未保存',
      SaveState.error => '保存失敗',
    };
  }
}

class _RenameSheetDialog extends StatefulWidget {
  const _RenameSheetDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameSheetDialog> createState() => _RenameSheetDialogState();
}

class _RenameSheetDialogState extends State<_RenameSheetDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('シート名を変更'),
      content: TextField(
        key: const Key('spreadsheet-sheet-name-input'),
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          key: const Key('spreadsheet-sheet-rename-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('変更'),
        ),
      ],
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({
    required this.width,
    required this.label,
    required this.background,
  });

  final double width;
  final String label;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _SpreadsheetPageState._cellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _SheetTabBar extends StatelessWidget {
  const _SheetTabBar({required this.viewModel, required this.onRename});

  final SpreadsheetViewModel viewModel;
  final Future<void> Function(SpreadsheetSheet sheet) onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeSheetId = viewModel.document!.activeSheetId;
    return SizedBox(
      height: 48,
      child: ColoredBox(
        color: colors.surfaceContainerLow,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                key: const Key('spreadsheet-sheet-tabs'),
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    for (final sheet in viewModel.sheets)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Material(
                          color: sheet.id == activeSheetId
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            key: Key('spreadsheet-sheet-${sheet.id}'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => viewModel.selectSheet(sheet.id),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    sheet.name,
                                    style: TextStyle(
                                      fontWeight: sheet.id == activeSheetId
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    key: Key(
                                      'spreadsheet-tab-rename-${sheet.id}',
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    iconSize: 15,
                                    tooltip: 'シート名を変更',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => unawaited(onRename(sheet)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const VerticalDivider(width: 1),
            IconButton(
              key: const Key('spreadsheet-add-sheet'),
              icon: const Icon(Icons.add),
              tooltip: 'シートを追加',
              onPressed: viewModel.addSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkbookSidebar extends StatelessWidget {
  const _WorkbookSidebar({
    required this.viewModel,
    required this.onRename,
  });

  final SpreadsheetViewModel viewModel;
  final Future<void> Function(SpreadsheetSheet sheet) onRename;

  @override
  Widget build(BuildContext context) {
    final document = viewModel.document!;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ブック', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final sheet in viewModel.sheets)
            ListTile(
              key: sheet.id == document.activeSheetId
                  ? const Key('spreadsheet-sheet-tab')
                  : Key('spreadsheet-sidebar-sheet-${sheet.id}'),
              selected: sheet.id == document.activeSheetId,
              leading: const Icon(Icons.grid_on_outlined),
              title: Text(sheet.name),
              subtitle: Text('${sheet.rowCount}行 × ${sheet.columnCount}列'),
              trailing: IconButton(
                key: Key('spreadsheet-rename-sheet-${sheet.id}'),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'シート名を変更',
                onPressed: () => unawaited(onRename(sheet)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              onTap: () => viewModel.selectSheet(sheet.id),
            ),
          OutlinedButton.icon(
            onPressed: viewModel.addSheet,
            icon: const Icon(Icons.add),
            label: const Text('シートを追加'),
          ),
          const Divider(height: 32),
          Text('使える数式', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          const Text(
            '=A1+B1\n'
            '=SUM(A1:A10)\n'
            '=AVERAGE(B1:B10)\n'
            '=MIN(A1:A10)\n'
            '=MAX(A1:A10)',
            style: TextStyle(fontFamily: 'monospace', height: 1.7),
          ),
          const SizedBox(height: 16),
          Text(
            'セルを選ぶと数式バーへ移動します。変更は端末内へ自動保存されます。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(onRetry()),
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }
}
