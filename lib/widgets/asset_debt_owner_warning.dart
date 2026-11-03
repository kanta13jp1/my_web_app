import 'package:flutter/material.dart';

/// This local override has no established owner in the current data model.
class AssetDebtOwnerWarning extends StatelessWidget {
  const AssetDebtOwnerWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '設定の所有者は未確認です',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
