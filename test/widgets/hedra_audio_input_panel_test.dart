import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/hedra_audio_input.dart';
import 'package:my_web_app/widgets/hedra_audio_input_panel.dart';

void main() {
  testWidgets('switches between TTS settings and file selection',
      (tester) async {
    var mode = HedraAudioInputMode.textToSpeech;
    final controller = TextEditingController(text: '読み上げテキスト');
    addTearDown(controller.dispose);

    Widget buildPanel() => MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SingleChildScrollView(
                child: HedraAudioInputPanel(
                  mode: mode,
                  ttsController: controller,
                  voice: 'female_narrator',
                  stability: 0.5,
                  speed: 1,
                  file: null,
                  enabled: true,
                  onModeChanged: (value) => setState(() => mode = value),
                  onVoiceChanged: (_) {},
                  onStabilityChanged: (_) {},
                  onSpeedChanged: (_) {},
                  onPickFile: () {},
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(buildPanel());
    expect(find.byKey(const ValueKey('hedra-tts-text')), findsOneWidget);
    expect(find.text('女性ナレーター'), findsOneWidget);

    await tester.tap(find.text('音声ファイル選択'));
    await tester.pump();
    expect(find.byKey(const ValueKey('hedra-tts-text')), findsNothing);
    expect(find.text('MP3 / WAV / M4Aを選択'), findsOneWidget);
  });
}
