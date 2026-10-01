import 'package:flutter/material.dart';
import '../services/slide_number_check.dart';

class SlideNumberCheckCard extends StatefulWidget {
  const SlideNumberCheckCard({super.key});

  @override
  State<SlideNumberCheckCard> createState() => _SlideNumberCheckCardState();
}

class _SlideNumberCheckCardState extends State<SlideNumberCheckCard> {
  final _before = TextEditingController(text: '80');
  final _after = TextEditingController(text: '100');
  bool _rates = false;
  SlideNumberCheck? _result;
  String? _error;

  @override
  void dispose() {
    _before.dispose();
    _after.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _result = null;
      _error = null;
    });
  }

  void _calculate() {
    try {
      final result = SlideNumberCheck.calculate(_before.text, _after.text);
      if (_rates &&
          (double.parse(_before.text) > 100 ||
              double.parse(_after.text) > 100)) {
        throw const FormatException('割合は0〜100%の範囲で入力してください。基準の0%は増加率を計算できません。');
      }
      setState(() {
        _result = result;
        _error = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _result = null;
        _error = e.message;
      });
    }
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
            Text('原稿に書く前に数字を検算',
                style: Theme.of(context).textTheme.titleMedium,),
            const SizedBox(height: 8),
            const Text(
                '同じ単位の2つの値を入力します。入力は送信・保存しません。原稿から自動抽出せず、元の資料と照らして入力してください。',),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('割合（%）どうしを比べる'),
              value: _rates,
              onChanged: (value) {
                setState(() => _rates = value);
                _clear();
              },
            ),
            TextField(
              key: const Key('slide-number-before'),
              controller: _before,
              decoration: const InputDecoration(labelText: '基準の値（増加率の分母）'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('slide-number-after'),
              controller: _after,
              decoration: const InputDecoration(labelText: '比較する値'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _clear(),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _calculate, child: const Text('数字を確認する')),
            if (_error != null)
              Text(_error!, key: const Key('slide-number-error')),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text('増加率: ${result.growthPercent.toStringAsFixed(2)}%',
                  key: const Key('slide-number-result'),),
              if (_rates)
                Text('ポイント差: ${result.pointDifference.toStringAsFixed(2)}ポイント'),
              const Text('増加率 =（比較値 − 基準値）÷ 基準値 × 100。表示は小数第2位に丸めています。'),
              if (_rates)
                const Text('ポイント差は2つの割合の差です。10%→15%は5ポイント、増加率は50%です。'),
            ],
            const SizedBox(height: 8),
            const Text(
                '根拠が足りない場合は資料を取りに戻ります。この計算だけでは、元の数字・指標・期間が正しいかや、変更が増加の原因かは判断できません。',),
          ],
        ),
      ),
    );
  }
}
