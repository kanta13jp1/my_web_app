# X (Twitter) 公式アカウント運用設計 — 自分株式会社

Status: v1 (Accepted baseline / **投稿コミット量・声のトーンは CEO 確認待ち**)
Date: 2026-06-09
Owner: Win Claude (L3 設計レーン / architect / 競合・SNS lane)
WBS: `fd9616af-bbdd-41ad-ba71-0c2dd76aa505` X 公式アカウント運用設計 (milestone `mvp-launch`)
Sources: [`MVP_SCOPE.md`](MVP_SCOPE.md) / [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) / [`PHILOSOPHY.md`](PHILOSOPHY.md) / [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / [`INDIE_DEV_VELOCITY_PRINCIPLES.md`](INDIE_DEV_VELOCITY_PRINCIPLES.md) / 既存ブログ/SNS 自動化 (T-1 dispatch / blog-publish) / 競合 21 社

---

## 0. このドキュメントについて

- **目的**: タスク記述「**週 5 投稿 / hashtag / engagement KPI**」の通り、X 公式アカウントの**運用 baseline** (誰に・何を・どの頻度で・どう測るか) を設計する。MVP ローンチ (2026-09-30 / 1,000 users) のトップ・オブ・ファネルとして、Beta-50 募集 → 一般公開の集客導線を担う。
- **位置づけ**: [`PHILOSOPHY.md`](PHILOSOPHY.md) (理念) → [`MVP_SCOPE.md`](MVP_SCOPE.md) (何を出すか) → [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) (来た人をどう定着させるか) → **本書 (そもそも人をどう連れてくるか / 認知)**。MVP ローンチ準備設計シリーズ (ADR→PRD→四半期ロードマップ→MVP スコープ→On-call SOP→オンボーディング設計) の集客面。
- **これは運用設計 (spec) であり、実装/自動化ではない** ([REAL-DATA]): 投稿自動化・スケジューラ・bot 実装は L2 (Codex) の既存 SNS 配信基盤 (T-1 dispatch / blog-publish) 上で行う。本書は**戦略・カデンス・ガードレール・KPI 定義**まで。
- **v1 注記 / CEO 確認待ち**: §4 の投稿量 (週 5) と §6 の KPI 目標値、§5 の声のトーンは **v1 仮説**。公開メッセージング・ブランド声の最終確定は **CEO (ユーザー) 判断** (原則 1)。固定 → 検証 → 改訂。

## 1. アカウントの位置づけ (Positioning)

- **一言**: 「**AI と一緒に、自分の人生を会社のように経営する**」を **build-in-public** で見せる、ソロファウンダー × AI fleet のアカウント。
- **想定オーディエンス**: ① 自己管理・自己投資に関心がある個人 (副業/フリーランス/多忙な会社員) ② AI/indie hacker コミュニティ (multi-AI 活用・AI 駆動開発に関心)。
- **差別化の核**: **多社 AI (AI大学)** と **6 部署で人生を経営**という世界観。競合 21 社 (notion / moneyforward / x 等) の単機能ではなく「**昨日の自分比較**で前進する一貫体験」を訴求 (North-Star / 原則 8)。
- **アカウントがやらないこと**: 他人比較を煽る・射幸性・誇張バズ狙い。**穏やかな mentor のトーン**を SNS でも保つ (原則 3-4 / AI_CHARACTER)。

## 2. コンテンツの柱 (Content Pillars)

6 部署と build-in-public を 4 本柱へ。各投稿はいずれか 1 柱に紐づける。

| 柱 | 内容 | 対応 (部署/理念) | 例 |
|----|------|----------------|----|
| **P1 Build-in-public** | 開発実績・ROADMAP・KPI を正直に共有 | 本社 / INDIE | 「今週 onboarding 設計を ship。狙いは初回 7 日で…」 |
| **P2 自分経営 tips** | 健康・家計・学習の小さな実践知 | 人事/財務/R&D | 「睡眠を 1 行記録するだけで前日比が見える」 |
| **P3 多社 AI / 競合インサイト** | AI 比較・AI大学の学び (**検証済のみ**) | R&D / 競合 lane | 「Opus 4.x と △△ を同条件で比較したら…」 |
| **P4 ユーザー価値/物語** | 「経営している感」の体験・声 | 横断 / IMBUE | onboarding の aha 体験の言語化 |

- **比率の目安 (v1)**: P1 2 / P2 1 / P3 1 / P4 1 = 週 5 (§4)。P1 (build-in-public) を主軸に信頼を積む。

## 3. 既存資産との連携 (再利用)

新規に作らず、既にある配信物を X 用に**転用**する (二重生産しない / INDIE)。

- **ブログ/T-1 dispatch**: 公開済ブログ (dev.to / Qiita) を要約 → P1/P3 投稿へ。
- **ROADMAP / development_achievements**: ship ログを P1 ネタ source に。
- **AI大学コンテンツ**: 学習トピックを P3 の素材に (出典付き)。
- **オンボーディング設計の aha**: P4 の語り口に。

## 4. 投稿カデンス (Cadence)

- **週 5 投稿** (タスク要件 / v1)。平日 1 本を基本、無理に毎日埋めない (**質 > 量** / 中毒的運用にしない)。
- **時間帯**: JST 朝 (7-9 時) か夜 (20-22 時) を既定。最終最適化は engagement データで (§6)。
- **形式**: 単発を基本、深い話題のみスレッド。画像/スクショは本番 UI の**実データ** ([REAL-DATA] / ダミー禁止)。
- **[SCHEDULE-WAKEUP] 整合**: 自動投稿の cron は深夜帯 (02-06 JST) を避ける。

## 5. ハッシュタグ & トーン / ガードレール

- **ハッシュタグ (v1)**: ブランド `#自分株式会社` + コミュニティ `#個人開発` `#buildinpublic` `#AI活用` (JA) / `#buildinpublic` `#indiehackers` (EN)。1 投稿 1-3 個、詰め込まない。
- **トーン**: 短く・優しく・断定しすぎない。煽り/FOMO/他人比較を使わない (AI_CHARACTER_PRINCIPLES)。
- **🔴 検証ファースト / 誇張禁止 (本アカウント最重要ガードレール)**: AI ツール・競合・ベンチマークに関する投稿は **[AI-TOOL-VERIFY] に従い一次情報を確認してから**投稿する。未検証のモデル名・性能・「最強」断定・引用未読 URL は**投稿しない**。本プロジェクトで SNS 誇張・捏造の指摘が累積した教訓 (verify-first 運用) を運用ルールとして恒久化する。数値主張は出典 or 自社実測のみ。
- **[AUTO-REPLY] 整合**: 自動リプライは `author == self` で必ず skip + 1 記事/run あたり上限。bot 自己ループ禁止。
- **秘密情報禁止**: token/credential/内部 URL を投稿に含めない (On-call SOP の通信プロトコルと同原則)。

## 6. Engagement KPI

「他人比較の虚栄指標」ではなく、**プロダクト成長への寄与**を測る (原則 8 / MVP_SCOPE §1)。

| 指標 | 定義 | v1 目標仮説 (要 CEO 確認) |
|------|------|--------------------------|
| **Engagement rate** | (いいね+RT+返信+クリック) / インプレッション | **2-4%** (業界相場の仮説) |
| **プロフィール→サイト CTR** | bio/投稿リンクのクリック→本番訪問 | 測定を確立し較正 |
| **Beta 流入** | X 経由の Beta-50 応募 (`e548b4b9`) | トップファネル寄与を可視化 |
| **フォロワー成長** | 純増 (vanity 単独では追わない) | 参考指標 (主指標は流入) |

- **主指標 = サイト流入 / Beta 応募寄与**。フォロワー数・インプレッションは**補助**に留める (vanity 回避)。
- 週次で 1 表にまとめ CEO レビュー。詳細ダッシュボード/自動集計は最適化フェーズ (§8)。

## 7. Beta-50 / 成長接続

- **X = トップ・オブ・ファネル**: 認知 (X) → 本番 LP/サイト → サインアップ → オンボーディング (`a7f97791`) → Activated → Beta-50 (`e548b4b9`) → GA (`ea87d61a`)。
- build-in-public (P1) で Beta 募集を自然に告知。応募導線は LP A/B (`3fe22123`) と連携。

## 8. Deferred / 非スコープ (実装・拡張は下流)

[NO-SCOPE-CREEP] のため baseline に含めず明示的に渡す:

- **投稿自動化・スケジューラ・KPI 自動集計の実装**: L2 (Codex) が既存 T-1 dispatch / blog-publish 基盤上で実装。本書は戦略/カデンス/KPI 定義まで。
- **有料広告 (X Ads)・インフルエンサー施策**: post-MVP / 別予算 (CEO 判断)。
- **他プラットフォーム (LinkedIn / YouTube 等)**: 本書は X 専用。プレスは PR Times task (`88d0ac29`)、ブランド全体は ブランドガイドライン (`dce3f86c`) が別途扱う。
- **声のトーン/ブランド最終確定**: §0 のとおり CEO 判断。本 v1 は叩き台。

## 9. 原則整合 (Philosophy Alignment)

- **原則 1 (CEO 感)**: 公開メッセージング・ブランド声の最終決定は CEO。
- **原則 3-4 (mentor)**: SNS でも穏やかな mentor トーン、煽らない。
- **原則 8 (KPI = 昨日の自分)**: 主指標をサイト流入/Beta 寄与に置き、vanity を北極星にしない。
- **原則 9 (IPO = ウェルビーイング)**: 射幸性・FOMO・他人比較を避ける運用。
- [`INDIE_DEV_VELOCITY_PRINCIPLES.md`](INDIE_DEV_VELOCITY_PRINCIPLES.md) (build-in-public / 既存資産の転用) + [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) (誠実・操作の回避) + [AI-TOOL-VERIFY] (検証ファースト) に整合。7+/9 ✅。

## 10. 運用 (Living Document)

- engagement データ (§6) を受けてカデンス・時間帯・柱比率を較正し、薄く保つ。
- 声のトーン/ブランドは CEO 確認後に Status を「Confirmed」へ更新 (現状 v1 = baseline draft)。
- スコープ拡大は feature Issue / 最適化タスクに分割。重要判断は [`adr/`](adr/README.md) に ADR 化。

## Links

- MVP スコープ: [`MVP_SCOPE.md`](MVP_SCOPE.md) / オンボーディング: [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md)
- 理念: [`PHILOSOPHY.md`](PHILOSOPHY.md) / AI 人格: [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / indie: [`INDIE_DEV_VELOCITY_PRINCIPLES.md`](INDIE_DEV_VELOCITY_PRINCIPLES.md)
- 関連タスク: Beta-50 `e548b4b9` / GA `ea87d61a` / LP A/B `3fe22123` / PR Times `88d0ac29` / ブランド `dce3f86c`
- 実行計画: WBS (project-gantt) / task `fd9616af-bbdd-41ad-ba71-0c2dd76aa505`
- マイルストーン: `mvp-launch` (1,000 users / 2026-09-30)
