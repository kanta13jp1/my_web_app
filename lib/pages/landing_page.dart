import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';

// Authモードの定義
enum AuthMode { signIn, signUp }

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logLandingView();
  }

  // 訪問数をカウントする関数 (流入元解析付き)
  Future<void> _logLandingView() async {
    try {
      final uri = Uri.base;
      final source = uri.queryParameters['ref'] ?? 'direct';

      await Supabase.instance.client.rpc('increment_landing_view', params: {
        'source_name': source,
      });
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  // コンバージョン（登録）をカウントする関数
  Future<void> _logConversion() async {
    try {
      await Supabase.instance.client.rpc('increment_conversion');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------
  // 認証ロジック
  // ----------------------------------------------------------------

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInAnonymously();

      await _logConversion();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ゲストログインエラー: $e'), backgroundColor: Colors.red),
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
      final supabase = Supabase.instance.client;
      if (mode == AuthMode.signUp) {
        final response = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (response.session == null && response.user != null) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('確認メールを送信しました。'),
                  backgroundColor: Colors.green),
            );
          }
          return;
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }

      if (mounted && supabase.auth.currentUser != null) {
        await _logConversion();

        Navigator.pop(context);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
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

  void _showAuthBottomSheet(BuildContext context, AuthMode initialMode) {
    AuthMode currentMode = initialMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isSignUp = currentMode == AuthMode.signUp;
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.white.withOpacity(0.9),
                  padding: EdgeInsets.only(
                      top: 24, left: 24, right: 24, bottom: bottomPadding + 24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isSignUp ? 'アカウント作成' : 'ログイン',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: 'メールアドレス',
                              border: OutlineInputBorder()),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                              labelText: 'パスワード', border: OutlineInputBorder()),
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : () => _handleEmailAuth(
                                    currentMode, setModalState),
                            child: _isLoading
                                ? const CircularProgressIndicator()
                                : Text(isSignUp ? '登録' : 'ログイン'),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(() => currentMode =
                              isSignUp ? AuthMode.signIn : AuthMode.signUp),
                          child: Text(isSignUp ? 'ログインへ切り替え' : '新規登録へ切り替え'),
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
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                //  ブランドカラー: ストラテジックネイビー & ゴールドの気配
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business_center, // アイコンもビジネス仕様に変更
                      size: 80,
                      color: Color(0xFFD4AF37)), // ゴールド
                  const SizedBox(height: 24),
                  const Text('自分株式会社', //  My Memo -> 自分株式会社
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0)),
                  const SizedBox(height: 12),
                  const Text('人生を経営する、最強のOS。', //  サブタイトル刷新
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 60),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _signInAnonymously,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37), // ゴールド
                          foregroundColor: const Color(0xFF0F172A)), // ネイビー
                      child: const Text('経営を開始する (登録不要)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        _showAuthBottomSheet(context, AuthMode.signIn),
                    child: const Text('ログイン / 登録',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
