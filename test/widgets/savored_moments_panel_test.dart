import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/domain/models/savored_moment.dart';
import 'package:my_web_app/view_models/savored_moment_view_model.dart';
import 'package:my_web_app/widgets/savored_moments_panel.dart';

import '../view_models/savored_moment_view_model_test.dart'
    show MemorySavoredMomentRepository;

void main() {
  SavoredMomentViewModel viewModelFor(
    MemorySavoredMomentRepository repository, {
    String? userId = 'user-1',
  }) {
    return SavoredMomentViewModel(
      repository: repository,
      userId: userId,
      clock: () => DateTime(2026, 11, 17, 21),
    );
  }

  Future<void> pump(WidgetTester tester, SavoredMomentViewModel vm) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 2000);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SavoredMomentsPanel(viewModel: vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('writing one line saves it and clears the field', (
    tester,
  ) async {
    final repository = MemorySavoredMomentRepository();
    final vm = viewModelFor(repository);
    addTearDown(vm.dispose);
    await vm.load();
    await pump(tester, vm);

    expect(find.text('今日、お金を使わずに味わえたこと'), findsOneWidget);
    expect(find.textContaining('点数も分析もつけず'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('savored-moments-input')),
      '夕焼けがきれいだった',
    );
    await tester.tap(find.byKey(const Key('savored-moments-save')));
    await tester.pumpAndSettle();

    expect(repository.lastNote, '夕焼けがきれいだった');
    expect(find.text('夕焼けがきれいだった'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('savored-moments-input')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('a blank line is not saved', (tester) async {
    final repository = MemorySavoredMomentRepository();
    final vm = viewModelFor(repository);
    addTearDown(vm.dispose);
    await vm.load();
    await pump(tester, vm);

    await tester.enterText(
      find.byKey(const Key('savored-moments-input')),
      '   ',
    );
    await tester.tap(find.byKey(const Key('savored-moments-save')));
    await tester.pumpAndSettle();

    expect(repository.addCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('recalls a few past moments as written, with no metrics', (
    tester,
  ) async {
    final repository = MemorySavoredMomentRepository()
      ..stored.add(
        SavoredMoment(
          id: 1,
          note: '散歩中に金木犀の匂いがした',
          momentDate: DateTime(2026, 11, 15),
          createdAt: DateTime(2026, 11, 15, 18),
        ),
      );
    final vm = viewModelFor(repository);
    addTearDown(vm.dispose);
    await vm.load();
    await pump(tester, vm);

    expect(find.text('最近のあなたが味わえたこと'), findsOneWidget);
    expect(find.text('11/15  散歩中に金木犀の匂いがした'), findsOneWidget);
    expect(find.textContaining('件'), findsNothing);
    expect(find.textContaining('連続'), findsNothing);
  });

  testWidgets('says so when the history could not be read', (tester) async {
    final repository = MemorySavoredMomentRepository()..failLoad = true;
    final vm = viewModelFor(repository);
    addTearDown(vm.dispose);
    await vm.load();
    await pump(tester, vm);

    expect(
      find.byKey(const Key('savored-moments-load-failed')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('savored-moments-input')), findsOneWidget);
  });

  testWidgets('a failed save shows the message and keeps the text', (
    tester,
  ) async {
    final repository = MemorySavoredMomentRepository();
    final vm = viewModelFor(repository);
    addTearDown(vm.dispose);
    await vm.load();
    await pump(tester, vm);
    repository.failAdd = true;

    await tester.enterText(
      find.byKey(const Key('savored-moments-input')),
      '星が見えた',
    );
    await tester.tap(find.byKey(const Key('savored-moments-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('保存できませんでした'), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const Key('savored-moments-input')),
    );
    expect(field.controller!.text, '星が見えた');
  });

  testWidgets('asks to sign in when signed out', (tester) async {
    final repository = MemorySavoredMomentRepository();
    final vm = viewModelFor(repository, userId: null);
    addTearDown(vm.dispose);
    await pump(tester, vm);

    expect(find.text('ログインすると、味わえたことを残せます。'), findsOneWidget);
    expect(find.byKey(const Key('savored-moments-input')), findsNothing);
  });
}
