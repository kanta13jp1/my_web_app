import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_web_app/services/ai_service.dart';
import 'package:my_web_app/services/note_card_service.dart';
import 'package:my_web_app/utils/web_image_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MindMapPage extends StatefulWidget {
  const MindMapPage({super.key});

  @override
  State<MindMapPage> createState() => _MindMapPageState();
}

class _MindMapPageState extends State<MindMapPage> {
  static const List<String> _mindMapFallbackModels = <String>[
    'gemini-2.5-flash',
    'gemma-3n-e2b-it',
    'gemini-2.5-pro',
  ];
  static const double _canvasPadding = 32;
  static const double _horizontalGap = 32;
  static const double _verticalGap = 88;
  static const double _minNodeWidth = 120;
  static const double _maxNodeWidth = 220;
  static const double _minNodeHeight = 56;

  final _topicController = TextEditingController();
  final _graphCaptureKey = GlobalKey();

  _MindMapLayoutResult? _layoutResult;
  bool _isLoading = false;
  bool _isDownloading = false;
  String? _errorMessage;
  String? _geminiApiKey;
  String _selectedModel = 'gemini-2.5-flash';

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
            throw Exception('AI からの応答がありません。');
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
        throw Exception(lastError?.toString() ?? 'AI からの応答がありません。');
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
        _layoutResult = _buildLayoutFromJson(decoded, topic);
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
    if (_layoutResult == null || _layoutResult!.nodes.isEmpty) {
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
          backgroundColor: const Color(0xFFE53935),
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

  _MindMapLayoutResult _buildLayoutFromJson(
    Map<String, dynamic> json,
    String topic,
  ) {
    final root = _buildTree(json, topic);
    final nodeSizes = <String, Size>{};
    final subtreeWidths = <String, double>{};

    Size measureNode(_MindMapTreeNode node) {
      return nodeSizes.putIfAbsent(node.id, () => _measureNode(node.label));
    }

    double computeSubtreeWidth(_MindMapTreeNode node) {
      final nodeWidth = measureNode(node).width;
      if (node.children.isEmpty) {
        subtreeWidths[node.id] = nodeWidth;
        return nodeWidth;
      }

      final childrenWidth = node.children
              .map(computeSubtreeWidth)
              .fold<double>(0, (sum, width) => sum + width) +
          (_horizontalGap * math.max(0, node.children.length - 1));
      final subtreeWidth = math.max(nodeWidth, childrenWidth);
      subtreeWidths[node.id] = subtreeWidth;
      return subtreeWidth;
    }

    int computeMaxDepth(_MindMapTreeNode node) {
      if (node.children.isEmpty) {
        return 0;
      }
      return 1 +
          node.children
              .map(computeMaxDepth)
              .fold<int>(0, (maxDepth, depth) => math.max(maxDepth, depth));
    }

    final rootWidth = computeSubtreeWidth(root);
    final maxDepth = computeMaxDepth(root);
    final maxNodeHeight = nodeSizes.values.fold<double>(
      _minNodeHeight,
      (maxHeight, size) => math.max(maxHeight, size.height),
    );
    final levelStride = maxNodeHeight + _verticalGap;

    final positionedNodes = <_MindMapLayoutNode>[];
    final edges = <_MindMapLayoutEdge>[];
    final rectsById = <String, Rect>{};

    void place(_MindMapTreeNode node, double left, int depth) {
      final nodeSize = nodeSizes[node.id]!;
      final subtreeWidth = subtreeWidths[node.id]!;
      final centerX = _canvasPadding + left + (subtreeWidth / 2);
      final top = _canvasPadding + (depth * levelStride);
      final rect = Rect.fromLTWH(
        centerX - (nodeSize.width / 2),
        top,
        nodeSize.width,
        nodeSize.height,
      );
      rectsById[node.id] = rect;
      positionedNodes.add(
        _MindMapLayoutNode(
          id: node.id,
          label: node.label,
          rect: rect,
        ),
      );

      if (node.children.isEmpty) {
        return;
      }

      final childrenTotalWidth = node.children
              .map((child) => subtreeWidths[child.id]!)
              .fold<double>(0, (sum, width) => sum + width) +
          (_horizontalGap * math.max(0, node.children.length - 1));
      var childLeft = left + ((subtreeWidth - childrenTotalWidth) / 2);

      for (final child in node.children) {
        place(child, childLeft, depth + 1);
        final childRect = rectsById[child.id]!;
        edges.add(
          _MindMapLayoutEdge(
            start: Offset(rect.center.dx, rect.bottom),
            end: Offset(childRect.center.dx, childRect.top),
          ),
        );
        childLeft += subtreeWidths[child.id]! + _horizontalGap;
      }
    }

    place(root, 0, 0);

    final canvasWidth = math.max(640.0, rootWidth + (_canvasPadding * 2));
    final canvasHeight = math.max(
      420.0,
      (_canvasPadding * 2) +
          ((maxDepth + 1) * maxNodeHeight) +
          (maxDepth * _verticalGap),
    );

    return _MindMapLayoutResult(
      nodes: positionedNodes,
      edges: edges,
      size: Size(canvasWidth, canvasHeight),
    );
  }

  _MindMapTreeNode _buildTree(Map<String, dynamic> json, String topic) {
    var nextNodeIndex = 0;

    _MindMapTreeNode buildBranch(String label, dynamic rawChildren) {
      final childrenMap = rawChildren is Map<String, dynamic>
          ? rawChildren
          : (rawChildren is Map
              ? Map<String, dynamic>.from(rawChildren)
              : null);
      final children = childrenMap == null
          ? const <_MindMapTreeNode>[]
          : childrenMap.entries
              .map((entry) => buildBranch(entry.key, entry.value))
              .toList(growable: false);
      final normalizedLabel = label.trim().isEmpty ? '(empty)' : label.trim();
      return _MindMapTreeNode(
        id: 'mind_map_node_${nextNodeIndex++}',
        label: normalizedLabel,
        children: children,
      );
    }

    final roots = json.entries
        .map((entry) => buildBranch(entry.key, entry.value))
        .toList(growable: false);

    if (roots.isEmpty) {
      return _MindMapTreeNode(
        id: 'mind_map_node_${nextNodeIndex++}',
        label: topic.trim().isEmpty ? 'マインドマップ' : topic.trim(),
        children: const <_MindMapTreeNode>[],
      );
    }

    if (roots.length == 1) {
      return roots.first;
    }

    return _MindMapTreeNode(
      id: 'mind_map_node_${nextNodeIndex++}',
      label: topic.trim().isEmpty ? 'マインドマップ' : topic.trim(),
      children: roots,
    );
  }

  Size _measureNode(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '...',
    )..layout(maxWidth: _maxNodeWidth - 32);

    final width = (painter.width + 32).clamp(_minNodeWidth, _maxNodeWidth);
    final height = math.max(_minNodeHeight, painter.height + 28);
    return Size(width.toDouble(), height);
  }

  @override
  Widget build(BuildContext context) {
    final hasMindMap = _layoutResult != null && _layoutResult!.nodes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('マインドマップ生成'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/mindmap'),
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: '保存済みマップ',
          ),
          IconButton(
            onPressed: _isLoading || _isDownloading || !hasMindMap
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
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
                style: const TextStyle(
                  color: Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasMindMap
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: _buildMindMapCanvas(_layoutResult!),
                      )
                    : _buildEmptyGraphState(),
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

  Widget _buildMindMapCanvas(_MindMapLayoutResult layout) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minCanvasWidth = math.max(0.0, constraints.maxWidth - 32);

        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(200),
            minScale: 0.2,
            maxScale: 3.0,
            child: RepaintBoundary(
              key: _graphCaptureKey,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minCanvasWidth,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MindMapEdgePainter(layout.edges),
                          ),
                        ),
                        ...layout.nodes.map(
                          (node) => Positioned(
                            left: node.rect.left,
                            top: node.rect.top,
                            width: node.rect.width,
                            height: node.rect.height,
                            child: _buildNode(node.label),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(String text) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFBBDEFB),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB0B0B0).withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEmptyGraphState() {
    return const Center(
      child: Text(
        '中心トピックを入力して、「生成」を押すとマインドマップを表示します。',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _MindMapTreeNode {
  const _MindMapTreeNode({
    required this.id,
    required this.label,
    required this.children,
  });

  final String id;
  final String label;
  final List<_MindMapTreeNode> children;
}

class _MindMapLayoutNode {
  const _MindMapLayoutNode({
    required this.id,
    required this.label,
    required this.rect,
  });

  final String id;
  final String label;
  final Rect rect;
}

class _MindMapLayoutEdge {
  const _MindMapLayoutEdge({
    required this.start,
    required this.end,
  });

  final Offset start;
  final Offset end;
}

class _MindMapLayoutResult {
  const _MindMapLayoutResult({
    required this.nodes,
    required this.edges,
    required this.size,
  });

  final List<_MindMapLayoutNode> nodes;
  final List<_MindMapLayoutEdge> edges;
  final Size size;
}

class _MindMapEdgePainter extends CustomPainter {
  const _MindMapEdgePainter(this.edges);

  final List<_MindMapLayoutEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final midY = (edge.start.dy + edge.end.dy) / 2;
      final path = Path()
        ..moveTo(edge.start.dx, edge.start.dy)
        ..cubicTo(
          edge.start.dx,
          midY,
          edge.end.dx,
          midY,
          edge.end.dx,
          edge.end.dy,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MindMapEdgePainter oldDelegate) {
    return oldDelegate.edges != edges;
  }
}
