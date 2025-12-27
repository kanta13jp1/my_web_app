import 'dart:ui'; // 追加: グラスモーフィズム用
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import 'home_page.dart';
import 'onboarding_page.dart';
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

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;

  // アニメーション用
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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

    // アニメーション初期化
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuad),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 認証ロジック (変更なし)
  // ----------------------------------------------------------------

  Future<bool> _shouldShowOnboarding(String userId) async {
    try {
      final response = await supabase
          .from('user_stats')
          .select('metadata')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return true;

      final metadata = response['metadata'] as Map<String, dynamic>?;
      final onboardingCompleted = metadata?['onboarding_completed'] as bool?;
      return onboardingCompleted != true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check onboarding status',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

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
            content: Text('ゲストログインに失敗しました: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating, // モダンなスタイル
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailAuth(
      AuthMode mode, StateSetter modalSetState) async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスとパスワードを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);
    modalSetState(() {});

    try {
      final isSignUp = mode == AuthMode.signUp;

      if (isSignUp) {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        final userId = response.user?.id;

        if (response.session == null && userId != null) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('確認メールを送信しました。リンクをクリックして登録を完了してください。'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 6),
              ),
            );
          }
          return;
        }

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

        if (userId != null) {
          try {
            await Future.delayed(const Duration(milliseconds: 500));
            final stats = await supabase
                .from('user_stats')
                .select('total_points')
                .eq('user_id', userId)
                .maybeSingle();

            if (stats != null) {
              final currentPoints = (stats['total_points'] as int?) ?? 0;
              await supabase.from('user_stats').update(
                {'total_points': currentPoints + 500},
              ).eq('user_id', userId);
            }
          } catch (e) {
            AppLogger.error('Welcome bonus error', error: e);
          }
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final userId = supabase.auth.currentUser?.id;
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
      }

      final userId = supabase.auth.currentUser?.id;
      if (mounted && userId != null) {
        final shouldShowOnboarding = await _shouldShowOnboarding(userId);
        if (!mounted) return;

        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => shouldShowOnboarding
                ? const OnboardingPage()
                : const HomePage(),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
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
        try {
          modalSetState(() {});
        } catch (_) {}
      }
    }
  }

  // ----------------------------------------------------------------
  // UI コンポーネント
  // ----------------------------------------------------------------

  void _showAuthBottomSheet(BuildContext context, AuthMode initialMode) {
    AuthMode currentMode = initialMode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // グラスモーフィズムのため透明に
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSignUp = currentMode == AuthMode.signUp;
            final theme = Theme.of(context);
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.9),
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
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isSignUp ? 'アカウント作成' : 'ログイン',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'メールアドレス',
                            prefixIcon: Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12))),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'パスワード',
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: const OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12))),
                            filled: true,
                            fillColor: Colors.white,
                            helperText: isSignUp ? '6文字以上' : null,
                          ),
                          obscureText: true,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
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
                              fillColor: Color(0xFFFFF8E1),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _handleEmailAuth(
                                    currentMode, setModalState),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Text(
                                    isSignUp ? '登録して始める' : 'ログイン',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setModalState(() {
                                    currentMode = isSignUp
                                        ? AuthMode.signIn
                                        : AuthMode.signUp;
                                  });
                                },
                          child: Text(
                            isSignUp
                                ? 'すでにアカウントをお持ちの方はログイン'
                                : 'アカウントをお持ちでない方は新規登録',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
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
      // FABは削除しました。メインCTAは画面中央にあります。
      body: Stack(
        children: [
          // 背景：グラデーションとパターン
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.primaryColor.withOpacity(0.9),
                    Colors.indigo.shade900,
                  ],
                ),
              ),
            ),
          ),

          // 装飾的な円形（背景アクセント）
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.2), // 影の色
                    blurRadius: 50, // ✅ BoxShadowの中で指定します
                    spreadRadius: 20, // ぼかしの広がり
                  ),
                ],
              ),
            ),
          ),

          // メインコンテンツ
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      // ✅ 変更点1: SliverToBoxAdapterにする
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // ✅ 変更点2: 最低でも画面の高さを確保（はみ出たら伸びる）
                          minHeight: MediaQuery.of(context).size.height,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center, // ✅ 上下中央寄せ
                            children: [
                              // ✅ 変更点3: Spacer()を削除し、固定の余白に変更
                              const SizedBox(height: 80), // 上部の余白

                              // 1. ロゴとタイトル
                              _buildHeroHeader(),

                              const SizedBox(height: 48),

                              // 2. メインCTA: ゲストログイン
                              _buildPrimaryButton(),

                              const SizedBox(height: 16),

                              // 3. サブCTA: メールログイン
                              _buildSecondaryButton(),

                              const SizedBox(height: 60), // 中央の余白

                              // 4. ソーシャルプルーフ（統計情報）
                              _buildGlassStats(),

                              const SizedBox(height: 40),

                              // 5. 特徴セクションへの誘導
                              const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white54, size: 30),
                              const Text("スクロールして詳細を見る",
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 12)),

                              const SizedBox(height: 40), // 下部の余白
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 特徴セクション（下部に続く）
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(24.0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(height: 40),
                            Text(
                              'ゲーム感覚で、\n毎日がもっと楽しくなる。',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 40),
                            const _FeatureCard(
                              icon: Icons.rocket_launch_rounded,
                              iconColor: Colors.amber,
                              title: 'レベルアップ',
                              description: 'メモを書くほど経験値ゲット。\nあなたの成長を可視化します。',
                            ),
                            const SizedBox(height: 16),
                            const _FeatureCard(
                              icon: Icons.emoji_events_rounded,
                              iconColor: Colors.purple,
                              title: '実績システム',
                              description: '「3日連続記録」など、\n28種類以上のバッジを集めよう。',
                            ),
                            const SizedBox(height: 16),
                            const _FeatureCard(
                              icon: Icons.bar_chart_rounded,
                              iconColor: Colors.blue,
                              title: 'みんなと競争',
                              description: 'リーダーボードで上位を目指して\nモチベーション維持。',
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ローディングインジケーター
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.note_alt_outlined,
            size: 64,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'My Memo',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '書くことが、冒険になる。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 64, // 大きく押しやすく
      child: ElevatedButton(
        onPressed: _signInAnonymously,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '今すぐ始める',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return TextButton(
      onPressed: () => _showAuthBottomSheet(context, AuthMode.signIn),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.login, size: 18),
          const SizedBox(width: 8),
          // ✅ Flexibleで囲むことで、幅が足りないときに自動で折り返すようになる
          Flexible(
            child: Text(
              'すでにアカウントをお持ちの方はこちら',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.9),
              ),
              // 必要に応じて省略記号を出すなら: overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassStats() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const LiveStatsBanner(), // 既存のウィジェットを再利用
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              const SizedBox(height: 16),
              const PageViewStats(), // 既存のウィジェットを再利用
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 30, color: iconColor),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
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
    );
  }
}
