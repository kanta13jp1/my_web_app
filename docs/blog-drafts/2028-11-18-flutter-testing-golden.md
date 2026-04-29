---
title: "Flutter ゴールデンテスト — UI スナップショットで回帰を防ぐ"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter ゴールデンテスト — UI スナップショットで回帰を防ぐ

ゴールデンテストは「期待する UI の画像」を保存し、変更後の描画と自動比較する手法。デザイン崩れを CI で検出できる。

## 基本的なゴールデンテスト

```dart
testWidgets('PricingCard goldentest', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PricingCard(
          plan: PricingPlan(name: 'Pro', price: 2980, highlight: true),
        ),
      ),
    ),
  );

  await expectLater(
    find.byType(PricingCard),
    matchesGoldenFile('goldens/pricing_card_pro.png'),
  );
});
```

初回実行 (`flutter test --update-goldens`) で PNG が生成される。以降は差分が出ると失敗。

## ゴールデンファイルの管理

```bash
# 初回 / デザイン変更時: ゴールデンを更新
flutter test --update-goldens test/widget/pricing_card_test.dart

# CI: 更新なしで差分チェック
flutter test test/widget/pricing_card_test.dart
```

## テーマ・ダークモード別テスト

```dart
Future<void> pumpWithTheme(
  WidgetTester tester,
  Widget widget, {
  ThemeMode mode = ThemeMode.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: Scaffold(body: widget),
    ),
  );
  await tester.pumpAndSettle();
}

testWidgets('PricingCard dark mode golden', (tester) async {
  await pumpWithTheme(
    tester,
    PricingCard(plan: PricingPlan(name: 'Pro', price: 2980, highlight: true)),
    mode: ThemeMode.dark,
  );
  await expectLater(
    find.byType(PricingCard),
    matchesGoldenFile('goldens/pricing_card_pro_dark.png'),
  );
});
```

## CI (GitHub Actions) でゴールデンテスト実行

```yaml
- name: Run golden tests
  run: flutter test test/widget/ --reporter github
  env:
    FLUTTER_TEST_GOLDEN: "true"

- name: Upload golden diff on failure
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: golden-failures
    path: test/failures/
```

## まとめ

```
初回         → flutter test --update-goldens でスナップショット生成
CI           → 差分検出 → test/failures/ に diff 画像保存
ダークモード → ThemeMode.dark バリアントも別ファイルで管理
運用         → デザイン変更時のみ --update-goldens 実行
```

ゴールデンテストは「目で確認していた UI 品質を自動化する」最もシンプルな方法。まず1つのコアコンポーネントから始めるのがおすすめ。
