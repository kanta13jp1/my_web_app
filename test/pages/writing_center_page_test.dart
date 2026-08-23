import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/writing_center_page.dart';
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

  testWidgets('legacy summary entry opens the summary tab and switches tools', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: WritingCenterPage(initialSection: WritingCenterSection.summaries),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI サマリー'), findsOneWidget);
    expect(find.text('文章作成・改善'), findsOneWidget);
    expect(find.text('AI要約・履歴'), findsOneWidget);

    await tester.tap(find.text('文章作成・改善'));
    await tester.pumpAndSettle();

    expect(find.text('AI文章アシスタント'), findsOneWidget);
    expect(find.text('要約'), findsNothing);

    await tester.tap(find.text('AI要約・履歴'));
    await tester.pumpAndSettle();

    expect(find.text('AI サマリー'), findsOneWidget);
  });
}
