import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_liability_payment_reminder_service.dart';
import 'package:my_web_app/services/asset_liability_planning_service.dart';
import 'package:my_web_app/widgets/asset_payment_reminder_gate.dart';

void main() {
  testWidgets(
    'restoration never exposes a provisional unpaid reminder',
    (tester) async {
      const planner = AssetLiabilityPlanningService();
      const reminders = AssetLiabilityPaymentReminderService();
      final now = DateTime(2026, 5, 15);
      var restored = false;
      var builds = 0;
      Widget screen({required bool ready, bool failed = false}) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: AssetPaymentReminderGate(
            ready: ready,
            loadFailed: failed,
            builder: (_) {
              builds++;
              final workbook = planner.buildWorkbook(
                latestSnapshot: const {'財布': 10000.0, 'モビット': -100000.0},
                baseDate: now,
                monthlyPaymentOverrides: const {'モビット': 10000.0},
                paidAccountNames: restored ? const {'モビット'} : const {},
              );
              final candidates = reminders.buildCandidates(
                workbook: workbook,
                now: now,
              );
              return Text(
                candidates.isEmpty ? '候補なし' : candidates.single.title,
              );
            },
          ),
        );
      }

      await tester.pumpWidget(screen(ready: false));
      expect(builds, 0);
      expect(find.textContaining('確認中'), findsOneWidget);
      expect(find.textContaining('本日支払日'), findsNothing);
      restored = true;
      await tester.pumpWidget(screen(ready: true));
      expect(find.text('候補なし'), findsOneWidget);
      restored = false;
      await tester.pumpWidget(screen(ready: false));
      expect(find.text('候補なし'), findsNothing);
      expect(find.textContaining('本日支払日'), findsNothing);
      await tester.pumpWidget(screen(ready: true));
      expect(find.textContaining('本日支払日'), findsOneWidget);
      await tester.pumpWidget(screen(ready: false, failed: true));
      expect(find.textContaining('未判定'), findsOneWidget);
      expect(find.textContaining('本日支払日'), findsNothing);
    },
  );
}
