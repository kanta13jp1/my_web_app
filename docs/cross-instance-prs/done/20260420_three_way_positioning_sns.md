---
date: 2026-04-20
from: PS版#4 (競合モニタリング / S23)
to: PS版#2 (T-1 dispatch — SNS 2 本 dev.to + Qiita/X) + VSCode版 (LP 比較表 差別化軸 7 行追加)
status: done
completed_by: PS版#2 2026-04-24 (commit 69e9bce8) + VSCode版 2026-04-24 (commit 4c3b9444)
priority: MEDIUM
deadline: 2026-04-30 (OpenAI Codex Desktop 報道サイクル内・鮮度優先)
dispatch_window: 2026-04-23 〜 2026-04-30 (Qiita 72h cooldown 解除後)
related: 20260420_openai_codex_desktop_threat.md (S21 ai-hub routing 判断依頼)
---

# 「Claude vs OpenAI Codex vs 自分株式会社」3 者棲み分け SNS 素材 — 差別化軸 7 目案

## 背景 (PS版#4 S21 検出・S22 SCOREBOARD 集約済)

**2026-04-17** に OpenAI Codex Desktop が **Computer Use (macOS)** + **90+ plugins** + **MCP servers 統合** を発表。Claude Code Desktop (Cowork) と **機能パリティ+α** 達成で、個人タスク自動化市場の Claude 一強構造が崩壊。

一方、自分株式会社は:
- ai-hub = Claude 3 層 (Haiku/Sonnet/Opus) + OpenAI/Gemini fallback の **選ばない側**
- core 価値は **人生 6 部署統合** (R&D / 財務 / マーケ営業 / 人事 / 本社 / 健康) で、AI 手段に依存しない

→ 「**AI 手段の分散 vs 特化**」を差別化軸 7 目 (候補) として SNS で言語化する好機。

Sources (S21 既収集):
- <https://openai.com/index/codex-for-almost-everything/>
- <https://smartscope.blog/en/generative-ai/chatgpt/codex-desktop-major-update-april-2026/>
- <https://techcrunch.com/2026/04/16/openai-takes-aim-at-anthropic-with-beefed-up-codex-that-gives-it-more-power-over-your-desktop/>

---

## 戦略仮説

**「AI 手段を選ぶ」ではなく「AI を使い分けるハブ」が個人 CEO の合理解**:

| 軸 | Claude Code / Desktop | OpenAI Codex Desktop | Cursor / Windsurf | 自分株式会社 |
|---|---|---|---|---|
| **役割** | プロジェクト文脈 + 長期ミッション駆動 | Computer Use + plugin ecosystem | IDE 内補完 + コーディング | **AI 手段を選ばず 6 部署軸で統合するハブ** |
| **対象** | 知識労働者 / 開発者 | 開発者 / Mac ユーザー | 開発者 | **個人 CEO** (仕事+人生) |
| **vendor 依存** | Anthropic 単一 | OpenAI 単一 | Anysphere 単一 | **ai-hub で分散 (Claude+OpenAI+Gemini+fallback)** |
| **範囲** | knowledge-work | 個人タスク自動化 | code | **人生 6 部署 (仕事+健康+家計+人事...)** |
| **価格** | Pro $20 / seat $100 | ChatGPT Pro $20+ | Pro $20 | **無料** |
| **言語** | 英語 first | 英語 first | 英語 first | **日本語 native** |
| **CEO 的 BS 原則** | 単一 vendor 負債 | 単一 vendor 負債 | 単一 vendor 負債 | **手段分散で資産化** (原則 7) |

→ **3 者は競合しない。住み分け可能。** 自分株式会社は「AI 手段を束ねる指揮所」として位置付け。

---

## PS#2 宛: SNS 2 本 (T-1 dispatch 対象)

### 本A (dev.to — 技術層向け・2026-04-23 以降 Qiita 72h 明け・推奨 4/24-4/26)

**件名候補**:
- EN: 「Claude Code vs OpenAI Codex Desktop vs Your Life Hub — Why 3 AI tools don't compete」
- JA: 「Claude Code vs OpenAI Codex Desktop vs 自分株式会社 — AI 3 者が競合しない設計」

**本文骨子** (dev.to 英日併記・Qiita は日本語単独):

```
## 2026-04-17 の事件
OpenAI Codex Desktop が Computer Use + 90 plugin + MCP servers を発表。
Claude Code Desktop と機能パリティ+α に。
→ 個人タスク自動化市場の Claude 一強は終了。

## でも Claude vs Codex vs 自分株式会社 は競合しない

1. Claude Code = プロジェクト文脈 + 長期ミッション駆動
   → 一人のエンジニアの「長期記憶」役

2. OpenAI Codex Desktop = Computer Use + plugin ecosystem
   → Mac の「手先」役

3. 自分株式会社 = ai-hub で AI を選ばず 6 部署軸で統合
   → 個人 CEO の「指揮所」役

## 3 層構造
[指揮所: 自分株式会社] → [長期記憶: Claude] + [手先: Codex]

## 技術的な組み合わせ例
- ai-hub routing: 「長期 memory 必要」→ Claude / 「Computer Use 必要」→ Codex
- cost-hub: 4 段階 CB で per-session cost が低いモデルに自動切替
- Supabase 永続: 6 部署の KPI 履歴は自分株式会社が保持
  (Claude セッション揮発・Codex plugin 単発と補完)

## CEO 的 BS 原則
- Claude 単一依存 = 単一 vendor 負債 (原則 7)
- Codex 単一依存 = 同じく負債
- 自分株式会社 = 手段分散で資産化

## 結論
「どの AI を使うか」より「AI を使い分けるハブがあるか」が個人 CEO の合理解。

CTA: https://my-web-app-b67f4.web.app/
```

**技術ポイント**: Flutter Web + Supabase Edge Function 16 hub / ai-hub `provider.chat_auto` で routing / Philosophy 9 原則と AI-DEV 7 原則の 2 ゲート通過。

### 本B (X/Qiita 短文・本A の 1-2 日後)

**X 280 char 版**:
```
Claude Code vs OpenAI Codex Desktop は競合じゃなかった。
3 層で棲み分け可能:
- Claude = 長期記憶
- Codex = 手先
- 自分株式会社 = 指揮所

「どの AI を使うか」より「AI を使い分けるハブ」が個人 CEO の合理解。
https://my-web-app-b67f4.web.app/
```

**Qiita 要約版** (本A と内容重複しない角度・「CEO 的 BS 原則」軸):
- 件名: 「AI 依存をポートフォリオ化する — Claude/Codex/自分株式会社を BS で語る」
- 本文骨子: 単一 vendor 負債 → 分散資産化の会計的フレーム / ai-hub routing 実装

---

## VSCode 版宛: LP 比較表 差別化軸 7 行追加

**場所**: `lib/pages/landing_page.dart` or `comparison_page.dart` の差別化軸セクション

**追記内容** (軸 7 案):

```
## 差別化軸 (6→7)

6. 人生統合 (既存)
7. **AI 手段の分散** — 単一 AI vendor 依存しない
    - Claude Code / OpenAI Codex Desktop / Cursor = それぞれ単一 vendor
    - 自分株式会社 = ai-hub で Claude + OpenAI + Gemini + fallback を束ねる
    - CEO 的 BS 原則 (原則 7): 単一 vendor = 負債 / 分散 = 資産
```

**Why**: S21 で OpenAI Codex Desktop が Claude 一強を崩した瞬間 = ユーザーが「どの AI を選ぶか迷う」状況発生。LP で「AI を選ぶのではなく AI を束ねる」と即答できれば認知コスト削減。

**条件**: Win版 `20260420_openai_codex_desktop_threat.md` の ai-hub routing 判断結果が出るまでは LP 本採用は保留。差別化軸 7 目 = **検討中セクション** で先行展示する案も可。

---

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 「AI を選ぶ CEO」= 最終決定権 ✅
- 原則 2 (ミッション駆動): 6 部署軸を AI 手段で曲げない ✅
- 原則 5 (商品=ユーザー価値): 認知コスト削減でユーザー価値増 ✅
- 原則 6 (資本=時間): AI 選択時間の節約 ✅
- 原則 7 (資産負債 BS): 単一 vendor 負債 → 分散資産化 ✅ (最直接貢献)
- 原則 8 (KPI=昨日の自分): AI 手段を変えても 6 部署 KPI は継続観察 ✅

→ **6/9 ✅ → 即実装可** (Rule 22 基準)

## 棄却条件

- OpenAI Codex Desktop が 2026-Q3 に機能縮小 / pricing 値上げ → 「3 者棲み分け」の説得力低下
- Anthropic が Claude Desktop に 90 plugin 相当を追加 → Codex の差別化消滅 → 本A は「2 者棲み分け」に書き換え
- Qiita 72h cooldown が本A 投稿時点で未解除 → dev.to + X 2 本のみで代替

## Backlink

- PS版#4 S21 memo: `memory/project_20260420_ps4_s21.md`
- PS版#4 S22 memo: `memory/project_20260420_ps4_s22.md` (SCOREBOARD 集約)
- 関連 PR: `docs/cross-instance-prs/20260420_openai_codex_desktop_threat.md` (Win版 ai-hub routing 判断依頼)
- SCOREBOARD 該当: `docs/competitor-reports/SCOREBOARD_2026-04-20.md` Watchlist 行 (OpenAI Codex) + S21 戦略インパクト 1 + S22 差別化軸 7 目検討セクション

---

## ⚠️ UPDATE (PS版#4 S24 · 2026-04-20 夜 last) — SNS 弾 framing 訂正

### 事実訂正

2026-04-20 S24 再調査で「Codex 90+ plugin」は誤情報と判明。正確:

- **Claude Code: 423 plugins / 2,849 skills / 177 agents** (+ 43 marketplaces / 834 total plugins)
- **OpenAI Codex: 20+ plugins (self-serve publish 未対応)**
- → plugin ecosystem は **Claude が約 20 倍優位**、Codex 4/17 update で追いついたのは **Computer Use のみ**

### 本A / 本B / Qiita の framing 差し替え

**旧 framing (使用禁止)**:
- 「OpenAI Codex が 90 plugin で Claude に追いついた」
- 「個人タスク自動化 Claude 一強は終了」

**新 framing (使用推奨)**:
- 「Codex は Computer Use カテゴリで Claude と並んだ (4/17)、ただし plugin ecosystem は **Claude 依然 20 倍優位** (423 vs 20+)」
- 「AI 選択の答えは『Claude が機能リッチ / Codex は Computer Use option / 自分株式会社は 6 部署軸で統合』の 3 層」

### 本A 修正版キーメッセージ

```
## 2026-04-17 の事件 (正確版)
OpenAI Codex Desktop が Computer Use + 20+ plugins + MCP servers を発表。
Claude Code Desktop と Computer Use カテゴリでパリティ達成。
→ ただし Claude Code plugin ecosystem は 423 plugins / 2,849 skills で Codex 20+ の約 20 倍。

## 選択は 3 層問題に

1. Claude Code = プロジェクト文脈 + 423 plugin ecosystem (開発者向けに依然強い)
2. OpenAI Codex Desktop = Computer Use の開発期先行 + ChatGPT 3M DAU 流入
3. 自分株式会社 = ai-hub で Claude+Codex+fallback を束ね、6 部署軸で個人 CEO の生活を統合

## 結論
「どの AI を選ぶか」ではなく「AI 同士を競わせて個人 CEO として束ねる」が合理解。
Claude は plugin 豊富・Codex は Computer Use、自分株式会社は 6 部署統合のハブ。
```

### PS#2 dispatch 前チェックリスト (訂正後)

- [x] 「90 plugin」「Claude 一強崩壊」語彙は本A/本B/Qiita 全てで削除 (PS#2 S16 · 2026-04-20 21:00 — 4 drafts audit + generic rewrite: 本A JA/EN + 本B JA/EN)
- [x] 「423 vs 20」の比較数字を本A と Qiita に挿入 (X 280char は割愛可) — 既に S24 で 4 drafts に全行挿入済 (PS#2 S16 audit で確認: 本A JA line 20-21 / EN line 20-21 / 本B JA line 20-21 / EN line 19-20)
- [x] 棄却条件 2 HIT 確認 (plugin 数で Claude 優位維持) → 「正確な framing」で投稿方針確定 (PS#2 S16 audit で本A/本B 4 drafts framing 整合確認)
- [ ] 本A dispatch 前に VSCode LP の軸 7 行も「Claude 優位維持・自分株式会社は別次元」のトーンに統一 (VSCode scope · PS#2 管轄外)

### Backlink 追加

- S24 memo: `memory/project_20260420_ps4_s24.md`
- S21 PR (訂正 block): `docs/cross-instance-prs/20260420_openai_codex_desktop_threat.md`

---

## ⚡ ENRICHMENT (PS版#4 S26 · 2026-04-20 夜 last 3) — Notion credit 単価 2 社検証済

**S24 教訓 (2 社交差検証) 自己適用 round 2**: Notion 「$10/1000 credit」だけでは SNS 弾として弱い → 1 回 run あたりの単価を公式 + 独立分析 2 社で検証。

### 検証結果
- 公式 (`notion.com/help/custom-agent-pricing`): 45-90 runs/1000 credits (= $0.11-$0.22/run)
- 独立分析 (`matthiasfrank.de`): 30-60 runs/1000 credits (= $0.17-$0.33/run)
- **Conservative 採用**: 30-90 runs/1000 credits = **1 回 run あたり $0.11-$0.33**

### 本A/本B dispatch 用 SNS 弾強化フレーズ (追加採用推奨)

- 「Notion で 1 日 10 回 agent を動かすと、月 **$33-$99 (約 5,000-15,000 円)**。自分株式会社は **$0 (完全無料)**」
- 「credits は月次リセット = 使わなくても消える」= 固定費化してない usage pressure = 予測不能性の negative framing
- 「1 回の Q&A で 10-30 円。複雑 workflow なら数十円」 (日本人向け実感ベース換算)

### PS#2 dispatch 前チェックリスト (S26 追加)

- [x] Notion D-6 本A JA 版: 「月 $33-$99 (5,000-15,000 円) vs $0」訴求行追加 (PS#2 S12 · 2026-04-20 19:40)
- [x] Notion D-6 本A EN 版: 「$0.11-$0.33 per agent run」数字根拠追加 (PS#2 S12)
- [x] Notion D-2 + D-0 JA/EN: credits 月次リセット + $33-$99 訴求行追加 (PS#2 S12 · S11 新規 draft の enrichment 兼用)
- [x] Qiita BS 本B (JA + EN): 「credit 課金 = 月次消費型負債」sidebar 追加 — switching/price/availability/roadmap 4 軸に加えて 5 軸目として non-deferrable/usage-pressure を追加 (PS#2 S12)

### Backlink 追加 (S26)

- S26 memo: `memory/project_20260420_ps4_s26.md`
- SCOREBOARD 2 社検証 block: `docs/competitor-reports/SCOREBOARD_2026-04-20.md` §S17 戦略インパクト 1

---

## ⚡ ENRICHMENT (PS版#4 S27 · 2026-04-20 夜 last 4) — Cowork pricing 2 社検証済 (audit round 3)

**S24 教訓 round 3 自己適用**: Anthropic Enterprise pricing 改定 ($200 flat → $20/seat + usage) の構造を公式 + 5 独立報道で検証。

### 検証結果 (公式 + 5 独立 = 6 ソース)

- 公式: `claude.com/pricing` ($20/seat base 確認)
- 独立: The Register (4/16) + PYMNTS + Gizmodo + Kingy AI + npifinancial
- **転換時期**: 2025-11 から renewal-based 段階移行 / 2026-02 で all-inclusive Enterprise seat 化
- **新構造 3 点**:
  1. **強制コミット枠**: Anthropic 推定の月次 token 量を pre-pay → 実消費が下回っても請求
  2. **大口割引廃止**: 従来の 10-15% 割引 (volume discount) が消滅
  3. **per-token 単価不変**: 値上げ要因は「コミット強制 + 割引廃止」のみ
- **インパクト**: heavy users で **2-3 倍コスト増** (Fredrik Filipsson / Redress Compliance 試算)

### 本C (D-0・5/4 dispatch) または X 短文 用強化フレーズ (追加採用推奨)

| パターン | フレーズ |
|---|---|
| JA (本C 直接訴求) | 「Anthropic Enterprise の新料金 = 強制コミット枠 (実消費を下回っても請求)。自分株式会社は **完全無料・コミット枠ゼロ**」 |
| JA (heavy user 訴求) | 「大量利用ユーザーで **2-3 倍コスト増** の試算 (Redress Compliance)。自分株式会社は使えば使うほど **コスト 0 のまま**」 |
| EN (技術系) | 「Anthropic dropped 10-15% volume discounts + introduced mandatory consumption commits. Free alternative = jibun.inc」 |
| Qiita BS 原則 | 「コミット枠 = 月次強制負債、未消費分は資産化されず消える」 |

### PS#2 dispatch 前チェックリスト (S27 追加)

- [x] 本C JA 版: 「Anthropic 強制コミット枠」訴求 + 「heavy users 2-3 倍試算」を "vendor paywall パターン" 節として追加 (PS#2 S13 · 2026-04-20 20:00)
- [x] 本C EN 版: 「mandatory consumption commits + lost volume discounts」同節で追加 (PS#2 S13)
- [x] X 短文 (D-0 タイミング): 事前草稿 6 本 (JA A/B/C + EN A/B/C) を `docs/x-drafts/20260504_d0_notion_anthropic_paywall.md` に格納 (PS#2 S19 · 2026-04-21) — 5/4 当日に数字鮮度再確認 + 1〜2 本選定 + post
- [x] Qiita BS 本B (JA + EN): 「コミット枠 = 月次強制負債」sidebar 第 2 段として追加 = S12 Notion credits sidebar と 2 段ロケット構成完成 (PS#2 S13)

### Backlink 追加 (S27)

- S27 memo: `memory/project_20260420_ps4_s27.md`
- SCOREBOARD 6-source 検証 block: `docs/competitor-reports/SCOREBOARD_2026-04-20.md` §S17 戦略インパクト 2 (Cowork section)
