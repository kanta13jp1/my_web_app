import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/asset_payslip_review_store.dart';
import 'asset_payroll_deductions_card.dart';

class AssetPayslipReviewDialog extends StatefulWidget {
  const AssetPayslipReviewDialog({
    super.key,
    required this.store,
    required this.payslipId,
    this.openPdf,
  });
  final PayslipReviewStore store;
  final String payslipId;
  final Future<bool> Function(Uri)? openPdf;
  @override
  State<AssetPayslipReviewDialog> createState() =>
      _AssetPayslipReviewDialogState();
}

class _AssetPayslipReviewDialogState extends State<AssetPayslipReviewDialog> {
  StreamSubscription<void>? _ownerSubscription;
  PayslipReviewSnapshot? _snapshot;
  bool _loading = true;
  bool _busy = false;
  bool _acknowledged = false;
  bool _pending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _ownerSubscription = widget.store.ownerChanges.listen((_) {
      if (mounted && !widget.store.isCurrentOwner) {
        setState(() {
          _snapshot = null;
          _acknowledged = false;
          _pending = false;
        });
      }
    });
    unawaited(_read());
  }

  @override
  void dispose() {
    unawaited(_ownerSubscription?.cancel());
    super.dispose();
  }

  Future<void> _read() async {
    setState(() {
      _loading = true;
      _snapshot = null;
      _acknowledged = false;
      _message = null;
    });
    try {
      final row = await widget.store.load(widget.payslipId);
      if (mounted) setState(() => _snapshot = row);
    } catch (_) {
      if (mounted) setState(() => _message = '明細を取得できませんでした。再取得してください。');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final row = _snapshot;
    if (_busy ||
        _pending ||
        !_acknowledged ||
        row == null ||
        row.blockingReason != null) { return; }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.store.confirm(row, confirmedDisplayedValues: true);
      if (!mounted) return;
      await _read();
      if (mounted) {
        setState(() => _message = _snapshot?.status == 'confirmed'
            ? '現在の記載内容は本人確認済みです。閉じると累計を再読込します。'
            : '確認更新の応答は受け取りました。現在状態を再取得してください。',);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pending = true;
          _acknowledged = false;
          _message = '保存結果が不明です。再送せず現在状態を照合してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reconcile() async {
    final old = _snapshot;
    if (!_pending || _busy || old == null) return;
    setState(() => _busy = true);
    try {
      final current = await widget.store.load(widget.payslipId);
      if (!mounted) return;
      setState(() {
        _snapshot = current;
        _pending = false;
        _acknowledged = false;
        _message = !old.sameOriginal(current)
            ? '元の記載内容が変わりました。前の確認は再送しません。新しい内容を原本と照合してください。'
            : current.status == 'confirmed'
                ? '現在は本人確認済みです。今回の操作で保存されたかは確定できません。閉じると累計を再読込します。'
                : '現在は未確認です。今回の保存結果は不明のため自動再送しません。再度、原本との照合が必要です。';
      });
    } catch (_) {
      if (mounted) setState(() => _message = '照合できませんでした。再送せず時間を置いて照合してください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOriginal() async {
    final row = _snapshot;
    if (row == null || _busy || _pending) return;
    setState(() => _busy = true);
    try {
      final uri = await widget.store.originalPdf(row);
      if (!widget.store.isCurrentOwner || !mounted) return;
      final opened = await (widget.openPdf?.call(uri) ??
          launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!opened) throw StateError('Not opened');
    } catch (_) {
      if (mounted) setState(() => _message = '元PDFを開けませんでした。お手元の原本でも照合できます。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static const otherLabels = {
    'base_salary': '基本給',
    'fixed_overtime': '固定残業手当',
    'overtime': '残業手当',
    'allowance': '手当',
    'commuting': '通勤手当',
    'work_days': '勤務日数',
    'overtime_hours': '時間外時間',
    'employees_pension_insurance': '厚生年金（別名）',
  };
  Widget _originalItems(String title, Object? raw) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          if (raw is! Map || raw.isEmpty) const Text('記載項目未取得'),
          if (raw is Map)
            for (final entry in raw.entries)
              Text(
                  '${AssetPayrollDeductionsCard.labels[entry.key] ?? otherLabels[entry.key] ?? 'その他（${entry.key}）'}：${entry.value ?? '未取得'}',),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final row = _snapshot;
    final projection = row?.projection;
    final active = widget.store.isCurrentOwner;
    final enabled = active && !_busy && !_loading && !_pending;
    return AlertDialog(
      title: const Text('給与明細の記載内容を確認'),
      scrollable: true,
      content: SizedBox(
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!active)
              const Text('利用者が切り替わりました。明細を開き直してください。')
            else ...[
              if (_loading) const LinearProgressIndicator(),
              if (row != null && projection != null) ...[
                Text(
                    '${row.raw['pay_date']} 支給／${row.raw['company_name'] ?? ''}',),
                Text(row.status == 'confirmed'
                    ? '記載済み値は本人確認済み'
                    : row.unreviewed
                        ? '取得済み・本人未確認'
                        : '確認保存の対象外です',),
                Text(
                    '総支給：${row.raw['gross_amount']}円／手取り：${row.raw['net_amount']}円',),
                Text('課税対象額：${row.raw['taxable_amount'] ?? '未取得'}'),
                _originalItems('控除の取込値（変更しません）', row.raw['deductions']),
                _originalItems('支給内訳の取込値（変更しません）', row.raw['earnings']),
                _originalItems('勤怠の取込値（変更しません）', row.raw['attendance']),
                Text(
                    '税金合計：${AssetPayrollDeductionsCard.amount(projection.taxTotalYen)}',),
                Text(
                    '社会保険合計：${AssetPayrollDeductionsCard.amount(projection.socialTotalYen)}',),
                Text('未分類控除：${projection.unclassified.length}項目'),
                Text(
                    '総支給−手取りと記載済み控除小計との差：${AssetPayrollDeductionsCard.amount(projection.unidentifiedDifferenceYen)}',),
                const Text(
                    '差額は未取得・未分類項目などが原因の可能性があります。差が0円でも全項目取得済みとは限りません。欠落は0円として保存・集計しません。',),
                if (row.blockingReason != null) Text(row.blockingReason!),
                TextButton(
                    onPressed: enabled ? _openOriginal : null,
                    child: const Text('保存済みの元PDFを開く'),),
                const Text('原本の閲覧は本人限定Storageから行います。PDFや記載内容を外部AIへ送りません。'),
                if (_pending) const Text('表示は保存前に取得した内容です。現在状態を照合してください。'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _acknowledged,
                  onChanged: enabled && row.blockingReason == null
                      ? (value) =>
                          setState(() => _acknowledged = value ?? false)
                      : null,
                  title: const Text(
                      '表示された取込内容を元の給与明細と照合しました。未取得項目を0円と確認するものではありません。',),
                ),
              ],
              if (_message != null) Text(_message!),
              if (_pending)
                TextButton(
                    onPressed: _busy ? null : _reconcile,
                    child: const Text('確認保存の現在状態を照合'),),
              if (row == null && !_loading)
                TextButton(
                    onPressed: _busy ? null : _read,
                    child: const Text('明細を再取得'),),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('閉じる'),),
        FilledButton(
          onPressed: enabled &&
                  row?.blockingReason == null &&
                  row != null &&
                  _acknowledged
              ? _save
              : null,
          child: const Text('記載内容を本人確認済みにする'),
        ),
      ],
    );
  }
}
