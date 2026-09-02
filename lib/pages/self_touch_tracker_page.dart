import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/abstinence_guard_store.dart';
import '../services/self_touch_consent_store.dart';

class SelfTouchTrackerPage extends StatefulWidget {
  final bool quickLogOnOpen;

  const SelfTouchTrackerPage({
    super.key,
    this.quickLogOnOpen = false,
  });

  @override
  State<SelfTouchTrackerPage> createState() => _SelfTouchTrackerPageState();
}

class _SelfTouchTrackerPageState extends State<SelfTouchTrackerPage>
    with SingleTickerProviderStateMixin {
  static const String _itemId = 'touch_hair';
  static const int _alertThreshold = 3;

  static const List<_AlternativeAction> _alternatives = [
    _AlternativeAction('🤲', '利き手でない手で頭をゆっくり撫でる', 'やさしい感覚へ意識を移す'),
    _AlternativeAction('🏐', 'ストレスボールを握る', '手の筋肉へ意識を向けて衝動を逃がす'),
    _AlternativeAction('💨', 'ゆっくり呼吸する', '無理のない長さで息を吐くことに意識を向ける'),
    _AlternativeAction('🧊', '冷たい水で手を洗う', '別の感覚へ意識を切り替える'),
    _AlternativeAction('🖊️', '今の気持ちをメモする', '気持ちを整理するきっかけにする'),
    _AlternativeAction('🚶', '5分だけ席を立つ', '環境を変えて刺激から距離を置く'),
  ];

  SelfTouchDisclosure _disclosure = SelfTouchDisclosure.fallback;
  bool _consentChecked = false;
  bool _consentGranted = false;
  bool _consentDialogOpen = false;
  int _todayCount = 0;
  List<AbstinenceSlipDailyCount> _weekTrend = [];
  bool _loading = true;
  bool _quickLogInProgress = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initialize();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final trend = await AbstinenceGuardStore.loadSlipCountsByDate(
        itemId: _itemId,
        days: 7,
      );
      final today =
          trend.where((t) => _isToday(t.date)).fold(0, (s, t) => s + t.count);
      if (mounted) {
        setState(() {
          _weekTrend = trend;
          _todayCount = today;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _initialize() async {
    final disclosure = await SelfTouchConsentStore.loadDisclosure();
    final granted = await SelfTouchConsentStore.hasCurrentConsent(
      version: disclosure.version,
    );
    if (!mounted) return;
    setState(() {
      _disclosure = disclosure;
      _consentChecked = true;
      _consentGranted = granted;
      if (!granted) {
        _loading = false;
      }
    });

    if (!granted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestConsent();
      });
      return;
    }

    await _load();
    if (widget.quickLogOnOpen) {
      await _runQuickLog();
    }
  }

  Future<void> _requestConsent() async {
    if (!mounted || _consentGranted || _consentDialogOpen) return;
    _consentDialogOpen = true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_disclosure.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_disclosure.body),
              const SizedBox(height: 12),
              Text(
                '説明文の版: ${_disclosure.version}',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('今は記録しない'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('内容を理解して記録を始める'),
          ),
        ],
      ),
    );
    _consentDialogOpen = false;
    if (accepted != true || !mounted) return;

    try {
      await SelfTouchConsentStore.grantConsent(
        version: _disclosure.version,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同意状態を保存できませんでした。通信状況を確認してください。')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _consentGranted = true);
    await _load();
    if (widget.quickLogOnOpen) {
      await _runQuickLog();
    }
  }

  Future<void> _openSupportResources() async {
    var opened = false;
    try {
      opened = await launchUrl(
        _disclosure.supportUrl,
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相談窓口を開けませんでした。ブラウザの設定を確認してください。')),
      );
    }
  }

  Future<void> _record({
    bool showSuccess = false,
    bool showFailure = false,
  }) async {
    if (!_consentGranted) {
      await _requestConsent();
      return;
    }
    try {
      await _pulseCtrl.forward(from: 0);
      await AbstinenceGuardStore.incrementSlip(
        itemId: _itemId,
        triggerNote: 'self_touch_quick_log',
      );
      await _load();
    } catch (_) {
      if (!mounted || !showFailure) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not record.'),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: _runQuickLog,
          ),
        ),
      );
      return;
    }

    if (!mounted) return;

    if (showSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recorded'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (_todayCount >= _alertThreshold) {
      _showAlternativeActions();
    }
  }

  Future<void> _runQuickLog() async {
    if (!mounted || _quickLogInProgress) {
      return;
    }
    setState(() {
      _quickLogInProgress = true;
    });
    await _record(showSuccess: true, showFailure: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _quickLogInProgress = false;
    });
  }

  void _showAlternativeActions() {
    final action = _alternatives[math.Random().nextInt(_alternatives.length)];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '代替アクションを試してみよう',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text(action.emoji, style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          action.reason,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(ctx)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '記録回数は診断結果ではありません。つらさが続くときや自分を傷つける心配があるときは、専門家や公的な相談窓口を利用してください。',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openSupportResources();
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('相談先を確認'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK、やってみる'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_consentChecked || _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('髪・自己接触トラッカー')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_consentGranted) {
      return _buildConsentGate(cs);
    }
    final alertColor =
        _todayCount >= _alertThreshold ? Colors.orange[700]! : cs.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('髪・自己接触トラッカー')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildSafetyCard(cs),
            const SizedBox(height: 16),
            _buildTodayCard(cs, alertColor),
            const SizedBox(height: 24),
            _buildTapButton(alertColor),
            const SizedBox(height: 32),
            _buildWeekChart(cs),
            const SizedBox(height: 24),
            _buildTipsSection(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentGate(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(title: const Text('髪・自己接触トラッカー')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        size: 40, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      _disclosure.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(_disclosure.body),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _requestConsent,
                      child: const Text('説明を確認する'),
                    ),
                    TextButton.icon(
                      onPressed: _openSupportResources,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(_disclosure.supportLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyCard(ColorScheme cs) {
    return Card(
      color: cs.secondaryContainer.withValues(alpha: 0.55),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '医療上の診断・治療ではありません',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '回数は自己観察のメモです。心身の不調が続く場合は、医療機関や公的な相談窓口を利用してください。',
              style: TextStyle(color: cs.onSecondaryContainer, height: 1.4),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openSupportResources,
              icon: const Icon(Icons.open_in_new),
              label: Text(_disclosure.supportLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(ColorScheme cs, Color alertColor) {
    final isAlert = _todayCount >= _alertThreshold;
    return Card(
      color: isAlert
          ? Colors.orange.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              isAlert ? Icons.self_improvement : Icons.touch_app,
              color: alertColor,
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今日の記録',
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '$_todayCount 回',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: alertColor,
                    ),
                  ),
                  if (isAlert)
                    Text(
                      'ひと休みや代替アクションを選べます',
                      style: TextStyle(color: alertColor, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapButton(Color color) {
    return Center(
      child: ScaleTransition(
        scale: _pulseAnim,
        child: GestureDetector(
          onTap: _record,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✋', style: TextStyle(fontSize: 48)),
                SizedBox(height: 8),
                Text(
                  '今、触った',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekChart(ColorScheme cs) {
    if (_weekTrend.isEmpty) return const SizedBox.shrink();
    final maxCount =
        _weekTrend.map((t) => t.count).fold(0, (a, b) => a > b ? a : b);
    final displayMax = math.max(maxCount, _alertThreshold).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '過去7日間',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _weekTrend.map((item) {
              final ratio = displayMax > 0 ? item.count / displayMax : 0.0;
              final isAlert = item.count >= _alertThreshold;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (item.count > 0)
                        Text(
                          '${item.count}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isAlert ? Colors.orange[700] : cs.primary,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: ratio.clamp(0.04, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isAlert
                                  ? Colors.orange[700]
                                  : cs.primary.withValues(alpha: 0.7),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              color: Colors.orange[700],
              margin: const EdgeInsets.only(right: 4),
            ),
            Text(
              'セルフケア提案（$_alertThreshold回以上）',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipsSection(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '代替アクション一覧',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        ..._alternatives.map(
          (a) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(a.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(
              a.label,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            subtitle: Text(
              a.reason,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlternativeAction {
  final String emoji;
  final String label;
  final String reason;
  const _AlternativeAction(this.emoji, this.label, this.reason);
}
