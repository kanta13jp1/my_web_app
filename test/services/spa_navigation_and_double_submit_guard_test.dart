import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/async_submission_guard.dart';
import 'package:my_web_app/services/spa_route_title_observer.dart';
import 'package:my_web_app/utils/route_document_title.dart';
import 'package:my_web_app/widgets/async_submit_guard_widgets.dart';
import 'package:my_web_app/widgets/atomic_forms/atoms/focus_blur_text_field.dart';
import 'package:my_web_app/widgets/atomic_forms/organisms/validated_submit_form_card.dart';

void main() {
  group('SpaRouteTitleResolver & SpaRouteTitleObserver (#2726)', () {
    test('resolves dynamic page titles per route and preserves SEO defaults',
        () {
      expect(SpaRouteTitleResolver.resolve('/'), landingDocumentTitle);
      expect(
        SpaRouteTitleResolver.resolve('/philosophy'),
        philosophyDocumentTitle,
      );
      expect(
        SpaRouteTitleResolver.resolve('/asset-management'),
        '資産・家計管理 | 自分株式会社',
      );
      expect(
        SpaRouteTitleResolver.resolve('/project-gantt?tab=wbs'),
        'WBS ガントチャート | 自分株式会社',
      );
      expect(
        SpaRouteTitleResolver.resolve('/price-tracker'),
        '価格トラッカー | 自分株式会社',
      );
      expect(
        SpaRouteTitleResolver.resolve('/custom-feature-page/?tab=1'),
        'Custom Feature Page | 自分株式会社',
      );
    });

    testWidgets(
        'updates browser title callback dynamically across push/replace/pop',
        (tester) async {
      final observedTitles = <String>[];
      final observer = SpaRouteTitleObserver(
        onTitleChanged: observedTitles.add,
        syncSystemChrome: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[observer],
          initialRoute: '/',
          routes: <String, WidgetBuilder>{
            '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/price-tracker'),
                    child: const Text('Go Price'),
                  ),
                ),
            '/price-tracker': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context)
                        .pushReplacementNamed('/project-gantt'),
                    child: const Text('Replace Gantt'),
                  ),
                ),
            '/project-gantt': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back Home'),
                  ),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(observer.currentTitle.value, landingDocumentTitle);

      await tester.tap(find.text('Go Price'));
      await tester.pumpAndSettle();
      expect(observer.currentRoutePath.value, '/price-tracker');
      expect(observer.currentTitle.value, '価格トラッカー | 自分株式会社');

      await tester.tap(find.text('Replace Gantt'));
      await tester.pumpAndSettle();
      expect(observer.currentRoutePath.value, '/project-gantt');
      expect(observer.currentTitle.value, 'WBS ガントチャート | 自分株式会社');

      await tester.tap(find.text('Back Home'));
      await tester.pumpAndSettle();
      expect(observer.currentRoutePath.value, '/');
      expect(observer.currentTitle.value, landingDocumentTitle);
      expect(
        observedTitles,
        <String>[
          landingDocumentTitle,
          '価格トラッカー | 自分株式会社',
          'WBS ガントチャート | 自分株式会社',
          landingDocumentTitle,
        ],
      );
    });
  });

  group('AsyncSubmissionGuard & UI feedback/navigation (#2726)', () {
    test('blocks concurrent duplicate execution and recovers after failure',
        () async {
      final guard = AsyncSubmissionGuard();
      final completer = Completer<int>();
      var callCount = 0;

      final firstFuture = guard.run<int>(
        action: () {
          callCount += 1;
          return completer.future;
        },
        successMessage: '登録完了',
      );
      expect(guard.isSubmitting, isTrue);

      final secondOutcome = await guard.run<int>(
        action: () async {
          callCount += 1;
          return 999;
        },
      );
      expect(secondOutcome.isIgnored, isTrue);
      expect(callCount, 1);
      expect(guard.ignoredDuplicateAttempts, 1);

      completer.complete(42);
      final firstOutcome = await firstFuture;
      expect(firstOutcome.isSucceeded, isTrue);
      expect(firstOutcome.data, 42);
      expect(guard.isSubmitting, isFalse);
      expect(guard.phase, AsyncSubmissionPhase.succeeded);

      final errorOutcome = await guard.run<void>(
        action: () async => throw Exception('Supabase RPC failed'),
      );
      expect(errorOutcome.isFailed, isTrue);
      expect(errorOutcome.message, 'Supabase RPC failed');
      expect(guard.isSubmitting, isFalse);
      expect(guard.phase, AsyncSubmissionPhase.failed);
    });

    testWidgets(
        'prevents double submit during async call, navigates on success, stays on error',
        (tester) async {
      final guard = AsyncSubmissionGuard();
      final observer = SpaRouteTitleObserver(syncSystemChrome: false);
      var completer = Completer<void>();
      var shouldFail = true;
      var callCount = 0;
      final titleFieldKey = GlobalKey<FocusBlurTextFieldState>();
      final controller = TextEditingController(text: '四半期予算レビュー');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          navigatorObservers: <NavigatorObserver>[observer],
          routes: <String, WidgetBuilder>{
            '/': (context) => Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ValidatedSubmitFormCard(
                      title: '新規申請',
                      fieldKeys: <GlobalKey<FocusBlurTextFieldState>>[
                        titleFieldKey,
                      ],
                      submitLabel: '登録する',
                      submittingLabel: '送信中...',
                      submitButtonKey: const ValueKey<String>('guarded_submit'),
                      submissionGuard: guard,
                      successMessage: '申請を登録しました',
                      onValidSubmitAsync: () async {
                        callCount += 1;
                        await completer.future;
                        if (shouldFail) {
                          throw Exception('一時的な保存エラー');
                        }
                      },
                      onSuccessNavigate: () =>
                          Navigator.of(context).pushReplacementNamed('/home'),
                      children: <Widget>[
                        FocusBlurTextField(
                          key: titleFieldKey,
                          controller: controller,
                          labelText: '件名',
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                                  ? '必須です'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
            '/home': (context) => const Scaffold(
                  body: Center(child: Text('登録後ホーム画面')),
                ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Rapid double tap while in flight -> executes once, stays on '/' on error
      await tester.tap(find.byKey(const ValueKey<String>('guarded_submit')));
      await tester.pump();
      expect(guard.isSubmitting, isTrue);
      expect(find.text('送信中...'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('guarded_submit')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(callCount, 1);

      completer.complete();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('async_submit_status_banner')),
        findsOneWidget,
      );
      expect(find.text('一時的な保存エラー'), findsWidgets);
      expect(find.text('登録後ホーム画面'), findsNothing);

      // Retry after error -> navigates to /home and updates title observer
      shouldFail = false;
      completer = Completer<void>();
      await tester.tap(find.byKey(const ValueKey<String>('guarded_submit')));
      await tester.pump();
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('登録後ホーム画面'), findsOneWidget);
      expect(observer.currentTitle.value, 'ホーム | 自分株式会社');
    });

    testWidgets(
        'passes layout overflow and accessibility guidelines at 2.0x scale in light/dark themes',
        (tester) async {
      final configs = <(Size, ThemeData)>[
        (const Size(390, 844), ThemeData.light()),
        (const Size(1280, 800), ThemeData.dark()),
      ];
      for (final (viewport, theme) in configs) {
        final guard = AsyncSubmissionGuard();
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          tester.view.physicalSize = viewport;
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey<String>('${viewport.width}_${theme.brightness}'),
              theme: theme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: viewport,
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: GuardedAsyncFormScope(
                      guard: guard,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text('フォーム操作ロック検証'),
                          const SizedBox(height: 12),
                          GuardedAsyncActionButton(
                            guard: guard,
                            label: '保存して進む',
                            buttonKey: const ValueKey<String>('a11y_submit'),
                            successMessage: '保存完了',
                            onSubmit: () async {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const ValueKey<String>('a11y_submit')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey<String>('async_submit_status_banner')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        } finally {
          handle.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      }
    });
  });
}
