import 'package:flutter/material.dart';
import '../services/jev_input_cost_comparison.dart';

class JevInputCostCard extends StatefulWidget {
  const JevInputCostCard({super.key});
  @override
  State<JevInputCostCard> createState() => _JevInputCostCardState();
}

class _JevInputCostCardState extends State<JevInputCostCard> {
  final _before = TextEditingController(text: '387');
  final _after = TextEditingController(text: '5762');
  final _requests = TextEditingController(text: '1000');
  final _rate = TextEditingController(text: '0.042');
  JevInputCostComparison? _result;
  String? _error;
  @override
  void dispose() {
    for (final controller in [_before, _after, _requests, _rate]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    try {
      final result = JevInputCostComparison.calculate(
        beforeTokens: int.parse(_before.text.trim()),
        afterTokens: int.parse(_after.text.trim()),
        requests: int.parse(_requests.text.trim()),
        usdPerMillionTokens: double.parse(_rate.text.trim()),
      );
      setState(() {
        _result = result;
        _error = null;
      });
    } on Object {
      setState(() {
        _result = null;
        _error = 'トークンは0以上の整数、回数は1以上の整数、単価は有限の0以上で入力してください。';
      });
    }
  }

  Widget _field(String label, TextEditingController controller) => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {
          _result = null;
          _error = null;
        }),
      );

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '入力を減らした場合の判断費用を比較',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                '入力トークン数はAPIのusageで確認します。文字数からは換算しません。単価は手動の仮定で、初期値は2026年10月10日確認のJev 1.13公開単価です。請求実額や速さ・精度は予測しません。入力は送信・保存しません。',
              ),
              _field('変更前の入力トークン / 1回', _before),
              _field('変更後の入力トークン / 1回', _after),
              _field('判断回数', _requests),
              _field('100万入力トークンの単価 / USD', _rate),
              const SizedBox(height: 12),
              FilledButton(onPressed: _calculate, child: const Text('概算費用を比較')),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_result case final result?)
                Text(
                  '変更前 USD ${result.beforeUsd.toStringAsFixed(6)}\n変更後 USD ${result.afterUsd.toStringAsFixed(6)}\n変更後 − 変更前 USD ${result.differenceUsd.toStringAsFixed(6)}',
                ),
            ],
          ),
        ),
      );
}
