import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/utils/home_feature_request_failure.dart';
import 'package:my_web_app/widgets/home_feature_request_failure_snackbar.dart';

void main() {
  testWidgets(
    'all three HomeFeatureRequestFailure SnackBars hide raw exceptions and trigger retry',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const rawExceptionText = 'PostgrestException: internal_table_secret_42';

      for (final failure in HomeFeatureRequestFailure.values) {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: FilledButton(
                      onPressed: () {
                        try {
                          throw Exception(rawExceptionText);
                        } catch (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            buildHomeFeatureRequestFailureSnackBar(
                              failure: failure,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              onRetry: () => retried = true,
                            ),
                          );
                        }
                      },
                      child: const Text('Trigger'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger'));
        await tester.pumpAndSettle();

        expect(find.text(failure.userMessage), findsOneWidget);
        expect(find.text(failure.retryLabel), findsOneWidget);
        expect(find.textContaining(rawExceptionText), findsNothing);
        expect(find.textContaining('Exception'), findsNothing);

        await tester.tap(find.text(failure.retryLabel));
        await tester.pumpAndSettle();
        expect(retried, isTrue);
      }
    },
  );
}
