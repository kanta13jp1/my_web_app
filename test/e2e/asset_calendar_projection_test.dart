import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_calendar_reflection_repository.dart';
import 'package:my_web_app/widgets/asset_calendar_reflection_panel.dart';

class _ReadOnlyStore implements AssetCalendarReflectionStore {
  _ReadOnlyStore([this.events = const []]);
  final List<AssetCalendarReflection> events;

  @override
  Future<List<AssetCalendarReflection>> load(
          DateTime start, DateTime end) async =>
      events;

  @override
  Future<void> import(List<AssetCalendarReflection> events) async {
    throw StateError('unexpected import');
  }
}

Map<String, dynamic> _flow(String description) => {
      'id': 333,
      'occurred_at': '2026-01-02T12:00:00',
      'action_type': 'expense',
      'description': description,
      'amount': 1000,
    };

Future<void> _showPanel(
  WidgetTester tester,
  String description, {
  List<AssetCalendarReflection> recorded = const [],
}) async {
  final projected = AssetCalendarReflection.fromFlows([_flow(description)]);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: AssetCalendarReflectionPanel(
            repository: _ReadOnlyStore(recorded),
            start: DateTime(2026, 1, 1),
            end: DateTime(2026, 2, 1),
            selectedDate: DateTime(2026, 1, 2),
            flowEvents: projected,
            onLoaded: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('denied drinking is shown as dining with its source',
      (tester) async {
    await _showPanel(tester, '外食、飲酒なし');
    expect(find.text('外食 1日'), findsOneWidget);
    expect(find.text('外飲み 0日'), findsOneWidget);
    expect(find.textContaining('外食: 外食、飲酒なし'), findsOneWidget);
    expect(find.textContaining('出典: 記録済み支出の明示された内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a separate affirmative drink remains visible', (tester) async {
    await _showPanel(tester, '外食、飲酒なし、ビールを飲んだ');
    expect(find.text('外食 1日'), findsOneWidget);
    expect(find.text('外飲み 1日'), findsOneWidget);
    expect(find.textContaining('外食・外飲み: 外食、飲酒なし、ビールを飲んだ'), findsOneWidget);
    expect(find.textContaining('出典: 記録済み支出の明示された内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a separate recorded source stays visible', (tester) async {
    await _showPanel(
      tester,
      '外食、ビール購入のみ',
      recorded: [
        AssetCalendarReflection(
          sourceKey: 'diary:synthetic',
          date: DateTime(2026, 1, 2),
          kinds: const {AssetReflectionKind.reading},
          title: '架空の読書記録',
          sourceLabel: '架空の日記',
        ),
      ],
    );
    expect(find.text('外飲み 0日'), findsOneWidget);
    expect(find.text('読書 1日'), findsOneWidget);
    expect(find.text('酒購入 1日'), findsOneWidget);
    expect(find.textContaining('外食・酒購入: 外食、ビール購入のみ'), findsOneWidget);
    expect(find.textContaining('出典: 架空の日記'), findsOneWidget);
    expect(find.textContaining('出典: 記録済み支出の明示された内容'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
