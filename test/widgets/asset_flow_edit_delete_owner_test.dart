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
  var writes = 0;
  var readbacks = 0;
  var failResponse = false;
  http.Request? mutation;
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
        if (request.url.path.endsWith('/wealth_struggles')) {
          if (request.method == 'PATCH' || request.method == 'DELETE') {
            writes++;
            mutation = request;
            await writeGate.future;
            responseSent.complete();
            return http.Response(
              failResponse
                  ? jsonEncode(
                      {'code': 'XX000', 'message': 'synthetic failure'},
                    )
                  : '',
              failResponse ? 400 : 204,
              headers: headers,
              request: request,
            );
          }
          if (request.method == 'GET') {
            readbacks++;
            return http.Response(
              jsonEncode([
                {
                  'id': 'synthetic-flow-id',
                  'user_id': '00000000-0000-4000-8000-000000000001',
                  'action_type': 'expense',
                  'amount': 111,
                  'description': '[現金] synthetic editable expense',
                  'occurred_at': DateTime.now().toUtc().toIso8601String(),
                },
              ]),
              200,
              headers: headers,
              request: request,
            );
          }
        }
        return http.Response('[]', 200, headers: headers, request: request);
      }),
    );
  });
  Future<void> signInAs(String id) async {
    owner = id;
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'synthetic@example.invalid',
      password: 'synthetic-only',
    );
  }

  Future<void> settleFrame(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const ownerA = '00000000-0000-4000-8000-000000000001';
  const ownerB = '00000000-0000-4000-8000-000000000002';
  for (final operation in ['edit', 'delete']) {
    for (final phase in ['dialog', 'write', 'writeError']) {
      for (final mode in ['same', 'other', 'aba']) {
        testWidgets(
          'flow $operation completion phase=$phase owner=$mode',
          (tester) async {
            writes = 0;
            readbacks = 0;
            mutation = null;
            failResponse = phase == 'writeError';
            writeGate = Completer<void>();
            responseSent = Completer<void>();
            SharedPreferences.setMockInitialValues({});
            await signInAs(ownerA);
            await tester.binding.setSurfaceSize(const Size(1200, 2400));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              const MaterialApp(home: AssetManagementPage()),
            );
            await settleFrame(tester);
            expect(readbacks, greaterThan(0));
            final row = find.ancestor(
              of: find.text('現金 ・ synthetic editable expense'),
              matching: find.byType(ListTile),
            );
            expect(row, findsOneWidget);
            final trigger = find.descendant(
              of: row,
              matching: find.byTooltip(operation == 'edit' ? '編集' : '削除'),
            );
            await tester.ensureVisible(trigger);
            await tester.tap(trigger);
            await tester.pump(const Duration(milliseconds: 300));
            expect(find.byType(AlertDialog), findsOneWidget);

            Future<void> switchSession() async {
              if (mode == 'same') return;
              await signInAs(ownerB);
              if (mode == 'aba') await signInAs(ownerA);
              await tester.pump();
            }

            if (phase == 'dialog') await switchSession();
            final confirm = find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(
                operation == 'edit' ? FilledButton : TextButton,
                operation == 'edit' ? '保存' : '削除',
              ),
            );
            await tester.ensureVisible(confirm);
            await tester.tap(confirm);
            await tester.pump(const Duration(milliseconds: 300));
            final shouldWrite = phase != 'dialog' || mode == 'same';
            expect(writes, shouldWrite ? 1 : 0);
            if (shouldWrite) {
              expect(
                mutation!.method,
                operation == 'edit' ? 'PATCH' : 'DELETE',
              );
              expect(
                mutation!.url.queryParameters['id'],
                'eq.synthetic-flow-id',
              );
              if (phase != 'dialog') await switchSession();
              await tester.runAsync(() async {
                writeGate.complete();
                await responseSent.future;
                await Future<void>.delayed(const Duration(milliseconds: 100));
              });
            }
            await settleFrame(tester);
            final success = operation == 'edit' ? '収支記録を更新しました' : '収支記録を削除しました';
            expect(
              find.text(success),
              mode == 'same' && !failResponse ? findsOneWidget : findsNothing,
            );
            if (mode != 'same') {
              expect(
                find.textContaining(
                  operation == 'edit' ? '収支記録の更新に失敗しました' : '収支記録の削除に失敗しました',
                ),
                findsNothing,
              );
            } else if (failResponse) {
              expect(
                find.textContaining(
                  operation == 'edit' ? '収支記録の更新に失敗しました' : '収支記録の削除に失敗しました',
                ),
                findsOneWidget,
              );
            }
            expect(writes, shouldWrite ? 1 : 0);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(seconds: 2));
          },
        );
      }
    }
  }
}
