import 'package:flutter/material.dart';

/// Detached presentation experiment; this does not establish owner identity,
/// prevent persistence, stop network calls, or protect other consumers.
/// `verified` must never be derived from this widget or caller-supplied guesses.
enum PaymentDayOwnerGateStatus {
  unverified,
  verifying,
  writeUncertain,
  writeRejected,
  verified,
}

class PaymentDayOwnerGateCandidate extends StatelessWidget {
  const PaymentDayOwnerGateCandidate({
    super.key,
    this.status = PaymentDayOwnerGateStatus.unverified,
    required this.verifiedBuilder,
  });

  final PaymentDayOwnerGateStatus status;
  final WidgetBuilder verifiedBuilder;

  @override
  Widget build(BuildContext context) {
    if (status == PaymentDayOwnerGateStatus.verified) {
      return verifiedBuilder(context);
    }
    final text = switch (status) {
      PaymentDayOwnerGateStatus.verifying =>
        '支払日設定の所有者を確認しています。',
      PaymentDayOwnerGateStatus.writeUncertain =>
        '支払日設定の保存結果を確認できません。設定の変更を控え、復旧をお待ちください。',
      PaymentDayOwnerGateStatus.writeRejected =>
        'この端末からの支払日設定の同期は拒否されました。保存状況を確認できないため、復旧をお待ちください。',
      PaymentDayOwnerGateStatus.unverified ||
      PaymentDayOwnerGateStatus.verified =>
        '支払日設定の所有者を確認できません。設定の表示と変更を保留しています。ログイン状態を確認し、復旧をお待ちください。',
    };
    return Semantics(
      liveRegion: true,
      child: Text(text),
    );
  }
}
