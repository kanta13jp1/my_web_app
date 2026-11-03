import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';
import 'package:my_web_app/services/asset_calendar_reflection_repository.dart';
import 'package:my_web_app/widgets/asset_calendar_reflection_panel.dart';

class _FixtureStore implements AssetCalendarReflectionStore {
  @override
  Future<void> import(List<AssetCalendarReflection> events) async =>
      throw StateError('fixture must not save');

  @override
  Future<List<AssetCalendarReflection>> load(
          DateTime start, DateTime end) async =>
      [];
}

class _Fixture extends StatefulWidget {
  const _Fixture();
  @override
  State<_Fixture> createState() => _FixtureState();
}

class _FixtureState extends State<_Fixture> {
  DateTime selected = DateTime(2026, 9, 20);
  bool rejected = false;
  final repository = _FixtureStore();
  @override
  Widget build(BuildContext context) {
    final flows = <Map<String, dynamic>>[
      {
        'id': 1,
        'occurred_at': '2026-09-20T12:00:00',
        'action_type': 'expense',
        'description': rejected ? '吉野家 持ち帰り' : '吉野家 食事',
        'amount': 1000,
      },
    ];
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              TextButton(
                onPressed: () =>
                    setState(() => selected = DateTime(2026, 9, 20)),
                child: const Text('9月20日'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => selected = DateTime(2026, 9, 21)),
                child: const Text('9月21日'),
              ),
              TextButton(
                onPressed: () => setState(() => rejected = !rejected),
                child: const Text('持ち帰りの例を表示'),
              ),
              AssetCalendarReflectionPanel(
                repository: repository,
                start: DateTime(2026, 9),
                end: DateTime(2026, 10),
                selectedDate: selected,
                onLoaded: (_) {},
                diningReviewCandidates:
                    AssetDiningReviewCandidate.fromOwnedFlows(
                  currentOwner: 'fixture-owner',
                  flowsOwner: 'fixture-owner',
                  reading: false,
                  failed: false,
                  flows: flows,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  print('diagnostic: fixture main reached');
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('選択日と利用形態に応じ未確定の候補のみを表示する', (tester) async {
    print('diagnostic: fixture assertion started');
    await tester.pumpWidget(const _Fixture());
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsOneWidget);
    expect(find.text('外食 0日'), findsOneWidget);
    expect(find.textContaining('表示期間の確認済み金額 0円'), findsOneWidget);

    await tester.tap(find.text('9月21日'));
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsNothing);

    await tester.tap(find.text('9月20日'));
    await tester.tap(find.text('持ち帰りの例を表示'));
    await tester.pumpAndSettle();
    expect(find.textContaining('外食かは要確認'), findsNothing);
    expect(find.text('外食 0日'), findsOneWidget);
    expect(find.textContaining('表示期間の確認済み金額 0円'), findsOneWidget);
  });
}
