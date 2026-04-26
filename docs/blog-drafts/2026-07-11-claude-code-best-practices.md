---
title: "Claude Code ベストプラクティス 2026 — 個人開発者が半年使って学んだ10のルール"
tags: claude,AI,個人開発,buildinpublic
published: false
---

# Claude Code ベストプラクティス 2026 — 個人開発者が半年使って学んだ10のルール

## 「Claude Code を使いこなせていない」という感覚

Claude Code を使い始めた多くの人が最初につまずく。

「コードを書いてもらったけど、意図と違う」「指示が複雑になりすぎてわからなくなった」「途中でコンテキストが飛んでリセットされた」。

半年間、10インスタンスを並行して動かしながら 500+ コミット/月を達成した経験から、実際に効果があったプラクティスを整理する。

---

## ルール1: CLAUDE.md に「プロジェクトの事実」だけ書く

CLAUDE.md は Claude Code がセッション開始時に読むファイルだ。しかし**行動ルール**は CLAUDE.md に書いても遵守されにくい。

```
❌ CLAUDE.md に書いても効きにくい
- "必ず dart format してから push すること"
- "ダミーデータを使わないこと"

✅ 効くのはファクト情報
- 技術スタック (Flutter Web + Supabase)
- EF の一覧と用途
- 命名規則のサンプル
```

行動ルールは `~/.claude/hooks/` の UserPromptSubmit hook で毎ターン注入する方が確実に遵守される (Distyl AI 研究: 指示 500 個 → 最高精度モデルで 68% 遵守。1 回読みの CLAUDE.md は訓練済みの癖に負ける)。

---

## ルール2: memory/ でセッション間の知識を蓄積する

`.claude/memory/MEMORY.md` + 個別ファイルによる 3 層記憶システムは必須だ。

```markdown
# MEMORY.md 運用ルール
- 1ファイル1行サマリ (200行超でアーカイブ分割)
- 失敗パターン (feedback_correction_*.md) は absolute keep
- タイムスタンプ必須: project_YYYYMMDD_ps2_s42.md
```

セッション間で「前回なぜこうしたか」が残るため、同じ失敗を繰り返さない。

---

## ルール3: タスクを「原子単位」に分割する

1つの Claude Code セッションに詰め込みすぎると、コンテキスト圧迫で精度が落ちる。

```
❌ 大きすぎるタスク
"Flutter のダッシュボードを全部リデザインして"

✅ 原子単位のタスク
"home_page.dart の KPI カードのカラーを DESIGN.md の primaryOrange に変更して"
```

1 タスク = 1 ファイルまたは 1 機能単位が目安。並行作業が必要なら別インスタンスに分散する。

---

## ルール4: 並行インスタンスは worktree で分離する

複数の Claude Code セッションが同じリポジトリを編集すると、uncommitted 変更が互いに干渉する。

```bash
# 各インスタンスに専用 worktree を作成
git worktree add .claude/worktrees/instance-ps2 -b claude/ps2-wip

# push は branch 経由で main に統合
git push origin claude/ps2-wip:main
```

`git stash` は同一 workdir の全プロセスに影響するため禁止。WIP commit で退避する。

---

## ルール5: 大規模リファクタリングは Gemini に委譲する

500行超の一括リファクタリングは Claude Code より Gemini Code Assist の方が得意だ。

- Claude Code → 設計・アーキテクチャ判断・複数ファイル整合性確認
- Gemini Code Assist → 500行超の機械的なリファクタリング
- GitHub Copilot → インライン補完・5分以内の小修正

Claude Code のトークンを設計・意思決定に集中させる。

---

## ルール6: EF は hub パターンで集約する

Supabase Edge Function は 50本制限があるため、1機能 = 1 EF という設計はすぐに限界に達する。

```typescript
// ❌ 機能ごとに EF を作る → 50本超える
functions/get-user-kpi
functions/update-user-kpi
functions/delete-user-kpi

// ✅ hub パターン: action パラメータでルーティング
functions/core-hub
// POST {"action": "user.get_kpi", "user_id": "..."}
// POST {"action": "user.update_kpi", "data": {...}}
```

現在 16本の hub EF で 200+ アクションをカバーしている。

---

## ルール7: git commit は細かく、メッセージは機械的に

1セッション = 1コミットではなく、論理的なまとまりごとに commit する。

```bash
# ✅ 良いコミットメッセージ
git commit -m "fix(auth): add null guard for anonymous user in ai_hub call"
git commit -m "feat(finance): add yesterday comparison to KPI card"

# ❌ 避けるべき
git commit -m "色々修正"
git commit -m "WIP"  # (緊急退避以外は避ける)
```

並行 instance が多いほど、commit の粒度と明確さが後の rebase 解決を楽にする。

---

## ルール8: `/wrap-up` を必ず実行する

セッション終了時に必ず:
1. `memory/project_YYYYMMDD_ps2_sNN.md` を保存
2. `docs/GROWTH_STRATEGY_ROADMAP.md` 末尾に追記
3. WBS の進捗を `wbs.update_progress` で更新

これをサボると、次のセッションで「前回何をしたか」が失われ、同じ調査から始めることになる。

---

## ルール9: 検索・調査は NotebookLM に委譲する

3ファイル以上を同時に読む作業は Claude Code のトークンを大量消費する。

```bash
# ❌ Claude Code で全ファイルを読む → ~150K tokens
"この3つのファイルを読んで分析して"

# ✅ NotebookLM に委譲 → ~5K tokens
notebooklm source add ./lib/pages/dashboard.dart
notebooklm source add ./docs/DESIGN.md
notebooklm ask "設計の整合性は取れているか?"
```

---

## ルール10: DYNAMIC-CLAIM で primary task が no-op でも進める

T-1 dispatch などの primary task が date-gate で skip される場合、WBS から代替タスクを引き取る。

```
条件: primary task no-op → DYNAMIC-CLAIM 発動
手順:
  1. wbs.priority_for_instance で候補確認
  2. marketing / docs / seo から 1件選択 (business-legal は禁止)
  3. 実作業 → commit → wbs.update_progress(100%)
上限: 1セッション2件
```

PS#2 ではこのパターンで SEO 50本計画の記事を毎セッション 2本ずつ書いた。

---

## まとめ

Claude Code は「何でもやってくれる AI」ではなく、**適切なタスク設計があって初めて力を発揮するツール**だ。

10のルールを一度に覚える必要はない。まず「memory/ を使う」「タスクを原子単位に分割する」の2つから始めるだけで、セッションの精度が大きく変わる。

自分株式会社の AI 大学では Claude Code の実践的な使い方を学べる。

→ [自分株式会社 AI 大学で Claude Code を学ぶ](https://my-web-app-b67f4.web.app/)
