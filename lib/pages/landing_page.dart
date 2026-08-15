import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/growth_acquisition_service.dart';
import '../services/growth_mission_service.dart';
import '../services/landing_conversion_experiment_service.dart';
import '../services/landing_page_adapter.dart';
import '../services/landing_signup_completion_service.dart';
import '../services/pending_landing_trial_service.dart';
import '../services/route_visibility_observer.dart';
import '../widgets/live_growth_banner.dart';

enum _LandingIntent { work, learning, money }

class LandingPage extends StatefulWidget {
  final LandingPageAdapter adapter;
  final GrowthMissionService growthService;
  final LandingConversionExperimentService conversionExperimentService;
  final LandingSignupCompletionService signupCompletionService;
  final PendingLandingTrialService pendingTrialService;
  final GrowthAcquisitionService acquisitionService;
  final LandingExperimentAssignment? experimentAssignment;
  final bool? analyticsEnabled;
  final Uri? landingUri;

  const LandingPage({
    super.key,
    LandingPageAdapter? adapter,
    GrowthMissionService? growthService,
    LandingConversionExperimentService? conversionExperimentService,
    LandingSignupCompletionService? signupCompletionService,
    PendingLandingTrialService? pendingTrialService,
    GrowthAcquisitionService? acquisitionService,
    this.experimentAssignment,
    this.analyticsEnabled,
    this.landingUri,
  })  : adapter = adapter ?? const SupabaseLandingPageAdapter(),
        growthService = growthService ?? const GrowthMissionService(),
        pendingTrialService =
            pendingTrialService ?? const PendingLandingTrialService(),
        signupCompletionService =
            signupCompletionService ?? const LandingSignupCompletionService(),
        acquisitionService =
            acquisitionService ?? const GrowthAcquisitionService(),
        conversionExperimentService = conversionExperimentService ??
            const LandingConversionExperimentService();

  @visibleForTesting
  static bool analyticsEnabledForUri(Uri? uri) {
    return uri?.queryParameters['lp_qa'] != '1';
  }

  @visibleForTesting
  static bool shouldFocusTrialForUri(Uri? uri) {
    return uri?.queryParameters['lp_intent']?.trim().toLowerCase() == 'trial';
  }

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with RouteAware {
  static const bool _googleLoginFeatureEnabled = bool.fromEnvironment(
    'LANDING_GOOGLE_LOGIN_ENABLED',
    defaultValue: false,
  );

  final _emailController = TextEditingController();
  final _trialEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _trialPromptController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _trialEmailFocusNode = FocusNode();
  final GlobalKey _trialSectionKey = GlobalKey();
  final GlobalKey _authSectionKey = GlobalKey();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _magicLinkCooldownTimer;

  bool _isLoading = false;
  bool _isTrialLoading = false;
  bool _isSignUp = true;
  bool _obscurePassword = true;
  bool _showPasswordAuth = false;
  bool _showSaveCtaPrompt = false;
  bool _showInboxShortcut = false;
  bool _showAllUniqueFeatures = false;
  int _magicLinkCooldownSeconds = 0;
  int _achievementCount = 0;
  int _totalUsers = 0;
  int _publicMemoCount = 0;
  List<Map<String, String>> _recentAchievements = [];

  String? _trialAction;
  String? _trialReason;
  String? _lastMagicLinkEmail;
  String? _pendingReferralCode;
  _LandingIntent _selectedIntent = _LandingIntent.work;
  LandingExperimentAssignment? _experimentAssignment;
  Future<LandingExperimentAssignment>? _experimentBootstrapFuture;
  Future<String>? _experimentVisitorIdFuture;
  final Set<String> _recordedExperimentStages = <String>{};
  bool _landingIntentHandled = false;

  Uri? get _landingUri => widget.landingUri ?? (kIsWeb ? Uri.base : null);
  GrowthAcquisitionService get _acquisitionService => widget.acquisitionService;

  bool get _analyticsEnabled {
    final override = widget.analyticsEnabled;
    if (override != null) {
      return override;
    }
    return LandingPage.analyticsEnabledForUri(_landingUri);
  }

  SupabaseClient? get _supabaseClientOrNull {
    try {
      return Supabase.instance.client;
    } on AssertionError {
      return null;
    } catch (_) {
      return null;
    }
  }

  // 可視化ゲート: 公開メモ等の deep link を直接開くと初期ルート展開で LP が
  // 不可視のまま下に積まれる。その状態で LP View を計上すると「見ていない LP」
  // が今日の登録ファネル最上段に混入するため、可視になるまで計測を遅延する。
  // 社会的証明は公開集計で、初期ルート判定との競合で欠落させないため先読みする。
  bool _visibleBootstrapDone = false;

  @override
  void initState() {
    super.initState();
    _experimentAssignment = widget.experimentAssignment;
    if (_experimentAssignment != null) {
      _experimentBootstrapFuture = Future.value(_experimentAssignment!);
    } else {
      _experimentBootstrapFuture = _loadConversionExperiment();
    }
    _authSubscription = widget.adapter.authStateChanges().listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        unawaited(
          widget.signupCompletionService.completeIfPending(
            signupUserId: data.session?.user.id,
            signupEmail: data.session?.user.email,
            accountCreatedAt: DateTime.tryParse(
              data.session?.user.createdAt ?? '',
            ),
          ),
        );
        unawaited(widget.growthService.applyPendingReferralIfPossible());
        _goToAuthenticatedEntry();
      }
    });
    unawaited(_bootstrapReferralInvite());
    unawaited(_loadSocialProofStats());
  }

  Future<LandingExperimentAssignment> _loadConversionExperiment() async {
    final assignment = await widget.conversionExperimentService.resolve(
      uri: _landingUri,
    );
    if (mounted && _experimentAssignment != assignment) {
      setState(() => _experimentAssignment = assignment);
    } else {
      _experimentAssignment = assignment;
    }
    return assignment;
  }

  Future<LandingExperimentAssignment> _resolveExperimentAssignment() {
    final assignment = _experimentAssignment;
    if (assignment != null) {
      return Future.value(assignment);
    }
    return _experimentBootstrapFuture ??= _loadConversionExperiment();
  }

  Future<String> _resolveExperimentVisitorId() {
    return _experimentVisitorIdFuture ??=
        widget.conversionExperimentService.resolveVisitorId();
  }

  bool _hypothesisEnabled(String hypothesisId) {
    return _experimentAssignment?.enables(hypothesisId) ?? true;
  }

  Future<void> _recordConversionStage(String stage) async {
    if (!_analyticsEnabled) {
      return;
    }
    String? visitorId;
    try {
      final assignment = await _resolveExperimentAssignment();
      visitorId = await _resolveExperimentVisitorId();
      if (!_recordedExperimentStages.add(stage)) {
        return;
      }
      await widget.adapter.recordConversionEvent(
        eventKey: assignment.eventKey(stage),
        visitorId: visitorId,
      );
    } catch (error) {
      debugPrint('LP conversion event failed ($stage): $error');
    }
    if (visitorId == null ||
        !GrowthAcquisitionService.firstUserFunnelStages.contains(stage)) {
      return;
    }
    try {
      await _acquisitionService.recordFirstUserFunnelStage(
        stage: stage,
        visitorId: visitorId,
        currentUri: _landingUri,
      );
    } catch (error) {
      debugPrint('First-user LP funnel event failed ($stage): $error');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      deepLinkVisibilityRouteObserver.subscribe(this, route);
    }
    // route が取れない (テスト直 pump 等) 場合は従来どおり即時計測する。
    if (route == null || route.isCurrent) {
      _startVisibleBootstrapOnce();
    }
  }

  @override
  void didPopNext() {
    // 上のルートが pop され LP が初めて実際に表示された。
    _startVisibleBootstrapOnce();
  }

  void _startVisibleBootstrapOnce() {
    if (_visibleBootstrapDone) return;
    _visibleBootstrapDone = true;
    unawaited(_loadAchievementCount());
    // LP View 計測 (今日の登録ファネルの最上段)。失敗は adapter 側で握る。
    if (_analyticsEnabled) {
      unawaited(widget.adapter.recordLpView());
    }
    unawaited(_recordConversionStage('view'));
    if (MediaQuery.sizeOf(context).width < 720) {
      unawaited(_recordConversionStage('mobile_view'));
    }
    unawaited(_honorLandingIntent());
  }

  Future<void> _honorLandingIntent() async {
    if (_landingIntentHandled ||
        !LandingPage.shouldFocusTrialForUri(_landingUri)) {
      return;
    }
    _landingIntentHandled = true;

    // The H03 assignment can move the trial below auth. Wait for that layout
    // decision before honoring the campaign promise to start with the trial.
    await _resolveExperimentAssignment();
    if (!mounted) return;
    _scheduleTrialSectionScroll();
  }

  @override
  void dispose() {
    deepLinkVisibilityRouteObserver.unsubscribe(this);
    _authSubscription?.cancel();
    _magicLinkCooldownTimer?.cancel();
    _emailController.dispose();
    _trialEmailController.dispose();
    _passwordController.dispose();
    _trialPromptController.dispose();
    _emailFocusNode.dispose();
    _trialEmailFocusNode.dispose();
    super.dispose();
  }

  String? get _webRedirectUrl {
    if (!kIsWeb) return null;
    return Uri.base.resolve('/').toString();
  }

  bool get _isFirstUserGrowthTraffic {
    final uri = _landingUri;
    if (uri == null) return false;
    return GrowthAcquisitionService.isFirstUserGrowthUri(uri);
  }

  bool get _usesHeroTrial {
    return _isFirstUserGrowthTraffic || _hypothesisEnabled('h03');
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
    if (client.auth.currentUser == null) return;
    try {
      final response = await client.functions.invoke(
        'core-hub',
        body: {'action': 'achievements.list', 'period': '今週の実績'},
      );
      final data = response.data as Map<String, dynamic>? ?? {};
      final list = (data['achievements'] as List<dynamic>?) ?? [];
      final recent = list
          .take(5)
          .map((e) {
            final m = e as Map<String, dynamic>;
            final completedAt = m['completed_at']?.toString() ?? '';
            String dateStr = '';
            final dt = DateTime.tryParse(completedAt)?.toLocal();
            if (dt != null) {
              dateStr =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
            }
            return <String, String>{
              'title': m['title']?.toString() ?? '',
              'date': dateStr,
            };
          })
          .where((m) => m['title']!.isNotEmpty)
          .toList();

      // 全件カウントは別で取得
      final allResponse = await client.functions.invoke(
        'core-hub',
        body: {'action': 'achievements.list'},
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
    try {
      final stats = await widget.adapter.loadSocialProofStats();
      if (!mounted) return;
      setState(() {
        _totalUsers = stats.totalUsers;
        _publicMemoCount = stats.publicMemoCount;
      });
    } catch (error) {
      debugPrint('Landing social proof load failed: $error');
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
    final tracksSignup = _isSignUp && _analyticsEnabled;
    try {
      if (_isSignUp) {
        if (tracksSignup) {
          await _markSignupCompletionPending(email: email);
        }
        unawaited(_recordSignupSubmitStages());
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
      if (tracksSignup) {
        await widget.signupCompletionService.cancelPending(email: email);
      }
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      if (tracksSignup) {
        await widget.signupCompletionService.cancelPending(email: email);
      }
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
      if (_analyticsEnabled) {
        await _markSignupCompletionPending();
      }
      unawaited(_recordSignupSubmitStages());
      unawaited(_acquisitionService.recordLandingSignupSubmit());
      final launched = await widget.adapter.signInWithGoogle(
        redirectTo: _webRedirectUrl,
      );
      if (!launched) {
        if (_analyticsEnabled) {
          await widget.signupCompletionService.cancelPending();
        }
        _showMessage('Googleログイン画面を開けませんでした。再読み込みしてから再実行してください。');
      }
    } on LandingPageAuthUnavailableException {
      if (_analyticsEnabled) {
        await widget.signupCompletionService.cancelPending();
      }
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      if (_analyticsEnabled) {
        await widget.signupCompletionService.cancelPending();
      }
      _showMessage(_resolveGoogleAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMagicLink({String? emailOverride}) async {
    final email = (emailOverride ?? _emailController.text).trim();
    if (email.isEmpty) {
      _showMessage('Magic Link を送るにはメールアドレスを入力してください。');
      return;
    }

    if (_emailController.text.trim() != email) {
      _emailController.text = email;
    }

    setState(() => _isLoading = true);
    try {
      if (_analyticsEnabled) {
        await _markSignupCompletionPending(email: email);
      }
      unawaited(_recordSignupSubmitStages());
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
      if (_analyticsEnabled) {
        await widget.signupCompletionService.cancelPending(email: email);
      }
      _showMessage('認証機能を初期化できませんでした。');
    } catch (error) {
      if (_analyticsEnabled) {
        await widget.signupCompletionService.cancelPending(email: email);
      }
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

  Future<void> _markSignupCompletionPending({String? email}) async {
    try {
      final assignment = await _resolveExperimentAssignment();
      final visitorId = await _resolveExperimentVisitorId();
      await widget.signupCompletionService.markPending(
        email: email,
        eventKey: assignment.eventKey('signup_complete'),
        visitorId: visitorId,
      );
    } catch (error) {
      debugPrint('Landing signup completion attribution failed: $error');
    }
  }

  void _startMagicLinkCooldown() {
    _magicLinkCooldownTimer?.cancel();
    if (!mounted) return;
    setState(() => _magicLinkCooldownSeconds = 30);
    _magicLinkCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) {
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
    unawaited(_recordTrialStages());
    final input = _trialPromptController.text.trim();
    final instantSuggestion = _buildTrialFallbackSuggestion(input);
    setState(() {
      _trialAction = instantSuggestion.$1;
      _trialReason = instantSuggestion.$2;
      _showSaveCtaPrompt = true;
    });
    _scrollToTrialMagicLink(requestFocus: false);
    if (input.isEmpty) {
      return;
    }

    setState(() => _isTrialLoading = true);
    try {
      final result = await widget.adapter.improveTrialPrompt(prompt: input);
      final parsed = _parseTrialAiResponse(result);
      if (!mounted) return;
      setState(() {
        _trialAction = parsed.$1;
        _trialReason = parsed.$2;
        _showSaveCtaPrompt = true;
      });
    } catch (e) {
      debugPrint('Trial preview failed: $e');
      unawaited(_recordConversionStage('trial_fallback'));
      final fallback = _buildTrialFallbackSuggestion(input);
      if (!mounted) return;
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = fallback.$2;
        _showSaveCtaPrompt = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isTrialLoading = false);
      }
    }
  }

  Future<void> _recordTrialStages() async {
    if (_analyticsEnabled) {
      try {
        await widget.adapter.recordTrialRun();
      } catch (error) {
        debugPrint('Landing trial analytics failed: $error');
      }
    }
    await _recordConversionStage('trial');
  }

  Future<void> _recordSignupSubmitStages() async {
    await _recordConversionStage('signup_submit');
    if (mounted && MediaQuery.sizeOf(context).width < 720) {
      await _recordConversionStage('mobile_signup_submit');
    }
  }

  Future<void> _recordSaveStages() async {
    if (_analyticsEnabled) {
      try {
        await widget.adapter.recordSaveCta();
      } catch (error) {
        debugPrint('Landing save analytics failed: $error');
      }
    }
    await _recordConversionStage('save_cta');
  }

  void _promptRegistrationForTrialSave() {
    unawaited(_recordSaveStages());
    setState(() {
      _showSaveCtaPrompt = true;
      _isSignUp = true;
    });
    _showMessage('この結果を保存するには登録が必要です。下の登録セクションから30秒で保存を開始できます。');
    _scrollToAuthSection();
  }

  Future<void> _saveTrialWithMagicLink() async {
    unawaited(_recordSaveStages());
    setState(() {
      _showSaveCtaPrompt = true;
      _isSignUp = true;
    });
    final email = _trialEmailController.text.trim();
    final action = _trialAction?.trim() ?? '';
    final reason = _trialReason?.trim() ?? '';
    final prompt = _trialPromptController.text.trim();
    if (email.isNotEmpty &&
        prompt.isNotEmpty &&
        action.isNotEmpty &&
        reason.isNotEmpty) {
      try {
        await widget.pendingTrialService.save(
          email: email,
          intent: _selectedIntent.name,
          prompt: prompt,
          action: action,
          reason: reason,
        );
      } catch (error) {
        debugPrint('Pending landing trial save failed: $error');
      }
    }
    await _sendMagicLink(emailOverride: email);
  }

  void _runQuickTrialSample(
    String prompt, {
    bool recordHeroCta = false,
  }) {
    if (recordHeroCta) {
      unawaited(_recordConversionStage('hero_cta'));
    }
    _trialPromptController
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
    unawaited(_runTrialActionPreview());
  }

  void _runHeroTrialActionPreview() {
    unawaited(_recordConversionStage('hero_cta'));
    unawaited(_runTrialActionPreview());
  }

  void _scrollToTrialSection() {
    final currentContext = _trialSectionKey.currentContext;
    if (currentContext != null) {
      unawaited(
        Scrollable.ensureVisible(
          currentContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.08,
        ),
      );
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trialContext = _trialSectionKey.currentContext;
      if (!mounted || trialContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          trialContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.08,
        ),
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _scheduleTrialSectionScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToTrialSection();
    });
    WidgetsBinding.instance.scheduleFrame();
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

  void _scrollToTrialMagicLink({bool requestFocus = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final captureContext = _trialEmailFocusNode.context;
      if (!mounted || captureContext == null) return;
      if (requestFocus) {
        _trialEmailFocusNode.requestFocus();
      }
      unawaited(
        Scrollable.ensureVisible(
          captureContext,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          alignment: 0.12,
        ),
      );
    });
  }

  void _handleHeroSignup() {
    unawaited(_recordConversionStage('hero_cta'));
    _scrollToAuthSection();
  }

  void _handleStickySignup() {
    unawaited(_recordConversionStage('sticky_cta'));
    if (_trialAction != null && _hypothesisEnabled('h04')) {
      unawaited(_recordSaveStages());
      setState(() {
        _showSaveCtaPrompt = true;
        _isSignUp = true;
      });
      _scrollToTrialMagicLink();
      return;
    }
    _scrollToAuthSection();
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
        return Uri(scheme: 'mailto', path: email);
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
      if (launched && _analyticsEnabled) {
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
      return ('今日の最重要を1件決める', '入力が空でも、最初に最重要を1件に絞るだけで着手はかなり早くなります。');
    }

    if (text.contains('メール') ||
        text.contains('SMS') ||
        text.contains('DM') ||
        text.contains('連絡')) {
      return ('未読の確認を1件だけ終える', '連絡系は放置コストが高いので、最初に1件だけ処理すると全体が進みます。');
    }

    if (RegExp(
      r'支出|出費|家計|固定費|変動費|予算|浪費|お金|請求|明細|サブスク|収入|貯金|資産|借金|返済|税金|投資|削減',
    ).hasMatch(text)) {
      return ('先月の明細で最も高い固定費を1件特定', '最大の固定費を先に確認すると、削減効果を比較しやすくなるためです。');
    }

    if (RegExp(r'学習|勉強|英語|読書|復習|試験|資格|暗記|教材|授業').hasMatch(text)) {
      return ('今日復習する教材を1件開く', '対象を1件に固定すると、短時間でも復習を完了しやすくなるためです。');
    }

    if (RegExp(
      r'LP|ランディング|登録|サインアップ|フォーム|CTA|ボタン|申込|コンバージョン|離脱',
      caseSensitive: false,
    ).hasMatch(text)) {
      return ('登録ボタン直前の価値説明を1文見直す', '登録後に得られる成果を明確にすると、迷った訪問者が判断しやすくなるためです。');
    }

    if (RegExp(r'健康|運動|睡眠|食事|体重|病院|服薬').hasMatch(text)) {
      return ('直近の健康記録を1件確認', '最新の状態を1件確認すると、今日変える行動を具体化しやすくなるためです。');
    }

    if (RegExp(r'情報整理|ノート|メモ|資料|ファイル|知識|文書').hasMatch(text)) {
      return ('未整理のメモを1件開き用途を1行追記', '用途を1行で固定すると、残すか行動に変えるかを判断しやすくなるためです。');
    }

    if (RegExp(r'予定|時間|先送り|後回し|着手|集中|習慣').hasMatch(text)) {
      return ('今日の予定から先送り中の1件を選ぶ', '対象を1件に固定すると、使える時間をその行動に割り当てやすくなるためです。');
    }

    if (text.contains('考える') ||
        text.contains('悩む') ||
        text.contains('迷う') ||
        text.contains('決めたい')) {
      return ('判断条件を1つだけ書き出す', '条件を先に言語化すると、迷いが減って次の行動が決まりやすくなります。');
    }

    if (text.contains('タスク') ||
        RegExp('[Tt][Oo][Dd][Oo]').hasMatch(text) ||
        text.contains('仕事') ||
        text.contains('課題')) {
      return ('10分だけ使って最重要を1件に絞る', '最重要を1件だけ先に固定すると、その後の先延ばしが大きく減ります。');
    }

    return ('20分だけ動ける最小単位に分解する', '大きすぎる作業は始めにくいので、最小単位まで分けてから着手してください。');
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

  String _promptForIntent(_LandingIntent intent) {
    switch (intent) {
      case _LandingIntent.work:
        return '仕事で抱えているタスクから、今日の最優先を1件に絞りたい';
      case _LandingIntent.learning:
        return '学びたいことが多すぎるので、今日やる学習を1件に絞りたい';
      case _LandingIntent.money:
        return '家計と資産の状況から、今日確認すべきことを1件に絞りたい';
    }
  }

  void _selectIntent(_LandingIntent intent) {
    final prompt = _promptForIntent(intent);
    setState(() {
      _selectedIntent = intent;
      _trialPromptController
        ..text = prompt
        ..selection = TextSelection.collapsed(offset: prompt.length);
    });
    unawaited(_recordConversionStage('intent'));
  }

  Widget _buildIntentSelector() {
    return Container(
      key: const Key('landing_h02_intent_selector'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controls = SegmentedButton<_LandingIntent>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: _LandingIntent.work,
                icon: Icon(Icons.work_outline, size: 18),
                label: Text('仕事'),
              ),
              ButtonSegment(
                value: _LandingIntent.learning,
                icon: Icon(Icons.school_outlined, size: 18),
                label: Text('学習'),
              ),
              ButtonSegment(
                value: _LandingIntent.money,
                icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: Text('お金'),
              ),
            ],
            selected: {_selectedIntent},
            onSelectionChanged: (selection) => _selectIntent(selection.first),
          );
          final action = OutlinedButton.icon(
            onPressed: _isTrialLoading
                ? null
                : () {
                    _runQuickTrialSample(_promptForIntent(_selectedIntent));
                    _scrollToTrialSection();
                  },
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('このテーマで1件試す'),
          );

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'まず、整理したいテーマを選ぶ',
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _promptForIntent(_selectedIntent),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                const SizedBox(height: 12),
                controls,
                const SizedBox(height: 10),
                action,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 18),
              controls,
              const SizedBox(width: 10),
              action,
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductProofSection() {
    const steps = [
      _ConversionProofStep(
        icon: Icons.edit_note_outlined,
        eyebrow: '入力',
        title: '頭の中を1行で書く',
        detail: '「仕事が多すぎて、何から始めるか決められない」',
      ),
      _ConversionProofStep(
        icon: Icons.auto_awesome,
        eyebrow: 'AI提案',
        title: '今やる1件だけに絞る',
        detail: '「止まっている案件の次の確認先を1人決める」',
      ),
      _ConversionProofStep(
        icon: Icons.bookmark_added_outlined,
        eyebrow: '継続',
        title: '保存して明日へつなぐ',
        detail: '提案、実行履歴、次の一手を同じ場所から再開',
      ),
    ];

    return Container(
      key: const Key('landing_h06_product_proof'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF102A43),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '登録すると何が変わるか',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '情報を増やすのではなく、次の行動を減らすための仕事OSです。',
            style: TextStyle(
              color: Color(0xFFB9D5EA),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    steps[0],
                    const _ProofArrow(vertical: true),
                    steps[1],
                    const _ProofArrow(vertical: true),
                    steps[2],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: steps[0]),
                  const _ProofArrow(),
                  Expanded(child: steps[1]),
                  const _ProofArrow(),
                  Expanded(child: steps[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBrandDefinitionSection() {
    const principles = <String>[
      '自分が人生のCEOとして決める',
      '時間・お金・スキルを資産として育てる',
      '他人ではなく昨日の自分をKPIにする',
    ];

    return Container(
      key: const Key('landing_brand_definition'),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            key: const Key('landing_brand_definition_heading'),
            header: true,
            child: const Text(
              '自分株式会社とは',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '自分株式会社は、自分自身を一つの会社に見立て、人生のCEOとして仕事・学習・お金・健康を経営する考え方をAIで実践できるライフマネジメントアプリです。AIが状況を整理し、今日やる1件まで具体化します。',
            style: TextStyle(
              color: Color(0xFF475569),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final principle in principles)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    principle,
                    style: const TextStyle(
                      color: Color(0xFF26364A),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('landing_brand_philosophy_link'),
            onPressed: () => Navigator.of(context).pushNamed('/philosophy'),
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: const Text('9つの基本理念を見る'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F7AE0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversionSequence() {
    final trialFirst = _usesHeroTrial;
    return Column(
      key: Key(
        trialFirst
            ? 'landing_h03_trial_before_auth'
            : 'landing_h03_auth_before_trial',
      ),
      children: [
        _buildAuthSection(),
        if (!trialFirst) ...[const SizedBox(height: 20), _buildTrialSection()],
      ],
    );
  }

  Widget? _buildMobileStickyCta(double screenWidth) {
    if (screenWidth >= 720 || !_hypothesisEnabled('h09')) {
      return null;
    }
    final hasTrialResult = _trialAction != null && _hypothesisEnabled('h04');
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('landing_h09_mobile_sticky_cta'),
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDCE7F2))),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '無料コア・カード不要',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: _handleStickySignup,
              icon: Icon(
                hasTrialResult
                    ? Icons.bookmark_add_outlined
                    : Icons.arrow_forward,
                size: 17,
              ),
              label: Text(hasTrialResult ? 'この提案を保存' : '無料で始める'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F7AE0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final firstUserGrowthMode = _isFirstUserGrowthTraffic;
    final trialFirst = _usesHeroTrial;
    return _WorkflowLandingHero(
      achievementCount: _achievementCount,
      showFirstUserGrowthCta: firstUserGrowthMode,
      outcomeFirstMessage: _hypothesisEnabled('h01'),
      showRiskReversal: _hypothesisEnabled('h05'),
      inlineTrial: trialFirst
          ? _buildTrialSection(
              heroMode: true,
              firstUserGrowthMode: firstUserGrowthMode,
            )
          : null,
      onGetStarted: _handleHeroSignup,
      onWatchDemo: _scrollToTrialSection,
    );
  }

  // ignore: unused_element
  Widget _buildLegacyHeroSection() {
    final heroPanel = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4ED), Color(0xFFF6F7FF), Color(0xFFF9FAFB)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFF6B35).withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.06),
            blurRadius: 36,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  height: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // メインヘッドライン
          const Text(
            '今日やるべき1件を、AIが決める。\n迷いが消えて、毎日が動き出す。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.5,
              letterSpacing: 0.48,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Gmail・予定・お金・習慣・学習までを1画面に集約。Notion や MoneyForward を渡り歩く代わりに、AIが今日の最優先1件を提案します。AI大学・英語速読で「学ぶ習慣」まで続く、人生を経営する無料コックピットです。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF475569),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          const _GettingStartedStrip(),
          const SizedBox(height: 14),
          const _PlannerGapStrip(),
          const SizedBox(height: 14),
          // 実績バッジ
          if (_achievementCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '✓ 実装済み $_achievementCount件の機能',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // プライマリ CTA
          SizedBox(
            height: 56,
            child: Tooltip(
              message: 'アカウントを作成して提案を保存できます。登録は30秒程度です。',
              child: FilledButton.icon(
                key: const Key('landing_register_button'),
                onPressed: _scrollToAuthSection,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text(
                  '無料で始める',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  shadowColor: const Color(0xFFFF6B35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // セカンダリ CTA
          SizedBox(
            height: 48,
            child: Tooltip(
              message: '登録不要でAI提案を1件試せます。',
              child: OutlinedButton.icon(
                key: const Key('landing_trial_scroll_button'),
                onPressed: _scrollToTrialSection,
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text(
                  '登録なしで1件試す',
                  style: TextStyle(fontWeight: FontWeight.w600, height: 1.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF6B35),
                  side: const BorderSide(color: Color(0xFFFF6B35)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
      ),
    );

    return Column(
      key: const Key('landing_hero_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ★ AI 開発 7 原則: 実装規律 (Rule 23)
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/ai-dev-principles'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F1F1F), Color(0xFF1A2E2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF26A69A).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF26A69A).withValues(alpha: 0.15),
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
                    color: const Color(0xFF26A69A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFF26A69A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI 開発 7 原則 — 実装規律',
                        style: TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Auth/Security/Observability/Circuit Breaker — 動画 5 本 + チェックリスト',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF26A69A),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
        // ★ 基本理念: 自分株式会社 — The Enterprise of Self
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/philosophy'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F0F1F), Color(0xFF1A1A2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF7986CB).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.15),
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
                    color: const Color(0xFF7986CB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: Color(0xFF7986CB),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基本理念 — 自分株式会社',
                        style: TextStyle(
                          color: Color(0xFFFAFAFA),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'あなたが CEO。動画 5 本 + 9 原則 + 完全文字起こし',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF7986CB),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
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
                color: const Color(0xFFFF6B35).withValues(alpha: 0.6),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
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
                    color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Color(0xFFFF6B35),
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
                              height: 1.6,
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
                  color: Color(0xFFFF6B35),
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
              border: Border.all(color: const Color(0xFFFF6B35).withAlpha(70)),
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
                    height: 1.6,
                  ),
                ),
                Spacer(),
                Icon(Icons.arrow_forward, color: Color(0xFFFF6B35), size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        heroPanel,
      ],
    );
  }

  Future<void> _shareOnX() async {
    const siteUrl = 'https://my-web-app-b67f4.web.app/';
    final userCount = _totalUsers > 10 ? '登録者$_totalUsers人突破！' : '';
    final text = 'スマホでギター録音＋21のSaaSを1アプリに統合。'
        '自分株式会社 $userCount\n'
        '無料コアから使えます。Proで支援できます👇\n'
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
              child: Text(
                '𝕏',
                style: TextStyle(
                  color: Color(0xFF1DA1F2),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
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
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'フォロワーに紹介すると登録者が増えてサービスが成長します',
                  style: TextStyle(
                    color: Color(0xFF71767B),
                    fontSize: 11,
                    height: 1.6,
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'シェア',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
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
                const Icon(Icons.recommend_outlined, color: Color(0xFF4CAF50)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Referral invite active: $pendingReferralCode',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      height: 1.5,
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
        color: _totalUsers > 10
            ? const Color(0xFF7986CB)
            : const Color(0xFFFFB74D),
        bgColor: _totalUsers > 10
            ? const Color(0xFF3D5AFE).withValues(alpha: 0.15)
            : const Color(0xFFFF9800).withValues(alpha: 0.15),
        value: _totalUsers > 10 ? '$_totalUsers' : '募集中',
        label: _totalUsers > 10 ? '登録ユーザー数' : '初期ユーザー',
      ),
      (
        icon: Icons.article_outlined,
        color: const Color(0xFF4FC3F7),
        bgColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
        value: _publicMemoCount > 0 ? '$_publicMemoCount' : '–',
        label: '公開メモ数',
      ),
      (
        icon: Icons.check_circle_outline,
        color: const Color(0xFF81C784),
        bgColor: const Color(0xFF4CAF50).withValues(alpha: 0.15),
        value: _achievementCount > 0 ? '$_achievementCount' : '本番',
        label: _achievementCount > 0 ? '実装済み機能数' : 'サービス稼働',
      ),
    ];

    return Container(
      key: const Key('landing_social_proof_stats'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
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
              const Icon(Icons.bar_chart, color: Color(0xFF7986CB), size: 18),
              const SizedBox(width: 8),
              const Text(
                'リアルタイム実績',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.6,
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
                    height: 1.5,
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
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB0B0B0),
                            height: 1.6,
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
                Expanded(
                  child: Text(
                    '他サービスからの移行は3ステップ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'データを失わずに、5分で完了します。',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
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
                        Text(
                          guide.icon,
                          style: const TextStyle(fontSize: 18, height: 1.4),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${guide.competitor} からの移行',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: guide.color,
                            height: 1.5,
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
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                e.value,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
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
      (
        key: 'evernote',
        name: 'Evernote',
        emoji: '🐘',
        color: Color(0xFF00A82D),
      ),
      (
        key: 'moneyforward',
        name: 'MoneyForward',
        emoji: '💰',
        color: Color(0xFF0D47A1),
      ),
      (key: 'x', name: 'X (Twitter)', emoji: '𝕏', color: Color(0xFF1C1C1E)),
      (
        key: 'animaworks',
        name: 'Animaworks',
        emoji: '🎯',
        color: Color(0xFFFF6B35),
      ),
      (
        key: 'claude-code',
        name: 'Claude Code',
        emoji: '🤖',
        color: Color(0xFFD97706),
      ),
      (key: 'codex', name: 'Codex', emoji: '⚡', color: Color(0xFF10B981)),
      (key: 'replit', name: 'Replit', emoji: '💻', color: Color(0xFFF5821B)),
      (
        key: 'netkeiba',
        name: 'netkeiba',
        emoji: '🐎',
        color: Color(0xFF7C3AED),
      ),
      (
        key: 'openclaw',
        name: 'OpenClaw',
        emoji: '🦾',
        color: Color(0xFF0EA5E9),
      ),
      (
        key: 'claude-cowork',
        name: 'Claude Cowork',
        emoji: '🏛️',
        color: Color(0xFF6366F1),
      ),
      (
        key: 'chatwork',
        name: 'Chatwork',
        emoji: '🏢',
        color: Color(0xFFE53935),
      ),
      (key: 'slack', name: 'Slack', emoji: '💬', color: Color(0xFF4A154B)),
      (key: 'jobcan', name: 'ジョブカン', emoji: '📋', color: Color(0xFF059669)),
      (key: 'amazon', name: 'Amazon', emoji: '📦', color: Color(0xFFFF9900)),
      (key: 'google', name: 'Google', emoji: '🔍', color: Color(0xFF4285F4)),
      (
        key: 'google_agent_builder',
        name: 'Google Agent Builder',
        emoji: '🤖',
        color: Color(0xFF34A853),
      ),
      (
        key: 'microsoft',
        name: 'Microsoft',
        emoji: '🪟',
        color: Color(0xFF00A4EF),
      ),
      (key: 'discord', name: 'Discord', emoji: '🎮', color: Color(0xFF5865F2)),
      (key: 'line', name: 'LINE', emoji: '💚', color: Color(0xFF06C755)),
      (
        key: 'facebook',
        name: 'Facebook',
        emoji: '👥',
        color: Color(0xFF1877F2),
      ),
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFEEF2FF),
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
                        '1894社との機能比較',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      Text(
                        '気になるサービスをタップして機能・価格を比較しよう',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: Text(
                        '${c.emoji}  vs ${c.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.color,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/competitors'),
                icon: const Icon(Icons.grid_view_rounded, size: 14),
                label: const Text(
                  '全1894社を見る →',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
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
          const Icon(Icons.business, color: Color(0xB3FFFFFF), size: 36),
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
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Slack・Chatwork・ジョブカンを1つに統合。法人導入無料。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
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
                height: 1.5,
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
                const Icon(
                  Icons.rocket_launch,
                  size: 16,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 6),
                const Text(
                  '今週の開発実績',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Text(
                  '全 $_achievementCount 件実装済み',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6EE7B7),
                    height: 1.5,
                  ),
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
                    const Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a['title'] ?? '',
                        style: const TextStyle(fontSize: 12, height: 1.6),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      a['date'] ?? '',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        height: 1.5,
                      ),
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
      (
        Icons.account_tree,
        '0xFF4F46E5',
        'AI組織OS (12部署20人)',
        '自然言語でタスクを入力するだけで最適な部署が自動受付。ゴールを12部署に自動分解・配布。SlackもJiraも不要。',
      ),
      (
        Icons.smart_toy,
        '0xFF6366F1',
        'AI役員会議 (MAGI)',
        'CEO/CFO/CMO/CHROのAIペルソナが多角的にアドバイス。Notionにもない独自機能。',
      ),
      (Icons.memory, '0xFF10B981', '記憶ドリル', '忘却曲線に基づく反復学習。Evernoteにはない学習機能。'),
      (
        Icons.account_balance_wallet,
        '0xFFF59E0B',
        '経営コックピット',
        '収支・資産・KPIを一画面で管理。MoneyForwardの代替として使える。',
      ),
      (
        Icons.upload_file,
        '0xFF3B82F6',
        'Excel/Word/Notion/Evernoteから0ステップ移行',
        'XLSX・DOCX・CSV・ENEXをそのままインポート。Notionのエージェント対応より先に企業データを取り込める。移行コストゼロ。',
      ),
      (Icons.hub, '0xFFA855F7', 'マインドマップ', '思考の整理をビジュアルで。ノートと連携。'),
      (Icons.public, '0xFF22C55E', '公開メモ・SEO', 'メモをURLで共有。知識のアウトプットが集客につながる。'),
      (
        Icons.psychology_alt,
        '0xFF8B5CF6',
        '性格診断 (16タイプ MBTI)',
        'MBTIベースの自己分析でメモ術・学習スタイルを最適化。恋愛相性診断も。他にはない自己理解機能。',
      ),
      (
        Icons.do_not_disturb_on,
        '0xFFEF4444',
        '思考妨害排除ガード',
        'SNS・通知・散漫思考をブロックして深い集中を守る。フォーカスセッション中はアプリ内通知を自動ミュート。他のサービスにはない認知コスト削減機能。',
      ),
      (
        Icons.visibility_off,
        '0xFFF97316',
        '見栄ガード',
        'かっこつけず・見栄をはらずに生きる仕組み。SNS承認欲求や衝動的な自己顕示を記録・可視化して断ち切る。競合21社に存在しない自己規律機能。',
      ),
      (
        Icons.money_off,
        '0xFF14B8A6',
        '浪費トラッキング',
        '投資を除いた資産放出を日次で記録・可視化。無意識の浪費パターンを把握してMoneyForwardを超える節制管理。',
      ),
      (
        Icons.corporate_fare,
        '0xFF6366F1',
        '12部署AI仮想組織',
        '自分一人でCEO・CFO・CMO・開発部・営業部など12部署20人のAI組織を持てる。Slack・Chatwork・ジョブカン対抗の次世代チーム管理。',
      ),
      (
        Icons.group_add,
        '0xFF22C55E',
        '友達招待・紹介コード',
        '紹介リンクをシェアするだけで招待実績が積み上がる。バイラル成長の仕組みを個人レベルで実装。',
      ),
      (
        Icons.chat_bubble_outline,
        '0xFF8B5CF6',
        'ノートコメント・リアクション',
        '公開メモにコメント・絵文字リアクション・OGPシェアが可能。Notion/Evernoteを超えるソーシャル連携機能。',
      ),
      (
        Icons.notifications,
        '0xFF0EA5E9',
        '通知センター',
        'アプリ内の全通知を一元管理。未読バッジ・フィルタリング・既読管理で重要な更新を見逃さない。',
      ),
      (
        Icons.draw,
        '0xFF64748B',
        '電子署名',
        '契約書・同意書をアプリ内で電子署名。法人・フリーランス向け。DocuSign連携と直接競合する機能を無料コアで提供。',
      ),
      (
        Icons.storefront,
        '0xFFEC4899',
        'コンビニ経営シミュレーション',
        '自分株式会社の中でコンビニを経営。春夏秋冬の季節・天気・トレンドをAIが反映した経営判断ゲーム。競合21社に存在しないゲーミフィケーション。',
      ),
      (
        Icons.timer,
        '0xFF10B981',
        '集中タイマー',
        'ポモドーロ/ディープフォーカスモードで深い集中を実現。思考妨害排除ガードと連携しSNS通知を自動ブロック。',
      ),
      (
        Icons.edit_note,
        '0xFF7C3AED',
        'AI文章アシスタント',
        'メモ・ブログ・SNS投稿の文章作成・推敲・要約をAIが支援。Notion AIを超える日本語特化の文章強化機能。',
      ),
      (
        Icons.fitness_center,
        '0xFFF59E0B',
        '浪費耐性トレーニング',
        '買わずに耐えた回数・防いだ出費・取り戻した時間を毎日記録。我慢を筋トレのように可視化して浪費を断つ精神性を育てる。',
      ),
      (
        Icons.video_camera_back,
        '0xFFDC2626',
        'バイラル動画パイプライン',
        'AIが広告動画を自動生成→X/SNSに自動投稿→効果測定まで全自動。TikTok・YouTube Shortsを超えるバイラル成長エンジン。',
      ),
      (
        Icons.translate,
        '0xFF0891B2',
        '語学学習',
        'フラッシュカード・発音練習・進捗管理をAIが支援。Duolingoを超える日本語圏特化の語学習得システム。',
      ),
      (
        Icons.restaurant_menu,
        '0xFFB45309',
        'レシピ・献立管理',
        '食材管理・献立提案・栄養分析をAIが自動化。MoneyForwardの家計管理と食費を連携した生活密着型機能。',
      ),
      (
        Icons.flight_takeoff,
        '0xFF0369A1',
        '旅行計画・行程管理',
        '行程管理・現地情報・費用管理を一元化。Google旅行機能を超えるAI行程最適化で旅をもっと豊かに。',
      ),
      (
        Icons.pets,
        '0xFF7E22CE',
        'ペット健康管理',
        'ワクチン記録・健康日記・体重管理をアプリ内で完結。競合21社にない個人ライフ全領域カバーの証明。',
      ),
      (
        Icons.photo_library,
        '0xFF065F46',
        'フォトギャラリー',
        'AI自動分類・思い出管理・家族共有まで対応。Google フォトに対抗しつつ自分株式会社データとシームレス連携。',
      ),
      (
        Icons.emoji_events,
        '0xFFEAB308',
        '習慣ゲーミフィケーション',
        'ストリーク・バッジ・XP獲得で習慣を楽しく継続。Duolingo式ゲーミフィケーションで継続率3倍。',
      ),
      (
        Icons.code,
        '0xFF0F172A',
        'コードプレイグラウンド',
        'ブラウザだけでコードを書いて即実行。学習・プロト制作・アイデア検証を一気通貫でサポート。',
      ),
      (
        Icons.home_work,
        '0xFF0284C7',
        '不動産管理',
        '物件情報・家賃・更新日を一元管理。投資用物件の収益計算もAIが自動化。',
      ),
      (
        Icons.school,
        '0xFF4338CA',
        'eラーニング',
        'コース作成・受講管理・修了証発行まで対応。Udemyを超える自分専用LMSを無料で構築。',
      ),
      (
        Icons.directions_car,
        '0xFF374151',
        '車両管理',
        '車検・整備記録・燃費管理を自動追跡。複数台・法人向け車両フリートにも対応。',
      ),
      (
        Icons.work_history,
        '0xFF059669',
        '採用ボード',
        '求人票作成・応募者管理・面接スケジューリングをAIが支援。HR SaaSの代替を無料コアで実現。',
      ),
      (
        Icons.sensors,
        '0xFF7C3AED',
        'IoTダッシュボード',
        '家電・センサー・スマートデバイスをダッシュボードで一元管理。スマートホームを自分株式会社に統合。',
      ),
      (
        Icons.gavel,
        '0xFFDC2626',
        '法務管理 / Harvey AI',
        '契約書・利用規約・コンプライアンスチェックをAIが支援。法律AI特化のHarveyをバックエンドに据えた自動法務レビュー基盤として、社内法務の下書き・論点整理・引用付き確認を一気通貫で進められます。',
      ),
      (
        Icons.mark_email_read,
        '0xFF0891B2',
        'メールテンプレート管理',
        '返信テンプレート・差し込み変数・ABテストをAIが最適化。メール生産性を10倍に引き上げる。',
      ),
      (
        Icons.security,
        '0xFF16A34A',
        '2FA/多要素認証',
        'TOTP・SMSで全アカウントを堅牢に保護。パスワードマネージャーと連携して認証情報を一元管理。',
      ),
      (
        Icons.music_video,
        '0xFFE11D48',
        '公開ギターギャラリー',
        'スマホで録音したギター演奏をUGCとして公開共有。OGP・sitemap対応でSEO流入も獲得。競合21社にない音楽SNS機能。',
      ),
      (
        Icons.calendar_month,
        '0xFF0F766E',
        '月次カレンダービュー',
        '月間スケジュールをカレンダー形式で一覧表示。タスク・習慣・イベントをTimeTree/Googleカレンダーを超える統合ビューで管理。',
      ),
      (
        Icons.dynamic_feed,
        '0xFF0F172A',
        'アクティビティフィード',
        '自分の行動ログ・達成記録・コミュニティ更新をタイムライン表示。Discord/Slackを超えるパーソナルアクティビティ可視化。',
      ),
      (
        Icons.emoji_events,
        '0xFFF59E0B',
        '報酬・達成バッジ',
        '習慣継続・目標達成でポイントとバッジを獲得。ゲーミフィケーションでモチベーションを維持し継続率を劇的に改善。',
      ),
      (
        Icons.alarm,
        '0xFF0369A1',
        '支払いリマインダー',
        '月次サブスク・公共料金・ローン返済を自動リマインド。MoneyForwardを超える決済管理と浪費防止の統合機能。',
      ),
      (
        Icons.how_to_vote,
        '0xFF1D4ED8',
        '地方選挙インテリジェンス',
        '47都道府県×1年先の選挙を自動追跡。X/SNSへの候補者分析スレッドをAIが自動生成。競合21社に存在しない市民×AI政治情報プラットフォーム。',
      ),
      (
        Icons.videocam,
        '0xFF6D28D9',
        'ビデオ会議・ミーティング管理',
        'ビデオ通話・会議室予約・議事録自動生成をワンストップで提供。Zoom/Google Meetを超える統合ミーティングプラットフォーム。',
      ),
      (
        Icons.inbox,
        '0xFF0F766E',
        'スマート受信箱',
        'AIがメール・通知・タスクを自動分類・優先度付け。重要度の低いメールを自動整理して認知コストを削減。',
      ),
      (
        Icons.lock,
        '0xFF7C3AED',
        'パスワード金庫',
        '全パスワードをゼロ知識暗号化で保護・自動入力・セキュリティ監査。1Password/Bitwardenを超える統合認証管理を無料コアで提供。',
      ),
      (
        Icons.podcasts,
        '0xFFF59E0B',
        'ポッドキャスト管理',
        'ポッドキャスト制作・公開・リスナー分析をワンストップ。Anchor/Spotifyを超える個人ポッドキャスタープラットフォーム。',
      ),
      (
        Icons.screen_share,
        '0xFF0369A1',
        'スクリーン録画',
        'ブラウザから直接スクリーン録画・即時共有。Loomを超える非同期ビデオコミュニケーションを無料コアで提供。',
      ),
      (
        Icons.storefront,
        '0xFFE11D48',
        'オークション・マーケットプレイス',
        'フリマ・オークション出品から決済まで一括管理。メルカリ/ヤフオクの機能を自分株式会社内で完結。',
      ),
      (
        Icons.mic,
        '0xFF059669',
        '音声メモ文字起こし',
        '録音した音声をAIが自動文字起こし・要約。会議・インタビュー・アイデアメモをテキスト化して検索可能に。',
      ),
      (
        Icons.draw,
        '0xFF6D28D9',
        '仮想ホワイトボード',
        'オンラインホワイトボードでアイデアをビジュアル整理。Miro/FigJamを超えるコラボ可能なキャンバス。',
      ),
      (
        Icons.alt_route,
        '0xFF0891B2',
        'ワークフロー自動化',
        'タスク・メール・通知をトリガー&アクションで自動化。Zapierを超えるノーコード業務自動化エンジン。',
      ),
      (
        Icons.qr_code,
        '0xFF374151',
        'QRコード生成',
        'URLやテキストを即座にQRコードに変換・保存・共有。業務・個人・イベント告知に対応した多用途QRジェネレーター。',
      ),
      (
        Icons.admin_panel_settings,
        '0xFF0F172A',
        'アクセス制御・権限管理',
        'ロール設定・ユーザー権限付与・アクセスログを一元管理。法人チームのセキュリティをジョブカンを超えるきめ細かさで実現。',
      ),
      (
        Icons.inventory,
        '0xFF059669',
        '在庫・バーコード管理',
        '商品バーコードスキャン・在庫数追跡・入出庫記録を自動化。Amazonの倉庫管理機能を個人・中小企業向けに無料コアで提供。',
      ),
      (
        Icons.dashboard_customize,
        '0xFF7C3AED',
        'テンプレート広場',
        'ビジネス・学習・ライフスタイル・技術開発など6カテゴリ18種のテンプレートを即適用。Notionマーケットプレイスを超える日本語特化テンプレート集。',
      ),
      (
        Icons.bar_chart,
        '0xFF0891B2',
        'パーソナルダッシュボード',
        'ノート数・タスク達成率・習慣ストリーク・集中時間をチャートで可視化。Notion 3.4のダッシュボードビューを超えるAIパーソナルKPI分析。',
      ),
      (
        Icons.calendar_today,
        '0xFF4285F4',
        'Google カレンダー同期',
        'アプリの予定 ↔ Google カレンダーを双方向リアルタイム同期。OAuth 2.0による安全な認証で複数カレンダーを一元管理。Google カレンダーを超える統合スケジュール管理を実現。',
      ),
      (
        Icons.account_balance_wallet,
        '0xFF00B900',
        'MoneyForward 連携',
        '銀行・証券・クレカ・電子マネー残高を自動取り込み。総資産・取引履歴をAIが分析して資産増加アドバイス。MoneyForwardを超える無料コアの資産管理を提供。',
      ),
      (
        Icons.webhook,
        '0xFF4A154B',
        'Slack 連携 × 6部署 KPI 通知 (法人導入)',
        '売上/資産/タスク/習慣など 6 部署 KPI の達成をリアルタイムで Slack チャンネルへ配信。Webhook URL 設定のみで即稼働。法人チームへの AI 組織 OS 導入差別化軸。',
      ),
      (
        Icons.psychology,
        '0xFF6366F1',
        'マイスキル (AIプロンプト再利用)',
        'よく使うAIプロンプトをスキルとして保存・1タップ再利用。Slackワークフロービルダーを超える個人AI自動化テンプレートを無制限登録。',
      ),
      (
        Icons.chat_bubble_outline,
        '0xFF5865F2',
        'チームチャット',
        'チャンネル別リアルタイムメッセージング。Discord/LINEを超える目的別チャンネル管理と検索可能なメッセージ履歴をセキュアに提供。',
      ),
      (
        Icons.favorite_outline,
        '0xFF22C55E',
        'ヘルスコーチ',
        '歩数・カロリー・睡眠・水分をAIが統合分析し毎日パーソナルアドバイス。Livenを超える日本語完全対応の無料ヘルスケアコーチング。',
      ),
      (
        Icons.shopping_cart_outlined,
        '0xFFF97316',
        'ショッピングリスト',
        '買い物リスト作成・価格管理・購入チェックをスマート管理。Amazonの購入管理機能を超えるAI節約提案付きの無料コアのショッピングアシスタント。',
      ),
      (
        Icons.notifications_active,
        '0xFF5865F2',
        'Discord 通知連携',
        'タスク完了・習慣達成・日次サマリーをリアルタイムでDiscordチャンネルに通知。Webhook URLを設定するだけで即稼働する自動通知ルーティング。',
      ),
      (
        Icons.notifications_active,
        '0xFF06C755',
        'LINE 通知連携',
        'タスク完了・習慣達成・ゴール達成をLINEにリアルタイム通知。LINE Notify トークン1枚で設定完了。LINEを超えるタスク×通知の完全統合。',
      ),
      (
        Icons.merge_type,
        '0xFF24292F',
        'GitHub PR 管理',
        'GitHubリポジトリのPull Request一覧・レビュー状況・マージ統計をアプリ内で一元管理。開発とライフマネジメントを自分株式会社に完全統合。',
      ),
      (
        Icons.psychology_alt,
        '0xFF4338CA',
        '思考妨害パターン診断',
        '4つの質問で最大の思考妨害要因を特定し禁欲ガードの対象を自動設定。SNS・ゲーム・動画など6カテゴリから衝動パターンを診断し、集中が途切れる時間帯と前兆サインを可視化するAIセルフケアツール。',
      ),
      (
        Icons.analytics,
        '0xFF6366F1',
        '週次 Slip パターンレポート',
        '思考妨害・衝動のslipを曜日別・時間帯別・要因別に分析。30日間のデータから最も危険な時間帯と要因を特定し、改善トレンドを可視化。',
      ),
      (
        Icons.flag,
        '0xFF10B981',
        'ゴール追跡',
        'OKR形式でスモールゴールから人生目標まで一元管理。進捗追跡・マイルストーン設定・期限リマインドをAIが支援し、目標達成率を劇的に向上。',
      ),
      (
        Icons.auto_awesome,
        '0xFF8B5CF6',
        'AIサマリー',
        'ノート・タスク・習慣データをAIが自動要約。1日・1週間・1ヶ月の活動を3行でまとめ、意思決定に必要なインサイトを即座に提供。',
      ),
      (
        Icons.trending_up,
        '0xFF0EA5E9',
        '収益予測',
        '過去データと市場トレンドからAIが収益を予測。キャッシュフロー・売上推移を視覚化してビジネス計画を最適化。MoneyForwardを超えるAI財務分析。',
      ),
      (
        Icons.bookmarks,
        '0xFFF59E0B',
        'ブックマーク同期',
        'ブラウザのブックマークをアプリと双方向同期。AI自動タグ付け・分類・検索で必要な情報を即座に発見。Notionリンクデータベースを超える知識管理。',
      ),
      (
        Icons.wb_sunny_outlined,
        '0xFF06B6D4',
        '天気・環境ウィジェット',
        '現在地の天気・気温・紫外線をダッシュボードに常時表示。天気に合わせた活動提案・外出可否判断をAIが自動生成し、ライフマネジメントと環境情報を完全統合。',
      ),
      (
        Icons.monetization_on,
        '0xFFEF4444',
        'アフィリエイト管理',
        'アフィリエイトリンク管理・クリック追跡・報酬分析を一元化。収益源の多様化を自動最適化するAI収益化エンジン。',
      ),
      (
        Icons.business_center,
        '0xFF0F766E',
        'CRM・営業パイプライン',
        'リード管理・商談ステージ追跡・成約予測をAIが自動化。Salesforceを超えるパーソナルCRMを無料で実現。',
      ),
      (
        Icons.table_chart,
        '0xFF6366F1',
        'スプレッドシートDB',
        'Notionデータベースを超える多機能スプレッドシート。フィルタ・ソート・数式・API連携に対応した柔軟なデータ管理。',
      ),
      (
        Icons.schedule_send,
        '0xFFEC4899',
        'SNS投稿スケジューラー',
        'X/Instagram/FacebookへのSNS投稿を最適時間に自動予約・一括投稿。AIが投稿内容の改善案も提案するコンテンツマーケ自動化ツール。',
      ),
      (
        Icons.subscriptions,
        '0xFF7C3AED',
        'サブスク課金管理',
        'サブスクリプション請求・顧客管理・解約防止分析を自動化。Stripeを超える自分株式会社内蔵の課金エンジン。',
      ),
      (
        Icons.contacts,
        '0xFF0369A1',
        'アドレス帳・人脈管理',
        '連絡先・誕生日・交流履歴・SNSリンクを一元管理。LinkedInを超えるパーソナルCRM×人脈グラフで関係性を見える化。',
      ),
      (
        Icons.book,
        '0xFF7E22CE',
        '読書リスト管理',
        '読みたい本・読了記録・メモ・評価を一元管理。AIが次に読むべき本を推薦するパーソナル書評プラットフォーム。',
      ),
      (
        Icons.checkroom,
        '0xFFF97316',
        'ワードローブ管理',
        '所持服の登録・コーデ提案・購入計画をAIが管理。ファッションコストを削減しながらスタイルを最適化。',
      ),
      (
        Icons.eco,
        '0xFF22C55E',
        'カーボンフットプリント',
        '日常行動のCO2排出量を自動計算・可視化。移動・食事・エネルギー消費から個人の環境負荷を数値化し持続可能な生活を設計。',
      ),
      (
        Icons.timer_outlined,
        '0xFF6366F1',
        'タイムトラッキング',
        'プロジェクト別・タスク別の作業時間を自動記録。Toggleを超えるAI分析付き時間管理で生産性の無駄を即特定。',
      ),
      (
        Icons.menu_book,
        '0xFF0F766E',
        'Wikiデータベース',
        '階層式Wikiページ・社内マニュアル・チームナレッジを一元管理。Confluenceを超える個人・チーム向け知識ベースを無料コアで構築。',
      ),
      (
        Icons.view_kanban,
        '0xFFF59E0B',
        'WIPリミット管理',
        '進行中タスク数の上限設定・ボトルネック検出・フロー可視化。Jiraを超えるリーンカンバン管理で作業効率を最大化。',
      ),
      (
        Icons.rss_feed,
        '0xFFEC4899',
        '技術ブログトラッカー',
        'Zenn/Qiita/note/dev.toの投稿管理・PV分析・読者獲得トレンドを一元追跡。エンジニアの影響力成長を数値化。',
      ),
      (
        Icons.calendar_view_day,
        '0xFF6366F1',
        '予約・アポイント管理',
        '来客予約・医療予約・会議調整をカレンダー連携で一元管理。Calendlyを超えるAI最適スケジューリングシステム。',
      ),
      (
        Icons.terminal,
        '0xFF0F172A',
        'API プレイグラウンド',
        'REST API・Supabase EF・外部APIをブラウザから即テスト。Postmanを超えるアプリ内API開発環境で実装速度を10倍に。',
      ),
      (
        Icons.download,
        '0xFF0891B2',
        'データ分析エクスポート',
        'ノート・タスク・習慣・財務データをCSV/JSON/PDFで一括エクスポート。BIツールへの連携や外部分析が自由自在。',
      ),
      (
        Icons.local_parking,
        '0xFF374151',
        '駐車場予約管理',
        '駐車場の空き確認・予約・支払い管理をアプリ内で完結。物件・店舗・イベント会場の駐車枠を効率的に運用。',
      ),
      (
        Icons.view_in_ar,
        '0xFF6D28D9',
        'AR ナビゲーション',
        '拡張現実(AR)で店舗・施設・商品へのルートをスマホ画面に重畳表示。競合21社に存在しない空間×AIナビゲーション機能。',
      ),
      (
        Icons.account_balance,
        '0xFF059669',
        '資産管理',
        '不動産・株・仮想通貨・現金など全資産をポートフォリオ形式で一元管理。AIが資産配分の最適化提案をリアルタイムに実行。',
      ),
      (
        Icons.trending_up,
        '0xFFF97316',
        '行動・習慣ログ詳細',
        '1分単位の行動ログ・習慣連続記録・パターン分析をAIが自動集計。自分の生活リズムを科学的に可視化して最適な時間設計を実現。',
      ),
      (
        Icons.delete_sweep,
        '0xFF7E22CE',
        '断捨離アシスト',
        'モノ・デジタルファイル・人間関係の断捨離を3ステップでAI支援。手放す/残す/保留を即決できる捨て活チェックリストで身軽な自分株式会社を構築。',
      ),
      (
        Icons.lock_clock,
        '0xFF0F172A',
        'プリズンモード',
        'スマホ依存・SNS中毒を断ち切る超高集中モード。指定時間内はSNS/動画を完全シャットアウトし、思考妨害をゼロに。刑務所級の集中力を自分で設計できる唯一のツール。',
      ),
      (
        Icons.hub,
        '0xFF1D9BF0',
        'ソーシャルフィード',
        'コミュニティメンバーの達成記録・習慣ストリーク・ノート共有をタイムラインで表示。FacebookとDiscordを超えるパーソナル×コミュニティ融合フィード。',
      ),
      (
        Icons.psychology,
        '0xFF10B981',
        '意思決定チェック',
        '重要な判断を迷わせる「認知バイアス」をAIが診断・可視化。見栄・衝動・過去の呪縛から解放されたクリアな意思決定を支援する競合21社にない独自機能。',
      ),
      (
        Icons.account_balance_wallet,
        '0xFF6366F1',
        'デジタルウォレット',
        'ポイント・ギフト券・仮想通貨・電子マネー残高を一元管理。多様化する決済手段をスマートに統合して家計管理と資産管理を完全連携。',
      ),
      (
        Icons.cruelty_free,
        '0xFFA855F7',
        'バーチャルペット',
        'アプリのタスク達成・習慣継続でペットが成長するゲーミフィケーション。モチベーション維持の最強トリガーを個性的なデジタルコンパニオンで実現。',
      ),
      (
        Icons.home_repair_service,
        '0xFF0F766E',
        'リアル断捨離記録',
        '実物のモノを写真で記録しながら断捨離を進行。手放した物品数・削減重量・解放スペースを数値化して身軽さを可視化。',
      ),
      (
        Icons.anchor,
        '0xFF4338CA',
        '思考アンカー',
        '集中を乱す雑念・不安・タスク割り込みをその場でキャプチャしアンカーに変換。後で必ず戻ると約束することで今この瞬間の集中を守る認知制御機能。',
      ),
      (
        Icons.flash_on,
        '0xFF8B5CF6',
        '思考キャプチャ',
        'ひらめき・アイデア・メモを0.5秒でキャプチャ。Inboxに溜めてAIが後から自動分類・タグ付けするGTD式思考管理システム。',
      ),
      (
        Icons.manage_search,
        '0xFF0EA5E9',
        'セマンティック検索',
        'キーワード一致ではなく意味・文脈で全ノート・タスク・習慣を横断検索。Notionの検索機能を超えるAI意味理解型の全文検索エンジン。',
      ),
      (
        Icons.receipt_long,
        '0xFF059669',
        '購買ログ・支出記録',
        '全購入品の記録・家計簿自動分類・支出トレンド分析。Amazonの購買履歴を超える節約インサイトをAIがリアルタイムで提供。',
      ),
      (
        Icons.audiotrack,
        '0xFF6D28D9',
        'オーディオエフェクト',
        'ギター・楽器・音声にエフェクト処理・音質補正・ミキシングをブラウザだけで実現。GarageBandを超えるポータブル音楽制作スタジオ。',
      ),
      (
        Icons.image,
        '0xFFF97316',
        'AI画像生成',
        'テキストから画像を即時生成。プレゼン・SNS・ブログ素材をAIが自動制作。Midjourneyを超えるライフマネジメント統合型AIクリエイティブツール。',
      ),
      (
        Icons.search,
        '0xFF0F766E',
        'AI横断検索',
        '自分株式会社の全データ(ノート・タスク・習慣・財務)をAIが横断検索。Notionの検索・Googleを超えるパーソナルナレッジ検索エンジン。',
      ),
      (
        Icons.balance,
        '0xFF4338CA',
        '現実確認チェック',
        '自分の目標・計画・実績を客観的にスコアリングし「見栄・感情・バイアス」を排除した現実ベースの意思決定を支援。唯一無二のAI自己客観化機能。',
      ),
      (
        Icons.compare_arrows,
        '0xFF8B5CF6',
        '相性チェック',
        '人・目標・習慣・ライフスタイルの相性をAIが多角分析。恋愛・ビジネスパートナー・チームメンバーとの相性スコアを科学的に算出。',
      ),
      (
        Icons.analytics_outlined,
        '0xFFFE4E1E',
        'サイトマップ分析',
        'サイトの全URLを可視化・SEO健全性チェック・クロール最適化をAIが自動分析。Googleサーチコンソールを超えるサイト構造把握ツール。',
      ),
      (
        Icons.feedback,
        '0xFF22C55E',
        '顧客フィードバック',
        'ユーザーの声・評価・要望を一元収集・AI分析・優先度付け。Intercomを超える個人×AI顧客インサイト管理プラットフォーム。',
      ),
      (
        Icons.history,
        '0xFF0891B2',
        '変更履歴管理',
        'コード・ドキュメント・設定の変更履歴を自動追跡。Changelogを自動生成してチームと変更情報を透明に共有。',
      ),
      (
        Icons.payments,
        '0xFF10B981',
        '支払いチャンネル台帳',
        '複数の支払い手段・口座・チャンネルを台帳形式で一元管理。誰に何をいくら支払ったかをAIが自動仕訳・可視化。',
      ),
      (
        Icons.smart_toy,
        '0xFF7C3AED',
        'AI自律エージェント',
        '指定ゴールに向けてタスクを自律分解・実行するAIエージェント。AutoGPTを超える自分株式会社専用の自律実行AI。人間が指示しなくても仕事が進む。',
      ),
      (
        Icons.support_agent,
        '0xFF0369A1',
        'AI仮想秘書',
        'スケジュール・タスク・メール返信をAIが全自動管理。アシスタント雇用コストをゼロにする自分株式会社の専属デジタル秘書。',
      ),
      (
        Icons.insert_chart,
        '0xFF6366F1',
        '利用統計ダッシュボード',
        'アプリの全機能利用状況・ユーザー行動・機能別エンゲージメントをリアルタイム可視化。自分のライフデータを科学する管理者コックピット。',
      ),
      (
        Icons.label,
        '0xFFF59E0B',
        'タグ・カテゴリ管理',
        'ノート・タスク・習慣・ファイルのタグ体系を一元設計。AI自動タグ付けと手動分類を組み合わせた最強の知識分類システム。',
      ),
      (
        Icons.assistant,
        '0xFF10B981',
        'AI文章添削',
        '日本語文章の誤字・文法・表現をAIがリアルタイム添削。ブログ・メール・報告書の品質を即座に向上させる自分株式会社内蔵の校正エンジン。',
      ),
      (
        Icons.workspace_premium,
        '0xFFDC2626',
        'プレミアムコンテンツ販売',
        'ノート・テンプレート・スキルをコンテンツとして販売・収益化。Gumroadを超えるナレッジマーケットプレイスを自分株式会社に内蔵。',
      ),
      (
        Icons.groups,
        '0xFF6D28D9',
        'オンラインコミュニティ',
        'テーマ別コミュニティ・勉強会・習慣チャレンジをアプリ内で開催。Discordを超える目的特化型コミュニティプラットフォーム。',
      ),
      (
        Icons.favorite_border,
        '0xFFEC4899',
        'AIメンタルヘルスケア',
        '気分・ストレス・睡眠を毎日記録しAIが統合分析。Calm/Headspaceを超えるパーソナライズドメンタルウェルネスを自分株式会社に内蔵。',
      ),
      (
        Icons.work_outline,
        '0xFF0891B2',
        'フリーランス管理',
        '案件・請求書・契約・稼働時間・確定申告を一元管理。freee/MoneyForwardを超える個人事業主向けオールインワン経営管理ツール。',
      ),
      (
        Icons.present_to_all,
        '0xFF7C3AED',
        'AIプレゼンビルダー',
        'テーマを入力するだけでAIがスライド構成を自動生成。Gamma/Canva/Beautiful.aiを超えるライフマネジメント統合型AIプレゼン作成エンジン。',
      ),
      (
        Icons.cloud_sync,
        '0xFF0F766E',
        'データバックアップ',
        '全データを自動バックアップ・クラウド同期・ワンクリック復元。Dropbox/iCloudを超えるライフデータ保全インフラが自分株式会社に標準搭載。',
      ),
      (
        Icons.calendar_view_week,
        '0xFFD97706',
        'コンテンツカレンダー',
        'SNS・ブログ・動画の制作スケジュールをカレンダーで一元管理。コンテンツ戦略・A/Bテスト計画・公開スケジュールを可視化するクリエイター向け投稿管理ツール。',
      ),
      (
        Icons.savings,
        '0xFF10B981',
        '家計・予算プランナー',
        '月次予算設定・支出追跡・カテゴリ別分析・AI節約提案。MoneyForward/Zaimを超える家計管理とビジネス財務を同一アプリで完結させるスマート予算管理ツール。',
      ),
      (
        Icons.psychology_outlined,
        '0xFF8B5CF6',
        'ブレインダンプ',
        '頭の中にある全てをGTD式に書き出し・AIが自動分類。タスク・アイデア・心配事を即座にキャプチャしマインドをクリアにするEvernoteを超える思考整理ツール。',
      ),
      (
        Icons.account_tree_outlined,
        '0xFF0891B2',
        'プロジェクト管理',
        'ガントチャート・スプリント計画・マイルストーン・依存関係を一元管理。Asana/Jira/GitHub Projectsを超えるライフマネジメント統合型プロジェクト管理ツール。',
      ),
      (
        Icons.contact_mail_outlined,
        '0xFFD97706',
        '名刺管理',
        'OCR+AI連絡先自動抽出・タグ管理・人脈グラフ可視化。Eightを超えるAI名刺管理とビジネスネットワーキングを自分株式会社に標準搭載。',
      ),
      (
        Icons.family_restroom,
        '0xFFEC4899',
        '家族カレンダー',
        '家族のスケジュール共有・タスク割当・誕生日・記念日管理を一元化。Googleカレンダー家族共有を超えるプライバシー重視の家族専用スマートカレンダー。',
      ),
      (
        Icons.school,
        '0xFFFF6B35',
        'AI大学 (80社マスター)',
        '80社のAIプロバイダーをクイズ形式で学習。FSRS間隔反復アルゴリズムで最適なタイミングに復習。競合21社に存在しないAI業界丸ごと習得プラットフォーム。',
      ),
      (
        Icons.view_timeline,
        '0xFF3D5AFE',
        'WBS・ガントチャート',
        'マイルストーン・タスク・進捗をガントチャートで可視化。α/β/v1リリース計画を全チームで共有。Asanaを超えるプロジェクト管理をライフマネジメントに統合。',
      ),
      (
        Icons.psychology,
        '0xFF10B981',
        'FSRS間隔反復学習',
        '科学的な忘却曲線アルゴリズム(FSRS)で学習カードを最適スケジューリング。今日の復習件数を可視化し、記憶定着率を最大化する次世代スペースドリピティションシステム。',
      ),
      (
        Icons.sports,
        '0xFFF59E0B',
        '競馬AI自動予想',
        'NAR/JRAのレース情報をAIが自動収集・分析・予想。独自スコアリングアルゴリズムで穴馬・本命を特定。競合21社に存在しない趣味×AIライフマネジメント統合機能。',
      ),
    ];

    Widget outcomeRow({
      required Key key,
      required IconData icon,
      required Color color,
      required String title,
      required String description,
    }) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF526174),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const Key('landing_h15_outcome_section'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最初に、3つの成果から始める',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '134機能を覚える必要はありません。悩みを1文入力すると、登録前に10分で終わる最初の一手を返します。気に入った提案だけ無料で保存できます。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF526174),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          outcomeRow(
            key: const Key('landing_h15_outcome_work'),
            icon: Icons.task_alt,
            color: const Color(0xFF1F6FEB),
            title: '仕事を1件に絞る',
            description: '散らかったタスクから、今日動かす1件と次の一手を決めます。',
          ),
          const Divider(height: 1, color: Color(0xFFDDE4EE)),
          outcomeRow(
            key: const Key('landing_h15_outcome_money'),
            icon: Icons.savings_outlined,
            color: const Color(0xFF0B7A53),
            title: '見直す支出を1件決める',
            description: '家計の悩みから、最初に確認する固定費や明細を具体化します。',
          ),
          const Divider(height: 1, color: Color(0xFFDDE4EE)),
          outcomeRow(
            key: const Key('landing_h15_outcome_learning'),
            icon: Icons.school_outlined,
            color: const Color(0xFF9A5A00),
            title: '今日の復習を1件決める',
            description: '学びたい内容を、今日終えられる復習や練習に変えます。',
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              key: const Key('landing_h15_try_without_signup'),
              onPressed: () {
                unawaited(_recordConversionStage('feature_outcome_trial'));
                _scrollToTrialSection();
              },
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text(
                '登録なしで1件試す',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F6FEB),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'メール登録は、提案を保存するときだけ',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const Key('landing_h15_feature_catalog_toggle'),
                onPressed: () {
                  final willShow = !_showAllUniqueFeatures;
                  setState(() => _showAllUniqueFeatures = willShow);
                  if (willShow) {
                    unawaited(_recordConversionStage('feature_catalog_expand'));
                  }
                },
                icon: Icon(
                  _showAllUniqueFeatures
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 18,
                ),
                label: Text(
                  _showAllUniqueFeatures ? '3つの成果だけ見る' : '134機能をすべて見る',
                ),
              ),
              TextButton.icon(
                key: const Key('landing_h15_pricing_link'),
                onPressed: () => Navigator.of(context).pushNamed('/billing'),
                icon: const Icon(Icons.payments_outlined, size: 17),
                label: const Text('料金を見る'),
              ),
            ],
          ),
          if (_showAllUniqueFeatures) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFDDE4EE)),
            const SizedBox(height: 18),
            const Text(
              '必要になった機能を、あとから選べます',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172033),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Notion・Evernote・MoneyForwardなどで分かれていた作業を、ひとつの場所につなげます。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              key: const Key('landing_h15_feature_catalog'),
              children: features.map((f) {
                final (icon, colorHex, title, desc) = f;
                final color = Color(int.parse(colorHex));
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
                                height: 1.5,
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
              }).toList(),
            ),
          ],
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
              Icon(Icons.upload_file, color: Color(0xB3FFFFFF), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Excel / Word / Notion / Evernote から 0 ステップ移行',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'XLSX・DOCX・CSV・ENEX をアップロードするだけ。Notion のエージェント Excel 対応より先に、企業データを 0 ステップで取り込めます。移行後も元のサービスと併用可。',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xB3FFFFFF),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0x61FFFFFF)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pushNamed('/import'),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text(
              '登録なしでインポートを試す',
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  /// 競合サービスとの価格・機能数比較セクション
  Widget _buildPricingComparisonSection() {
    final rows = [
      const _CompetitorRow('Notion', '¥1,100〜/月 (+AI従量課金)', '100+', false),
      const _CompetitorRow('Evernote', '¥1,300〜/月', '50+', false),
      const _CompetitorRow('MoneyForward', '¥500〜/月', '30+', false),
      const _CompetitorRow('Slack (Agentforce)', '¥2,250〜/月', '80+', false),
      const _CompetitorRow(
        'Claude Cowork',
        '¥3,000〜/月 (Pro \$20)',
        '30+',
        false,
      ),
      const _CompetitorRow('Google Workspace', '¥680〜/月', '80+', false),
      const _CompetitorRow('Microsoft 365', '¥1,241〜/月', '90+', false),
      const _CompetitorRow('LINE AI', '¥750〜/月 (5項目)', '5', false),
      const _CompetitorRow('自分株式会社', '無料コア + Pro', '21サービス分', true),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1F0A) : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF3A2A00) : const Color(0xFFFDE68A),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('💰', style: TextStyle(fontSize: 20, height: 1.4)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'コアは無料。Proで支援と上限緩和。',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '日常の基本機能は無料で使えます。Pro/Teamは決済後に追加機能と上限緩和を提供します。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF78350F),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Free: AI質問30回/月・基本機能無料 / Pro: ¥980/月 / Team: ¥2,980/席',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF78350F),
              height: 1.6,
            ),
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
                        height: 1.5,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      row.price,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            row.isOurs ? FontWeight.w800 : FontWeight.w600,
                        color: row.isOurs
                            ? const Color(0xFFFFC107)
                            : const Color(0xFF64748B),
                        height: 1.5,
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
                            ? const Color(0xB3FFFFFF)
                            : const Color(0xFF94A3B8),
                        height: 1.5,
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
      (
        Icons.play_circle_outline,
        '1. 無料トライアル',
        'まず登録なしで1件試す。AIが今日の最優先タスクを提案。',
        Color(0xFF6366F1),
      ),
      (
        Icons.save_outlined,
        '2. 無料登録して保存',
        'メール認証だけで即登録。提案を保存して明日も続きから再開。',
        Color(0xFF10B981),
      ),
      (
        Icons.upload_file_outlined,
        '3. 既存データを移行 (XLSX/DOCX/CSV/ENEX)',
        'Excel・Word・Notion CSV・Evernote ENEX をそのままインポート。移行コストゼロ。',
        Color(0xFFF59E0B),
      ),
    ];

    final isDarkSteps = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkSteps ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isDarkSteps ? const Color(0xFF2A2A2A) : const Color(0xFFE2E8F0),
        ),
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
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'クレジットカード不要。登録は30秒。',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              height: 1.6,
            ),
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
                            height: 1.5,
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
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
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

  Widget _buildTrialSection({
    bool heroMode = false,
    bool firstUserGrowthMode = false,
  }) {
    final compactHero = heroMode && MediaQuery.sizeOf(context).width < 480;
    return KeyedSubtree(
      key: const Key('landing_trial_section'),
      child: Card(
        key: _trialSectionKey,
        elevation: heroMode ? 0 : 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          key: Key(
            heroMode ? 'landing_h03_inline_trial' : 'landing_h03_lower_trial',
          ),
          padding: EdgeInsets.all(compactHero ? 10 : (heroMode ? 16 : 18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstUserGrowthMode
                    ? 'Xから来た方へ: まず1タップで結果を見る'
                    : heroMode
                        ? '30秒で試す: いま詰まっていることは？'
                        : 'AIに「今日やる1件」を聞く',
                style: TextStyle(
                  fontSize: compactHero ? 16 : 18,
                  fontWeight: FontWeight.w800,
                  height: compactHero ? 1.3 : 1.4,
                ),
              ),
              SizedBox(height: compactHero ? 4 : 6),
              Text(
                firstUserGrowthMode
                    ? '入力・登録・カードは不要です。下のボタンだけで「今やる1件」を確認し、役立った時だけ保存できます。'
                    : compactHero
                        ? '登録不要。例を押すか1行書くと「今やる1件」を返します。'
                        : heroMode
                            ? '登録はまだ不要です。1行書くか、下の例を押すと「今やる1件」を返します。'
                            : 'まず1回だけ使って、価値があるかを確認してください。保存したくなった時だけ登録すれば十分です。',
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: compactHero ? 12 : 14,
                  height: compactHero ? 1.35 : 1.5,
                ),
              ),
              SizedBox(height: compactHero ? 6 : 12),
              _buildTrialAnswerPreview(
                compact: compactHero,
                heroMode: heroMode,
                firstUserGrowthMode: firstUserGrowthMode,
              ),
              SizedBox(height: compactHero ? 8 : 12),
              Text(
                firstUserGrowthMode ? '別の悩みで試す' : 'ほかの悩みを1タップで試す',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: compactHero ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              SizedBox(height: compactHero ? 5 : 7),
              Wrap(
                spacing: compactHero ? 6 : 8,
                runSpacing: compactHero ? 6 : 8,
                children: [
                  ActionChip(
                    key: const Key('landing_trial_sample_priority'),
                    avatar: Icon(Icons.flash_on, size: compactHero ? 16 : 18),
                    label: Text(compactHero ? '最優先' : '今日の最優先'),
                    visualDensity: compactHero ? VisualDensity.compact : null,
                    materialTapTargetSize:
                        compactHero ? MaterialTapTargetSize.shrinkWrap : null,
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今日の最優先タスクを1件に絞りたい',
                              recordHeroCta: heroMode,
                            ),
                  ),
                  ActionChip(
                    key: const Key('landing_trial_sample_plan'),
                    avatar: Icon(Icons.event_note, size: compactHero ? 16 : 18),
                    label: Text(compactHero ? '計画' : '今日の計画を立てる'),
                    visualDensity: compactHero ? VisualDensity.compact : null,
                    materialTapTargetSize:
                        compactHero ? MaterialTapTargetSize.shrinkWrap : null,
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今日1日の計画を立てて、最も重要なことに集中したい',
                              recordHeroCta: heroMode,
                            ),
                  ),
                  ActionChip(
                    key: const Key('landing_trial_sample_procrastination'),
                    avatar: Icon(Icons.done_all, size: compactHero ? 16 : 18),
                    label: Text(compactHero ? '先送り' : '先送り解消'),
                    visualDensity: compactHero ? VisualDensity.compact : null,
                    materialTapTargetSize:
                        compactHero ? MaterialTapTargetSize.shrinkWrap : null,
                    onPressed: _isTrialLoading
                        ? null
                        : () => _runQuickTrialSample(
                              '今いちばん先送りしていることを片付けたい',
                              recordHeroCta: heroMode,
                            ),
                  ),
                ],
              ),
              SizedBox(height: compactHero ? 8 : 14),
              TextField(
                key: const Key('landing_trial_prompt_input'),
                controller: _trialPromptController,
                minLines: heroMode ? 1 : 2,
                maxLines: heroMode ? 2 : 3,
                decoration: InputDecoration(
                  labelText: '例: 今日いちばん詰まっていることを簡単に書く',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.bolt),
                  isDense: compactHero,
                  contentPadding: compactHero
                      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                      : null,
                ),
              ),
              SizedBox(height: compactHero ? 8 : 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: Key(
                    heroMode
                        ? 'landing_h03_inline_trial_action'
                        : 'landing_h03_lower_trial_action',
                  ),
                  onPressed: _isTrialLoading
                      ? null
                      : heroMode
                          ? _runHeroTrialActionPreview
                          : _runTrialActionPreview,
                  icon: const Icon(Icons.play_arrow),
                  label: _isTrialLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('今やる1件を試す'),
                  style: compactHero
                      ? FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        )
                      : null,
                ),
              ),
              if (_trialAction != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF3D5AFE).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '提案された1件',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3D5AFE),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _trialAction!,
                        key: const Key('landing_trial_result_action'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.5,
                        ),
                      ),
                      if (_trialReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _trialReason!,
                          key: const Key('landing_trial_result_reason'),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (_hypothesisEnabled('h10')) ...[
                        const SizedBox(height: 10),
                        const Text(
                          '登録すると、この提案・実行履歴・次の一手が残り、明日もここから再開できます。',
                          key: Key('landing_h10_continuity_value'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF607D8B),
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_hypothesisEnabled('h04'))
                        _buildInlineTrialMagicLink()
                      else
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('landing_h04_control_save_scroll'),
                            onPressed: _promptRegistrationForTrialSave,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _hypothesisEnabled('h10')
                                  ? 'この結果を保存して明日も続ける'
                                  : 'この結果を保存して続ける',
                            ),
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

  Widget _buildTrialAnswerPreview({
    required bool compact,
    required bool heroMode,
    bool firstUserGrowthMode = false,
  }) {
    const samplePrompt = '仕事が多すぎて、何から始めるか決められない';
    return Container(
      key: const Key('landing_h11_answer_preview'),
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF6FAFE),
        border: Border(left: BorderSide(color: Color(0xFF1F7AE0), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '実際の回答例',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '入力: 「$samplePrompt」',
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: compact ? 11 : 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '今やる1件: 止まっている案件を1つ開く',
            style: TextStyle(
              color: const Color(0xFF172033),
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '最初の10分: 確認先を1人決め、連絡文の下書きを作る',
            style: TextStyle(
              color: const Color(0xFF475569),
              fontSize: compact ? 11 : 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          if (firstUserGrowthMode)
            FilledButton.icon(
              key: const Key('first_user_growth_one_tap_trial'),
              onPressed: _isTrialLoading
                  ? null
                  : () => _runQuickTrialSample(
                        samplePrompt,
                        recordHeroCta: heroMode,
                      ),
              icon: const Icon(Icons.bolt, size: 17),
              label: const Text('1タップで「今日やる1件」を出す'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F7AE0),
                foregroundColor: Colors.white,
                minimumSize: Size.fromHeight(compact ? 44 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            )
          else
            OutlinedButton.icon(
              key: const Key('landing_h11_answer_preview_action'),
              onPressed: _isTrialLoading
                  ? null
                  : () => _runQuickTrialSample(
                        samplePrompt,
                        recordHeroCta: heroMode,
                      ),
              icon: const Icon(Icons.bolt, size: 17),
              label: const Text('この例で即試す'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1F7AE0),
                minimumSize: Size.fromHeight(compact ? 40 : 44),
                side: const BorderSide(color: Color(0xFF93C5FD)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          if (firstUserGrowthMode) ...[
            const SizedBox(height: 8),
            const Wrap(
              key: Key('first_user_growth_trial_reassurance'),
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 6,
              children: [
                _TrustPoint(
                  icon: Icons.visibility_outlined,
                  label: '登録は結果を見てから',
                ),
                _TrustPoint(
                  icon: Icons.credit_card_off_outlined,
                  label: 'カード不要',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineTrialMagicLink() {
    return Container(
      key: const Key('landing_h04_inline_magic_capture'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB9D7F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'この提案を保存して、明日もここから再開',
            style: TextStyle(
              color: Color(0xFF172033),
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('landing_h04_inline_email'),
            controller: _trialEmailController,
            focusNode: _trialEmailFocusNode,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) {
              if (!_isLoading && !_isMagicLinkCoolingDown) {
                unawaited(_saveTrialWithMagicLink());
              }
            },
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              hintText: 'you@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('landing_h04_inline_magic_link'),
            onPressed: (_isLoading || _isMagicLinkCoolingDown)
                ? null
                : _saveTrialWithMagicLink,
            icon: Icon(
              _showInboxShortcut
                  ? Icons.check_circle_outline
                  : Icons.bookmark_add_outlined,
              size: 18,
            ),
            label: Text(
              _showInboxShortcut ? 'Magic Linkを送信しました' : '無料で保存して始める',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _showInboxShortcut
                ? '受信箱のリンクを開くと、保存した提案から開始できます。'
                : 'パスワード・カード入力は不要です。',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              height: 1.45,
            ),
          ),
          if (_showInboxShortcut) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('landing_h04_inline_open_inbox'),
              onPressed: _openInbox,
              icon: const Icon(Icons.open_in_new, size: 17),
              label: const Text('受信箱を開く'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    const faqs = [
      (
        q: 'Notion AI がカレンダー・メール・Slack連携を始めました。それでも違いはありますか?',
        a: '2026年4月にNotion AIはカレンダー・Mail・Slack統合をGA化しました。ただし「財務管理」「健康・習慣管理」「KPI＝昨日の自分（自己比較）」「日本語文化対応」は依然として対象外です。自分株式会社はAIが「今日やるべき1件」を決め、MoneyForward型資産管理・習慣化・AI診断まで人生6部署を一元管理します。Notionは仕事を整理しますが、自分株式会社は人生全体を整理します。基本機能は無料で、Pro/Teamで上限緩和と支援導線を用意します。',
      ),
      (
        q: '12部署20人のAI組織OSって何?',
        a: '自分1人で12の仮想部署（企画・開発・営業・CS・法務・広報・調達など）と20人のAIエージェントを動かせる機能です。自然言語でゴールを入力するだけでAIが最適な部署に自動振り分け、タスク分解・進捗管理まで担当します。SlackもJiraも不要で、1アプリで組織のように動けます。',
      ),
      (
        q: '無料のまま使い続けられますか?',
        a: 'はい。登録なしでAI提案を1回体験でき、登録後も基本機能は無料で利用できます。Pro/Teamは追加機能・上限緩和・開発支援のための有料プランです。',
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
        q: 'AIサービスが障害を起こしたらアプリが使えなくなりませんか?',
        a: 'LINE AIはOpenAI単一依存、一部のAIサービスはAnthropic単一依存のため、障害時に全機能が停止するリスクがあります。自分株式会社はAnthropic・Google Gemini・AWS Novaの3社マルチベンダー構成で、用途ごとに最適なAIを選択し、1社が障害でも他社で継続できる設計です。',
      ),
      (
        q: 'Claude Cowork (Anthropic公式) が出ましたが、何が違うの?',
        a: 'Claude Cowork (Pro \$20/月〜) は仕事のSaaS連携に特化した企業向けAIエージェントです。分離VM内で動作するため、セッションが終わるとデータが消えます。自分株式会社は「財務・健康・習慣・KPI」など人生6部署をSupabaseに永続保存し、昨日の自分と毎日比較できます。仕事だけでなく人生全体を経営したい個人CEOには、無料コアから始めて必要に応じてProへ進める自分株式会社が最適です。',
      ),
      (
        q: 'Perplexity Mac Agentに毎日のタスクを任せればよいのでは?',
        a: 'Perplexity Mac Agentは「PCの操作を代行する」ツールです。自分株式会社は代行ではなく、あなたがCEOとして最終決定権を持つ設計です（原則1）。AIは判断材料を整理し、行動はあなたが選ぶ。デスクトップ操作の自動化と、人生6部署のバランスシート管理は目的が異なります。',
      ),
      (
        q: 'OpenAI Codex DesktopとClaude Codeが競合していますが、自分株式会社はどう違うの?',
        a: 'Claude Code（423 plugins / 2,849 skills）とOpenAI Codex Desktop（Computer Use先行・20+ plugins）はツール選択の問題です。自分株式会社のai-hubは両方を含むClaude・OpenAI・Geminiを束ねる「指揮所」です。どのAIを使うかより「AIを使い分けるハブを持つか」が個人CEOの合理解。単一vendorへの依存は負債、分散が資産（原則7）。基本機能は無料で、Pro/Teamで継続支援できます。',
      ),
      (
        q: 'Notion Custom Agentsが課金されるようになりましたが?',
        a: '2026年5月4日からNotion Custom Agentsは\$10/1,000 creditの従量課金（Business/Enterprise add-on）となりました。credit残高を気にしながらAIを使うより、自分株式会社は無料コアと任意のPro/Teamを分けています。予測可能な基本利用で「KPI＝昨日の自分」を継続観察できます。',
      ),
      (
        q: 'Notion、LINE、Claude Cowork、Perplexity、Codex Desktopと比べる時の差別化軸は何ですか?',
        a: '見るべき軸は、目的の広さ、生活資本との接続、KGI/CSF/KPIの自動化、データ永続化、AIベンダー分散、無料で続けられること、そして日本語で迷わず使えることの7つです。このサイトは単体AIツールではなく、人生全体の浪費を減らす経営OSとして設計しています。',
      ),
      (
        q: 'AIベンダーを分散する意味はありますか?',
        a: 'あります。単一AIへの依存は障害、値上げ、仕様変更、品質劣化の影響をそのまま受けます。このサイトはOpenAI、Anthropic、Geminiなどを役割ごとに使い分ける前提で、継続的なモニタリングと改善を止めない設計にしています。',
      ),
      (
        q: '時間・お金・健康・体力・知能・集中力の浪費はどう減らしますか?',
        a: 'まず現状をAIが棚卸しし、KGIを決め、KGI達成に必要なCSFへ分解します。そのうえでKPIを数値化し、毎日の低ハードル行動と週次レビューに落とします。あれもこれも増やすのではなく、最初の1手を習慣化してから次へ進めます。',
      ),
      (
        q: 'KGI、CSF、KPIは毎回ユーザーが入力する必要がありますか?',
        a: '基本はAIが既存データから候補を作ります。ユーザーは提案されたKGI、CSF、KPIを確認し、必要な時だけ調整します。入力作業よりも、判断と実行に集中できることを優先しています。',
      ),
      (
        q: '継続系タスクが増えすぎて破綻しませんか?',
        a: '破綻しないよう、習慣化前のタスクを増やしすぎない仕組みにしています。未定着の行動は低ハードルの1件に絞り、3日継続や7日達成などの解除条件を満たしてから次の行動候補を開放します。',
      ),
      (
        q: 'サイトの使い方が分からない時はどうすればいいですか?',
        a: 'サイト内チャットに聞けば、画面の意味、どの機能を使うべきか、次に押すべきボタンを案内します。複雑な画面を覚えるのではなく、迷った瞬間に質問できる体験を前提にしています。',
      ),
      (
        q: 'NotebookLMなど外部AIノートとはどう使い分けますか?',
        a: 'NotebookLMは資料理解や要約に強い一方、このサイトは理解した内容をKGI/CSF/KPI、タスク、WBS、定期モニタリングへ接続します。外部AIで得た知見を、実行管理に変換する場所として使います。',
      ),
      (
        q: '法務管理ではHarvey AIをどこに使っていますか?',
        a: '法務・コンプライアンス画面のHarveyタブから、Harvey APIを使った契約レビュー、法務メモ作成、引用付き回答を実行できます。LPでは「法務管理 / Harvey AI」として、専門領域のバックエンドAIを備えていることを明示しています。',
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
      (
        q: 'すでに Notion + Slack を使っています。なぜ自分株式会社が必要ですか?',
        a: 'Notionはチームのナレッジを整理します。Slackはチームとのコミュニケーションを支えます。しかし「あなた自身の意思決定」「昨日の自分との比較」「資産・負債のバランスシート」を管理するツールはどこにも存在しません。自分株式会社はその空白を埋める個人向けライフOSです。Notionが仕事を整理するなら、自分株式会社はあなた自身を経営します。基本機能は無料で始められます。',
      ),
      (
        q: 'Notion Japan DC開設で日本市場が変わりますが、自分株式会社との違いは？',
        a: 'Notion Japan DCはエンタープライズ向けデータ居住要件への対応です。自分株式会社はすでにSupabase東京リージョンでデータを管理しており、Japan DC相当の対応は完了しています。本質的な差別化は、財務管理・AI大学(300社+の学習コンテンツ)・WBS・12インスタンスAI組織という個人CEO向け機能群です。Notionはチーム・企業向けナレッジOS、自分株式会社はあなた1人のライフOSという目的の違いがあります。',
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '気になることがあればお気軽にどうぞ。',
              style: TextStyle(color: Color(0xFF64748B), height: 1.5),
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

  Widget _buildLegalFooterLinks() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/terms'),
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('利用規約'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/tokusho'),
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: const Text('特定商取引法に基づく表記'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/privacy'),
          icon: const Icon(Icons.privacy_tip_outlined, size: 18),
          label: const Text('プライバシーポリシー'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pushNamed('/billing'),
          icon: const Icon(Icons.workspace_premium_outlined, size: 18),
          label: const Text('有料プラン'),
        ),
      ],
    );
  }

  Widget _buildNotionVsSection() {
    const rows = [
      ('自分株式会社', 'Notion'),
      ('「昨日の自分」をKPIにする意思決定OS', 'ナレッジ管理 + タスク管理'),
      ('CEO感 — 最終決定権を自分に返す設計', 'チームコラボレーション中心'),
      ('資産/負債バランスシート（時間・お金）', 'プロジェクト管理'),
      ('IPO/ウェルビーイングという個人ゴール', 'ゴール設定なし'),
      ('6部署バランス（人事最優先の自己経営）', '業務効率化のみ'),
      ('無料コア + Pro/Team', '¥1,100〜/月 + AI従量課金'),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      key: const Key('landing_notion_vs_section'),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'NotionでもSlackでもない、あなた自身のCEOオフィス',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Notionは仕事を整理します。自分株式会社はあなた自身を経営します。',
              style: TextStyle(color: Color(0xFF64748B), height: 1.6),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(1),
              },
              border: TableBorder.all(
                color:
                    isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(8),
              ),
              children: [
                for (var i = 0; i < rows.length; i++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: i == 0
                          ? (isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEEF2FF))
                          : (i.isEven
                              ? (isDark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFF9FAFB))
                              : null),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          rows[i].$1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                i == 0 ? FontWeight.w700 : FontWeight.w500,
                            color: i == 0 ? const Color(0xFF3949AB) : null,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          rows[i].$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                i == 0 ? FontWeight.w700 : FontWeight.w400,
                            color: i == 0
                                ? const Color(0xFF6B7280)
                                : const Color(0xFF9CA3AF),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    final compactMagicLink = _hypothesisEnabled('h04');
    return KeyedSubtree(
      key: const Key('landing_auth_section'),
      child: Card(
        key: _authSectionKey,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                    border: Border.all(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text(
                    'この提案を保存するには登録が必要です。Magic Link なら、メール1通でそのまま保存を始められます。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                '今すぐ無料ではじめる',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isSignUp
                    ? 'メールアドレスだけで30秒登録。AIが今日のタスクを整理し、資産管理・習慣化まで一元化。カード不要。'
                    : '既存ユーザーも Magic Link が最短です。パスワード入力なしで、そのまま再開できます。',
                style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BenefitChip(icon: Icons.card_membership, label: '無料コア'),
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
              if (_hypothesisEnabled('h10')) ...[
                const SizedBox(height: 8),
                const Text(
                  '保存される内容: AI提案 / 実行履歴 / 明日の続き',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                key: const Key('landing_h04_magic_primary'),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.5,
                ),
              ),
              if (_showInboxShortcut) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3D5AFE).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Magic Link を送信しました。受信箱でメールを開いて、そのままログインしてください。',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '届かない場合は迷惑メールも確認してください。',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.5,
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
              ],
              if (!compactMagicLink || _showPasswordAuth) ...[
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'パスワードで続ける',
                        style: TextStyle(color: Color(0xFF94A3B8), height: 1.5),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('landing_password_field'),
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
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
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
                              height: 1.5,
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
              ] else ...[
                TextButton.icon(
                  key: const Key('landing_h04_password_toggle'),
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _showPasswordAuth = true),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('パスワードを使う'),
                ),
              ],
              if (_hypothesisEnabled('h08')) ...[
                const SizedBox(height: 8),
                Container(
                  key: const Key('landing_h08_privacy_assurance'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDCE7F2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 19,
                        color: Color(0xFF247B64),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'メールはログイン確認に使用し、公開しません。決済情報はStripeが管理します。',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/privacy'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('プライバシーポリシーを確認'),
                            ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final wideHeader = screenWidth >= 860;

    return Scaffold(
      key: const Key('landing_page_scaffold'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: screenWidth < 480 ? 56 : 72,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        titleSpacing: screenWidth >= 900 ? 72 : 16,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF1F7AE0),
                borderRadius: BorderRadius.circular(7),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F7AE0).withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              key: const Key('landing_appbar_brand_heading'),
              header: true,
              child: const Text(
                '自分株式会社',
                key: Key('landing_page_title'),
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (wideHeader)
            TextButton(
              onPressed: _scrollToAuthSection,
              child: const Text(
                'ログイン',
                style: TextStyle(
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              right: screenWidth >= 900 ? 72 : 12,
              left: 8,
            ),
            child: FilledButton(
              onPressed: _handleHeroSignup,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F7AE0),
                foregroundColor: Colors.white,
                minimumSize: Size(screenWidth < 480 ? 92 : 132, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                screenWidth < 480 ? '始める' : '無料で始める',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF8FBFF),
      bottomNavigationBar: _buildMobileStickyCta(screenWidth),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 640 ? 14 : 28,
              vertical: screenWidth < 480 ? 12 : 22,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Title(
                    key: const Key('landing_document_title'),
                    title: '自分株式会社とは？ | 人生を経営するAIライフマネジメントアプリ',
                    color: const Color(0xFF1F7AE0),
                    child: const SizedBox.shrink(),
                  ),
                  _buildHeroSection(),
                  const SizedBox(height: 20),
                  _buildBrandDefinitionSection(),
                  const SizedBox(height: 20),
                  if (_hypothesisEnabled('h02')) ...[
                    _buildIntentSelector(),
                    const SizedBox(height: 20),
                  ],
                  if (_hypothesisEnabled('h06')) ...[
                    _buildProductProofSection(),
                    const SizedBox(height: 20),
                  ],
                  if (_hypothesisEnabled('h07')) ...[
                    _buildSocialProofStatsSection(),
                    const SizedBox(height: 20),
                  ],
                  _buildConversionSequence(),
                  const SizedBox(height: 20),
                  if (!_hypothesisEnabled('h07')) ...[
                    _buildSocialProofStatsSection(),
                    const SizedBox(height: 20),
                  ],
                  _buildUniqueValueSection(),
                  const SizedBox(height: 20),
                  _buildGetStartedStepsSection(),
                  const SizedBox(height: 20),
                  _buildPricingComparisonSection(),
                  const SizedBox(height: 20),
                  _buildRecentAchievementsSection(),
                  const SizedBox(height: 20),
                  _buildMigrationGuideSection(),
                  const SizedBox(height: 20),
                  _buildNotionVsSection(),
                  const SizedBox(height: 20),
                  _buildFaqSection(),
                  const SizedBox(height: 20),
                  _buildImportCtaSection(),
                  const SizedBox(height: 20),
                  _buildComparisonLinksSection(),
                  _buildEnterpriseCta(),
                  const SizedBox(height: 20),
                  LiveGrowthBanner(
                    growthService: widget.growthService,
                    compact: true,
                    title: '今まさに成長中',
                    subtitle: '登録者数・開発状況をリアルタイムで確認',
                  ),
                  const SizedBox(height: 12),
                  _buildViralShareSection(),
                  const SizedBox(height: 20),
                  _buildLegalFooterLinks(),
                  const SizedBox(height: 20),
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

class _TrustPoint extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustPoint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF247B64)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ConversionProofStep extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String detail;

  const _ConversionProofStep({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFDBEAFE),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF1F7AE0), size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Color(0xFF7DD3FC),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: const TextStyle(
                  color: Color(0xFFB9D5EA),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProofArrow extends StatelessWidget {
  final bool vertical;

  const _ProofArrow({this.vertical = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: vertical
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Icon(
        vertical ? Icons.arrow_downward : Icons.arrow_forward,
        color: const Color(0xFF7DD3FC),
        size: 20,
      ),
    );
  }
}

class _WorkflowLandingHero extends StatelessWidget {
  final int achievementCount;
  final bool showFirstUserGrowthCta;
  final bool outcomeFirstMessage;
  final bool showRiskReversal;
  final Widget? inlineTrial;
  final VoidCallback onGetStarted;
  final VoidCallback onWatchDemo;

  const _WorkflowLandingHero({
    required this.achievementCount,
    this.showFirstUserGrowthCta = false,
    required this.outcomeFirstMessage,
    required this.showRiskReversal,
    this.inlineTrial,
    required this.onGetStarted,
    required this.onWatchDemo,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compactTrialHero = screenWidth < 480 && inlineTrial != null;

    return Container(
      key: const Key('landing_hero_section'),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FB),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: compactTrialHero
          ? const EdgeInsets.fromLTRB(10, 12, 10, 16)
          : const EdgeInsets.fromLTRB(22, 46, 22, 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compactTrialHero) ...[
            Center(
              child: Semantics(
                key: const Key('landing_brand_heading'),
                header: true,
                child: const Text(
                  '自分株式会社',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Text(
                outcomeFirstMessage
                    ? '仕事・学習・お金の「次の1件」を、AIが1分で決める'
                    : 'Notion・Slack・MoneyForward・WBSを、ひとつの仕事OSへ',
                key: Key(
                  outcomeFirstMessage
                      ? 'landing_h01_outcome_offer'
                      : 'landing_h01_control_offer',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF102A43),
                  fontSize: compactTrialHero ? 22 : 28,
                  height: compactTrialHero ? 1.25 : 1.45,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SizedBox(height: compactTrialHero ? 8 : 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Text(
                outcomeFirstMessage
                    ? '散らばった予定・メモ・資産・学習をまとめ、迷いを「今やる具体的な行動」に変えます。'
                    : '情報を一か所にまとめ、AIが今日の最優先アクションまで案内します。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontSize: compactTrialHero ? 13 : 16,
                  height: compactTrialHero ? 1.45 : 1.7,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (inlineTrial != null) ...[
            SizedBox(height: compactTrialHero ? 10 : 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: inlineTrial,
              ),
            ),
          ],
          if (achievementCount > 0) ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                '実装済み機能 $achievementCount件を、ひとつの作業空間から利用できます',
                style: const TextStyle(
                  color: Color(0xFF247B64),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (showFirstUserGrowthCta && inlineTrial == null) ...[
            _FirstUserGrowthHeroCta(
              onGetStarted: onGetStarted,
              onWatchDemo: onWatchDemo,
            ),
            const SizedBox(height: 18),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('landing_primary_signup_cta'),
                onPressed: onGetStarted,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('無料で保存を始める'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1F7AE0),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(190, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (inlineTrial == null)
                OutlinedButton.icon(
                  key: const Key('landing_primary_trial_cta'),
                  onPressed: onWatchDemo,
                  icon: const Icon(Icons.play_circle_outline, size: 19),
                  label: const Text('登録なしで1件試す'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF172033),
                    minimumSize: const Size(190, 52),
                    side: const BorderSide(color: Color(0xFF9CB7CC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (showRiskReversal) ...[
            const SizedBox(height: 16),
            const Wrap(
              key: Key('landing_h05_risk_reversal'),
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 8,
              children: [
                _TrustPoint(icon: Icons.check_circle_outline, label: '無料コア'),
                _TrustPoint(
                  icon: Icons.credit_card_off_outlined,
                  label: 'カード不要',
                ),
                _TrustPoint(icon: Icons.pause_circle_outline, label: 'いつでも停止'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FirstUserGrowthHeroCta extends StatelessWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onWatchDemo;

  const _FirstUserGrowthHeroCta({
    required this.onGetStarted,
    required this.onWatchDemo,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF93C5FD)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1F7AE0).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: compact ? WrapAlignment.start : WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    key: const Key('first_user_growth_signup_button'),
                    onPressed: onGetStarted,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('30秒で保存'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1F7AE0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('first_user_growth_trial_button'),
                    onPressed: onWatchDemo,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: const Text('5分だけ試す'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F7AE0),
                      side: const BorderSide(color: Color(0xFF93C5FD)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              );

              const copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xから来た方へ',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'まず5分で「今日やる1件」を出して、役に立った点と迷った点だけ教えてください。',
                    style: TextStyle(
                      color: Color(0xFF172033),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1.55,
                    ),
                  ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [copy, const SizedBox(height: 12), actions],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: copy),
                  const SizedBox(width: 16),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// Retained for compatibility with screenshots and future authenticated demos.
// ignore: unused_element
class _HeroFeatureGrid extends StatelessWidget {
  final List<Widget> children;

  const _HeroFeatureGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 14),
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children) ...[
                Expanded(child: child),
                if (child != children.last) const SizedBox(width: 0),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _WorkflowFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget visual;
  final VoidCallback onTap;

  const _WorkflowFeatureCard({
    required this.title,
    required this.subtitle,
    required this.visual,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFDCE7F2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 30, 30, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF245078),
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF4B5A6A),
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 172,
                child: Align(alignment: Alignment.bottomCenter, child: visual),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _AutomationPreview extends StatelessWidget {
  const _AutomationPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 142),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RuleLine(prefix: 'When', text: 'WBS task is blocked'),
          const Divider(height: 18, color: Color(0xFFEAEFF6)),
          const _RuleLine(prefix: 'Then', text: 'Split into next actions'),
          const Spacer(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Automation Rule Active',
                  style: TextStyle(
                    color: Color(0xFF7B8794),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F7AE0),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String prefix;
  final String text;

  const _RuleLine({required this.prefix, required this.text});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 13,
          height: 1.5,
        ),
        children: [
          TextSpan(
            text: '$prefix  ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _TimerPreview extends StatelessWidget {
  const _TimerPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: List.generate(
              3,
              (_) => Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(left: 4),
                decoration: const BoxDecoration(
                  color: Color(0xFFB8C2CF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const Text(
            '02:17:45',
            style: TextStyle(
              color: Color(0xFF172033),
              fontSize: 32,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: const Color(0xFF2E9D37),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    disabledForegroundColor: const Color(0xFF344054),
                    side: const BorderSide(color: Color(0xFFE6ECF3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text('Add Entry'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ReportPreview extends StatelessWidget {
  const _ReportPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE3EAF4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A5F).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Productivity Overview',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.more_horiz, size: 18, color: Color(0xFF9AA7B5)),
            ],
          ),
          SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox.expand(
                    child: CustomPaint(painter: _MiniBarChartPainter()),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: CustomPaint(
                    painter: _MiniDonutPainter(),
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _LegendDot(color: Color(0xFF2F9DED), label: 'Projects'),
              _LegendDot(color: Color(0xFFFFB547), label: 'Hours'),
              _LegendDot(color: Color(0xFF43C77D), label: 'Progress'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF657386),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _WhatsNewPanel extends StatelessWidget {
  final int achievementCount;
  final VoidCallback onOpenRoadmap;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenReports;

  const _WhatsNewPanel({
    required this.achievementCount,
    required this.onOpenRoadmap,
    required this.onOpenTasks,
    required this.onOpenReports,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      color: Colors.white.withValues(alpha: 0.9),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFFD9E2EC))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    Text(
                      "What's New?",
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Discover the Latest Features',
                      style: TextStyle(
                        color: Color(0xFF536173),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: Color(0xFFD9E2EC))),
            ],
          ),
          const SizedBox(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                _WhatsNewItem(
                  icon: Icons.account_tree_outlined,
                  color: const Color(0xFF276EF1),
                  title: 'Smart Automations',
                  text: 'Custom workflow automations',
                  onTap: onOpenTasks,
                ),
                _WhatsNewItem(
                  icon: Icons.schedule_outlined,
                  color: const Color(0xFF1D74D8),
                  title: 'Time Tracking',
                  text: 'Built-in focus and habit timer',
                  onTap: onOpenRoadmap,
                ),
                _WhatsNewItem(
                  icon: Icons.pie_chart_outline,
                  color: const Color(0xFF25A46A),
                  title: 'Detailed Reports',
                  text: achievementCount > 0
                      ? '$achievementCount shipped features tracked'
                      : 'Enhanced analytics and reports',
                  onTap: onOpenReports,
                ),
              ];
              if (constraints.maxWidth < 760) {
                return Column(
                  children: [
                    for (final item in items) ...[
                      item,
                      if (item != items.last) const SizedBox(height: 14),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (final item in items) ...[
                    Expanded(child: item),
                    if (item != items.last) const SizedBox(width: 18),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WhatsNewItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final VoidCallback onTap;

  const _WhatsNewItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF245078),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Color(0xFF4B5A6A),
                      fontSize: 13,
                      height: 1.45,
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

// ignore: unused_element
class _HeroWavePainter extends CustomPainter {
  const _HeroWavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEAF4FF)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height * 0.45)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.34,
        size.width * 0.37,
        size.height * 0.55,
        size.width * 0.58,
        size.height * 0.44,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.34,
        size.width * 0.84,
        size.height * 0.30,
        size.width,
        size.height * 0.19,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final upperPaint = Paint()
      ..color = const Color(0xFFF3F8FE).withValues(alpha: 0.86)
      ..style = PaintingStyle.fill;
    final upper = Path()
      ..moveTo(0, size.height * 0.34)
      ..cubicTo(
        size.width * 0.16,
        size.height * 0.28,
        size.width * 0.28,
        size.height * 0.42,
        size.width * 0.46,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.62,
        size.height * 0.29,
        size.width * 0.77,
        size.height * 0.37,
        size.width,
        size.height * 0.22,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(upper, upperPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniBarChartPainter extends CustomPainter {
  const _MiniBarChartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEAF0F6)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (i + 1) / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const values = [0.52, 0.74, 0.45, 0.64, 0.38, 0.82, 0.56, 0.72];
    const colors = [Color(0xFF2F9DED), Color(0xFFFFB547), Color(0xFF43C77D)];
    final groupWidth = size.width / values.length;
    for (var i = 0; i < values.length; i++) {
      final barHeight = size.height * values[i];
      final x = i * groupWidth + groupWidth * 0.22;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, groupWidth * 0.42, barHeight),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, Paint()..color = colors[i % colors.length]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniDonutPainter extends CustomPainter {
  const _MiniDonutPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: side * 0.78,
      height: side * 0.78,
    );
    const segments = [
      (Color(0xFF2F9DED), 0.34),
      (Color(0xFF43C77D), 0.38),
      (Color(0xFFFF7676), 0.28),
    ];
    var start = -1.5708;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.18
      ..strokeCap = StrokeCap.butt;
    for (final segment in segments) {
      paint.color = segment.$1;
      final sweep = 6.28318 * segment.$2;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BenefitChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BenefitChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF3D3A6E) : const Color(0xFFC7D2FE),
        ),
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
              height: 1.5,
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
                      height: 1.5,
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

class _GettingStartedStrip extends StatelessWidget {
  const _GettingStartedStrip();

  @override
  Widget build(BuildContext context) {
    const steps = <(String, String)>[
      ('1', '無料で始める（30秒）'),
      ('2', '今日の最優先1件をAIが提案'),
      ('3', 'AI大学・英語速読で学ぶ習慣に'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in steps)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    s.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.$2,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlannerGapStrip extends StatelessWidget {
  const _PlannerGapStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          _PlannerGapChip(
            icon: Icons.mail_outline,
            label: 'Google Planner Gem',
            value: 'Gmail・予定・Drive中心',
            color: Color(0xFF4285F4),
          ),
          _PlannerGapChip(
            icon: Icons.account_balance_wallet_outlined,
            label: '財務',
            value: '支出・資産・浪費を監視',
            color: Color(0xFF16A34A),
          ),
          _PlannerGapChip(
            icon: Icons.favorite_border,
            label: '健康・習慣',
            value: '体調・継続・集中を保護',
            color: Color(0xFFDC2626),
          ),
          _PlannerGapChip(
            icon: Icons.corporate_fare_outlined,
            label: '6部署AI',
            value: 'CEO/CFO/CMO/CHO/CHRO/R&D',
            color: Color(0xFFFF6B35),
          ),
        ],
      ),
    );
  }
}

class _PlannerGapChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _PlannerGapChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 148, maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 11,
                    height: 1.45,
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
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          height: 1.5,
        ),
      ),
    );
  }
}
