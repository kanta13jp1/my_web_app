import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/personality_test_service.dart';
import '../models/personality_test.dart';
import '../services/app_share_service.dart';

/// 性格診断の結果ページ
class PersonalityTestResultPage extends StatefulWidget {
  final int testId;

  const PersonalityTestResultPage({
    super.key,
    required this.testId,
  });

  @override
  State<PersonalityTestResultPage> createState() =>
      _PersonalityTestResultPageState();
}

class _PersonalityTestResultPageState extends State<PersonalityTestResultPage> {
  final PersonalityTestService _service = PersonalityTestService();
  PersonalityTest? _test;
  PersonalityType? _personalityType;
  Map<String, int>? _scores;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResult();
  }

  Future<void> _loadResult() async {
    try {
      final test = await _service.getTestResult(widget.testId);
      final scores = await _service.calculateScores(widget.testId);
      final personalityType =
          _service.getPersonalityTypeDetails(test.personalityType!);

      setState(() {
        _test = test;
        _scores = scores;
        _personalityType = personalityType;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('結果の読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _shareToTwitter() async {
    if (_personalityType == null || _test == null) return;

    final text = '''
性格診断の結果: ${_personalityType!.code}（${_personalityType!.nameJa}）🧠

「${_personalityType!.nameEn}」タイプ

${_personalityType!.description}

#マイメモ #性格診断 #MBTI
''';

    final url = 'https://mymemo.app/personality-test';

    await AppShareService.shareToTwitter(customMessage: '$text\n$url');
  }

  Future<void> _copyToClipboard() async {
    if (_personalityType == null) return;

    final text = '''
性格診断の結果: ${_personalityType!.code}（${_personalityType!.nameJa}）

「${_personalityType!.nameEn}」タイプ

${_personalityType!.description}
''';

    await Clipboard.setData(ClipboardData(text: text));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('クリップボードにコピーしました'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_test == null || _personalityType == null || _scores == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('性格診断結果'),
        ),
        body: const Center(
          child: Text('結果が見つかりませんでした'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('診断結果'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareToTwitter,
            tooltip: 'Twitterでシェア',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
            tooltip: 'コピー',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ヒーローセクション
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.secondary,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'あなたの性格タイプは...',
                    style: textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _personalityType!.code,
                    style: textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_personalityType!.nameJa}（${_personalityType!.nameEn}）',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 説明セクション
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _personalityType!.description,
                        style: textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 性格の特徴（スコア）
                  _SectionTitle(
                    icon: Icons.bar_chart,
                    title: '性格の特徴',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildScoreBar('内向的 / 外向的', 'E/I', _scores!['E/I']!),
                  const SizedBox(height: 12),
                  _buildScoreBar('感覚的 / 直感的', 'N/S', _scores!['N/S']!),
                  const SizedBox(height: 12),
                  _buildScoreBar('感情型 / 思考型', 'T/F', _scores!['T/F']!),
                  const SizedBox(height: 12),
                  _buildScoreBar('柔軟的 / 計画的', 'J/P', _scores!['J/P']!),
                  const SizedBox(height: 12),
                  _buildScoreBar('慎重 / 自己主張的', 'A/T', _scores!['A/T']!),
                  const SizedBox(height: 24),

                  // 強み
                  _SectionTitle(
                    icon: Icons.star,
                    title: '強み',
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 16),
                  ..._personalityType!.strengths.map(
                    (strength) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              strength,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 弱み
                  _SectionTitle(
                    icon: Icons.warning,
                    title: '注意すべき点',
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  ..._personalityType!.weaknesses.map(
                    (weakness) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              weakness,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // メモの書き方のアドバイス
                  _SectionTitle(
                    icon: Icons.tips_and_updates,
                    title: 'メモの書き方のアドバイス',
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  ..._personalityType!.noteAdvice.map(
                    (advice) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb,
                            color: colorScheme.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              advice,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // アクションボタン
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _shareToTwitter,
                      icon: const Icon(Icons.share),
                      label: const Text('Twitterでシェア'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DA1F2), // Twitter blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.home),
                      label: const Text('ホームに戻る'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(String label, String axis, int score) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // スコアを0-100の範囲に正規化（-12から+12の範囲を想定）
    final normalizedScore = ((score + 12) / 24 * 100).clamp(0, 100).toInt();

    // 軸の左右ラベルを取得
    final parts = axis.split('/');
    final leftLabel = parts[1]; // 例: "I"（内向的）
    final rightLabel = parts[0]; // 例: "E"（外向的）

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$normalizedScore%',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: normalizedScore / 100,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  leftLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  rightLabel,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// セクションタイトル
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}
