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
}

Widget _buildShell({
  bool? isLoggedInOverride,
  Future<void> Function(String text)? onInboxSave,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) {
      return UniversalAiShareShell(
        navigatorKey: navigatorKey,
        isLoggedInOverride: isLoggedInOverride,
        onInboxSave: onInboxSave,
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: const Scaffold(body: Text('home')),
  );
}
