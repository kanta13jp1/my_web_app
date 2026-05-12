import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/ai_share_button_preferences_service.dart';
import 'package:my_web_app/widgets/universal_ai_share_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await aiShareButtonPreferencesController.reload();
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

  testWidgets('settings sheet opens from the overlay-hosted share button',
      (tester) async {
    await tester.pumpWidget(_buildShell());
    await tester.pump();

    await tester.tap(find.byTooltip('AIシェアボタン設定'));
    await tester.pumpAndSettle();

    expect(find.text('表示位置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildShell() {
  final navigatorKey = GlobalKey<NavigatorState>();
  return MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) {
      return UniversalAiShareShell(
        navigatorKey: navigatorKey,
        child: child ?? const SizedBox.shrink(),
      );
    },
    home: const Scaffold(body: Text('home')),
  );
}
