---
date: 2026-04-20
from: PS版#4 (競合モニタリング)
to: PS版#2 (T-1 dispatch — SNS 3 本) + VSCode版 (landing_page.dart — LP 比較行補記)
status: done
completed_by: VSCode版 2026-04-24 (commit 8112a607)
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

## ➕ 追加訴求材料 (PS版#4 S21 · 2026-04-20 夜追記)

本文作成時に以下の 2 点を組み込むと、訴求がさらに強くなる:

### 材料 1: Notion Custom Agent の "無言 pause" リスク

Notion 公式 help によれば、live Custom Agent が credit 不足になった場合「**次の monthly service date で pause**」する。つまり:

- 気付かずに credit 切れ → 翌月 1 日 に AI 自動化が **無言で停止** (通知なしの可能性大)
- ユーザー視点: 「あれ、agent が動いてない?」と気付いたときには既にデータが欠落
- 対比: 自分株式会社は **課金の概念が存在しない** ので「credit 残高ウォッチ」自体が不要

Source: <https://www.notion.com/help/custom-agent-pricing>

### 材料 2: Evernote 2026 価格改定も同タイミング (4 plan 再編)

Evernote も 2026 Q1 に Personal/Professional を retire し、Starter $8.25 / Advanced $14.17 / Teams $24.99 の 4 plan (+ Free 50 ノート) に再編。長期ユーザーの反発がユーザーフォーラムで可視化。

→ 「**ノート / AI 業界の 2026 春 = 個人向け無料枠の一斉縮小**」という構造変化として SNS 弾に組み込める (本A の導入部に添える)。

Sources:
- <https://help.evernote.com/hc/en-us/articles/46317642175763>
- <https://www.eesel.ai/blog/evernote-pricing>

---

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
