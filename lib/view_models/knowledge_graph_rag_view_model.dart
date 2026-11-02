import 'package:flutter/foundation.dart';

import '../models/knowledge_graph_rag.dart';
import '../services/knowledge_graph_rag_service.dart';

class KnowledgeGraphRagViewModel extends ChangeNotifier {
  KnowledgeGraphRagViewModel({required KnowledgeGraphRagGateway gateway})
      : _gateway = gateway;

  static const List<String> availableSources = <String>[
    'issues',
    'wbs',
    'docs',
    'memory',
    'notebooklm',
  ];

  final KnowledgeGraphRagGateway _gateway;
  final Set<String> _selectedSources = <String>{...availableSources};

  KnowledgeGraphRagAnswer? _answer;
  String? _errorMessage;
  bool _requiresLogin = false;
  bool _isLoading = false;
  bool _useLlm = true;
  int _requestSequence = 0;
  bool _disposed = false;

  KnowledgeGraphRagAnswer? get answer => _answer;
  String? get errorMessage => _errorMessage;
  bool get requiresLogin => _requiresLogin;
  bool get isLoading => _isLoading;
  bool get useLlm => _useLlm;
  Set<String> get selectedSources => Set<String>.unmodifiable(_selectedSources);

  void setSourceSelected(String source, bool selected) {
    if (!availableSources.contains(source)) return;
    if (selected) {
      _selectedSources.add(source);
    } else if (_selectedSources.length > 1) {
      _selectedSources.remove(source);
    } else {
      _errorMessage = '情報源を1つ以上選択してください。';
    }
    _notifyListeners();
  }

  void setUseLlm(bool value) {
    if (_useLlm == value) return;
    _useLlm = value;
    _notifyListeners();
  }

  Future<bool> search(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty || _isLoading) return false;

    final sequence = ++_requestSequence;
    _isLoading = true;
    _errorMessage = null;
    _requiresLogin = false;
    _answer = null;
    _notifyListeners();

    try {
      final answer = await _gateway.query(
        query: normalizedQuery,
        sources: selectedSources,
        useLlm: _useLlm,
      );
      if (_disposed || sequence != _requestSequence) return false;
      _answer = answer;
      return true;
    } on KnowledgeGraphRagException catch (error) {
      if (_disposed || sequence != _requestSequence) return false;
      _requiresLogin = error.requiresLogin;
      _errorMessage = _friendlyMessage(error.message);
      return false;
    } catch (error) {
      if (_disposed || sequence != _requestSequence) return false;
      _errorMessage = _friendlyMessage(error.toString());
      return false;
    } finally {
      if (!_disposed && sequence == _requestSequence) {
        _isLoading = false;
        _notifyListeners();
      }
    }
  }

  String _friendlyMessage(String rawMessage) {
    if (_requiresLogin) return 'この機能を使うにはログインしてください。';
    if (RegExp(r'rate.?limit|429', caseSensitive: false).hasMatch(rawMessage)) {
      return '検索が混み合っています。1分ほど待ってから再度お試しください。';
    }
    if (rawMessage.contains('1,000')) return rawMessage;
    return 'AI回答を生成できませんでした。時間をおいて再度お試しください。';
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestSequence++;
    super.dispose();
  }
}
