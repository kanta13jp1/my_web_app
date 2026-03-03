import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/ai_service.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

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
  final GlobalKey _authSectionKey = GlobalKey();

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _magicLinkCooldownTimer;

  bool _isLoading = false;
  bool _isTrialLoading = false;
  bool _isSignUp = true;
  bool _isLoadingStats = true;
  bool _showSaveCtaPrompt = false;
  bool _showInboxShortcut = false;
  int _magicLinkCooldownSeconds = 0;

  int _todayViews = 0;
  int _monthViews = 0;
  int _totalViews = 0;
  List<FlSpot> _pvSpots = const <FlSpot>[];
  List<String> _pvLabels = const <String>[];

  String? _trialAction;
  String? _trialReason;
  String? _lastMagicLinkEmail;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          _goToAuthenticatedEntry();
        }
      },
    );
    _initLpViewStats();
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _initLpViewStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('increment_lp_view');
      final dynamic raw = await supabase.rpc('get_lp_view_stats');
      final data =
          raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

      final today = (data['today'] as num?)?.toInt() ?? 0;
      final month = (data['month'] as num?)?.toInt() ?? 0;
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final series =
          data['series'] is List ? data['series'] as List : const <dynamic>[];

      final spots = <FlSpot>[];
      final labels = <String>[];
      for (var i = 0; i < series.length; i++) {
        final rowRaw = series[i];
        if (rowRaw is! Map) continue;
        final row = Map<String, dynamic>.from(rowRaw);
        final dateStr = row['date']?.toString() ?? '';
        final count = (row['count'] as num?)?.toDouble() ?? 0;
        spots.add(FlSpot(i.toDouble(), count));
        final date = DateTime.tryParse(dateStr);
        labels.add(date == null ? '' : DateFormat('M/d').format(date));
      }

      if (!mounted) return;
      setState(() {
        _todayViews = today;
        _monthViews = month;
        _totalViews = total;
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
        final result = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _webRedirectUrl,
        );
        if (!mounted) return;
        if (result.session == null) {
          _showMessage('確認メールを送信しました。メール内のリンクから登録を完了してください。');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
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
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _webRedirectUrl,
      );
      if (!launched) {
        _showMessage('Googleログイン画面を開けませんでした。再読み込みしてから再実行してください。');
      }
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
      await Supabase.instance.client.auth.signInWithOtp(
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
    final input = _trialPromptController.text.trim();
    if (input.isEmpty) {
      final fallback = _buildTrialFallbackSuggestion(input);
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = fallback.$2;
        _showSaveCtaPrompt = false;
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

      final result = await AIService().improveText(prompt);
      final parsed = _parseTrialAiResponse(result);
      if (!mounted) return;
      setState(() {
        _trialAction = parsed.$1;
        _trialReason = parsed.$2;
        _showSaveCtaPrompt = false;
      });
    } catch (e) {
      debugPrint('Trial preview failed: $e');
      final fallback = _buildTrialFallbackSuggestion(input);
      if (!mounted) return;
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = '${fallback.$2} AI応答が不安定だったため簡易提案を表示しています。';
        _showSaveCtaPrompt = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isTrialLoading = false);
      }
    }
  }

  void _promptRegistrationForTrialSave() {
    setState(() {
      _showSaveCtaPrompt = true;
      _isSignUp = true;
    });
    _showMessage(
      'この結果を保存するには登録が必要です。下の登録セクションから30秒で保存を開始できます。',
    );
    _scrollToAuthSection();
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
      if (!launched) {
        _showMessage('受信箱を開けませんでした。ブラウザかメールアプリで受信箱を確認してください。');
      }
    } catch (e) {
      debugPrint('Open inbox failed: $e');
      _showMessage('受信箱を開けませんでした。ブラウザかメールアプリで受信箱を確認してください。');
    }
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(
          Icons.business_center,
          size: 68,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        const Text(
          'AI提案を保存して、明日も続きから再開。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '最初の1件は登録前に試せます。価値を感じたら、30秒で保存を始めてください。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.black54),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: const Column(
            children: [
              Text(
                '登録すると残るもの',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey,
                ),
              ),
              SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BenefitChip(icon: Icons.save, label: 'AI提案を保存'),
                  _BenefitChip(icon: Icons.replay, label: '続きから再開'),
                  _BenefitChip(icon: Icons.history, label: '履歴を残す'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _scrollToAuthSection,
            child: const Text(
              '30秒で保存を始める',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPvSection() {
    final fmt = NumberFormat('#,###');
    final labelInterval =
        _pvLabels.length <= 6 ? 1 : (_pvLabels.length / 6).ceil();

    return Card(
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
    return Card(
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
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _promptRegistrationForTrialSave,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('この結果を保存する'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthSection() {
    return Card(
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
                          ? (_isMagicLinkCoolingDown ? '送信済み' : 'Magic Linkを再送')
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
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自分株式会社へようこそ'),
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
                  const SizedBox(height: 24),
                  _buildTrialSection(),
                  const SizedBox(height: 20),
                  _buildAuthSection(),
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
