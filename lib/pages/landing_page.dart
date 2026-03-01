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

  StreamSubscription<AuthState>? _authSubscription;

  bool _isLoading = false;
  bool _isTrialLoading = false;
  bool _isSignUp = false;
  bool _isLoadingStats = true;

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
          _showMessage('確認メールを送信しました。メール内リンクから続行してください。');
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
        _showMessage('Googleログインを開始できませんでした。');
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
      _showMessage('Magic Link を送信しました。メール内リンクから続行してください。');
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
      });
    } catch (_) {
      final suggestion = _buildTrialFallbackSuggestion(text);
      if (!mounted) return;
      setState(() {
        _trialAction = suggestion.$1;
        _trialReason = '${suggestion.$2}（AI応答失敗のため簡易判定）';
      });
    } finally {
      if (mounted) setState(() => _isTrialLoading = false);
    }
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
      return 'パスワードが弱すぎます。英字・数字を混ぜて、もう少し長くしてください。';
    }
    if (error is AuthException) {
      final lowerMessage = error.message.toLowerCase();
      final lowerCode = (error.code ?? '').toLowerCase();

      if (lowerCode.contains('invalid_credentials') ||
          lowerMessage.contains('invalid login credentials')) {
        return 'メールアドレスかパスワードが一致していません。';
      }
      if (lowerCode.contains('email_exists') ||
          lowerMessage.contains('already registered')) {
        return 'このメールアドレスは既に登録済みです。ログインに切り替えてください。';
      }
      if (lowerCode.contains('weak_password')) {
        return 'パスワードが弱すぎます。英字・数字を混ぜて、もう少し長くしてください。';
      }
      if (lowerCode.contains('email_address_invalid') ||
          lowerMessage.contains('invalid email')) {
        return 'メールアドレスの形式が不正です。';
      }
      if (lowerCode.contains('over_request_rate_limit') ||
          lowerCode.contains('over_email_send_rate_limit') ||
          lowerMessage.contains('rate limit') ||
          error.statusCode == '429') {
        return '試行回数が多すぎます。少し待ってから再試行してください。';
      }
      return '認証に失敗しました。入力内容を確認して、もう一度試してください。';
    }
    return '認証に失敗しました。通信状態を確認して、もう一度試してください。';
  }

  String _resolveGoogleAuthError(Object error) {
    if (error is AuthException) {
      final lowerMessage = error.message.toLowerCase();
      final lowerCode = (error.code ?? '').toLowerCase();

      if (lowerCode.contains('provider_disabled') ||
          lowerMessage.contains('provider is not enabled')) {
        return 'Googleログインが未設定です。Supabase Auth の Google provider を有効化してください。';
      }
      if (lowerMessage.contains('redirect') ||
          lowerCode.contains('bad_oauth_callback') ||
          lowerCode.contains('validation_failed')) {
        return 'Googleログインのリダイレクト設定が不正です。Supabase の Site URL / Redirect URLs を確認してください。';
      }
      if (lowerCode.contains('over_request_rate_limit') ||
          lowerMessage.contains('rate limit') ||
          error.statusCode == '429') {
        return 'Googleログインの試行回数が多すぎます。少し待ってから再試行してください。';
      }
      return 'Googleログインに失敗しました。設定または通信状態を確認してください。';
    }

    final message = error.toString().toLowerCase();
    if (message.contains('popup') || message.contains('blocked')) {
      return 'Googleログインがブラウザにブロックされました。ポップアップ制限を解除して再試行してください。';
    }

    return 'Googleログインに失敗しました。設定または通信状態を確認してください。';
  }

  String _resolveMagicLinkError(Object error) {
    if (error is AuthException) {
      final lowerMessage = error.message.toLowerCase();
      final lowerCode = (error.code ?? '').toLowerCase();

      if (lowerCode.contains('email_address_invalid') ||
          lowerMessage.contains('invalid email')) {
        return 'Magic Link を送れません。メールアドレスの形式を確認してください。';
      }
      if (lowerCode.contains('over_email_send_rate_limit') ||
          lowerCode.contains('over_request_rate_limit') ||
          lowerMessage.contains('rate limit') ||
          error.statusCode == '429') {
        return 'Magic Link の送信回数が多すぎます。少し待ってから再試行してください。';
      }
      if (lowerMessage.contains('smtp') ||
          lowerCode.contains('email_not_confirmed')) {
        return 'メール送信設定に問題があります。時間を置くか、別のログイン方法を使ってください。';
      }
      if (lowerMessage.contains('redirect') ||
          lowerCode.contains('validation_failed')) {
        return 'Magic Link のリダイレクト設定が不正です。Supabase の Site URL / Redirect URLs を確認してください。';
      }
      return 'Magic Link を送れませんでした。メールアドレスと送信設定を確認してください。';
    }

    return 'Magic Link を送れませんでした。通信状態を確認して、もう一度試してください。';
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
                    const SizedBox(height: 8),
                    const Text(
                      '続き保存、実行ログ、AI補助は登録後に使えます。',
                      style: TextStyle(fontSize: 12, color: Colors.black45),
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
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
