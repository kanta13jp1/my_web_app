import 'package:flutter/material.dart';

/// ホームの「CEO Eval」承認導線カード。
class HomeEvalApprovalCard extends StatelessWidget {
  const HomeEvalApprovalCard({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fact_check_outlined,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: const Text(
          'CEO Eval',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('AI役員から届いた選択肢を承認・否認'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
