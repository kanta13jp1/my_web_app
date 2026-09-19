import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmbeddingLabPage extends StatefulWidget {
  const EmbeddingLabPage({super.key});

  @override
  State<EmbeddingLabPage> createState() => _EmbeddingLabPageState();
}

class _EmbeddingLabPageState extends State<EmbeddingLabPage> {
  // Single embedding mode
  final TextEditingController _inputController = TextEditingController();
  String _singleResult = '';

  // Similarity mode
  final TextEditingController _textAController = TextEditingController();
  final TextEditingController _textBController = TextEditingController();
  double? _similarityScore;
  String _similarityLabel = '';

  bool _isLoading = false;
  int _tabIndex = 0; // 0=single, 1=similarity

  @override
  void dispose() {
    _inputController.dispose();
    _textAController.dispose();
    _textBController.dispose();
    super.dispose();
  }

  Future<List<double>> _fetchEmbedding(String text) async {
    final response = await Supabase.instance.client.functions.invoke(
      'ai-hub',
      body: {'action': 'provider.embed', 'text': text},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final embeddingData = data['embedding'];
    if (embeddingData is Map && embeddingData['values'] is List) {
      return (embeddingData['values'] as List<dynamic>)
          .map((v) => (v as num).toDouble())
          .toList();
    }
    throw const FormatException('Embedding response does not contain values.');
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty || a.length != b.length) return 0.0;
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  String _similarityDescription(double score) {
    if (score >= 0.95) return '非常に似ている (Almost identical)';
    if (score >= 0.85) return '高い類似度 (Highly similar)';
    if (score >= 0.70) return '関連あり (Related)';
    if (score >= 0.50) return 'やや関連 (Somewhat related)';
    return '異なるトピック (Different topics)';
  }

  Color _similarityColor(double score) {
    if (score >= 0.85) return Colors.green;
    if (score >= 0.70) return Colors.lightGreen;
    if (score >= 0.50) return const Color(0xFFFF6B35);
    return Colors.red;
  }

  Future<void> _generateSingleEmbedding() async {
    if (_inputController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _singleResult = '';
    });

    try {
      final vector = await _fetchEmbedding(_inputController.text.trim());
      if (mounted) {
        setState(() {
          _singleResult = 'モデル: gemini-embedding-001\n'
              '次元数: ${vector.length}\n\n'
              '--- 先頭10件 ---\n[${vector.take(10).map((v) => v.toStringAsFixed(6)).join(', ')}...]\n\n'
              '✅ Embedding 生成成功';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _singleResult = 'エラー: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _compareSimilarity() async {
    final textA = _textAController.text.trim();
    final textB = _textBController.text.trim();
    if (textA.isEmpty || textB.isEmpty) return;

    setState(() {
      _isLoading = true;
      _similarityScore = null;
    });

    try {
      final results = await Future.wait([
        _fetchEmbedding(textA),
        _fetchEmbedding(textB),
      ]);
      final score = _cosineSimilarity(results[0], results[1]);
      if (mounted) {
        setState(() {
          _similarityScore = score;
          _similarityLabel = _similarityDescription(score);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Embedding Lab'),
        backgroundColor: const Color(0xFF009688),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabIndex = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabIndex == 0
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: const Text(
                      'テキスト埋め込み',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _tabIndex = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tabIndex == 1
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: const Text(
                      '類似度比較',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _tabIndex == 0 ? _buildSingleTab() : _buildSimilarityTab(),
    );
  }

  Widget _buildSingleTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            color: Color(0xFF00796B),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.science, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'gemini-embedding-001 — 768次元ベクトルを生成',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(
              labelText: 'テキストを入力',
              border: OutlineInputBorder(),
              hintText: '例: 人工知能の未来について',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : _generateSingleEmbedding,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.memory),
            label: const Text('Embedding を生成'),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'APIキーはサーバー側のSecretで管理されます。',
              style: TextStyle(fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _singleResult.isEmpty ? 'ここに結果が表示されます' : _singleResult,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: _singleResult.isEmpty
                        ? const Color(0xFF9CA3AF)
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarityTab() {
    final score = _similarityScore;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            color: Color(0xFF303F9F),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.compare_arrows, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '2つのテキストのコサイン類似度を計算します',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _textAController,
            decoration: const InputDecoration(
              labelText: 'テキスト A',
              border: OutlineInputBorder(),
              hintText: '例: 機械学習はデータからパターンを学ぶ技術です',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textBController,
            decoration: const InputDecoration(
              labelText: 'テキスト B',
              border: OutlineInputBorder(),
              hintText: '例: ディープラーニングはニューラルネットワークを使います',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _compareSimilarity,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.compare),
            label: const Text('類似度を計算'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3D5AFE),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'APIキーはサーバー側のSecretで管理されます。',
              style: TextStyle(fontSize: 12, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          if (score != null) ...[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      '類似度スコア',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      score.toStringAsFixed(4),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _similarityColor(score),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((score + 1) / 2).clamp(0.0, 1.0),
                        minHeight: 12,
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceContainerHigh,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _similarityColor(score),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _similarityColor(score).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _similarityColor(score).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _similarityLabel,
                        style: TextStyle(
                          color: _similarityColor(score),
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      '1.0 = 完全一致 / 0.0 = 無相関 / -1.0 = 逆の意味',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!_isLoading)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 48,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '2つのテキストを入力して\n類似度を計算しましょう',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
