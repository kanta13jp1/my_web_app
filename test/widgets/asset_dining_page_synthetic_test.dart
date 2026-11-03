import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const fixtureBase = 'http://127.0.0.1:18765';
const fixturePassword = 'fixture-password-only';

Future<void> settleSyntheticPage(WidgetTester tester) async {
  // Browser I/O needs real event-loop turns; bounded polling does not infer success.
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> showPage(WidgetTester tester, DateTime today) async {
  await tester.pumpWidget(MaterialApp(
    home: AssetManagementPage(
      debugNow: today,
      debugCalendarNow: today,
      debugInitialAssetData: const {},
    ),
  ));
  await settleSyntheticPage(tester);
}

Future<void> discardPage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 10));
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: fixtureBase,
      publishableKey: 'fixture-publishable-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });

  testWidgets('actual asset page keeps synthetic dining candidate owner-scoped',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final day = find.byKey(Key('asset_calendar_day_${now.day}'));
    final candidate = find.textContaining('飲食店の利用・外食かは要確認');

    // No authenticated user: no private candidate is displayed.
    await showPage(tester, now);
    expect(day, findsOneWidget);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await settleSyntheticPage(tester);
    expect(candidate, findsNothing);
    expect(find.text('外食・飲酒・たばこ購入・読書の振り返り'), findsNothing);
    await discardPage(tester);

    await tester
        .runAsync(() => Supabase.instance.client.auth.signInWithPassword(
              email: 'fixture-a@example.invalid',
              password: fixturePassword,
            ));
    await showPage(tester, now);
    expect(day, findsOneWidget);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await settleSyntheticPage(tester);
    expect(candidate, findsOneWidget);
    expect(
      find.textContaining(
        '支出の内容に「吉野家」という文字があります（飲食店の利用・外食かは要確認）\n'
        '出典: 記録済み支出。外食日数には含みません。',
      ),
      findsOneWidget,
    );
    expect(find.text('${now.month}/${now.day} の振り返り'), findsOneWidget);
    expect(find.text('外食 0日'), findsOneWidget);
    await discardPage(tester);

    // A different synthetic owner receives no flow and cannot see A's candidate.
    await tester
        .runAsync(() => Supabase.instance.client.auth.signInWithPassword(
              email: 'fixture-b@example.invalid',
              password: fixturePassword,
            ));
    await showPage(tester, now);
    expect(day, findsOneWidget);
    await tester.ensureVisible(day);
    await tester.tap(day);
    await settleSyntheticPage(tester);
    expect(find.text('外食・飲酒・たばこ購入・読書の振り返り'), findsOneWidget);
    expect(find.text('${now.month}/${now.day} の振り返り'), findsOneWidget);
    expect(find.text('外食 0日'), findsOneWidget);
    expect(candidate, findsNothing);
    await discardPage(tester);

    final status = await tester.runAsync(() async {
      final response =
          await http.get(Uri.parse('$fixtureBase/__fixture_status'));
      expect(response.statusCode, 200);
      return jsonDecode(response.body) as Map<String, dynamic>;
    });
    expect(status, isNotNull);
    expect(status!['auth'], 2);
    expect(status['flows_a'], greaterThan(0));
    expect(status['flows_b'], greaterThan(0));
    expect(status['reflection_a'], greaterThan(0));
    expect(status['reflection_b'], greaterThan(0));
    expect(status['rejected_writes'], 0);
    expect(status['rejected_identity'], 0);
  });
}
