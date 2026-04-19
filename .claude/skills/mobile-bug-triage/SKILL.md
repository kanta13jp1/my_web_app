---
name: mobile-bug-triage
description: |
  📱 スマホ版 Claude Code 専用スキル。ユーザーがスマホで本番サイト
  https://my-web-app-b67f4.web.app を実機検証中に発見した不具合を、
  screenshot + 説明から GitHub Issue 化 + ラベル付け + 該当ファイル推定を行う。

  Triggers on: "/mobile-bug-triage", "スマホ不具合", "モバイル UAT",
  "iPhone で見たら", "Android で表示が", "screenshot 添付", "Issue 作成して".

  引数なし or screenshot 添付。1-2 ターンで完結する軽量トリアージ skill。
---

# 📱 mobile-bug-triage スキル

## 概要

スマホ版 Claude Code が実機 UAT で発見したモバイル不具合を **構造化 Issue** にして
GitHub に登録するためのトリアージスキル。

**専任**: スマホ版インスタンス (📱)。他インスタンスでも実行可だが、
スマホ版 = 実機検証 + 画像分析 + GitHub MCP の三位一体が最も効率的。

## 制約

- スマホ版は git CLI / dart / flutter 直接実行不可
- 全 GitHub 操作は `mcp__plugin_github_github__*` 経由
- 重い修正 (lint cascade / 多ファイル) は VSCode版に handoff (cross-instance-pr)

## 手順

### Step 1: 不具合の構造化

ユーザーが screenshot + 一文説明 (例: 「AI大学画面で右側が切れる」) を入力。

スキルが画像分析:

- **要素**: どの部品か (FAB / カード / タブ / テキスト / 画像)
- **症状**: 何が起きているか (overflow / 重なり / 押せない / 文字切れ)
- **画面**: 推定ページ (LP / ホーム / AI大学 / 競馬予想 等)
- **デバイス**: ユーザー入力 (iPhone X / Android / iPad mini 等)
- **ブラウザ**: ユーザー入力 (Safari / Chrome / Firefox)

### Step 2: モバイル特化チェックリスト評価

以下 8 項目を screenshot から判定:

```markdown
- [ ] **Touch target ≥ 48dp** (Material Design 推奨)
- [ ] **Viewport overflow なし** (横スクロール発生していない)
- [ ] **FAB 重なり** なし (他要素と被っていない)
- [ ] **iOS Safari 100vh** bug (CSS env(safe-area-inset-bottom))
- [ ] **キーボード起動時 Scroll** が正しく動作
- [ ] **Dark mode コントラスト** WCAG AA 以上
- [ ] **PWA manifest** 適切 (iOS add-to-home 動作)
- [ ] **Pull-to-refresh** 誤動作なし
```

### Step 3: 該当ファイル推定 (GitHub MCP search_code)

```
mcp__plugin_github_github__search_code
  q: "<推定ページタイトル文字列>"
  → lib/pages/<page>.dart 候補返却
```

### Step 4: GitHub Issue 作成

```
mcp__plugin_github_github__create_issue
  owner: "kanta13jp1"
  repo: "my_web_app"
  title: "[mobile-bug] <症状一行>"
  body: |
    ## 症状
    <一文説明>

    ## 環境
    - デバイス: <iPhone X 等>
    - ブラウザ: <Safari 等>
    - URL: https://my-web-app-b67f4.web.app/<path>

    ## Screenshot
    (画像URL or base64)

    ## 推定ファイル
    - `lib/pages/<page>.dart`
    - L<推定行数> 付近

    ## チェックリスト評価
    - 該当原因: Touch target / Viewport overflow / FAB重なり / 100vh bug 等

    ## 修正規模 (推定)
    - 軽量 (1ファイル数行) → スマホ版で PR 可
    - 重い (複数ファイル / lint影響) → VSCode版 handoff

    ## 優先度
    - high (画面が使えない) / medium (見た目崩れ) / low (微調整)
  labels: ["mobile-bug", "priority:<level>"]
```

### Step 5: 修正規模で分岐

#### 軽量修正 (推奨)

スマホ版が直接 PR 作成:

```
mcp__plugin_github_github__get_file_contents
  → 該当ファイル取得

mcp__plugin_github_github__create_or_update_file
  → 修正版コミット (新ブランチ作成)

mcp__plugin_github_github__create_pull_request
  title: "fix: [mobile] <症状> (Issue #NNN)"
  body: |
    Closes #NNN
    ## 修正
    - <変更箇所>
    ## VSCode版に依頼
    - flutter analyze + Playwright モバイル UAT
  base: "main"
  head: "fix/mobile-issue-NNN"
```

#### 重い修正 (handoff)

`docs/cross-instance-prs/YYYYMMDD_mobile_<title>.md` を作成:

```
mcp__plugin_github_github__create_or_update_file
  path: "docs/cross-instance-prs/YYYYMMDD_mobile_<title>.md"
  content: |
    ---
    date: YYYY-MM-DD
    from: スマホ版
    to: VSCode版
    status: pending
    priority: <level>
    ---

    # [mobile] <症状>

    ## 経緯
    Issue #NNN で報告された モバイル不具合。スマホ版で軽量修正範囲を超える
    (lint cascade / 多ファイル影響 / Flutter rebuild 必要) ため handoff。

    ## 依頼内容
    1. lib/pages/<page>.dart の <該当箇所> 修正
    2. flutter analyze 0 エラー確認
    3. Playwright で本番モバイル viewport 検証
    4. PR マージ後 Issue #NNN クローズ

    ## 推奨修正案
    <スマホ版の提案>
```

### Step 6: 完了報告

ユーザーに以下形式で:

```
✅ mobile-bug-triage 完了

- Issue 作成: #NNN [URL]
- ラベル: mobile-bug, priority:<level>
- 修正規模: 軽量 (PR #MMM 作成済) / 重い (cross-instance-pr 作成済)
- 推定ファイル: lib/pages/<page>.dart:LXXX
- 次ステップ: VSCode版が PR レビュー / handoff 受領 → flutter analyze + 実装
```

## 運用上の注意

### スマホ版でやらないこと

- ❌ `git pull / push / commit` (CLI 不可)
- ❌ `dart format / flutter analyze` (実行不可)
- ❌ Playwright/Puppeteer (デスクトップ専用)
- ❌ 大規模リファクタリング (token 効率悪・lint cascade リスク)

### スマホ版でやるべきこと

- ✅ **実機検証** (iOS Safari の細かい挙動・PWA・touch gesture)
- ✅ Screenshot 撮影 + 添付 + 画像分析
- ✅ GitHub Issue 作成 (テンプレ化済)
- ✅ 軽量 PR (1 ファイル数行)
- ✅ cross-instance-pr で handoff
- ✅ 修正後の再検証 (Issue close)

### モバイル特化バグの典型例

| 症状 | 原因 | 修正担当 |
| --- | --- | --- |
| 横スクロール発生 | viewport overflow / 固定幅 widget | VSCode版 |
| FAB が押せない | bottom safe-area 不足 | スマホ版 (簡単) |
| キーボード起動で input 隠れる | resizeToAvoidBottomInset 設定 | VSCode版 |
| iOS で 100vh が画面外 | CSS env(safe-area-inset-bottom) | VSCode版 (web/index.html) |
| Touch target 小さすぎ | `IconButton` の minSize 未指定 | スマホ版 (簡単) |
| ダークモード contrast 不足 | DESIGN.md token 違反 | VSCode版 (Rule 12) |
| PWA install ボタン出ない | manifest.json 不備 | Win版 (web/) |

### Philosophy / AI Dev 原則チェック

- **PHILOSOPHY (Rule 22)**: モバイル不具合修正 = ユーザーが CEO として自分の人生を経営する障害除去 → 原則 1 (CEO感) 直結
- **AI Dev (Rule 23)**: 該当外 (UI修正で AI 機能ではない)

## トラブルシュート

- 画像が大きすぎて分析失敗 → ユーザーに圧縮版 (1MB 以下) を依頼
- GitHub MCP 認証エラー → `~/.claude/settings.json` の GITHUB_PERSONAL_ACCESS_TOKEN 確認
- 該当ファイルが特定できない → 画像 + ユーザーに「どのページですか」確認
- 既に同じ Issue がある → `mcp__plugin_github_github__search_issues` で重複検出
