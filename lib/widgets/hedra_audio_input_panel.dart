import 'package:flutter/material.dart';

import '../models/hedra_audio_input.dart';

class HedraAudioInputPanel extends StatelessWidget {
  const HedraAudioInputPanel({
    super.key,
    required this.mode,
    required this.ttsController,
    required this.voice,
    required this.stability,
    required this.speed,
    required this.file,
    required this.enabled,
    required this.onModeChanged,
    required this.onVoiceChanged,
    required this.onStabilityChanged,
    required this.onSpeedChanged,
    required this.onPickFile,
  });

  final HedraAudioInputMode mode;
  final TextEditingController ttsController;
  final String voice;
  final double stability;
  final double speed;
  final HedraAudioFile? file;
  final bool enabled;
  final ValueChanged<HedraAudioInputMode> onModeChanged;
  final ValueChanged<String> onVoiceChanged;
  final ValueChanged<double> onStabilityChanged;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '音声入力',
              style: TextStyle(fontWeight: FontWeight.bold, height: 1.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('音声ファイル選択'),
                  selected: mode == HedraAudioInputMode.file,
                  onSelected: enabled
                      ? (_) => onModeChanged(HedraAudioInputMode.file)
                      : null,
                ),
                ChoiceChip(
                  label: const Text('テキストから音声合成'),
                  selected: mode == HedraAudioInputMode.textToSpeech,
                  onSelected: enabled
                      ? (_) => onModeChanged(HedraAudioInputMode.textToSpeech)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mode == HedraAudioInputMode.file) ...[
              OutlinedButton.icon(
                onPressed: enabled ? onPickFile : null,
                icon: const Icon(Icons.audio_file_outlined),
                label: Text(file?.name ?? 'MP3 / WAV / M4Aを選択'),
              ),
              const SizedBox(height: 6),
              Text(
                file == null
                    ? '4MB以下。サーバーで検証後、保存せずHedraへ転送します。'
                    : '${(file!.bytes.length / 1024).ceil()} KB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              TextFormField(
                key: const ValueKey('hedra-tts-text'),
                controller: ttsController,
                enabled: enabled,
                minLines: 3,
                maxLines: 5,
                maxLength: hedraTtsMaxCharacters,
                decoration: const InputDecoration(
                  labelText: '読み上げテキスト',
                  hintText: '動画で話す内容を入力',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const ValueKey('hedra-tts-voice'),
                initialValue: voice,
                decoration: const InputDecoration(
                  labelText: '話者',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'female_narrator',
                    child: Text('女性ナレーター'),
                  ),
                  DropdownMenuItem(
                    value: 'male_narrator',
                    child: Text('男性ナレーター'),
                  ),
                ],
                onChanged: enabled
                    ? (value) {
                        if (value != null) onVoiceChanged(value);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              Text('安定性 ${stability.toStringAsFixed(2)}'),
              Slider(
                key: const ValueKey('hedra-tts-stability'),
                value: stability,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: enabled ? onStabilityChanged : null,
              ),
              Text('速度 ${speed.toStringAsFixed(2)}x'),
              Slider(
                key: const ValueKey('hedra-tts-speed'),
                value: speed,
                min: 0.7,
                max: 1.2,
                divisions: 10,
                onChanged: enabled ? onSpeedChanged : null,
              ),
              const Text(
                'Hedraの音声合成と動画生成を1回の操作で実行します。',
                style: TextStyle(fontSize: 12, height: 1.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
