import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/budget_balance_calculator.dart';
import '../view_models/budget_balance_view_model.dart';

class BudgetBalanceCard extends StatefulWidget {
  const BudgetBalanceCard({super.key});

  @override
  State<BudgetBalanceCard> createState() => _BudgetBalanceCardState();
}

class _BudgetBalanceCardState extends State<BudgetBalanceCard> {
  final _model = BudgetBalanceViewModel();
  final _controllers = {
    for (final field in BudgetBalanceField.values)
      field: TextEditingController(),
  };
  final _format = NumberFormat('#,###', 'ja_JP');
  static const _labels = {
    BudgetBalanceField.income: '毎月の手取り（円）',
    BudgetBalanceField.essential: '必須生活費・返済（月額・円）',
    BudgetBalanceField.annual: '年払い・臨時支出（年額・円）',
    BudgetBalanceField.reserve: '現金の予備費積立（月額・円）',
    BudgetBalanceField.enjoyment: '今の楽しみ（月額・円）',
    BudgetBalanceField.investment: '投資積立（月額・円）',
  };
  static const _hints = {
    BudgetBalanceField.income: '税・社会保険料を引いた後。賞与は含めません',
    BudgetBalanceField.essential: '家賃、食費、光熱費、保険、返済などの合計',
    BudgetBalanceField.annual: '更新料・家電交換など。ほかの欄と重複させません',
    BudgetBalanceField.reserve: '急な出費に備え、今月現金で残す額',
    BudgetBalanceField.enjoyment: '趣味や外食など、自分が今使いたい額',
    BudgetBalanceField.investment: '自分で検討中の額。推奨額ではありません',
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _model,
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          final result = _model.result;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '今と将来の配分チェック',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('生活費、今の楽しみ、将来への備えを一緒に並べて、毎月の収支を確かめます。'),
                  const SizedBox(height: 8),
                  const Text(
                    '金額はこの画面での試算だけに使い、保存・送信しません。空欄は未確認として扱います。支出がないと確認できた欄は0を入力してください。',
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth >= 640
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 20,
                        children: [
                          for (final field in BudgetBalanceField.values)
                            SizedBox(
                              width: width,
                              child: TextField(
                                key: ValueKey('balance-${field.name}'),
                                controller: _controllers[field],
                                keyboardType: TextInputType.number,
                                onChanged: (value) =>
                                    _model.update(field, value),
                                decoration: InputDecoration(
                                  labelText: _labels[field],
                                  helperText: _hints[field],
                                  helperMaxLines: 4,
                                  errorText: _model.errorFor(field),
                                  errorMaxLines: 4,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _model.calculate,
                    icon: const Icon(Icons.balance),
                    label: const Text('配分を確認する'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: cs.onSurface,
                      foregroundColor: cs.surface,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: cs.onSurface),
                    onPressed: () {
                      for (final controller in _controllers.values) {
                        controller.clear();
                      }
                      _model.reset();
                    },
                    child: const Text('入力をクリア'),
                  ),
                  if (_model.needsRecalculation)
                    Semantics(
                      liveRegion: true,
                      child: const Text('金額を変更しました。配分をもう一度確認してください。'),
                    ),
                  if (result != null)
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: result.remaining < 0
                              ? cs.errorContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: result.remaining < 0
                                ? cs.onErrorContainer
                                : cs.onSurface,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.remaining < 0
                                    ? '毎月 ${_format.format(-result.remaining)}円の不足'
                                    : '配分後の残り ${_format.format(result.remaining)}円',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '年間支出の月割り：${_format.format(result.monthlyAnnualProvision)}円',
                              ),
                              Text(
                                '配分の合計：${_format.format(result.allocated)}円／月',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.remaining < 0
                                    ? '配分の合計が手取りを超えています。費用の重複・漏れと、それぞれの金額を見直してください。'
                                    : '入力した範囲での差額です。費用の漏れがないか確認してください。残額の投資を勧めるものではありません。',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '年間支出は12で割り、1円未満を切り上げます。支払日の残高や運用益は計算しません。本人の満足度や積立額の適否は、この差額だけでは判断できません。',
                  ),
                ],
              ),
            ),
          );
        },
      );
}
