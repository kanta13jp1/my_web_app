import 'package:flutter/material.dart';
import '../../utils/date_formatter.dart';

/// 日付範囲選択の結果
class DateFilterResult {
  final DateTime? startDate;
  final DateTime? endDate;
  final String selectedPreset;

  DateFilterResult({
    this.startDate,
    this.endDate,
    required this.selectedPreset,
  });
}

/// 日付フィルターダイアログ
class DateFilterDialog extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String initialPreset;

  const DateFilterDialog({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    this.initialPreset = '全期間',
  });

  @override
  State<DateFilterDialog> createState() => _DateFilterDialogState();
}

class _DateFilterDialogState extends State<DateFilterDialog> {
  late DateTime? _startDate;
  late DateTime? _endDate;
  late String _selectedPreset;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    _selectedPreset = widget.initialPreset;
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case '今日':
          _startDate = today;
          _endDate = today;
          break;
        case '昨日':
          final yesterday = today.subtract(const Duration(days: 1));
          _startDate = yesterday;
          _endDate = yesterday;
          break;
        case '今週':
          final weekday = now.weekday;
          final firstDayOfWeek = today.subtract(Duration(days: weekday - 1));
          _startDate = firstDayOfWeek;
          _endDate = today;
          break;
        case '先週':
          final weekday = now.weekday;
          final lastWeekEnd = today.subtract(Duration(days: weekday));
          final lastWeekStart = lastWeekEnd.subtract(const Duration(days: 6));
          _startDate = lastWeekStart;
          _endDate = lastWeekEnd;
          break;
        case '今月':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = today;
          break;
        case '先月':
          final lastMonth = DateTime(now.year, now.month - 1, 1);
          final lastMonthEnd = DateTime(now.year, now.month, 0);
          _startDate = lastMonth;
          _endDate = lastMonthEnd;
          break;
        case '全期間':
          _startDate = null;
          _endDate = null;
          break;
      }
    });
  }

  Widget _buildPresetChip(String label) {
    final isSelected = _selectedPreset == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        _applyPreset(label);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('日付で絞り込み'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'プリセット',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('今日'),
                _buildPresetChip('昨日'),
                _buildPresetChip('今週'),
                _buildPresetChip('先週'),
                _buildPresetChip('今月'),
                _buildPresetChip('先月'),
                _buildPresetChip('全期間'),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'カスタム範囲',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('開始日'),
              subtitle: Text(
                _startDate != null
                    ? DateFormatter.formatFull(_startDate!)
                    : '指定なし',
              ),
              trailing: _startDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _startDate = null;
                          _selectedPreset = 'カスタム';
                        });
                      },
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                    _selectedPreset = 'カスタム';
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('終了日'),
              subtitle: Text(
                _endDate != null ? DateFormatter.formatFull(_endDate!) : '指定なし',
              ),
              trailing: _endDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _endDate = null;
                          _selectedPreset = 'カスタム';
                        });
                      },
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: _startDate ?? DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                    _selectedPreset = 'カスタム';
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateFilterResult(
                startDate: null,
                endDate: null,
                selectedPreset: '全期間',
              ),
            );
          },
          child: const Text('リセット'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              DateFilterResult(
                startDate: _startDate,
                endDate: _endDate,
                selectedPreset: _selectedPreset,
              ),
            );
          },
          child: const Text('適用'),
        ),
      ],
    );
  }
}
