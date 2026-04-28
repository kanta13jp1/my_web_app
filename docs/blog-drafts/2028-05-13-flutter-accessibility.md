---
title: "Flutter アクセシビリティ対応 — Semantics / スクリーンリーダー / WCAG"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter アクセシビリティ対応 — Semantics / スクリーンリーダー / WCAG

アクセシビリティ対応は「特別な機能」ではなく「品質の基準」。

## Semantics: スクリーンリーダーへの情報提供

```dart
// Bad: アイコンボタンに意味がない
IconButton(
  icon: const Icon(Icons.favorite),
  onPressed: () => _toggleFavorite(),
);

// Good: semanticLabel でスクリーンリーダーが読み上げる内容を指定
IconButton(
  icon: const Icon(Icons.favorite),
  onPressed: () => _toggleFavorite(),
  tooltip: 'お気に入りに追加',  // これがそのまま semanticLabel になる
);

// カスタムウィジェットには Semantics を明示
Semantics(
  label: '進捗: 75%',
  value: '75',
  child: LinearProgressIndicator(value: 0.75),
);

// 装飾目的の画像は excludeFromSemantics
Image.asset(
  'assets/decorative_banner.png',
  excludeFromSemantics: true,  // スクリーンリーダーがスキップ
);
```

## フォーカス管理

```dart
// フォームのフォーカス順序を制御
class _LoginFormState extends State<LoginForm> {
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          focusNode: _emailFocus,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordFocus.requestFocus(),
          decoration: const InputDecoration(label: Text('メールアドレス')),
        ),
        TextField(
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          obscureText: true,
          decoration: const InputDecoration(label: Text('パスワード')),
        ),
      ],
    );
  }
}
```

## コントラスト比: WCAG AA 準拠

```dart
// WCAG AA: 通常テキスト 4.5:1 以上 / 大テキスト 3:1 以上

// Bad: コントラスト不足 (グレーの薄いテキスト)
Text(
  '補足説明',
  style: TextStyle(color: Color(0xFFAAAAAA)),  // コントラスト比 約 2.3:1
);

// Good: 十分なコントラスト
Text(
  '補足説明',
  style: TextStyle(color: Color(0xFF767676)),  // コントラスト比 4.5:1 (白背景)
);

// Flutter の AccessibilityFeatures で端末設定を取得
final features = MediaQuery.of(context).accessibilityFeatures;
if (features.highContrast) {
  // ハイコントラストモード対応
}
```

## タッチターゲット: 最小 48×48 dp

```dart
// Bad: 小さすぎるボタン
InkWell(
  onTap: () {},
  child: const Icon(Icons.close, size: 16),  // タップしにくい
);

// Good: SizedBox で最小サイズを確保
SizedBox(
  width: 48,
  height: 48,
  child: InkWell(
    onTap: () {},
    child: const Center(
      child: Icon(Icons.close, size: 16),
    ),
  ),
);
```

## アクセシビリティ検査

```bash
# Flutter accessibility scanner
flutter test --tags accessibility

# デバッグモードで Semantics ツリーを確認
# DevTools > Accessibility タブ
```

```dart
// テストでアクセシビリティを検証
testWidgets('ログインボタンに semantic label がある', (tester) async {
  await tester.pumpWidget(const MyApp());
  expect(
    tester.getSemantics(find.byType(ElevatedButton)),
    matchesSemantics(label: 'ログイン', isButton: true),
  );
});
```

## まとめ

```
Semantics     → label/value で読み上げ内容を明示
フォーカス管理 → FocusNode + textInputAction で Tab 順序を制御
コントラスト  → 通常テキスト 4.5:1 / 大テキスト 3:1 (WCAG AA)
タッチ        → 最小 48×48 dp (Material Design 推奨)
```

VoiceOver / TalkBack で実機テストするのが最も確実。
