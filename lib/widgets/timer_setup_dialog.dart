import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// タイマー設定ダイアログ
class TimerSetupDialog extends StatefulWidget {
  final int? noteId;

  const TimerSetupDialog({
    super.key,
    this.noteId,
  });

  @override
  State<TimerSetupDialog> createState() => _TimerSetupDialogState();
}

class _TimerSetupDialogState extends State<TimerSetupDialog> {
  final _nameController = TextEditingController(text: 'ポモドーロ');
  int _hours = 0;
  int _minutes = 25;
  int _seconds = 0;
  bool _soundNotification = true;
  bool _browserNotification = true;
  bool _autoSave = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _setQuickTime(int minutes) {
    setState(() {
      _hours = 0;
      _minutes = minutes;
      _seconds = 0;
    });
  }

  int get _totalSeconds => (_hours * 3600) + (_minutes * 60) + _seconds;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー
              Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'タイマー設定',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'メモを書きながら集中時間を計測できます',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // タイマー名
              const Text(
                'タイマー名（任意）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'ポモドーロ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 時間設定
              const Text(
                '時間を設定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeInput(
                    '時',
                    _hours,
                    (value) => setState(() => _hours = value),
                    0,
                    23,
                  ),
                  const SizedBox(width: 12),
                  _buildTimeInput(
                    '分',
                    _minutes,
                    (value) => setState(() => _minutes = value),
                    0,
                    59,
                  ),
                  const SizedBox(width: 12),
                  _buildTimeInput(
                    '秒',
                    _seconds,
                    (value) => setState(() => _seconds = value),
                    0,
                    59,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // クイック設定
              const Text(
                'クイック設定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickButton('5分', 5),
                  _buildQuickButton('10分', 10),
                  _buildQuickButton('15分', 15),
                  _buildQuickButton('25分', 25),
                  _buildQuickButton('30分', 30),
                  _buildQuickButton('45分', 45),
                  _buildQuickButton('1時間', 60),
                ],
              ),
              const SizedBox(height: 24),

              // 通知設定
              const Text(
                '終了時の動作',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('サウンドで通知'),
                value: _soundNotification,
                onChanged: (value) {
                  setState(() {
                    _soundNotification = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('ブラウザ通知'),
                value: _browserNotification,
                onChanged: (value) {
                  setState(() {
                    _browserNotification = value ?? true;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (widget.noteId != null)
                CheckboxListTile(
                  title: const Text('自動保存'),
                  value: _autoSave,
                  onChanged: (value) {
                    setState(() {
                      _autoSave = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              const SizedBox(height: 24),

              // ボタン
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _totalSeconds > 0
                        ? () {
                            Navigator.of(context).pop({
                              'name': _nameController.text.trim().isEmpty
                                  ? 'タイマー'
                                  : _nameController.text.trim(),
                              'durationSeconds': _totalSeconds,
                              'soundNotification': _soundNotification,
                              'browserNotification': _browserNotification,
                              'autoSave': _autoSave,
                            });
                          }
                        : null,
                    child: const Text('開始'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput(
    String label,
    int value,
    ValueChanged<int> onChanged,
    int min,
    int max,
  ) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          child: TextField(
            controller: TextEditingController(text: value.toString()),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
            ),
            onChanged: (text) {
              final newValue = int.tryParse(text) ?? 0;
              if (newValue >= min && newValue <= max) {
                onChanged(newValue);
              }
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickButton(String label, int minutes) {
    final isSelected =
        _hours == 0 && _minutes == minutes && _seconds == 0;

    return ElevatedButton(
      onPressed: () => _setQuickTime(minutes),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
      child: Text(label),
    );
  }
}
