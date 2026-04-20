---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: PS版#2 (T-1 dispatch — SNS 3 本) + VSCode版 (landing_page.dart — LP 比較行補記)
status: pending
priority: HIGH
deadline: 2026-05-04 (課金開始日)
dispatch_window: 2026-04-28 〜 2026-05-03 (D-6 〜 D-1)
related: 20260421_notion_ai_lp_update.md (Notion AI カレンダー GA 対応)
---

# Notion Custom Agents 課金開始 D-14 弾 — 無料 6 部署統合の優位性訴求

## 背景 (S17 検出済)

**Notion Custom Agents 課金切替**:
- 2026-05-03 まで: 無料試用 (全 Business/Enterprise 顧客)
- **2026-05-04 から**: **$10 / 1000 credit** の従量課金 (Business/Enterprise add-on)
- Source: notion.com/help/custom-agent-pricing + notion.com/releases/2026-04-14

## 戦略仮説

Notion 課金開始日 **直前〜直後** は「Notion 課金 vs 自分株式会社 無料」の対比が最高に刺さる窓。
対比軸は以下:

| 軸 | Notion Custom Agents | 自分株式会社 |
|---|---|---|
| 価格 | **$10/1000 credit 従量** (Business add-on) | **無料** |
| スコープ | ノート/Wiki/タスク/カレンダー (仕事業務中心) | **6 部署** (R&D/財務/マーケ/人事/本社/健康) |
| 日本語 UX | 英語主 + DeepL 風翻訳 | **日本語ネイティブ** |
| データ永続化 | Notion クラウド (有料依存) | **Supabase 永続** (予測可能) |

## PS#2 宛: SNS 3 本 (T-1 dispatch 対象)

### 本A (D-6 ぐらい = 2026-04-28 予定)

**Qiita / dev.to / X 横展開**:

> 件名候補: 「Notion Custom Agents 5/4 から $10/1000 credit 課金 — 無料で 6 部署を全部回す方法」
>
> 本文骨子:
> 1. 5/4 から Notion Custom Agents が従量課金に (Business/Enterprise add-on, $10/1000 credit)
> 2. credit は「1 回の AI 実行で数〜数十消費」→ 1000 credit ≒ 数十回〜 100 回の実行
> 3. **自分株式会社は個人向け 6 部署統合 (R&D/財務/マーケ/人事/本社/健康) を無料提供** — 仕事だけでなく人生全体を扱える
> 4. 「credit 残高ウォッチ」で時間消費するより、予測可能な無料で KPI=昨日の自分を回す方が早い
> 5. 技術ポイント: Supabase Edge Function 16 hub 構成 + Flutter Web + AI ルーティング
>
> CTA: <https://my-web-app-b67f4.web.app/>

### 本B (D-2 = 2026-05-02 予定)

> 件名候補: 「Notion 課金まであと 2 日 — 切替前に個人 AI 管理を無料 6 部署に分散しておこう」
>
> 本文骨子:
> 1. 「credit 残高を気にしながら AI を使う」= 人生で一番疲れる使い方
> 2. Notion Custom Agents の強みは企業データ統合 — 個人の 6 部署 (特に人事・健康) は範囲外
> 3. 自分株式会社の個人 6 部署を Notion と **並走** させれば、仕事用の課金 credit を節約できる
> 4. 実例: Notion = 仕事ノート / 自分株式会社 = 毎日の健康ログ・家計 KPI
>
> CTA: <https://my-web-app-b67f4.web.app/>

### 本C (D-0 当日 = 2026-05-04 朝 予定)

> 件名候補: 「Notion Custom Agents 本日課金開始 — 無料で人生 6 部署を回すオルタナティブ」
>
> 本文骨子:
> 1. 本日 5/4 から Notion Custom Agents が従量課金モードへ
> 2. **代替** として自分株式会社 (無料 6 部署統合 Flutter Web + Supabase)
> 3. **併用** として「Notion = 仕事中心」「自分株式会社 = 個人・健康・家計」分担
> 4. 6 部署サマリー画面スクリーンショット 1 枚
>
> CTA: <https://my-web-app-b67f4.web.app/>

**PS#2 タスク**: 上記 3 本を T-1 skill で dev.to / Qiita / X (X は要約 280 char) へ dispatch。Qiita rolling 24h 制限に注意 (本A → 次の本B は 72h 以上空ける)。

## VSCode 版宛: landing_page.dart 追記

**場所**: `lib/pages/landing_page.dart` の Notion 比較行 (既存 `20260421_notion_ai_lp_update.md` PR と統合可)

**追記内容**:
```
Notion AI 比較行に小さな注記:
  「※ Custom Agents は 2026-05-04 から $10/1000 credit の従量課金 (Business/Enterprise add-on)」

「自分株式会社」行の強調:
  「無料 6 部署統合 (課金不要で KPI=昨日の自分を継続観察)」
```

**Why**: LP 訪問者が「有料化の情報」を LP で即確認できる → 「自分株式会社 = 予測可能な無料」の決定打になる。

## 棄却条件

- Notion 側が 5/4 直前に無料期間を延長した場合 → 発信内容の日付を差し替え、残 2 本は保留
- Notion 側が「個人プラン」にも課金拡大を宣言した場合 → 発信トーンを「代替」から「避難経路」へシフト
- Qiita 429 が本A 投稿後に発生 → 本B / 本C は X + dev.to のみで代替

## Philosophy alignment (Rule 22)

- 原則 5 (商品=ユーザー価値): 「予測可能な無料」は価値の核 ✅
- 原則 6 (資本=時間): 「credit 残高ウォッチ」撲滅 = 時間資本の保全 ✅
- 原則 8 (KPI=昨日の自分): 課金不安で中断せず継続観察できる ✅

→ **3/9 の原則に直接貢献**

## Backlink

- PS版#4 S17 detect: `memory/project_20260420_ps4_s17.md` (3A - Notion 5/4 $10/1000 credit)
- S17 next候補 #1 (5/4 Notion 課金 D-2 弾) の具体化
- 既存関連 PR: `docs/cross-instance-prs/20260421_notion_ai_lp_update.md` (Notion AI カレンダー GA 対応)
