import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/ai_image_generator_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://dummy.supabase.co',
      publishableKey: 'dummy',
    );
  });

  testWidgets('renders image quality choices with usage tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AiImageGeneratorPage()));
    await tester.pump();

    expect(find.text('高速'), findsOneWidget);
    expect(find.text('標準'), findsOneWidget);
    expect(find.text('高画質'), findsOneWidget);
    expect(find.byTooltip('アイデア出しや大量生成向け。待ち時間を短くします。'), findsOneWidget);
    expect(find.byTooltip('速度と品質のバランスを取った通常設定です。'), findsOneWidget);
    expect(find.byTooltip('細部の忠実度を優先します。図解や仕上げ用途向けです。'), findsOneWidget);
  });

  testWidgets('renders structured prompt input fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiImageGeneratorPage()));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.text('シーンと対象'), findsOneWidget);
    expect(find.text('スタイル'), findsOneWidget);
    expect(find.text('制約（維持・除外するもの）'), findsOneWidget);
    expect(find.text('画像内テキスト'), findsOneWidget);
  });
}
