import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  var owner = '00000000-0000-4000-8000-000000000001';
  var posts = 0;
  Map<String, dynamic>? posted;
  var writeGate = Completer<void>();
  var responseSent = Completer<void>();
  const headers = {'content-type': 'application/json'};
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.llfbandit.app_links/events'),
      (call) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-only',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/v1/token') {
          final payload = base64Url
              .encode(
                utf8.encode(
                  jsonEncode({
                    'sub': owner,
                    'exp': 4102444800,
                    'role': 'authenticated',
                  }),
                ),
              )
              .replaceAll('=', '');
          return http.Response(
            jsonEncode({
              'access_token': 'e30.$payload.test',
              'refresh_token': 'synthetic-refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'role': 'authenticated',
                'app_metadata': {},
                'user_metadata': {},
                'created_at': '2026-01-01T00:00:00Z',
              },
            }),
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.url.path == '/auth/v1/user') {
          return http.Response(
            jsonEncode({
              'id': owner,
              'aud': 'authenticated',
              'role': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-01-01T00:00:00Z',
            }),
            200,
            headers: headers,
            request: request,
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/wealth_struggles')) {
          posts++;
          posted = jsonDecode(request.body) as Map<String, dynamic>;
          await writeGate.future;
          responseSent.complete();
          return http.Response('', 201, headers: headers, request: request);
        }
        return http.Response('[]', 200, headers: headers, request: request);
      }),
    );
  });
  for (final switchOwner in [false, true]) {
    testWidgets('flow completion respects owner switch=$switchOwner',
        (tester) async {
      owner = '00000000-0000-4000-8000-000000000001';
      posts = 0;
      posted = null;
      writeGate = Completer<void>();
      responseSent = Completer<void>();
      SharedPreferences.setMockInitialValues({});
      await Supabase.instance.client.auth.signInWithPassword(
        email: 'synthetic@example.invalid',
        password: 'synthetic-only',
      );
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: AssetManagementPage()));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final memo = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == '内容',
      );
      final amount = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == '金額 (円)',
      );
      expect(memo, findsOneWidget);
      await tester.ensureVisible(memo);
      await tester.enterText(memo, 'synthetic A draft');
      await tester.enterText(amount, '111');
      final card = find.ancestor(of: memo, matching: find.byType(Card)).first;
      final save = find.descendant(
        of: card,
        matching: find.widgetWithText(ElevatedButton, '追加'),
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 300));
      expect(posts, 1);
      expect(posted!['user_id'], owner);
      if (switchOwner) {
        owner = '00000000-0000-4000-8000-000000000002';
        await Supabase.instance.client.auth.signInWithPassword(
          email: 'second@example.invalid',
          password: 'synthetic-only',
        );
        expect(Supabase.instance.client.auth.currentUser!.id, owner);
        await tester.enterText(memo, 'synthetic B draft');
        await tester.enterText(amount, '222');
        expect(tester.widget<TextField>(memo).controller!.text,
            'synthetic B draft');
        expect(tester.widget<TextField>(amount).controller!.text, '222');
      }
      await tester.runAsync(() async {
        writeGate.complete();
        await responseSent.future;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(posts, 1);
      expect(
        tester.widget<TextField>(memo).controller!.text,
        switchOwner ? 'synthetic B draft' : '',
      );
      expect(
        tester.widget<TextField>(amount).controller!.text,
        switchOwner ? '222' : '',
      );
      if (switchOwner) {
        expect(find.text('収支を記録しました'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
