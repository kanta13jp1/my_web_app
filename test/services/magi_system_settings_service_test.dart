import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/magi_system_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads defaults and builds ai-assistant payload', () async {
    const service = MagiSystemSettingsService();

    final settings = await service.loadSettings();
    final payload = await service.buildAiAssistantPayload(
      baseBody: <String, dynamic>{
        'action': 'improve',
        'content': 'focus on the essential point',
      },
    );

    expect(settings.enabled, isTrue);
    expect(settings.melchiorModel, MagiSystemSettings.defaultMelchiorModel);
    expect(settings.balthasarModel, MagiSystemSettings.defaultBalthasarModel);
    expect(payload['useMagi'], isTrue);
    expect(payload['melchiorModel'], MagiSystemSettings.defaultMelchiorModel);
    expect(payload['balthasarModel'], MagiSystemSettings.defaultBalthasarModel);
    expect(payload['casperModel'], MagiSystemSettings.defaultCasperModel);
    expect(payload['synthesisModel'], MagiSystemSettings.defaultSynthesisModel);
  });

  test('persists enabled state and node model overrides', () async {
    const service = MagiSystemSettingsService();

    await service.saveEnabled(false);
    await service.saveNodeModel(MagiNodeRole.melchior, 'gpt-5.4');

    final settings = await service.loadSettings();
    final payload = await service.buildAiAssistantPayload(
      baseBody: <String, dynamic>{'action': 'summarize'},
    );

    expect(settings.enabled, isFalse);
    expect(settings.melchiorModel, 'gpt-5.4');
    expect(payload, containsPair('useMagi', false));
    expect(payload.containsKey('melchiorModel'), isFalse);
  });
}
