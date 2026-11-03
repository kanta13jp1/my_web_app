import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/asset_liability_workbook.dart';
import '../services/asset_future_card_bill.dart';
import '../services/asset_liability_monthly_state_store.dart';
import '../services/asset_liability_repository.dart';

class AssetFutureCardBillCard extends StatefulWidget {
  final AssetLiabilityRepository repository;
  final List<AssetLiabilityAccount> accounts;
  final Set<String> subscriptionIds;
  final DateTime currentStateMonth;
  const AssetFutureCardBillCard({
    super.key,
    required this.repository,
    required this.accounts,
    required this.subscriptionIds,
    required this.currentStateMonth,
  });
  @override
  State<AssetFutureCardBillCard> createState() =>
      _AssetFutureCardBillCardState();
}

class _AssetFutureCardBillCardState extends State<AssetFutureCardBillCard> {
  late DateTime _month = DateTime(
    widget.currentStateMonth.year,
    widget.currentStateMonth.month + 1,
  );
  AssetLiabilityMonthlyState? _state;
  String? _accountId;
  String? _cardId;
  bool _busy = false;
  String? _message;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _state = null;
      _message = null;
    });
    try {
      final state = await widget.repository.loadMonth(_month);
      if (!widget.repository.isMonthVerifiedForAi(_month)) {
        throw StateError('サーバから対象月を確認できませんでした');
      }
      if (mounted) {
        setState(() {
          _state = state;
          _select(_accountId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = '対象月の読込に失敗しました。再読込してください。';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  void _select(String? id) {
    _accountId = id;
    _cardId = _state?.cardBillingAccountIds[id];
    _amount.text = _state?.paymentOverrides[id]?.toStringAsFixed(0) ?? '';
    final note = _state?.paymentDifferenceReasons[id] ?? '';
    _note.text = note.startsWith(AssetFutureCardBill.notePrefix)
        ? note.substring(AssetFutureCardBill.notePrefix.length)
        : '';
  }

  Future<void> _save() async {
    final amount = AssetFutureCardBill.parseAmount(_amount.text);
    if (_accountId == null ||
        _cardId == null ||
        amount == null ||
        amount <= 0) {
      setState(() {
        _message = '利用先・請求先カード・正の整数金額を入力してください。';
      });
      return;
    }
    final account = widget.accounts.singleWhere((a) => a.id == _accountId);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final base = await widget.repository.loadMonth(_month);
      if (!widget.repository.isMonthVerifiedForAi(_month) ||
          !widget.repository.supabaseWritesEnabled) {
        throw StateError('サーバ保存が有効ではありません');
      }
      final ownsRead = widget.repository.captureMonthAiOwnership(_month);
      final edited = AssetFutureCardBill.apply(
        state: base,
        accountId: account.id,
        accountName: account.name,
        cardId: _cardId!,
        amount: amount.toDouble(),
        note: _note.text,
        editedAt: DateTime.now(),
      );
      if (!ownsRead()) {
        throw StateError('保存対象のユーザーが変わりました');
      }
      await widget.repository.saveMonth(month: _month, state: edited);
      final restored = await widget.repository.loadMonth(_month);
      if (!ownsRead() ||
          await widget.repository.hasPendingMonthEdits(_month) ||
          restored.paymentOverrides[account.id] != amount.toDouble() ||
          restored.cardBillingAccountIds[account.id] != _cardId ||
          restored.paidAccountNames.contains(account.id) ||
          restored.paidAccountNames.contains(account.name) ||
          restored.actualPaymentAmounts.containsKey(account.id) ||
          restored.billingConfirmedAccountIds.contains(account.id)) {
        throw StateError('サーバ再読込の照合が未完了です');
      }
      if (mounted) {
        setState(() {
          _state = restored;
          _message = '対象月へ保存・サーバ再読込確認済み（未確定・未払い）';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = '保存の確認ができませんでした：$e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = widget.accounts
        .where((a) => widget.subscriptionIds.contains(a.id))
        .toList();
    final cards = widget.accounts
        .where(
          (a) =>
              a.kind == AssetLiabilityAccountKind.creditCard ||
              a.kind == AssetLiabilityAccountKind.shoppingDebt,
        )
        .toList();
    final months = List.generate(
      12,
      (i) => DateTime(
        widget.currentStateMonth.year,
        widget.currentStateMonth.month + i + 1,
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '将来月のカード請求内訳（未確定）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              '請求対象月の予定額だけを保存します。恒久月額・今月・カード請求総額・収支・残高を変更しません。カード請求に含むため別途引落として加算しません。支払日は確定しません。',
            ),
            for (final entry in (_state?.paymentDifferenceReasons.entries ??
                const <MapEntry<String, String>>[]))
              if (entry.value.startsWith(AssetFutureCardBill.notePrefix))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${widget.accounts.where((a) => a.id == entry.key).map((a) => a.name).firstOrNull ?? entry.key} '
                    '¥${_state!.paymentOverrides[entry.key]?.toStringAsFixed(0) ?? "未入力"} / '
                    '${cards.where((a) => a.id == _state!.cardBillingAccountIds[entry.key]).map((a) => a.name).firstOrNull ?? "カード未設定"}請求に含む / '
                    '未確定・${_state!.paidAccountNames.contains(entry.key) || _state!.actualPaymentAmounts.containsKey(entry.key) ? "支払状態を要照合" : "未払い"}\n'
                    '${entry.value.substring(AssetFutureCardBill.notePrefix.length)}',
                  ),
                ),
            DropdownButtonFormField<DateTime>(
              initialValue: _month,
              decoration: const InputDecoration(labelText: '請求対象月'),
              items: months
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(DateFormat('yyyy/MM').format(m)),
                    ),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (m) {
                      if (m != null) {
                        setState(() {
                          _month = m;
                        });
                        _load();
                      }
                    },
            ),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: '利用先'),
              items: subscriptions
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (id) => setState(() {
                        _select(id);
                      }),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey('$_accountId:$_cardId:${_month.month}'),
              initialValue: cards.any((a) => a.id == _cardId) ? _cardId : null,
              decoration: const InputDecoration(labelText: '請求先カード（請求に含む）'),
              items: cards
                  .map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                  )
                  .toList(),
              onChanged: _busy
                  ? null
                  : (id) => setState(() {
                        _cardId = id;
                      }),
            ),
            TextField(
              controller: _amount,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '未確定の予定額（円）'),
            ),
            TextField(
              controller: _note,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '対象期間・明細の注記（例：11月以降、11/27以降）',
              ),
            ),
            if (_message != null) Text(_message!),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('対象月を再読込'),
                ),
                FilledButton(
                  onPressed: _busy || _state == null ? null : _save,
                  child: const Text('未確定・未払いで保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
