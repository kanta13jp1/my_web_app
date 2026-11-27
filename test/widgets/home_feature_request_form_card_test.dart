import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_feature_request_form_card.dart';

void main() {
  testWidgets(
    'HomeFeatureRequestFormCard renders normal, submitting, and submitted states at 360x800 @ 2.0x',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final formKey = GlobalKey<FormState>();
      final titleCtrl = TextEditingController();
      final descCtrl = TextEditingController();
      final outcomeCtrl = TextEditingController();
      addTearDown(() {
        titleCtrl.dispose();
        descCtrl.dispose();
        outcomeCtrl.dispose();
      });

      var submitCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeFeatureRequestFormCard(
                  isDark: false,
                  isCompact: true,
                  formKey: formKey,
                  titleController: titleCtrl,
                  descriptionController: descCtrl,
                  outcomeController: outcomeCtrl,
                  category: '機能追加',
                  priority: 'medium',
                  isSubmitting: false,
                  isAnalyzingAttachment: false,
                  hasAttachment: false,
                  onCategoryChanged: (_) {},
                  onPriorityChanged: (_) {},
                  onPickAttachment: () {},
                  onAnalyzeAttachment: () {},
                  onClearAttachment: () {},
                  onSubmit: () => submitCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('改善内容を送る'), findsOneWidget);
      expect(find.text('登録する'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final submitFinder = find.text('登録する');
      await tester.ensureVisible(submitFinder);
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();
      expect(submitCalled, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: HomeFeatureRequestFormCard(
                  isDark: true,
                  isCompact: true,
                  formKey: formKey,
                  titleController: titleCtrl,
                  descriptionController: descCtrl,
                  outcomeController: outcomeCtrl,
                  category: '機能追加',
                  priority: 'medium',
                  isSubmitting: true,
                  isAnalyzingAttachment: true,
                  hasAttachment: true,
                  attachmentFileName: 'shot.png',
                  attachmentSizeLabel: '120 KB',
                  analysisObservation: 'ボタンが小さい',
                  analysisProposal: '48dp以上へ拡大',
                  hasSubmission: true,
                  submissionSuccess: true,
                  issueNumber: 4916,
                  issueUrl:
                      'https://github.com/kanta13jp1/my_web_app/issues/4916',
                  hasWbsTask: true,
                  onCategoryChanged: (_) {},
                  onPriorityChanged: (_) {},
                  onPickAttachment: () {},
                  onAnalyzeAttachment: () {},
                  onClearAttachment: () {},
                  onSubmit: () {},
                  onLaunchXShare: () async => false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('登録中'), findsOneWidget);
      expect(find.text('AI診断中'), findsOneWidget);
      expect(find.text('受付番号: #4916'), findsOneWidget);
      expect(find.text('改善タスクに登録済み'), findsOneWidget);

      final shareBtn = find.byKey(const Key('feature_request_share_x_button'));
      await tester.ensureVisible(shareBtn);
      await tester.tap(shareBtn);
      await tester.pump();
      expect(
        find.text('Xの投稿画面を開けませんでした。本文をコピーして共有してください。'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
