import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/pages/real_world_danshari_page.dart';

// --- 1. ImagePickerのみモック化する ---
// OSのアルバム画面は自動操作できないため、「画像が選ばれたこと」にします。
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
    // テスト用の1x1ピクセルの透明PNG画像データ
    final Uint8List bytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    // 本物の画像ファイルが選ばれたように振る舞う
    return XFile.fromData(bytes, name: 'test_image.png');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('結合テスト: 実機でSupabase APIを叩いて断捨離判定を行う', (WidgetTester tester) async {
    // --- 2. 初期設定（本物のSupabaseを初期化） ---
    // すでにmain.dart等で初期化されている場合はスキップ可ですが、
    // テスト独立性を保つためここで初期化・ログインすることをお勧めします。
    
    const supabaseUrl = 'YOUR_SUPABASE_URL'; // ★実際のURLを入れてください
    const supabaseKey = 'YOUR_SUPABASE_ANON_KEY'; // ★実際のAnon Keyを入れてください
    
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (_) {
      // 既に初期化済みの場合は無視
    }

    final supabase = Supabase.instance.client;

    // テスト用ユーザーでログイン（APIを叩くため必須）
    // ★事前にAuthentication > Usersで作成したテスト用アカウントを使ってください
    await supabase.auth.signInWithPassword(
      email: 'test@example.com', 
      password: 'password123',
    );

    // --- 3. アプリ（ページ）を起動 ---
    // ImagePickerだけモックを注入し、Supabaseは本物を渡す
    final mockPicker = MockImagePicker();
    
    await tester.pumpWidget(MaterialApp(
      home: RealWorldDanshariPage(
        supabaseClient: supabase, // 本物
        imagePicker: mockPicker,  // モック
      ),
    ));
    await tester.pumpAndSettle();

    // --- 4. 操作シミュレーション ---
    
    // カメラアイコンを探してタップ
    final cameraButton = find.byIcon(Icons.camera_alt);
    expect(cameraButton, findsOneWidget);
    await tester.tap(cameraButton);
    await tester.pumpAndSettle(); // モック画像がセットされるのを待つ

    // 「判定する」ボタンを探してタップ
    final analyzeButton = find.text('AIに判定してもらう'); // ボタンの文言に合わせて修正してください
    expect(analyzeButton, findsOneWidget);
    await tester.tap(analyzeButton);

    // --- 5. 結果の検証（本物のAPI待ち） ---
    // 実際にネットワーク通信を行うため、少し長めに待ちます
    // APIが成功し、結果画面（例: ダイアログや特定のテキスト）が出るまで待機
    
    // 例: ローディング表示が出ることを確認
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 例: AIの判定結果が出るまで最大30秒待つ
    // 実際のレスポンスに含まれるであろうテキスト（"KEEP" または "DISCARD" など）を待ち受ける
    // 注: 本物のAIの回答は毎回変わる可能性がありますが、JSONのキーなどは共通のはずです
    await tester.pumpAndSettle(const Duration(seconds: 30));

    // エラーが出ていないことを確認（成功時になくなるWidgetや、表示されるWidgetで検証）
    // ここでは単純に「エラー」という文字が出ていないことを確認
    expect(find.text('エラーが発生しました'), findsNothing);
    
    // 何らかの結果テキストが表示されているはず
    // デバッグ用にウィジェットツリーを出力してみるのも有効です
    // debugDumpApp();
  });
}