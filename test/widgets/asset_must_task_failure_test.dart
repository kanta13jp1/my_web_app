import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/pages/asset_management_page.dart';
import 'package:my_web_app/services/asset_must_task_repository.dart';

class FakeTasks implements AssetMustTaskRepository {
  bool fail = false;
  final rows = <Map<String, dynamic>>[
    {
      'id': 'one',
      'title': 'Synthetic original',
      'deadline': '2026-10-25T00:00:00Z',
      'is_completed': false,
    },
  ];
  @override
  Future<List<Map<String, dynamic>>> load() async {
    if (fail) throw StateError('offline');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<void> add(String title, DateTime deadline) async {
    if (fail) throw StateError('offline');
    rows.add({
      'id': 'two',
      'title': title,
      'deadline': deadline.toIso8601String(),
      'is_completed': false,
    });
  }

  @override
  Future<void> setCompleted(String id, bool completed) async {
    if (fail) throw StateError('offline');
    rows.singleWhere((r) => r['id'] == id)['is_completed'] = completed;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:9999',
      publishableKey: 'test-key',
      authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
    );
  });
  testWidgets(
      'failed add retains input and failed toggle retains original state; retry recovers',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeTasks();
    await tester.pumpWidget(MaterialApp(
        home: AssetManagementPage(debugMustTaskRepository: repository,),),);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final original =
        find.widgetWithText(CheckboxListTile, 'Synthetic original');
    expect(original, findsOneWidget);
    repository.fail = true;
    await tester.ensureVisible(original);
    await tester.tap(original);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<CheckboxListTile>(original).value, false);
    expect(find.textContaining('完了状態の保存を確認できませんでした。'), findsOneWidget);
    final add = find.text('タスクを追加');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField),);
    await tester.enterText(field, 'Synthetic new');
    final save = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, '追加'),);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'Synthetic new');
    expect(find.textContaining('保存を確認できませんでした。入力を保持'), findsOneWidget);
    expect(repository.rows.length, 1);
    repository.fail = false;
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Synthetic new'), findsOneWidget);
    await tester.ensureVisible(original);
    await tester.tap(original);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<CheckboxListTile>(original).value, true);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });
}
