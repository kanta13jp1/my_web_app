import 'package:flutter/material.dart';
import '../services/python_block_review.dart';

class PythonBlockReviewCard extends StatefulWidget {
  const PythonBlockReviewCard({super.key});
  @override
  State<PythonBlockReviewCard> createState() => _PythonBlockReviewCardState();
}

class _PythonBlockReviewCardState extends State<PythonBlockReviewCard> {
  final _response = TextEditingController();
  final _names = TextEditingController(text: 'parse_duration');
  PythonBlockReview? _result;
  String? _error;
  void _clear() => setState(() {
        _result = null;
        _error = null;
      });
  void _loadExample(bool ambiguous) {
    _names.text = 'parse_duration';
    _response.text = ambiguous
        ? '```python\ndef parse_duration(s):\n    return 1\n```\n```python\ndef parse_duration(s):\n    return 2\n```'
        : '```python\ndef parse_duration(s):\n    return 1\n```\n```python\nprint(parse_duration("1s"))\n```';
    _clear();
  }

  void _inspect() {
    try {
      final result = PythonBlockReview.inspect(_response.text, _names.text);
      setState(() {
        _result = result;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _result = null;
        _error = e.message.toString();
      });
    }
  }

  @override
  void dispose() {
    _response.dispose();
    _names.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '採点するコードを取り違えていませんか',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'AIの回答を貼り付けて、Pythonの実装と使用例を見比べます。入力は送信・保存せず、コードも実行しません。',
            ),
            const Text('人工の回答例を読み込めます。現在の入力を置き換えます。'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _loadExample(false),
                  child: const Text('使用例が末尾にある例'),
                ),
                OutlinedButton(
                  onPressed: () => _loadExample(true),
                  child: const Text('実装が2つある例'),
                ),
              ],
            ),
            TextField(
              controller: _names,
              decoration: const InputDecoration(
                labelText: '必要な関数名（カンマ区切り）',
              ),
              onChanged: (_) => _clear(),
            ),
            TextField(
              controller: _response,
              minLines: 3,
              maxLines: 8,
              maxLength: 30000,
              decoration: const InputDecoration(
                labelText: 'Pythonコードブロックを含む回答',
              ),
              onChanged: (_) => _clear(),
            ),
            FilledButton(onPressed: _inspect, child: const Text('コードの候補を確認する')),
            if (_error != null) Text(_error!),
            if (result != null) ...[
              Text(
                'Pythonブロック: ${result.blocks.length}件 / 関数名を含む候補: ${result.candidates.length}件',
              ),
              const Text(
                'これは行頭のdefと関数名を調べる形式確認です。構文・動作・要件の充足や、AIの自己判定が正しいかは検証していません。インデントされた定義やasync defは対象外です。',
              ),
              if (result.candidates.length != 1)
                const Text(
                  '候補を一意に選べません。元の回答と必要な関数を確認してください。',
                ),
              if (result.candidates.length == 1 &&
                  result.candidates.single != result.blocks.length - 1)
                const Text(
                  '末尾ブロックと関数を含む候補が異なります。使用例を採点していないか確認してください。',
                ),
              for (final index in result.candidates) ...[
                Text(
                  '候補 ${index + 1}',
                ),
                SelectableText(result.blocks[index]),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
