---
title: "Flutter アクセシビリティ — Semantics・スクリーンリーダー・WCAG 対応"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter アクセシビリティ — Semantics・スクリーンリーダー・WCAG 対応

アクセシビリティ対応はユーザー体験の土台。Flutter の Semantics ウィジェットで screen reader や高コントラストモードに対応する方法をまとめる。

## Semantics ウィジェット基礎

```dart
// ボタンにスクリーンリーダー用ラベルを付与
Semantics(
  label: '送信ボタン',
  hint: 'フォームを送信します',
  button: true,
  child: ElevatedButton(
    onPressed: _submit,
    child: const Text('送信'),
  ),
)

// 画像の代替テキスト
Semantics(
  label: 'ユーザーアバター画像',
  image: true,
  child: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
)

// 装飾的な要素は TalkBack/VoiceOver からスキップ
ExcludeSemantics(
  child: Icon(Icons.star, color: Colors.amber),
)
```

## カスタムアクション (スワイプ操作)

```dart
Semantics(
  customSemanticsActions: {
    CustomSemanticsAction(label: '削除'): () => _deleteItem(item.id),
    CustomSemanticsAction(label: 'アーカイブ'): () => _archiveItem(item.id),
  },
  child: ListTile(title: Text(item.title)),
)
```

## コントラスト比チェック

```dart
// WCAG AA: 4.5:1 以上 (通常テキスト) / 3:1 以上 (大テキスト)
// MaterialApp でハイコントラストテーマを提供
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  ),
  highContrastTheme: ThemeData(
    colorScheme: const ColorScheme.highContrast(),
  ),
  home: const MyHomePage(),
)
```

## アクセシビリティテスト

```dart
testWidgets('Submit button has correct semantics', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: MyForm()));

  final semantics = tester.getSemantics(find.text('送信'));
  expect(semantics.label, contains('送信'));
  expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
  semantics.dispose();
});
```

## まとめ

```
Semantics       → label/hint/button/image フラグで screen reader に情報提供
ExcludeSemantics → 装飾要素をフォーカスから除外
HighContrast    → highContrastTheme で OS 設定に自動追従
テスト          → tester.getSemantics() でユニットテスト可能
```

アクセシビリティは「後付け」ではなく設計段階から考えると対応コストが最小化される。
