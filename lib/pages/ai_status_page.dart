import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class AiStatusPage extends StatefulWidget {
  const AiStatusPage({super.key});

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  List<dynamic> _models = [];
  bool _isLoading = true;
  String? _error;

  // テスト結果の状態管理
  Map<String, String> _testResults = {}; // 'testing', 'success', 'error'
  Map<String, String> _testErrors = {}; // エラー詳細メッセージ
  Map<String, Map<String, dynamic>> _visionScores = {}; // Visionベンチマーク詳細

  @override
  void initState() {
    super.initState();
    _fetchAvailableModels();
  }

  // モデル一覧の取得
  Future<void> _fetchAvailableModels() async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      );

      if (response.status != 200)
        throw Exception('API Error: ${response.status}');

      final data =
          response.data is String ? jsonDecode(response.data) : response.data;

      setState(() {
        _models = List.from(data['models'] ?? []);
        _models
            .sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // 全モデルの順次テスト実行
  Future<void> _runAllTests() async {
    for (var model in _models) {
      final String modelName = model['model'];
      _testSingleModel(modelName);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // 単体モデルのテスト実行 (Visionベンチマーク対応)
  Future<void> _testSingleModel(String modelName) async {
    setState(() {
      _testResults[modelName] = 'testing';
      _testErrors.remove(modelName);
      _visionScores.remove(modelName);
    });

    try {
      final res = await supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'test_model', 'model': modelName},
      );

      setState(() {
        if (res.status == 200) {
          _testResults[modelName] = 'success';
          // ベンチマーク結果（スコアとレイテンシ）があれば保存
          final benchmark = res.data['benchmark'];
          if (benchmark != null) {
            _visionScores[modelName] = Map<String, dynamic>.from(benchmark);
          }
        } else {
          _testResults[modelName] = 'error';
          _testErrors[modelName] =
              res.data['error']?.toString() ?? 'Unknown Error';
        }
      });
    } catch (e) {
      setState(() {
        _testResults[modelName] = 'error';
        _testErrors[modelName] = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color navy = const Color(0xFF0F172A);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('AI稼働モニター'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _runAllTests,
            tooltip: '全モデルをテスト',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAvailableModels,
            tooltip: '一覧を更新',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('エラー: $_error',
                        style: const TextStyle(color: Colors.red)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    final provider = model['provider'] as String;
                    final score = model['score'] as int;
                    final modelName = model['model'] as String;
                    final status = _testResults[modelName];

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _testSingleModel(modelName),
                        leading: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _buildProviderBadge(provider),
                            if (status != null)
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: status == 'testing'
                                      ? Colors.orange
                                      : (status == 'success'
                                          ? Colors.green
                                          : Colors.red),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                          ],
                        ),
                        title: Text(modelName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Provider: ${provider.toUpperCase()}'),
                            // Visionベンチマークバッジの表示
                            if (_visionScores.containsKey(modelName))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    _buildScoreBadge(
                                        "画像認識",
                                        "${_visionScores[modelName]!['score']}%",
                                        Colors.purple),
                                    _buildScoreBadge(
                                        "応答速度",
                                        "${(_visionScores[modelName]!['latency'] / 1000).toStringAsFixed(1)}s",
                                        Colors.teal),
                                  ],
                                ),
                              ),
                            // エラー詳細の表示
                            if (_testErrors.containsKey(modelName))
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  _testErrors[modelName]!,
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('$score',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: score >= 1100
                                        ? Colors.blue
                                        : (score >= 900
                                            ? Colors.green
                                            : Colors.grey))),
                            const Text('Score', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  // スコア・速度表示用のバッジ
  Widget _buildScoreBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        "$label: $value",
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildProviderBadge(String provider) {
    Color color;
    IconData icon;
    switch (provider.toLowerCase()) {
      case 'openai':
        color = Colors.green;
        icon = Icons.bolt;
        break;
      case 'anthropic':
        color = Colors.orange;
        icon = Icons.auto_awesome;
        break;
      case 'gemini':
        color = Colors.blue;
        icon = Icons.auto_graph;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    return CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20));
  }
}
