import 'package:flutter/cupertino.dart';
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
  bool _confirmingDiscard = false;
  String? _errorMessage;

  bool get _hasDraft => _controller.text.trim().isNotEmpty;

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

  Future<void> _requestClose() async {
    if (_saving || _confirmingDiscard) return;
    if (!_hasDraft) {
      Navigator.of(context).pop(false);
      return;
    }
    _confirmingDiscard = true;
    final discard = await showAdaptiveDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final platform = Theme.of(dialogContext).platform;
        final apple =
            platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
        void finish(bool value) => Navigator.of(dialogContext).pop(value);
        return AlertDialog.adaptive(
          title: const Text('入力したメモを破棄しますか？'),
          content: const Text('このメモはまだ保存されていません。'),
          actions: [
            if (apple) ...[
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => finish(false),
                child: const Text('入力を続ける'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => finish(true),
                child: const Text('破棄する'),
              ),
            ] else ...[
              TextButton(
                onPressed: () => finish(false),
                child: const Text('入力を続ける'),
              ),
              TextButton(
                onPressed: () => finish(true),
                child: const Text('破棄する'),
              ),
            ],
          ],
        );
      },
    );
    _confirmingDiscard = false;
    if (!mounted || discard != true) return;
    Navigator.of(context).pop(false);
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
    return PopScope<bool>(
      // Read the current draft in _requestClose, even before the next frame.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestClose();
      },
      child: AlertDialog(
        scrollable: true,
        title: const Row(
          children: [
            Icon(Icons.inbox_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('Inboxへメモ')),
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
                readOnly: _saving,
                minLines: 4,
                maxLines: 10,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  hintText: '今の考えをそのまま入力',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _errorMessage!,
                    key: const Key('inbox_quick_capture_error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _requestClose,
            child: const Text('キャンセル'),
          ),
          FilledButton.icon(
            key: const Key('inbox_quick_capture_save_button'),
            onPressed: _canSave ? _save : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : 'Inboxに保存'),
          ),
        ],
      ),
    );
  }
}
