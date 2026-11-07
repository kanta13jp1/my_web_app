import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/hedra_audio_start_field.dart';

void main() {
  testWidgets('explains silence, cropping, and validates the safe range', (
    tester,
  ) async {
    var value = '0';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HedraAudioStartField(
            value: value,
            onChanged: (next) => value = next,
          ),
        ),
      ),
    );

    expect(find.text('音声開始オフセット（ミリ秒）'), findsOneWidget);
    expect(find.textContaining('負値は冒頭に無音を追加'), findsOneWidget);
    expect(find.textContaining('正値は音声冒頭をクロップ'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('hedra-audio-start-ms-field')),
      '30001',
    );
    await tester.pump();

    expect(value, '30001');
    expect(
      find.text('-30000〜30000 msの範囲で入力してください'),
      findsOneWidget,
    );
  });
}
