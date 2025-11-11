import 'package:flutter/material.dart';
import '../services/personality_test_service.dart';
import 'personality_test_questions_page.dart';

/// 性格診断の開始ページ
class PersonalityTestLandingPage extends StatelessWidget {
  const PersonalityTestLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('性格診断'),
        elevation: 0,
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
                  Icon(
                    Icons.psychology,
                    size: 80,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'あなたの性格タイプを診断',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'メモの書き方から性格がわかる！',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // 機能紹介セクション
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _FeatureCard(
                    icon: Icons.timer,
                    title: 'たった5分で完了',
                    description: '60問の質問に答えるだけで、あなたの性格タイプがわかります',
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    icon: Icons.auto_awesome,
                    title: '16種類の性格タイプ',
                    description: 'MBTI準拠の科学的な性格分類で、あなたの特徴を詳しく分析',
                    color: colorScheme.secondary,
                  ),
                  const SizedBox(height: 16),
                  _FeatureCard(
                    icon: Icons.article,
                    title: '詳細な分析レポート',
                    description: '強み・弱み・メモの書き方のアドバイスを提供',
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(height: 32),

                  // 診断開始ボタン
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _startTest(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '診断を開始する（無料）',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 注意事項
                  Text(
                    '※ 診断結果は統計的な分類であり、個人を完全に特定するものではありません',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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

  Future<void> _startTest(BuildContext context) async {
    try {
      // ローディング表示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // テストを開始
      final service = PersonalityTestService();
      final test = await service.startTest();

      // ローディングを閉じる
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // 質問ページに遷移
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PersonalityTestQuestionsPage(testId: test.id),
          ),
        );
      }
    } catch (e) {
      // エラー処理
      if (context.mounted) {
        Navigator.of(context).pop(); // ローディングを閉じる
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('診断の開始に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// 機能カード
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
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
}
