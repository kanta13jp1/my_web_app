import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/widgets/asset_reflection_day_badge.dart';
import 'package:my_web_app/widgets/asset_unreconciled_expense_badge.dart';

const _kinds = {
  AssetReflectionKind.dining,
  AssetReflectionKind.drinkingOut,
  AssetReflectionKind.alcoholPurchase,
  AssetReflectionKind.reading,
  AssetReflectionKind.tobaccoPurchase,
};
const _labels = '外食\n外飲み\n酒購入\n読書\nたばこ購入';

Widget _app(double scale, {required bool preserve}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: Column(
              children: [
                AssetReflectionDayBadge(
                  kinds: _kinds,
                  preserveTextScale: preserve,
                ),
                AssetUnreconciledExpenseBadge(preserveTextScale: preserve),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('expanded labels retain the user text scale', (tester) async {
    await tester.pumpWidget(_app(1, preserve: true));
    final normalHeight = tester.getSize(find.text(_labels)).height;
    final normalUnknownHeight = tester.getSize(find.text('不明')).height;
    await tester.pumpWidget(_app(2, preserve: true));
    expect(find.byType(FittedBox), findsNothing);
    expect(
      tester.getSize(find.text(_labels)).height,
      greaterThan(normalHeight * 1.7),
    );
    expect(find.text('不明'), findsOneWidget);
    expect(
      tester.getSize(find.text('不明')).height,
      greaterThan(normalUnknownHeight * 1.7),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('default badges keep the existing scale-down layout',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AssetReflectionDayBadge(kinds: _kinds),
              AssetUnreconciledExpenseBadge(),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(FittedBox), findsNWidgets(2));
    expect(find.text(_labels), findsOneWidget);
    expect(find.text('不明'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
