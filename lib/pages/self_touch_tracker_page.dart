import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/abstinence_guard_store.dart';

class SelfTouchTrackerPage extends StatefulWidget {
  const SelfTouchTrackerPage({super.key});

  @override
  State<SelfTouchTrackerPage> createState() => _SelfTouchTrackerPageState();
}

class _SelfTouchTrackerPageState extends State<SelfTouchTrackerPage>
    with SingleTickerProviderStateMixin {
  static const String _itemId = 'touch_hair';
  static const int _alertThreshold = 3;

  static const List<_AlternativeAction> _alternatives = [
    _AlternativeAction('🤲', '利き手でない手で頭をゆっくり撫でる', 'オキシトシン分泌を促す代替行動'),
    _AlternativeAction('🏐', 'ストレスボールを握る', '手の筋肉へ意識を向けて衝動を逃がす'),
    _AlternativeAction('💨', '4-7-8 呼吸法', '4秒吸って・7秒止めて・8秒吐く'),
    _AlternativeAction('🧊', '冷たい水で手を洗う', '感覚を切り替えて衝動をリセット'),
    _AlternativeAction('🖊️', '今の気持ちをメモする', '言語化で衝動の強度が下がる'),
    _AlternativeAction('🚶', '5分だけ席を立つ', '環境を変えて刺激から距離を置く'),
  ];

  int _todayCount = 0;
  List<AbstinenceSlipDailyCount> _weekTrend = [];
  bool _loading = true;
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
    _load();
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

  Future<void> _record() async {
    await _pulseCtrl.forward(from: 0);
    await AbstinenceGuardStore.incrementSlip(itemId: _itemId);
    await _load();
    if (!mounted) return;

    if (_todayCount >= _alertThreshold) {
      _showAlternativeActions();
    }
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
    final alertColor =
        _todayCount >= _alertThreshold ? Colors.orange[700]! : cs.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('髪・自己接触トラッカー')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
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
              isAlert ? Icons.warning_amber_rounded : Icons.touch_app,
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
                      '代替アクションを試してみよう',
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
              '警戒ライン（$_alertThreshold回以上）',
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
