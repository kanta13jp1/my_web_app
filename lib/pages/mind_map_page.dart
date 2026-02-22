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
  String _selectedModel = 'gemini-1.5-flash';

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
    if (mounted) {
      setState(() {
        _geminiApiKey = prefs.getString('gemini_api_key');
        _selectedModel =
            prefs.getString('gemini_model_mind_map') ?? 'gemini-1.5-flash';
      });
    }
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
      final responseText = await aiService.generateMindMap(
        model: _selectedModel,
        topic: topic,
      );

      if (responseText == null) {
        throw Exception('AIからの応答がありません。');
      }

      var responseJson = responseText.trim();
      final jsonStartIndex = responseJson.indexOf('{');
      final jsonEndIndex = responseJson.lastIndexOf('}');
      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        responseJson = responseJson.substring(jsonStartIndex, jsonEndIndex + 1);
      }

      final decoded = jsonDecode(responseJson) as Map<String, dynamic>;

      setState(() {
        _buildGraphFromJson(decoded, null);
      });
    } catch (e) {
      _errorMessage = 'マインドマップの生成に失敗しました: ${e.toString()}';
    } finally {
      setState(() => _isLoading = false);
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

      final children = json[key] as Map<String, dynamic>;
      if (children.isNotEmpty) {
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
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Colors.red),),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    constrained: false,
                    boundaryMargin: const EdgeInsets.all(100),
                    minScale: 0.01,
                    maxScale: 5.6,
                    child: GraphView(
                      graph: _graph,
                      algorithm: BuchheimWalkerAlgorithm(
                          _algorithmConfig, TreeEdgeRenderer(_algorithmConfig),),
                      builder: (Node node) {
                        final a = node.key!.value as String?;
                        return _buildNode(a!);
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
}
