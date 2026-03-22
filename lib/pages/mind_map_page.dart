import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/mind_map_graph_builder_service.dart';
import 'package:my_web_app/services/note_card_service.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key});

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  final _topicController = TextEditingController();
  final _graphBuilder = MindMapGraphBuilderService();
  final _graphCaptureKey = GlobalKey();
  final Map<String, String> _nodeLabels = <String, String>{};
  final BuchheimWalkerConfiguration _algorithmConfig =
      BuchheimWalkerConfiguration();

  Graph _graph = Graph();
  Widget? _graphCanvas;
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _errorMessage;
  int _graphVersion = 0;

  String? _geminiApiKey;
  String _selectedModel = 'gemini-2.5-flash';

  static const List<String> _mindMapFallbackModels = <String>[
    'gemini-2.5-flash',
    'gemma-3n-e2b-it',
    'gemini-2.0-flash',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _algorithmConfig
      ..siblingSeparation = 100
      ..levelSeparation = 150
      ..subtreeSeparation = 150
      ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
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
              orElse: () => 'gemini-2.5-flash',
            );

    if (!mounted) {
      return;
    }

    setState(() {
      _geminiApiKey = prefs.getString('gemini_api_key');
      _selectedModel = resolvedModel;
    });
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
      if (normalized.isEmpty || seen.contains(normalized)) {
        continue;
      }
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
    if (firstBrace == -1) {
      return trimmed;
    }

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
        if (depth == 0) {
          start = i;
        }
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
    final map = decoded is Map<String, dynamic>
        ? decoded
        : (decoded is Map ? Map<String, dynamic>.from(decoded) : null);
    if (map == null) {
      throw const FormatException('マインドマップの JSON を読み取れませんでした。');
    }

    final embeddedText = _extractTextFromGeminiEnvelope(map);
    if (embeddedText != null && embeddedText.trim().isNotEmpty) {
      return _decodeMindMapJson(embeddedText);
    }

    return map;
  }

  String? _extractTextFromGeminiEnvelope(Map<String, dynamic> payload) {
    final candidates = payload['candidates'];
    if (candidates is! List) {
      return null;
    }

    for (final candidate in candidates.whereType<Map>()) {
      final content = candidate['content'];
      if (content is! Map) {
        continue;
      }
      final parts = content['parts'];
      if (parts is! List) {
        continue;
      }
      for (final part in parts.whereType<Map>()) {
        final text = part['text']?.toString();
        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      }
    }

    return null;
  }

  String _preferredOutputLanguage(String topic) {
    final trimmed = topic.trim();
    if (trimmed.isEmpty) {
      return 'Japanese';
    }
    if (RegExp(r'[\u3040-\u30FF\uFF66-\uFF9F]').hasMatch(trimmed)) {
      return 'Japanese';
    }
    if (RegExp(r'[A-Za-z]').hasMatch(trimmed)) {
      return 'English';
    }
    if (RegExp(r'[\uAC00-\uD7AF]').hasMatch(trimmed)) {
      return 'Korean';
    }
    return 'Japanese';
  }

  Future<void> _generateMindMap() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('中心トピックを入力してください。')),
      );
      return;
    }

    if (_geminiApiKey == null || _geminiApiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gemini APIキーが設定されていません。')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final aiService = AIService(null, _geminiApiKey);
      final candidates = _modelCandidatesForMindMap();
      final outputLanguage = _preferredOutputLanguage(topic);
      String? responseText;
      String? usedModel;
      Object? lastError;

      for (final model in candidates) {
        try {
          final result = await aiService.generateMindMap(
            model: model,
            topic: topic,
            outputLanguage: outputLanguage,
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
        throw const FormatException('マインドマップの JSON が空です。');
      }

      if (usedModel != null && usedModel != _selectedModel) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gemini_model_mind_map', usedModel);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        if (usedModel != null) {
          _selectedModel = usedModel;
        }
        _buildGraphFromJson(decoded);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'マインドマップの生成に失敗しました: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadMindMapAsPng() async {
    if (_graph.nodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ダウンロードするマインドマップがありません。')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
    });

    try {
      final imageBytes = await NoteCardService.captureWidgetSimple(
        _graphCaptureKey,
      );
      if (imageBytes == null) {
        throw Exception('PNG の生成に失敗しました。');
      }

      final fileName = _buildMindMapFileName(_topicController.text);
      downloadImageFile(imageBytes, fileName);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PNG をダウンロードしました: $fileName')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PNG のダウンロードに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  String _buildMindMapFileName(String topic) {
    final normalizedTopic = topic
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final safeTopic = normalizedTopic.isEmpty ? 'mind_map' : normalizedTopic;
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return 'mind_map_${safeTopic}_$timestamp.png';
  }

  void _buildGraphFromJson(Map<String, dynamic> json) {
    final result = _graphBuilder.build(json);
    _graph = result.graph;
    _graphVersion++;
    _nodeLabels
      ..clear()
      ..addAll(result.nodeLabels);
    _graphCanvas = _createGraphCanvas();
  }

  Widget _createGraphCanvas() {
    return RepaintBoundary(
      key: _graphCaptureKey,
      child: ColoredBox(
        color: const Color(0xFFF8FAFC),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GraphView.builder(
            key: ValueKey(
              'mind_map_graph_view_$_graphVersion',
            ),
            graph: _graph,
            animated: false,
            algorithm: BuchheimWalkerAlgorithm(
              _algorithmConfig,
              TreeEdgeRenderer(_algorithmConfig),
            ),
            builder: (Node node) {
              final value = node.key?.value;
              final nodeId = value?.toString();
              final text = (nodeId != null && _nodeLabels.containsKey(nodeId))
                  ? _nodeLabels[nodeId]!
                  : '(empty)';
              return _buildNode(text);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マインドマップ生成'),
        actions: [
          IconButton(
            onPressed: _isLoading || _isDownloading || _graph.nodes.isEmpty
                ? null
                : _downloadMindMapAsPng,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: 'PNGをダウンロード',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '使用モデル: $_selectedModel',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: _graphCanvas ?? _buildEmptyGraphState(),
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
