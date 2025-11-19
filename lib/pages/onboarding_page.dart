import 'package:flutter/material.dart';
import '../main.dart';
import 'home_page.dart';
import '../utils/app_logger.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  bool _isLoading = false;
  bool _sampleNotesCreated = false;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'ようこそ！',
      description: 'マイメモへようこそ！\nこのアプリでは、メモを書くことが楽しくなるゲーミフィケーション機能が満載です。',
      icon: Icons.celebration,
      color: Colors.purple,
    ),
    OnboardingStep(
      title: 'ポイントを貯めよう',
      description: 'メモを作成したり、ログインしたりするとポイントがもらえます。\nポイントを貯めてレベルアップしましょう！',
      icon: Icons.stars,
      color: Colors.amber,
    ),
    OnboardingStep(
      title: 'アチーブメント解除',
      description: '様々な条件を達成すると、アチーブメントが解除されます。\n全てのアチーブメントを集めよう！',
      icon: Icons.emoji_events,
      color: Colors.orange,
    ),
    OnboardingStep(
      title: 'サンプルメモを作成',
      description: 'まずは練習として、サンプルメモを自動作成しましょう。',
      icon: Icons.note_add,
      color: Colors.blue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _markOnboardingStarted();
  }

  Future<void> _markOnboardingStarted() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Mark that user has started onboarding
      await supabase
          .from('user_stats')
          .update({
            'metadata': {'onboarding_started': true},
          })
          .eq('user_id', userId);
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to mark onboarding started',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _createSampleNotes() async {
    if (_sampleNotesCreated) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create sample category first
      final categoryResponse = await supabase
          .from('categories')
          .insert({
            'user_id': userId,
            'name': 'サンプル',
            'icon': '📝',
            'color': '#667eea',
          })
          .select()
          .single();

      final categoryId = categoryResponse['id'].toString();

      // Create sample notes
      final sampleNotes = [
        {
          'user_id': userId,
          'title': 'ようこそ！マイメモへ',
          'content': '''こんにちは！マイメモへようこそ。

このアプリでは、以下の機能が使えます：

📝 **メモ作成**: テキストや画像を自由に記録
⭐ **お気に入り**: 重要なメモをお気に入り登録
🔔 **リマインダー**: メモに期限を設定して通知
🏆 **ゲーミフィケーション**: ポイントを貯めてレベルアップ
🎯 **デイリーチャレンジ**: 毎日のミッションをクリア
👥 **コミュニティ**: 他のユーザーとつながる

さあ、メモを書き始めましょう！''',
          'category_id': categoryId,
          'is_favorite': true,
        },
        {
          'user_id': userId,
          'title': '今日のタスク',
          'content': '''✅ マイメモにサインアップ
⬜ サンプルメモを確認
⬜ 最初のメモを作成
⬜ プロフィールを設定
⬜ デイリーチャレンジに挑戦

このように、タスクリストを簡単に作成できます！''',
          'category_id': categoryId,
        },
        {
          'user_id': userId,
          'title': 'アイデアメモ',
          'content': '''💡 新しいアイデア

メモは自由に書けます。
箇条書きでも、長文でも、何でもOK！

【カテゴリ】
カテゴリを使ってメモを整理しましょう。

【リマインダー】
メモに期限を設定すれば、忘れることはありません。

【共有】
友達とメモを共有して、コラボレーションも可能です。''',
          'category_id': categoryId,
        },
      ];

      await supabase.from('notes').insert(sampleNotes);

      // Award points for completing onboarding
      // Update user_stats directly to award 100 points
      final statsResponse = await supabase
          .from('user_stats')
          .select('total_points')
          .eq('user_id', userId)
          .maybeSingle();

      if (statsResponse != null) {
        final currentPoints = statsResponse['total_points'] as int;
        await supabase
            .from('user_stats')
            .update({'total_points': currentPoints + 100})
            .eq('user_id', userId);
      }

      setState(() {
        _sampleNotesCreated = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('サンプルメモを作成しました！+100ポイント獲得！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to create sample notes',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: $e')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Mark onboarding as completed
      await supabase
          .from('user_stats')
          .update({
            'metadata': {
              'onboarding_completed': true,
              'onboarding_completed_at': DateTime.now().toIso8601String(),
            },
          })
          .eq('user_id', userId);

      // Navigate to home page
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to complete onboarding',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == _steps.length - 1) {
      // Last step: create sample notes
      _createSampleNotes();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _skipOnboarding() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('オンボーディングをスキップ'),
        content: const Text('本当にスキップしますか？\nサンプルメモと100ポイントの報酬を逃すことになります。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _completeOnboarding();
            },
            child: const Text('スキップ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(currentStepData.color),
            ),
            // Skip button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ステップ ${_currentStep + 1}/${_steps.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: const Text('スキップ'),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: currentStepData.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        currentStepData.icon,
                        size: 64,
                        color: currentStepData.color,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Title
                    Text(
                      currentStepData.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Description
                    Text(
                      currentStepData.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Show loading indicator or success message on last step
                    if (_currentStep == _steps.length - 1) ...[
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else if (_sampleNotesCreated)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'サンプルメモ作成完了！',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('戻る'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_sampleNotesCreated
                                ? _completeOnboarding
                                : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentStepData.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _sampleNotesCreated
                            ? '完了'
                            : (_currentStep == _steps.length - 1
                                  ? 'サンプルメモを作成'
                                  : '次へ'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
