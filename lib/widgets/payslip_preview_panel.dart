import 'package:flutter/material.dart';

enum PayslipPreviewField {
  payDate('支給日'),
  company('会社名'),
  gross('総支給額（円）'),
  net('手取り額（円）'),
  taxable('課税対象額（円）'),
  insurance('社会保険料合計（円）');

  const PayslipPreviewField(this.label);

  final String label;
}

class PayslipPreview {
  const PayslipPreview._(this.values, this.hasWarnings);

  final Map<PayslipPreviewField, String?> values;
  final bool hasWarnings;

  static bool validDate(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return false;
    }
    final date = DateTime.tryParse('${text}T00:00:00Z');
    return date != null && date.toIso8601String().split('T').first == text;
  }

  static String? _yen(Object? value) {
    if (value is! num || !value.isFinite || value < 0 ||
        value > 9007199254740991 || value != value.truncate()) {
      return null;
    }
    return value.toInt().toString();
  }

  static PayslipPreview? fromResponse(
    Object? response, {
    required String owner,
    required String storagePath,
  }) {
    if (response is! Map<Object?, Object?> ||
        response['success'] != true ||
        response['status'] != 'preview_only' ||
        response['persisted'] != false ||
        owner.isEmpty ||
        !storagePath.startsWith('$owner/')) {
      return null;
    }
    final row = response['payslip'];
    final parsed = response['parsed'];
    if (row is! Map<Object?, Object?> || parsed is! Map<Object?, Object?> ||
        row['user_id'] != owner ||
        row['source_pdf_path'] != storagePath ||
        row['review_status'] != 'needs_review') {
      return null;
    }
    final date = parsed['pay_date'];
    final net = _yen(parsed['net_amount']);
    if (date is! String || !validDate(date) || net == null || net == '0') {
      return null;
    }
    final gross = _yen(parsed['gross_amount']);
    final company = parsed['company_name'];
    final warnings = response['warnings'];
    return PayslipPreview._(
      Map.unmodifiable({
        PayslipPreviewField.payDate: date,
        PayslipPreviewField.company: company is String &&
                company.trim().isNotEmpty && company.trim() != 'unknown'
            ? company.trim()
            : null,
        PayslipPreviewField.net: net,
        PayslipPreviewField.gross: gross == '0' ? null : gross,
        PayslipPreviewField.taxable: _yen(parsed['taxable_amount']),
        PayslipPreviewField.insurance: _yen(parsed['social_insurance_total']),
      }),
      warnings is List && warnings.isNotEmpty,
    );
  }
}

class PayslipPreviewPanel extends StatefulWidget {
  const PayslipPreviewPanel({
    super.key,
    required this.preview,
    required this.onDismiss,
  });

  final PayslipPreview preview;
  final VoidCallback onDismiss;

  @override
  State<PayslipPreviewPanel> createState() => _PayslipPreviewPanelState();
}

class _PayslipPreviewPanelState extends State<PayslipPreviewPanel> {
  final _form = GlobalKey<FormState>();
  final _drafts = <PayslipPreviewField, String>{};
  bool _editing = false;

  String? _validate(PayslipPreviewField field, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || field == PayslipPreviewField.company) {
      return null;
    }
    if (field == PayslipPreviewField.payDate) {
      return PayslipPreview.validDate(value) ? null : '日付をYYYY-MM-DDで入力してください。';
    }
    final amount = int.tryParse(value);
    if (!RegExp(r'^\d+$').hasMatch(value) || amount == null ||
        amount > 9007199254740991 ||
        (field == PayslipPreviewField.net && amount == 0)) {
      return field == PayslipPreviewField.net
          ? '手取り額は1円以上の整数で入力してください。'
          : '金額は0円以上の整数で入力してください。';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('給与明細の解析プレビュー', style: Theme.of(context).textTheme.titleMedium),
              const Text('PDFは保管済みです。今回の解析結果・訂正候補は未登録です。'),
              const Text('このプレビューから給与明細を登録し、給与収入へ反映する操作は未提供です。閉じると画面内の訂正候補は消え、保管済みのPDFは残ります。'),
              const Text('主要6項目をPDFと照合してください。支給日はファイル名から補完される場合があります。'),
              if (widget.preview.hasWarnings)
                const Text('解析時に注意事項があります。各項目を原本で確認してください。'),
              for (final field in PayslipPreviewField.values) ...[
                const SizedBox(height: 8),
                Text('${field.label}　解析値　${widget.preview.values[field] ?? '未読取・要確認'}'),
                if (_editing)
                  TextFormField(
                    key: ValueKey(field),
                    initialValue: _drafts[field],
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    enableInteractiveSelection: false,
                    decoration: InputDecoration(labelText: '${field.label}の訂正候補'),
                    validator: (value) => _validate(field, value),
                    onChanged: (value) => _drafts[field] = value.trim(),
                  )
                else if ((_drafts[field] ?? '').isNotEmpty)
                  Text('訂正候補　${_drafts[field]}'),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () {
                      if (_editing && _form.currentState?.validate() != true) {
                        return;
                      }
                      setState(() => _editing = !_editing);
                    },
                    child: Text(_editing ? '訂正候補を見直す' : '訂正候補を入力'),
                  ),
                  TextButton(onPressed: widget.onDismiss, child: const Text('入力を破棄して閉じる')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
