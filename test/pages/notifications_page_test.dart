import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/notifications_page.dart';

void main() {
  group('NotificationsPage extracted widgets', () {
    testWidgets('NotificationsMarkAllButton light and dark', (tester) async {
      var tapCount = 0;

      Future<void> pumpWithTheme(ThemeData theme) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              appBar: AppBar(
                actions: [
                  NotificationsMarkAllButton(
                    onPressed: () => tapCount += 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      await pumpWithTheme(ThemeData.light());
      final lightCtx = tester.element(find.byType(NotificationsMarkAllButton));
      final lightOnSurface = Theme.of(lightCtx).colorScheme.onSurface;
      expect(lightOnSurface, isNot(Colors.white));
      final lightButton = tester.widget<TextButton>(
        find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(
        lightButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        lightOnSurface,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('全既読'))).style.color,
        lightOnSurface,
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.done_all))).color,
        lightOnSurface,
      );

      await pumpWithTheme(ThemeData.dark());
      final darkCtx = tester.element(find.byType(NotificationsMarkAllButton));
      final darkOnSurface = Theme.of(darkCtx).colorScheme.onSurface;
      final darkButton = tester.widget<TextButton>(
        find.byWidgetPredicate((w) => w is TextButton),
      );
      expect(
        darkButton.style?.foregroundColor?.resolve(const <WidgetState>{}),
        darkOnSurface,
      );
      expect(
        DefaultTextStyle.of(tester.element(find.text('全既読'))).style.color,
        darkOnSurface,
      );
      expect(
        IconTheme.of(tester.element(find.byIcon(Icons.done_all))).color,
        darkOnSurface,
      );

      await tester.tap(find.text('全既読'));
      await tester.pump();
      expect(tapCount, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NotificationFilterChip dark mode contrast', (tester) async {
      const darkScheme = ColorScheme.dark(
        primary: Color(0xFFFF8C5A),
        onPrimary: Color(0xFF1A110C),
        onSurface: Colors.white,
      );
      var selectedTapped = false;
      var unselectedTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: darkScheme),
          home: Scaffold(
            body: Row(
              children: [
                NotificationFilterChip(
                  label: 'すべて',
                  selected: true,
                  onTap: () => selectedTapped = true,
                ),
                NotificationFilterChip(
                  label: '未読',
                  selected: false,
                  onTap: () => unselectedTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      final selectedText = tester.widget<Text>(find.text('すべて'));
      expect(selectedText.style?.color, const Color(0xFF1A110C));
      expect(selectedText.style?.color, isNot(Colors.white));

      final unselectedText = tester.widget<Text>(find.text('未読'));
      expect(unselectedText.style?.color, Colors.white);

      await tester.tap(find.text('すべて'));
      await tester.tap(find.text('未読'));
      await tester.pump();

      expect(selectedTapped, isTrue);
      expect(unselectedTapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NotificationsSignedOutState calls onLogin', (tester) async {
      var loginTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationsSignedOutState(
              onLogin: () => loginTapped = true,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('notifications_signed_out_state')),
        findsOneWidget,
      );
      expect(find.text('ログインすると通知を確認できます。'), findsOneWidget);
      expect(find.text('ログイン'), findsOneWidget);

      await tester.tap(find.text('ログイン'));
      await tester.pump();

      expect(loginTapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NotificationTile handles non-String fields', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationTile(
              notif: const <String, dynamic>{
                'id': 123,
                'title': 456,
                'message': null,
                'created_at': 999,
                'link': 42,
                'is_read': false,
              },
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('456'), findsOneWidget);
      expect(find.text('→ タップして詳細を見る'), findsOneWidget);

      await tester.tap(find.byType(NotificationTile));
      await tester.pump();

      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('NotificationTile handles null and bad types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationTile(
              notif: const <String, dynamic>{
                'id': null,
                'type': 777,
                'title': null,
                'message': 888,
                'created_at': null,
                'link': null,
                'is_read': 'invalid',
              },
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('その他'), findsOneWidget);
      expect(find.text('888'), findsOneWidget);
      expect(find.text('→ タップして詳細を見る'), findsNothing);
    });
  });
}
