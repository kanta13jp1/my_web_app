import 'package:flutter/foundation.dart';
import 'package:my_web_app/repositories/wiki_repository.dart';

class WikiReadModel extends ChangeNotifier {
  WikiReadModel(this._repository);
  final WikiRepository _repository;
  List<Map<String, dynamic>> _pages = [];
  List<Map<String, dynamic>> get pages => List.unmodifiable(_pages);
  int? nextOffset;
  bool loading = false;
  String? error;
  String? selectedId;
  Map<String, dynamic>? selectedPage;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> get children => List.unmodifiable(_children);
  List<Map<String, dynamic>> _tableRows = [];
  List<Map<String, dynamic>> get tableRows => List.unmodifiable(_tableRows);
  bool childrenHasMore = false;
  bool tableRowsHasMore = false;
  bool detailLoading = false;
  String? detailError;
  int _listRequest = 0;
  int _detailRequest = 0;
  bool _disposed = false;
  int _retryOffset = 0;
  bool _retryReplace = true;

  Future<void> refresh() => _load(0, replace: true);

  Future<void> retry() async {
    if (loading || error == null) return;
    await _load(_retryOffset, replace: _retryReplace);
  }

  Future<void> loadMore() async {
    if (loading) return;
    final offset = nextOffset;
    if (offset != null) await _load(offset, replace: false);
  }

  Future<void> _load(int offset, {required bool replace}) async {
    if (_disposed) return;
    final request = ++_listRequest;
    _retryOffset = offset;
    _retryReplace = replace;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final batch = await _repository.list(offset: offset);
      if (_disposed || request != _listRequest) return;
      final byId = <String, Map<String, dynamic>>{
        if (!replace)
          for (final page in _pages) page['id'] as String: page,
        for (final page in batch.pages) page['id'] as String: page,
      };
      _pages = byId.values.toList();
      nextOffset = batch.nextOffset;
    } catch (_) {
      if (_disposed || request != _listRequest) return;
      error = 'Wikiページを取得できませんでした。再試行してください。';
    } finally {
      if (!_disposed && request == _listRequest) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(String id) async {
    if (_disposed) return;
    final request = ++_detailRequest;
    selectedId = id;
    selectedPage = null;
    _children = [];
    _tableRows = [];
    childrenHasMore = false;
    tableRowsHasMore = false;
    detailLoading = true;
    detailError = null;
    notifyListeners();
    try {
      final detail = await _repository.getDetail(id);
      if (_disposed || request != _detailRequest) return;
      selectedPage = detail.page;
      _children = detail.children;
      _tableRows = detail.tableRows;
      childrenHasMore = detail.childrenHasMore;
      tableRowsHasMore = detail.tableRowsHasMore;
    } catch (_) {
      if (_disposed || request != _detailRequest) return;
      detailError = 'ページ詳細を取得できませんでした。ページを選び直してください。';
    } finally {
      if (!_disposed && request == _detailRequest) {
        detailLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> createPage({
    required String title,
    required String content,
    String? parentId,
  }) async {
    await _repository.createPage(
      title: title,
      content: content,
      parentId: parentId,
    );
    if (_disposed) return;
    await refresh();
    if (!_disposed && parentId != null && selectedId == parentId) {
      await select(parentId);
    }
  }

  Future<void> addTableRow({
    required String pageId,
    required String content,
  }) async {
    await _repository.addTableRow(pageId: pageId, content: content);
    if (_disposed) return;
    await select(pageId);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
