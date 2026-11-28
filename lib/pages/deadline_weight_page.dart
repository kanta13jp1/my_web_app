import 'package:flutter/material.dart';

import '../models/deadline_weight_models.dart';
import '../services/deadline_weight_service.dart';
import '../theme/design_tokens.dart';

/// 締め切りの重さ。
///
/// ADHD 傾向の脳は「来週の月曜に締め切りがある」を頭では理解しても、
/// 身体的な重さを伴う脅威としては認識しない (時間盲目性 / 時間的近視眼)。
/// そこでこの画面は残り日数ではなく **「手を動かせる残り時間」** を主役にし、
/// 本人が見積もった必要時間と並べて「間に合う / 足りない」を出す。
///
/// 足りないときに責めないことが設計の芯になっている。自己批判は次の行動の
/// 閾値を上げるだけなので、代わりに数字のついた打ち手を 3 つ提示する。
///
/// 個人の締め切りを扱うため **ログイン済みユーザー限定**。
class DeadlineWeightPage extends StatefulWidget {
  const DeadlineWeightPage({super.key, this.service});

  /// データ供給 (テスト時に差し替え可能)。
  final DeadlineWeightService? service;

  @override
  State<DeadlineWeightPage> createState() => _DeadlineWeightPageState();
}

class _DeadlineWeightPageState extends State<DeadlineWeightPage> {
  late final DeadlineWeightService _service;

  DeadlineWeightSnapshot? _snapshot;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? DeadlineWeightService();
    if (_service.isSignedIn) {
      _reload();
    } else {
      _loading = false;
    }
  }

  Future<void> _reload() async {
    try {
      final items = await _service.fetchItems();
      final settings = await _service.fetchSettings();
      if (!mounted) return;
      setState(() {
        _snapshot = buildDeadlineWeightSnapshot(
          items,
          settings,
          DateTime.now(),
        );
        _loading = false;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '締め切りの読み込みに失敗しました: $e';
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _service.isSignedIn;
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.hourglass_bottom,
              color: DesignTokens.orange,
              size: 20,
            ),
            SizedBox(width: DesignTokens.space8),
            Text(
              '締め切りの重さ',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: '可処分時間の設定',
              onPressed: _openSettingsSheet,
              icon: const Icon(Icons.tune, size: 20),
            ),
        ],
      ),
      floatingActionButton: signedIn
          ? FloatingActionButton.extended(
              backgroundColor: DesignTokens.orange,
              onPressed: _openAddDialog,
              icon: const Icon(Icons.add),
              label: const Text('締め切りを追加'),
            )
          : null,
      body: signedIn ? _buildBody() : _buildSignInGate(),
    );
  }

  // ── ログイン導線 ───────────────────────────────────────────
  Widget _buildSignInGate() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 40,
              color: DesignTokens.textTertiary,
            ),
            const SizedBox(height: DesignTokens.space16),
            const Text(
              'この機能はログインが必要です',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.space8),
            const Text(
              '自分の締め切りと可処分時間を扱うため、\n'
              'ログインしたユーザーのみ利用できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: DesignTokens.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DesignTokens.space24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.orange,
              ),
              onPressed: () => Navigator.of(context).pushNamed('/login'),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('ログインする'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 本体 ───────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final snapshot = _snapshot;
    if (_error.isNotEmpty && snapshot == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.space24),
          child: Text(
            _error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: DesignTokens.red),
          ),
        ),
      );
    }
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      _buildBudgetStrip(snapshot.settings),
      if (snapshot.isEmpty)
        _buildEmptyState()
      else ...[
        if (snapshot.shortCount > 0) _buildShortSummary(snapshot.shortCount),
        for (final card in snapshot.active) _buildCard(card, snapshot.settings),
        if (snapshot.overdue.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              DesignTokens.space16,
              DesignTokens.space24,
              DesignTokens.space16,
              DesignTokens.space8,
            ),
            child: Text(
              '期日を過ぎたもの',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
          for (final card in snapshot.overdue)
            _buildCard(card, snapshot.settings),
        ],
      ],
      const SizedBox(height: 96),
    ];

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.only(top: DesignTokens.space8),
        children: children,
      ),
    );
  }

  Widget _buildBudgetStrip(DisposableTimeSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space8,
        DesignTokens.space16,
        DesignTokens.space8,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        onTap: _openSettingsSheet,
        child: Container(
          padding: const EdgeInsets.all(DesignTokens.space16),
          decoration: BoxDecoration(
            color: DesignTokens.surface1,
            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
            border: Border.all(color: DesignTokens.divider),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule,
                size: 18,
                color: DesignTokens.indigo,
              ),
              const SizedBox(width: DesignTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1週間に手を動かせる時間',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.space2),
                    Text(
                      formatMinutes(settings.weeklyMinutes),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: DesignTokens.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortSummary(int shortCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space4,
        DesignTokens.space16,
        DesignTokens.space8,
      ),
      child: Text(
        '$shortCount件は、今のままだと時間が足りません。打てる手を下に出しています。',
        style: const TextStyle(
          fontSize: 12,
          color: DesignTokens.amber,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.space24,
        DesignTokens.space32,
        DesignTokens.space24,
        DesignTokens.space24,
      ),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 40,
            color: DesignTokens.textTertiary,
          ),
          SizedBox(height: DesignTokens.space16),
          Text(
            'まだ締め切りがありません',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textPrimary,
            ),
          ),
          SizedBox(height: DesignTokens.space8),
          Text(
            '気になっている締め切りをひとつ入れてみてください。\n'
            '「あと何日」ではなく「手を動かせるのは あと何時間」に置き換えます。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: DesignTokens.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ── カード ─────────────────────────────────────────────────
  Color _verdictColor(DeadlineVerdict verdict) => switch (verdict) {
        DeadlineVerdict.comfortable => DesignTokens.green,
        DeadlineVerdict.tight => DesignTokens.amber,
        DeadlineVerdict.short => DesignTokens.orange,
        DeadlineVerdict.overdue => DesignTokens.textTertiary,
      };

  Widget _buildCard(DeadlineWeightCard card, DisposableTimeSettings settings) {
    final color = _verdictColor(card.verdict);
    final isOverdue = card.verdict == DeadlineVerdict.overdue;
    final borderColor =
        isOverdue ? DesignTokens.divider : color.withValues(alpha: 0.35);
    final slack = card.slackMinutes;
    final slackLabel = slack >= 0
        ? '余り ${formatMinutes(slack)}'
        : '${formatMinutes(-slack)} 足りない';

    final body = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              card.item.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: DesignTokens.space8),
          _chip(verdictLabel(card.verdict), color),
        ],
      ),
      const SizedBox(height: DesignTokens.space4),
      Text(
        '${_formatDueOn(card.item.dueOn)} · '
        '${formatDaysLeft(card.calendarDaysLeft)}',
        style: const TextStyle(
          fontSize: 12,
          color: DesignTokens.textSecondary,
        ),
      ),
      const SizedBox(height: DesignTokens.space16),
      if (isOverdue)
        const Text(
          '過ぎたことは責めません。まだ必要なら、新しい期日を決め直しましょう。',
          style: TextStyle(
            fontSize: 12,
            color: DesignTokens.textSecondary,
            height: 1.5,
          ),
        )
      else ...[
        RichText(
          text: TextSpan(
            children: [
              const TextSpan(
                text: '手を動かせるのは ',
                style: TextStyle(
                  fontSize: 13,
                  color: DesignTokens.textSecondary,
                ),
              ),
              TextSpan(
                text: 'あと${formatMinutes(card.disposableMinutes)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignTokens.space8),
        ClipRRect(
          borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
          child: LinearProgressIndicator(
            value: (card.fillRatio / 2).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: DesignTokens.surface3,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: DesignTokens.space8),
        Text(
          '必要と見ているのは ${formatMinutes(card.requiredMinutes)} · $slackLabel',
          style: const TextStyle(
            fontSize: 12,
            color: DesignTokens.textSecondary,
          ),
        ),
      ],
      if (card.recovery != null) ...[
        const SizedBox(height: DesignTokens.space16),
        _buildRecovery(card, card.recovery!, settings),
      ],
      const SizedBox(height: DesignTokens.space8),
      Row(
        children: [
          TextButton.icon(
            onPressed: () => _pickNewDueDate(card),
            icon: const Icon(Icons.event, size: 16),
            label: const Text('期日を変える'),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _run(() => _service.completeItem(card.item.id)),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('完了'),
          ),
          IconButton(
            tooltip: '削除',
            onPressed: () => _confirmDelete(card),
            icon: const Icon(
              Icons.delete_outline,
              size: 18,
              color: DesignTokens.textTertiary,
            ),
          ),
        ],
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.space16,
        DesignTokens.space4,
        DesignTokens.space16,
        DesignTokens.space8,
      ),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: DesignTokens.surface1,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: body,
        ),
      ),
    );
  }

  /// 「もう足りない」ときの 3 択。責めずに、数字のついた選択肢だけを出す。
  Widget _buildRecovery(
    DeadlineWeightCard card,
    RecoveryOptions recovery,
    DisposableTimeSettings settings,
  ) {
    final postpone = recovery.postponeDays;
    final actions = <Widget>[
      if (postpone != null)
        _recoveryButton(
          '期日を$postpone日ずらす',
          () => _run(
            () => _service.updateDueOn(
              card.item.id,
              DateTime(
                card.item.dueOn.year,
                card.item.dueOn.month,
                card.item.dueOn.day + postpone,
              ),
            ),
          ),
        ),
      _recoveryButton(
        '必要時間を${formatMinutes(recovery.cutMinutes)}削る',
        () => _run(
          () => _service.updateRequiredMinutes(
            card.item.id,
            card.requiredMinutes - recovery.cutMinutes,
          ),
        ),
      ),
      _recoveryButton(
        '毎日${formatMinutes(recovery.extraMinutesPerDay)}増やす',
        () => _run(() {
          var next = settings;
          for (var weekday = DateTime.monday;
              weekday <= DateTime.sunday;
              weekday += 1) {
            next = next.copyWith(
              weekday: weekday,
              minutes: (next.minutesByWeekday[weekday] ?? 0) +
                  recovery.extraMinutesPerDay,
            );
          }
          return _service.saveSettings(next);
        }),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(DesignTokens.space12),
      decoration: BoxDecoration(
        color: DesignTokens.surface2,
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '打てる手',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textSecondary,
            ),
          ),
          const SizedBox(height: DesignTokens.space8),
          Wrap(
            spacing: DesignTokens.space8,
            runSpacing: DesignTokens.space8,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _recoveryButton(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: DesignTokens.textPrimary,
        side: const BorderSide(color: DesignTokens.divider),
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space12,
          vertical: DesignTokens.space8,
        ),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space8,
        vertical: DesignTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _formatDueOn(DateTime dueOn) => '${dueOn.month}月${dueOn.day}日';

  // ── 操作 ───────────────────────────────────────────────────
  Future<void> _pickNewDueDate(DeadlineWeightCard card) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: card.item.dueOn.isBefore(now) ? now : card.item.dueOn,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    await _run(() => _service.updateDueOn(card.item.id, picked));
  }

  Future<void> _confirmDelete(DeadlineWeightCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.surface1,
        title: const Text('この締め切りを削除しますか？'),
        content: Text(card.item.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _service.deleteItem(card.item.id));
  }

  Future<void> _openAddDialog() async {
    final titleController = TextEditingController();
    final hoursController = TextEditingController(text: '3');
    var dueOn = DateTime.now().add(const Duration(days: 7));

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: DesignTokens.surface1,
            title: const Text('締め切りを追加'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: '何の締め切り？',
                    hintText: '例: 確定申告の書類をそろえる',
                  ),
                ),
                const SizedBox(height: DesignTokens.space8),
                Row(
                  children: [
                    const Text(
                      '期日',
                      style: TextStyle(color: DesignTokens.textSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: dueOn,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                        );
                        if (picked != null) {
                          setDialogState(() => dueOn = picked);
                        }
                      },
                      child: Text('${dueOn.year}/${dueOn.month}/${dueOn.day}'),
                    ),
                  ],
                ),
                TextField(
                  controller: hoursController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '必要だと思う時間 (時間)',
                    helperText: '正確でなくて大丈夫。ざっくりで足ります。',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('やめる'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('追加する'),
              ),
            ],
          );
        },
      ),
    );

    final title = titleController.text.trim();
    final hours = double.tryParse(hoursController.text.trim()) ?? 0;
    titleController.dispose();
    hoursController.dispose();
    if (saved != true || title.isEmpty) return;

    final minutes = (hours * 60).round().clamp(1, 60000);
    await _run(
      () => _service.addItem(
        title: title,
        dueOn: dueOn,
        requiredMinutes: minutes,
      ),
    );
  }

  Future<void> _openSettingsSheet() async {
    final current = _snapshot?.settings ?? DisposableTimeSettings.initial;
    var draft = current;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: DesignTokens.surface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusXl),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final rows = <Widget>[
            const Text(
              '曜日ごとに手を動かせる時間',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.space4),
            const Text(
              '睡眠・仕事・生活を引いた「実際に作業できる時間」を入れてください。\n'
              'ここで決めた時間が、すべての締め切りの残り時間になります。',
              style: TextStyle(
                fontSize: 12,
                color: DesignTokens.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            for (var weekday = DateTime.monday;
                weekday <= DateTime.sunday;
                weekday += 1)
              _weekdayRow(
                weekday,
                draft,
                (minutes) => setSheetState(() {
                  draft = draft.copyWith(weekday: weekday, minutes: minutes);
                }),
              ),
            const SizedBox(height: DesignTokens.space8),
            Text(
              '1週間の合計: ${formatMinutes(draft.weeklyMinutes)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),
            const SizedBox(height: DesignTokens.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.orange,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存する'),
              ),
            ),
          ];

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(DesignTokens.space20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rows,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (saved != true) return;
    await _run(() => _service.saveSettings(draft));
  }

  Widget _weekdayRow(
    int weekday,
    DisposableTimeSettings settings,
    ValueChanged<int> onChanged,
  ) {
    const names = <int, String>{
      DateTime.monday: '月',
      DateTime.tuesday: '火',
      DateTime.wednesday: '水',
      DateTime.thursday: '木',
      DateTime.friday: '金',
      DateTime.saturday: '土',
      DateTime.sunday: '日',
    };
    final minutes = settings.minutesByWeekday[weekday] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.space4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              names[weekday] ?? '',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              // 上限は DB 制約 (0〜1440 分) に合わせる。「毎日N分増やす」で
              // 押し上げられた値が範囲外にならないようにするため。
              value: minutes.clamp(0, 1440).toDouble(),
              max: 1440,
              divisions: 48,
              activeColor: DesignTokens.orange,
              label: formatMinutes(minutes),
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              formatMinutes(minutes),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: DesignTokens.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
