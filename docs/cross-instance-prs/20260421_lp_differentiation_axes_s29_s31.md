---
date: 2026-04-21
from: PS版#4 S32 (競合モニタリング)
to: VSCode版 (LP / landing_page.dart 差別化軸)
status: done
completed_by: VSCode版 2026-04-24 (commit db32be24)
priority: MEDIUM
---

# LP 差別化軸拡張 + LINE 数字訂正 — S29 LINE / S31 Replit 統合 handoff

## 背景

PS#4 audit round 5-6 完走 (2026-04-20 夜 → 2026-04-21 朝)。2 件の公開 LP 反映候補あり:

1. **S29 — LINE AI ¥750/月 verified** (LYCorp 公式 + 6 独立 = 7 sources) / launch 2025-09-10 / feature-narrow (code interpreter / deep research / GPTs 全て無し) / OpenAI GPT-4o 単一依存
2. **S31 — Replit $9B verified** (公式 + 9 独立 = 10 sources) / Georgian 主導 Series D 2026-03-11 / FY2025 $240M (24× / 1 年) / vibe-coding for non-programmers 新 pivot

LP (`lib/pages/landing_page.dart` 3820 行) を確認したところ、**data stale + 差別化軸追加余地** の 2 点を発見。

---

## 発見 1: LP の LINE 価格が 5 倍誇張 (訂正必須)

### 現状 (line 2800)

```dart
const _CompetitorRow('LINE (Business)', '¥5,000〜/月', '30+', false),
```

### 問題

- 「LINE (Business)」= **LINE 公式アカウント (企業 CRM / LINE for Business)** の価格であり、個人向け LINE AI とは別商材
- 自分株式会社の LP は **個人ユーザー向け**比較表 → 無関係な B2B 商材と比較するのは誤誘導
- 読者は "自分が LINE に ¥5,000/月 払ってる" と思わないので、比較が刺さらない

### 推奨訂正 (S29 検証値)

```dart
const _CompetitorRow('LINE AI', '¥750〜/月 (無制限)', '5', false),
// または
const _CompetitorRow('LINE AI', '無料 3回/日 or ¥750/月', '5', false),
```

**機能数「5」の根拠** (S29 verified): Q&A / 画像生成 / トークサジェスト / 翻訳 / 画像解析 のみ = 5 項目。code interpreter / deep research / GPTs / agent は**全て無し**。

### 副次的効果

- 「LINE AI ¥750 vs 自分株式会社 Free」で **価格勝ち**が明確化
- 「LINE AI 5 項目 vs 自分株式会社 21 サービス (6 部署統合)」で **機能深度勝ち** が圧倒的
- 従来の「¥5,000 vs Free」の主張より刺さる (読者が「LINE AI ¥750 使ってみたけど物足りなかった」経験層に訴求)

---

## 発見 2: 差別化軸 7-8 行目の追加提案 (S29 + S31 統合)

### 現状

SCOREBOARD#docs S13 追加分で **差別化軸 6 軸** 確立済:
1. 対象 (個人 CEO)
2. 範囲 (人生 6 部署統合)
3. 言語 (日本語 first)
4. 価格 (無料)
5. データ永続化 (Supabase 永続)
6. 人生統合 (6 部署 vs 仕事のみ)

LP 本文に上記 6 軸の表現はあるが、S29 / S31 audit で **新しい 2 軸の訴求材料** が見つかった。

### 提案: 7 軸 = **vendor 分散**

**根拠** (S29 LINE + S27 Anthropic):
- LINE AI = OpenAI GPT-4o / 4o-mini 単一依存 → OpenAI 障害で全機能停止
- Anthropic 単一依存サービス (Claude Cowork / Notion AI 一部) も同様の障害耐性問題
- 自分株式会社 = **Anthropic + Gemini + AWS Nova の multi-vendor** 分散
- ai-hub routing で用途別に 3 vendor 切替可能

**LP コピー案**:
> **「どれか 1 社が障害でも使える」 — AI を 3 社分散運用**
> LINE AI は OpenAI 単一依存 / Claude Cowork は Anthropic 単一依存。自分株式会社はメモは Claude、翻訳は Gemini、画像は Nova — 用途別に 3 社ルーティング。どれか 1 社が落ちても他で代替できる。

### 提案: 8 軸 = **feature depth (特化 vs 統合深度)**

**根拠** (S29 LINE feature-narrow 発見):
- LINE AI = 対話 5 項目のみ / code interpreter / deep research / GPTs / agent は全て無し
- ChatGPT Plus ¥3,000 との機能差が大きい = LINE AI ユーザーは機能制限に気づかず払っている層
- 自分株式会社は **対話 + 21 サービス** で深度 + 幅 両立

**LP コピー案**:
> **「¥750 で 5 項目 vs 無料で 21 サービス × 6 部署統合」**
> LINE AI は ¥750/月 で Q&A/画像生成/翻訳 などの対話 5 項目だけ。自分株式会社は無料で Notion × Slack × MoneyForward × X × Amazon の 21 サービスを統合。同じ AI 時代でも、機能深度と統合スコープは桁違い。

### 副次: Replit 棲み分け行 (任意)

Replit が non-programmer pivot で自分株式会社軸に接近する可能性 (S31 watchlist 🟢→🟠 昇格) を LP の FAQ に追記してもよい:

> **Q: Replit / Lovable / Cursor でアプリ作れば自分株式会社いらない?**
> A: Replit Agent 4 / Lovable / Cursor は「アプリ **を** 作る」ツール (tool-creation)。自分株式会社は「人生 **を** 運営する」プラットフォーム (life-management)。同じ AI 時代でも「作る」と「生きる」は別レイヤー。

---

## 実装 checklist (VSCode 担当)

- [ ] line 2800: `_CompetitorRow('LINE (Business)', '¥5,000〜/月', '30+', false)` → LINE AI 版に訂正
- [ ] 差別化軸セクション (LP 中盤 or 上部 hero) に 7-8 軸目を追加
  - 7: vendor 分散 (障害耐性)
  - 8: feature depth (特化 vs 統合深度)
- [ ] FAQ に Replit / Lovable / Cursor 質問 (任意・低優先)
- [ ] flutter analyze 0 / dart format OK / push

## PS#4 本件に関する追加対応

なし (競合モニタリング専任のため、LP の Dart 編集は VSCode scope)。
本 PR 起票後、VSCode 着手時に cross-reference する source:
- `docs/competitor-reports/SCOREBOARD_2026-04-20.md` (#18 LINE / #20 Replit / [S29]/[S31] 末尾 block)
- `memory/project_20260420_ps4_s29.md` (LINE 詳細)
- `memory/project_20260421_ps4_s31.md` (Replit 詳細)

## Philosophy alignment (Rule 22)

- 原則 1 (CEO 感): 数字の正確さ = 経営判断の資産 ✅
- 原則 5 (商品=ユーザー価値): LP で実数値を提示 = ユーザーに誤誘導しない ✅
- 原則 7 (BS 原則): vendor 分散を資産側に明示 ✅
- 原則 8 (KPI=昨日の自分): 差別化軸 6 → 8 軸拡張 = 成長 ✅

→ 4/9 ✅ (LP コピーは VSCode 判断なので 9/9 チェックは VSCode 側)
