import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:intl/intl.dart';

import '../services/abstinence_guard_store.dart';
import '../widgets/pwa_install_banner.dart';

class AbstinenceGuardPage extends StatefulWidget {
  final DateTime Function()? nowProvider;
  final DateTime? initialDate;

  const AbstinenceGuardPage({
    super.key,
    this.nowProvider,
    this.initialDate,
  });

  @override
  State<AbstinenceGuardPage> createState() => _AbstinenceGuardPageState();
}

class _AbstinenceGuardPageState extends State<AbstinenceGuardPage> {
  static const List<String> _digitalPresetIds = <String>[
    'sns',
    'mobile_games',
    'smartphone',
    'video',
    'manga',
  ];
  static const List<String> _impulsePresetIds = <String>[
    'alcohol',
    'smoking',
    'masturbation',
    'lust',
    'dating_apps',
  ];
  static const String _selfContactItemId = 'touch_hair';
  static const int _selfContactAlertThreshold = 3;

  AbstinenceGuardSnapshot? _snapshot;
  List<AbstinenceSlipDailyCount> _selfContactTrend =
      const <AbstinenceSlipDailyCount>[];
  bool _isLoading = true;
  late DateTime _selectedDate;

  DateTime _currentDate() => widget.nowProvider?.call() ?? DateTime.now();

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _selectedMoment() {
    final now = _currentDate();
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }

  _DailyGuardStatus _resolveDailyStatus(AbstinenceGuardSnapshot snapshot) {
    if (snapshot.totalSlipCount > 0) {
      return const _DailyGuardStatus(
        label: '逸脱あり',
        detail: 'その日は抑止ラインを突破しています。',
        color: Color(0xFFFF6B35),
        icon: Icons.warning_amber_rounded,
      );
    }
    if (snapshot.enabledCount == 0) {
      return const _DailyGuardStatus(
        label: '未設定',
        detail: 'その日の禁止対象が固定されていません。',
        color: Color(0xFF607D8B),
        icon: Icons.radio_button_unchecked,
      );
    }
    return const _DailyGuardStatus(
      label: '無傷',
      detail: '禁止対象を保ったまま終えています。',
      color: Color(0xFF4CAF50),
      icon: Icons.verified,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _startOfDay(widget.initialDate ?? _currentDate());
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await AbstinenceGuardStore.loadSnapshot(
      now: _selectedDate,
    );
    final selfContactTrend = await AbstinenceGuardStore.loadSlipCountsByDate(
      itemId: _selfContactItemId,
      now: _selectedDate,
    );
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _selfContactTrend = selfContactTrend;
      _isLoading = false;
    });
  }

  Future<void> _setEnabled(String itemId, bool isEnabled) async {
    await AbstinenceGuardStore.setEnabled(
      itemId: itemId,
      isEnabled: isEnabled,
      now: _selectedDate,
    );
    await _loadSnapshot();
  }

  Future<void> _incrementSlip(String itemId) async {
    await AbstinenceGuardStore.incrementSlip(
      itemId: itemId,
      triggerNote:
          itemId == _selfContactItemId ? 'self_contact_quick_record' : '',
      now: _selectedDate,
    );
    await _loadSnapshot();
    final item =
        AbstinenceGuardStore.items.where((entry) => entry.id == itemId);
    if (!mounted || item.isEmpty) return;
    final selectedItem = item.first;
    final updatedState =
        _snapshot == null ? null : _stateFor(_snapshot!, itemId);
    if (itemId == _selfContactItemId &&
        (updatedState?.slipCount ?? 0) >= _selfContactAlertThreshold) {
      await _showSelfContactIntervention(
        selectedItem,
        updatedState?.slipCount ?? _selfContactAlertThreshold,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selectedItem.label}: ${selectedItem.eliminationAction}',
        ),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearSlip(String itemId) async {
    await AbstinenceGuardStore.clearSlip(itemId: itemId, now: _selectedDate);
    await _loadSnapshot();
  }

  AbstinenceGuardState? _stateFor(
    AbstinenceGuardSnapshot snapshot,
    String itemId,
  ) {
    for (final state in snapshot.states) {
      if (state.item.id == itemId) return state;
    }
    return null;
  }

  Future<void> _recordSelfContact() async {
    await _incrementSlip(_selfContactItemId);
  }

  Future<void> _showSelfContactIntervention(
    AbstinenceGuardItem item,
    int slipCount,
  ) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('abstinence_guard_self_contact_alert'),
          title: const Text('代替アクションへ切替'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日は $slipCount 回記録されています。'),
              const SizedBox(height: 10),
              Text('排除手順: ${item.eliminationAction}'),
              const SizedBox(height: 6),
              Text('代替行動: ${item.replacementAction}'),
              const SizedBox(height: 6),
              const Text('追加: ストレスボールを握る、肩を回す、30秒だけ腹式呼吸する。'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('代替行動に戻る'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setEnabledBatch(List<String> itemIds) async {
    for (final itemId in itemIds) {
      await AbstinenceGuardStore.setEnabled(
        itemId: itemId,
        isEnabled: true,
        now: _selectedDate,
      );
    }
    await _loadSnapshot();
  }

  List<AbstinenceGuardState> _priorityStates(AbstinenceGuardSnapshot snapshot) {
    return snapshot.priorityStates;
  }

  List<AbstinenceQuitProtocolStatus> _quitProtocolStatuses(
    AbstinenceGuardSnapshot snapshot,
  ) {
    return snapshot.quitProtocolStatuses;
  }

  Future<void> _setQuitProtocolStep(
    String itemId,
    String stepId,
    bool isCompleted,
  ) async {
    await AbstinenceGuardStore.setQuitProtocolStep(
      itemId: itemId,
      stepId: stepId,
      isCompleted: isCompleted,
      now: _selectedDate,
    );
    await _loadSnapshot();
  }

  Future<void> _recordDisciplineRep(
    AbstinenceDisciplineCategory category,
  ) async {
    final moneyController = TextEditingController(
      text: category.defaultMoneySaved.toString(),
    );
    final timeController = TextEditingController(
      text: category.defaultTimeSavedMinutes.toString(),
    );
    final noteController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(category.label),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.description),
                  const SizedBox(height: 8),
                  Text(
                    category.principle,
                    style: const TextStyle(
                      color: Color(0xFF455A64),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: moneyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: '防いだ出費 (円)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: timeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      labelText: '取り戻した時間 (分)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: '何を我慢したか (任意)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('記録する'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    await AbstinenceGuardStore.recordDisciplineRep(
      categoryId: category.id,
      moneySaved: int.tryParse(moneyController.text.trim()) ??
          category.defaultMoneySaved,
      timeSavedMinutes: int.tryParse(timeController.text.trim()) ??
          category.defaultTimeSavedMinutes,
      note: noteController.text.trim(),
      now: _selectedMoment(),
    );
    await _loadSnapshot();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${category.label} を記録しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _removeDisciplineRep(String entryId) async {
    await AbstinenceGuardStore.removeDisciplineRep(
      entryId: entryId,
      now: _selectedDate,
    );
    await _loadSnapshot();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('我慢記録を取り消しました'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _moveDay(int offset) async {
    final candidate = _startOfDay(
      _selectedDate.add(Duration(days: offset)),
    );
    final today = _startOfDay(_currentDate());
    if (candidate.isAfter(today)) return;

    setState(() {
      _isLoading = true;
      _selectedDate = candidate;
    });
    await _loadSnapshot();
  }

  Future<void> _pickDate() async {
    final today = _startOfDay(_currentDate());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: today,
    );
    if (picked == null) return;

    final candidate = _startOfDay(picked);
    if (_isSameDay(candidate, _selectedDate)) return;

    setState(() {
      _isLoading = true;
      _selectedDate = candidate;
    });
    await _loadSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final targetDateLabel = DateFormat('yyyy/MM/dd').format(_selectedDate);
    final canMoveToNextDay = !_isSameDay(_selectedDate, _currentDate());
    final dailyStatus = snapshot == null
        ? const _DailyGuardStatus(
            label: '読込中',
            detail: '',
            color: Color(0xFF607D8B),
            icon: Icons.more_horiz,
          )
        : _resolveDailyStatus(snapshot);

    return Scaffold(
      appBar: AppBar(
        title: const Text('禁欲ガード'),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: const Color(0xFFE5E7EB),
      ),
      body: _isLoading || snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSnapshot,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const PwaInstallBanner(
                    storageKey: 'abstinence_guard_pwa_install_banner',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dailyStatus.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dailyStatus.color.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '今日やらないことを固定する',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.outlined(
                              tooltip: '前日',
                              onPressed: () => _moveDay(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Center(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: _pickDate,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      '対象日: $targetDateLabel',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton.outlined(
                              tooltip: '日付を選択',
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today_outlined),
                            ),
                            const SizedBox(width: 4),
                            IconButton.outlined(
                              tooltip: '翌日',
                              onPressed:
                                  canMoveToNextDay ? () => _moveDay(1) : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    dailyStatus.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    dailyStatus.icon,
                                    size: 16,
                                    color: dailyStatus.color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dailyStatus.label,
                                    style: TextStyle(
                                      color: dailyStatus.color,
                                      fontWeight: FontWeight.w800,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dailyStatus.detail,
                          style: TextStyle(
                            color: dailyStatus.color.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '害悪行動を「意思」ではなく「先に禁止する設定」に変える。',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetricChip(
                              label: '今日の禁止',
                              value: '${snapshot.enabledCount}件',
                              color: const Color(0xFFE53935),
                            ),
                            _buildMetricChip(
                              label: '逸脱回数',
                              value: '${snapshot.totalSlipCount}回',
                              color: const Color(0xFFFF6B35),
                            ),
                            _buildMetricChip(
                              label: '無傷',
                              value: '${snapshot.cleanEnabledCount}件',
                              color: const Color(0xFF4CAF50),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDisciplinePanel(snapshot.disciplineSnapshot),
                  _buildSelfContactPanel(snapshot),
                  _buildPriorityPanel(snapshot),
                  _buildAbsoluteQuitPanel(snapshot),
                  _buildPresetPanel(),
                  ...snapshot.states.map(_buildGuardCard),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSelfContactPanel(AbstinenceGuardSnapshot snapshot) {
    final state = _stateFor(snapshot, _selfContactItemId);
    final todayCount = state?.slipCount ?? 0;
    final weekTotal =
        _selfContactTrend.fold<int>(0, (sum, day) => sum + day.count);
    final alertActive = todayCount >= _selfContactAlertThreshold;
    final color =
        alertActive ? const Color(0xFFE53935) : const Color(0xFF0F766E);

    return Container(
      key: const Key('abstinence_guard_self_contact_panel'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.back_hand_outlined, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '自己接触トラッカー',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  alertActive ? '介入ライン' : '監視中',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '髪に手が伸びた瞬間だけ記録し、短時間で増えたら代替行動に切り替えます。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                label: '今日',
                value: '$todayCount回',
                color: color,
              ),
              _buildMetricChip(
                label: '7日合計',
                value: '$weekTotal回',
                color: const Color(0xFF3D5AFE),
              ),
              _buildMetricChip(
                label: '通知ライン',
                value: '$_selfContactAlertThreshold回',
                color: const Color(0xFFFF6B35),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSelfContactTrendBars(color),
          const SizedBox(height: 12),
          if (alertActive)
            Container(
              key: const Key('abstinence_guard_self_contact_inline_alert'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.22),
                ),
              ),
              child: const Text(
                '手を机に置く、ストレスボールを握る、肩を回す、30秒腹式呼吸のどれかに切り替えます。',
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('abstinence_guard_self_contact_log'),
                onPressed: _recordSelfContact,
                icon: const Icon(Icons.add_alert_rounded, size: 18),
                label: const Text('髪をさわった +1'),
                style: FilledButton.styleFrom(backgroundColor: color),
              ),
              OutlinedButton.icon(
                key: const Key('abstinence_guard_self_contact_report'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/weekly-slip-report',
                ),
                icon: const Icon(Icons.bar_chart, size: 18),
                label: const Text('週次レポート'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelfContactTrendBars(Color color) {
    if (_selfContactTrend.isEmpty) {
      return const Text('7日グラフを読み込み中です。');
    }

    final maxCount = _selfContactTrend.fold<int>(
      1,
      (maxValue, day) => day.count > maxValue ? day.count : maxValue,
    );

    return Container(
      key: const Key('abstinence_guard_self_contact_chart'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '日別頻度グラフ',
            style: TextStyle(fontWeight: FontWeight.w800, height: 1.5),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _selfContactTrend.map((day) {
                final barHeight = 8 + (44 * day.count / maxCount);
                final isToday = _isSameDay(day.date, _selectedDate);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${day.count}',
                          style: TextStyle(
                            color: isToday ? color : const Color(0xFF607D8B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: barHeight.toDouble(),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: (isToday ? color : const Color(0xFF3D5AFE))
                                .withValues(
                              alpha: day.count == 0 ? 0.18 : 0.72,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.label,
                          style: const TextStyle(fontSize: 10, height: 1.2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplinePanel(AbstinenceDisciplineSnapshot snapshot) {
    final stageColor = switch (snapshot.mindsetStageLabel) {
      '浪費を断れる' => const Color(0xFF4CAF50),
      '我慢が定着中' => const Color(0xFFFF6B35),
      '一拍置ける' => const Color(0xFF3D5AFE),
      _ => const Color(0xFF607D8B),
    };

    return Container(
      key: const Key('abstinence_guard_discipline_panel'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: stageColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stageColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '浪費耐性トレーニング',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  snapshot.mindsetStageLabel,
                  style: TextStyle(
                    color: stageColor,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '「買わなかった」「開かなかった」「不便に耐えた」を記録して、衝動より原則を強くする。',
          ),
          const SizedBox(height: 8),
          Text(
            snapshot.mindsetStageDetail,
            style: TextStyle(
              color: stageColor.withValues(alpha: 0.92),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                label: '我慢回数',
                value: '${snapshot.totalRepCount}回',
                color: const Color(0xFF3D5AFE),
              ),
              _buildMetricChip(
                label: '防いだ出費',
                value: '${_formatYen(snapshot.totalMoneySaved)}円',
                color: const Color(0xFF4CAF50),
              ),
              _buildMetricChip(
                label: '取り戻した時間',
                value: '${snapshot.totalTimeSavedMinutes}分',
                color: const Color(0xFFFF6B35),
              ),
              _buildMetricChip(
                label: '連続日数',
                value: '${snapshot.streakDays}日',
                color: const Color(0xFF795548),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...snapshot.summaries.map(_buildDisciplineCategoryCard),
          const SizedBox(height: 4),
          const Text(
            '最近の我慢',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (snapshot.recentEntries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF607D8B).withValues(alpha: 0.18),
                ),
              ),
              child: const Text(
                'まだ我慢記録がありません。小さな1回から積み上げます。',
              ),
            )
          else
            ...snapshot.recentEntries.take(4).map(_buildDisciplineEntryTile),
        ],
      ),
    );
  }

  Widget _buildDisciplineCategoryCard(
    AbstinenceDisciplineCategorySummary summary,
  ) {
    final category = summary.category;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: const Color(0xFF607D8B).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D5AFE).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${summary.count}回',
                  style: const TextStyle(
                    color: Color(0xFF3D5AFE),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(category.description),
          const SizedBox(height: 4),
          Text(
            category.principle,
            style: const TextStyle(
              color: Color(0xFF455A64),
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                label: '累計出費防止',
                value: '${_formatYen(summary.totalMoneySaved)}円',
                color: const Color(0xFF4CAF50),
              ),
              _buildMetricChip(
                label: '累計時間回収',
                value: '${summary.totalTimeSavedMinutes}分',
                color: const Color(0xFFFF6B35),
              ),
              _buildMetricChip(
                label: '既定値',
                value:
                    '${_formatYen(category.defaultMoneySaved)}円 / ${category.defaultTimeSavedMinutes}分',
                color: const Color(0xFF607D8B),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            key: Key('abstinence_guard_discipline_record_${category.id}'),
            onPressed: () => _recordDisciplineRep(category),
            icon: const Icon(Icons.fitness_center),
            label: const Text('我慢を記録する'),
          ),
        ],
      ),
    );
  }

  Widget _buildDisciplineEntryTile(AbstinenceDisciplineEntry entry) {
    final category = AbstinenceGuardStore.disciplineCategories.firstWhere(
      (candidate) => candidate.id == entry.categoryId,
      orElse: () => const AbstinenceDisciplineCategory(
        id: 'unknown',
        label: '我慢記録',
        description: '',
        principle: '',
        defaultMoneySaved: 0,
        defaultTimeSavedMinutes: 0,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFF607D8B).withValues(alpha: 0.16)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          category.label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            height: 1.5,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '防いだ出費 ${_formatYen(entry.moneySaved)}円 / 取り戻した時間 ${entry.timeSavedMinutes}分 / ${DateFormat('HH:mm').format(entry.recordedAt)}',
            ),
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(entry.note),
            ],
          ],
        ),
        trailing: IconButton(
          key: Key('abstinence_guard_discipline_delete_${entry.id}'),
          tooltip: '取り消す',
          onPressed: () => _removeDisciplineRep(entry.id),
          icon: const Icon(Icons.undo_outlined),
        ),
      ),
    );
  }

  String _formatYen(int amount) => NumberFormat('#,##0').format(amount);

  Widget _buildPresetPanel() {
    return Container(
      key: const Key('abstinence_guard_quick_preset_panel'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF607D8B).withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'よくある邪魔をまとめてガードする',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '思考を切りやすい対象を先にONにして、主犯を炙り出します。',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('abstinence_guard_quick_preset_digital'),
                onPressed: () => _setEnabledBatch(_digitalPresetIds),
                icon: const Icon(Icons.phone_android),
                label: const Text('SNS・ゲーム・動画'),
              ),
              FilledButton.tonalIcon(
                key: const Key('abstinence_guard_quick_preset_impulse'),
                onPressed: () => _setEnabledBatch(_impulsePresetIds),
                icon: const Icon(Icons.block),
                label: const Text('快楽衝動をまとめて遮断'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAbsoluteQuitPanel(AbstinenceGuardSnapshot snapshot) {
    final protocols = _quitProtocolStatuses(snapshot);

    return Container(
      key: const Key('abstinence_guard_absolute_quit_panel'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Absolute quit: alcohol and smoking',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Finish every blocking step for today before cravings hit. This is the hard-stop layer for 酒 and 煙草.',
          ),
          const SizedBox(height: 12),
          if (protocols.isEmpty)
            const Text('No absolute quit protocol is available for today.')
          else
            ...protocols.map((protocol) {
              final progressText =
                  '${protocol.completedCount}/${protocol.totalCount} done';
              final statusColor = protocol.isLockedForToday
                  ? const Color(0xFF4CAF50)
                  : protocol.isEnabled
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF607D8B);

              return Container(
                key: Key('abstinence_guard_absolute_quit_${protocol.item.id}'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            protocol.item.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            protocol.isLockedForToday
                                ? 'locked'
                                : protocol.isEnabled
                                    ? 'arming'
                                    : 'off',
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Today: $progressText / slips ${protocol.slipCount}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!protocol.isEnabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton.tonalIcon(
                          key: Key(
                            'abstinence_guard_absolute_enable_${protocol.item.id}',
                          ),
                          onPressed: () => _setEnabled(protocol.item.id, true),
                          icon: const Icon(Icons.shield_outlined),
                          label: Text(
                            'Enable ${protocol.item.label} guard first',
                          ),
                        ),
                      ),
                    ...protocol.steps.map((stepState) {
                      return CheckboxListTile(
                        key: Key(
                          'abstinence_guard_absolute_step_${protocol.item.id}_${stepState.step.id}',
                        ),
                        value: stepState.isCompleted,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(stepState.step.label),
                        subtitle: Text(
                          'Fallback: ${protocol.item.replacementAction}',
                        ),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          _setQuitProtocolStep(
                            protocol.item.id,
                            stepState.step.id,
                            value,
                          );
                        },
                      );
                    }),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPriorityPanel(AbstinenceGuardSnapshot snapshot) {
    final priorityStates = _priorityStates(snapshot);
    final primary = priorityStates.isEmpty ? null : priorityStates.first;

    return Container(
      key: const Key('abstinence_guard_priority_panel'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '思考をぶった切る主犯候補',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          if (primary == null)
            const Text(
              'まだ主犯候補が見えていません。まずは SNS / スマホゲーム / 動画 / 漫画 / オナニー / 煙草 / 酒 / 出会い系 などから先にガードを入れます。',
            )
          else ...[
            Text(
              '主犯: ${primary.item.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text('切断サイン: ${primary.item.interruptionSignal}'),
            const SizedBox(height: 4),
            Text('排除手順: ${primary.item.eliminationAction}'),
            const SizedBox(height: 4),
            Text('復帰行動: ${primary.item.replacementAction}'),
          ],
          if (priorityStates.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: priorityStates.take(3).map((state) {
                final color = state.slipCount > 0
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFFE53935);
                final suffix =
                    state.slipCount > 0 ? '逸脱 ${state.slipCount}回' : 'ガード中';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${state.item.label} $suffix',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuardCard(AbstinenceGuardState state) {
    final color =
        state.isEnabled ? const Color(0xFFE53935) : const Color(0xFF607D8B);
    final tags = <String>[
      if (state.item.isDigital) 'デジタル',
      if (state.item.isImpulse) '衝動',
    ];

    return Container(
      key: Key('abstinence_guard_card_${state.item.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.item.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
                Switch.adaptive(
                  key: Key('abstinence_guard_switch_${state.item.id}'),
                  value: state.isEnabled,
                  onChanged: (value) => _setEnabled(state.item.id, value),
                ),
              ],
            ),
            Text(
              state.isEnabled ? '今日は明確にやらない対象です。' : '必要なら今日の禁止対象に加える。',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.68),
                height: 1.5,
              ),
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '代替行動: ${state.item.replacementAction}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildActionBox(
              title: '切断サイン',
              value: state.item.interruptionSignal,
              color: color,
              icon: Icons.sensors_off_outlined,
            ),
            const SizedBox(height: 8),
            _buildActionBox(
              title: '排除手順',
              value: state.item.eliminationAction,
              color: const Color(0xFFE53935),
              icon: Icons.block,
            ),
            if (state.isEnabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: Key('abstinence_guard_slip_${state.item.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: const Color(0xFFE5E7EB),
                      ),
                      onPressed: () => _incrementSlip(state.item.id),
                      icon: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: Text('逸脱 +1 (${state.slipCount})'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: state.slipCount > 0
                        ? () => _clearSlip(state.item.id)
                        : null,
                    child: const Text('逸脱をクリア'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionBox({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    height: 1.5,
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

class _DailyGuardStatus {
  final String label;
  final String detail;
  final Color color;
  final IconData icon;

  const _DailyGuardStatus({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
  });
}
