import 'dart:convert';

import 'package:flutter/material.dart';

/// Checks the syntax of the entire input on the device without submitting it.
class JsonContractChecker extends StatefulWidget {
  const JsonContractChecker({super.key});

  @override
  State<JsonContractChecker> createState() => _JsonContractCheckerState();
}

class _JsonContractCheckerState extends State<JsonContractChecker> {
  final _controller = TextEditingController();
  bool? _isValid;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleInputChange);
  }

  void _handleInputChange() {
    setState(() => _isValid = null);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleInputChange);
    _controller.dispose();
    super.dispose();
  }

  void _check() {
    bool valid;
    try {
      jsonDecode(_controller.text);
      valid = true;
    } on FormatException {
      valid = false;
    }
    setState(() => _isValid = valid);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('JSON構文を確認', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('入力全文を端末内で確認します。内容の正しさや必須項目は判定しません。'),
            const SizedBox(height: 12),
            TextField(
              key: const Key('json-contract-input'),
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '確認するテキスト',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _controller.text.trim().isEmpty ? null : _check,
              child: const Text('JSON構文を確認する'),
            ),
            if (_isValid != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  _isValid!
                      ? '入力全文はJSONとして読み取れます。'
                      : '入力全文はJSONとして読み取れません。Markdownの囲みもJSONには含められません。',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
