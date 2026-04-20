---
title: "Claude Code vs OpenAI Codex Desktop vs 自分株式会社 — AI を束ねる個人 CEO の 3 層設計"
tags: AI,Claude,OpenAI,個人開発,buildinpublic
published: false
---

# Claude Code vs OpenAI Codex Desktop vs 自分株式会社 — AI を束ねる個人 CEO の 3 層設計

## 2026-04-17 の事件 (正確に)

**2026-04-17**、OpenAI Codex Desktop が大型アップデートを発表した。

- **Computer Use** (macOS sandbox VM・ユーザー妨害なし)
- **20+ plugins** (Atlassian / CircleCI / GitLab / Microsoft / MCP servers・self-serve publish 未対応)
- **Multiple agents parallel + Memory preview**
- **ChatGPT 3M weekly devs 流入**

ここで **ネットで「Codex 90 plugin で Claude に追いついた」と流れた情報は誤り**だった。正確に数えると:

- **Claude Code: 423 plugins / 2,849 skills / 177 agents** (43 marketplaces / 834 total)
- **OpenAI Codex: 20+ plugins (self-serve publish 未対応)**

→ plugin ecosystem は **Claude が約 20 倍優位**。Codex が 4/17 で追いついたのは **Computer Use カテゴリのみ**。

Sources:
- <https://openai.com/index/codex-for-almost-everything/>
- <https://techcrunch.com/2026/04/16/openai-takes-aim-at-anthropic-with-beefed-up-codex/>

## 選択は「どちらか」ではなく「3 層」問題に

個人開発者の私は、この発表を見た瞬間に「Claude から Codex に乗り換えるべきか?」と悩んだ。
でも **結論は「3 層で使い分け・束ねる」** だった。

なぜか。**3 者は同じ土俵で戦っていない**。

### 1. Claude Code = plugin 豊富な長期記憶役

プロジェクト文脈 + 長期ミッション駆動。CLAUDE.md + memory/ + NotebookLM Master Brain による **セッション横断の連続性** が強み。
**423 plugins / 2,849 skills / 177 agents** で開発者向けエコシステムは依然として圧倒的。

### 2. OpenAI Codex Desktop = Computer Use 先行役

Computer Use は 4/17 update で Claude Desktop に追いついた。**ChatGPT 3M 週次 DAU 流入** で個人タスク自動化のリーチが広い。
ブラウザ操作 / GitHub Issue 一括処理 / Atlassian 連携など、**Claude にない Mac 実行機構** が選択理由になる。

### 3. 自分株式会社 = AI を束ねる指揮所

ai-hub で Claude / OpenAI / Gemini / fallback を **選ばない側**。
6 部署 (R&D / 財務 / マーケ営業 / 人事 / 本社 / 健康) を **AI 手段に依存せず統合する** Flutter Web + Supabase アプリ。

## 3 層構造

```text
 ┌─────────────────────────────────────┐
 │   指揮所: 自分株式会社              │  ← 6 部署 KPI / 人生全体
 │   (ai-hub で AI を選ぶ)             │
 └──────────┬──────────────────┬───────┘
            │                  │
            ▼                  ▼
 ┌────────────────┐   ┌──────────────────┐
 │  長期記憶 +    │   │  Computer Use +  │
 │  plugin 豊富:  │   │  ChatGPT 流入:   │
 │  Claude Code   │   │  OpenAI Codex    │
 │  (423 plugin)  │   │  (20+ plugin)    │
 └────────────────┘   └──────────────────┘
```

## 技術的な組み合わせ例

- **ai-hub routing**: 「長期 memory 必要な設計判断」→ Claude / 「Computer Use 必要な Mac 実行」→ Codex
- **cost-hub 4 段階 CB**: per-session cost が閾値超え → 低コストモデル (Haiku / Flash) に自動切替
- **Supabase 永続**: 6 部署の KPI 履歴 (睡眠 / 支出 / 学習) は自分株式会社が保持
  - Claude セッションは揮発 / Codex plugin 起動は単発 / → **歴史だけ自分株式会社に残る** 設計

## CEO 的 BS 原則 (自分株式会社の第 7 原則)

自分株式会社の設計原則 7「資産負債バランスシート」では、**単一 vendor 依存は負債**として扱う。

| 項目 | 評価 |
|---|---|
| Claude 単一依存 | 負債 (Anthropic 障害 / 値上げで全滅・plugin 豊富でも依存度は同じ) |
| Codex 単一依存 | 負債 (OpenAI 障害 / 値上げで全滅) |
| Cursor 単一依存 | 負債 (Anysphere 依存・IDE ロックイン) |
| **自分株式会社 (ai-hub 分散)** | **資産** (AI 手段を束ねる指揮所) |

「Claude が plugin 423 本で強い」は事実だが、**個人 CEO として 1 社に全賭けする正当化にはならない**。
会計的に言えば「AI を 1 社に決め打つ = 短期負債」「複数を束ねる = 固定資産」。

## 比較表

| 軸 | Claude Code | OpenAI Codex | Cursor | **自分株式会社** |
|---|---|---|---|---|
| 役割 | 文脈 + plugin 423 | Computer Use + ChatGPT 3M DAU | IDE 内補完 | **AI を選ばず 6 部署統合** |
| plugin 数 | 423 / skills 2,849 | 20+ (self-serve 未対応) | — | **AI 非依存** |
| 対象 | 知識労働者 / 開発者 | 開発者 / Mac ユーザー | 開発者 | **個人 CEO** |
| vendor 依存 | Anthropic 単一 | OpenAI 単一 | Anysphere 単一 | **ai-hub で分散** |
| 範囲 | knowledge-work | 個人タスク自動化 | code | **人生 6 部署** |
| 価格 | Pro $20 / seat $100 | ChatGPT Pro $20+ | Pro $20 | **無料** |
| 言語 | 英語 first | 英語 first | 英語 first | **日本語 native** |

## 結論

「**どの AI を使うか**」より「**AI を使い分けるハブがあるか**」が個人 CEO の合理解。

Claude は plugin 豊富、Codex は Computer Use 先行、自分株式会社は 6 部署統合のハブ。
**3 者は別次元で動いていて、束ねるのが最適**。

## 試してみる

- 本番: <https://my-web-app-b67f4.web.app/>
- 21 競合比較: <https://my-web-app-b67f4.web.app/comparison>

AI 選択で迷っている個人開発者にこそ、「選ぶ」より「束ねる」という選択肢を知ってほしい。
