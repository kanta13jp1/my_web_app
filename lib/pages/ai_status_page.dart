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

  // モデル一覧の取得 (サーバー側の実績スコアに基づいた初期ソート)
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
        // 初期状態をスコア順にソート
        _sortModels();
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

  // リストをスコア順に並び替える共通メソッド
  void _sortModels() {
    _models.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
  }

  // 全モデルの順次テスト実行
  Future<void> _runAllTests() async {
    for (var model in _models) {
      final String modelName = model['model'];
      // 各モデルのテストを待機せずに並列気味に回す（UI更新を優先）
      _testSingleModel(modelName);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  // 単体モデルのテスト実行 (動的ソート対応版)
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

      final data = res.data is String
          ? jsonDecode(res.data)
          : res.data as Map<String, dynamic>;

      setState(() {
        if (data['success'] == true) {
          _testResults[modelName] = 'success';

          final benchmark = data['benchmark'];
          if (benchmark != null) {
            _visionScores[modelName] = Map<String, dynamic>.from(benchmark);

            // ★ 追加ロジック: ローカルのモデルリスト内のスコアも動的に更新する
            final index = _models.indexWhere((m) => m['model'] == modelName);
            if (index != -1) {
              // サーバー側のロジックと同じ計算式でスコアを暫定計算
              // (認識率 * 10) - (速度ms / 100)
              final int newScore = ((benchmark['score'] as int) * 10) -
                  ((benchmark['latency'] as num) ~/ 100);

              _models[index]['score'] = newScore;

              // ★ 順位が変わる可能性があるため再ソート
              _sortModels();
            }
          }
        } else {
          _testResults[modelName] = 'error';
          _testErrors[modelName] = data['error']?.toString() ?? 'Unknown Error';

          // エラー時はスコアを0にして最下位へ
          final index = _models.indexWhere((m) => m['model'] == modelName);
          if (index != -1) {
            _models[index]['score'] = 0;
            _sortModels();
          }
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
                      key: ValueKey(modelName), // ソート時にアニメーションを安定させるため
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
                            Builder(builder: (context) {
                              final benchmark = _visionScores[modelName];
                              if (benchmark == null)
                                return const SizedBox.shrink();

                              final scoreValue =
                                  benchmark['score'] as int? ?? 0;
                              final latency = benchmark['latency'] as num? ?? 0;
                              final detail =
                                  benchmark['detail'] as String? ?? '回答なし';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Icon(
                                        scoreValue == 100
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        size: 14,
                                        color: scoreValue == 100
                                            ? Colors.green
                                            : Colors.grey,
                                      ),
                                      _buildScoreBadge("画像認識", "$scoreValue%",
                                          Colors.purple),
                                      _buildScoreBadge(
                                          "速度",
                                          "${(latency / 1000).toStringAsFixed(2)}s",
                                          Colors.teal),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "認識結果: $detail",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade700,
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            if (_testErrors.containsKey(modelName))
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
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
