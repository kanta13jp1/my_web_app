import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key});

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  final _topicController = TextEditingController();
  final Graph _graph = Graph();
  final BuchheimWalkerConfiguration _algorithmConfig =
      BuchheimWalkerConfiguration();

  bool _isLoading = false;
  String? _errorMessage;

  String? _geminiApiKey;
  String _selectedModel = 'gemini-2.0-flash';
  static const List<String> _mindMapFallbackModels = <String>[
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _algorithmConfig
      ..siblingSeparation = (100)
      ..levelSeparation = (150)
      ..subtreeSeparation = (150)
      ..orientation = (BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCandidates = <String?>[
      prefs.getString('gemini_model_mind_map'),
      prefs.getString('gemini_model'),
      prefs.getString('gemini_model_emergency_meeting'),
      ..._mindMapFallbackModels,
    ];

    final resolvedModel =
        savedCandidates.whereType<String>().map((v) => v.trim()).firstWhere(
              (v) => v.isNotEmpty,
              orElse: () => 'gemini-2.0-flash',
            );

    if (mounted) {
      setState(() {
        _geminiApiKey = prefs.getString('gemini_api_key');
        _selectedModel = resolvedModel;
      });
    }
  }

  List<String> _modelCandidatesForMindMap() {
    final candidates = <String>[
      _selectedModel,
      ..._mindMapFallbackModels,
    ];
    final unique = <String>[];
    final seen = <String>{};
    for (final model in candidates) {
      final normalized = model.trim();
      if (normalized.isEmpty || seen.contains(normalized)) continue;
      seen.add(normalized);
      unique.add(normalized);
    }
    return unique;
  }

  bool _isUnrecoverableModelError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('api key not valid') ||
        lower.contains('permission denied') ||
        lower.contains('unauthorized') ||
        lower.contains('401') ||
        lower.contains('403');
  }

  String _extractFirstJsonObject(String text) {
    final trimmed = text.trim();
    final firstBrace = trimmed.indexOf('{');
    if (firstBrace == -1) return trimmed;

    var inString = false;
    var escaped = false;
    var depth = 0;
    var start = firstBrace;

    for (var i = firstBrace; i < trimmed.length; i++) {
      final ch = trimmed[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
        continue;
      }
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return trimmed.substring(start, i + 1);
        }
      }
    }
    return trimmed.substring(start);
  }

  Map<String, dynamic> _decodeMindMapJson(String responseText) {
    final extracted = _extractFirstJsonObject(responseText);
    final dynamic decoded = jsonDecode(extracted);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('マインドマップJSONがオブジェクトではありません。');
  }

  Future<void> _generateMindMap() async {
    final topic = _topicController.text;
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('トピックを入力してください。')),
      );
      return;
    }

    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini APIキーが設定されていません。')),
      );
      // Here we could open the settings dialog
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final aiService = AIService(null, _geminiApiKey);
      final candidates = _modelCandidatesForMindMap();
      String? responseText;
      String? usedModel;
      Object? lastError;

      for (final model in candidates) {
        try {
          final result = await aiService.generateMindMap(
            model: model,
            topic: topic,
          );
          if (result == null || result.trim().isEmpty) {
            throw Exception('AIからの応答がありません。');
          }
          responseText = result;
          usedModel = model;
          break;
        } catch (e) {
          lastError = e;
          if (_isUnrecoverableModelError(e.toString())) {
            rethrow;
          }
        }
      }

      if (responseText == null) {
        throw Exception(lastError?.toString() ?? 'AIからの応答がありません。');
      }

      final decoded = _decodeMindMapJson(responseText);
      if (decoded.isEmpty) {
        throw const FormatException('マインドマップJSONが空です。');
      }

      if (usedModel != null && usedModel != _selectedModel) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gemini_model_mind_map', usedModel);
      }

      setState(() {
        if (usedModel != null) {
          _selectedModel = usedModel;
        }
        _buildGraphFromJson(decoded, null);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'マインドマップの生成に失敗しました: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _buildGraphFromJson(Map<String, dynamic> json, Node? parent) {
    if (parent == null) {
      _graph.nodes.clear();
      _graph.edges.clear();
    }

    for (var key in json.keys) {
      final node = Node.Id(key);
      _graph.addNode(node);

      if (parent != null) {
        _graph.addEdge(parent, node);
      }

      final rawChildren = json[key];
      final children = rawChildren is Map<String, dynamic>
          ? rawChildren
          : (rawChildren is Map
              ? Map<String, dynamic>.from(rawChildren)
              : null);
      if (children != null && children.isNotEmpty) {
        _buildGraphFromJson(children, node);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マインドマップ生成'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '中心トピック',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.psychology_alt),
              ),
              onSubmitted: (_) => _generateMindMap(),
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _graph.nodes.isEmpty
                    ? _buildEmptyGraphState()
                    : InteractiveViewer(
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(100),
                        minScale: 0.01,
                        maxScale: 5.6,
                        child: GraphView(
                          graph: _graph,
                          algorithm: BuchheimWalkerAlgorithm(
                            _algorithmConfig,
                            TreeEdgeRenderer(_algorithmConfig),
                          ),
                          builder: (Node node) {
                            final value = node.key?.value;
                            final text = value is String && value.isNotEmpty
                                ? value
                                : '(empty)';
                            return _buildNode(text);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _generateMindMap,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('生成'),
      ),
    );
  }

  Widget _buildNode(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  Widget _buildEmptyGraphState() {
    return const Center(
      child: Text(
        '中心トピックを入力して「生成」を押すとマインドマップを表示します。',
        textAlign: TextAlign.center,
      ),
    );
  }
}
