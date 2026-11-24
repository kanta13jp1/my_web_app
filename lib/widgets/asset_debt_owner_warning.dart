import 'package:flutter/material.dart';

/// The ownership of this setting is not established by the current model.
class AssetDebtOwnerWarning extends StatelessWidget {
  const AssetDebtOwnerWarning({super.key, this.legacyNameRetained = false});

  final bool legacyNameRetained;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('設定の所有者は未確認です', style: style),
          if (legacyNameRetained)
            Text('旧名の設定が残るため、この欄では解除できません。別の日付を選んでも旧名は残ります。', style: style),
        ],
      ),
    );
  }
}
