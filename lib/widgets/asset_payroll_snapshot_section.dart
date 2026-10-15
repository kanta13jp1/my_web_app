import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/asset_payroll_snapshot_store.dart';

/// Records explicit owner confirmation; never infers a deposit from a date.
class AssetPayrollSnapshotSection extends StatefulWidget {
  const AssetPayrollSnapshotSection({
    super.key,
    required this.store,
    required this.initialMonth,
  });
  final PayrollSnapshotStore store;
  final DateTime initialMonth;

  @override
  State<AssetPayrollSnapshotSection> createState() =>
      _AssetPayrollSnapshotSectionState();
}

class _AssetPayrollSnapshotSectionState
    extends State<AssetPayrollSnapshotSection> {
  final _balance = TextEditingController();
  final _date = TextEditingController();
  final _note = TextEditingController();
  final _reason = TextEditingController();
  final _form = GlobalKey<FormState>();
  List<PayrollSnapshotAccount> _accounts = [];
  String? _account;
  late DateTime _month;
  PayrollSnapshotRecord? _current;
  PayrollSnapshotRecord? _previous;
  PayrollSnapshotDraft? _pending;
  bool _loading = true;
  bool _dataReady = false;
  bool _busy = false;
  bool _reconciledAbsent = false;
  String? _error;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month);
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_balance, _date, _note, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _dataReady = false;
      _current = null;
      _previous = null;
      _error = null;
    });
    try {
      final accounts = await widget.store.accounts();
      if (!mounted || epoch != _epoch) return;
      final selected = accounts.any((a) => a.id == _account)
          ? _account
          : accounts.isEmpty
              ? null
              : accounts.first.id;
      final values = selected == null
          ? <PayrollSnapshotRecord?>[null, null]
          : await Future.wait([
              widget.store.selected(selected, _month),
              widget.store
                  .selected(selected, DateTime(_month.year, _month.month - 1)),
            ]);
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _accounts = accounts;
        _account = selected;
        _current = values[0];
        _previous = values[1];
        _loading = false;
        _dataReady = true;
      });
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      setState(() {
        _loading = false;
        _error = '取得できませんでした。再読込してください。';
      });
    }
  }

  Future<void> _createAccount() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('給与口座の呼び名'),
        content: TextField(
          controller: controller,
          maxLength: 120,
          decoration: const InputDecoration(labelText: '呼び名（口座番号は入力しない）'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || label == null) return;
    setState(() => _busy = true);
    try {
      await widget.store.createAccount(label);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = '口座設定の保存結果を確認できません。再追加前に再読込してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime? _validDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
    final date = DateTime.tryParse(value);
    return date != null &&
            payrollDate(date) == value &&
            !date.isAfter(DateUtils.dateOnly(DateTime.now()))
        ? date
        : null;
  }

  Future<void> _review() async {
    if (!_form.currentState!.validate() || _account == null) return;
    final draft = PayrollSnapshotDraft(
      accountId: _account!,
      month: _month,
      depositDate: _validDate(_date.text.trim())!,
      balanceYen: int.parse(_balance.text.trim()),
      note: _note.text.trim(),
      reason: _current == null ? '初回の本人確認' : _reason.text.trim(),
      requestId: const Uuid().v4(),
      previousId: _current?.id,
    );
    var acknowledged = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('給与入金直後の残高を確認'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '口座：${_accounts.firstWhere((a) => a.id == _account).label}',
                ),
                Text('対象月：${_month.year}/${_month.month}'),
                Text('給与入金日：${payrollDate(draft.depositDate)}（時刻未取得）'),
                Text('入金直後残高：${draft.balanceYen}円'),
                Text('確認資料メモ：${draft.note}'),
                if (_current != null)
                  Text('旧記録：${_current!.balanceYen}円／訂正理由：${draft.reason}'),
                const Text(
                  '記録種別は本人確認です。銀行検証済みではありません。資料は短文メモで残し、画像・PDFは送信しません。口座の呼び名・対象月・直後残高・訂正履歴を本人限定で保存し、既存残高・収支は変更しません。',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('後日の残高ではなく、給与入金取引の直後残高を確認しました'),
                  value: acknowledged,
                  onChanged: (value) =>
                      setDialogState(() => acknowledged = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('保留する'),
            ),
            FilledButton(
              onPressed:
                  acknowledged ? () => Navigator.pop(context, true) : null,
              child: const Text('確認して保存'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _pending = draft;
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.confirm(draft);
      if (!mounted) return;
      setState(() {
        _pending = null;
        _reconciledAbsent = false;
      });
      _balance.clear();
      _date.clear();
      _note.clear();
      _reason.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '保存結果が未確認です。再送せず「保存結果を照合」を押してください。画面を開き直した場合は同じ口座・月を選び、取得結果を確認してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconcile() async {
    final pending = _pending;
    if (pending == null) return;
    setState(() => _busy = true);
    try {
      final record = await widget.store.byRequest(pending);
      if (!mounted) return;
      if (record != null) {
        setState(() {
          _pending = null;
          _reconciledAbsent = false;
        });
        _balance.clear();
        _date.clear();
        _note.clear();
        _reason.clear();
        await _load();
      } else {
        setState(() {
          _reconciledAbsent = true;
          _error = '同内容の保存記録は見つかりません。再読込して編集へ戻れます。';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '照合できませんでした。再登録せず、時間を置いて照合してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _dataReady && !_loading && !_busy && _pending == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('給与入金直後の残高', style: Theme.of(context).textTheme.titleMedium),
            const Text('銀行の自動取得は未対応です。予定日や現在残高から推定しません。'),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: enabled
                      ? () {
                          _month = DateTime(_month.year, _month.month - 1);
                          _load();
                        }
                      : null,
                  child: const Text('前月'),
                ),
                Text('${_month.year}/${_month.month}'),
                TextButton(
                  onPressed: enabled
                      ? () {
                          _month = DateTime(_month.year, _month.month + 1);
                          _load();
                        }
                      : null,
                  child: const Text('翌月'),
                ),
                TextButton(
                  onPressed: !_busy && (_pending == null || _reconciledAbsent)
                      ? () {
                          _pending = null;
                          _reconciledAbsent = false;
                          _load();
                        }
                      : null,
                  child: const Text('再読込'),
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Text(_error!),
            if (_pending != null)
              TextButton(
                onPressed: _busy ? null : _reconcile,
                child: const Text('保存結果を照合'),
              ),
            if (!_loading && _accounts.isEmpty)
              TextButton(
                onPressed: enabled ? _createAccount : null,
                child: const Text('給与口座の呼び名を設定'),
              ),
            if (_accounts.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _account,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '給与口座'),
                items: [
                  for (final account in _accounts)
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.label),
                    ),
                ],
                onChanged: enabled
                    ? (value) {
                        _account = value;
                        _load();
                      }
                    : null,
              ),
              Text(
                '本人確認の直後残高：${_current == null ? '未取得' : '${_current!.balanceYen}円'}',
              ),
              Text(
                '前月との差：${_current == null || _previous == null ? '比較対象未取得' : '${_current!.balanceYen - _previous!.balanceYen}円'}',
              ),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _date,
                      enabled: enabled,
                      decoration:
                          const InputDecoration(labelText: '給与入金日（YYYY-MM-DD）'),
                      validator: (value) =>
                          _validDate(value?.trim() ?? '') == null
                              ? '実際の入金日を入力してください'
                              : null,
                    ),
                    TextFormField(
                      controller: _balance,
                      enabled: enabled,
                      decoration:
                          const InputDecoration(labelText: '給与入金取引の直後残高（円）'),
                      keyboardType:
                          const TextInputType.numberWithOptions(signed: true),
                      validator: (value) =>
                          RegExp(r'^-?\d+$').hasMatch(value?.trim() ?? '') &&
                                  int.tryParse(value!.trim()) != null
                              ? null
                              : '整数の残高を入力してください',
                    ),
                    TextFormField(
                      controller: _note,
                      enabled: enabled,
                      maxLength: 300,
                      decoration: const InputDecoration(
                        labelText: '確認資料の短文メモ（口座番号などは入力しない）',
                      ),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : '確認資料を入力してください',
                    ),
                    if (_current != null)
                      TextFormField(
                        controller: _reason,
                        enabled: enabled,
                        maxLength: 300,
                        decoration: const InputDecoration(
                          labelText: '訂正理由（旧記録は履歴に残ります）',
                        ),
                        validator: (value) => value?.trim().isNotEmpty == true
                            ? null
                            : '訂正理由を入力してください',
                      ),
                    FilledButton(
                      onPressed: enabled ? _review : null,
                      child: const Text('保存前の確認へ'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
