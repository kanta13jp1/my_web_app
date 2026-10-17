import 'package:flutter/material.dart';

import '../services/echo_pump_audio.dart';

class EchoPumpAudioControls extends StatelessWidget {
  const EchoPumpAudioControls({super.key, required this.audio});

  final EchoPumpAudio audio;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Material(
        color: const Color(0xFF0A161A),
        child: SafeArea(
          top: false,
          child: AnimatedBuilder(
            animation: audio,
            builder: (context, child) {
              final toggle = TextButton.icon(
                key: const Key('echo-audio-toggle'),
                onPressed: () => audio.setEnabled(!audio.enabled),
                icon: Icon(audio.enabled ? Icons.volume_up : Icons.volume_off),
                label: Text(audio.enabled ? '音をOFF' : '音をON'),
              );
              final volume = Slider(
                key: const Key('echo-audio-volume'),
                value: audio.volume,
                divisions: 10,
                label: '${(audio.volume * 100).round()}%',
                semanticFormatterCallback: (value) =>
                    'BGM・SEの音量 ${(value * 100).round()}パーセント',
                onChanged: audio.setVolume,
              );
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 500 ||
                                MediaQuery.textScalerOf(context).scale(14) > 20;
                            final label = Text(
                              'BGM・SE / 音量 ${(audio.volume * 100).round()}%',
                            );
                            if (compact) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      toggle,
                                      const Spacer(),
                                      Flexible(child: label),
                                    ],
                                  ),
                                  volume,
                                ],
                              );
                            }
                            return Row(
                              children: [toggle, label, Expanded(child: volume)],
                            );
                          },
                        ),
                        if (audio.error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(audio.error!, maxLines: 2),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
