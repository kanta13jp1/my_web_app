import 'package:flutter/foundation.dart';

import '../../../../data/repositories/spreadsheet_repository.dart';
import '../../../../data/services/spreadsheet_file_gateway.dart';
import '../../../../domain/models/spreadsheet_document.dart';
import '../../../../domain/use_cases/evaluate_spreadsheet_formula_use_case.dart';
import '../../../../domain/use_cases/spreadsheet_csv_codec.dart';
import '../../../../domain/use_cases/spreadsheet_xlsx_codec.dart';
import '../../../../services/auto_save_service.dart';

enum SpreadsheetLoadStatus { initial, loading, ready, failure }

class SpreadsheetViewModel extends ChangeNotifier {
  SpreadsheetViewModel({
    required SpreadsheetRepository repository,
    required EvaluateSpreadsheetFormulaUseCase evaluateFormula,
    required SpreadsheetCsvCodec csvCodec,
    required SpreadsheetFileGateway fileGateway,
    required AutoSaveService autoSaveService,
    SpreadsheetXlsxCodec xlsxCodec = const SpreadsheetXlsxCodec(),
    DateTime Function()? clock,
  })  : _repository = repository,
        _evaluateFormula = evaluateFormula,
        _csvCodec = csvCodec,
        _xlsxCodec = xlsxCodec,
        _fileGateway = fileGateway,
        _autoSaveService = autoSaveService,
        _clock = clock ?? DateTime.now {
    _autoSaveService.addListener(_handleSaveStateChanged);
  }

  static const int _maxHistoryLength = 50;

  final SpreadsheetRepository _repository;
  final EvaluateSpreadsheetFormulaUseCase _evaluateFormula;
  final SpreadsheetCsvCodec _csvCodec;
  final SpreadsheetXlsxCodec _xlsxCodec;
  final SpreadsheetFileGateway _fileGateway;
  final AutoSaveService _autoSaveService;
  final DateTime Function() _clock;
  final Map<String, SpreadsheetFormulaResult> _evaluationCache =
      <String, SpreadsheetFormulaResult>{};
  final List<SpreadsheetDocument> _history = <SpreadsheetDocument>[];

  SpreadsheetLoadStatus _status = SpreadsheetLoadStatus.initial;
  SpreadsheetDocument? _document;
  CellAddress _selectedCell = const CellAddress(row: 0, column: 0);
  String? _errorMessage;
  String? _noticeMessage;
  bool _disposed = false;
  bool _isImporting = false;
  bool _isExporting = false;
  int _historyIndex = -1;

  SpreadsheetLoadStatus get status => _status;
  SpreadsheetDocument? get document => _document;
  CellAddress get selectedCell => _selectedCell;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  bool get isImporting => _isImporting;
  bool get isExporting => _isExporting;
  SaveState get saveState => _autoSaveService.saveState;
  DateTime? get lastSavedAt => _autoSaveService.lastSavedTime;
  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;
  List<SpreadsheetSheet> get sheets =>
      List<SpreadsheetSheet>.unmodifiable(_document?.sheets ?? const []);

  String get selectedCellInput {
    final current = _document;
    return current == null ? '' : current.inputAt(_selectedCell);
  }

  Future<void> load() async {
    _status = SpreadsheetLoadStatus.loading;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final loaded = await _repository.load();
      final initial = loaded ?? SpreadsheetDocument.blank(now: _clock());
      _document = initial;
      _history
        ..clear()
        ..add(initial);
      _historyIndex = 0;
      _selectedCell = const CellAddress(row: 0, column: 0);
      _evaluationCache.clear();
      _status = SpreadsheetLoadStatus.ready;
    } catch (_) {
      _status = SpreadsheetLoadStatus.failure;
      _errorMessage = '保存済みの表計算ファイルを読み込めませんでした。';
    }
    notifyListeners();
  }

  void selectCell(CellAddress address) {
    final current = _document;
    if (current == null ||
        address.row >= current.rowCount ||
        address.column >= current.columnCount ||
        address == _selectedCell) {
      return;
    }
    _selectedCell = address;
    notifyListeners();
  }

  void updateSelectedCell(String input) {
    final current = _document;
    if (current == null || current.inputAt(_selectedCell) == input) return;
    final activeSheet = current.activeSheet;
    final nextCells = Map<String, String>.from(activeSheet.cells);
    if (input.isEmpty) {
      nextCells.remove(_selectedCell.key);
    } else {
      nextCells[_selectedCell.key] = input;
    }
    _commit(
      current.replaceSheet(
        activeSheet.copyWith(
          cells: nextCells,
          textCells: activeSheet.textCells
              .where((key) => key != _selectedCell.key)
              .toList(),
        ),
        updatedAt: _clock(),
      ),
    );
  }

  void clearSelectedCell() => updateSelectedCell('');

  void updateTitle(String title) {
    final current = _document;
    if (current == null) return;
    final normalized = title.trim().isEmpty ? '無題のブック' : title.trim();
    if (current.title == normalized) return;
    _commit(current.copyWith(title: normalized, updatedAt: _clock()));
  }

  void addRow() {
    final current = _document;
    if (current == null) return;
    _commit(
      current.replaceSheet(
        current.activeSheet.copyWith(rowCount: current.rowCount + 1),
        updatedAt: _clock(),
      ),
    );
  }

  void addColumn() {
    final current = _document;
    if (current == null) return;
    _commit(
      current.replaceSheet(
        current.activeSheet.copyWith(columnCount: current.columnCount + 1),
        updatedAt: _clock(),
      ),
    );
  }

  void addSheet() {
    final current = _document;
    if (current == null) return;
    final id = _nextSheetId(current);
    final sheet = SpreadsheetSheet.blank(
      id: id,
      name: 'シート${current.sheets.length + 1}',
    );
    _selectedCell = const CellAddress(row: 0, column: 0);
    _commit(
      current.copyWith(
        sheets: <SpreadsheetSheet>[...current.sheets, sheet],
        activeSheetId: id,
        updatedAt: _clock(),
      ),
    );
  }

  void selectSheet(String sheetId) {
    final current = _document;
    if (current == null ||
        current.activeSheetId == sheetId ||
        _sheetById(current, sheetId) == null) {
      return;
    }
    _selectedCell = const CellAddress(row: 0, column: 0);
    _commit(current.copyWith(activeSheetId: sheetId, updatedAt: _clock()));
  }

  void renameSheet(String sheetId, String name) {
    final current = _document;
    if (current == null) return;
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final target = _sheetById(current, sheetId);
    if (target == null || target.name == normalized) return;
    _commit(
      current.replaceSheet(
        target.copyWith(name: normalized),
        updatedAt: _clock(),
      ),
    );
  }

  Future<bool> importCsv() async {
    if (_isImporting || _isExporting) return false;
    final current = _document;
    if (current == null) return false;
    _isImporting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final picked = await _fileGateway.pickCsv();
      if (picked == null) return false;
      final id = _nextSheetId(current);
      final imported = _csvCodec.decode(
        bytes: picked.bytes,
        sheetId: id,
        sheetName: _sheetNameFromFile(picked.name, current.sheets.length + 1),
      );
      _selectedCell = const CellAddress(row: 0, column: 0);
      _commit(
        current.copyWith(
          sheets: <SpreadsheetSheet>[...current.sheets, imported],
          activeSheetId: id,
          updatedAt: _clock(),
        ),
      );
      _noticeMessage = '${picked.name} を新しいシートとして読み込みました。';
      return true;
    } on FormatException catch (error) {
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      _errorMessage = 'CSVファイルを読み込めませんでした。';
      return false;
    } finally {
      _isImporting = false;
      notifyListeners();
    }
  }

  Future<bool> exportCsv() async {
    if (_isExporting || _isImporting) return false;
    final current = _document;
    if (current == null) return false;
    _isExporting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final saved = await _fileGateway.saveCsv(
        suggestedName: _safeFileName(
          '${current.title}-${current.activeSheet.name}.csv',
        ),
        bytes: _csvCodec.encode(current.activeSheet),
      );
      if (saved) _noticeMessage = 'CSVを書き出しました。';
      return saved;
    } catch (_) {
      _errorMessage = 'CSVファイルを書き出せませんでした。';
      return false;
    } finally {
      _isExporting = false;
      notifyListeners();
    }
  }

  Future<bool> importXlsx() async {
    if (_disposed || _isImporting || _isExporting || _document == null) {
      return false;
    }
    _isImporting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final picked = await _fileGateway.pickXlsx();
      if (_disposed || picked == null) return false;
      final imported = _xlsxCodec.decode(picked.bytes);
      final current = _document!;
      if (current.sheets.length + imported.length > 20) {
        throw const FormatException('追加後のシート数は20枚までです。');
      }
      final names = current.sheets.map((s) => s.name.toLowerCase()).toSet();
      if (imported.any((s) => names.contains(s.name.toLowerCase()))) {
        throw const FormatException('同名シートがあります。既存シートの名前を変更してから読み込んでください。');
      }
      final sheets = <SpreadsheetSheet>[...current.sheets];
      for (final sheet in imported) {
        final id = _nextSheetId(current.copyWith(sheets: sheets));
        sheets.add(
          SpreadsheetSheet(
            id: id,
            name: sheet.name,
            rowCount: sheet.rowCount,
            columnCount: sheet.columnCount,
            cells: sheet.cells,
            textCells: sheet.textCells,
          ),
        );
      }
      _selectedCell = const CellAddress(row: 0, column: 0);
      _commit(
        current.copyWith(
          sheets: sheets,
          activeSheetId: sheets[current.sheets.length].id,
          updatedAt: _clock(),
        ),
      );
      _noticeMessage =
          '${picked.name} の${imported.length}シートを追加しました。${SpreadsheetXlsxCodec.compatibilityNotice}';
      return true;
    } on FormatException catch (error) {
      if (_disposed) return false;
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      if (_disposed) return false;
      _errorMessage = 'XLSXファイルを読み込めませんでした。';
      return false;
    } finally {
      _isImporting = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> exportXlsx() async {
    if (_disposed || _isImporting || _isExporting || _document == null) {
      return false;
    }
    _isExporting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final current = _document!;
      final saved = await _fileGateway.saveXlsx(
        suggestedName: _safeFileName('${current.title}-export.xlsx'),
        bytes: _xlsxCodec.encode(current),
      );
      if (_disposed) return false;
      if (saved) {
        _noticeMessage =
            'XLSXを書き出しました。${SpreadsheetXlsxCodec.compatibilityNotice}';
      }
      return saved;
    } on FormatException catch (error) {
      if (_disposed) return false;
      _errorMessage = error.message.toString();
      return false;
    } catch (_) {
      if (_disposed) return false;
      _errorMessage = 'XLSXファイルを書き出せませんでした。';
      return false;
    } finally {
      _isExporting = false;
      if (!_disposed) notifyListeners();
    }
  }

  void clearMessages() {
    if (_noticeMessage == null && _errorMessage == null) return;
    _noticeMessage = null;
    _errorMessage = null;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    _historyIndex--;
    _restoreHistoryEntry();
  }

  void redo() {
    if (!canRedo) return;
    _historyIndex++;
    _restoreHistoryEntry();
  }

  SpreadsheetFormulaResult evaluationAt(CellAddress address) {
    final current = _document;
    if (current == null) {
      return const SpreadsheetFormulaResult(displayValue: '');
    }
    return _evaluationCache.putIfAbsent(
      address.key,
      () => _evaluateFormula(current, address),
    );
  }

  Future<bool> save() async {
    final current = _document;
    if (current == null) return false;
    _errorMessage = null;
    notifyListeners();
    try {
      await _autoSaveService.saveImmediately(() => _repository.save(current));
      return true;
    } catch (_) {
      _errorMessage = '表計算ファイルを保存できませんでした。';
      notifyListeners();
      return false;
    }
  }

  void _commit(SpreadsheetDocument next) {
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(next);
    if (_history.length > _maxHistoryLength) {
      _history.removeAt(0);
    } else {
      _historyIndex++;
    }
    _document = next;
    _evaluationCache.clear();
    _errorMessage = null;
    _noticeMessage = null;
    _triggerAutoSave();
    notifyListeners();
  }

  void _restoreHistoryEntry() {
    _document = _history[_historyIndex];
    _evaluationCache.clear();
    _errorMessage = null;
    _noticeMessage = null;
    _triggerAutoSave();
    notifyListeners();
  }

  void _triggerAutoSave() {
    _autoSaveService.triggerAutoSave(() {
      final current = _document;
      return current == null ? Future<void>.value() : _repository.save(current);
    });
  }

  void _handleSaveStateChanged() => notifyListeners();

  SpreadsheetSheet? _sheetById(SpreadsheetDocument document, String sheetId) {
    for (final sheet in document.sheets) {
      if (sheet.id == sheetId) return sheet;
    }
    return null;
  }

  String _nextSheetId(SpreadsheetDocument document) {
    var suffix = document.sheets.length + 1;
    while (document.sheets.any((sheet) => sheet.id == 'sheet-$suffix')) {
      suffix++;
    }
    return 'sheet-$suffix';
  }

  String _sheetNameFromFile(String fileName, int fallbackNumber) {
    final withoutExtension = fileName.replaceFirst(
      RegExp(r'\.csv$', caseSensitive: false),
      '',
    );
    final normalized = withoutExtension.trim();
    return normalized.isEmpty ? 'シート$fallbackNumber' : normalized;
  }

  String _safeFileName(String value) {
    final safe = value.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
    return safe.isEmpty ? 'spreadsheet.csv' : safe;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _autoSaveService.removeListener(_handleSaveStateChanged);
    _autoSaveService.dispose();
    super.dispose();
  }
}
