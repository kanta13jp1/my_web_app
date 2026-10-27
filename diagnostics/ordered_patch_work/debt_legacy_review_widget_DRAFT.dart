// NON-SHIPPING UI DRAFT. No storage, auth, network, or production data access.
import 'package:flutter/material.dart';

class LegacyReviewRowDraft {
  const LegacyReviewRowDraft({required this.label, required this.day});
  final String label;
  final int? day;
}

class DebtLegacyReviewDraft extends StatelessWidget {
  const DebtLegacyReviewDraft({
    super.key,
    required this.destinationLabel,
    required this.rows,
    required this.onContinueLocal,
    this.onReviewCopy,
    this.copyAvailable = false,
  });

  final String? destinationLabel;
  final List<LegacyReviewRowDraft> rows;
  final VoidCallback onContinueLocal;
  // UI callback only: the caller must perform owner/epoch/digest/version
  // verification and an actual atomic copy. This widget does not authorize
  // remote delivery and cannot itself prove consent, identity or atomicity.
  final VoidCallback? onReviewCopy;
  final bool copyAvailable;

  @override
  Widget build(BuildContext context) {
    final destination = destinationLabel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('この端末の以前の支払日設定'),
            const SizedBox(height: 8),
            const Text('以前の設定はこの端末に残しています。'
                'ログインしていない間も、端末での編集を続けられます。'),
            const SizedBox(height: 8),
            if (destination == null)
              const Text('コピー先を確認するにはログインしてください。')
            else
              Text('コピー先として選択中: $destination'),
            const SizedBox(height: 8),
            for (final row in rows)
              Text('${row.label}: ${row.day == null ? '自動' : '${row.day}日'}'),
            const SizedBox(height: 8),
            const Text('コピー前に内容とコピー先を確認します。元の設定は残ります。'),
            if (!copyAvailable)
              const Text('いまは安全にコピーできないため、端末の設定を保持します。'),
            Wrap(spacing: 8, children: <Widget>[
              TextButton(onPressed: onContinueLocal, child: const Text('端末で続ける')),
              FilledButton(
                onPressed: copyAvailable && destination != null ? onReviewCopy : null,
                child: const Text('内容とコピー先を確認'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
