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
  List<FlSpot> _pvSpots = [];
  List<String> _pvLabels = [];

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _initLpViewStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('increment_lp_view');
      final res = await supabase.rpc('get_lp_view_stats');
      final map = Map<String, dynamic>.from(res as Map);

      final today = (map['today'] as num?)?.toInt() ?? 0;
      final month = (map['month'] as num?)?.toInt() ?? 0;
      final total = (map['total'] as num?)?.toInt() ?? 0;
      final series = (map['series'] as List?) ?? const [];

      final spots = <FlSpot>[];
      final labels = <String>[];

      for (var i = 0; i < series.length; i++) {
        final row = Map<String, dynamic>.from(series[i] as Map);
        final dateStr = (row['date'] ?? '').toString();
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
        final res = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          emailRedirectTo: _webRedirectUrl,
        );
        if (!mounted) return;
        if (res.session == null) {
          _showMessage('確認メールを送信しました。受信箱の確認リンクから続行してください。');
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(_resolveEmailAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final launched = await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _webRedirectUrl,
      );
      if (!launched && mounted) {
        _showMessage('Googleログインを開始できませんでした。もう一度押してください。');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(_resolveGoogleAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      if (!mounted) return;
      _showMessage('Magic Link を送信しました。受信箱のメール内リンクから続行してください。');
    } catch (e) {
      if (!mounted) return;
      _showMessage(_resolveMagicLinkError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _runTrialActionPreview() async {
    final text = _trialPromptController.text.trim();
    if (text.isEmpty) {
      final suggestion = _buildTrialFallbackSuggestion(text);
      setState(() {
        _trialAction = suggestion.$1;
        _trialReason = suggestion.$2;
        _showSaveCtaPrompt = false;
      });
      return;
    }

    setState(() => _isTrialLoading = true);
    try {
      final aiService = AIService();
      final prompt = '''
以下のユーザー入力から、今すぐ着手すべき1件を日本語で提案してください。
出力は必ず次の2行のみで返してください。
ACTION: 20文字以内の具体的な次アクション
REASON: 60文字以内の理由

ユーザー入力:
$text
''';
      final raw = await aiService.improveText(prompt);
      final suggestion = _parseTrialAiResponse(raw);
      if (!mounted) return;
      setState(() {
        _trialAction = suggestion.$1;
        _trialReason = suggestion.$2;
        _showSaveCtaPrompt = false;
      });
    } catch (_) {
      final suggestion = _buildTrialFallbackSuggestion(text);
      if (!mounted) return;
      setState(() {
        _trialAction = suggestion.$1;
        _trialReason = '${suggestion.$2}（AI応答失敗のため簡易判定）';
        _showSaveCtaPrompt = false;
      });
    } finally {
      if (mounted) setState(() => _isTrialLoading = false);
    }
  }

  void _promptRegistrationForTrialSave() {
    setState(() {
      _showSaveCtaPrompt = true;
      _isSignUp = true;
    });
    _showMessage('この結果を保存するには登録が必要です。下の認証エリアから続行してください。');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authContext = _authSectionKey.currentContext;
      if (authContext == null || !mounted) return;
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
        .split('\n')
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
        (reason != null && reason.isNotEmpty) ? reason : 'AIが最短の着手ポイントとして選びました。'
      );
    }

    final compact = raw.replaceAll('\n', ' ').trim();
    if (compact.isNotEmpty) {
      final safeText =
          compact.length > 80 ? '${compact.substring(0, 80)}…' : compact;
      return (safeText, 'AI応答をそのまま次アクション候補として表示しています。');
    }

    return _buildTrialFallbackSuggestion(_trialPromptController.text);
  }

  (String, String) _buildTrialFallbackSuggestion(String input) {
    final text = input.trim();
    if (text.isEmpty) {
      return ('まずは今日やる最優先を1件だけ決める。', '入力が空でも、最初の1件を固定すると行動開始が早くなります。');
    }

    if (text.contains('メール') ||
        text.contains('SMS') ||
        text.contains('DM') ||
        text.contains('連絡') ||
        text.contains('返信')) {
      return ('未読の連絡を3件だけ処理する。', '連絡系は先に未読を減らすと、その後の判断負荷が落ちます。');
    }

    if (text.contains('お金') ||
        text.contains('支払') ||
        text.contains('残高') ||
        text.contains('請求') ||
        text.contains('口座')) {
      return ('残高か請求を1件だけ確認して記録する。', '金額確認を先に終えると、後ろの意思決定が数字ベースに戻ります。');
    }

    if (text.contains('仕事') ||
        text.contains('タスク') ||
        text.contains('締切') ||
        text.contains('TODO') ||
        text.contains('作業')) {
      return ('10分以内に着手できるタスクを1件だけ始める。', '最優先の1件を小さく切ると、先延ばしより着手が勝ちます。');
    }

    if (text.contains('片付') || text.contains('掃除') || text.contains('整理')) {
      return ('視界に入る場所を1区画だけ片付ける。', '環境を1区画だけ整えると、次の作業への抵抗が下がります。');
    }

    return ('今から10分で終わる単位に分解して、1件だけ着手する。', '内容が広いときは、10分単位まで小さくするのが最短です。');
  }

  String _resolveEmailAuthError(Object error) {
    if (error is AuthWeakPasswordException) {
      return 'パスワードが弱すぎます。英字と数字を混ぜて8文字以上にしてください。';
    }
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();

      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          message.contains('invalid login credentials')) {
        return 'メールアドレスかパスワードが一致していません。入力を見直してから再試行してください。';
      }
      if (code == 'email_exists' || code == 'user_already_exists') {
        return 'このメールアドレスは既に登録済みです。新規登録ではなくログインに切り替えてください。';
      }
      if (code == 'email_not_confirmed') {
        return 'メール確認が未完了です。受信箱の確認メールを開き、認証リンクを押してからログインしてください。';
      }
      if (code == 'signup_disabled') {
        return '現在メール新規登録は停止中です。Googleログインか Magic Link を使ってください。';
      }
      if (code == 'weak_password') {
        return 'パスワードが弱すぎます。英字と数字を混ぜて8文字以上にしてください。';
      }
      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'メールアドレスの形式が不正です。`@` を含む正しい形式で入力してください。';
      }
      if (code == 'over_request_rate_limit' ||
          code == 'over_email_send_rate_limit' ||
          error.statusCode == '429' ||
          message.contains('rate limit')) {
        return '試行回数が多すぎます。1分ほど待ってから再試行してください。';
      }
      if (code == 'unexpected_failure' || error.statusCode == '500') {
        return '認証サーバー側で失敗しました。時間を置いて再試行するか、Googleログインを使ってください。';
      }
      return '認証に失敗しました。入力内容を確認して、もう一度試してください。';
    }
    return '認証に失敗しました。通信状態を確認してから再試行してください。';
  }

  String _resolveGoogleAuthError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();

      if (code == 'provider_disabled' ||
          message.contains('provider is not enabled')) {
        return 'Googleログインが未設定です。Supabase Auth の Google provider を有効化してください。';
      }
      if (code == 'bad_oauth_callback' ||
          code == 'bad_oauth_state' ||
          code == 'flow_state_expired' ||
          code == 'flow_state_not_found' ||
          code == 'validation_failed' ||
          message.contains('redirect')) {
        return 'Googleログインのリダイレクト設定が不正です。Supabase の Site URL と Redirect URLs を確認してください。';
      }
      if (code == 'access_denied' || message.contains('cancel')) {
        return 'Googleログインが途中で中断されました。アカウント選択とアクセス許可を最後まで完了してください。';
      }
      if (code == 'over_request_rate_limit' ||
          error.statusCode == '429' ||
          message.contains('rate limit')) {
        return 'Googleログインの試行回数が多すぎます。少し待ってから再試行してください。';
      }
      if (code == 'unexpected_failure' || error.statusCode == '500') {
        return 'Googleログイン側で一時的に失敗しました。時間を置くか、Magic Link に切り替えてください。';
      }
      return 'Googleログインに失敗しました。設定または通信状態を確認してください。';
    }

    final message = error.toString().toLowerCase();
    if (message.contains('popup') || message.contains('blocked')) {
      return 'Googleログインがブラウザにブロックされました。ポップアップ制限を解除してから再試行してください。';
    }
    return 'Googleログインに失敗しました。通信状態を確認してから再試行してください。';
  }

  String _resolveMagicLinkError(Object error) {
    if (error is AuthException) {
      final code = (error.code ?? '').toLowerCase();
      final message = error.message.toLowerCase();

      if (code == 'email_address_invalid' ||
          message.contains('invalid email')) {
        return 'Magic Link を送れません。メールアドレスの形式を修正してから再送してください。';
      }
      if (code == 'signup_disabled') {
        return '現在メール登録が停止中です。Googleログインを使ってください。';
      }
      if (code == 'email_provider_disabled') {
        return 'Magic Link が未設定です。Supabase Auth の Email provider を有効化してください。';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          error.statusCode == '429' ||
          message.contains('rate limit')) {
        return 'Magic Link の送信回数が多すぎます。1分ほど待ってから再送してください。';
      }
      if (code == 'validation_failed' ||
          code == 'flow_state_expired' ||
          code == 'flow_state_not_found' ||
          message.contains('redirect')) {
        return 'Magic Link の遷移設定が不正です。Supabase の Site URL と Redirect URLs を確認してください。';
      }
      if (message.contains('smtp') || code == 'unexpected_failure') {
        return 'メール送信側で失敗しました。時間を置くか、Googleログインに切り替えてください。';
      }
      return 'Magic Link を送れませんでした。メールアドレスと送信設定を確認してください。';
    }

    return 'Magic Link を送れませんでした。通信状態を確認してから再試行してください。';
  }

  Widget _buildPvSection() {
    final fmt = NumberFormat('#,###', 'ja_JP');
    final interval = (_pvLabels.length / 5).ceil().clamp(1, 999).toDouble();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'LP View数',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'まずは流入を増やす。登録改善の前に、見られているかを確認します。',
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
                                  interval: interval,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    final label =
                                        (index >= 0 && index < _pvLabels.length)
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
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '今いちばん詰まっていることを入れると、今やる1件を返します。',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _trialPromptController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '例: 仕事と連絡が散らかっていて何から手を付けるか迷う',
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
                      '今やる1件',
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
                  'この結果を保存するには登録が必要です。Google、Magic Link、メール登録のいずれかで続行してください。',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text(
              '30秒で始める',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isSignUp ? '新規登録。最初の設定はあとからでも進められます。' : 'ログイン。前回の続きから再開します。',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Googleで続ける'),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'または',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 12),
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
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _sendMagicLink,
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('Magic Linkを送る'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'パスワードを作らず、そのままメール内リンクで続行できます。',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
            const SizedBox(height: 14),
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
                    '今日のやるべきことを、AIと運用導線で1件に絞る。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '優先順位決め、実行、振り返りを1つにまとめた個人用オペレーティングシステムです。',
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
