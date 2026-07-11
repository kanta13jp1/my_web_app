import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_share_button_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads visible bottom-right defaults', () async {
    const service = AiShareButtonPreferencesService();

    final preferences = await service.loadPreferences();

    expect(preferences.visible, isTrue);
    expect(preferences.position, AiShareButtonPosition.bottomRight);
    // 動画エンジンの既定は従来動作(Hedra プレゼンター動画)を維持する。
    expect(preferences.videoEngine, AiShareVideoEngine.presenter);
  });

  test('persists visibility and selected position', () async {
    const service = AiShareButtonPreferencesService();

    await service.savePreferences(
      const AiShareButtonPreferences(
        visible: false,
        position: AiShareButtonPosition.topLeft,
      ),
    );

    final preferences = await service.loadPreferences();

    expect(preferences.visible, isFalse);
    expect(preferences.position, AiShareButtonPosition.topLeft);
  });

  test('falls back to bottom-right when stored position is unknown', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ai_share_button_visible_v1': false,
      'ai_share_button_position_v1': 'center_screen',
    });
    const service = AiShareButtonPreferencesService();

    final preferences = await service.loadPreferences();

    expect(preferences.visible, isFalse);
    expect(preferences.position, AiShareButtonPosition.bottomRight);
  });

  test('persists selected video engine', () async {
    const service = AiShareButtonPreferencesService();

    await service.saveVideoEngine(AiShareVideoEngine.cinematic);

    final preferences = await service.loadPreferences();

    expect(preferences.videoEngine, AiShareVideoEngine.cinematic);
    // 他の設定は既定のまま保たれる。
    expect(preferences.visible, isTrue);
    expect(preferences.position, AiShareButtonPosition.bottomRight);
  });

  test('falls back to presenter when stored video engine is unknown',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ai_share_video_engine_v1': 'hologram',
    });
    const service = AiShareButtonPreferencesService();

    final preferences = await service.loadPreferences();

    expect(preferences.videoEngine, AiShareVideoEngine.presenter);
  });
}
