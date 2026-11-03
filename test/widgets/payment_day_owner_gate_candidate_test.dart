import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/payment_day_owner_gate_candidate.dart';

void main() {
  testWidgets('unverified never builds the previous owner value or editor',
      (tester) async {
    var calls = 0;
    var edits = 0;
    Widget screen(PaymentDayOwnerGateStatus status) => MaterialApp(
          home: Scaffold(
            body: PaymentDayOwnerGateCandidate(
              status: status,
              verifiedBuilder: (_) {
                calls++;
                return ElevatedButton(
                  onPressed: () => edits++,
                  child: const Text('前の所有者の架空支払日 27日'),
                );
              },
            ),
          ),
        );

    await tester.pumpWidget(screen(PaymentDayOwnerGateStatus.unverified));
    expect(calls, 0);
    expect(find.textContaining('27日'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.textContaining('表示と変更を保留'), findsOneWidget);

    await tester.pumpWidget(screen(PaymentDayOwnerGateStatus.verified));
    expect(calls, greaterThan(0));
    final verifiedCalls = calls;
    expect(find.textContaining('27日'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    expect(edits, 1);

    await tester.pumpWidget(screen(PaymentDayOwnerGateStatus.unverified));
    expect(calls, verifiedCalls);
    expect(find.textContaining('27日'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(edits, 1);
  });

  testWidgets('unconfirmed writes never present a saved result', (tester) async {
    for (final status in [
      PaymentDayOwnerGateStatus.verifying,
      PaymentDayOwnerGateStatus.writeUncertain,
      PaymentDayOwnerGateStatus.writeRejected,
    ]) {
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PaymentDayOwnerGateCandidate(
            status: status,
            verifiedBuilder: (_) {
              calls++;
              return const Text('保存済み 27日');
            },
          ),
        ),
      ),);
      expect(calls, 0);
      expect(find.textContaining('保存済み'), findsNothing);
      expect(find.textContaining('27日'), findsNothing);
      expect(find.byType(Text), findsOneWidget);
    }
    expect(find.textContaining('同期は拒否'), findsOneWidget);
    expect(find.textContaining('保存状況を確認できない'), findsOneWidget);
  });

  testWidgets('default is fail closed', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: PaymentDayOwnerGateCandidate(
        verifiedBuilder: (_) {
          calls++;
          return const Text('架空値 27日');
        },
      ),
    ),);
    expect(calls, 0);
    expect(find.textContaining('架空値'), findsNothing);
    expect(find.textContaining('所有者を確認できません'), findsOneWidget);
  });
}
