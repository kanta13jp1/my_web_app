import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_share_button_preferences_service.dart';
import 'package:my_web_app/services/universal_x_share_service.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await aiShareButtonPreferencesController.reload();
    universalAiShareRouteObserver.currentPage.value =
        UniversalSharePageContext.fromRouteName('/notes');
  });

  testWidgets('anonymous landing hides the universal share button',
      (tester) async {
    universalAiShareRouteObserver.currentPage.value =
        UniversalSharePageContext.fromRouteName('/');

    await tester.pumpWidget(_buildShell());
    await tester.pump();

    expect(find.byTooltip('AIシェア'), findsNothing);
    expect(find.byTooltip('AIシェアボタン設定'), findsNothing);
  });

  testWidgets('AI share tooltip is hosted inside the navigator overlay',
      (tester) async {
    await tester.pumpWidget(_buildShell());
    await tester.pump();

    expect(find.byTooltip('AIシェア'), findsOneWidget);

    await tester.longPress(find.byTooltip('AIシェア'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('authenticated users can capture Inbox text from the overlay',
      (tester) async {
    String? savedText;
    await tester.pumpWidget(
      _buildShell(
        isLoggedInOverride: true,
        onInboxSave: (text) async {
          savedText = text;
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Inboxへメモ'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('inbox_quick_capture_text_field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('inbox_quick_capture_text_field')),
      'Capture from any screen',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('inbox_quick_capture_save_button')));
    await tester.pumpAndSettle();

    expect(savedText, 'Capture from any screen');
    expect(find.text('Inboxに保存しました'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile viewport hides the overlay so it cannot cover content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildShell());
    await tester.pump();

    expect(find.byTooltip('AIシェア'), findsNothing);
    expect(find.byTooltip('AIシェアボタン設定'), findsNothing);
  });

  testWidgets('mobile asset Inbox stays clear of the right-hand chat action',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    universalAiShareRouteObserver.currentPage.value =
        UniversalSharePageContext.fromRouteName('/asset-management');

    await tester.pumpWidget(_buildShell(isLoggedInOverride: true));
    await tester.pump();

    final inbox = tester.getRect(
      find.byKey(const Key('universal_inbox_capture_button')),
    );
    expect(inbox.right, lessThan(100));
    expect(find.byTooltip('AIシェア'), findsNothing);
    await tester.tap(find.byTooltip('Inboxへメモ'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('inbox_quick_capture_text_field')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  test('asset mobile placement override preserves other routes and preferences',
      () {
    for (final width in [320.0, 390.0, 599.0, 600.0, 1024.0]) {
      expect(
        resolveAiShareFabPosition(
          preferred: AiShareButtonPosition.bottomRight,
          routePath: '/asset-management',
          screenWidth: width,
        ),
        width < 600
            ? AiShareButtonPosition.bottomLeft
            : AiShareButtonPosition.bottomRight,
      );
    }
    expect(
      resolveAiShareFabPosition(
        preferred: AiShareButtonPosition.topRight,
        routePath: '/asset-management',
        screenWidth: 390,
      ),
      AiShareButtonPosition.topRight,
    );
    expect(
      resolveAiShareFabPosition(
        preferred: AiShareButtonPosition.bottomRight,
        routePath: '/notes',
        screenWidth: 390,
      ),
      AiShareButtonPosition.bottomRight,
    );
  });

  testWidgets('settings sheet opens from the overlay-hosted share button',
      (tester) async {
    await tester.pumpWidget(_buildShell());
    await tester.pump();

    await tester.tap(find.byTooltip('AIシェアボタン設定'));
    await tester.pumpAndSettle();

    expect(find.text('表示位置'), findsOneWidget);
    expect(find.text('動画エンジン'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings sheet switches the share video engine to cinematic',
      (tester) async {
    await tester.pumpWidget(_buildShell());
    await tester.pump();

    await tester.tap(find.byTooltip('AIシェアボタン設定'));
    await tester.pumpAndSettle();

    expect(
      aiShareButtonPreferencesController.preferences.videoEngine,
      AiShareVideoEngine.presenter,
    );

    await tester.ensureVisible(find.text('シネマティック'));
    await tester.tap(find.text('シネマティック'));
    await tester.pumpAndSettle();

    expect(
      aiShareButtonPreferencesController.preferences.videoEngine,
      AiShareVideoEngine.cinematic,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('/note-editor では左下 Inbox FAB を非表示にする', (tester) async {
    universalAiShareRouteObserver.currentPage.value =
        UniversalSharePageContext.fromRouteName('/note-editor');
    await tester.pumpWidget(_buildShell(isLoggedInOverride: true));
    await tester.pump();

    expect(
      find.byKey(const Key('universal_inbox_capture_button')),
      findsNothing,
    );
  });

  test('目標センター系ルートでは既定 bottomRight を左下へ退避し他の位置設定を保つ', () {
    for (final routePath in <String>[
      '/life-goals',
      '/goal-tracker',
      '/life-goals/',
    ]) {
      for (final width in <double>[320.0, 390.0, 599.0, 600.0, 1280.0]) {
        expect(
          resolveAiShareFabPosition(
            preferred: AiShareButtonPosition.bottomRight,
            routePath: routePath,
            screenWidth: width,
          ),
          AiShareButtonPosition.bottomLeft,
          reason: '$routePath ($width px) has a bottom-right page FAB',
        );
      }
      for (final preferred in <AiShareButtonPosition>[
        AiShareButtonPosition.topRight,
        AiShareButtonPosition.topLeft,
        AiShareButtonPosition.bottomLeft,
      ]) {
        expect(
          resolveAiShareFabPosition(
            preferred: preferred,
            routePath: routePath,
            screenWidth: 1280,
          ),
          preferred,
        );
      }
    }

    for (final routePath in <String>[
      '/daily-habits',
      '/ai-writing-assistant',
    ]) {
      expect(
        resolveAiShareFabPosition(
          preferred: AiShareButtonPosition.bottomRight,
          routePath: routePath,
          screenWidth: 390,
        ),
        AiShareButtonPosition.bottomRight,
      );
    }
  });

  testWidgets(
    '/daily-habits では NavigationBar の上に配置され右タブ操作を妨げずアクセシビリティ要件を満たす',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final size in const <Size>[Size(390, 844), Size(1440, 1000)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          universalAiShareRouteObserver.currentPage.value =
              UniversalSharePageContext.fromRouteName('/daily-habits');
          var selectedTab = 0;

          await tester.pumpWidget(
            _buildShell(
              isLoggedInOverride: true,
              home: StatefulBuilder(
                builder: (context, setState) {
                  return Scaffold(
                    body: Text('tab-$selectedTab'),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: selectedTab,
                      onDestinationSelected: (index) {
                        setState(() => selectedTab = index);
                      },
                      destinations: const <NavigationDestination>[
                        NavigationDestination(
                          icon: Icon(Icons.repeat),
                          label: '今日の習慣',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          label: 'XP・バッジ',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final navBarRect = tester.getRect(find.byType(NavigationBar));
          final inboxFinder = find.byKey(
            const Key('universal_inbox_capture_button'),
          );
          final inboxRect = tester.getRect(inboxFinder);
          expect(inboxRect.overlaps(navBarRect), isFalse);
          expect(inboxRect.bottom, lessThanOrEqualTo(navBarRect.top - 12));

          final overlayRect = tester.getRect(
            find.ancestor(
              of: inboxFinder,
              matching: find.byWidgetPredicate(
                (widget) => widget is Material && widget.elevation == 6,
              ),
            ),
          );
          expect(overlayRect.overlaps(navBarRect), isFalse);
          expect(overlayRect.bottom, lessThanOrEqualTo(navBarRect.top - 12));
          if (size.width >= kAiShareFabMinScreenWidth) {
            expect(
              tester.getRect(find.byTooltip('AIシェア')).overlaps(navBarRect),
              isFalse,
            );
            expect(
              tester.getRect(find.byTooltip('AIシェアボタン設定')).overlaps(navBarRect),
              isFalse,
            );
          }

          await tester.tap(find.text('XP・バッジ'));
          await tester.pumpAndSettle();
          expect(selectedTab, 1);

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }

        await tester.tap(
          find.byKey(const Key('universal_inbox_capture_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('inbox_quick_capture_text_field')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    '/life-goals では NavigationBar と右下追加FABの両方を避け 320px/2.0x でも重ならない',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final size in const <Size>[Size(390, 844), Size(1440, 1000)]) {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          universalAiShareRouteObserver.currentPage.value =
              UniversalSharePageContext.fromRouteName('/life-goals');
          var selectedTab = 0;
          var fabTapped = 0;

          await tester.pumpWidget(
            _buildShell(
              isLoggedInOverride: true,
              home: StatefulBuilder(
                builder: (context, setState) {
                  return Scaffold(
                    body: Scaffold(
                      body: Center(child: Text('goal-tab-$selectedTab')),
                      floatingActionButton: FloatingActionButton.extended(
                        onPressed: () {
                          setState(() => fabTapped += 1);
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: selectedTab,
                      onDestinationSelected: (index) {
                        setState(() => selectedTab = index);
                      },
                      destinations: const <NavigationDestination>[
                        NavigationDestination(
                          icon: Icon(Icons.account_tree_outlined),
                          label: '人生目標',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.flag_outlined),
                          label: '従来の目標',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pump();
          await tester.pump();

          final navBarRect = tester.getRect(find.byType(NavigationBar));
          final fabRect = tester.getRect(
            find.byType(FloatingActionButton),
          );
          final inboxFinder = find.byKey(
            const Key('universal_inbox_capture_button'),
          );
          final overlayRect = tester.getRect(
            find.ancestor(
              of: inboxFinder,
              matching: find.byWidgetPredicate(
                (widget) => widget is Material && widget.elevation == 6,
              ),
            ),
          );

          expect(overlayRect.overlaps(navBarRect), isFalse);
          expect(overlayRect.bottom, lessThanOrEqualTo(navBarRect.top - 12));
          expect(overlayRect.overlaps(fabRect), isFalse);
          expect(overlayRect.right, lessThan(fabRect.left));

          await tester.tap(find.text('追加'));
          await tester.pump();
          expect(fabTapped, 1);

          await tester.tap(find.text('従来の目標'));
          await tester.pumpAndSettle();
          expect(selectedTab, 1);

          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        }

        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        universalAiShareRouteObserver.currentPage.value =
            UniversalSharePageContext.fromRouteName('/life-goals');

        await tester.pumpWidget(
          _buildShell(
            isLoggedInOverride: true,
            textScaler: const TextScaler.linear(2.0),
            home: Scaffold(
              body: Scaffold(
                body: const SizedBox.expand(),
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ),
              bottomNavigationBar: const SizedBox(height: 80),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        final fabRect = tester.getRect(find.byType(FloatingActionButton));
        final inboxRect = tester.getRect(
          find.byKey(const Key('universal_inbox_capture_button')),
        );
        expect(inboxRect.overlaps(fabRect), isFalse);
        expect(inboxRect.right, lessThan(fabRect.left));

        await tester.tap(
          find.byKey(const Key('universal_inbox_capture_button')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('inbox_quick_capture_text_field')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

Widget _buildShell({
  bool? isLoggedInOverride,
  Future<void> Function(String text)? onInboxSave,
  Widget home = const Scaffold(body: Text('home')),
  TextScaler? textScaler,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) {
      final shell = UniversalAiShareShell(
        navigatorKey: navigatorKey,
        isLoggedInOverride: isLoggedInOverride,
        onInboxSave: onInboxSave,
        child: child ?? const SizedBox.shrink(),
      );
      if (textScaler == null) return shell;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: shell,
      );
    },
    home: home,
  );
}
