import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final GlobalKey _authSectionKey = GlobalKey();

  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = false;
  bool _isTrialLoading = false;
  bool _isSignUp = false;
  bool _isLoadingStats = true;
  bool _showSaveCtaPrompt = false;

  int _todayViews = 0;
  int _monthViews = 0;
  int _totalViews = 0;
  List<FlSpot> _pvSpots = const <FlSpot>[];
  List<String> _pvLabels = const <String>[];

  String? _trialAction;
  String? _trialReason;

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
    _emailController.dispose();
    _passwordController.dispose();
    _trialPromptController.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    } catch (_) {
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
          _showMessage('確認メールを送りました。メール内のリンクを開いて登録を完了してください。');
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
        'Googleログインは未設定のため現在は非表示です。Google provider を有効化し、'
        '--dart-define=LANDING_GOOGLE_LOGIN_ENABLED=true で再表示してください。',
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
        _showMessage('Googleログインを開始できませんでした。少し待ってから再試行してください。');
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
      _showMessage('Magic Link を送りました。メール内のリンクを開くとそのまま開始できます。');
    } catch (error) {
      _showMessage(_resolveMagicLinkError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
あなたはランディングページ上の体験導線AIです。
ユーザーの入力から、今すぐ着手すべき1件を日本語で提案してください。
出力は次の2行のみです。
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
    } catch (_) {
      final fallback = _buildTrialFallbackSuggestion(input);
      if (!mounted) return;
      setState(() {
        _trialAction = fallback.$1;
        _trialReason = '${fallback.$2} AI応答に失敗したため簡易判定を表示しています。';
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
    _showMessage('この結果を保存するには登録が必要です。下の認証セクションから開始してください。');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authContext = _authSectionKey.currentContext;
      if (!mounted || authContext == null) return;
      Scrollable.ensureVisible(
        authContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    });
  }

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
        (reason != null && reason.isNotEmpty) ? reason : 'AIが選んだ最短の着手順です。'
      );
    }

    final compact = raw.replaceAll('\n', ' ').trim();
    if (compact.isNotEmpty) {
      final safe =
          compact.length > 80 ? '${compact.substring(0, 80)}...' : compact;
      return (safe, 'AI応答をそのまま簡易表示しています。');
    }

    return _buildTrialFallbackSuggestion(_trialPromptController.text.trim());
  }

  (String, String) _buildTrialFallbackSuggestion(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return (
        '今日の最重要1件を書く',
        '入力が空でも、最優先を1件に絞るだけで着手しやすくなります。',
      );
    }

    if (text.contains('メール') ||
        text.contains('SMS') ||
        text.contains('DM') ||
        text.contains('連絡')) {
      return (
        '未読の連絡を1件だけ処理する',
        '連絡系は放置すると判断コストが増えるので、最初に1件片付けます。',
      );
    }

    if (text.contains('お金') ||
        text.contains('請求') ||
        text.contains('残高') ||
        text.contains('支払い')) {
      return (
        '残高か請求を1件だけ確認する',
        '数字を先に確認すると、不安が曖昧なまま膨らみにくくなります。',
      );
    }

    if (text.contains('タスク') ||
        text.contains('TODO') ||
        text.contains('整理') ||
        text.contains('優先')) {
      return (
        '10分だけ使って最優先を1件に絞る',
        '着手前に優先順位を1件まで圧縮すると、その後の判断が速くなります。',
      );
    }

    return (
      '20分以内で終わる最小作業に分解する',
      '大きすぎるタスクは始めにくいので、最小単位まで切ってから着手します。',
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
        return 'メールアドレスかパスワードが一致していません。入力を見直すか、Magic Link に切り替えてください。';
      }
      if (code == 'email_exists' || code == 'user_already_exists') {
        return 'このメールアドレスはすでに登録済みです。ログインに切り替えるか、Magic Link を使ってください。';
      }
      if (code == 'email_not_confirmed') {
        return '確認メールの認証がまだです。メール内リンクを開くか、Magic Link で入り直してください。';
      }
      if (code == 'signup_disabled') {
        return 'メール新規登録は現在停止中です。Magic Link を使うか、認証設定を確認してください。';
      }
      if (code == 'weak_password') {
        return 'パスワードが弱すぎます。英字と数字を含めて、8文字以上にしてください。';
      }
      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'メールアドレスの形式が正しくありません。`@` を含む形式で入力してください。';
      }
      if (code == 'validation_failed') {
        return '入力内容の検証に失敗しました。メール形式とパスワードの長さを確認して再試行してください。';
      }
      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return '試行回数が多すぎます。1〜2分待ってから再試行するか、Magic Link に切り替えてください。';
      }
      if (code == 'unexpected_failure' || status == '500') {
        return '認証サーバー側で一時エラーが出ています。少し待ってから再試行してください。';
      }
      return '認証に失敗しました。入力内容を確認し、それでもだめなら Magic Link を使ってください。';
    }
    return '認証に失敗しました。通信状態を確認してから再試行してください。';
  }

  String _resolveGoogleAuthError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final status = error.statusCode?.toString() ?? '';

      if (code == 'provider_disabled' ||
          message.contains('provider is not enabled')) {
        return 'Google provider が Supabase で無効です。Authentication > Sign In / Providers で Google を有効化してください。';
      }
      if (code == 'bad_oauth_callback' ||
          code == 'bad_oauth_state' ||
          code == 'flow_state_expired' ||
          code == 'flow_state_not_found' ||
          code == 'validation_failed' ||
          message.contains('redirect')) {
        return 'Google OAuth のリダイレクト設定が不正です。Supabase の Site URL / Redirect URLs と Google 側の callback URL を確認してください。';
      }
      if (code == 'access_denied' || message.contains('cancel')) {
        return 'Google ログインが中断されました。アカウント選択をやり直すか、Magic Link を使ってください。';
      }
      if (code == 'over_request_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return 'Google ログインの試行回数が多すぎます。少し待ってから再試行してください。';
      }
      return 'Google ログインに失敗しました。設定を確認するか、Magic Link を主導線として使ってください。';
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('popup') || raw.contains('blocked')) {
      return 'Google ログインの画面がブラウザにブロックされました。ポップアップを許可するか、Magic Link を使ってください。';
    }
    return 'Google ログインに失敗しました。設定確認後に再試行してください。';
  }

  String _resolveMagicLinkError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();
      final status = error.statusCode?.toString() ?? '';

      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'メールアドレスの形式が正しくありません。入力を見直してから再送してください。';
      }
      if (code == 'signup_disabled') {
        return '新規ユーザーの自動作成が停止中です。Supabase の Email Auth 設定を確認してください。';
      }
      if (code == 'email_provider_disabled') {
        return 'メール認証自体が無効です。Supabase の Email provider を有効化してください。';
      }
      if (code == 'validation_failed' ||
          code == 'flow_state_expired' ||
          code == 'flow_state_not_found' ||
          message.contains('redirect')) {
        return 'Magic Link の遷移先設定が不正です。Supabase の Site URL / Redirect URLs を確認してください。';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          status == '429' ||
          message.contains('rate limit')) {
        return 'メール送信回数が多すぎます。1〜2分待ってから再送してください。';
      }
      if (code == 'unexpected_failure' || message.contains('smtp')) {
        return 'メール送信設定に失敗しています。Supabase の SMTP / Email 設定を確認してください。';
      }
      return 'Magic Link の送信に失敗しました。メールアドレスと認証設定を確認してください。';
    }
    return 'Magic Link の送信に失敗しました。通信状態を確認してから再試行してください。';
  }

  Widget _buildPvSection() {
    final fmt = NumberFormat('#,###', 'ja_JP');
    final labelInterval =
        _pvLabels.length <= 5 ? 1 : (_pvLabels.length / 5).ceil();

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
              'グラフは今月の日次LP Viewです。',
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
              'まず1回だけ使って価値を確認できます。保存したくなった時だけ登録してください。',
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
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Text(
                  'この結果を保存するには登録が必要です。まずは Magic Link で始めるのが最短です。',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              '30秒で開始',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp
                  ? '新規登録モードです。まずは Magic Link で入り、必要なら後でパスワード設定に切り替えます。'
                  : '最短導線は Magic Link です。既存ユーザーは下のパスワードログインも使えます。',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _sendMagicLink,
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('Magic Link で続ける'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '最短導線です。パスワード不要で、そのまま新規登録にもログインにも使えます。',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
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
                  'Googleログインは未設定のため現在は非表示です。Supabase で Google provider を有効化し、'
                  '--dart-define=LANDING_GOOGLE_LOGIN_ENABLED=true で再表示できます。',
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
                  const Icon(
                    Icons.business_center,
                    size: 68,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '今日のやるべきことを、AIと運営導線で1件に絞る。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'まず1回試して価値を確認し、保存したくなった時だけ登録する構成です。'
                    '新規登録の主導線は Magic Link に寄せています。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  _buildPvSection(),
                  const SizedBox(height: 20),
                  _buildTrialSection(),
                  const SizedBox(height: 20),
                  _buildAuthSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
