import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/savings_life_plan.dart';
import '../services/savings_life_plan_service.dart';
import '../services/savings_life_plan_store.dart';

class SavingsLifePlanCard extends StatefulWidget {
  const SavingsLifePlanCard({
    super.key,
    required this.userId,
    required this.today,
    required this.monthlyCommitments,
    required this.commitmentsEstimated,
    required this.onReviewPayments,
    this.suggestedIncome,
    this.store,
  });

  final String userId;
  final DateTime today;
  final int monthlyCommitments;
  final bool commitmentsEstimated;
  final int? suggestedIncome;
  final VoidCallback onReviewPayments;
  final SavingsLifePlanStore? store;

  @override
  State<SavingsLifePlanCard> createState() => _SavingsLifePlanCardState();
}

class _SavingsLifePlanCardState extends State<SavingsLifePlanCard> {
  final _form = GlobalKey<FormState>();
  final _savings = TextEditingController();
  final _income = TextEditingController();
  final _living = TextEditingController();
  final _reserve = TextEditingController(text: '0');
  final _spent = TextEditingController(text: '0');
  late SavingsLifePlanStore _store;
  late SavingsLifePlan _plan;
  late DateTime _deadline;
  Set<String> _daily = {};
  bool _loading = true;
  bool _busy = false;
  bool _loadFailed = false;
  bool _saved = false;
  bool _edited = false;
  String? _message;

  String _yen(int value) => '¥${NumberFormat('#,###').format(value)}';
  String get _day => SavingsLifePlan.dateText(widget.today);

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? SavingsLifePlanStore(widget.userId);
    final start = SavingsLifePlanService.day(widget.today);
    _plan = SavingsLifePlan(
      start: start,
      targetDate: SavingsLifePlanService.anniversary(start, 12),
    );
    _deadline = _plan.targetDate;
    _load();
  }

  @override
  void didUpdateWidget(covariant SavingsLifePlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (SavingsLifePlan.dateText(oldWidget.today) != _day) {
      _daily = {};
      _spent.text = '0';
      _loadDaily();
    }
  }

  Future<void> _loadDaily() async {
    final requestedDay = _day;
    try {
      final daily = await _store.loadDaily(widget.today);
      if (!mounted || requestedDay != _day) return;
      setState(() {
        _daily = daily;
        _spent.text = daily
                .where((entry) => entry.startsWith('spent:'))
                .map((entry) => entry.substring(6))
                .firstOrNull ??
            '0';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _message = '今日のチェックを読み込めませんでした。';
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final saved = await _store.load();
      if (!mounted) return;
      final plan = saved ?? _plan;
      setState(() {
        _plan = plan;
        _deadline = plan.targetDate;
        _saved = saved != null;
        _edited = false;
        _savings.text = plan.savings?.toString() ?? '';
        _income.text =
            (plan.income ?? widget.suggestedIncome)?.toString() ?? '';
        _living.text = plan.livingCosts?.toString() ?? '';
        _reserve.text = plan.reserve.toString();
      });
      await _loadDaily();
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _amount(String value) {
    final clean = value.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,9}$').hasMatch(clean)) return null;
    final number = int.tryParse(clean);
    return number != null && number <= 100000000 ? number : null;
  }

  Future<void> _chooseDeadline() async {
    final first = SavingsLifePlanService.day(widget.today).add(const Duration(days: 1));
    final last = SavingsLifePlanService.anniversary(_plan.start, 24);
    if (first.isAfter(last)) return;
    final initial = _deadline.isBefore(first) ? first : _deadline;
    final chosen = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: '貯蓄目標の期限を選択',
    );
    if (chosen != null && mounted) {
      setState(() {
        _deadline = SavingsLifePlanService.day(chosen);
        _edited = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final next = SavingsLifePlan(
      start: _plan.start,
      targetDate: _deadline,
      target: _plan.target,
      savings: _amount(_savings.text),
      income: _amount(_income.text),
      livingCosts: _amount(_living.text),
      reserve: _amount(_reserve.text)!,
    );
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await _store.save(next);
      if (!mounted) return;
      setState(() {
        _plan = next;
        _saved = true;
        _edited = false;
        _message = '計画をこのブラウザーに保存しました。';
      });
    } catch (_) {
      if (mounted) {
        setState(() => _message = '保存できませんでした。入力は保持しています。再試行してください。');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDaily(Set<String> next) async {
    final date = widget.today;
    final requestedDay = _day;
    setState(() => _busy = true);
    try {
      await _store.saveDaily(date, next);
      if (!mounted || requestedDay != _day) return;
      setState(() {
        _daily = next;
        _message = '今日の計画チェックを保存しました（金融実績は変更しません）。';
      });
    } catch (_) {
      if (mounted) setState(() => _message = 'チェックを保存できませんでした。再試行してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool positive = false,
  }) =>
      SizedBox(
        width: min(300, MediaQuery.sizeOf(context).width - 80),
        child: TextFormField(
          controller: controller,
          onChanged: (_) => setState(() => _edited = true),
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: '円',
            border: const OutlineInputBorder(),
          ),
          validator: (value) => _amount(value ?? '') == null ||
                  (positive && _amount(value ?? '') == 0)
              ? (positive
                  ? '生活に必要な1円以上の金額を入力してください'
                  : '0〜100,000,000円の整数を入力してください')
              : null,
        ),
      );

  Widget _check(String id, String label) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _daily.contains(id),
        title: Text(label),
        onChanged: _busy
            ? null
            : (checked) {
                final next = Set<String>.from(_daily);
                if (checked == true) {
                  next.add(id);
                } else {
                  next.remove(id);
                }
                _saveDaily(next);
              },
      );

  @override
  Widget build(BuildContext context) {
    final result = SavingsLifePlanService.calculate(
      plan: _plan,
      asOf: widget.today,
      monthlyCommitments: widget.monthlyCommitments,
    );
    final storedSpent = _daily.where((e) => e.startsWith('spent:')).firstOrNull;
    final spent =
        storedSpent == null ? 0 : _amount(storedSpent.substring(6)) ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1年で貯蓄残高100万円・返済と生活の計画',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${SavingsLifePlan.dateText(_plan.start)} → ${SavingsLifePlan.dateText(_plan.targetDate)}',
            ),
            const Text('目標は貯蓄残高100万円です。投資評価額・借入可能額・支払い用の口座残高は自動算入しません。'),
            const Text('計画と日々のチェックは本人用にこのブラウザーへ保存します。他端末との同期はありません。'),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            if (_loadFailed) ...[
              const Text('保存済み計画を読み込めませんでした。上書きを防ぐため編集を止めています。'),
              TextButton(onPressed: _load, child: const Text('計画の読み込みを再試行')),
            ],
            if (!_loading && !_loadFailed) ...[
              const SizedBox(height: 16),
              Text(
                '登録済みの返済・固定費：月 ${_yen(widget.monthlyCommitments)}${widget.commitmentsEstimated ? '（推定額を含む）' : ''}',
              ),
              const Text(
                'カード請求に含む内訳を二重加算せず、今月の支払予定が毎月続く条件の試算です。返済額・支払日・臨時請求は明細で確認してください。',
              ),
              TextButton(
                onPressed: widget.onReviewPayments,
                child: const Text('返済・固定費と支払日を確認'),
              ),
              TextButton.icon(
              onPressed: _busy ? null : _chooseDeadline,
              icon: const Icon(Icons.event),
              label: Text('目標期限 ${SavingsLifePlan.dateText(_deadline)} を変更'),
            ),
            Form(
                key: _form,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _field('目標用の現在貯蓄残高', _savings),
                    _field('今後の毎月の手取り収入（計画値）', _income),
                    _field('毎月の生活費（食費・交通・日用品等）', _living, positive: true),
                    _field('毎月の予備費（臨時支出用）', _reserve),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '現在貯蓄は返済・当面の生活費を確保した上で、目標用に分けてある実額を入力してください。生活費には上の固定費を重複して含めないでください。',
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '保存中…' : '計画を保存・再計算'),
              ),
              if (!_saved || !result.ready)
                const Text('貯蓄・手取り・生活費を確認して保存すると、達成見込みと日々の予算を表示します。'),
              if (_edited) const Text('未保存の入力があります。下の試算は最後に保存した計画です。'),
              if (_saved && result.ready) ...[
                const Divider(height: 32),
                Semantics(
                container: true,
                header: true,
                child: Text('必要な積立：月 ${_yen(result.requiredMonthlySavings)}'),
              ),
                Text('生活費・返済・予備費を引いた余力：月 ${_yen(result.monthlyCapacity)}'),
                if (result.expired)
                  Text(
                    _plan.savings! >= _plan.target
                        ? '期限到達：入力した貯蓄残高は目標以上です。'
                        : '期限に到達しています。現在貯蓄を確認して計画を見直してください。',
                  )
                else if (result.monthlyShortfall > 0) ...[
                  Text(
                    '現計画では月 ${_yen(result.monthlyShortfall)} 不足',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '食事や通勤費を削って合わせず、収入増・固定費見直し・目標期限の再検討が必要です。日々の使用可能額は提示しません。',
                  ),
                ] else
                  const Text('入力条件が続く場合、期限までの100万円を計画できます（達成保証ではありません）。'),
                Text('積立後の生活費上限：月 ${_yen(result.monthlyLivingCeiling)}'),
                const Text(
                  '新規借入・運用益・未確認のボーナスを収入に含めません。口座別・支払日ごとの不足は既存マネーカレンダーで別途確認してください。',
                ),
                const Text('見込みは生活費・返済後の余力を全額積み立てる場合です。将来の残高実績ではありません。'),
                ExpansionTile(
                  title: const Text('月ごとの目標と現計画の見込み'),
                  children: [
                    for (final checkpoint in result.checkpoints)
                      ListTile(
                        title: Text(SavingsLifePlan.dateText(checkpoint.date)),
                        subtitle: Text(
                          '目標 ${_yen(checkpoint.targetSavings)} / 現計画 ${_yen(checkpoint.forecastSavings)}',
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '今日の生活設計 · $_day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result.dailyLivingBudget != null) ...[
                  Text(
                    '生活費の日割り目安 ${_yen(result.dailyLivingBudget!)} / 日（毎月の日数で計算）',
                  ),
                  Text(
                    '今日の計画メモ ${_yen(spent)} / 残り ${_yen(max(0, result.dailyLivingBudget! - spent))}',
                  ),
                  if (spent > result.dailyLivingBudget!)
                    Text(
                      '日割り目安を ${_yen(spent - result.dailyLivingBudget!)} 超えています。翌日の食事は確保し、週の配分を見直してください。',
                    ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: min(280, MediaQuery.sizeOf(context).width - 80),
                      child: TextField(
                        controller: _spent,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '今日の生活費合計（計画用メモ）',
                          suffixText: '円',
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () {
                              final amount = _amount(_spent.text);
                              if (amount == null) {
                                setState(
                                  () => _message =
                                      '生活費メモは0〜100,000,000円の整数で入力してください。',
                                );
                                return;
                              }
                              _saveDaily({
                                ..._daily.where((e) => !e.startsWith('spent:')),
                                'spent:$amount',
                              });
                            },
                      child: const Text('生活費メモを保存'),
                    ),
                  ],
                ),
                const Text(
                    'このメモは家計簿の支出・貯蓄・返済実績へ自動登録しません。重複を避け、実績は収支欄で照合してください。',),
                _check('morning', '朝：朝食・食器洗い・歯磨き、今日の予定を確認'),
                _check('noon', '昼：昼食・食器洗い・歯磨き、残り予算を確認'),
                _check('evening', '夜：夕食・食器洗い・歯磨き、生活費を見直す'),
                _check('payments', '支払日・口座残高を確認（引落済みには変更しない）'),
                _check('savings', '給料日の積立予定と目標用貯蓄を確認（振替は実行しない）'),
                _check('work', '収入を増やす行動を1件・休息時間を確保'),
              ],
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Text(_message!, key: const Key('savings-plan-message')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in [_savings, _income, _living, _reserve, _spent]) {
      controller.dispose();
    }
    super.dispose();
  }
}
