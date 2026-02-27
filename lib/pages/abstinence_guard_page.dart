import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/abstinence_guard_store.dart';

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
  AbstinenceGuardSnapshot? _snapshot;
  bool _isLoading = true;
  late DateTime _selectedDate;

  DateTime _currentDate() => widget.nowProvider?.call() ?? DateTime.now();

  DateTime _startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _selectedDate = _startOfDay(widget.initialDate ?? _currentDate());
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    final snapshot = await AbstinenceGuardStore.loadSnapshot(now: _selectedDate);
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
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
    await AbstinenceGuardStore.incrementSlip(itemId: itemId, now: _selectedDate);
    await _loadSnapshot();
  }

  Future<void> _clearSlip(String itemId) async {
    await AbstinenceGuardStore.clearSlip(itemId: itemId, now: _selectedDate);
    await _loadSnapshot();
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('禁欲ガード'),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _isLoading || snapshot == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSnapshot,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.24),
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
                              onPressed: canMoveToNextDay
                                  ? () => _moveDay(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
                              color: Colors.redAccent,
                            ),
                            _buildMetricChip(
                              label: '逸脱回数',
                              value: '${snapshot.totalSlipCount}回',
                              color: Colors.orange,
                            ),
                            _buildMetricChip(
                              label: '無傷',
                              value: '${snapshot.cleanEnabledCount}件',
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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
        ),
      ),
    );
  }

  Widget _buildGuardCard(AbstinenceGuardState state) {
    final color = state.isEnabled ? Colors.redAccent : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: state.isEnabled,
                  onChanged: (value) => _setEnabled(state.item.id, value),
                ),
              ],
            ),
            Text(
              state.isEnabled ? '今日は明確にやらない対象です。' : '必要なら今日の禁止対象に加える。',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.68),
              ),
            ),
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (state.isEnabled) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
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
}
