import 'package:flutter/material.dart';

class InboxQuickCaptureDialog extends StatefulWidget {
  const InboxQuickCaptureDialog({super.key, required this.onSave});

  final Future<void> Function(String text) onSave;

  @override
  State<InboxQuickCaptureDialog> createState() =>
      _InboxQuickCaptureDialogState();
}

class _InboxQuickCaptureDialogState extends State<InboxQuickCaptureDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  bool get _canSave => !_saving && _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await widget.onSave(text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = '保存できませんでした。通信状態を確認して、もう一度お試しください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.inbox_outlined),
          SizedBox(width: 8),
          Text('Inboxへメモ'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('inbox_quick_capture_text_field'),
              controller: _controller,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '今の考えをそのまま入力',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                key: const Key('inbox_quick_capture_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton.icon(
          key: const Key('inbox_quick_capture_save_button'),
          onPressed: _canSave ? _save : null,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Inboxに保存'),
        ),
      ],
    );
  }
}
