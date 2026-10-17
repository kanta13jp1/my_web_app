import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_recurring_tombstone_sync_service.dart';
import 'package:my_web_app/services/asset_sync_dirty_keys_store.dart';
import 'package:my_web_app/widgets/expense_classification_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final requests = <http.Request>[];
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'synthetic-publishable-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('[]', 200, headers: {'content-type': 'application/json'});
      }),
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());

  testWidgets('actual flow controllers survive focus, suggestions, source, type and date changes without saving', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'asset_management_display_mode_v1': 'full'});
    AssetSyncDirtyKeysStore.resetWriteLockForTest();
    AssetRecurringTombstoneSyncService.resetSharedForTest();
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: AssetManagementPage(initialFocus: AssetManagementInitialFocus.flow)));
    await tester.pumpAndSettle();
    Finder field(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);
    final memo = field('内容');
    final amount = field('金額 (円)');
    final memoController = tester.widget<TextField>(memo).controller!;
    final amountController = tester.widget<TextField>(amount).controller!;
    const text = 'Synthetic probe コーヒー';
    void retained() {
      expect(memoController.text, text);
      expect(amountController.text, '1234');
      expect(tester.widget<TextField>(amount).controller, same(amountController));
    }
    await tester.ensureVisible(memo);
    await tester.enterText(memo, text);
    await tester.pumpAndSettle();
    expect(tester.widget<ExpenseClassificationReview>(find.byType(ExpenseClassificationReview)).memo, text);
    await tester.ensureVisible(amount);
    await tester.enterText(amount, '1234');
    await tester.pumpAndSettle();
    retained();
    await tester.ensureVisible(memo);
    await tester.tap(memo);
    await tester.pumpAndSettle();
    retained();
    final source = find.ancestor(of: find.text('入出金元'), matching: find.byType(DropdownButtonFormField<String>));
    await tester.ensureVisible(source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    await tester.tap(find.text('銀行口座').last);
    await tester.pumpAndSettle();
    retained();
    final type = find.byKey(const Key('asset_flow_type_dropdown'));
    for (final value in ['収入', '振替', '支出']) {
      await tester.ensureVisible(type);
      await tester.tap(type);
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last);
      await tester.pumpAndSettle();
      retained();
      final activeMemo = field(value == '振替' ? 'メモ（任意）' : '内容');
      expect(tester.widget<TextField>(activeMemo).controller, same(memoController));
    }
    final flowCard = find.ancestor(of: type, matching: find.byType(Card)).first;
    final dateIcon = find.descendant(of: flowCard, matching: find.byIcon(Icons.calendar_today)).first;
    await tester.ensureVisible(dateIcon);
    await tester.tap(dateIcon);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    retained();
    expect(Supabase.instance.client.auth.currentUser, isNull);
    expect(requests.where((r) => !['GET', 'HEAD'].contains(r.method)), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
