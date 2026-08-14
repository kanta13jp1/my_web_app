import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/voice_dubbing_service.dart';

void main() {
  test('Eleven v3 exposes at least 70 selectable languages', () {
    expect(voiceDubbingLanguages.length, greaterThanOrEqualTo(70));
    expect(
      voiceDubbingLanguages.map((language) => language.code).toSet().length,
      voiceDubbingLanguages.length,
    );
    expect(
      voiceDubbingModels.first.supports(
        voiceDubbingLanguages.firstWhere((language) => language.code == 'ja'),
      ),
      isTrue,
    );
  });

  test('model language lists match the advertised surfaces', () {
    final multilingual = voiceDubbingModels.firstWhere(
      (model) => model.id == 'eleven_multilingual_v2',
    );
    final flash = voiceDubbingModels.firstWhere(
      (model) => model.id == 'eleven_flash_v2_5',
    );
    final multilingualCount =
        voiceDubbingLanguages.where(multilingual.supports).length;
    final flashCount = voiceDubbingLanguages.where(flash.supports).length;

    expect(multilingualCount, 29);
    expect(flashCount, 32);
    expect(multilingual.maxCharacters, 30000);
    expect(flash.maxCharacters, 40000);
  });

  test('generation request carries voice expression controls', () {
    const voice = VoiceOption(
      id: 'voice-123456',
      name: 'Test Voice',
      category: 'premade',
      description: '',
      previewUrl: '',
      labels: {},
    );
    final request = VoiceDubbingRequest(
      text: 'こんにちは',
      fileName: 'article',
      model: voiceDubbingModels.first,
      language: voiceDubbingLanguages.firstWhere(
        (language) => language.code == 'ja',
      ),
      voice: voice,
      stability: 0.4,
      similarityBoost: 0.8,
      style: 0.3,
      speed: 1.1,
      speakerBoost: false,
    ).toJson();

    expect(request['action'], 'voice.dubbing.generate');
    expect(request['model_id'], 'eleven_v3');
    expect(request['language'], 'ja');
    expect(request['voice_id'], 'voice-123456');
    expect(request['voice_settings'], {
      'stability': 0.4,
      'similarity_boost': 0.8,
      'style': 0.3,
      'speed': 1.1,
      'use_speaker_boost': false,
    });
  });
}
