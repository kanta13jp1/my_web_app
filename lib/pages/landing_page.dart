import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 追加
import 'auth_page.dart';
import 'home_page.dart'; // 👈 LeaderboardPageの代わりにHomePageへ遷移するため
import '../widgets/live_stats_banner.dart';
import '../widgets/page_view_stats.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  // ビルド時に注入されたバージョンを取得
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoading = false; // ローディング状態管理

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 匿名ログイン実行
      await Supabase.instance.client.auth.signInAnonymously();

      if (mounted) {
        // ホーム画面へ遷移（戻れないようにpushReplacement）
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ゲストログインに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverToBoxAdapter(
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withValues(alpha: 0.7),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // App Icon
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.note_alt_outlined,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          'マイメモ',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        const Text(
                          'ゲーミフィケーションで楽しく続けられる\nメモアプリ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // CTA Buttons
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AuthPage(
                                          initialMode: AuthMode.signUp,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: theme.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    '無料で始める',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const AuthPage(
                                          initialMode: AuthMode.signIn,
                                        ),
                                      ),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'ログイン',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // 👇 ここを修正: ゲストログインボタン
                              if (_isLoading)
                                const CircularProgressIndicator(
                                    color: Colors.white)
                              else
                                TextButton(
                                  onPressed: _signInAnonymously,
                                  child: const Text(
                                    'ゲストとしてメモを書く →',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Live Stats Banner
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: const LiveStatsBanner(),
                        ),

                        // Page View Stats
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const PageViewStats(),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Features Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text(
                    '特徴',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Feature Cards
                  const _FeatureCard(
                    icon: Icons.emoji_events,
                    iconColor: Colors.amber,
                    title: 'レベルアップシステム',
                    description: 'メモを書くほどレベルアップ！\n経験値とポイントを獲得して成長しよう',
                  ),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                    icon: Icons.military_tech,
                    iconColor: Colors.purple,
                    title: '28種類以上の達成項目',
                    description: '様々なチャレンジをクリアして\n実績を解除しよう',
                  ),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                    icon: Icons.leaderboard,
                    iconColor: Colors.blue,
                    title: 'リーダーボード',
                    description: '他のユーザーと競い合って\nトップを目指そう',
                  ),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orange,
                    title: '連続記録',
                    description: '毎日メモを書いて\nストリークを維持しよう',
                  ),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                    icon: Icons.folder_special,
                    iconColor: Colors.teal,
                    title: 'カテゴリ管理',
                    description: 'メモをカテゴリで整理して\n効率的に管理',
                  ),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                    icon: Icons.share,
                    iconColor: Colors.green,
                    title: 'メモ共有',
                    description: 'メモをリンクで簡単共有\nSNSへの投稿も可能',
                  ),

                  const SizedBox(height: 60),

                  // Bottom CTA
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor.withValues(alpha: 0.1),
                          theme.primaryColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '今すぐ始めよう！',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'メモを書きながらレベルアップ\n達成項目を解除して報酬をゲット',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AuthPage(
                                      initialMode: AuthMode.signUp,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '無料で始める',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // バージョン情報
                  if (LandingPage.appVersion.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'v${LandingPage.appVersion}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
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
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.5,
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
