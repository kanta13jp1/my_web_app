// ignore_for_file: argument_type_not_assignable
@TestOn('browser')

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:my_web_app/pages/real_world_danshari_page.dart';
import 'package:my_web_app/services/theme_service.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@GenerateMocks(
  [SupabaseClient, FunctionsClient, FunctionResponse, ThemeService],
)
import 'real_world_danshari_page_test.mocks.dart';

// --- 追加: 有効な1x1ピクセルのPNG画像データ ---
final _kTransparentImage = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class MockImagePickerPlatform extends ImagePickerPlatform {
  XFile? pickedFile;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions? options,
  }) async {
    return pickedFile;
  }
}

// 異常系テスト用のモック
class ErrorMockImagePickerPlatform extends ImagePickerPlatform {
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions? options,
  }) async {
    throw Exception('Picker Failed');
  }
}

void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockFunctionsClient mockFunctionsClient;
  late MockThemeService mockThemeService;
  late MockImagePickerPlatform mockImagePickerPlatform;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockFunctionsClient = MockFunctionsClient();
    mockThemeService = MockThemeService();
    mockImagePickerPlatform = MockImagePickerPlatform();

    when(mockSupabaseClient.functions).thenReturn(mockFunctionsClient);
    when(mockThemeService.isDarkMode).thenReturn(false);

    ImagePickerPlatform.instance = mockImagePickerPlatform;
  });

  Widget createTestWidget() {
    return ChangeNotifierProvider<ThemeService>.value(
      value: mockThemeService,
      child: MaterialApp(
        home: RealWorldDanshariPage(
          supabaseClient: mockSupabaseClient,
        ),
      ),
    );
  }

  testWidgets('初期表示: 説明文とボタンが表示されること', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    expect(find.text('リアル断捨離クエスト'), findsOneWidget);
    expect(find.textContaining('あなたの部屋にある'), findsOneWidget);
    expect(find.text('カメラで撮影'), findsOneWidget);
    expect(find.text('アルバムから選択'), findsOneWidget);
    expect(find.text('ここに写真が表示されます'), findsOneWidget);
  });

  testWidgets('画像選択キャンセル時は何も起こらないこと', (WidgetTester tester) async {
    mockImagePickerPlatform.pickedFile = null;

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('カメラで撮影'));
    await tester.pumpAndSettle();

    verifyNever(mockFunctionsClient.invoke(any, body: anyNamed('body')));
    expect(find.text('ここに写真が表示されます'), findsOneWidget);
  });

  testWidgets('正常系: 画像選択後、分析が成功し結果が表示されること (JSON Stringレスポンス)',
      (WidgetTester tester) async {
    // 修正: 有効な画像データを使用
    mockImagePickerPlatform.pickedFile = XFile.fromData(
      _kTransparentImage,
      name: 'test.jpg',
      mimeType: 'image/jpeg',
    );

    final successResponse = {
      'success': true,
      'result': {
        'decision': 'DISCARD',
        'item_name': '古いジャケット',
        'spark_joy_score': 30,
        'reason': 'ボロボロです',
        'witty_comment': 'タイムマシンがあれば...',
      },
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(jsonEncode(successResponse));

    when(
      mockFunctionsClient.invoke(
        'ai-assistant',
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('アルバムから選択'));

    // 画像描画の完了を待つ
    await tester.pump();

    // APIコールの完了を待つ
    await tester.pumpAndSettle();

    expect(find.text('古いジャケット'), findsOneWidget);
    expect(find.text(' 廃棄推奨 (DISCARD)'), findsOneWidget);
    expect(find.text('30 / 100'), findsOneWidget);
  });

  testWidgets('正常系: 画像選択後、分析が成功し結果が表示されること (Mapレスポンス)',
      (WidgetTester tester) async {
    // 修正: 有効な画像データを使用
    mockImagePickerPlatform.pickedFile = XFile.fromData(
      _kTransparentImage,
    );

    final successResponse = {
      'success': true,
      'result': {
        'decision': 'KEEP',
        'item_name': '大切な時計',
        'spark_joy_score': 90,
        'reason': '輝いています',
        'witty_comment': '素晴らしい！',
      },
    };
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(successResponse);

    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('カメラで撮影'));
    await tester.pump(); // 画像ロード待ち
    await tester.pumpAndSettle();

    expect(find.text('大切な時計'), findsOneWidget);
    expect(find.text(' 維持 (KEEP)'), findsOneWidget);
  });

  testWidgets('異常系: APIがエラー(success: false)を返した場合',
      (WidgetTester tester) async {
    // 修正: 有効な画像データを使用
    mockImagePickerPlatform.pickedFile = XFile.fromData(_kTransparentImage);

    final errorResponse = {'success': false, 'error': 'AI Error occurred'};
    final mockResponse = MockFunctionResponse();
    when(mockResponse.data).thenReturn(errorResponse);

    when(mockFunctionsClient.invoke(any, body: anyNamed('body')))
        .thenAnswer((_) async => mockResponse);

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('カメラで撮影'));
    await tester.pump(); // 画像ロード待ち
    await tester.pumpAndSettle();

    expect(
      find.textContaining('AI分析エラー: Exception: AI Error occurred'),
      findsOneWidget,
    );
  });

  testWidgets('異常系: 画像取得時に例外が発生した場合', (WidgetTester tester) async {
    // 一時的にモックをエラー発生版に差し替え
    ImagePickerPlatform.instance = ErrorMockImagePickerPlatform();

    await tester.pumpWidget(createTestWidget());
    await tester.tap(find.text('カメラで撮影'));
    await tester.pumpAndSettle();

    expect(find.textContaining('画像の取得に失敗しました'), findsOneWidget);

    // 後始末: 元に戻す（他のテストへの影響防止）
    ImagePickerPlatform.instance = mockImagePickerPlatform;
  });
}
