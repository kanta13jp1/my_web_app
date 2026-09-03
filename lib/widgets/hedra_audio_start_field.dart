import 'package:flutter/material.dart';

import '../models/hedra_audio_start.dart';

class HedraAudioStartField extends StatelessWidget {
  const HedraAudioStartField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const Key('hedra-audio-start-ms-field'),
      initialValue: value,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validateHedraAudioStartMs,
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: '音声開始オフセット（ミリ秒）',
        helperText: '負値は冒頭に無音を追加、正値は音声冒頭をクロップします。'
            '範囲は-30000〜30000 msで、総再生時間もその分だけ増減します。',
        border: OutlineInputBorder(),
      ),
    );
  }
}
