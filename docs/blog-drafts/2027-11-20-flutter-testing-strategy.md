---
title: "Flutter テスト完全戦略 — Unit / Widget / Integration / Golden Test"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter テスト完全戦略 — Unit / Widget / Integration / Golden Test

「テストを書く時間がない」と「バグで時間を失う」のどちらが損か。4種のテストの使い分けを解説する。

## テストピラミッド

```
       /Golden\        ← 少数 (UIスナップショット)
      /Integration\    ← 中程度 (実際の画面フロー)
     /  Widget    \    ← 多め (ウィジェット単体)
    /    Unit      \   ← 最多 (ビジネスロジック)
```

## Unit Test: ロジックの正確性を保証

```dart
// test/services/kpi_calculator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/kpi_calculator.dart';

void main() {
  group('KpiCalculator', () {
    test('calculates DAU/MAU ratio correctly', () {
      final calc = KpiCalculator();
      expect(calc.dauMauRatio(dau: 100, mau: 500), equals(0.20));
    });

    test('returns 0 when MAU is 0', () {
      final calc = KpiCalculator();
      expect(calc.dauMauRatio(dau: 0, mau: 0), equals(0.0));
    });

    test('MRR growth rate is calculated correctly', () {
      final calc = KpiCalculator();
      // 10000 → 12000 = 20% growth
      expect(calc.mrrGrowthRate(previous: 10000, current: 12000), equals(0.20));
    });
  });
}
```

**実行**:

```bash
flutter test test/services/kpi_calculator_test.dart
```

## Widget Test: UIコンポーネントを単体でテスト

```dart
// test/widgets/kpi_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/kpi_card.dart';

void main() {
  testWidgets('KpiCard shows title and value', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KpiCard(
          title: 'MAU',
          value: '1,234',
          trend: 0.15,
        ),
      ),
    );

    expect(find.text('MAU'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('+15%'), findsOneWidget);  // trend表示
  });

  testWidgets('KpiCard shows negative trend in red', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: KpiCard(title: 'Churn', value: '5%', trend: -0.03),
      ),
    );

    final trendText = tester.widget<Text>(find.text('-3%'));
    expect(trendText.style?.color, equals(Colors.red));
  });
}
```

**Riverpod の Provider をモック**:

```dart
// Riverpod の ProviderScope でオーバーライド
testWidgets('shows user profile from provider', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) => Future.value(Profile(id: '1', username: 'test_user')),
        ),
      ],
      child: const MaterialApp(home: ProfilePage()),
    ),
  );

  await tester.pump();
  expect(find.text('test_user'), findsOneWidget);
});
```

## Integration Test: 実際の画面フローをテスト

```dart
// integration_test/login_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login with magic link flow', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // メールフォームに入力
    await tester.enterText(
      find.byKey(const Key('email_field')),
      'test@example.com',
    );

    // 送信ボタンをタップ
    await tester.tap(find.byKey(const Key('send_magic_link_button')));
    await tester.pumpAndSettle();

    // 成功メッセージを確認
    expect(find.text('メールを送信しました'), findsOneWidget);
  });
}
```

**CI での実行**:

```yaml
# .github/workflows/ci.yml
- name: Run integration tests (Chrome)
  run: |
    flutter test integration_test/ \
      -d chrome \
      --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
      --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

## Golden Test: UIスナップショットで見た目を保護

```dart
// test/golden/kpi_dashboard_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

void main() {
  testGoldens('KpiDashboard looks correct', (tester) async {
    await tester.pumpWidgetBuilder(
      const KpiDashboard(),
      surfaceSize: const Size(375, 812),  // iPhone 12 サイズ
    );

    await screenMatchesGolden(tester, 'kpi_dashboard');
    // 初回実行: goldens/kpi_dashboard.png が生成される
    // 2回目以降: 前回の PNG と比較 → 差分があればテスト失敗
  });
}
```

**Golden ファイルの更新**:

```bash
# UIデザインを変更した後に Golden を更新
flutter test --update-goldens test/golden/
```

## テスト戦略の選び方

```
ビジネスロジック (計算・変換・バリデーション) → Unit
ウィジェット単体の表示・インタラクション       → Widget
画面遷移・フォーム送信・API連携               → Integration
デザイン崩れの防止                           → Golden
```

**個人開発での推奨割合**:

```
Unit:        60% (ロジックが最も崩れやすい)
Widget:      25% (コアコンポーネントのみ)
Integration: 10% (ハッピーパスのみ)
Golden:       5% (LP・重要画面のみ)
```

テストは「書く時間」より「バグ修正の時間」を節約する投資。Unit Test から始めて、リグレッションが起きた箇所から段階的に拡充する。

