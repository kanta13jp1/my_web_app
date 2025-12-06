import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_page.dart';
import 'home_page.dart';
import '../widgets/live_stats_banner.dart';
import '../widgets/page_view_stats.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoading = false;

  Future<void> _signInAnonymously() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.signInAnonymously();

      if (mounted) {
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
      // 🚀 施策2: スクロールしても常に表示される「追従型CTAボタン」を追加
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _signInAnonymously,
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.rocket_launch),
              label: const Text(
                '登録不要で試す',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

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
                              // 🚀 施策1: 「ゲスト利用」を最上位に配置し、色を変えて目立たせる
                              if (_isLoading)
                                const CircularProgressIndicator(
                                    color: Colors.white)
                              else
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: _signInAnonymously,
                                    style: ElevatedButton.styleFrom(
                                      // アクセントカラー（オレンジ）を使用して注目を集める
                                      backgroundColor: Colors.orange.shade400,
                                      foregroundColor: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.flash_on),
                                    label: const Text(
                                      '登録不要で今すぐ使う',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),

                              // アカウント作成（長期利用向け）は2番手に
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
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'アカウントを作成して保存',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ログインはテキストリンクへ（既存ユーザー向けなので控えめに）
                              TextButton(
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
                                child: const Text(
                                  'すでにアカウントをお持ちの方はこちら',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
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
                            child: ElevatedButton.icon(
                              onPressed: _signInAnonymously,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade400,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.flash_on),
                              label: const Text(
                                '登録不要で今すぐ使う',
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
