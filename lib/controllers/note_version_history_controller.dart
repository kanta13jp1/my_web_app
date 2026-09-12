import 'package:flutter/foundation.dart';

import '../services/note_version_history_service.dart';

class NoteVersionHistoryController extends ChangeNotifier {
  NoteVersionHistoryController({
    required this.repository,
    required this.noteId,
  });

  final NoteVersionHistoryRepository repository;
  final String noteId;
  final List<NoteVersionSummary> _items = [];
  List<NoteVersionSummary> get items => List.unmodifiable(_items);
  bool loading = false;
  bool hasMore = true;
  String? pageError;
  NoteVersionSummary? selected;
  NoteVersionDetail? detail;
  bool detailLoading = false;
  String? detailError;
  bool _disposed = false;
  int _detailRequest = 0;
  NoteVersionCursor? _cursor;

  Future<void> loadMore() async {
    if (_disposed || loading || !hasMore) return;
    loading = true;
    pageError = null;
    notifyListeners();
    try {
      final page = await repository.loadPage(noteId, before: _cursor);
      if (_disposed) return;
      if (page.hasMore &&
          (page.items.isEmpty || page.items.last.id == _cursor?.id)) {
        throw StateError('History cursor did not advance');
      }
      final known = _items.map((item) => item.id).toSet();
      _items.addAll(page.items.where((item) => known.add(item.id)));
      if (page.items.isNotEmpty) _cursor = page.items.last.cursor;
      hasMore = page.hasMore;
    } catch (_) {
      if (!_disposed) pageError = '履歴を取得できませんでした。再試行してください。';
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(NoteVersionSummary summary) async {
    if (_disposed) return;
    final request = ++_detailRequest;
    selected = summary;
    detail = null;
    detailError = null;
    detailLoading = true;
    notifyListeners();
    try {
      final loaded = await repository.loadDetail(noteId, summary.id);
      if (_disposed || request != _detailRequest) return;
      if (loaded.summary.id != summary.id) {
        throw StateError('History identifier mismatch');
      }
      detail = loaded;
    } catch (_) {
      if (!_disposed && request == _detailRequest) {
        detailError = '履歴の本文・添付情報を取得できませんでした。';
      }
    } finally {
      if (!_disposed && request == _detailRequest) {
        detailLoading = false;
        notifyListeners();
      }
    }
  }

  void showList() {
    ++_detailRequest;
    selected = null;
    detail = null;
    detailError = null;
    detailLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_detailRequest;
    super.dispose();
  }
}
