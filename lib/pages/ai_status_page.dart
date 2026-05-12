import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/ai_model_preference_service.dart';
import '../services/magi_system_settings_service.dart';

class AiStatusPage extends StatefulWidget {
  // テスト時に SupabaseClient を注入できるようにする
  final SupabaseClient? supabaseClient;
  final AiModelPreferenceService modelPreferenceService;
  final MagiSystemSettingsService magiSettingsService;

  const AiStatusPage({
    super.key,
    this.supabaseClient,
    this.modelPreferenceService = const AiModelPreferenceService(),
    this.magiSettingsService = const MagiSystemSettingsService(),
  });

  @override
  State<AiStatusPage> createState() => _AiStatusPageState();
}

class _AiStatusPageState extends State<AiStatusPage> {
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = true;
  String? _error;
  String? _preferredModel;
  MagiSystemSettings _magiSettings = const MagiSystemSettings();

  // テスト実行の状態管理
  final Map<String, String> _testResults = {}; // 'testing', 'success', 'error'
  final Map<String, String> _testErrors = {}; // エラー詳細メッセージ
  final Map<String, Map<String, dynamic>> _visionScores = {}; // Vision ベンチマーク詳細

  // テスト時は注入されたクライアントを使い、通常時はシングルトンを使う
  SupabaseClient get _supabase =>
      widget.supabaseClient ?? Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadPreferredModel();
    _loadMagiSettings();
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
      SnackBar(content: Text('既定の AI モデルを $modelName に設定しました')),
    );
  }

  Future<void> _loadMagiSettings() async {
    final settings = await widget.magiSettingsService.loadSettings();
    if (!mounted) {
      _magiSettings = settings;
      return;
    }
    setState(() {
      _magiSettings = settings;
    });
  }

  Future<void> _setMagiEnabled(bool enabled) async {
    final settings = await widget.magiSettingsService.saveEnabled(enabled);
    if (!mounted) {
      _magiSettings = settings;
      return;
    }
    setState(() {
      _magiSettings = settings;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(enabled ? 'MAGI システムを全体で有効にしました' : 'MAGI システムを全体で無効にしました'),
      ),
    );
  }

  Future<void> _setMagiNodeModel(MagiNodeRole role, String modelName) async {
    final settings = await widget.magiSettingsService.saveNodeModel(
      role,
      modelName,
    );
    if (!mounted) {
      _magiSettings = settings;
      return;
    }
    setState(() {
      _magiSettings = settings;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${role.label} のモデルを $modelName に設定しました')),
    );
  }

  // モデル一覧の取得（API レスポンスを UI 用に整形）
  Future<void> _fetchAvailableModels() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      setState(() => _isLoading = true);

      // _supabase クライアントを使用
      final response = await _supabase.functions.invoke(
        'ai-assistant',
        body: {'action': 'get_models'},
      );

      if (response.status != 200) {
        throw Exception('API エラー: ${response.status}');
      }

      final data = (response.data is String
          ? jsonDecode(response.data)
          : response.data) as Map<String, dynamic>;

      setState(() {
        final List<dynamic> rawList = data['models'] as List<dynamic>? ?? [];

        // ここでデータを整形します
        _models = rawList
            .map<Map<String, dynamic>?>((m) {
              final modelMap = m as Map<String, dynamic>;
              // API の 'name' または 'model' を正規化
              final String name = modelMap['model'] as String? ??
                  modelMap['name'] as String? ??
                  '不明';

              // プロバイダー表記をそろえて、MAGI 表示用のエンジン名へ正規化
              final rawProvider = modelMap['provider'] as String? ?? '';
              final provider = _normalizeEngine(rawProvider, name);
              if (provider == 'xai') {
                return null;
              }

              return {
                'model': name,
                'provider': provider,
                // score がない場合は 0 として扱う
                'score': modelMap['score'] as int? ?? 0,
                'description': modelMap['description'] as String?,
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        _sortModels();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // リストをスコア順に並び替える共通メソッド（Null 安全対応）
  void _sortModels() {
    _models.sort((a, b) {
      final scoreA = a['score'] as int? ?? 0;
      final scoreB = b['score'] as int? ?? 0;
      return scoreB.compareTo(scoreA);
    });
  }

  // すべてのモデルのテストを実行
  Future<void> _runAllTests() async {
    for (var model in _models) {
      final String modelName = model['model'] as String;
      // 各モデルのテストを順番に実行し、UI 更新が見やすいよう少し待つ
      _testSingleModel(modelName);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // 個別モデルのテスト実行（詳細ベンチマーク対応）
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

            // 詳細ベンチマーク結果をスコアへ反映
            final index = _models.indexWhere(
              (m) => m['model'] == modelName,
            );
            if (index != -1) {
              // (Vision スコア * 10) - (遅延 ms / 100)
              final int visionScore = benchmark['score'] as int? ?? 0;
              final int latencyMs =
                  (benchmark['latency'] as num?)?.toInt() ?? 0;
              final int newScore = (visionScore * 10) - (latencyMs ~/ 100);

              _models[index]['score'] = newScore;

              // スコア順が変わる可能性があるため再ソート
              _sortModels();
            }
          }
        } else {
          _testResults[modelName] = 'error';
          _testErrors[modelName] = data['error']?.toString() ?? '不明なエラー';

          // エラー時はスコアを 0 にして末尾へ回す
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
      if (!mounted) return;
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
      appBar: AppBar(
        title: const Text('MAGIモデルステータス'),
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: _runAllTests,
            tooltip: 'すべてのモデルをテスト',
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
                      style: const TextStyle(
                        color: Color(0xFFE53935),
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_preferredModel != null) _buildDefaultModelBanner(navy),
                    _buildMagiSystemCard(navy),
                    ..._models
                        .map((modelMap) => _buildModelCard(navy, modelMap)),
                  ],
                ),
    );
  }

  Widget _buildModelCard(Color navy, Map<String, dynamic> modelMap) {
    final provider = modelMap['provider'] as String? ?? '不明';
    final score = modelMap['score'] as int? ?? 0;
    final modelName = modelMap['model'] as String? ?? '不明';
    final status = _testResults[modelName];
    final nodeCode = _resolveMagiNode(provider, modelName);

    return Card(
      key: ValueKey(modelName),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
      ),
      child: InkWell(
        onTap: () => _testSingleModel(modelName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                                ? const Color(0xFFFF6B35)
                                : (status == 'success'
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFE53935)),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          modelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'MAGIノード: $nodeCode (${provider.toUpperCase()})',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: score >= 900
                              ? const Color(0xFF4CAF50)
                              : (score >= 500
                                  ? const Color(0xFFFF6B35)
                                  : const Color(0xFF9CA3AF)),
                          height: 1.5,
                        ),
                      ),
                      const Text(
                        'スコア',
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                        ),
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
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            '既定',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        )
                      else
                        OutlinedButton(
                          key: Key(
                            'ai_status_default_model_button_$modelName',
                          ),
                          onPressed: () => _setPreferredModel(modelName),
                          child: const Text('既定にする'),
                        ),
                    ],
                  ),
                ],
              ),
              _buildBenchmarkResult(modelName),
              if (_testErrors.containsKey(modelName))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _testErrors[modelName]!,
                    style: const TextStyle(
                      color: Color(0xFFE53935),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMagiSystemCard(Color navy) {
    return Container(
      key: const Key('ai_status_magi_system_card'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: navy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_outlined, color: navy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MAGI システム全体設定',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: navy.withValues(alpha: 0.92),
                        height: 1.5,
                      ),
                    ),
                    Text(
                      '改善、要約、翻訳、カスタムプロンプト、役員会議へ共通反映します。',
                      style: TextStyle(
                        fontSize: 12,
                        color: navy.withValues(alpha: 0.65),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            key: const Key('ai_status_magi_enabled_switch'),
            contentPadding: EdgeInsets.zero,
            value: _magiSettings.enabled,
            title: const Text('MAGI を全体で使う'),
            subtitle: Text(
              _magiSettings.enabled ? '各ノードの意見を合成して回答します。' : '単一モデルで回答します。',
            ),
            onChanged: (value) {
              _setMagiEnabled(value);
            },
          ),
          const SizedBox(height: 8),
          _buildMagiModelDropdown(role: MagiNodeRole.melchior),
          const SizedBox(height: 12),
          _buildMagiModelDropdown(role: MagiNodeRole.balthasar),
          const SizedBox(height: 12),
          _buildMagiModelDropdown(role: MagiNodeRole.casper),
          const SizedBox(height: 12),
          _buildMagiModelDropdown(role: MagiNodeRole.synthesis),
        ],
      ),
    );
  }

  Widget _buildMagiModelDropdown({
    required MagiNodeRole role,
  }) {
    final options = _modelsForRole(role);
    final selectedModel = _selectedRoleModel(role, options);

    return DropdownButtonFormField<String>(
      key: Key('ai_status_${role.name}_dropdown'),
      initialValue: selectedModel,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: '${role.label} (${role.description})',
        helperText: _magiRoleHelperText(role),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: _magiSettings.enabled
            ? Colors.white
            : const Color(0xFF9CA3AF).withValues(alpha: 0.05),
      ),
      items: options
          .map(
            (modelName) => DropdownMenuItem<String>(
              value: modelName,
              child: Text(modelName),
            ),
          )
          .toList(),
      onChanged: !_magiSettings.enabled
          ? null
          : (value) {
              if (value == null || value.isEmpty) {
                return;
              }
              _setMagiNodeModel(role, value);
            },
    );
  }

  List<String> _modelsForRole(MagiNodeRole role) {
    final values = <String>{_magiSettings.modelFor(role)};

    for (final modelMap in _models) {
      final modelName = modelMap['model'] as String? ?? '';
      if (modelName.isEmpty) {
        continue;
      }
      if (role == MagiNodeRole.synthesis) {
        values.add(modelName);
        continue;
      }
      final provider = modelMap['provider'] as String? ?? '';
      if (_resolveMagiNode(provider, modelName) == role.label) {
        values.add(modelName);
      }
    }

    final list = values.where((value) => value.trim().isNotEmpty).toList();
    list.sort();
    return list;
  }

  String _selectedRoleModel(MagiNodeRole role, List<String> options) {
    final configured = _magiSettings.modelFor(role);
    if (options.contains(configured)) {
      return configured;
    }
    return options.first;
  }

  String _magiRoleHelperText(MagiNodeRole role) {
    switch (role) {
      case MagiNodeRole.melchior:
        return '論理・分析担当。OpenAI / DeepSeek 系が向いています。';
      case MagiNodeRole.balthasar:
        return '共感・人間理解担当。Claude 系が向いています。';
      case MagiNodeRole.casper:
        return '批判・リスク検討担当。Gemini / Gemma 系が向いています。';
      case MagiNodeRole.synthesis:
        return '最終回答を統合するモデルです。';
    }
  }

  /// 既定モデルバナーの Widget
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
                  '既定の AI モデル',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: navy.withValues(alpha: 0.92),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _preferredModel ?? '',
                  style: TextStyle(
                    color: navy.withValues(alpha: 0.72),
                    height: 1.5,
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

        // 総合スコアのプログレスバー
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalScore / 100,
                  minHeight: 8,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    totalScore >= 80
                        ? const Color(0xFF4CAF50)
                        : (totalScore >= 50
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFFE53935)),
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
                    ? const Color(0xFF4CAF50)
                    : (totalScore >= 50
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFFE53935)),
                height: 1.5,
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
            _buildScoreBadge('総合', '$totalScore点', const Color(0xFF3D5AFE)),
            _buildScoreBadge(
              '遅延',
              '${(latency / 1000).toStringAsFixed(2)}s',
              const Color(0xFF009688),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // サマリーテキスト
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ),

        // レベル詳細一覧（展開可能）
        if (levels != null && levels.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'レベル詳細',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
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

  /// レベル詳細の Widget
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
            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
            : const Color(0xFFE53935).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed
              ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
              : const Color(0xFFE53935).withValues(alpha: 0.3),
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
                color:
                    passed ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getLevelLabel(levelName, description),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              Text(
                '$levelScore/$maxPoints',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: passed
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE53935),
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 12,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '${(levelLatency / 1000).toStringAsFixed(2)}s',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '応答: $response',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// レベル名のラベルを整形
  String _getLevelLabel(String levelName, String? description) {
    // description があればそれを優先し、サーバーから返された説明を使う
    if (description != null && description.isNotEmpty) {
      final levelNum = levelName.replaceAll('level', 'L');
      return '$levelNum: $description';
    }
    // フォールバック
    switch (levelName) {
      case 'level1':
        return 'L1: 軽量推論';
      case 'level2':
        return 'L2: バランス実行';
      case 'level3':
        return 'L3: 中規模分析';
      case 'level4':
        return 'L4: 精度重視';
      case 'level5':
        return 'L5: 戦略統合';
      case 'level6':
        return 'L6: 専門領域対応';
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
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.bold,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildProviderBadge(String provider, String modelName) {
    final node = _resolveMagiNode(provider, modelName);
    Color color;
    IconData icon;
    switch (node) {
      case 'MELCHIOR':
        color = const Color(0xFF3D5AFE);
        icon = Icons.psychology_alt;
        break;
      case 'BALTHASAR':
        color = const Color(0xFFFF6B35);
        icon = Icons.auto_awesome;
        break;
      case 'CASPER':
        color = const Color(0xFF3D5AFE);
        icon = Icons.auto_graph;
        break;
      default:
        color = const Color(0xFF9CA3AF);
        icon = Icons.hub;
    }
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _normalizeEngine(String provider, String modelName) {
    final normalizedProvider = provider.toLowerCase().trim();
    final normalizedModel = modelName.toLowerCase().trim();
    final source = '$normalizedProvider $normalizedModel';

    if (source.contains('deepseek')) {
      return 'deepseek';
    }
    if (source.contains('openai') ||
        normalizedModel.startsWith('gpt') ||
        normalizedModel.startsWith('o')) {
      return 'gpt';
    }
    if (source.contains('anthropic') || source.contains('claude')) {
      return 'claude';
    }
    if (source.contains('google') ||
        source.contains('gemini') ||
        source.contains('gemma')) {
      return 'gemini';
    }
    if (source.contains('xai') || source.contains('grok')) {
      return 'xai';
    }
    return provider.trim().isEmpty ? 'unknown' : provider.toLowerCase();
  }

  String _resolveMagiNode(String provider, String modelName) {
    final engine = _normalizeEngine(provider, modelName);
    switch (engine) {
      case 'gpt':
        return 'MELCHIOR';
      case 'deepseek':
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
