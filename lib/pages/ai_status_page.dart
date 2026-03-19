import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_model_preference_service.dart';

class AiStatusPage extends StatefulWidget {
  // 繝・せ繝育畑縺ｫSupabaseClient繧呈ｳｨ蜈･縺ｧ縺阪ｋ繧医≧縺ｫ縺吶ｋ
  final SupabaseClient? supabaseClient;
  final AiModelPreferenceService modelPreferenceService;

  const AiStatusPage({
    super.key,
    this.supabaseClient,
    this.modelPreferenceService = const AiModelPreferenceService(),
  });

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = true;
  String? _error;
  String? _preferredModel;

  // 繝・せ繝育ｵ先棡縺ｮ迥ｶ諷狗ｮ｡逅・
  final Map<String, String> _testResults = {}; // 'testing', 'success', 'error'
  final Map<String, String> _testErrors = {}; // 繧ｨ繝ｩ繝ｼ隧ｳ邏ｰ繝｡繝・そ繝ｼ繧ｸ
  final Map<String, Map<String, dynamic>> _visionScores = {}; // Vision繝吶Φ繝√・繝ｼ繧ｯ隧ｳ邏ｰ

  // 繝・せ繝域凾縺ｯ豕ｨ蜈･縺輔ｌ縺溘け繝ｩ繧､繧｢繝ｳ繝医ｒ菴ｿ縺・・壼ｸｸ譎ゅ・繧ｷ繝ｳ繧ｰ繝ｫ繝医Φ繧剃ｽｿ縺・
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadPreferredModel();
    _fetchAvailableModels();
  }

  Future<void> _loadPreferredModel() async {
    final preferredModel =
        await widget.modelPreferenceService.loadPreferredModel();
    if (!mounted) {
      _preferredModel = preferredModel;
      return;
    }
    setState(() {
      _preferredModel = preferredModel;
    });
  }

  Future<void> _setPreferredModel(String modelName) async {
    await widget.modelPreferenceService.savePreferredModel(modelName);
    if (!mounted) {
      _preferredModel = modelName;
      return;
    }
    setState(() {
      _preferredModel = modelName;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Default AI model set to $modelName')),
    );
  }

  // 繝｢繝・Ν荳隕ｧ縺ｮ蜿門ｾ・(API繝ｬ繧ｹ繝昴Φ繧ｹ繧旦I逕ｨ縺ｫ謨ｴ蠖｢)
  Future<void> _fetchAvailableModels() async {
    try {
      setState(() => _isLoading = true);

      // _supabase 繧ｯ繝ｩ繧､繧｢繝ｳ繝医ｒ菴ｿ逕ｨ
      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      );

      if (response.status != 200) {
        throw Exception('API Error: ${response.status}');
      }

      final data = (response.data is String
          ? jsonDecode(response.data)
          : response.data) as Map<String, dynamic>;

      setState(() {
        final List<dynamic> rawList = data['models'] as List<dynamic>? ?? [];

        // 縲宣㍾隕√代％縺薙〒繝・・繧ｿ繧呈ｭ｣隕丞喧縺励∪縺・
        _models = rawList.map((m) {
          final modelMap = m as Map<String, dynamic>;
          // API縺ｮ 'name' 繧旦I縺ｮ 'model' 縺ｫ繝槭ャ繝斐Φ繧ｰ
          final String name = modelMap['model'] as String? ??
              modelMap['name'] as String? ??
              'Unknown';

          // 繝励Ο繝舌う繝繝ｼ陦ｨ險倥ｆ繧後ｒ蜷ｸ蜿弱＠縲｀AGI縺ｧ謇ｱ縺・お繝ｳ繧ｸ繝ｳ蜷阪∈豁｣隕丞喧
          final rawProvider = modelMap['provider'] as String? ?? '';
          final provider = _normalizeEngine(rawProvider, name);

          return {
            'model': name,
            'provider': provider,
            // score縺窟PI縺ｫ縺ｪ縺・ｴ蜷医・ 0 縺ｧ蛻晄悄蛹悶＠縺ｦ繧ｨ繝ｩ繝ｼ繧帝亟縺・
            'score': modelMap['score'] as int? ?? 0,
            'description': modelMap['description'] as String?,
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

  // 繝ｪ繧ｹ繝医ｒ繧ｹ繧ｳ繧｢鬆・↓荳ｦ縺ｳ譖ｿ縺医ｋ蜈ｱ騾壹Γ繧ｽ繝・ラ (Null螳牙・蟇ｾ蠢・
  void _sortModels() {
    _models.sort((a, b) {
      final scoreA = a['score'] as int? ?? 0;
      final scoreB = b['score'] as int? ?? 0;
      return scoreB.compareTo(scoreA);
    });
  }

  // 蜈ｨ繝｢繝・Ν縺ｮ鬆・ｬ｡繝・せ繝亥ｮ溯｡・
  Future<void> _runAllTests() async {
    for (var model in _models) {
      final String modelName = model['model'] as String;
      // 蜷・Δ繝・Ν縺ｮ繝・せ繝医ｒ蠕・ｩ溘○縺壹↓荳ｦ蛻玲ｰ怜袖縺ｫ蝗槭☆・・I譖ｴ譁ｰ繧貞━蜈茨ｼ・
      _testSingleModel(modelName);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // 蜊倅ｽ薙Δ繝・Ν縺ｮ繝・せ繝亥ｮ溯｡・(螟壽ｮｵ髫弱・繝ｳ繝√・繝ｼ繧ｯ蟇ｾ蠢懃沿)
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

      final data = (res.data is String ? jsonDecode(res.data) : res.data)
          as Map<String, dynamic>;

      setState(() {
        if (data['success'] == true) {
          _testResults[modelName] = 'success';

          final benchmark = data['benchmark'] as Map<String, dynamic>?;
          if (benchmark != null) {
            _visionScores[modelName] = benchmark;

            // 笘・螟壽ｮｵ髫弱・繝ｳ繝√・繝ｼ繧ｯ蟇ｾ蠢・ 繧ｹ繧ｳ繧｢繧貞虚逧・↓譖ｴ譁ｰ
            final index = _models.indexWhere(
              (m) => m['model'] == modelName,
            );
            if (index != -1) {
              // (隱崎ｭ倡紫 * 10) - (騾溷ｺｦms / 100)
              final int visionScore = benchmark['score'] as int? ?? 0;
              final int latencyMs =
                  (benchmark['latency'] as num?)?.toInt() ?? 0;
              final int newScore = (visionScore * 10) - (latencyMs ~/ 100);

              _models[index]['score'] = newScore;

              // 笘・鬆・ｽ阪′螟峨ｏ繧句庄閭ｽ諤ｧ縺後≠繧九◆繧∝・繧ｽ繝ｼ繝・
              _sortModels();
            }
          }
        } else {
          _testResults[modelName] = 'error';
          _testErrors[modelName] = data['error']?.toString() ?? 'Unknown Error';

          // 繧ｨ繝ｩ繝ｼ譎ゅ・繧ｹ繧ｳ繧｢繧・縺ｫ縺励※譛荳倶ｽ阪∈
          final index = _models.indexWhere(
            (m) => m['model'] == modelName,
          );
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
        title: const Text('MAGI遞ｼ蜒阪Δ繝九ち繝ｼ'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _runAllTests,
            tooltip: 'Run all tests',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAvailableModels,
            tooltip: '荳隕ｧ繧呈峩譁ｰ',
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
                      '繧ｨ繝ｩ繝ｼ: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _models.length + (_preferredModel != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_preferredModel != null && index == 0) {
                      return _buildDefaultModelBanner(navy);
                    }
                    final modelIndex = _preferredModel != null ? index - 1 : index;
                    final modelMap = _models[modelIndex];
                    final provider =
                        modelMap['provider'] as String? ?? 'Unknown';
                    // score縺系ull縺ｧ繧・縺ｨ縺励※謇ｱ縺・
                    final score = modelMap['score'] as int? ?? 0;
                    final modelName = modelMap['model'] as String? ?? 'Unknown';
                    final status = _testResults[modelName];
                    final nodeCode = _resolveMagiNode(provider, modelName);

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
                              // 繝倥ャ繝繝ｼ陦・
                              Row(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      _buildProviderBadge(provider, modelName),
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
                                          'MAGI Node: $nodeCode (${provider.toUpperCase()})',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 繧ｹ繧ｳ繧｢陦ｨ遉ｺ
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
                                      const SizedBox(height: 8),
                                      if (_preferredModel == modelName)
                                        Container(
                                          key: Key(
                                            'ai_status_default_model_badge_$modelName',
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: navy.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Default',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      else
                                        OutlinedButton(
                                          key: Key(
                                            'ai_status_default_model_button_$modelName',
                                          ),
                                          onPressed: () =>
                                              _setPreferredModel(modelName),
                                          child: const Text('Set Default'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),

                              // 繝吶Φ繝√・繝ｼ繧ｯ邨先棡縺ｮ陦ｨ遉ｺ
                              _buildBenchmarkResult(modelName),

                              // 繧ｨ繝ｩ繝ｼ陦ｨ遉ｺ
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

  /// 繝吶Φ繝√・繝ｼ繧ｯ邨先棡縺ｮWidget・亥､壽ｮｵ髫主ｯｾ蠢懶ｼ・
  Widget _buildDefaultModelBanner(Color navy) {
    return Container(
      key: const Key('ai_status_default_model_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: navy.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.rocket_launch_outlined, color: navy),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OpenClaw-style default model',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: navy.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _preferredModel ?? '',
                  style: TextStyle(
                    color: navy.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

        // 邱丞粋繧ｹ繧ｳ繧｢縺ｮ繝励Ο繧ｰ繝ｬ繧ｹ繝舌・
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

        // 繝舌ャ繧ｸ陦ｨ遉ｺ
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildScoreBadge('邱丞粋', '$totalScore轤ｹ', Colors.purple),
            _buildScoreBadge(
              '騾溷ｺｦ',
              '${(latency / 1000).toStringAsFixed(2)}s',
              Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 繧ｵ繝槭Μ繝ｼ繝・く繧ｹ繝・
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

        // 繝ｬ繝吶Ν蛻･隧ｳ邏ｰ・亥ｱ暮幕蜿ｯ閭ｽ・・
        if (levels != null && levels.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                '繝ｬ繝吶Ν蛻･隧ｳ邏ｰ',
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

  /// 繝ｬ繝吶Ν蛻･隧ｳ邏ｰ縺ｮWidget
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
            '蝗樒ｭ・ $response',
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

  /// 繝ｬ繝吶Ν蜷阪・繝ｩ繝吶Ν螟画鋤
  String _getLevelLabel(String levelName, String? description) {
    // description縺後≠繧後・縺昴ｌ繧剃ｽｿ逕ｨ・医し繝ｼ繝舌・縺九ｉ騾√ｉ繧後※縺上ｋ・・
    if (description != null && description.isNotEmpty) {
      final levelNum = levelName.replaceAll('level', 'L');
      return '$levelNum: $description';
    }
    // 繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ
    switch (levelName) {
      case 'level1':
        return 'L1: Lightweight reasoning';
      case 'level2':
        return 'L2: Balanced execution';
      case 'level3':
        return 'L3: Mid-range analysis';
      case 'level4':
        return 'L4: Accuracy focused';
      case 'level5':
        return 'L5: Strategic synthesis';
      case 'level6':
        return 'L6: Specialized domain';
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

  Widget _buildProviderBadge(String provider, String modelName) {
    final node = _resolveMagiNode(provider, modelName);
    Color color;
    IconData icon;
    switch (node) {
      case 'MELCHIOR':
        color = Colors.lightBlue;
        icon = Icons.psychology_alt;
        break;
      case 'BALTHASAR':
        color = Colors.deepOrange;
        icon = Icons.auto_awesome;
        break;
      case 'CASPER':
        color = Colors.indigo;
        icon = Icons.auto_graph;
        break;
      default:
        color = Colors.grey;
        icon = Icons.hub;
    }
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _normalizeEngine(String provider, String modelName) {
    final source = '${provider.toLowerCase()} ${modelName.toLowerCase()}';
    if (source.contains('openai') || source.contains('gpt')) {
      return 'gpt';
    }
    if (source.contains('anthropic') || source.contains('claude')) {
      return 'claude';
    }
    if (source.contains('google') || source.contains('gemini')) {
      return 'gemini';
    }
    return provider.trim().isEmpty ? 'unknown' : provider.toLowerCase();
  }

  String _resolveMagiNode(String provider, String modelName) {
    final engine = _normalizeEngine(provider, modelName);
    switch (engine) {
      case 'gpt':
        return 'MELCHIOR';
      case 'claude':
        return 'BALTHASAR';
      case 'gemini':
        return 'CASPER';
      default:
        return 'AUX';
    }
  }
}
