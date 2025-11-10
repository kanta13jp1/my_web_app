import 'package:flutter/material.dart';
import '../main.dart';
import 'home_page.dart';
import 'onboarding_page.dart';
import '../services/referral_service.dart';
import '../services/daily_login_service.dart';
import '../utils/app_logger.dart';

enum AuthMode { signIn, signUp }

class AuthPage extends StatefulWidget {
  final AuthMode initialMode;
  final String? referralCode;

  const AuthPage({
    super.key,
    this.initialMode = AuthMode.signIn,
    this.referralCode,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _isLoading = false;
  late bool _isSignUp;
  late ReferralService _referralService;
  late DailyLoginService _dailyLoginService;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialMode == AuthMode.signUp;
    _referralService = ReferralService(supabase);
    _dailyLoginService = DailyLoginService(supabase);

    // If referral code is provided, pre-fill it
    if (widget.referralCode != null) {
      _referralCodeController.text = widget.referralCode!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<bool> _shouldShowOnboarding(String userId) async {
    try {
      final response = await supabase
          .from('user_stats')
          .select('metadata')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // New user, show onboarding
        return true;
      }

      final metadata = response['metadata'] as Map<String, dynamic>?;
      final onboardingCompleted = metadata?['onboarding_completed'] as bool?;

      // Show onboarding if not completed
      return onboardingCompleted != true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to check onboarding status', error: e, stackTrace: stackTrace);
      // Default to not showing onboarding on error
      return false;
    }
  }

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSignUp) {
        // サインアップ
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final userId = response.user?.id;

        // Apply referral code if provided
        if (userId != null && _referralCodeController.text.trim().isNotEmpty) {
          try {
            final success = await _referralService.applyReferralCode(
              userId,
              _referralCodeController.text.trim(),
            );

            if (success) {
              AppLogger.info('Referral code applied successfully');
            }
          } catch (e, stackTrace) {
            AppLogger.error('Failed to apply referral code', error: e, stackTrace: stackTrace);
          }
        }

        // Award welcome bonus (500 points)
        if (userId != null) {
          try {
            final stats = await supabase
                .from('user_stats')
                .select('total_points')
                .eq('user_id', userId)
                .maybeSingle();

            if (stats != null) {
              final currentPoints = stats['total_points'] as int;
              await supabase
                  .from('user_stats')
                  .update({'total_points': currentPoints + 500})
                  .eq('user_id', userId);

              AppLogger.info('Welcome bonus awarded: 500 points');
            }
          } catch (e, stackTrace) {
            AppLogger.error('Failed to award welcome bonus', error: e, stackTrace: stackTrace);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('確認メールを送信しました。ウェルカムボーナス500ポイント獲得！'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // ログイン
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Check and award daily login bonus
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          try {
            final bonus = await _dailyLoginService.checkDailyLoginBonus(userId);

            if (bonus != null && bonus['is_new_bonus'] == true) {
              final consecutiveDays = bonus['consecutive_days'] as int;
              final bonusPoints = bonus['bonus_points'] as int;

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'デイリーログインボーナス！+$bonusPointsポイント ($consecutiveDays日連続)',
                    ),
                    backgroundColor: Colors.amber,
                  ),
                );
              }
            }
          } catch (e, stackTrace) {
            AppLogger.error('Failed to check daily login bonus', error: e, stackTrace: stackTrace);
          }
        }

        // Check if user has completed onboarding
        if (mounted && userId != null) {
          final shouldShowOnboarding = await _shouldShowOnboarding(userId);

          // Re-check mounted after async operation
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
          SnackBar(
            content: Text('エラー: $error'),
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
      appBar: AppBar(
        title: Text(_isSignUp ? 'サインアップ' : 'ログイン'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon & Title
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor,
                        theme.primaryColor.withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.note_alt_outlined,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'マイメモ',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? 'アカウントを作成してゲーミフィケーションの世界へ'
                      : 'メモを書いてレベルアップしよう',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Benefits (for SignUp)
                if (_isSignUp) ...[
                  Card(
                    elevation: 0,
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBenefit(Icons.emoji_events, 'レベルアップシステム', theme),
                          const SizedBox(height: 8),
                          _buildBenefit(Icons.military_tech, '28種類以上の達成項目', theme),
                          const SizedBox(height: 8),
                          _buildBenefit(Icons.leaderboard, 'リーダーボードで競争', theme),
                          const SizedBox(height: 8),
                          _buildBenefit(Icons.local_fire_department, '連続記録でストリーク', theme),
                          const SizedBox(height: 8),
                          _buildBenefit(Icons.card_giftcard, '新規登録で500ポイント', theme),
                          const SizedBox(height: 8),
                          _buildBenefit(Icons.celebration, 'デイリーログインボーナス', theme),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Email Field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'メールアドレス',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: theme.brightness == Brightness.light
                        ? Colors.grey[50]
                        : Colors.grey[900],
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'パスワード',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: theme.brightness == Brightness.light
                        ? Colors.grey[50]
                        : Colors.grey[900],
                  ),
                  obscureText: true,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),

                // Referral Code Field (only for sign up)
                if (_isSignUp) ...[
                  TextField(
                    controller: _referralCodeController,
                    decoration: InputDecoration(
                      labelText: '紹介コード (任意)',
                      hintText: '友達から受け取ったコードを入力',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      prefixIcon: const Icon(Icons.card_giftcard),
                      suffixIcon: const Icon(Icons.stars, color: Colors.amber),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? Colors.amber[50]
                          : Colors.grey[900],
                    ),
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.green[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '紹介コード入力でボーナスポイント獲得！',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _isSignUp ? '無料で始める' : 'ログイン',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                // Toggle Sign In/Up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isSignUp
                          ? 'すでにアカウントをお持ちですか？'
                          : 'アカウントをお持ちでないですか？',
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                              });
                            },
                      child: Text(
                        _isSignUp ? 'ログイン' : 'サインアップ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.primaryColor,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}