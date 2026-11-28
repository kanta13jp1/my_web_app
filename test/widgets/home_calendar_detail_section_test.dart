import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/widgets/home_calendar_detail_section.dart';

Widget _wrapAt360x800({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: Colors.indigo,
    ),
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        textScaler: TextScaler.linear(2.0),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders title and bulleted items at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        child: const HomeCalendarDetailSection(
          title: '本日のタスク',
          accent: Color(0xFF2563EB),
          items: <String>['家計簿を記録する', '固定費を見直す'],
          emptyLabel: '登録されたタスクはありません',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本日のタスク'), findsOneWidget);
    expect(find.text('・家計簿を記録する'), findsOneWidget);
    expect(find.text('・固定費を見直す'), findsOneWidget);
    expect(find.text('登録されたタスクはありません'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty label in dark mode at 360x800 2.0x',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapAt360x800(
        brightness: Brightness.dark,
        child: const HomeCalendarDetailSection(
          title: '完了した予定',
          accent: Color(0xFF059669),
          items: <String>[],
          emptyLabel: 'この日の完了予定はありません',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('完了した予定'), findsOneWidget);
    expect(find.text('この日の完了予定はありません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
