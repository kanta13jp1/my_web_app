---
title: "Claude Design の handoff bundle を Flutter に取り込むインポーターを作った"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: true
---

# Claude Design の handoff bundle を Flutter に取り込むインポーターを作った

## はじめに

Anthropic Labs の **Claude Design** (Pro/Max プラン) で生成した UI デザインを Flutter コードに変換するインポーターを実装しました。

ルート: `/dev/claude-design-importer` (管理者専用)

## Claude Design とは

Claude Design は Anthropic Labs が提供する AI UI デザインツールです。

プロンプトから HTML/CSS のデザインを生成し、**handoff bundle (JSON)** としてエクスポートできます。この JSON には:

- `tokens` — カラー・タイポグラフィ・スペーシング・ボーダーラジウス
- `components` — HTML スニペット + プロパティ定義
- `pages` — ページ一覧とルーティング情報

が含まれています。

## インポーターの実装

### 1. handoff_bundle.dart — JSON パーサー

```dart
class ClaudeDesignHandoff {
  final DesignTokens tokens;
  final List<DesignComponent> components;
  final List<DesignPage> pages;

  factory ClaudeDesignHandoff.fromJson(Map<String, dynamic> json) {
    return ClaudeDesignHandoff(
      tokens: DesignTokens.fromJson(asStrMap(json['tokens'])),
      components: ((json['components'] as List<dynamic>?) ?? [])
          .map((e) => DesignComponent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      pages: ((json['pages'] as List<dynamic>?) ?? [])
          .map((e) => DesignPage.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      ...
    );
  }
}
```

カラーは `#RRGGBB` / `#AARRGGBB` 両対応でパースします。

### 2. token_diff.dart — デザイントークン差分検出

`docs/DESIGN.md` の既存トークンと incoming bundle を比較:

```dart
class TokenDiff {
  final Map<String, TokenChange> colors;
  final Map<String, TokenChange> spacing;
  // added / modified / removed を分類
}
```

これにより「新しい bundle で何が変わったか」を一目で確認できます。

### 3. flutter_codegen.dart — HTML → Flutter 変換 (約70%精度)

HTML スニペットをパターンマッチで Flutter widget に変換:

```dart
// Button patterns
if (_matchesTag(trimmed, 'button')) {
  final isOutlined = trimmed.contains('outlined') || trimmed.contains('border:');
  if (isOutlined) return "OutlinedButton(...)";
  return "ElevatedButton(...)";
}

// Input patterns
if (_matchesTag(trimmed, 'input') || _matchesTag(trimmed, 'textarea')) {
  return "TextField(decoration: InputDecoration(hintText: '$placeholder'))";
}
```

h1/h2/p/div/img など主要タグに対応。div は `flex-direction: row` で `Row`、それ以外は `Column` に変換します。

### 4. importer_page.dart — UI

3タブ構成:
- **Tokens** — カラー・スペーシング差分を色付きで表示
- **Components** — HTML スニペットと生成された Flutter コード
- **Pages** — ページ一覧とルーティング案

## 使い方

1. Claude Design で UI をデザイン → JSON エクスポート
2. `/dev/claude-design-importer` を開く
3. JSON を貼り付けて「解析」ボタン
4. **Tokens タブ**: `docs/DESIGN.md` との差分を確認 → 必要なら手動で DESIGN.md を更新
5. **Components タブ**: 生成された Dart コードをコピーして `lib/widgets/` に配置

## まとめ

Claude × Flutter の組み合わせで UI デザインワークフローを効率化できました。
`FlutterCodegen` はパターンベースのため精度は約70%ですが、ボイラープレートの削減には十分です。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #Claude
