import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/data/repositories/custom_task_list_repository.dart';
import 'package:my_web_app/data/services/custom_task_list_ai_service.dart';
import 'package:my_web_app/data/services/custom_task_list_store.dart';
import 'package:my_web_app/domain/models/custom_task_list.dart';
import 'package:my_web_app/ui/features/custom_task_list/custom_task_list_feature.dart';

void main() {
  testWidgets('generates and lets the user complete, edit, and delete tasks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final viewModel = _buildViewModel();

    await tester.pumpWidget(
      MaterialApp(home: CustomTaskListPage(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('custom_task_compact_layout')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('custom_task_goal_field')),
      '引っ越し準備を終える',
    );
    await tester.enterText(
      find.byKey(const Key('custom_task_situation_field')),
      '平日は30分だけ使える',
    );
    final generateButton = find.byKey(const Key('custom_task_generate_button'));
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(viewModel.items, hasLength(3));
    expect(find.text('荷物を部屋別に数える'), findsOneWidget);
    expect(find.text('0 / 3 完了'), findsOneWidget);

    final firstId = viewModel.items.first.id;
    final firstCheckbox = find.byKey(Key('custom_task_checkbox_$firstId'));
    await tester.ensureVisible(firstCheckbox);
    await tester.tap(firstCheckbox);
    await tester.pump();
    expect(find.text('1 / 3 完了'), findsOneWidget);

    final secondId = viewModel.items[1].id;
    final editButton = find.byKey(Key('custom_task_edit_$secondId'));
    await tester.ensureVisible(editButton);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('custom_task_edit_field')),
      '見積もりを2社へ依頼する',
    );
    await tester.tap(find.byKey(const Key('custom_task_edit_save_button')));
    await tester.pumpAndSettle();
    expect(find.text('見積もりを2社へ依頼する'), findsOneWidget);

    final thirdId = viewModel.items.last.id;
    final deleteButton = find.byKey(Key('custom_task_delete_$thirdId'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(viewModel.items, hasLength(2));
  });

  testWidgets('uses a side-by-side layout on a wide window', (tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: CustomTaskListPage(viewModel: _buildViewModel())),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('custom_task_wide_layout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows validation feedback when both inputs are empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CustomTaskListPage(viewModel: _buildViewModel())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('custom_task_generate_button')));
    await tester.pump();

    expect(find.byKey(const Key('custom_task_error_message')), findsOneWidget);
    expect(find.text('目標または現状を入力してください。'), findsOneWidget);
  });
}

CustomTaskListViewModel _buildViewModel() {
  return CustomTaskListViewModel(
    repository: CustomTaskListRepositoryImpl(
      generator: const _WidgetTestGenerator(),
      store: _WidgetTestStore(),
      now: () => DateTime.utc(2026, 8, 24, 13),
    ),
  );
}

class _WidgetTestGenerator implements CustomTaskListGenerator {
  const _WidgetTestGenerator();

  @override
  Future<GeneratedCustomTaskList> generate({
    required String goal,
    required String situation,
  }) async {
    return const GeneratedCustomTaskList(
      taskTitles: <String>['荷物を部屋別に数える', '引っ越し業者へ見積もりを依頼する', '不要品を3箱に分類する'],
      source: 'test-ai',
    );
  }
}

class _WidgetTestStore implements CustomTaskListStore {
  CustomTaskListSnapshot? snapshot;

  @override
  Future<CustomTaskListSnapshot?> load() async => snapshot;

  @override
  Future<void> save(CustomTaskListSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}
