import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_calendar_reflection_repository.dart';
import 'package:my_web_app/widgets/asset_calendar_reflection_panel.dart';
import 'package:my_web_app/widgets/asset_reflection_day_badge.dart';

class FakeRepository extends AssetCalendarReflectionRepository {
  FakeRepository(super.client);
  int loads = 0;
  @override
  Future<List<AssetCalendarReflection>> load(DateTime start, DateTime end) async {
    loads++;
    return [AssetCalendarReflection(sourceKey: 'test:reading', date: DateTime(2026, 1, 3),
      kinds: {AssetReflectionKind.reading}, title: 'Test book', sourceLabel: 'Test diary',
      memo: 'Confirmed reading memo', pages: 12)];
  }
}
void main() {
  testWidgets('badges distinguish drinking dining and reading using words and color', (tester) async {
    final kinds = {AssetReflectionKind.dining, AssetReflectionKind.drinkingOut, AssetReflectionKind.reading};
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 60, height: 84,
      child: AssetReflectionDayBadge(kinds: kinds)))));
    expect(find.text('外食\n外飲み\n読書'), findsOneWidget);
    expect(AssetReflectionDayBadge.backgroundFor(kinds), const Color(0xFFFECACA));
    expect(AssetReflectionDayBadge.backgroundFor({AssetReflectionKind.reading}), const Color(0xFFBBF7D0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('selected day reading detail and period changes stay scoped', (tester) async {
    final client = SupabaseClient('http://localhost', 'test-key');
    addTearDown(client.dispose);
    final repository = FakeRepository(client);
    Widget app(DateTime selected, DateTime start) => MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: AssetCalendarReflectionPanel(repository: repository, start: start, end: DateTime(2026, 2),
        selectedDate: selected, onLoaded: (_) {}))));
    await tester.pumpWidget(app(DateTime(2026, 1, 2), DateTime(2026, 1)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmed reading memo'), findsNothing);
    await tester.pumpWidget(app(DateTime(2026, 1, 3), DateTime(2026, 1)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Confirmed reading memo'), findsOneWidget);
    expect(find.textContaining('12ページ'), findsOneWidget);
    expect(find.textContaining('0分'), findsNothing);
    expect(repository.loads, 1);
    await tester.pumpWidget(app(DateTime(2026, 1, 3), DateTime(2025, 12, 25)));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(tester.takeException(), isNull);
  });
}
