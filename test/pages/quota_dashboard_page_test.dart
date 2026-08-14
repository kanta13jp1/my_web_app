// R21: AI クォータ監視ページの widget テスト。
// 未計測ツールへの緑「正常」バッジ捏造・$0.00 捏造・アラートバナーの
// 「Claude MAX レート制限」原因決め打ちの回帰を固定する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin/quota_dashboard_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeUser extends Fake implements User {
  @override
  String get id => 'quota-admin-id';
}

class _FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => _FakeUser();
}

class _FakeFunctionResponse extends Fake implements FunctionResponse {
  final dynamic _data;
  _FakeFunctionResponse(this._data);

  @override
  dynamic get data => _data;

  @override
  int get status => 200;
}

class _FakeFunctionsClient extends Fake implements FunctionsClient {
  final List<Map<String, dynamic>> latestRows;
  _FakeFunctionsClient(this.latestRows);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      final body = invocation.namedArguments[#body];
      final action = body is Map ? '${body['action']}' : '';
      if (action == 'quota.latest') {
        return Future.value(
          _FakeFunctionResponse({'success': true, 'data': latestRows}),
        );
      }
      return Future.value(
        _FakeFunctionResponse({'success': true, 'data': <dynamic>[]}),
      );
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  final FunctionsClient _functions;
  _FakeSupabaseClient(this._functions);

  @override
  FunctionsClient get functions => _functions;

  @override
  GoTrueClient get auth => _FakeGoTrueClient();
}

Future<void> _pumpQuotaPage(
  WidgetTester tester,
  List<Map<String, dynamic>> rows,
) async {
  final client = _FakeSupabaseClient(_FakeFunctionsClient(rows));
  await tester.pumpWidget(
    MaterialApp(home: QuotaDashboardPage(supabaseClient: client)),
  );
  await tester.pumpAndSettle();
}

String _today() {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '${now.year}-$m-$d';
}

String _daysAgo(int days) {
  final dt = DateTime.now().subtract(Duration(days: days));
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未計測ツールは「正常」ではなく「未計測」バッジ', (tester) async {
    await _pumpQuotaPage(tester, [
      {
        'tool': 'anthropic',
        'alert': false,
        'checked_at': _today(),
        'usage_json': {'cost_usd': 1.25},
      },
    ]);

    // anthropic のみ計測済み → 正常1 / 残り4ツールは未計測。
    expect(find.text('正常'), findsOneWidget);
    expect(find.text('未計測'), findsNWidgets(4));
    expect(find.text('\$1.25'), findsOneWidget);
  });

  testWidgets('cost_usd 欠落時は \$0.00 を捏造せず「コスト未取得」', (tester) async {
    await _pumpQuotaPage(tester, [
      {
        'tool': 'github_copilot',
        'alert': false,
        'checked_at': _today(),
        'usage_json': {'plan': 'copilot_pro'},
      },
    ]);

    expect(find.text('コスト未取得'), findsOneWidget);
    expect(find.text('\$0.00'), findsNothing);
    expect(find.textContaining('% 使用'), findsNothing);
  });

  testWidgets('古い checked_at は「計測停止?」+経過日数を明示', (tester) async {
    await _pumpQuotaPage(tester, [
      {
        'tool': 'anthropic',
        'alert': false,
        'checked_at': _daysAgo(5),
        'usage_json': {'cost_usd': 0.0},
      },
    ]);

    expect(find.text('計測停止?'), findsOneWidget);
    expect(find.textContaining('計測停止の可能性'), findsOneWidget);
  });

  testWidgets('非Claudeアラートで「Claude MAX」原因を捏造しない', (tester) async {
    await _pumpQuotaPage(tester, [
      {
        'tool': 'hedra',
        'alert': true,
        'checked_at': _today(),
        'usage_json': {'remaining': 10, 'threshold': 50},
      },
    ]);

    expect(find.text('⚠️ クォータアラート'), findsOneWidget);
    expect(
      find.textContaining('Hedra API のクォータが閾値を超えています'),
      findsOneWidget,
    );
    expect(find.textContaining('Claude はファイル種別'), findsNothing);
  });

  testWidgets('Claudeアラート時のみフォールバック表を出す', (tester) async {
    await _pumpQuotaPage(tester, [
      {
        'tool': 'anthropic',
        'alert': true,
        'checked_at': _today(),
        'usage_json': {'cost_usd': 51.0},
      },
    ]);

    expect(find.textContaining('Claude はファイル種別'), findsOneWidget);
    expect(find.textContaining('Gemini Code Assist'), findsOneWidget);
  });
}
