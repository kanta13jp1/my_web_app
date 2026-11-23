import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/career_monthly_kpi_page.dart';
import 'package:my_web_app/services/self_skill_asset_service.dart';
import 'package:my_web_app/widgets/atomic_forms/atoms/focus_blur_text_field.dart';
import 'package:my_web_app/widgets/atomic_forms/molecules/validated_input_group.dart';
import 'package:my_web_app/widgets/atomic_forms/organisms/validated_submit_form_card.dart';
import 'package:my_web_app/widgets/self_skill_asset_portfolio_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-publishable-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        return http.Response(
          '{"items":[]}',
          200,
          headers: const <String, String>{'content-type': 'application/json'},
          request: request,
        );
      }),
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Atomic Design Focus-Blur Validation (#2730)', () {
    testWidgets(
        'shows inline validation error immediately on focus loss and blocks invalid submit',
        (tester) async {
      final nameKey = GlobalKey<FocusBlurTextFieldState>();
      final nameCtrl = TextEditingController();
      final otherNode = FocusNode();
      addTearDown(nameCtrl.dispose);
      addTearDown(otherNode.dispose);

      var submitCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  ValidatedSubmitFormCard(
                    title: 'フォーカス喪失検証テストフォーム',
                    fieldKeys: <GlobalKey<FocusBlurTextFieldState>>[nameKey],
                    submitLabel: '送信',
                    submitButtonKey: const Key('atomic_test_submit_button'),
                    onValidSubmit: () => submitCalls++,
                    children: <Widget>[
                      ValidatedInputGroup(
                        label: '項目名',
                        requiredField: true,
                        fieldKey: nameKey,
                        controller: nameCtrl,
                        validator: SelfSkillAssetService.validateSkillName,
                      ),
                    ],
                  ),
                  TextField(
                    key: const Key('other_blur_target_field'),
                    focusNode: otherNode,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final inputFinder = find.byType(FocusBlurTextField);
      await tester.tap(inputFinder);
      await tester.pump();
      await tester.enterText(inputFinder, 'X');
      await tester.pump();
      expect(find.text('スキル名は2文字以上で入力してください。'), findsNothing);

      // Move focus away (blur) -> error must appear BEFORE submit.
      await tester.tap(find.byKey(const Key('other_blur_target_field')));
      await tester.pump();
      expect(find.text('スキル名は2文字以上で入力してください。'), findsOneWidget);

      // Submit button must NOT call onValidSubmit while invalid.
      await tester.tap(find.byKey(const Key('atomic_test_submit_button')));
      await tester.pump();
      expect(submitCalls, 0);

      // Enter valid text and submit -> callback runs once.
      await tester.tap(inputFinder);
      await tester.enterText(inputFinder, 'Flutter');
      await tester.pump();
      await tester.tap(find.byKey(const Key('atomic_test_submit_button')));
      await tester.pump();
      expect(submitCalls, 1);
    });
  });

  group('SelfSkillAssetPortfolioPanel & CareerMonthlyKpiPage (#1392 / #2770)',
      () {
    testWidgets(
        'supports skill CRUD, radar chart rendering, and acquisition targets on 390x844 mobile',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = SelfSkillAssetService(
        storage: SharedPreferencesSelfSkillAssetStorage(userScope: 'ui_test'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelfSkillAssetPortfolioPanel(service: service),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('self_skill_radar_empty')), findsOneWidget);

      Future<void> addSkill(String name, String category, String level) async {
        final formCard = find.byKey(const Key('self_skill_asset_form_card'));
        final nameField = find.descendant(
          of: formCard,
          matching: find.byType(FocusBlurTextField).first,
        );
        await tester.ensureVisible(nameField);
        await tester.enterText(nameField, name);

        final levelField = find.descendant(
          of: formCard,
          matching: find.byType(FocusBlurTextField).at(1),
        );
        await tester.ensureVisible(levelField);
        await tester.enterText(levelField, level);

        final catChip = find.byKey(Key('self_skill_cat_$category'));
        await tester.ensureVisible(catChip);
        await tester.tap(catChip);
        await tester.pump();

        final submitBtn = find.byKey(const Key('self_skill_submit_button'));
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();
      }

      await addSkill('Flutter', '技術・開発', '5');
      expect(
        find.byKey(const Key('self_skill_radar_bars_fallback')),
        findsOneWidget,
      );

      await addSkill('AIエージェント', 'AI・データ', '4');
      await addSkill('財務KPI管理', '事業・経営', '3');

      expect(
        find.byKey(const Key('self_skill_radar_canvas_box')),
        findsOneWidget,
      );

      // Add an acquisition target (#1392 / #2770).
      final targetCard = find.byKey(const Key('self_skill_target_form_card'));
      final targetNameField = find.descendant(
        of: targetCard,
        matching: find.byType(FocusBlurTextField).first,
      );
      await tester.ensureVisible(targetNameField);
      await tester.enterText(targetNameField, '法務・知財戦略');
      final targetSubmitBtn = find.byKey(
        const Key('self_skill_target_submit_button'),
      );
      await tester.ensureVisible(targetSubmitBtn);
      await tester.tap(targetSubmitBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('法務・知財戦略'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'renders SelfSkillAssetPortfolioPanel inside CareerMonthlyKpiPage on desktop',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final service = SelfSkillAssetService(
        storage: SharedPreferencesSelfSkillAssetStorage(
          userScope: 'desktop_page_test',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CareerMonthlyKpiPage(skillAssetService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('self_skill_asset_portfolio_card')),
        300,
      );
      expect(
        find.byKey(const Key('self_skill_asset_portfolio_card')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
