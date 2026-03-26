import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/public_memo.dart';
import '../services/growth_acquisition_service.dart';
import '../services/growth_mission_service.dart';
import '../services/landing_page_adapter.dart';
import '../services/landing_share_service.dart';
import '../services/public_memo_service.dart';
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
  final _waitlistEmailController = TextEditingController();
  final _featureRequestTitleController = TextEditingController();
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
  bool _isLoadingStats = true;
  bool _isLoadingShareStats = true;
  bool _showSaveCtaPrompt = false;
  bool _showInboxShortcut = false;
  int _magicLinkCooldownSeconds = 0;

  int _todayViews = 0;
  int _monthViews = 0;
  int _totalViews = 0;
  List<FlSpot> _pvSpots = const <FlSpot>[];
  List<String> _pvLabels = const <String>[];
  String? _activeShareChannel;
  int _achievementCount = 0;
  int _totalUsers = 0;
  int _publicMemoCount = 0;

  String? _trialAction;
  String? _trialReason;
  String? _lastMagicLinkEmail;
  String? _pendingReferralCode;
  LandingShareSnapshot _shareSnapshot = LandingShareSnapshot.empty();
  List<PublicMemo> _publicMemos = const <PublicMemo>[];
  bool _isLoadingPublicMemos = true;

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
    _initLpViewStats();
    _loadShareSnapshot();
    _loadPublicMemos();
    unawaited(_loadAchievementCount());
    unawaited(_loadSocialProofStats());
  }

  bool _waitlistSubmitted = false;
  bool _featureRequestSubmitted = false;

  @override
  void dispose() {
    _authSubscription?.cancel();
    _magicLinkCooldownTimer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _trialPromptController.dispose();
    _waitlistEmailController.dispose();
    _featureRequestTitleController.dispose();
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

  Future<void> _loadShareSnapshot() async {
    try {
      final snapshot = await widget.adapter.loadShareSnapshot();
      if (!mounted) return;
      setState(() {
        _shareSnapshot = snapshot;
        _isLoadingShareStats = false;
      });
    } catch (error) {
      debugPrint('Landing share snapshot failed: $error');
      if (!mounted) return;
      setState(() => _isLoadingShareStats = false);
    }
  }

  Future<void> _loadAchievementCount() async {
    final client = _supabaseClientOrNull;
    if (client == null) return;
    try {
      final response = await client.functions.invoke(
        'development-achievements',
        body: {'action': 'get', 'period': 'すべての実績'},
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final count = (data['achievements'] as List<dynamic>?)?.length ?? 0;
      if (!mounted) return;
      setState(() => _achievementCount = count);
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

  Future<void> _loadPublicMemos() async {
    final client = _supabaseClientOrNull;
    if (client == null) {
      if (!mounted) return;
      setState(() => _isLoadingPublicMemos = false);
      return;
    }

    try {
      final service = PublicMemoService(client);
      final memos = await service.getPublicMemos(limit: 4);
      if (!mounted) return;
      setState(() {
        _publicMemos = memos;
        _isLoadingPublicMemos = false;
      });
    } catch (error) {
      debugPrint('Landing public memo load failed: $error');
      if (!mounted) return;
      setState(() => _isLoadingPublicMemos = false);
    }
  }

  Future<void> _shareLandingPage(String channel) async {
    if (_activeShareChannel != null) {
      return;
    }

    setState(() => _activeShareChannel = channel);
    try {
      final snapshot = await widget.adapter.shareLandingPage(channel: channel);
      if (!mounted) return;
      setState(() => _shareSnapshot = snapshot);
      final label = LandingShareService.channelLabel(channel);
      _showMessage(
        channel == LandingShareService.channelCopy
            ? '計測付きの共有リンクをコピーしました。'
            : '$label の共有画面を開きました。',
      );
    } catch (error) {
      debugPrint('Landing share failed: $error');
      _showMessage('共有の起動に失敗しました。');
    } finally {
      if (mounted) {
        setState(() => _activeShareChannel = null);
      }
    }
  }

  Future<void> _initLpViewStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final stats = await widget.adapter.loadLpViewStats();
      final spots = <FlSpot>[];
      final labels = <String>[];
      for (var i = 0; i < stats.series.length; i++) {
        final row = stats.series[i];
        spots.add(FlSpot(i.toDouble(), row.count));
        labels.add(row.date == null ? '' : DateFormat('M/d').format(row.date!));
      }

      if (!mounted) return;
      setState(() {
        _todayViews = stats.todayViews;
        _monthViews = stats.monthViews;
        _totalViews = stats.totalViews;
        _pvSpots = spots;
        _pvLabels = labels;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('LP view stats failed: $e');
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
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

  Widget _buildBuildInPublicSection() {
    final launchDate = DateTime(2026, 3, 1);
    final daysBuilding = DateTime.now().difference(launchDate).inDays + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.construction, color: Colors.amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Build in Public 🚀',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '13製品に挑戦中 · $daysBuilding日目'
                  '${_achievementCount > 0 ? ' · 実装済み$_achievementCount件' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.amber,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Column(
      key: const Key('landing_hero_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // メインヘッドライン
        const Text(
          'Notion・Evernote・MoneyForward\nSlack を1つに。完全無料。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '13のSaaSの機能を1アプリに統合。AIが今日の最優先タスクを整理し、資産管理・習慣化・チームコラボまで一元管理。登録30秒・クレジットカード不要。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF475569),
            height: 1.6,
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
          height: 54,
          child: FilledButton.icon(
            key: const Key('landing_register_button'),
            onPressed: _scrollToAuthSection,
            icon: const Icon(Icons.rocket_launch, size: 18),
            label: const Text(
              '無料で始める（30秒）',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3949AB),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // セカンダリ CTA
        OutlinedButton.icon(
          key: const Key('landing_trial_scroll_button'),
          onPressed: _scrollToTrialSection,
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('登録なしで1件試す'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3949AB),
            side: const BorderSide(color: Color(0xFFBFD0F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
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

  Widget _buildReferralInviteSection() {
    final pendingReferralCode = _pendingReferralCode;
    if (pendingReferralCode == null || pendingReferralCode.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      key: const Key('landing_referral_invite_section'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        color: const Color(0xFF3949AB),
        value: _totalUsers > 0 ? '$_totalUsers' : '–',
        label: '登録ユーザー数',
      ),
      (
        icon: Icons.article_outlined,
        color: const Color(0xFF0288D1),
        value: _publicMemoCount > 0 ? '$_publicMemoCount' : '–',
        label: '公開メモ数',
      ),
      (
        icon: Icons.check_circle_outline,
        color: const Color(0xFF388E3C),
        value: _achievementCount > 0 ? '$_achievementCount' : '–',
        label: '実装済み機能数',
      ),
    ];

    return Card(
      key: const Key('landing_social_proof_stats'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bar_chart, color: Color(0xFF3949AB), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'リアルタイム実績',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF388E3C),
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
                          Icon(s.icon, color: s.color, size: 28),
                          const SizedBox(height: 6),
                          Text(
                            s.value,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: s.color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.label,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              style: TextStyle(fontSize: 13, color: Colors.black54),
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
    ];

    return Card(
      key: const Key('landing_comparison_links'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    borderRadius: BorderRadius.circular(10),
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
                        '他サービスからの移行比較',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '気になる競合と機能を比較してみましょう',
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
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: c.color.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildPvSection() {
    final fmt = NumberFormat('#,###');
    final labelInterval =
        _pvLabels.length <= 6 ? 1 : (_pvLabels.length / 6).ceil();

    return Card(
      key: const Key('landing_pv_section'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'LP View 数',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'まずは流入を増やし、その後に登録導線を詰めます。今日のLP Viewを毎日確認します。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _pvKpi('今日', fmt.format(_todayViews)),
                _pvKpi('今月', fmt.format(_monthViews)),
                _pvKpi('累計', fmt.format(_totalViews)),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 180,
              child: _isLoadingStats
                  ? const Center(child: CircularProgressIndicator())
                  : (_pvSpots.isEmpty
                      ? const Center(child: Text('表示できるデータがまだありません。'))
                      : LineChart(
                          LineChartData(
                            minY: 0,
                            gridData: const FlGridData(show: true),
                            borderData: FlBorderData(show: true),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 34,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  interval: labelInterval.toDouble(),
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    final label =
                                        index >= 0 && index < _pvLabels.length
                                            ? _pvLabels[index]
                                            : '';
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _pvSpots,
                                isCurved: false,
                                barWidth: 2.4,
                                color: Colors.blue,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        )),
            ),
            const SizedBox(height: 8),
            const Text(
              'グラフは今月の日次 LP View です。',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublicMemoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '公開メモ',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              '登録前でも読めるメモを増やして、検索流入と共有流入の入口を作ります。',
            ),
            const SizedBox(height: 16),
            if (_isLoadingPublicMemos)
              const Center(child: CircularProgressIndicator())
            else if (_publicMemos.isEmpty)
              const Text('公開メモはまだありません。')
            else
              ..._publicMemos.map(
                (memo) => Card(
                  child: ListTile(
                    title: Text(memo.title),
                    subtitle: Text(
                      memo.content ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text('${memo.viewCount} views'),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed('/public-memo?id=${memo.id}'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).pushNamed('/public-memos'),
              icon: const Icon(Icons.open_in_new),
              label: const Text('公開メモ一覧を見る'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniqueValueSection() {
    const features = [
      (Icons.smart_toy, '0xFF6366F1', 'AI役員会議 (MAGI)', 'CEO/CFO/CMO/CHROのAIペルソナが多角的にアドバイス。Notionにもない独自機能。'),
      (Icons.memory, '0xFF10B981', '記憶ドリル', '忘却曲線に基づく反復学習。Evernoteにはない学習機能。'),
      (Icons.account_balance_wallet, '0xFFF59E0B', '経営コックピット', '収支・資産・KPIを一画面で管理。MoneyForwardの代替として使える。'),
      (Icons.upload_file, '0xFF3B82F6', 'Notion/Evernoteから移行', 'CSVやENEXをそのままインポート。移行コストゼロ。'),
      (Icons.hub, '0xFFA855F7', 'マインドマップ', '思考の整理をビジュアルで。ノートと連携。'),
      (Icons.public, '0xFF22C55E', '公開メモ・SEO', 'メモをURLで共有。知識のアウトプットが集客につながる。'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFF), Color(0xFFF0F4FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '自分株式会社でしかできない6つのこと',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Notion・Evernote・MoneyForward の良いとこ取りに、AIと記憶ドリルをプラス。',
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
                      borderRadius: BorderRadius.circular(10),
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
      const _CompetitorRow('Chatwork', '¥700〜/月', '40+', false),
      const _CompetitorRow('ジョブカン', '¥500〜/月', '60+', false),
      const _CompetitorRow('自分株式会社', '完全無料', '13サービス分', true),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
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
            '月額数千円のSaaS6本分の機能を、無料で使えます。',
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
        borderRadius: BorderRadius.circular(20),
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
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitWaitlist() async {
    final email = _waitlistEmailController.text.trim();
    if (email.isEmpty) return;
    final client = _supabaseClientOrNull;
    if (client == null) return;
    try {
      await client.from('newsletter_waitlist').insert({
        'email': email,
        'source': 'landing',
      });
      if (!mounted) return;
      setState(() => _waitlistSubmitted = true);
      _waitlistEmailController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _waitlistSubmitted = true); // show success even on duplicate
    }
  }

  Future<void> _submitFeatureRequest() async {
    final title = _featureRequestTitleController.text.trim();
    if (title.isEmpty) return;
    final client = _supabaseClientOrNull;
    if (client == null) return;
    try {
      await client.from('feature_requests').insert({'title': title});
      if (!mounted) return;
      setState(() => _featureRequestSubmitted = true);
      _featureRequestTitleController.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() => _featureRequestSubmitted = true);
    }
  }

  /// ウェイトリスト登録・機能リクエストセクション
  Widget _buildWaitlistAndFeatureRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ウェイトリスト
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F5FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDDD6FE)),
          ),
          child: _waitlistSubmitted
              ? const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF7C3AED), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '登録ありがとうございます！\nリリース情報をお届けします。',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4C1D95),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('📬', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '新機能リリースをメールで受け取る',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '登録不要で最新アップデートをお知らせします。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _waitlistEmailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'your@email.com',
                              hintStyle: const TextStyle(fontSize: 13),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFDDD6FE)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFDDD6FE)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submitWaitlist,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            '登録',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        // 機能リクエスト
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: _featureRequestSubmitted
              ? const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFFD97706), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'リクエストを受け付けました！\n開発計画に反映します。',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('💡', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'こんな機能が欲しい！をリクエスト',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '登録不要。要望を直接開発チームに届けられます。',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _featureRequestTitleController,
                            decoration: InputDecoration(
                              hintText: '例: Notionのデータベース機能が欲しい',
                              hintStyle: const TextStyle(fontSize: 12),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFFDE68A)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFFFDE68A)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _submitFeatureRequest,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            '送信',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildGrowthSection() {
    return LiveGrowthBanner(
      growthService: widget.growthService,
      compact: true,
      title: '登録者数と閲覧者数をライブ表示',
      subtitle: '今どれだけ人が見ていて、どれだけ登録されているかをその場で追えます。',
    );
  }

  Widget _pvKpi(String label, String value) {
    return Container(
      width: 112,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style: TextStyle(color: Colors.black54),
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
                    avatar: const Icon(Icons.trending_up, size: 18),
                    label: const Text('登録を増やす'),
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '登録者数を増やすための次の一手を決めたい',
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
                          style: const TextStyle(color: Colors.black54),
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

  Widget _buildAuthSection() {
    return KeyedSubtree(
      key: const Key('landing_auth_section'),
      child: Card(
        key: _authSectionKey,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    borderRadius: BorderRadius.circular(14),
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
                '保存して、明日も続きから再開',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? '登録すると、AI提案・実行履歴・明日の続きが残ります。最短は Magic Link です。'
                    : '既存ユーザーも Magic Link が最短です。パスワード入力なしで、そのまま再開できます。',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BenefitChip(icon: Icons.save, label: 'AI提案を保存'),
                  _BenefitChip(icon: Icons.replay, label: '明日も続きから再開'),
                  _BenefitChip(icon: Icons.history, label: '履歴を残す'),
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
                  color: Colors.black54,
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
                            : 'Magic Linkで保存を始める',
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
                style: TextStyle(fontSize: 12, color: Colors.black45),
              ),
              if (_showInboxShortcut) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(14),
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
                          color: Colors.black54,
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
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text(
                    'Googleログインは設定済み環境でのみ表示します。現在は Magic Link を主導線にしています。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
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
                      style: TextStyle(color: Colors.black45),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'パスワード',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
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

  Widget _buildShareSection() {
    final lastChannel = _shareSnapshot.lastChannel;
    final lastChannelLabel = lastChannel == null
        ? 'まだ未実施'
        : LandingShareService.channelLabel(lastChannel);

    return Card(
      key: const Key('landing_share_section'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SNSでシェアして流入を増やす',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              '各SNSごとに計測付きリンクを発行します。今日のシェア回数と累計をその場で確認できます。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            if (_isLoadingShareStats)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _shareMetricCard('今日のシェア', '${_shareSnapshot.todayCount}回'),
                  _shareMetricCard('累計シェア', '${_shareSnapshot.totalCount}回'),
                  _shareMetricCard('直近チャネル', lastChannelLabel),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: LandingShareService.supportedChannels.map((channel) {
                  final label = LandingShareService.channelLabel(channel);
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text(
                        '${_shareSnapshot.countFor(channel)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    label: Text(label),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _shareActionButton(
                  channel: LandingShareService.channelX,
                  icon: Icons.alternate_email,
                ),
                _shareActionButton(
                  channel: LandingShareService.channelLine,
                  icon: Icons.chat_bubble_outline,
                ),
                _shareActionButton(
                  channel: LandingShareService.channelFacebook,
                  icon: Icons.thumb_up_alt_outlined,
                ),
                _shareActionButton(
                  channel: LandingShareService.channelCopy,
                  icon: Icons.link,
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'シェアリンクには流入元の識別子を付与しています。管理画面でもシェア回数とチャネル別内訳を確認できます。',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareMetricCard(String label, String value) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _shareActionButton({
    required String channel,
    required IconData icon,
  }) {
    final label = LandingShareService.channelLabel(channel);
    final isActive = _activeShareChannel == channel;
    return FilledButton.icon(
      key: Key('landing_share_button_$channel'),
      onPressed:
          _activeShareChannel == null ? () => _shareLandingPage(channel) : null,
      icon: isActive
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
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
                  _buildHeroSection(),
                  const SizedBox(height: 20),
                  _buildBuildInPublicSection(),
                  const SizedBox(height: 20),
                  _buildSocialProofStatsSection(),
                  const SizedBox(height: 20),
                  _buildMigrationGuideSection(),
                  const SizedBox(height: 20),
                  _buildComparisonLinksSection(),
                  const SizedBox(height: 20),
                  _buildPricingComparisonSection(),
                  const SizedBox(height: 20),
                  _buildUniqueValueSection(),
                  const SizedBox(height: 20),
                  _buildGetStartedStepsSection(),
                  const SizedBox(height: 20),
                  _buildImportCtaSection(),
                  const SizedBox(height: 20),
                  _buildReferralInviteSection(),
                  if (_pendingReferralCode != null) const SizedBox(height: 20),
                  _buildGrowthSection(),
                  const SizedBox(height: 20),
                  _buildTrialSection(),
                  const SizedBox(height: 20),
                  _buildAuthSection(),
                  const SizedBox(height: 20),
                  _buildPublicMemoSection(),
                  const SizedBox(height: 20),
                  _buildShareSection(),
                  const SizedBox(height: 20),
                  _buildWaitlistAndFeatureRequestSection(),
                  const SizedBox(height: 20),
                  _buildPvSection(),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
