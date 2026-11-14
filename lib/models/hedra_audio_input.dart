import 'dart:convert';
import 'dart:typed_data';

const int hedraTtsMaxCharacters = 450;
const int hedraAudioFileMaxBytes = 4 * 1024 * 1024;

enum HedraAudioInputMode { file, textToSpeech }

extension HedraAudioInputModeApi on HedraAudioInputMode {
  String get apiValue => switch (this) {
        HedraAudioInputMode.file => 'file',
        HedraAudioInputMode.textToSpeech => 'tts',
      };
}

class HedraAudioFile {
  const HedraAudioFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

String? validateHedraTtsText(String value) {
  final text = value.trim();
  if (text.isEmpty) return '読み上げテキストを入力してください。';
  if (text.length > hedraTtsMaxCharacters) {
    return '読み上げテキストは$hedraTtsMaxCharacters文字以内で入力してください。';
  }
  return null;
}

String? validateHedraAudioFile(HedraAudioFile? file) {
  if (file == null) return '音声ファイルを選択してください。';
  if (file.bytes.isEmpty) return '空の音声ファイルは使用できません。';
  if (file.bytes.length > hedraAudioFileMaxBytes) {
    return '音声ファイルは4MB以下にしてください。';
  }
  final extension = file.name.split('.').last.toLowerCase();
  if (!const {'mp3', 'wav', 'm4a'}.contains(extension)) {
    return 'MP3、WAV、M4Aのいずれかを選択してください。';
  }
  return null;
}

Map<String, Object> buildHedraAudioInputPayload({
  required HedraAudioInputMode mode,
  HedraAudioFile? file,
  String text = '',
  String voice = 'female_narrator',
  double stability = 0.5,
  double speed = 1.0,
}) {
  if (mode == HedraAudioInputMode.file) {
    final error = validateHedraAudioFile(file);
    if (error != null) throw ArgumentError(error);
    return <String, Object>{
      'mode': mode.apiValue,
      'fileName': file!.name,
      'mimeType': file.mimeType,
      'dataBase64': base64Encode(file.bytes),
    };
  }

  final error = validateHedraTtsText(text);
  if (error != null) throw ArgumentError(error);
  if (stability < 0 || stability > 1) {
    throw ArgumentError('stability must be between 0 and 1');
  }
  if (speed < 0.7 || speed > 1.2) {
    throw ArgumentError('speed must be between 0.7 and 1.2');
  }
  return <String, Object>{
    'mode': mode.apiValue,
    'text': text.trim(),
    'voice': voice,
    'stability': stability,
    'speed': speed,
  };
}
