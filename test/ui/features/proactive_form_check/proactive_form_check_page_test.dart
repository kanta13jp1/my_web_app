import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/ui/features/proactive_form_check/data/proactive_form_validator.dart';
import 'package:my_web_app/ui/features/proactive_form_check/proactive_form_check_feature.dart';

void main() {
  const validator = RuleBasedProactiveFormValidator(
    simulatedLatency: Duration.zero,
  );

  testWidgets('送信前にエラーと解決策を示し、修正案をフォームへ反映する', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProactiveFormCheckFeature(
          validator: validator,
          debounceDuration: Duration.zero,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('proactive-title-field')),
      '夏の新商品キャンペーン',
    );
    await tester.enterText(
      find.byKey(const Key('proactive-email-field')),
      'invalid-address',
    );
    await tester.enterText(
      find.byKey(const Key('proactive-destinationUrl-field')),
      'example.com/campaign',
    );
    await tester.enterText(
      find.byKey(const Key('proactive-dailyBudget-field')),
      '3000',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('proactive-finding-email-format')),
      findsOneWidget,
    );
    expect(
      find.text('送信を妨げるエラー・通知先メールアドレス'),
      findsOneWidget,
    );
    expect(
      find.text('解決策: 「name@example.com」の形式で入力してください。'),
      findsOneWidget,
    );
    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('proactive-form-submit')),
    );
    expect(submitButton.onPressed, isNull);

    final applyUrl = find.byKey(const Key('apply-url-scheme'));
    await tester.ensureVisible(applyUrl);
    await tester.tap(applyUrl);
    await tester.pumpAndSettle();
    final urlField = tester.widget<TextField>(
      find.byKey(const Key('proactive-destinationUrl-field')),
    );
    expect(urlField.controller?.text, 'https://example.com/campaign');

    await tester.enterText(
      find.byKey(const Key('proactive-email-field')),
      'owner@example.com',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('proactive-finding-email-format')),
      findsNothing,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('proactive-form-submit')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('画面幅に応じて1列と2列を切り替える', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    tester.view.physicalSize = const Size(390, 1000);
    await tester.pumpWidget(
      const MaterialApp(
        home: ProactiveFormCheckFeature(
          validator: validator,
          debounceDuration: Duration.zero,
        ),
      ),
    );
    expect(
      find.byKey(const Key('proactive-form-check-narrow')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(find.byKey(const Key('proactive-form-check-wide')), findsOneWidget);
  });
}
