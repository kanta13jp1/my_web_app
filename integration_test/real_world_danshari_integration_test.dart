import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart'; // 追加
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/pages/real_world_danshari_page.dart';
import 'package:my_web_app/services/theme_service.dart'; // 追加

import 'support/local_integration_config.dart';

// --- 1. ImagePickerのみモック化 ---
class MockImagePicker extends Mock implements ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    final Uint8List bytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    return XFile.fromData(bytes, name: 'test_image.png');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('結合テスト: 実機でSupabase APIを叩いて断捨離判定を行う',
      (WidgetTester tester) async {
    // Explicit, disposable local test configuration only. Never use live accounts.
    const enabled = bool.fromEnvironment('RUN_LOCAL_DANSHARI_INTEGRATION');
    const supabaseUrl = String.fromEnvironment('TEST_SUPABASE_URL');
    const supabaseKey = String.fromEnvironment('TEST_SUPABASE_PUBLISHABLE_KEY');
    const email = String.fromEnvironment('TEST_SUPABASE_EMAIL');
    const password = String.fromEnvironment('TEST_SUPABASE_PASSWORD');
    validateLocalIntegrationConfig(
      enabled: enabled,
      url: supabaseUrl,
      publishableKey: supabaseKey,
      email: email,
      password: password,
    );
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
    addTearDown(() => Supabase.instance.dispose());
    final supabase = Supabase.instance.client;
    final authResponse = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (authResponse.session == null) {
      fail('Supabaseへのログインに失敗しました。ユーザーが正しく作成されているか確認してください。');
    }

    final mockPicker = MockImagePicker();

    // --- 3. アプリ起動 (Providerでラップする) ---
    await tester.pumpWidget(
      // ★ ThemeServiceを提供するためにChangeNotifierProviderでラップ
      ChangeNotifierProvider<ThemeService>(
        create: (_) => ThemeService(),
        child: MaterialApp(
          home: RealWorldDanshariPage(
            supabaseClient: supabase,
            imagePicker: mockPicker,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // --- 4. 操作シミュレーション ---
    final cameraButton = find.byIcon(Icons.camera_alt); // カメラアイコンを探す
    if (cameraButton.evaluate().isNotEmpty) {
      await tester.tap(cameraButton);
    } else {
      // 万が一見つからない場合はアルバムアイコンを試す
      final galleryButton = find.byIcon(Icons.photo_library);
      await tester.tap(galleryButton);
    }
    await tester.pumpAndSettle();

    // --- 5. 判定と検証 ---
    // ここで自動的に通信が走る想定であれば待機
    // API呼び出し（30秒タイムアウト）
    // 通信中は CircularProgressIndicator が出ているはず
    // expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 30));

    // 結果の確認
    expect(find.textContaining('ときめきスコア'), findsOneWidget);
  });
}
