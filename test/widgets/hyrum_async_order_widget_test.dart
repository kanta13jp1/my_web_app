import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/hyrum_order_jitter_helper.dart';

class _AsyncOrderTestHarness extends StatefulWidget {
  const _AsyncOrderTestHarness({
    required this.profileFuture,
    required this.summaryFuture,
    required this.alertsFuture,
  });

  final Future<String> profileFuture;
  final Future<String> summaryFuture;
  final Future<String> alertsFuture;

  @override
  State<_AsyncOrderTestHarness> createState() => _AsyncOrderTestHarnessState();
}

class _AsyncOrderTestHarnessState extends State<_AsyncOrderTestHarness> {
  String? _profile;
  String? _summary;
  String? _alerts;

  @override
  void initState() {
    super.initState();
    widget.profileFuture.then((String value) {
      if (mounted) {
        setState(() => _profile = value);
      }
    });
    widget.summaryFuture.then((String value) {
      if (mounted) {
        setState(() => _summary = value);
      }
    });
    widget.alertsFuture.then((String value) {
      if (mounted) {
        setState(() => _alerts = value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              Chip(label: Text(_profile ?? 'loading-profile')),
              Chip(label: Text(_summary ?? 'loading-summary')),
              Chip(label: Text(_alerts ?? 'loading-alerts')),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'renders cleanly across varying async completion orders at 2.0x textScale',
    (WidgetTester tester) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        errors.add(details);
      };

      try {
        for (final seed in <int>[11, 47]) {
          final profile = Completer<String>();
          final summary = Completer<String>();
          final alerts = Completer<String>();

          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                size: Size(375, 667),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                home: _AsyncOrderTestHarness(
                  profileFuture: profile.future,
                  summaryFuture: summary.future,
                  alertsFuture: alerts.future,
                ),
              ),
            ),
          );

          final steps = permuteWithSeed<void Function()>(
            <void Function()>[
              () => profile.complete('Profile Ready'),
              () => summary.complete('Summary Ready'),
              () => alerts.complete('Alerts Ready'),
            ],
            seed: seed,
          );

          for (final completeStep in steps) {
            completeStep();
            await tester.pump();
          }

          expect(find.text('Profile Ready'), findsOneWidget);
          expect(find.text('Summary Ready'), findsOneWidget);
          expect(find.text('Alerts Ready'), findsOneWidget);
        }
        expect(errors, isEmpty);
      } finally {
        FlutterError.onError = oldOnError;
      }
    },
  );
}
