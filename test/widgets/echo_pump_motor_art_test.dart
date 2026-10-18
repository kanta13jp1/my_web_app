import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_web_app/widgets/echo_pump_motor_art.dart';

class _MissingPumpBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => throw StateError('missing $key');
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
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await show(false, false, 'fault');
    await show(false, true, 'fault');
    await show(true, false, 'idle');
    await show(true, true, 'live');
    await show(true, false, 'idle');
  });

  testWidgets('failed pump image leaves the underlying schematic available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DefaultAssetBundle(
          bundle: _MissingPumpBundle(),
          child: const Stack(
            children: [
              Text('既存の設備図'),
              EchoPumpMotorArt(repaired: true, powered: true),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('既存の設備図'), findsOneWidget);
    expect(find.byKey(const Key('echo-pump-motor-surface')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
