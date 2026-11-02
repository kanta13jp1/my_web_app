import 'package:flutter/material.dart';

import '../../../../services/paddle_invoice_access.dart';

class PaddleSandboxInvoiceAccessCard extends StatefulWidget {
  const PaddleSandboxInvoiceAccessCard({
    super.key,
    required this.config,
    required this.launchPortal,
  });

  final PaddleInvoiceAccessConfig config;
  final PaddleInvoicePortalLauncher launchPortal;

  @override
  State<PaddleSandboxInvoiceAccessCard> createState() =>
      _PaddleSandboxInvoiceAccessCardState();
}

class _PaddleSandboxInvoiceAccessCardState
    extends State<PaddleSandboxInvoiceAccessCard> {
  bool _isOpening = false;
  String? _publicError;

  Future<void> _openPortal() async {
    final uri = widget.config.portalUri;
    if (uri == null || _isOpening) return;

    setState(() {
      _isOpening = true;
      _publicError = null;
    });
    try {
      if (!await widget.launchPortal(uri)) {
        throw const FormatException('Portal launcher returned false');
      }
    } catch (_) {
      debugPrint('Paddle sandbox customer portal launch failed.');
      if (mounted) {
        setState(() {
          _publicError = '請求書画面を開けませんでした。設定を確認して再試行してください。';
        });
      }
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validationMessage = widget.config.validationMessage;
    return Card(
      key: const Key('paddle_sandbox_invoice_access_card'),
      color: scheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined),
                Text(
                  'Paddle 請求書（インボイス）',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Chip(label: Text('SANDBOX ONLY')),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '請求書の発行元は、Merchant of Record（MoR）であるPaddleです。'
              '決済時に使ったメールアドレスで本人確認し、Paddle Customer Portalの'
              '取引履歴からPDFを取得できます。',
            ),
            const SizedBox(height: 10),
            const Text(
              '取得手順: メールアドレスを入力 → 届いたマジックリンクを開く → '
              'Payments（取引履歴）からDownload invoiceを選ぶ',
            ),
            const SizedBox(height: 10),
            const Text(
              'VAT / Tax IDの適用結果は請求先の国・地域と取引条件で変わります。'
              '決済画面の再計算後の税額を確認してください。',
            ),
            if (validationMessage != null || _publicError != null) ...[
              const SizedBox(height: 10),
              Text(
                _publicError ?? validationMessage!,
                key: const Key('paddle_sandbox_invoice_status'),
                style: TextStyle(color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('paddle_sandbox_invoice_button'),
              onPressed:
                  _isOpening || !widget.config.canOpen ? null : _openPortal,
              icon: _isOpening
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.open_in_new),
              label: const Text('Paddleで過去の請求書を開く'),
            ),
          ],
        ),
      ),
    );
  }
}
