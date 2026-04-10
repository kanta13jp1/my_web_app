import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/growth_acquisition_service.dart';
import '../services/growth_mission_service.dart';
import '../services/landing_page_adapter.dart';
import '../widgets/live_growth_banner.dart';

class LandingPage extends StatefulWidget {
  final LandingPageAdapter adapter;
  final GrowthMissionService growthService;

  const LandingPage({
    super.key,
    LandingPageAdapter? adapter,
    GrowthMissionService? growthService,
  })  : adapter = adapter ?? const SupabaseLandingPageAdapter(),
        growthService = growthService ?? const GrowthMissionService();

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  static const bool _googleLoginFeatureEnabled = bool.fromEnvironment(
    'LANDING_GOOGLE_LOGIN_ENABLED',
    defaultValue: false,
  );

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _trialPromptController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final GlobalKey _trialSectionKey = GlobalKey();
  final GlobalKey _authSectionKey = GlobalKey();
  final GrowthAcquisitionService _acquisitionService =
      const GrowthAcquisitionService();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _magicLinkCooldownTimer;

  bool _isLoading = false;
  bool _isTrialLoading = false;
  bool _isSignUp = true;
  bool _obscurePassword = true;
  bool _showSaveCtaPrompt = false;
  bool _showInboxShortcut = false;
  int _magicLinkCooldownSeconds = 0;
  int _achievementCount = 0;
  int _totalUsers = 0;
  int _publicMemoCount = 0;
  List<Map<String, String>> _recentAchievements = [];

  String? _trialAction;
  String? _trialReason;
  String? _lastMagicLinkEmail;
  String? _pendingReferralCode;

  SupabaseClient? get _supabaseClientOrNull {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.adapter.authStateChanges().listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        unawaited(widget.growthService.applyPendingReferralIfPossible());
        _goToAuthenticatedEntry();
      }
    });
    unawaited(_bootstrapReferralInvite());
    unawaited(_loadAchievementCount());
    unawaited(_loadSocialProofStats());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _magicLinkCooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _trialPromptController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String? get _webRedirectUrl {
    if (!kIsWeb) return null;
    return Uri.base.resolve('/').toString();
  }

  void _goToAuthenticatedEntry() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  Future<void> _bootstrapReferralInvite() async {
    await widget.growthService.capturePendingReferralFromUri();
    final pendingReferralCode =
        await widget.growthService.loadPendingReferralCode();
    if (!mounted) {
      return;
    }
    setState(() => _pendingReferralCode = pendingReferralCode);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadAchievementCount() async {
    final client = _supabaseClientOrNull;
    if (client == null) return;
    try {
      final response = await client.functions.invoke(
        'development-achievements',
        body: {'action': 'get', 'period': '今週の実績'},
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final list = (data['achievements'] as List<dynamic>?) ?? [];
      final recent = list.take(5).map((e) {
        final m = e as Map<String, dynamic>;
        final completedAt = m['completed_at']?.toString() ?? '';
        String dateStr = '';
        final dt = DateTime.tryParse(completedAt)?.toLocal();
        if (dt != null) {
          dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        }
        return <String, String>{
          'title': m['title']?.toString() ?? '',
          'date': dateStr,
        };
      }).where((m) => m['title']!.isNotEmpty).toList();

      // 全件カウントは別で取得
      final allResponse = await client.functions.invoke(
        'development-achievements',
        body: {'action': 'get', 'period': 'すべての実績'},
      );
      final allData = allResponse.data as Map<String, dynamic>? ?? {};
      final count = (allData['achievements'] as List<dynamic>?)?.length ?? 0;

      if (!mounted) return;
      setState(() {
        _achievementCount = count;
        _recentAchievements = recent;
      });
    } catch (_) {
      // Silently ignore; count stays 0
    }
  }

  Future<void> _loadSocialProofStats() async {
    final client = _supabaseClientOrNull;
    if (client == null) return;
    try {
      final results = await Future.wait<dynamic>([
        client.from('user_profiles').select('id').count(CountOption.exact),
        client
            .from('public_memos')
            .select('id')
            .eq('is_public', true)
            .count(CountOption.exact),
      ]);
      if (!mounted) return;
      final r0 = results[0];
      final r1 = results[1];
      final userCount = r0 is PostgrestResponse ? r0.count : 0;
      final memoCount = r1 is PostgrestResponse ? r1.count : 0;
      setState(() {
        _totalUsers = userCount;
        _publicMemoCount = memoCount;
      });
    } catch (_) {
      // Silently ignore
    }
  }

  Future<void> _auth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showMessage('メールアドレスとパスワードを入力してください。');
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isSignUp) {
        unawaited(_acquisitionService.recordLandingSignupSubmit());
        final result = await widget.adapter.signUp(
          email: email,
          password: password,
          emailRedirectTo: _webRedirectUrl,
        );
        if (!mounted) return;
        if (result.session == null) {
          _showMessage('確認メールを送信しました。メール内のリンクから登録を完了してください。');
        }
      } else {
        await widget.adapter.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on LandingPageAuthUnavailableException {
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      _showMessage(_resolveEmailAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (!_googleLoginFeatureEnabled) {
      _showMessage(
        'Googleログインは現在非表示です。`LANDING_GOOGLE_LOGIN_ENABLED=true` で再ビルドすると表示されます。',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final launched = await widget.adapter.signInWithGoogle(
        redirectTo: _webRedirectUrl,
      );
      if (!launched) {
        _showMessage('Googleログイン画面を開けませんでした。再読み込みしてから再実行してください。');
      }
    } on LandingPageAuthUnavailableException {
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      _showMessage(_resolveGoogleAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMagicLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Magic Link を送るにはメールアドレスを入力してください。');
      return;
    }

    setState(() => _isLoading = true);
    try {
      unawaited(_acquisitionService.recordLandingSignupSubmit());
      await widget.adapter.sendMagicLink(
        email: email,
        emailRedirectTo: _webRedirectUrl,
        shouldCreateUser: true,
      );
      if (mounted) {
        setState(() {
          _showInboxShortcut = true;
          _lastMagicLinkEmail = email;
        });
      }
      _startMagicLinkCooldown();
      _showMessage('Magic Link を送信しました。メール内のリンクからそのまま開始できます。');
    } on LandingPageAuthUnavailableException {
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      if (mounted) {
        setState(() => _showInboxShortcut = false);
      }
      _showMessage(_resolveMagicLinkError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startMagicLinkCooldown() {
    _magicLinkCooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _magicLinkCooldownSeconds = 30);
    _magicLinkCooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_magicLinkCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _magicLinkCooldownSeconds = 0);
        return;
      }
      setState(() => _magicLinkCooldownSeconds -= 1);
    });
  }

  Future<void> _runTrialActionPreview() async {
    unawaited(widget.adapter.recordTrialRun());
    final input = _trialPromptController.text.trim();
    if (input.isEmpty) {
      final fallback = _buildTrialFallbackSuggestion(input);
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = fallback.$2;
        _showSaveCtaPrompt = true;
      });
      return;
    }

    setState(() => _isTrialLoading = true);
    try {
      final prompt = '''
あなたは登録前LPの導線アシスタントです。
ユーザーの入力を読み、今すぐ着手すべき最初の1件を日本語で返してください。
出力は次の2行だけにしてください。
ACTION: 20文字以内の具体的な行動
REASON: 60文字以内の理由

ユーザー入力:
$input
''';

      final result = await widget.adapter.improveTrialPrompt(prompt: prompt);
      final parsed = _parseTrialAiResponse(result);
      if (!mounted) return;
      setState(() {
        _trialAction = parsed.$1;
        _trialReason = parsed.$2;
        _showSaveCtaPrompt = true;
      });
    } catch (e) {
      debugPrint('Trial preview failed: $e');
      final fallback = _buildTrialFallbackSuggestion(input);
      if (!mounted) return;
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = '${fallback.$2} AI応答が不安定だったため簡易提案を表示しています。';
        _showSaveCtaPrompt = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isTrialLoading = false);
      }
    }
  }

  void _promptRegistrationForTrialSave() {
    unawaited(widget.adapter.recordSaveCta());
    setState(() {
      _showSaveCtaPrompt = true;
      _isSignUp = true;
    });
    _showMessage(
      'この結果を保存するには登録が必要です。下の登録セクションから30秒で保存を開始できます。',
    );
    _scrollToAuthSection();
  }

  void _runQuickTrialSample(String prompt) {
    _trialPromptController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    unawaited(_runTrialActionPreview());
  }

  void _scrollToTrialSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trialContext = _trialSectionKey.currentContext;
      if (!mounted || trialContext == null) return;
      Scrollable.ensureVisible(
        trialContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    });
  }

  void _scrollToAuthSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authContext = _authSectionKey.currentContext;
      if (!mounted || authContext == null) return;
      Scrollable.ensureVisible(
        authContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.08,
      ).then((_) {
        if (!mounted) return;
        _emailFocusNode.requestFocus();
      });
    });
  }

  Uri _resolveInboxUri(String email) {
    final parts = email.split('@');
    final domain = parts.length == 2 ? parts.last.toLowerCase() : '';

    switch (domain) {
      case 'gmail.com':
      case 'googlemail.com':
        return Uri.parse('https://mail.google.com/mail/u/0/#inbox');
      case 'outlook.com':
      case 'hotmail.com':
      case 'live.com':
      case 'msn.com':
        return Uri.parse('https://outlook.live.com/mail/0/');
      case 'yahoo.co.jp':
        return Uri.parse('https://mail.yahoo.co.jp/');
      case 'yahoo.com':
        return Uri.parse('https://mail.yahoo.com/');
      case 'icloud.com':
      case 'me.com':
      case 'mac.com':
        return Uri.parse('https://www.icloud.com/mail');
      default:
        return Uri(
          scheme: 'mailto',
          path: email,
        );
    }
  }

  Future<void> _openInbox() async {
    final email = (_lastMagicLinkEmail ?? _emailController.text).trim();
    if (email.isEmpty) {
      _showMessage('先にメールアドレスを入力して、Magic Link を送信してください。');
      return;
    }

    final inboxUri = _resolveInboxUri(email);
    try {
      final launched = await launchUrl(
        inboxUri,
        mode: LaunchMode.platformDefault,
      );
      if (launched) {
        await widget.adapter.recordInboxOpen();
      }
      if (!launched) {
        _showMessage('受信箱を開けませんでした。ブラウザかメールアプリで受信箱を確認してください。');
      }
    } catch (e) {
      debugPrint('Open inbox failed: $e');
      _showMessage('受信箱を開けませんでした。ブラウザかメールアプリで受信箱を確認してください。');
    }
  }

  Future<void> _openImportPage() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushNamed('/import');
  }

  bool get _isMagicLinkCoolingDown => _magicLinkCooldownSeconds > 0;

  (String, String) _parseTrialAiResponse(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? action;
    String? reason;

    for (final line in lines) {
      final normalized = line.replaceFirst(RegExp(r'^[-*]\s*'), '');
      if (normalized.startsWith('ACTION:')) {
        action = normalized.substring('ACTION:'.length).trim();
      } else if (normalized.startsWith('REASON:')) {
        reason = normalized.substring('REASON:'.length).trim();
      }
    }

    if (action != null && action.isNotEmpty) {
      return (
        action,
        (reason != null && reason.isNotEmpty) ? reason : 'AIが最短の1件として判断しました。',
      );
    }

    final compact = raw.replaceAll('\n', ' ').trim();
    if (compact.isNotEmpty) {
      final safe =
          compact.length > 80 ? '${compact.substring(0, 80)}...' : compact;
      return (safe, 'AIの返答をそのまま簡易表示しています。');
    }

    return _buildTrialFallbackSuggestion(_trialPromptController.text.trim());
  }

  (String, String) _buildTrialFallbackSuggestion(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return (
        '今日の最重要を1件決める',
        '入力が空でも、最初に最重要を1件に絞るだけで着手はかなり早くなります。',
      );
    }

    if (text.contains('メール') ||
        text.contains('SMS') ||
        text.contains('DM') ||
        text.contains('連絡')) {
      return (
        '未読の確認を1件だけ終える',
        '連絡系は放置コストが高いので、最初に1件だけ処理すると全体が進みます。',
      );
    }

    if (text.contains('考える') ||
        text.contains('悩む') ||
        text.contains('迷う') ||
        text.contains('決めたい')) {
      return (
        '判断条件を1つだけ書き出す',
        '条件を先に言語化すると、迷いが減って次の行動が決まりやすくなります。',
      );
    }

    if (text.contains('タスク') ||
        text.contains('TODO') ||
        text.contains('仕事') ||
        text.contains('課題')) {
      return (
        '10分だけ使って最重要を1件に絞る',
        '最重要を1件だけ先に固定すると、その後の先延ばしが大きく減ります。',
      );
    }

    return (
      '20分だけ動ける最小単位に分解する',
      '大きすぎる作業は始めにくいので、最小単位まで分けてから着手してください。',
    );
  }

  String _resolveEmailAuthError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final status = error.statusCode?.toString() ?? '';

      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          message.contains('invalid login credentials')) {
        return 'メールアドレスかパスワードが一致していません。入力を見直すか、Magic Link を使ってください。';
      }
      if (code == 'email_exists' || code == 'user_already_exists') {
        return 'このメールアドレスは既に登録済みです。ログインに切り替えるか、Magic Link を使ってください。';
      }
      if (code == 'email_not_confirmed') {
        return '確認メールがまだ未完了です。メール内のリンクを開くか、Magic Link を送って入り直してください。';
      }
      if (code == 'signup_disabled') {
        return 'メール新規登録は現在停止中です。Magic Link を使うか、設定を確認してください。';
      }
      if (code == 'weak_password') {
        return 'パスワードが弱すぎます。8文字以上で、英字と数字を混ぜてください。';
      }
      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'メールアドレスの形式が正しくありません。`@` を含む形式で入力してください。';
      }
      if (code == 'validation_failed') {
        return '入力内容の検証に失敗しました。メール形式とパスワード長を見直してください。';
      }
      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return '試行回数が多すぎます。少し待ってから再実行するか、Magic Link を使ってください。';
      }
      if (code == 'unexpected_failure' || status == '500') {
        return '認証サーバー側で一時的なエラーが出ています。少し待ってから再試行してください。';
      }

      return '認証に失敗しました。入力内容を見直すか、Magic Link を使ってください。';
    }

    return '認証に失敗しました。通信状況を確認してから再試行してください。';
  }

  String _resolveGoogleAuthError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final status = error.statusCode?.toString() ?? '';

      if (code == 'provider_disabled' ||
          message.contains('provider is not enabled')) {
        return 'Supabase で Google provider が無効です。Authentication > Sign In / Providers で Google を有効化してください。';
      }
      if (code == 'bad_oauth_callback' ||
          code == 'bad_oauth_state' ||
          code == 'flow_state_expired' ||
          code == 'flow_state_not_found' ||
          code == 'validation_failed' ||
          message.contains('redirect')) {
        return 'Google OAuth のリダイレクト設定が一致していません。Supabase の Site URL / Redirect URLs と Google 側の callback URL を確認してください。';
      }
      if (code == 'access_denied' || message.contains('cancel')) {
        return 'Googleログインが中断されました。アカウント選択をやり直すか、Magic Link を使ってください。';
      }
      if (code == 'over_request_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return 'Googleログインの試行回数が多すぎます。少し待ってから再試行してください。';
      }

      return 'Googleログインに失敗しました。設定を確認するか、Magic Link を使ってください。';
    }

    final text = error.toString().toLowerCase();
    if (text.contains('popup')) {
      return 'ポップアップがブロックされました。ブラウザで許可してから再実行してください。';
    }
    return 'Googleログインに失敗しました。少し待ってから再試行してください。';
  }

  String _resolveMagicLinkError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final status = error.statusCode?.toString() ?? '';

      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'メールアドレスの形式が正しくありません。`@` を含む形式で入力してください。';
      }
      if (code == 'signup_disabled') {
        return '新規登録が停止中です。既存アカウントでのログインか、設定確認が必要です。';
      }
      if (code == 'email_provider_disabled') {
        return 'メール認証が無効です。Supabase の Email provider 設定を確認してください。';
      }
      if (code == 'validation_failed') {
        return 'Magic Link の送信条件を満たしていません。メールアドレスとリダイレクト設定を確認してください。';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return '送信回数が多すぎます。少し待ってから再送してください。';
      }
      if (code == 'flow_state_expired' || code == 'flow_state_not_found') {
        return '前回の認証状態が切れています。ページを再読み込みしてからもう一度送信してください。';
      }

      return 'Magic Link の送信に失敗しました。メール設定と入力内容を確認してください。';
    }
    return 'Magic Link の送信に失敗しました。通信状況を確認してから再試行してください。';
  }


  Widget _buildHeroSection() {
    return Column(
      key: const Key('landing_hero_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ★ メイン機能: ギター録音スタジオ
        GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed('/guitar-recording-studio'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE94560),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE94560).withAlpha(40),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE94560).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Color(0xFFE94560),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ギター録音スタジオ 🎸',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                          SizedBox(width: 6),
                          _LandingMainBadge(),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        '録音・WAV保存・メトロノーム・コード辞典・AI分析',
                        style: TextStyle(
                          color: Color(0xFFBBBBCC),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFE94560),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // ギャラリーリンク
        GestureDetector(
          onTap: () =>
              Navigator.of(context).pushNamed('/public-guitar-gallery'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withAlpha(15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFFF6B35).withAlpha(70),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.library_music_outlined,
                  color: Color(0xFFFF6B35),
                  size: 16,
                ),
                SizedBox(width: 8),
                Text(
                  '公開ギャラリーで録音を聴く',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                Spacer(),
                Icon(
                  Icons.arrow_forward,
                  color: Color(0xFFFF6B35),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // アプリ名バッジ
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3949AB), Color(0xFF6366F1)],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '自分株式会社 — AI統合プラットフォーム',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // メインヘッドライン
        const Text(
          'Notion・Slack・LINE・GitHub\n21サービスを1つに。完全無料。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '21のSaaSの機能を1アプリに統合。AIが今日の最優先タスクを整理し、資産管理・習慣化・チームコラボまで一元管理。登録30秒・クレジットカード不要。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF475569),
            height: 1.7,
          ),
        ),
        const SizedBox(height: 14),
        // 実績バッジ
        if (_achievementCount > 0)
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Text(
                    '✓ 実装済み $_achievementCount件の機能',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // プライマリ CTA
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            key: const Key('landing_register_button'),
            onPressed: _scrollToAuthSection,
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text(
              '無料で始める（30秒）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // セカンダリ CTA
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const Key('landing_trial_scroll_button'),
            onPressed: _scrollToTrialSection,
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text(
              '登録なしで1件試す',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF4F46E5),
              side: const BorderSide(color: Color(0xFFC7D2FE)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 信頼バッジ行
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _BenefitChip(icon: Icons.lock_open, label: '無料・制限なし'),
            _BenefitChip(icon: Icons.upload_file, label: 'Notionから移行可'),
            _BenefitChip(icon: Icons.smart_toy, label: 'AI自動整理'),
            _BenefitChip(icon: Icons.public, label: 'メモ公開共有'),
          ],
        ),
      ],
    );
  }

  Future<void> _shareOnX() async {
    const siteUrl = 'https://my-web-app-b67f4.web.app/';
    final userCount = _totalUsers > 0 ? '登録者$_totalUsers人突破！' : '';
    final text = 'スマホでギター録音＋21のSaaSを1アプリに統合。'
        '自分株式会社 $userCount\n'
        '完全無料で使えます👇\n'
        '$siteUrl\n'
        '#FlutterWeb #buildinpublic #自分株式会社 #ギター録音';
    final uri = Uri.https('x.com', '/intent/tweet', {'text': text});
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildViralShareSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2F3336)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1DA1F2).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('𝕏', style: TextStyle(color: Color(0xFF1DA1F2), fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'X でシェアして広める',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'フォロワーに紹介すると登録者が増えてサービスが成長します',
                  style: TextStyle(color: Color(0xFF71767B), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _shareOnX,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1DA1F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('シェア', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralInviteSection() {
    final pendingReferralCode = _pendingReferralCode;
    if (pendingReferralCode == null || pendingReferralCode.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('landing_referral_invite_section'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.recommend_outlined, color: Colors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Referral invite active: $pendingReferralCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'You arrived from an invite link. Create your account to keep the referral attribution, import notes from Notion or Evernote, and get to first value faster.',
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _scrollToAuthSection,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Create account'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _openImportPage,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('See import flow'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialProofStatsSection() {
    final stats = [
      (
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF4F46E5),
        bgColor: const Color(0xFFEEF2FF),
        value: _totalUsers > 0 ? '$_totalUsers' : '–',
        label: '登録ユーザー数',
      ),
      (
        icon: Icons.article_outlined,
        color: const Color(0xFF0284C7),
        bgColor: const Color(0xFFE0F2FE),
        value: _publicMemoCount > 0 ? '$_publicMemoCount' : '–',
        label: '公開メモ数',
      ),
      (
        icon: Icons.check_circle_outline,
        color: const Color(0xFF16A34A),
        bgColor: const Color(0xFFDCFCE7),
        value: _achievementCount > 0 ? '$_achievementCount' : '–',
        label: '実装済み機能数',
      ),
    ];

    return Container(
      key: const Key('landing_social_proof_stats'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFF4F46E5), size: 18),
              const SizedBox(width: 8),
              const Text(
                'リアルタイム実績',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.4,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: stats
                .map(
                  (s) => Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: s.bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(s.icon, color: s.color, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.value,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: s.color,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationGuideSection() {
    final steps = [
      (
        competitor: 'Notion',
        icon: '📝',
        color: const Color(0xFF1F2937),
        steps: [
          'Notionのページを開き「…」→「エクスポート」→「Markdown & CSV」を選択',
          '自分株式会社の「インポート」画面を開く',
          'エクスポートしたZIPをアップロード → AI整理で自動変換',
        ],
      ),
      (
        competitor: 'Evernote',
        icon: '🐘',
        color: const Color(0xFF00A82D),
        steps: [
          'Evernoteで「ファイル」→「ノートをエクスポート」→「ENEX形式」で書き出し',
          '自分株式会社の「インポート」画面を開く',
          'ENEXファイルをアップロード → メモ・添付ファイルを自動インポート',
        ],
      ),
    ];

    return Card(
      key: const Key('landing_migration_guide'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz, color: Color(0xFF3949AB), size: 20),
                SizedBox(width: 8),
                Text(
                  '他サービスからの移行は3ステップ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'データを失わずに、5分で完了します。',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ...steps.map((guide) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(guide.icon, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(
                          '${guide.competitor} からの移行',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: guide.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...guide.steps.asMap().entries.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: guide.color.withAlpha(26),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Center(
                                child: Text(
                                  '${e.key + 1}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: guide.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(fontSize: 13, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/import'),
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('インポート画面を開く'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonLinksSection() {
    const competitors = [
      (key: 'notion', name: 'Notion', emoji: '📝', color: Color(0xFF1F2937)),
      (key: 'evernote', name: 'Evernote', emoji: '🐘', color: Color(0xFF00A82D)),
      (key: 'moneyforward', name: 'MoneyForward', emoji: '💰', color: Color(0xFF0D47A1)),
      (key: 'x', name: 'X (Twitter)', emoji: '𝕏', color: Color(0xFF1C1C1E)),
      (key: 'animaworks', name: 'Animaworks', emoji: '🎯', color: Color(0xFFFF6B35)),
      (key: 'claude-code', name: 'Claude Code', emoji: '🤖', color: Color(0xFFD97706)),
      (key: 'codex', name: 'Codex', emoji: '⚡', color: Color(0xFF10B981)),
      (key: 'netkeiba', name: 'netkeiba', emoji: '🐎', color: Color(0xFF7C3AED)),
      (key: 'openclaw', name: 'OpenClaw', emoji: '🦾', color: Color(0xFF0EA5E9)),
      (key: 'claude-cowork', name: 'Claude Cowork', emoji: '🏛️', color: Color(0xFF6366F1)),
      (key: 'chatwork', name: 'Chatwork', emoji: '🏢', color: Color(0xFFE53935)),
      (key: 'slack', name: 'Slack', emoji: '💬', color: Color(0xFF4A154B)),
      (key: 'jobcan', name: 'ジョブカン', emoji: '📋', color: Color(0xFF059669)),
      (key: 'amazon', name: 'Amazon', emoji: '📦', color: Color(0xFFFF9900)),
      (key: 'google', name: 'Google', emoji: '🔍', color: Color(0xFF4285F4)),
      (key: 'microsoft', name: 'Microsoft', emoji: '🪟', color: Color(0xFF00A4EF)),
      (key: 'discord', name: 'Discord', emoji: '🎮', color: Color(0xFF5865F2)),
      (key: 'line', name: 'LINE', emoji: '💚', color: Color(0xFF06C755)),
      (key: 'facebook', name: 'Facebook', emoji: '👥', color: Color(0xFF1877F2)),
      (key: 'liven', name: 'Liven', emoji: '🍽️', color: Color(0xFFFF6B35)),
      (key: 'github', name: 'GitHub', emoji: '🐙', color: Color(0xFF24292E)),
    ];

    return Card(
      key: const Key('landing_comparison_links'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.compare_arrows,
                    color: Color(0xFF3949AB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '21社との機能比較',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '気になるサービスをタップして機能・価格を比較しよう',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: competitors.map((c) {
                return InkWell(
                  onTap: () => Navigator.of(context).pushNamed('/vs-${c.key}'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: c.color.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'vs ${c.name}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildEnterpriseCta() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF3949AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.business, color: Colors.white70, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🏢 チームで使う',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Slack・Chatwork・ジョブカンを1つに統合。法人導入無料。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/enterprise'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            child: const Text('詳しく見る'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAchievementsSection() {
    if (_recentAchievements.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD1FAE5)),
      ),
      color: const Color(0xFFF0FDF4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rocket_launch, size: 16, color: Color(0xFF059669)),
                const SizedBox(width: 6),
                const Text(
                  '今週の開発実績',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                const Spacer(),
                Text(
                  '全 $_achievementCount 件実装済み',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6EE7B7)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._recentAchievements.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a['title'] ?? '',
                        style: const TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      a['date'] ?? '',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueValueSection() {
    const features = [
      (Icons.account_tree, '0xFF4F46E5', 'AI組織OS (12部署20人)', '自然言語でタスクを入力するだけで最適な部署が自動受付。ゴールを12部署に自動分解・配布。SlackもJiraも不要。'),
      (Icons.smart_toy, '0xFF6366F1', 'AI役員会議 (MAGI)', 'CEO/CFO/CMO/CHROのAIペルソナが多角的にアドバイス。Notionにもない独自機能。'),
      (Icons.memory, '0xFF10B981', '記憶ドリル', '忘却曲線に基づく反復学習。Evernoteにはない学習機能。'),
      (Icons.account_balance_wallet, '0xFFF59E0B', '経営コックピット', '収支・資産・KPIを一画面で管理。MoneyForwardの代替として使える。'),
      (Icons.upload_file, '0xFF3B82F6', 'Notion/Evernoteから移行', 'CSVやENEXをそのままインポート。移行コストゼロ。'),
      (Icons.hub, '0xFFA855F7', 'マインドマップ', '思考の整理をビジュアルで。ノートと連携。'),
      (Icons.public, '0xFF22C55E', '公開メモ・SEO', 'メモをURLで共有。知識のアウトプットが集客につながる。'),
      (Icons.psychology_alt, '0xFF8B5CF6', '性格診断 (16タイプ MBTI)', 'MBTIベースの自己分析でメモ術・学習スタイルを最適化。恋愛相性診断も。他にはない自己理解機能。'),
      (Icons.do_not_disturb_on, '0xFFEF4444', '思考妨害排除ガード', 'SNS・通知・散漫思考をブロックして深い集中を守る。フォーカスセッション中はアプリ内通知を自動ミュート。他のサービスにはない認知コスト削減機能。'),
      (Icons.visibility_off, '0xFFF97316', '見栄ガード', 'かっこつけず・見栄をはらずに生きる仕組み。SNS承認欲求や衝動的な自己顕示を記録・可視化して断ち切る。競合21社に存在しない自己規律機能。'),
      (Icons.money_off, '0xFF14B8A6', '浪費トラッキング', '投資を除いた資産放出を日次で記録・可視化。無意識の浪費パターンを把握してMoneyForwardを超える節制管理。'),
      (Icons.corporate_fare, '0xFF6366F1', '12部署AI仮想組織', '自分一人でCEO・CFO・CMO・開発部・営業部など12部署20人のAI組織を持てる。Slack・Chatwork・ジョブカン対抗の次世代チーム管理。'),
      (Icons.group_add, '0xFF22C55E', '友達招待・紹介コード', '紹介リンクをシェアするだけで招待実績が積み上がる。バイラル成長の仕組みを個人レベルで実装。'),
      (Icons.chat_bubble_outline, '0xFF8B5CF6', 'ノートコメント・リアクション', '公開メモにコメント・絵文字リアクション・OGPシェアが可能。Notion/Evernoteを超えるソーシャル連携機能。'),
      (Icons.notifications, '0xFF0EA5E9', '通知センター', 'アプリ内の全通知を一元管理。未読バッジ・フィルタリング・既読管理で重要な更新を見逃さない。'),
      (Icons.draw, '0xFF64748B', '電子署名', '契約書・同意書をアプリ内で電子署名。法人・フリーランス向け。DocuSign連携と直接競合する機能を完全無料で提供。'),
      (Icons.storefront, '0xFFEC4899', 'コンビニ経営シミュレーション', '自分株式会社の中でコンビニを経営。春夏秋冬の季節・天気・トレンドをAIが反映した経営判断ゲーム。競合21社に存在しないゲーミフィケーション。'),
      (Icons.timer, '0xFF10B981', '集中タイマー', 'ポモドーロ/ディープフォーカスモードで深い集中を実現。思考妨害排除ガードと連携しSNS通知を自動ブロック。'),
      (Icons.edit_note, '0xFF7C3AED', 'AI文章アシスタント', 'メモ・ブログ・SNS投稿の文章作成・推敲・要約をAIが支援。Notion AIを超える日本語特化の文章強化機能。'),
      (Icons.fitness_center, '0xFFF59E0B', '浪費耐性トレーニング', '買わずに耐えた回数・防いだ出費・取り戻した時間を毎日記録。我慢を筋トレのように可視化して浪費を断つ精神性を育てる。'),
      (Icons.video_camera_back, '0xFFDC2626', 'バイラル動画パイプライン', 'AIが広告動画を自動生成→X/SNSに自動投稿→効果測定まで全自動。TikTok・YouTube Shortsを超えるバイラル成長エンジン。'),
      (Icons.translate, '0xFF0891B2', '語学学習', 'フラッシュカード・発音練習・進捗管理をAIが支援。Duolingoを超える日本語圏特化の語学習得システム。'),
      (Icons.restaurant_menu, '0xFFB45309', 'レシピ・献立管理', '食材管理・献立提案・栄養分析をAIが自動化。MoneyForwardの家計管理と食費を連携した生活密着型機能。'),
      (Icons.flight_takeoff, '0xFF0369A1', '旅行計画・行程管理', '行程管理・現地情報・費用管理を一元化。Google旅行機能を超えるAI行程最適化で旅をもっと豊かに。'),
      (Icons.pets, '0xFF7E22CE', 'ペット健康管理', 'ワクチン記録・健康日記・体重管理をアプリ内で完結。競合21社にない個人ライフ全領域カバーの証明。'),
      (Icons.photo_library, '0xFF065F46', 'フォトギャラリー', 'AI自動分類・思い出管理・家族共有まで対応。Google フォトに対抗しつつ自分株式会社データとシームレス連携。'),
      (Icons.emoji_events, '0xFFEAB308', '習慣ゲーミフィケーション', 'ストリーク・バッジ・XP獲得で習慣を楽しく継続。Duolingo式ゲーミフィケーションで継続率3倍。'),
      (Icons.code, '0xFF0F172A', 'コードプレイグラウンド', 'ブラウザだけでコードを書いて即実行。学習・プロト制作・アイデア検証を一気通貫でサポート。'),
      (Icons.home_work, '0xFF0284C7', '不動産管理', '物件情報・家賃・更新日を一元管理。投資用物件の収益計算もAIが自動化。'),
      (Icons.school, '0xFF4338CA', 'eラーニング', 'コース作成・受講管理・修了証発行まで対応。Udemyを超える自分専用LMSを無料で構築。'),
      (Icons.directions_car, '0xFF374151', '車両管理', '車検・整備記録・燃費管理を自動追跡。複数台・法人向け車両フリートにも対応。'),
      (Icons.work_history, '0xFF059669', '採用ボード', '求人票作成・応募者管理・面接スケジューリングをAIが支援。HR SaaSの代替を完全無料で実現。'),
      (Icons.sensors, '0xFF7C3AED', 'IoTダッシュボード', '家電・センサー・スマートデバイスをダッシュボードで一元管理。スマートホームを自分株式会社に統合。'),
      (Icons.gavel, '0xFFDC2626', '法務管理', '契約書・利用規約・コンプライアンスチェックをAIが支援。LegalForceを超える自動法務レビュー機能。'),
      (Icons.mark_email_read, '0xFF0891B2', 'メールテンプレート管理', '返信テンプレート・差し込み変数・ABテストをAIが最適化。メール生産性を10倍に引き上げる。'),
      (Icons.security, '0xFF16A34A', '2FA/多要素認証', 'TOTP・SMSで全アカウントを堅牢に保護。パスワードマネージャーと連携して認証情報を一元管理。'),
      (Icons.music_video, '0xFFE11D48', '公開ギターギャラリー', 'スマホで録音したギター演奏をUGCとして公開共有。OGP・sitemap対応でSEO流入も獲得。競合21社にない音楽SNS機能。'),
      (Icons.calendar_month, '0xFF0F766E', '月次カレンダービュー', '月間スケジュールをカレンダー形式で一覧表示。タスク・習慣・イベントをTimeTree/Googleカレンダーを超える統合ビューで管理。'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFF), Color(0xFFF0F4FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '自分株式会社でしかできない38のこと',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Notion・Evernote・MoneyForward・Google・LINE・Facebook の良いとこ取りに、AIと記憶ドリルをプラス。',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ...features.map((f) {
            final (icon, colorHex, title, desc) = f;
            final color = Color(int.parse(colorHex.replaceFirst('0x', '0xFF')));
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _scrollToAuthSection,
              icon: const Icon(Icons.rocket_launch, size: 16),
              label: const Text(
                '無料で全機能を使う',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3949AB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCtaSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.upload_file, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                'Notion / Evernote / Markdown から移行',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ファイルをアップロードするだけで、過去のデータがそのまま引き継げます。移行後も元のサービスを使い続けながら、少しずつ切り替えられます。',
            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.6),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pushNamed('/import'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text(
              '登録なしでインポートを試す',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// 競合サービスとの価格・機能数比較セクション
  Widget _buildPricingComparisonSection() {
    final rows = [
      const _CompetitorRow('Notion', '¥1,100〜/月', '100+', false),
      const _CompetitorRow('Evernote', '¥1,300〜/月', '50+', false),
      const _CompetitorRow('MoneyForward', '¥500〜/月', '30+', false),
      const _CompetitorRow('Slack', '¥925〜/月', '80+', false),
      const _CompetitorRow('Google Workspace', '¥680〜/月', '80+', false),
      const _CompetitorRow('Microsoft 365', '¥1,241〜/月', '90+', false),
      const _CompetitorRow('LINE (Business)', '¥5,000〜/月', '30+', false),
      const _CompetitorRow('自分株式会社', '完全無料', '21サービス分', true),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💰', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '他社は有料。自分株式会社は完全無料。',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '月額数千円のSaaS21本分の機能を、無料で使えます。',
            style: TextStyle(fontSize: 13, color: Color(0xFF78350F)),
          ),
          const SizedBox(height: 14),
          ...rows.map((row) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: row.isOurs
                    ? const Color(0xFF3949AB)
                    : const Color(0xFFFEFCE8),
                borderRadius: BorderRadius.circular(12),
                border: row.isOurs
                    ? null
                    : Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            row.isOurs ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.price,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: row.isOurs ? FontWeight.w800 : FontWeight.w600,
                        color: row.isOurs
                            ? Colors.yellowAccent
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${row.featureCount}機能',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: row.isOurs
                            ? Colors.white70
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 3ステップで始めるセクション
  Widget _buildGetStartedStepsSection() {
    const steps = [
      (Icons.play_circle_outline, '1. 無料トライアル', 'まず登録なしで1件試す。AIが今日の最優先タスクを提案。',
          Color(0xFF6366F1)),
      (Icons.save_outlined, '2. 無料登録して保存', 'メール認証だけで即登録。提案を保存して明日も続きから再開。',
          Color(0xFF10B981)),
      (Icons.upload_file_outlined, '3. 既存データを移行',
          'NotionのCSV・EvernoteのENEXをインポート。移行コストゼロ。', Color(0xFFF59E0B)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3ステップで始める',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'クレジットカード不要。登録は30秒。',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ...steps.map((s) {
            final (icon, title, desc, color) = s;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _scrollToAuthSection,
              icon: const Icon(Icons.rocket_launch, size: 18),
              label: const Text(
                '無料で始める（30秒）',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3949AB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialSection() {
    return KeyedSubtree(
      key: const Key('landing_trial_section'),
      child: Card(
        key: _trialSectionKey,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '登録前の1アクション体験',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'まず1回だけ使って、価値があるかを確認してください。保存したくなった時だけ登録すれば十分です。',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.flash_on, size: 18),
                    label: const Text('今日の最優先'),
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今日の最優先タスクを1件に絞りたい',
                            ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.event_note, size: 18),
                    label: const Text('今日の計画を立てる'),
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今日1日の計画を立てて、最も重要なことに集中したい',
                            ),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.done_all, size: 18),
                    label: const Text('先送り解消'),
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今いちばん先送りしていることを片付けたい',
                            ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _trialPromptController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '例: 今日いちばん詰まっていることを簡単に書く',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bolt),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isTrialLoading ? null : _runTrialActionPreview,
                  icon: const Icon(Icons.play_arrow),
                  label: _isTrialLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('今やる1件を試す'),
                ),
              ),
              if (_trialAction != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '提案された1件',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _trialAction!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (_trialReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _trialReason!,
                          style: const TextStyle(color: Color(0xFF64748B)),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const Text(
                        '保存すると、この提案を明日も続きから開けます。',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _promptRegistrationForTrialSave,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('この結果を保存して続ける'),
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
    );
  }

  Widget _buildFaqSection() {
    const faqs = [
      (
        q: 'Notionと何が違うの?',
        a: '自分株式会社はAIが「今日やるべき1件」を決めてくれる点が最大の違いです。Notionは情報整理ツールですが、本アプリはAIが優先順位を付けて行動提案まで行います。さらに12部署20人のAI組織OS・資産管理・習慣化・性格診断も1つのアプリで完結します。',
      ),
      (
        q: '12部署20人のAI組織OSって何?',
        a: '自分1人で12の仮想部署（企画・開発・営業・CS・法務・広報・調達など）と20人のAIエージェントを動かせる機能です。自然言語でゴールを入力するだけでAIが最適な部署に自動振り分け、タスク分解・進捗管理まで担当します。SlackもJiraも不要で、1アプリで組織のように動けます。',
      ),
      (
        q: '完全無料で使い続けられますか?',
        a: 'はい、現在は完全無料です。登録なしでAI提案を1回体験でき、登録後は制限なくすべての機能を利用できます。将来的にプレミアムプランを検討していますが、基本機能は無料のままです。',
      ),
      (
        q: 'NotionやEvernoteからデータを移行できますか?',
        a: 'はい、インポート機能が使えます。NotionのCSVエクスポートとEvernoteのENEXファイルをそのままインポートできます。移行コストゼロで今すぐ試せます。',
      ),
      (
        q: 'LINE・Discord・SNSの代わりになりますか?',
        a: 'LINE・Discordのメッセージ・通話機能の代替ではありませんが、個人のタスク管理・メモ・習慣化・資産管理という日常生活の生産性ツールとしては大きく上回ります。SNSで分散した情報を一元管理したい方に特に適しています。',
      ),
      (
        q: 'データは安全ですか?',
        a: 'データはSupabase (PostgreSQL) に保存され、行レベルのセキュリティで各ユーザーが自分のデータのみアクセスできます。AIに送信されるのはあなたが入力したテキストのみで、第三者に販売・共有することはありません。',
      ),
      (
        q: 'AIは具体的に何をしてくれますか?',
        a: 'タスク・習慣・資産・状況をもとに「今日の最優先アクション1件」を提案します。なぜそれをすべきかの理由と、48時間以内の次の一手まで整理してくれます。MAGIシステムで3つの視点から意思決定をサポートし、AI組織OSに委任することもできます。',
      ),
      (
        q: 'スマホやタブレットでも使えますか?',
        a: 'Flutter Web製のためブラウザがあればどのデバイスでも動作します。スマホのホーム画面に追加(PWA)すると、アプリのように快適に使えます。',
      ),
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'よくある質問',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              '気になることがあればお気軽にどうぞ。',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            for (final faq in faqs) ...[
              _FaqItem(question: faq.q, answer: faq.a),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    return KeyedSubtree(
      key: const Key('landing_auth_section'),
      child: Card(
        key: _authSectionKey,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_showSaveCtaPrompt) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'この提案を保存するには登録が必要です。Magic Link なら、メール1通でそのまま保存を始められます。',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                '今すぐ無料ではじめる',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? 'メールアドレスだけで30秒登録。AIが今日のタスクを整理し、資産管理・習慣化まで一元化。カード不要。'
                    : '既存ユーザーも Magic Link が最短です。パスワード入力なしで、そのまま再開できます。',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BenefitChip(icon: Icons.card_membership, label: '完全無料'),
                  _BenefitChip(icon: Icons.auto_awesome, label: 'AI自動整理'),
                  _BenefitChip(icon: Icons.import_export, label: 'Notionから移行可'),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                focusNode: _emailFocusNode,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '保存される内容: AI提案 / 実行履歴 / 明日の続き',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: (_isLoading ||
                          (_showInboxShortcut && _isMagicLinkCoolingDown))
                      ? null
                      : _sendMagicLink,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showInboxShortcut
                            ? (_isMagicLinkCoolingDown
                                ? '送信済み'
                                : 'Magic Linkを再送')
                            : 'Magic Linkで今すぐ始める',
                      ),
                      if (_showInboxShortcut && _isMagicLinkCoolingDown) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '新規登録もログインも、この1通で完了します。',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              if (_showInboxShortcut) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Magic Link を送信しました。受信箱でメールを開いて、そのままログインしてください。',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '届かない場合は迷惑メールも確認してください。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openInbox,
                              icon: const Icon(Icons.open_in_new),
                              label: const Text('受信箱を開く'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: (_isLoading || _isMagicLinkCoolingDown)
                                  ? null
                                  : _sendMagicLink,
                              icon: const Icon(Icons.refresh),
                              label: Text(
                                _isMagicLinkCoolingDown
                                    ? '再送 ${_magicLinkCooldownSeconds}s'
                                    : '再送する',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (_googleLoginFeatureEnabled) ...[
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    icon: const Icon(Icons.login),
                    label: const Text('Googleで続ける'),
                  ),
                ),
                const SizedBox(height: 10),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text(
                    'Googleログインは設定済み環境でのみ表示します。現在は Magic Link を主導線にしています。',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'パスワードで続ける',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enableInteractiveSelection: true,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        tooltip: _obscurePassword ? '表示' : '非表示',
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_paste_rounded),
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data?.text != null) {
                            _passwordController.text = data!.text!;
                          }
                        },
                        tooltip: '貼り付け',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isLoading ? null : _auth,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isSignUp ? 'メールで新規登録' : 'メールでログイン',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() => _isSignUp = !_isSignUp);
                      },
                child: Text(
                  _isSignUp ? 'すでにアカウントがある場合はログイン' : 'アカウントがない場合は新規登録',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('landing_page_scaffold'),
      appBar: AppBar(
        title: const Text(
          '自分株式会社へようこそ',
          key: Key('landing_page_title'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Scrollable.ensureVisible(
            _authSectionKey.currentContext ?? context,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: const Color(0xFF3949AB),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.rocket_launch, size: 18),
        label: const Text(
          '無料で始める',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. ヒーロー
                  _buildHeroSection(),
                  const SizedBox(height: 20),
                  // 2. 実績数字で信頼感を作る
                  _buildSocialProofStatsSection(),
                  const SizedBox(height: 12),
                  // 2b. X バイラルシェア
                  _buildViralShareSection(),
                  const SizedBox(height: 12),
                  // 3. ライブ成長メーター (登録者数・競合差分をリアルタイム表示)
                  LiveGrowthBanner(
                    growthService: widget.growthService,
                    compact: true,
                    title: '今まさに成長中',
                    subtitle: '登録者数・競合との差をリアルタイムで確認',
                  ),
                  const SizedBox(height: 20),
                  // 4. すぐ登録できるよう認証フォームを最上位に
                  _buildAuthSection(),
                  const SizedBox(height: 20),
                  // 4. 最近の開発実績 (活発な開発をアピール)
                  _buildRecentAchievementsSection(),
                  const SizedBox(height: 20),
                  // 5. 独自価値の訴求
                  _buildUniqueValueSection(),
                  const SizedBox(height: 20),
                  // 5. 始め方のシンプルさを見せる
                  _buildGetStartedStepsSection(),
                  const SizedBox(height: 20),
                  // 6. 移行しやすさ（Notion/Evernote ユーザー向け）
                  _buildMigrationGuideSection(),
                  const SizedBox(height: 20),
                  // 7. 価格比較（無料を強調）
                  _buildPricingComparisonSection(),
                  const SizedBox(height: 20),
                  // 8. 登録なしでまず試す
                  _buildTrialSection(),
                  const SizedBox(height: 20),
                  // 9. FAQ で不安を解消
                  _buildFaqSection(),
                  const SizedBox(height: 20),
                  // 10. インポート CTA
                  _buildImportCtaSection(),
                  const SizedBox(height: 20),
                  // 11. 21社との機能比較
                  _buildComparisonLinksSection(),
                  // 12. B2B エンタープライズ CTA
                  _buildEnterpriseCta(),
                  const SizedBox(height: 20),
                  // 13. 紹介（紹介コードがある場合のみ表示）
                  _buildReferralInviteSection(),
                  if (_pendingReferralCode != null) const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4338CA),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitorRow {
  final String name;
  final String price;
  final String featureCount;
  final bool isOurs;

  const _CompetitorRow(this.name, this.price, this.featureCount, this.isOurs);
}

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.answer,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

/// ランディングページ用 MAIN 機能バッジ
class _LandingMainBadge extends StatelessWidget {
  const _LandingMainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE94560),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'MAIN',
        style: TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
