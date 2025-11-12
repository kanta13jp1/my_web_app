import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/personality_test_service.dart';
import '../services/compatibility_service.dart';
import '../models/compatibility_match.dart';
import '../models/personality_test.dart';

/// 恋愛相性診断の結果表示ページ
class CompatibilityResultPage extends StatefulWidget {
  final String myType;
  final String partnerType;

  const CompatibilityResultPage({
    Key? key,
    required this.myType,
    required this.partnerType,
  }) : super(key: key);

  @override
  State<CompatibilityResultPage> createState() =>
      _CompatibilityResultPageState();
}

class _CompatibilityResultPageState extends State<CompatibilityResultPage>
    with SingleTickerProviderStateMixin {
  final CompatibilityService _compatibilityService = CompatibilityService();
  late CompatibilityMatch _compatibilityMatch;
  late AnimationController _animationController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _compatibilityMatch = _compatibilityService.calculateCompatibility(
      widget.myType,
      widget.partnerType,
    );

    // スコアアニメーション
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scoreAnimation = Tween<double>(
      begin: 0,
      end: _compatibilityMatch.compatibilityScore.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _shareOnTwitter() async {
    final text = '''🎯 MBTI恋愛相性診断の結果

${widget.myType} × ${widget.partnerType}
相性スコア: ${_compatibilityMatch.compatibilityScore}点
${_compatibilityMatch.compatibilityLevel == 'excellent' ? '💖 最高の相性！' : _compatibilityMatch.compatibilityLevel == 'good' ? '💕 良い相性' : _compatibilityMatch.compatibilityLevel == 'fair' ? '💛 まずまずの相性' : '💪 チャレンジングな相性'}

あなたも診断してみよう！
#MBTI #恋愛相性診断 #性格診断''';

    final url = Uri.encodeFull(
        'https://twitter.com/intent/tweet?text=$text&url=https://your-app-url.com');
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Twitterを開けませんでした')),
        );
      }
    }
  }

  Future<void> _copyToClipboard() async {
    final text = '''MBTI恋愛相性診断の結果

${widget.myType} × ${widget.partnerType}
相性スコア: ${_compatibilityMatch.compatibilityScore}点
相性レベル: ${_compatibilityMatch.getCompatibilityLevelJa()}

${_compatibilityMatch.description}''';

    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クリップボードにコピーしました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相性診断結果'),
        backgroundColor: Colors.pink.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareOnTwitter,
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー（2つのタイプ）
              _buildTypesHeader(),
              const SizedBox(height: 24),

              // 相性スコア
              _buildScoreCard(),
              const SizedBox(height: 24),

              // タイトルと説明
              _buildDescriptionCard(),
              const SizedBox(height: 24),

              // 強み
              _buildStrengthsCard(),
              const SizedBox(height: 16),

              // 課題
              _buildChallengesCard(),
              const SizedBox(height: 16),

              // アドバイス
              _buildTipsCard(),
              const SizedBox(height: 32),

              // アクションボタン
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypesHeader() {
    final myPersonalityType =
        PersonalityTestService.personalityTypes.firstWhere(
      (t) => t.code == widget.myType,
      orElse: () => PersonalityTestService.personalityTypes[0],
    );

    final partnerPersonalityType =
        PersonalityTestService.personalityTypes.firstWhere(
      (t) => t.code == widget.partnerType,
      orElse: () => PersonalityTestService.personalityTypes[0],
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade50, Colors.pink.shade50],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // あなたのタイプ
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'あなた',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.myType,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.blue.shade900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    myPersonalityType.nameJa,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // ハートアイコン
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(
                Icons.favorite,
                size: 32,
                color: Colors.pink.shade400,
              ),
            ),

            // 相手のタイプ
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '相手',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.pink.shade900,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.partnerType,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.pink.shade900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partnerPersonalityType.nameJa,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink.shade50,
              Colors.white,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              '相性スコア',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
            ),
            const SizedBox(height: 16),

            // アニメーション付きスコア表示
            AnimatedBuilder(
              animation: _scoreAnimation,
              builder: (context, child) {
                return Column(
                  children: [
                    Text(
                      '${_scoreAnimation.value.round()}',
                      style:
                          Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.pink.shade700,
                                fontSize: 72,
                              ),
                    ),
                    Text(
                      '/ 100',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // 相性レベル
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Color(int.parse(
                    _compatibilityMatch.getCompatibilityColor().substring(1),
                    radix: 16) + 0xFF000000).withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Color(int.parse(
                      _compatibilityMatch.getCompatibilityColor().substring(1),
                      radix: 16) + 0xFF000000),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _compatibilityMatch.getCompatibilityEmoji(),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _compatibilityMatch.getCompatibilityLevelJa(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Color(int.parse(_compatibilityMatch
                                  .getCompatibilityColor()
                                  .substring(1),
                              radix: 16) + 0xFF000000),
                        ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // プログレスバー
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _compatibilityMatch.compatibilityScore / 100,
                minHeight: 12,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.pink.shade400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Text(
                  _compatibilityMatch.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _compatibilityMatch.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: Colors.grey.shade800,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStrengthsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade700),
                const SizedBox(width: 8),
                Text(
                  '関係性の強み',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._compatibilityMatch.strengths.map((strength) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        strength,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '乗り越えるべき課題',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._compatibilityMatch.challenges.map((challenge) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        challenge,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '関係を深めるヒント',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._compatibilityMatch.tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tips_and_updates,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tip,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Twitterシェアボタン
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _shareOnTwitter,
            icon: const Icon(Icons.share, size: 24),
            label: const Text(
              'Twitterでシェア',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1DA1F2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 別の相性を診断
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.refresh, size: 24),
            label: const Text(
              '別の相性を診断',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.pink.shade700,
              side: BorderSide(color: Colors.pink.shade300, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
