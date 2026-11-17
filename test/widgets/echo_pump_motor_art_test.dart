import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/widgets/echo_pump_motor_art.dart';

class _MissingPumpBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('missing $key');
}

class _DelayedPumpBundle extends CachingAssetBundle {
  final requested = Completer<void>();
  final image = Completer<ByteData>();

  @override
  Future<ByteData> load(String key) {
    if (key == 'assets/echo_pump/pump_idle.png') {
      if (!requested.isCompleted) requested.complete();
      return image.future;
    }
    return rootBundle.load(key);
  }
}

Future<void> _finishImageLoad(
  WidgetTester tester, {
  bool expectFailure = false,
}) async {
  final image = tester.widget<Image>(find.byType(Image));
  final context = tester.element(find.byType(EchoPumpMotorArt));
  final errors = <Object>[];
  await tester.runAsync(() async {
    await precacheImage(
      image.image,
      context,
      onError: (error, stack) => errors.add(error),
    ).timeout(const Duration(seconds: 10));
  });
  expect(tester.takeException(), isNull);
  expect(errors, expectFailure ? isNotEmpty : isEmpty);
  await tester.pump();
}

void main() {
  testWidgets('pump image follows repaired and powered facts', (tester) async {
    Future<void> show(bool repaired, bool powered, String expected) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EchoPumpMotorArt(repaired: repaired, powered: powered),
        ),
      );
      final image = tester.widget<Image>(
        find.byKey(ValueKey('echo-pump-motor-$expected')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/echo_pump/pump_$expected.png',
      );
      await _finishImageLoad(tester);
      expect(find.byKey(const Key('echo-pump-motor-surface')), findsOneWidget);
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(tester.takeException(), isNull);
    }

    await show(false, false, 'fault');
    await show(false, true, 'fault');
    await show(true, false, 'idle');
    await show(true, true, 'live');
    await show(true, false, 'idle');
  });

  testWidgets('pending image keeps schematic until its first decoded frame',
      (tester) async {
    final bundle = _DelayedPumpBundle();
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: const Stack(
            children: [
              Text('underlying schematic'),
              EchoPumpMotorArt(repaired: true, powered: false),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await bundle.requested.future.timeout(const Duration(seconds: 10));
    });
    expect(tester.takeException(), isNull);
    expect(find.text('underlying schematic'), findsOneWidget);
    expect(find.byKey(const Key('echo-pump-motor-surface')), findsNothing);
    await tester.runAsync(() async {
      bundle.image.complete(
        await rootBundle.load('assets/echo_pump/pump_idle.png'),
      );
    });
    await _finishImageLoad(tester);
    expect(find.byKey(const Key('echo-pump-motor-surface')), findsOneWidget);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed pump image leaves the underlying schematic available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MissingPumpBundle(),
          child: const Stack(
            children: [
              Text('underlying schematic'),
              EchoPumpMotorArt(repaired: true, powered: true),
            ],
          ),
        ),
      ),
    );
    await _finishImageLoad(tester, expectFailure: true);
    expect(find.text('underlying schematic'), findsOneWidget);
    expect(find.byKey(const Key('echo-pump-motor-surface')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
