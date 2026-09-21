import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/danshari_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'signed-out users see sign-in guidance instead of an endless loader',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DanshariPage(
            supabaseClient: _SignedOutSupabaseClient(),
          ),
          routes: {
            '/login': (_) => const Scaffold(
                  body: Text('ログイン画面'),
                ),
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('ログインが必要です'), findsOneWidget);
      expect(
        find.text('保存したメモの断捨離を始めるにはログインしてください。'),
        findsOneWidget,
      );

      final signInButton = find.byKey(
        const Key('danshari-sign-in-button'),
      );
      expect(signInButton, findsOneWidget);

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(find.text('ログイン画面'), findsOneWidget);
    },
  );
}

class _SignedOutSupabaseClient extends Fake implements SupabaseClient {
  @override
  final GoTrueClient auth = _SignedOutGoTrueClient();
}

class _SignedOutGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => null;
}
