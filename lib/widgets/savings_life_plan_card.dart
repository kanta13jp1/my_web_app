import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/savings_life_plan.dart';
import '../services/savings_life_plan_service.dart';
import '../services/savings_life_plan_store.dart';
import '../services/savings_plan_proposal_service.dart';

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
    this.propose,
    this.proposalRevision = '',
  });

  final String userId;
  final DateTime today;
  final int monthlyCommitments;
  final bool commitmentsEstimated;
  final int? suggestedIncome;
  final VoidCallback onReviewPayments;
  final SavingsLifePlanStore? store;
  final Future<SavingsPlanProposal> Function()? propose;
  final String proposalRevision;

  @override
  State<SavingsLifePlanCard> createState() => _SavingsLifePlanCardState();
}

class _SavingsLifePlanCardState extends State<SavingsLifePlanCard> {
  final _form = GlobalKey<FormState>();
  final _cashBalance = TextEditingController();
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
  SavingsPlanProposal? _proposal;

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
    if (oldWidget.suggestedIncome != widget.suggestedIncome) {
      _income.text = widget.suggestedIncome?.toString() ?? '';
    }
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
        _cashBalance.text = plan.cashBalance?.toString() ?? '';
        _income.text = widget.suggestedIncome?.toString() ?? '';
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

  Future<void> _suggest() async {
    final generate = widget.propose;
    if (generate == null) return;
    final revision = widget.proposalRevision;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final proposal = await generate();
      if (!mounted) return;
      if (revision != widget.proposalRevision) {
        setState(() => _message = '分析中に口座情報が変わりました。再度提案を取得してください。');
        return;
      }
      setState(() {
        _proposal = proposal;
        _cashBalance.text = proposal.input.cashBalance.toString();
        _income.text = widget.suggestedIncome?.toString() ?? '';
        _living.text = proposal.livingCosts.toString();
        _reserve.text = proposal.reserve.toString();
        _edited = true;
        _message = '提案を入力欄に反映しました。根拠と必要生活費を確認してから保存してください。';
      });
    } catch (_) {
      if (mounted) setState(() => _message = '提案を取得できませんでした。保存済み計画は保持します。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseDeadline() async {
    final first =
        SavingsLifePlanService.day(widget.today).add(const Duration(days: 1));
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
      cashBalance: _amount(_cashBalance.text),
      income: widget.suggestedIncome,
      livingCosts: _amount(_living.text),
      reserve: _amount(_reserve.text)!,
      guidance: _proposal?.rationale ?? _plan.guidance,
      proposalSource: _proposal?.source ?? _plan.proposalSource,
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
    bool readOnly = false,
  }) =>
      SizedBox(
        width: min(300, MediaQuery.sizeOf(context).width - 80),
        child: TextFormField(
          controller: controller,
          readOnly: readOnly,
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
      monthlyIncomeCeiling: widget.suggestedIncome,
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
              '1年後の同棲準備資金100万円・節約生活の計画',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${SavingsLifePlan.dateText(_plan.start)} → ${SavingsLifePlan.dateText(_plan.targetDate)}',
            ),
            const Text(
              '目標は、翌1給与サイクル分の生活費・固定費・返済・予備費を別に確保した後、同棲準備に丸々使える100万円です。収入増・副業収入は前提にしません。投資評価額・借入可能額は含めません。',
            ),
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
              OutlinedButton.icon(
                onPressed: _busy || widget.propose == null ? null : _suggest,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('口座を分析してAI提案'),
              ),
              const Text(
                '現金・預金、登録返済・固定費、手取り計画、生活費の集計だけを既存AIへ送ります。口座番号や明細原文は送りません。AIが使えない場合は仮置き案と表示します。',
              ),
              if (_proposal != null) ...[
                Semantics(container: true, child: Text(_proposal!.source)),
                Text(
                  '現在の貯蓄余力案：${_yen(_proposal!.availableSavings)} / 別枠確保：${_yen(_proposal!.protectedCash)}',
                ),
                if (_proposal!.reserveShortfall > 0)
                  Text(
                    '確保資金が ${_yen(_proposal!.reserveShortfall)} 不足。先に生活と支払いを確保します。',
                  ),
                Text(
                  '生活費案 ${_yen(_proposal!.livingCosts)}・予備費案 ${_yen(_proposal!.reserve)}',
                ),
                Semantics(container: true, child: Text(_proposal!.rationale)),
                Text(
                  '生活費記録がある日：${_proposal!.input.recordedDays}日。未入力支出・臨時支出・未確定請求は別途確認が必要です。',
                ),
              ],
              if (widget.suggestedIncome == null)
                const Text('手取り収入が未確認です。給与明細または登録給料額を確認してください。収入増は計画に含めません。'),
              Form(
                key: _form,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    _field('現在の現金・預金（計画の起点）', _cashBalance),
                    _field('登録済みの手取り収入（収入増なし）', _income, readOnly: true),
                    _field('毎月の生活費（食費・交通・日用品等）', _living, positive: true),
                    _field('毎月の予備費（臨時支出用）', _reserve),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '口座の現金・預金から、翌1サイクルの生活費・返済・固定費・予備費を別枠で確保します。生活費には上の固定費を重複して含めないでください。',
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '保存中…' : '計画を保存・再計算'),
              ),
              if (!_saved || !result.ready)
                const Text('口座分析の提案または入力を確認して保存すると、自由資金の達成見込みと日々の予算を表示します。'),
              if (_edited) const Text('未保存の入力があります。下の試算は最後に保存した計画です。'),
              if (_saved && result.ready) ...[
                const Divider(height: 32),
                Semantics(
                  container: true,
                  header: true,
                  child: Text('必要な積立：月 ${_yen(result.requiredMonthlySavings)}'),
                ),
                Text('生活費・返済・予備費を引いた余力：月 ${_yen(result.monthlyCapacity)}'),
                Text('翌1サイクルの別枠確保：${_yen(result.protectedCash)}'),
                Text(
                  '期限時点で必要な現金・預金：${_yen(_plan.target + result.protectedCash)}（自由資金100万円＋別枠確保）',
                ),
                Text('現在の自由資金：${_yen(max(0, result.currentFreeCash))}'),
                if (result.currentFreeCash < 0)
                  Text(
                    '現在の別枠確保不足：${_yen(-result.currentFreeCash)}。この不足の補充も必要積立に含めています。',
                  ),
                if (result.expired)
                  Text(
                    result.currentFreeCash >= _plan.target
                        ? '期限到達：確保資金を除いた自由資金が目標以上です。'
                        : '期限に到達しています。現在の現金・預金を確認して計画を見直してください。',
                  )
                else if (result.monthlyShortfall > 0) ...[
                  Semantics(
                    container: true,
                    header: true,
                    liveRegion: true,
                    child: Text(
                      '現計画では月 ${_yen(result.monthlyShortfall)} 不足',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Text(
                    '食事・通勤・医療と返済を守り、不要な固定費・購入を見直す必要があります。収入増で不足を埋めません。削減可能額が足りなければ1年以内の達成は困難です。日々の使用可能額は提示しません。',
                  ),
                ] else
                  const Text('入力条件が続く場合、期限までの自由資金100万円を計画できます（達成保証ではありません）。'),
                Text('積立後の生活費上限：月 ${_yen(result.monthlyLivingCeiling)}'),
                const Text(
                  '新規借入・運用益・未確認のボーナスを収入に含めません。口座別・支払日ごとの不足は既存マネーカレンダーで別途確認してください。',
                ),
                const Text('見込みは生活費・返済後の余力を全額積み立てる場合です。将来の残高実績ではありません。'),
                ExpansionTile(
                  title: const Text('月ごとの目標と現計画の見込み'),
                  children: [
                    for (final checkpoint in result.checkpoints)
                      Semantics(
                        container: true,
                        label:
                            '${SavingsLifePlan.dateText(checkpoint.date)} 自由資金目標 ${_yen(checkpoint.targetSavings)} / 現計画 ${_yen(checkpoint.forecastSavings)}',
                        child: ExcludeSemantics(
                          child: ListTile(
                            title:
                                Text(SavingsLifePlan.dateText(checkpoint.date)),
                            subtitle: Text(
                              '自由資金目標 ${_yen(checkpoint.targetSavings)} / 現計画 ${_yen(checkpoint.forecastSavings)}',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (_proposal == null && _plan.guidance.isNotEmpty) ...[
                  Text('保存した生活方針：${_plan.proposalSource}'),
                  Text(_plan.guidance),
                ],
                const Divider(height: 24),
                Text(
                  '今日の生活設計 · $_day',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (result.currentFreeCash < 0)
                  const Text(
                    '別枠資金が未確保のため日割り使用可能額は出しません。食事・通勤・直近の支払いを先に確保し、支払日ごとの不足はマネーカレンダーで確認してください。',
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
                  'このメモは家計簿の支出・貯蓄・返済実績へ自動登録しません。重複を避け、実績は収支欄で照合してください。',
                ),
                _check('morning', '朝：朝食・食器洗い・歯磨き、今日の予定を確認'),
                _check('noon', '昼：昼食・食器洗い・歯磨き、残り予算を確認'),
                _check('evening', '夜：夕食・食器洗い・歯磨き、生活費を見直す'),
                _check('payments', '支払日・口座残高を確認（引落済みには変更しない）'),
                _check('savings', '給料日の積立予定と目標用貯蓄を確認（振替は実行しない）'),
                _check('work', '同棲準備の節約を1件見直す・休息時間を確保'),
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
    for (final controller in [
      _cashBalance,
      _income,
      _living,
      _reserve,
      _spent,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }
}
