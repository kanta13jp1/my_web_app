import 'package:flutter/widgets.dart';

/// Avoid presenting provisional unpaid rows as reminders during restoration.
class AssetPaymentReminderGate extends StatelessWidget {
  final bool ready;
  final bool loadFailed;
  final WidgetBuilder builder;

  const AssetPaymentReminderGate({
    super.key,
    required this.ready,
    required this.loadFailed,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (loadFailed) {
      return const Text('支払設定を読み取れないため、リマインダー候補は未判定です。');
    }
    if (!ready) {
      return const Text('支払設定を確認中です。リマインダー候補はまだ判定していません。');
    }
    return builder(context);
  }
}
