# MVP 機能スコープ — 自分株式会社

Status: v1 (Accepted baseline / **cut-line は CEO 確認待ち**)
Date: 2026-06-08
Owner: Win Claude (L3 設計レーン / architect)
WBS: `2c710eb1-f333-4a0f-8b10-b9aad34a0df6` MVP feature scope 確定 (milestone `mvp-launch`)
Sources: [`PRD.md`](PRD.md) (§4 In-Scope) / [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) (§4-1 「MVP スコープ確定」) / [`PHILOSOPHY.md`](PHILOSOPHY.md) (6 部署) / 本番機能 / 競合 21 社 / 旧 Draft [PR #1661](https://github.com/kanta13jp1/my_web_app/pull/1661) (GA readiness gate / CLOSED)

---

## 0. このドキュメントについて

- **目的**: [`PRD.md`](PRD.md) §4 の広い In-Scope を、MVP ローンチ (2026-09-30 / 1,000 users) で **必ず仕上げるコア 5 機能**へ絞り込む。タスク `2c710eb1` の要件「コア機能 5 個に絞る (現状の比較ページ等は keep)」そのもの。
- **位置づけ**: [`PHILOSOPHY.md`](PHILOSOPHY.md) (恒久理念) → [`PRD.md`](PRD.md) (何を作るか) → [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) (いつ・どの順) → **本書 (MVP の cut-line = どこまで出すか)** → WBS (個々の実行)。PRD と Roadmap が定めた方向を「出荷可能な最小単位」に翻訳する層。
- **運用 (living doc)**: 週次レビューで更新し薄く保つ。スコープ拡大は feature Issue に分割 (本体には書かない)。
- **v1 注記 / CEO 確認待ち**: コア 5 機能は既存 canon (理念 / PRD / 本番機能) から **codify した draft** であり、新たな事業判断ではない。ただし最終的な **cut-line (何を MVP に含め、何を後回しにするか) は CEO (ユーザー) の product judgment を要する** (旧 Draft #1661 recovery_plan の明記どおり)。本書はその判断のための **叩き台 v1**。固定 → 検証 → 改訂。

## 1. MVP の定義と狙い

- **MVP = 2026-09-30 までに一般公開し、最初の 1,000 users に「昨日の自分より良くなる」体験を届けられる最小の一貫プロダクト** (事業 KPI は [`PRD.md`](PRD.md) §6 / [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) §1)。
- **North-Star**: ユーザーの「**昨日の自分**」比較での自己進捗・自己効力感 (他人比較 DAU/滞在時間は北極星にしない / 原則 8・9)。
- **絞り込みの原則**: **人事 (健康) > 生存指標 (1,000 users) > 機能拡張** ([`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) §4)。6 部署すべてを薄く広げるのではなく、**日々の「自分経営ループ」を一周させる**最小機能に集中する。

## 2. コア 5 機能 (MVP に必ず含める)

各機能は 6 部署のいずれかに対応し、North-Star (昨日の自分比較) に貢献することを採用基準とした。「現状」は [`PRD.md`](PRD.md) §4 が本番 In-Scope として列挙する機能を指す (本書で新規に本番状態を主張しない / [REAL-DATA])。

| # | コア機能 | 部署 | なぜ MVP 必須か | MVP 仕上げ条件 (minimal acceptance) |
|---|---------|------|---------------|--------------------------------|
| 1 | **ホーム / ダッシュボード (昨日の自分比較 KPI 俯瞰)** | 本社 | North-Star を可視化する玄関。ここが無いと「経営している感」が成立しない (原則 1・8) | 6 部署の主要 KPI を 1 画面で俯瞰でき、前日比が表示される |
| 2 | **健康・睡眠・ジャーナル** | 人事 (**最優先**) | 理念で最優先の土台。ここが止まると全部署が機能停止 (原則 = 人事最優先) | 健康/睡眠/ジャーナルを記録でき、ダッシュボード(#1)に反映される |
| 3 | **AI大学 (多社 AI 学習) + タグ付きノート** | R&D | 自己投資の中核かつ競合との明確な差別化点 (多社 AI) | 学習コンテンツを閲覧でき、ノートをタグ付き保存できる |
| 4 | **家計簿・収支ダッシュボード** | 財務 | 「お金 = 時間資本」の最適配分 (MoneyForward 代替方向) | 収支を記録・集計でき、ダッシュボード(#1)に反映される |
| 5 | **横断 AI mentor (提案 / 実行可否はユーザー決定)** | 横断 | 「AI が自然に価値を生む」差別化の核。命令でなく優しい mentor 型 (原則 1・3・4) | 各部署データに基づく提案を返し、実行可否は常にユーザーが選択する |

- **5 機能の一貫性**: 1 が俯瞰面、2–4 が 3 部署 (人事/R&D/財務) の入力、5 がそれらを束ねて価値に変える。**入力 (2–4) → 俯瞰 (1) → 提案 (5) → ユーザー決定**で「自分経営ループ」が一周する。
- **採用しなかった部署 (マーケ営業)**: MVP では新規構築しない (§3)。発信は §4 の既存ページ keep で最小担保。

## 3. MVP に含めない (Deferred / post-MVP)

非目標 ([`PRD.md`](PRD.md) §5) とローンチ集中の観点から、Q3 MVP gate の外に置く。遅延時はここから先に削る (§6)。

- **マーケ営業の SNS 統合フル機能** — プロフィール公開は §4 で軽く keep。本格 SNS 連携は post-MVP。
- **モバイルアプリ同時リリース (#1495)** — Q3 に並走するが **GA gate 条件にはしない** (Web 先行で 1,000 users 到達可 / 同時リリースの要否は **CEO 判断**)。
- **課金 / Stripe 導入** — Q4 (`paying-100` 助走 / [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) §5)。MVP は無料公開。
- **配信完全自動化の本番 E2E (#1950) のフル化** — ブログ公開自体は keep (§4)、完全自動化は別タスクで継続。
- **法人 / チーム機能** — PRD §5 で明示的に保留 (個人の経営に集中)。
- **他社データの全自動インポート移行** — 競合移行は価値だが、MVP は手動/部分でも可。

## 4. そのまま keep (現状維持 / MVP gate 外)

タスク記述「現状の比較ページ等は keep」に対応。**新規に磨かないが落とさない**既存資産。

- **AI 比較ページ / AI ランキング** — 集客・SEO 資産として現状維持。
- **LP (「120 のこと」)** — 価値訴求の入口。最適化は [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) のグロース側で別管理。
- **ブログ作成・公開機能** — 公開機能自体は keep。完全自動化 (#1950) は別。
- **基盤 (Flutter Web + Supabase + Firebase / [`adr/`](adr/README.md))** — 変更なし。

## 5. MVP 完了判定 (GA gate との関係)

- 本書は「**何を作るか (scope)**」、GA gate は「**出せる状態か (readiness)**」を定義する別レイヤー。旧 Draft [PR #1661](https://github.com/kanta13jp1/my_web_app/pull/1661) (`docs/product/MVP_GA_READINESS_GATE.md` / CLOSED) の readiness 観点は、改めて起こすなら本 scope の **コア 5 機能の minimal acceptance (§2 右列) 全達成**を入力条件とする。
- **MVP 完了 = コア 5 機能が §2 の minimal acceptance を満たし、一般公開 (招待制 → public) に耐える品質**。安定性・パフォーマンスは [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) §4 の test/release 工程で担保。

## 6. リスクと削減順 (Risk Notes)

[`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md) §6-R1 と整合。

- **遅延時の削減順**: ① §3 Deferred を後ろ倒し → ② コア 5 のうち優先度の低い面 (例: #4 財務の集計粒度) を簡素化 → ③ **#1 #2 #5 (俯瞰 + 人事 + mentor) は死守**。テスト/リリース (delivery) を最優先で守り、不確実な機能を後段に置く (原則 6・8・9)。
- **L3 駆動の制約 (正直)**: 実装の前進は user が L2 (Codex) を回すことに依存する。本書は命令でなく **scope を固定する計画成果物**。
- **cut-line の最終確定**: §0 のとおり CEO 判断待ち。本 v1 は叩き台。

## 7. 原則整合 (Philosophy Alignment)

[`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則で **7+/9 ✅**。コア 5 の採用基準は原則 1 (ユーザーが社長 / 最終決定権) · 原則 4 (mentor) · 原則 8 (KPI = North-Star 優先) · 原則 9 (IPO = ウェルビーイング) · 人事 (健康) 最優先から導出。非目標 (§3) は中毒性・監視・他人比較・全自動最適化を避ける原則由来。

## 8. 運用 (Living Document)

- 週次レビューで更新し薄く保つ。L1 (Antigravity+Gemini) の persona 検証が出たらコア 5 の優先度を精緻化する。
- cut-line は CEO 確認後に Status を「Confirmed」へ更新する (現状 v1 = baseline draft)。
- スコープ拡大は feature Issue に分割。重要な設計判断は [`adr/`](adr/README.md) に ADR 化。

## Links

- 理念: [`PHILOSOPHY.md`](PHILOSOPHY.md)
- 製品定義: [`PRD.md`](PRD.md)
- 四半期ロードマップ: [`QUARTERLY_ROADMAP.md`](QUARTERLY_ROADMAP.md)
- 設計判断: [`adr/README.md`](adr/README.md)
- 実行計画: WBS (project-gantt) / task `2c710eb1-f333-4a0f-8b10-b9aad34a0df6`
- マイルストーン: `mvp-launch` (1,000 users / 2026-09-30)
