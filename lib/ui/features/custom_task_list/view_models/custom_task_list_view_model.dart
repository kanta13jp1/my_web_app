import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/custom_task_list_repository.dart';
import '../../../../data/services/custom_task_list_ai_service.dart';
import '../../../../domain/models/custom_task_list.dart';

class CustomTaskListViewModel extends ChangeNotifier {
  final CustomTaskListRepository _repository;

  CustomTaskListViewModel({required CustomTaskListRepository repository})
      : _repository = repository;

  CustomTaskListSnapshot? _snapshot;
  bool _isLoading = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get goal => _snapshot?.goal ?? '';
  String get situation => _snapshot?.situation ?? '';
  String get source => _snapshot?.source ?? '';
  int get completedCount =>
      _snapshot?.items.where((item) => item.isCompleted).length ?? 0;
  UnmodifiableListView<CustomTaskItem> get items =>
      UnmodifiableListView(_snapshot?.items ?? const <CustomTaskItem>[]);

  Future<void> restore() async {
    try {
      _snapshot = await _repository.load();
      _errorMessage = null;
    } catch (_) {
      _errorMessage = '保存済みのタスクリストを読み込めませんでした。';
    }
    _notifyListeners();
  }

  Future<bool> generate({
    required String goal,
    required String situation,
  }) async {
    if (goal.trim().isEmpty && situation.trim().isEmpty) {
      _errorMessage = '目標または現状を入力してください。';
      _notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _notifyListeners();
    try {
      _snapshot = await _repository.generate(goal: goal, situation: situation);
      return true;
    } on CustomTaskListGenerationException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'タスクリストを生成できませんでした。時間をおいて再試行してください。';
      return false;
    } finally {
      _isLoading = false;
      _notifyListeners();
    }
  }

  Future<bool> editTask(String id, String title) async {
    final normalizedTitle = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalizedTitle.isEmpty) {
      _errorMessage = 'タスク名を入力してください。';
      _notifyListeners();
      return false;
    }
    if (normalizedTitle.length > 120) {
      _errorMessage = 'タスク名は120文字以内にしてください。';
      _notifyListeners();
      return false;
    }
    return _replaceItems(
      items
          .map(
            (item) =>
                item.id == id ? item.copyWith(title: normalizedTitle) : item,
          )
          .toList(growable: false),
    );
  }

  Future<bool> deleteTask(String id) async {
    return _replaceItems(
      items.where((item) => item.id != id).toList(growable: false),
    );
  }

  Future<bool> toggleTask(String id) async {
    return _replaceItems(
      items
          .map(
            (item) => item.id == id
                ? item.copyWith(isCompleted: !item.isCompleted)
                : item,
          )
          .toList(growable: false),
    );
  }

  Future<bool> _replaceItems(List<CustomTaskItem> nextItems) async {
    final current = _snapshot;
    if (current == null) return false;
    final next = current.copyWith(items: nextItems);
    _snapshot = next;
    _errorMessage = null;
    _notifyListeners();
    try {
      await _repository.save(next);
      return true;
    } catch (_) {
      if (identical(_snapshot, next)) {
        _snapshot = current;
      }
      _errorMessage = '変更を端末に保存できませんでした。';
      _notifyListeners();
      return false;
    }
  }

  void _notifyListeners() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
