import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElectionStrategyPage extends StatefulWidget {
  const ElectionStrategyPage({super.key});

  @override
  State<ElectionStrategyPage> createState() => _ElectionStrategyPageState();
}

class _ElectionStrategyPageState extends State<ElectionStrategyPage> {
  // シミュレーション用パラメータ
  double _supportRate = 15.0; // 党支持率 (%)
  double _youthTurnout = 40.0; // 若年層投票率 (%)
  double _swingVoterCapture = 30.0; // 無党派層獲得率 (%)

  // AIアドバイス用
  String _aiAdvice = '';
  bool _isAnalyzing = false;
  String? _apiKey;

  // 目標議席数 (過半数233議席を仮想目標とする)
  final int _targetSeats = 233;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('gemini_api_key');
    });
  }

  // 簡易的な議席獲得予測ロジック (あくまでシミュレーション用の仮計算です)
  int get _projectedSeats {
    // 基礎票 + (支持率 * 勢い係数) + (若年層投票率 * ブースト)
    double base = 10.0;
    double momentum = (_supportRate * 3.5);
    double youthBoost = (_youthTurnout > 50) ? (_youthTurnout - 50) * 1.5 : 0;
    double swingBoost = _swingVoterCapture * 0.5;

    int seats = (base + momentum + youthBoost + swingBoost).round();
    return seats > 465 ? 465 : seats; // 最大議席数キャップ
  }

  Future<void> _askGeminiStrategist() async {
    if (_apiKey == null) return;

    setState(() {
      _isAnalyzing = true;
      _aiAdvice = '';
    });

    try {
      // 最新の高速モデルを使用
      final model = GenerativeModel(
        model: 'models/gemini-2.5-flash',
        apiKey: _apiKey!,
      );

      final prompt = '''
あなたは国民民主党の選挙戦略担当の最高責任者(Chief Strategist)です。
2026年衆議院選挙に向けたシミュレーション結果に基づき、勝利のための具体的かつ大胆なアクションプランを3つ提案してください。

【シミュレーション数値】
- 現在の党支持率: ${_supportRate.toStringAsFixed(1)}%
- 若年層(10-20代)の投票率: ${_youthTurnout.toStringAsFixed(1)}%
- 無党派層の獲得率: ${_swingVoterCapture.toStringAsFixed(1)}%
- 予測獲得議席数: $_projectedSeats 議席 (目標: $_targetSeats 議席)

【党の重要政策キーワード】
- 「手取りを増やす」
- 「103万円の壁撤廃」
- 「トリガー条項凍結解除」
- 「現役世代への投資」

【指示】
ターゲット層を明確にし、SNS戦略、街頭演説の重点ポイント、他党との差別化戦略を含めてください。
回答はマークダウン形式で、士気を高めるようなトーンで記述してください。
''';

      final response = await model.generateContent([Content.text(prompt)]);

      if (mounted) {
        setState(() {
          _aiAdvice = response.text ?? '戦略の生成に失敗しました。';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAdvice = 'エラーが発生しました: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectedSeats = _projectedSeats;
    // final progress = projectedSeats / _targetSeats; // 削除: 未使用変数
    final isVictory = projectedSeats >= _targetSeats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 衆院選 勝利戦略室'),
        backgroundColor: Colors.yellow.shade700, // 国民民主党のイメージカラーに近い色
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildScoreBoard(projectedSeats, isVictory),
            const SizedBox(height: 24),
            const Text(
              'パラメータ・シミュレーション',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildSlider(
              '党支持率 (メディア世論調査)',
              _supportRate,
              0,
              60,
              (v) => setState(() => _supportRate = v),
              unit: '%',
              color: Colors.orange,
            ),
            _buildSlider(
              '若年層投票率 (10-20代)',
              _youthTurnout,
              20,
              80,
              (v) => setState(() => _youthTurnout = v),
              unit: '%',
              color: Colors.blue,
            ),
            _buildSlider(
              '無党派層からの支持',
              _swingVoterCapture,
              0,
              100,
              (v) => setState(() => _swingVoterCapture = v),
              unit: '%',
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_isAnalyzing || _apiKey == null)
                    ? null
                    : _askGeminiStrategist,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology),
                label: const Text('Gemini参謀に戦略を諮問する'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            if (_aiAdvice.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('参謀からの提言:',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: Text(_aiAdvice),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBoard(int seats, bool isVictory) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text('予測獲得議席数', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$seats',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: isVictory ? Colors.red : Colors.black87,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    ' / 465',
                    style: TextStyle(fontSize: 24, color: Colors.grey),
                  ),
                ),
              ],
            ),
            if (isVictory)
              const Text(
                '🎉 政権交代・過半数獲得圏内 🎉',
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: seats / 465,
              backgroundColor: Colors.grey.shade200,
              color: isVictory ? Colors.red : Colors.yellow.shade700,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(height: 8),
            const Text('「手取りを増やす」政策の浸透度が鍵となります。',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String unit = '',
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${value.toStringAsFixed(1)}$unit',
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }
}