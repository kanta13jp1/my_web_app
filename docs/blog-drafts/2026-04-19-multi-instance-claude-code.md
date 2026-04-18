---
title: "Claude Code 3インスタンスを並行運用して月$20で$200相当の開発をする話"
tags: ClaudeCode,個人開発,AI,buildinpublic,Flutter
published: false
---

# Claude Code 3インスタンスを並行運用して月$20で$200相当の開発をする話

## 概要

私は[自分株式会社](https://my-web-app-b67f4.web.app/)というFlutter WebアプリをClaude Codeで開発しています。
月$20のプランで、**3つのインスタンスを専任制で並行運用**することで、$200相当の開発効率を実現しています。

## インスタンス専任制とは

3つのClaude Code環境に明確な役割分担を設けています:

| インスタンス | 専任タスク | 特徴 |
|------------|-----------|------|
| **VSCode版** | UI/デザイン改善 (Rule12/19) | haiku-4.5で高速・安価 |
| **PowerShell版** | CI/CD健全性 (Rule17) + ブログ投稿 | sonnet-4.6で品質重視 |
| **Windowsアプリ版** | AI大学プロバイダー追加 + migration | データ処理特化 |

## なぜ専任制が有効か

### 問題: 並行 push による deploy-prod キャンセル連鎖

3インスタンスが同時にpushすると、GitHub Actionsの `deploy-prod.yml` が連続キャンセルされます。

```
PS版 push → deploy start
VSCode版 push (5秒後) → deploy cancel → new deploy start
Win版 push (3秒後) → deploy cancel → new deploy start
→ 20分後: ようやく1回deploy完了
```

### 解決策: 役割分担 + cross-instance-prs

各インスタンスが担当外の作業は `docs/cross-instance-prs/` 経由で依頼します:

```markdown
# docs/cross-instance-prs/20260419_trailing_comma_fix.md

## 依頼先: PS版
## 内容: require_trailing_commas 36件修正
## 理由: PS版がCI担当なので
```

VSCode版がdart analyzeエラーを発見 → cross-instance-prに記録 → PS版が次のセッションで修正。

## 並行衝突を検知する方法

```bash
# セッション開始時に必ず実行
git log origin/main --oneline -10

# 例: 連続してコミットしているインスタンスを確認
# 88e37a2 Merge branch 'main' (競合解消)
# f2520c6 (PS版#136)
# c66830d (VSCode版#104)
# badccf5 (PS版#135)
```

複数インスタンスが交互にコミットしている → 並行作業中 → ROADMAP更新時のconflict警戒。

## トークン節約戦略

月$20プランで3インスタンス並行運用するため、以下でトークンを節約しています:

### 1. CAVEMAN通信モード

```
❌ Normal:
"I'll be happy to help you fix the lint errors. 
Let me first analyze the current state..."

✅ CAVEMAN mode:
"2276 lint errors. dart fix --apply → dart format → 0 errors. push."
```

約75%のトークン節約になります。

### 2. 重い処理はNotebookLMに委譲

| タスク | Claude消費 | NotebookLM委譲後 |
|--------|-----------|----------------|
| 3ファイル以上同時読込 | ~150Kトークン | ~5Kトークン |
| URL分析 | ~60Kトークン | ~2Kトークン |
| 競合調査 | ~80Kトークン | ~3Kトークン |

### 3. 専任制による文脈の最小化

各インスタンスが担当範囲に特化することで、不要なファイル読込が減ります。
「全部知ってから判断する」ではなく「担当範囲だけ深く知る」設計です。

## 実際の1日の流れ

```
09:00 JST - PS版: Rule17 WF健全性チェック + T-1ブログdispatch
11:00 JST - VSCode版: UI改善 + DESIGN.md準拠率向上
14:00 JST - Win版: AI大学新プロバイダー追加
16:00 JST - PS版: deploy-prod確認 + 追加T-1作成
18:00 JST - Win版: migration + EF cleanup
```

並行しているときは `git log origin/main -5` でお互いのコミットを確認します。

## 結果

- **開発速度**: 1人で3人分の並行開発
- **コスト**: 月$20で$200相当の作業量
- **品質**: 専任制でCI/CD・UI・データが独立して品質向上

## まとめ

Claude Codeのマルチインスタンス並行運用は:
1. **明確な専任制** — インスタンスごとに役割を固定
2. **cross-instance-prで連携** — 担当外はファイル経由で依頼
3. **CAVEMAN通信** — 節約したトークンを実作業に使う

月$20の制約が、むしろ「どこにトークンを使うか」の思考を鍛えてくれます。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#ClaudeCode #buildinpublic #個人開発 #AI開発
