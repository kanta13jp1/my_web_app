---
title: "Flutter Web アクセシビリティ完全ガイド — WCAG 2.2・Semantics・スクリーンリーダー対応"
tags: Flutter,accessibility,webdev,個人開発
published: true
---

アクセシビリティ対応はユーザー全員にとって使いやすいアプリを作るための基礎です。Flutter Web で WCAG 2.2 に準拠し、スクリーンリーダー対応・キーボードナビゲーション・コントラスト比を正しく実装する方法を解説します。

## なぜFlutter Webでアクセシビリティが難しいのか

Flutter Web は Canvas/DOM ハイブリッドレンダリングのため、通常の HTML とは異なるアクセシビリティツリーの扱いが必要です。

- CanvasKit モード: 独自の Semantics tree → `aria-label` 相当の情報を Flutter 側で明示
- HTML モード: 一部 widget が自動的にセマンティクスを付与するが不完全

## Semantics ウィジェット基礎

```dart
Semantics(
  label: '送信ボタン',
  hint: 'フォームを送信します',
  button: true,
  child: ElevatedButton(
    onPressed: _submit,
    child: const Text('送信'),
  ),
)
```

## WCAG 2.2 チェックリスト (Flutter Web版)

| 基準 | Flutter対応 | 実装方法 |
|------|------------|---------|
| 1.1.1 代替テキスト | `Semantics(label:)` | 全画像・アイコンに必須 |
| 1.4.3 コントラスト比 4.5:1 | `ThemeData` カラー設計 | `ColorScheme` で定義 |
| 2.1.1 キーボード操作 | `Focus` ウィジェット | `FocusTraversalGroup` |
| 2.4.7 フォーカス可視化 | `focusColor` 設定 | ボーダー表示 |
| 4.1.2 名前・役割・値 | `Semantics` 詳細設定 | `role`, `value` 明示 |

## コントラスト比の計算と設定

```dart
// Design token でコントラスト比を保証
const Color _primaryText = Color(0xFF1A1A1A); // on white: 17.1:1
const Color _hintText = Color(0xFF767676);    // on white: 4.54:1 (WCAG AA)

ThemeData accessibleTheme() {
  return ThemeData(
    colorScheme: const ColorScheme.light(
      onSurface: _primaryText,
      onSurfaceVariant: _hintText,
    ),
  );
}
```

## キーボードナビゲーション

```dart
FocusTraversalGroup(
  policy: OrderedTraversalPolicy(),
  child: Column(
    children: [
      FocusTraversalOrder(
        order: const NumericFocusOrder(1),
        child: TextField(decoration: InputDecoration(labelText: 'メール')),
      ),
      FocusTraversalOrder(
        order: const NumericFocusOrder(2),
        child: TextField(
          decoration: InputDecoration(labelText: 'パスワード'),
          obscureText: true,
        ),
      ),
      FocusTraversalOrder(
        order: const NumericFocusOrder(3),
        child: ElevatedButton(onPressed: _login, child: const Text('ログイン')),
      ),
    ],
  ),
)
```

## スクリーンリーダー対応 (NVDA/VoiceOver)

```dart
// ライブリージョン: 動的コンテンツをアナウンス
Semantics(
  liveRegion: true,
  child: Text(_statusMessage),
)

// 画像の代替テキスト
Image.asset(
  'assets/chart.png',
  semanticLabel: '2024年売上グラフ: 前年比120%',
)

// アイコンボタン
IconButton(
  icon: const Icon(Icons.delete),
  tooltip: '削除',  // tooltip が semantics label になる
  onPressed: _delete,
)
```

## Flutter Web 特有の注意点

### ExcludeSemantics

装飾的な要素はスクリーンリーダーから除外:

```dart
ExcludeSemantics(
  child: Icon(Icons.star, color: Colors.amber), // 装飾的な星アイコン
)
```

### SemanticsService でアナウンス

```dart
SemanticsService.announce('保存完了しました', TextDirection.ltr);
```

## アクセシビリティ自動テスト

```dart
testWidgets('ログインフォーム アクセシビリティ', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: LoginPage()));

  // Semantics ツリー確認
  final SemanticsHandle handle = tester.ensureSemantics();
  
  expect(
    tester.getSemantics(find.byType(TextField).first),
    matchesSemantics(label: 'メール'),
  );
  
  handle.dispose();
});
```

## まとめ

Flutter Web でのアクセシビリティ対応は、`Semantics` ウィジェット・`ThemeData` カラー設計・`FocusTraversalGroup` の3本柱で実現できます。WCAG 2.2 準拠はユーザビリティ向上と法的リスク回避の両方に効果的です。

次回は Supabase Edge Functions の高度な活用 (ストリーミング・WebSocket・バックグラウンドジョブ) を解説します。
