---
date: 2026-04-18
from: Windowsアプリ版#94
to: VSCode版
status: pending
priority: high
---

# Claude Design handoff bundle → Flutter importer ヘルパー実装

## 概要

Windows版#94 で以下を導入済み:
1. **CLAUDE.md Rule 21** 新設: `Claude Design` SaaS + `frontend-design` プラグインを本プロジェクトのデザインワークフローに統合
2. **`.claude/commands/claude-design-handoff.md`** 新設: handoff bundle を受け取り Flutter widget skeleton + DESIGN.md 差分を生成する slash command (LLM ベース)

次段階として **永続的な Dart/Flutter ヘルパー** を実装してほしい。slash command は「今回だけ生成して commit」のワンショット用途だが、繰り返し handoff を取り込む運用にはコード化されたパイプラインが必要。

## 依頼内容

### 1. `lib/dev/claude_design/` ディレクトリ新設

以下 4 ファイル:

#### `lib/dev/claude_design/handoff_bundle.dart`
Claude Design handoff bundle の型定義:

```dart
class ClaudeDesignHandoff {
  final DesignTokens tokens;
  final List<DesignComponent> components;
  final List<DesignPage> pages;
  final String? sourceBundleId;
  final DateTime importedAt;

  const ClaudeDesignHandoff({
    required this.tokens,
    required this.components,
    required this.pages,
    this.sourceBundleId,
    required this.importedAt,
  });

  factory ClaudeDesignHandoff.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}

class DesignTokens {
  final Map<String, Color> colors;
  final Map<String, TextStyle> typography;
  final Map<String, double> spacing;
  final Map<String, double> radius;
  // ...
}
```

#### `lib/dev/claude_design/token_diff.dart`
現行 DESIGN.md トークン (=`lib/theme/app_theme.dart` など) と handoff bundle のトークンを比較し、差分リストを返す。

```dart
class TokenDiff {
  final List<TokenChange> changes;
  int get addedCount => changes.where((c) => c.kind == ChangeKind.added).length;
  // ...
}

enum ChangeKind { added, removed, modified, unchanged }

TokenDiff diffTokens(DesignTokens current, DesignTokens incoming);
```

#### `lib/dev/claude_design/flutter_codegen.dart`
HTML + props → Flutter widget 生成エンジン。最低対応:

- `<button>` → `ElevatedButton` / `TextButton` / `OutlinedButton`
- `<input>` → `TextField` / `TextFormField`
- `<div display:flex row|column>` → `Row` / `Column`
- `<img>` → `Image.network`
- `<span>` / `<p>` / `<h1-3>` → `Text` with TextStyle
- CSS `padding` → `Padding` widget or widget-specific padding
- CSS `border-radius` → `BorderRadius.circular`
- CSS `color` → `Color(0xFF...)`
- CSS `background-color` → `Container decoration` or widget bg color

出力先は `lib/widgets/generated/claude_design/<snake_case_name>.dart`。

#### `lib/dev/claude_design/importer_page.dart`
開発者向け UI ページ (`/dev/claude-design-importer`):

1. テキストフィールドで bundle JSON を貼り付け
2. 「Parse」ボタンで `ClaudeDesignHandoff.fromJson`
3. 「Diff vs DESIGN.md」ボタンで差分表示
4. 「Generate Flutter widgets」ボタンで `flutter_codegen` 呼び出し → `Share.share(code)` or `Clipboard.setData`
5. 生成内容をエディタ風プレビュー

`main.dart` のルートに `/dev/claude-design-importer` を追加 (admin 権限チェック付き)。

### 2. unit test

`test/dev/claude_design/`:
- `handoff_bundle_test.dart`: fromJson/toJson round-trip
- `token_diff_test.dart`: fixture で added/removed/modified カバー
- `flutter_codegen_test.dart`: HTML snippet → expected Dart コード

### 3. 統合テスト (optional)

`integration_test/claude_design_importer_test.dart`:
- 開発者ページを開く → sample bundle をペースト → diff & codegen 実行

### 4. docs 更新

`docs/DESIGN_TOOLING_SETUP.md` に「Claude Design 取り込みフロー」セクションを追加:
- Claude Design SaaS で bundle 出力
- 開発者ページ `/dev/claude-design-importer` でペースト → codegen
- 生成された widget を `lib/widgets/generated/claude_design/` から通常の widget ディレクトリに移動 → 必要な改変

## 関連ファイル

- `CLAUDE.md` Rule 21 (Claude Design 統合)
- `docs/DESIGN.md` (Orange+Indigo トークン)
- `.claude/commands/claude-design-handoff.md` (slash command 版)
- `lib/theme/app_theme.dart` (現行 ThemeData) — あれば

## 完了条件

- [ ] `lib/dev/claude_design/` 4 ファイル作成
- [ ] unit test 3 ファイル + 基本ケース パス
- [ ] `/dev/claude-design-importer` ルート追加 (admin 権限チェック)
- [ ] `flutter analyze` 0 エラー
- [ ] `docs/DESIGN_TOOLING_SETUP.md` にフロー追記
- [ ] `main.dart` ルート登録

完了後 `done/20260418_claude_design_flutter_importer.md` へ移動してください。

## 補足

- **Claude Design SaaS は Pro/Max/Team/Enterprise プラン必須** のため、当面は管理者 (kanta13jp1) のみ使用
- 生成コード品質は 70% 手動調整で使える水準を目指す (100% 完璧は不可)
- `docs/DESIGN.md` 更新は自動 merge しない (ユーザー確認必須)
