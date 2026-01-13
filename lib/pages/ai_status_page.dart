import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiStatusPage extends StatefulWidget {
  // テスト用にSupabaseClientを注入できるようにする
  final SupabaseClient? supabaseClient;

  const AiStatusPage({super.key, this.supabaseClient});

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  List<dynamic> _models = [];
  bool _isLoading = true;
  String? _error;

  // テスト結果の状態管理
  final Map<String, String> _testResults = {}; // 'testing', 'success', 'error'
  final Map<String, String> _testErrors = {}; // エラー詳細メッセージ
  final Map<String, Map<String, dynamic>> _visionScores = {}; // Visionベンチマーク詳細

  // テスト時は注入されたクライアントを使い、通常時はシングルトンを使う
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchAvailableModels();
  }

  // モデル一覧の取得 (APIレスポンスをUI用に整形)
  Future<void> _fetchAvailableModels() async {
    try {
      setState(() => _isLoading = true);

      // _supabase クライアントを使用
      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      );

      if (response.status != 200) {
        throw Exception('API Error: ${response.status}');
      }

      final data =
          response.data is String ? jsonDecode(response.data) : response.data;

      setState(() {
        final List<dynamic> rawList = data['models'] ?? [];

        // 【重要】ここでデータを正規化します
        _models = rawList.map((m) {
          // APIの 'name' をUIの 'model' にマッピング
          final String name = m['model'] ?? m['name'] ?? 'Unknown';

          // プロバイダー名の表記ゆれ吸収 (Google -> gemini)
          String provider = m['provider'] ?? 'Unknown';
          if (provider.toLowerCase() == 'google') {
            provider = 'gemini';
          }

          return {
            'model': name,
            'provider': provider,
            // scoreがAPIにない場合は 0 で初期化してエラーを防ぐ
            'score': m['score'] ?? 0,
            'description': m['description'],
          };
        }).toList();

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

  // リストをスコア順に並び替える共通メソッド (Null安全対応)
  void _sortModels() {
    _models.sort((a, b) {
      final scoreA = a['score'] as int? ?? 0;
      final scoreB = b['score'] as int? ?? 0;
      return scoreB.compareTo(scoreA);
    });
  }

  // 全モデルの順次テスト実行
  Future<void> _runAllTests() async {
    for (var model in _models) {
      final String modelName = model['model'];
      // 各モデルのテストを待機せずに並列気味に回す（UI更新を優先）
      _testSingleModel(modelName);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // 単体モデルのテスト実行 (多段階ベンチマーク対応版)
  Future<void> _testSingleModel(String modelName) async {
    setState(() {
      _testResults[modelName] = 'testing';
      _testErrors.remove(modelName);
      _visionScores.remove(modelName);
    });

    try {
      final res = await _supabase.functions.invoke(
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

            // ★ 多段階ベンチマーク対応: スコアを動的に更新
            final index = _models.indexWhere((m) => m['model'] == modelName);
            if (index != -1) {
              // (認識率 * 10) - (速度ms / 100)
              final int visionScore = benchmark['score'] as int? ?? 0;
              final int latencyMs =
                  (benchmark['latency'] as num?)?.toInt() ?? 0;
              final int newScore = (visionScore * 10) - (latencyMs ~/ 100);

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
    const Color navy = Color(0xFF0F172A);
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
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      'エラー: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length,
                  itemBuilder: (context, index) {
                    final model = _models[index];
                    final provider = model['provider'] as String? ?? 'Unknown';
                    // scoreがnullでも0として扱う
                    final score = model['score'] as int? ?? 0;
                    final modelName = model['model'] as String? ?? 'Unknown';
                    final status = _testResults[modelName];

                    return Card(
                      key: ValueKey(modelName),
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: () => _testSingleModel(modelName),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ヘッダー行
                              Row(
                                children: [
                                  Stack(
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
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          modelName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Provider: ${provider.toUpperCase()}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // スコア表示
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$score',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: score >= 900
                                              ? Colors.green
                                              : (score >= 500
                                                  ? Colors.orange
                                                  : Colors.grey),
                                        ),
                                      ),
                                      const Text(
                                        'Score',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              // ベンチマーク結果の表示
                              _buildBenchmarkResult(modelName),

                              // エラー表示
                              if (_testErrors.containsKey(modelName))
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _testErrors[modelName]!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  /// ベンチマーク結果のWidget（多段階対応）
  Widget _buildBenchmarkResult(String modelName) {
    final benchmark = _visionScores[modelName];
    if (benchmark == null) return const SizedBox.shrink();

    final int totalScore = benchmark['score'] as int? ?? 0;
    final num latency = benchmark['latency'] as num? ?? 0;
    final String detail = benchmark['detail'] as String? ?? '';
    final List<dynamic>? levels = benchmark['levels'] as List<dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // 総合スコアのプログレスバー
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalScore / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    totalScore >= 80
                        ? Colors.green
                        : (totalScore >= 50 ? Colors.orange : Colors.red),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$totalScore/100',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: totalScore >= 80
                    ? Colors.green
                    : (totalScore >= 50 ? Colors.orange : Colors.red),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // バッジ表示
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildScoreBadge('総合', '$totalScore点', Colors.purple),
            _buildScoreBadge(
              '速度',
              '${(latency / 1000).toStringAsFixed(2)}s',
              Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // サマリーテキスト
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            detail,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ),

        // レベル別詳細（展開可能）
        if (levels != null && levels.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'レベル別詳細',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              children: levels.map<Widget>((level) {
                final levelData = level as Map<String, dynamic>;
                return _buildLevelDetail(levelData);
              }).toList(),
            ),
          ),
      ],
    );
  }

  /// レベル別詳細のWidget
  Widget _buildLevelDetail(Map<String, dynamic> levelData) {
    final String levelName = levelData['level'] as String? ?? '';
    final String? description = levelData['description'] as String?;
    final int levelScore = levelData['score'] as int? ?? 0;
    final int maxPoints = levelData['maxPoints'] as int? ?? 0;
    final bool passed = levelData['passed'] as bool? ?? false;
    final String response = levelData['response'] as String? ?? '';
    final num levelLatency = levelData['latency'] as num? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: passed
            ? Colors.green.withValues(alpha: 0.08)
            : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: passed ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getLevelLabel(levelName, description),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '$levelScore/$maxPoints',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: passed ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                '${(levelLatency / 1000).toStringAsFixed(2)}s',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '回答: $response',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// レベル名のラベル変換
  String _getLevelLabel(String levelName, String? description) {
    // descriptionがあればそれを使用（サーバーから送られてくる）
    if (description != null && description.isNotEmpty) {
      final levelNum = levelName.replaceAll('level', 'L');
      return '$levelNum: $description';
    }
    // フォールバック
    switch (levelName) {
      case 'level1':
        return 'L1: 色認識';
      case 'level2':
        return 'L2: 単純OCR';
      case 'level3':
        return 'L3: 複雑カウント';
      case 'level4':
        return 'L4: 空間認識';
      case 'level5':
        return 'L5: 論理推論';
      case 'level6':
        return 'L6: 微細識別';
      default:
        return levelName;
    }
  }

  Widget _buildScoreBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$label: $value',
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
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
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
