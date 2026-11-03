import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/asset_debt_owner_warning.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('warning remains readable at 140px and 200% in $brightness', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    key: const Key('payment-day-width'),
                    width: 140,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('manual'),
                        const AssetDebtOwnerWarning(),
                        DropdownButton<int>(
                          value: 5,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 5, child: Text('5')),
                          ],
                          onChanged: (_) {},
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        const notice = '設定の所有者は未確認です';
        expect(
          tester.getSize(find.byKey(const Key('payment-day-width'))).width,
          140,
        );
        expect(find.text(notice), findsOneWidget);
        expect(find.bySemanticsLabel(notice), findsOneWidget);
        final text = tester.widget<Text>(find.text(notice));
        final context = tester.element(find.text(notice));
        expect(text.style!.color, Theme.of(context).colorScheme.onSurface);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
