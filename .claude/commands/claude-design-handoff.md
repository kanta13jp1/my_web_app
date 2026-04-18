---
description: Claude Design (Anthropic Labs SaaS) の handoff bundle を受け取り、Flutter widget skeleton + DESIGN.md 差分を生成する
argument-hint: <handoff-bundle-file-path-or-paste>
---

# /claude-design-handoff — Claude Design Handoff Importer

## 概要

[Claude Design](https://claude.com/plugins/design) (Anthropic Labs SaaS) が出力する **handoff bundle** を受け取り、本プロジェクト (Flutter Web + `docs/DESIGN.md` Orange+Indigo ダークテーマ) への **取り込み作業** を自動実行する。

対応する 2 入力形式:
1. **ファイルパス指定**: 引数にファイルパス (例: `/claude-design-handoff ~/Downloads/bundle.json`)
2. **ペースト**: 引数省略時、ユーザーに bundle JSON/Markdown をチャットに貼り付けてもらう

## 実行手順

### Step 1: handoff bundle 受領・パース

- 引数 `$ARGUMENTS` がファイルパスなら Read ツールで読む
- 空の場合は「handoff bundle を JSON または Markdown で貼り付けてください」とユーザーに依頼
- bundle 想定スキーマ:
  ```json
  {
    "design_tokens": {
      "colors": {"primary": "#...", "accent": "#...", "surface": "#...", ...},
      "typography": {"heading_font": "...", "body_font": "...", "sizes": {...}},
      "spacing": {"xs": 4, "sm": 8, "md": 16, ...},
      "radius": {"sm": 4, "md": 8, "lg": 16, ...}
    },
    "components": [
      {"name": "PrimaryButton", "html": "<button...>", "props": ["label", "onPressed"]}
    ],
    "pages": [
      {"route": "/example", "title": "...", "layout": "<html>..."}
    ]
  }
  ```
- Markdown 形式の場合は fenced code block + 見出しから抽出

### Step 2: `docs/DESIGN.md` と差分チェック

1. `docs/DESIGN.md` を Read して現在のトークン (Orange=`#FF6B35`, Indigo=`#6366F1`, surface0/1/2 等) を把握
2. bundle の `design_tokens.colors` を現行と比較し、差分を表示:
   ```
   ## カラートークン差分
   | トークン名 | DESIGN.md 現行 | Claude Design 提案 | 判定 |
   | --- | --- | --- | --- |
   | primary | #FF6B35 | #FF8C42 | 要検討 (明度+10%) |
   | ... | ... | ... | ✅ 既存と一致 |
   ```
3. 差分が多い場合、ユーザーに「DESIGN.md を更新しますか？ (y/n)」を確認
4. `y` なら `docs/DESIGN.md` を更新する PR を Edit で準備

### Step 3: Flutter widget skeleton 生成

bundle の `components[]` ごとに `lib/widgets/generated/claude_design/<snake_case_name>.dart` を新規作成:

```dart
// Generated from Claude Design handoff bundle (YYYY-MM-DD)
// Source: <bundle-id or filename>
// NOTE: 手動で docs/DESIGN.md トークンに合わせて調整済み
import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF6B35), // Orange primary (DESIGN.md)
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }
}
```

変換ルール:
- `background-color` / `color` → `Color(0xFF...)` (hex 大文字)
- `padding` → `EdgeInsets.symmetric/all/fromLTRB`
- `border-radius` → `BorderRadius.circular`
- `font-family` → `GoogleFonts.notoSansJp` or `const TextStyle(fontFamily: ...)`
- HTML タグマッピング:
  - `<button>` → `ElevatedButton` / `TextButton` / `OutlinedButton`
  - `<input>` → `TextField` / `TextFormField`
  - `<div>` with `display: flex` → `Row` / `Column`
  - `<img>` → `Image.network` or `Image.asset`

### Step 4: `lib/pages/generated/claude_design/<route>.dart` 生成 (pages がある場合)

各 `pages[]` に対し Scaffold 付きのページスケルトンを生成。`main.dart` のルート登録は **手動** (ユーザー確認後)。

### Step 5: サマリー出力

```markdown
## 📦 Claude Design Handoff 取り込み結果

- **design tokens 差分**: 3 件 (primary 明度+10% / spacing-xs 変更なし / radius-lg 新規)
- **生成 widgets**: 5 件 → `lib/widgets/generated/claude_design/`
- **生成 pages**: 1 件 → `lib/pages/generated/claude_design/`
- **次のステップ**:
  1. `flutter analyze` で 0 エラー確認
  2. `docs/DESIGN.md` 差分を確認 → merge するか判断
  3. `main.dart` ルートに新ページを登録
  4. cross-instance-pr で VSCode版にデザインレビュー依頼
```

### Step 6: commit 準備 (ユーザー確認後)

- ブランチ: `feat/claude-design-<yyyymmdd>-<short-name>`
- コミット: `feat: Claude Design handoff 取り込み <component-or-page-name>`

## 制約

- **`docs/DESIGN.md` の既存トークンと衝突する提案は警告のみ**、自動 merge はしない
- **Flutter 標準 Widget のみ使用** (Material 3 ベース)
- **日本語本文の `letter-spacing: 0` / `line-height: 1.7〜2.0` を維持** (本文 TextStyle の height パラメータに注意)
- **Theme.of(context) + ThemeService 統合**: Color を直接ハードコードするのは generated/ ディレクトリ内に限定、最終的には Theme Extension 化を推奨

## 関連

- CLAUDE.md Rule 21 (Claude Design 統合)
- docs/DESIGN.md (本プロジェクトのデザイントークン)
- docs/DESIGN_TOOLING_SETUP.md (デザインワークフロー正式手順書)
- cross-instance-pr: VSCode版に Flutter importer ヘルパーの実装を依頼中

## Usage 例

```
/claude-design-handoff ~/Downloads/race-detail-bundle.json
```

```
/claude-design-handoff
(引数省略 → チャットに bundle を貼り付け)
```
