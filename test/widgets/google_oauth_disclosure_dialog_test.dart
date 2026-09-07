import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/google_oauth_disclosure_dialog.dart';

void main() {
  testWidgets('requires an explicit decision before Google OAuth', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/privacy': (_) => const Scaffold(body: Text('privacy route')),
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await showGoogleOAuthDisclosureDialog(
                  context: context,
                );
              },
              child: const Text('Googleで続ける'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Googleで続ける'));
    await tester.pumpAndSettle();

    expect(find.text('Googleに移動する前の確認'), findsOneWidget);
    expect(find.textContaining('表示名、メールアドレス'), findsOneWidget);
    expect(find.textContaining('Gmail、Googleカレンダー'), findsOneWidget);
    expect(find.textContaining('広告配信やデータ販売'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byKey(const Key('google-oauth-cancel')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('opens the public privacy route from the disclosure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/privacy': (_) => const Scaffold(body: Text('privacy route')),
        },
        home: const Scaffold(body: GoogleOAuthDisclosureDialog()),
      ),
    );

    await tester.tap(find.byKey(const Key('google-oauth-privacy-link')));
    await tester.pumpAndSettle();

    expect(find.text('privacy route'), findsOneWidget);
  });
}
