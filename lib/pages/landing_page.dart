import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // supabase変数へのアクセスのため
import 'home_page.dart';
import 'onboarding_page.dart'; // オンボーディング遷移用
import '../services/referral_service.dart';
import '../services/daily_login_service.dart';
import '../utils/app_logger.dart';
import '../widgets/live_stats_banner.dart';
import '../widgets/page_view_stats.dart';

// Authモードの定義
enum AuthMode { signIn, signUp }

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '');

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoading = false;

  // Auth用のコントローラーとサービス
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  late ReferralService _referralService;
  late DailyLoginService _dailyLoginService;

  @override
  void initState() {
    super.initState();
    _referralService = ReferralService(supabase);
    _dailyLoginService = DailyLoginService(supabase);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 認証ロジック (AuthPageから移植)
  // ----------------------------------------------------------------

  Future<bool> _shouldShowOnboarding(String userId) async {
    try {
      final response = await supabase
          .from('user_stats')
          .select('metadata')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return true; // New user

      final metadata = response['metadata'] as Map<String, dynamic>?;
      final onboardingCompleted = metadata?['onboarding_completed'] as bool?;
      return onboardingCompleted != true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check onboarding status',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // ゲストログイン処理
  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
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
              content: Text('ゲストログインに失敗しました: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // メールアドレス認証処理 (Login / SignUp)
  Future<void> _handleEmailAuth(
      AuthMode mode, StateSetter modalSetState) async {
    // モーダル内のローディング表示のために modalSetState を使用する可能性あり
    // 今回は全体の _isLoading を使用し、親Widgetを再描画させる
    setState(() => _isLoading = true);
    // モーダル側も再描画
    modalSetState(() {});

    try {
      final isSignUp = mode == AuthMode.signUp;

      if (isSignUp) {
        // --- サインアップ ---
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final userId = response.user?.id;

        // 紹介コード適用
        if (userId != null && _referralCodeController.text.trim().isNotEmpty) {
          try {
            await _referralService.applyReferralCode(
              userId,
              _referralCodeController.text.trim(),
            );
          } catch (e) {
            AppLogger.error('Referral code error', error: e);
          }
        }

        // ウェルカムボーナス (500pt)
        if (userId != null) {
          try {
            final stats = await supabase
                .from('user_stats')
                .select('total_points')
                .eq('user_id', userId)
                .maybeSingle();
            if (stats != null) {
              final currentPoints = stats['total_points'] as int;
              await supabase.from('user_stats').update(
                  {'total_points': currentPoints + 500}).eq('user_id', userId);
            }
          } catch (e) {
            AppLogger.error('Welcome bonus error', error: e);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('確認メールを送信しました。'), backgroundColor: Colors.green),
          );
          Navigator.pop(context); // モーダルを閉じる
        }
      } else {
        // --- ログイン ---
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final userId = supabase.auth.currentUser?.id;

        // デイリーボーナス確認
        if (userId != null) {
          try {
            final bonus = await _dailyLoginService.checkDailyLoginBonus(userId);
            if (bonus != null && bonus['is_new_bonus'] == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('デイリーボーナス！+${bonus['bonus_points']}ポイント'),
                  backgroundColor: Colors.amber,
                ),
              );
            }
          } catch (e) {
            AppLogger.error('Daily login error', error: e);
          }
        }

        // 画面遷移判定
        if (mounted && userId != null) {
          final shouldShowOnboarding = await _shouldShowOnboarding(userId);
          if (!mounted) return;

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => shouldShowOnboarding
                  ? const OnboardingPage()
                  : const HomePage(),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        modalSetState(() {});
      }
    }
  }

  // ----------------------------------------------------------------
  // UI コンポーネント
  // ----------------------------------------------------------------

  // ログイン/登録用のボトムシートを表示
  void _showAuthBottomSheet(BuildContext context, AuthMode initialMode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 全画面近くまで広げられるように
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        // シート内でState管理（ログイン/サインアップの切り替え）をするためにStatefulBuilderを使用
        return StatefulBuilder(
          builder: (context, setModalState) {
            var currentMode = initialMode;
            final isSignUp = currentMode == AuthMode.signUp;
            final theme = Theme.of(context);
            // キーボード分padding確保
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(
                top: 24,
                left: 24,
                right: 24,
                bottom: bottomPadding + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ハンドルバー
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // タイトル
                    Text(
                      isSignUp ? 'アカウント作成' : 'ログイン',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // メールアドレス
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'メールアドレス',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // パスワード
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'パスワード',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.all(Radius.circular(12))),
                      ),
                      obscureText: true,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),

                    // 紹介コード (サインアップ時のみ)
                    if (isSignUp) ...[
                      TextField(
                        controller: _referralCodeController,
                        decoration: const InputDecoration(
                          labelText: '紹介コード (任意)',
                          prefixIcon: Icon(Icons.card_giftcard),
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(12))),
                          filled: true,
                          fillColor: Color(0xFFFFF8E1), // 薄いアンバー
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 8),
                      // 紹介コード特典メッセージ
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                size: 16, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Text(
                              'コード入力でボーナスポイント獲得！',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ] else ...[
                      const SizedBox(height: 24),
                    ],

                    // アクションボタン
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () =>
                                _handleEmailAuth(currentMode, setModalState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(isSignUp ? '登録して始める' : 'ログイン',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // モード切り替えボタン
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setModalState(() {
                                initialMode = isSignUp
                                    ? AuthMode.signIn
                                    : AuthMode.signUp;
                                // コントローラーのクリアなどは任意で
                              });
                            },
                      child: Text(
                        isSignUp ? 'すでにアカウントをお持ちの方はログイン' : 'アカウントをお持ちでない方は新規登録',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 常に表示されるゲストログインボタン
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: _signInAnonymously,
              backgroundColor: Colors.amber.shade700,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.rocket_launch),
              label: const Text(
                '登録不要で試す (ゲスト)',
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
                        // アイコン
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  spreadRadius: 5),
                            ],
                          ),
                          child: const Icon(Icons.note_alt_outlined,
                              size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        // タイトル
                        const Text(
                          'マイメモ',
                          style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ゲーミフィケーションで楽しく続けられる\nメモアプリ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, color: Colors.white, height: 1.5),
                        ),
                        const SizedBox(height: 40),

                        // メインアクションエリア
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 400),
                          child: Column(
                            children: [
                              // アカウント作成ボタン -> モーダル起動
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAuthBottomSheet(
                                      context, AuthMode.signUp),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: theme.primaryColor,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.mail_outline),
                                  label: const Text('メールアドレスで登録・ログイン',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ライブ統計など
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: const LiveStatsBanner(),
                        ),
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

          // Features Section (既存のまま)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Text('特徴',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 32),
                  const _FeatureCard(
                      icon: Icons.emoji_events,
                      iconColor: Colors.amber,
                      title: 'レベルアップシステム',
                      description: 'メモを書くほどレベルアップ！\n経験値とポイントを獲得して成長しよう'),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                      icon: Icons.military_tech,
                      iconColor: Colors.purple,
                      title: '28種類以上の達成項目',
                      description: '様々なチャレンジをクリアして\n実績を解除しよう'),
                  const SizedBox(height: 16),
                  const _FeatureCard(
                      icon: Icons.leaderboard,
                      iconColor: Colors.blue,
                      title: 'リーダーボード',
                      description: '他のユーザーと競い合って\nトップを目指そう'),
                  const SizedBox(height: 60),
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

  const _FeatureCard(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.description});

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
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey[600], height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
