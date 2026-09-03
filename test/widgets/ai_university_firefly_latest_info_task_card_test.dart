import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/ai_university_firefly_latest_info_task_card.dart';

void main() {
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  Widget subject(AiUniversityFireflyLatestInfoTaskSubmit onSubmit) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiUniversityFireflyLatestInfoTaskCard(onSubmit: onSubmit),
          ),
        ),
      );

  Future<void> completeTask(WidgetTester tester) async {
    await tapVisible(tester, find.byKey(const Key('firefly-latest-q0-o0')));
    await tapVisible(tester, find.byKey(const Key('firefly-latest-q1-o0')));
    await tapVisible(tester, find.byKey(const Key('firefly-latest-q2-o1')));
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-feature-interfaces_batch')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-output-asset_batch')),
    );
    await tapVisible(tester, find.byKey(const Key('firefly-latest-assets-100')));
    await tapVisible(tester, find.byKey(const Key('firefly-latest-legacy-60')));
    await tapVisible(tester, find.byKey(const Key('firefly-latest-new-30')));
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-revisions-1')),
    );
    await tapVisible(tester, find.byKey(const Key('firefly-latest-usable-yes')));
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-workplace-yes')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-adoption-pilot')),
    );
    await tapVisible(
      tester,
      find.byKey(const Key('firefly-latest-comparison-documented')),
    );
    await tapVisible(tester, find.byKey(const Key('firefly-latest-rating-4')));
  }

  testWidgets('keeps submission disabled until the full comparison is done',
      (tester) async {
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required selfRating,
        required releaseFeature,
        required outputKind,
        required inputAssetCount,
        required legacyWorkflowMinutes,
        required latestWorkflowMinutes,
        required revisionCount,
        required usableOutput,
        required workplaceApplicable,
        required adoptionDecision,
      }) async =>
          true),
    );

    final submit = find.byKey(const Key('firefly-latest-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await completeTask(tester);
    await tester.ensureVisible(submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
  });

  testWidgets('submits only finite aggregate workflow evidence', (tester) async {
    Map<String, Object>? submitted;
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required selfRating,
        required releaseFeature,
        required outputKind,
        required inputAssetCount,
        required legacyWorkflowMinutes,
        required latestWorkflowMinutes,
        required revisionCount,
        required usableOutput,
        required workplaceApplicable,
        required adoptionDecision,
      }) async {
        submitted = <String, Object>{
          'correctAnswers': correctAnswers,
          'selfRating': selfRating,
          'releaseFeature': releaseFeature,
          'outputKind': outputKind,
          'inputAssetCount': inputAssetCount,
          'legacyWorkflowMinutes': legacyWorkflowMinutes,
          'latestWorkflowMinutes': latestWorkflowMinutes,
          'revisionCount': revisionCount,
          'usableOutput': usableOutput,
          'workplaceApplicable': workplaceApplicable,
          'adoptionDecision': adoptionDecision,
        };
        return true;
      }),
    );

    await completeTask(tester);
    await tapVisible(tester, find.byKey(const Key('firefly-latest-submit')));
    await tester.pumpAndSettle();

    expect(submitted, <String, Object>{
      'correctAnswers': 3,
      'selfRating': 4,
      'releaseFeature': 'interfaces_batch',
      'outputKind': 'asset_batch',
      'inputAssetCount': 100,
      'legacyWorkflowMinutes': 60,
      'latestWorkflowMinutes': 30,
      'revisionCount': 1,
      'usableOutput': true,
      'workplaceApplicable': true,
      'adoptionDecision': 'pilot',
    });
    expect(
      find.byKey(const Key('firefly-latest-submitted-result')),
      findsOneWidget,
    );
  });

  testWidgets('shows a retryable error when aggregate submission is rejected',
      (tester) async {
    await tester.pumpWidget(
      subject(({
        required correctAnswers,
        required selfRating,
        required releaseFeature,
        required outputKind,
        required inputAssetCount,
        required legacyWorkflowMinutes,
        required latestWorkflowMinutes,
        required revisionCount,
        required usableOutput,
        required workplaceApplicable,
        required adoptionDecision,
      }) async =>
          false),
    );

    await completeTask(tester);
    await tapVisible(tester, find.byKey(const Key('firefly-latest-submit')));
    await tester.pump();

    expect(find.textContaining('結果を送信できませんでした'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('firefly-latest-submit')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
