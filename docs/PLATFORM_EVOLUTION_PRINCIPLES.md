# プラットフォーム進化 7 原則 — 自分株式会社 Workplace OS 化戦略

> このドキュメントは、自分株式会社が **Flutter Web SaaS** から **AI Workplace OS** へ進化するための **戦略原則 + 技術原則** を定義する **必守原則** である.
>
> **ソース**: NotebookLM Notebook [Anthropic Evolution: Claude Apps, Opus 4.7, and Enterprise Expansion](https://notebooklm.google.com/notebook/e89d2ca7-1dc9-41a1-8fe2-bad5103a757b)
> Anthropic の Claude Apps for Slack/Figma/Asana/Canva (interactive integration) + Opus 4.7 (task_budget / effort パラメータ / 高解像度 vision) + NEC 30,000 従業員導入 + Claude Design + Workplace OS 野心 を題材としたエンタープライズプラットフォーム進化原則 (2026-04-28 取り込み)
>
> **位置づけ**: 既存 8 設計軸 (含む VIBE_CODING メタ) に加え、**戦略+技術ミックス層** として追加 (= 9 番目軸)
> - PHILOSOPHY (why) / AI_DEV (how) / AI_CHARACTER (who) / IMBUE (how it feels)
> - COLLAB_AI (how it evolves) / MCP_AUTH (how it opens) / AI_VIDEO (how it appears)
> - VIBE_CODING (how it stays responsible)
> - **PLATFORM_EVOLUTION (how it grows from app to OS)** ← 新規 9 番目

---

## なぜ必要か

自分株式会社は現状、Notion/Evernote/MoneyForward/Slack 等 **21 競合 SaaS** の機能を統合した「**AI 統合ライフマネジメントアプリ**」だが、機能列挙では大手 SaaS と消耗戦になる. Anthropic 自身が 2025-2026 年で実証した **「chat 製品 → Apps platform → Workplace OS」進化戦略** をベンチマークとして取り込み、**21 競合と差別化** + **エンタープライズ市場参入** + **新 Opus 4.7 capabilities 活用** の 3 軸で **プラットフォーム化** を加速する必要がある.

具体的に Anthropic が実証した進化軌跡:
- **chat 単体製品** (Claude.ai 2023) → **Computer Use** (2024) → **Claude Apps for Slack/Figma/Asana/Canva** (2026) → **NEC 30,000 enterprise 導入** (2026) → **Workplace OS 野心** (継続)

= 自分株式会社も同パターンで以下を実装すべき:
- **chat + 21 機能統合 SaaS** (現状 2026-04) → **Interactive UI within chat** (#1) → **Orchestration of external tools** (#2) → **Enterprise Client Zero playbook** (#3)

---

## 7 原則

### 原則 1: UI as a Context (Interactive Integration)

**ルール本文**: チャット内で **直接操作可能なインタラクティブ UI** を動的にレンダリングする. ユーザーにコンテキストスイッチ (= 別 page への遷移 / 別アプリ起動) を強いない.

**なぜ重要か**: 21 競合 SaaS は「専用 UI へ遷移」が前提だが、AI Workplace OS は「**AI と話す中で全てが完結**」が差別化. Claude Apps for Slack の MCP `ui://` resource パターン = AI 応答内にネイティブ Flutter widget をレンダリング.

**どう適用するか**:
- `lib/widgets/ai_chat_interactive_widget.dart` 新規 (将来): AI 応答内に Flutter widget を埋め込み (例: 家計簿入力 / カレンダー予定追加 / メモ作成)
- MCP `ui://` リソース実装 (= MCP_AUTH 原則 #1 DCR + 原則 #5 Resource Indicators との接続)
- AI_CHARACTER との対話内で Supabase データを **チャット内で直接編集** (= 専用画面遷移なし)
- ❌ NG: 「家計簿に追加するには /finance ページに移動してください」と AI が誘導
- ✅ OK: AI が応答内に inline 入力 widget をレンダリング → ユーザー入力 → AI が処理して即時反映

### 原則 2: System of Orchestration (Workplace OS 志向)

**ルール本文**: 個別の「記録システム」にとどまらず、AI を **インターフェースのハブ** として **他ツールを統合・指揮する** オーケストレーション層になる. **21 競合と機能比較で戦わず、それらを束ねる立場** へ移行.

**なぜ重要か**: Notion / Evernote / MoneyForward / Slack を **個別に超える** のは数十年がかりだが、それらを **連携先として統合する** のは 1-2 年で可能. NEC が Anthropic を選んだ理由 = 既存ツール群 (Slack / Box / Salesforce) を **AI が orchestrate** できるから.

**どう適用するか**:
- 新 EF: `supabase/functions/orchestrator-hub` (= 既存 hub 化方針と整合)
- アクション例: `notion.create_page` / `slack.send_msg` / `gmail.draft_reply` / `gcal.add_event`
- MCP server 公開 (= MCP_AUTH 原則 #1-#10 全クリア前提) で外部 AI からも呼出可能
- 21 競合との比較ページ (`/competitors`) を **「これら全てを束ねる」差別化メッセージ** に書き換え
- ❌ NG: 「Notion より使いやすい家計簿機能」訴求 (= 局所機能比較)
- ✅ OK: 「あなたの Notion + MoneyForward + Slack を AI が orchestrate」訴求 (= プラットフォーム位置取り)

### 原則 3: Client Zero & Trust-Based Acquisition (Enterprise GTM)

**ルール本文**: 自社を **最初の顧客 (Client Zero)** として徹底活用し、得た **運用ノウハウ + セキュリティ実績** をエンタープライズ顧客獲得の武器とする. 「自分達が日々使っているから信頼できる」を最強の営業資料にする.

**なぜ重要か**: NEC が 30,000 人で Claude を導入した動機 = Anthropic 自身が **Claude を Anthropic 内部で使い倒している** から. 12 インスタンス AI fleet 自体が **史上最も radical な Client Zero 実証** であり、これをエンタープライズ向けマテリアル化すべき.

**どう適用するか**:
- `docs/CLIENT_ZERO_CASE_STUDY.md` 新規 (将来): 12 fleet 運用の生産性数値 / OPS-28 達成 / コスト効率を公開
- 自社の以下を **エンタープライズ営業資料** に転用:
  - 12 fleet × 1 セッション = 14 part の 5-7x スループット (= part 60 session_summary)
  - 1 日サイクル運用パターン (= OPS-28 charter §6)
  - 設計軸 9 軸 60+ 原則 governance (= 「うちでこれだけ厳格にやっているから安心」)
- LP の対象を「個人ユーザー」から「個人 + Enterprise」に拡張
- ❌ NG: 「自分株式会社は AI が使いやすい個人サービス」訴求
- ✅ OK: 「12 AI fleet で運営する自分株式会社 = AI 駆動経営の Client Zero」訴求

### 原則 4: Handoff Bundle Driven (Design to Code)

**ルール本文**: AI による **デザイン段階** から、コンポーネント構成 + デザイントークン + Supabase スキーマ + EF action までを含む **「実装バンドル (Handoff bundle)」** を生成し、本番コードへシームレスに変換する.

**なぜ重要か**: 既存の `Claude Design` (Anthropic Labs SaaS) は Figma 風 UI 設計から Flutter コードを直生成するが、自分株式会社は更に進んで **Supabase + EF まで含む全 stack handoff** を実装する余地がある. = VIBE_CODING 原則 #2 (AI as PM) の Plan アーティファクト機能を bundle 化.

**どう適用するか**:
- `docs/handoff-bundles/<task-id>/` 新規ディレクトリ構造:
  - `design.json` (= Claude Design / Figma 出力)
  - `flutter_widgets.dart` (= 自動生成 Flutter コード)
  - `supabase_schema.sql` (= 必要 table / RLS)
  - `edge_function.ts` (= 必要な EF action)
  - `integration_test.dart` (= VIBE_CODING 原則 #5 minimal E2E)
- bundle = 1 機能 = 1 PR (= cross-instance-pr の進化形)
- ❌ NG: 「Figma 渡したから後はよろしく」(= 設計と実装が分離)
- ✅ OK: bundle 1 つ = 全 stack 完結 → 受領 instance は merge 判断のみ

### 原則 5: High-Res Vision Integration (Opus 4.7 Capabilities)

**ルール本文**: Opus 4.7 の **最大 2576px 高解像度画像対応** を活かし、画面 / 文書の **ピクセルレベルの正確な理解** をプロダクトに組み込む. ダウンサンプリングなしで UI の **1:1 座標マッピング** を AI に把握させる.

**なぜ重要か**: 現状 design-skills agent は Playwright screenshot を AI に渡しているが、解像度損失で「ボタン位置がずれている」「テキスト切れ」の検出精度が低い. Opus 4.7 の高解像度対応を使えば **production UI の自動回帰検出** が可能.

**どう適用するか**:
- `scripts/ui_regression_check.py` 新規 (将来): Playwright でフルページ screenshot → Opus 4.7 に渡して「前回 baseline と比較 / 差分検出」
- AI_VIDEO #5 ウォーターマーク + メタデータ層と連携 → 動画フレームの ピクセル正確性検証
- 競合 21 SaaS の **ダッシュボード screenshot** を Opus 4.7 に解析させ、UI/UX の差別化ポイント抽出
- ❌ NG: 低解像度 (1024px) screenshot で AI に判断させる
- ✅ OK: 2576px 高解像度を Opus 4.7 に直接渡し、座標精度を担保

### 原則 6: Budget-Aware Autonomous Agent (Cost Control)

**ルール本文**: 自律的なエージェントループに対して **「タスク予算 (task_budget)」** を設定し、コストをコントロールしながらタスクを完遂させる. 12 fleet × 数百 commit/日 が **API コストで破綻しない** 仕組み.

**なぜ重要か**: 12 instance 並行 + Opus 4.7 (高単価) の組み合わせは月コスト数百万円規模に跳ねる可能性. Anthropic API の `task_budget` ベータ機能を使えば、**個別タスクごとに上限** を設けつつ AI が自律的に予算内で完結.

**どう適用するか**:
- 各 GHA workflow に `TASK_BUDGET_USD` 環境変数追加 (= GitHub secret)
- `supabase/functions/_shared/task_budget.ts` 新規 (将来): 全 EF が tracking する budget meter
- 月次 quota report に「fleet 別コスト」を追加 (= 既に `quota-monitor.yml` 拡張)
- task_budget 超過時は **完了率に応じた部分成功** で AI を強制停止
- ❌ NG: 「fleet を 100 に増やそう」だけ言ってコスト無視
- ✅ OK: fleet 拡大時は task_budget 設計を必ず先行

### 原則 7: Effort-Tuned Architecture (Adaptive Intelligence)

**ルール本文**: タスクの難易度に応じて AI の **「推論の深さ (effort)」** を動的に切り替え、速度 + 品質 + コストのバランスを最適化する. すべてを `effort=xhigh` で回せば破産、低 effort だけでは品質崩壊.

**なぜ重要か**: 自分株式会社の AI 機能は多様 (= AI 大学 quiz / daily-judgment / customer-feedback / horse_racing predictor / etc). 一律設定では非効率. Opus 4.7 の `effort` パラメータで以下を最適化:
- 日常対話: `low/medium` (高速 + 低コスト)
- アーキテクチャ判断: `high/xhigh` (深い推論)
- 競馬予想: `xhigh` (因子 18+ の複雑判断)
- AI 大学 quiz 採点: `low` (定型処理)

**どう適用するか**:
- `supabase/functions/_shared/effort_router.ts` 新規 (将来): action 名から effort 自動選択
- 各 EF に `effort` パラメータ明示 (= deterministic / docs に明記)
- 月次レポートに「effort 別コール数」追加 (= 設定が適切か検証)
- ❌ NG: 全機能で `effort=xhigh` (= 無駄な高コスト)
- ✅ OK: 機能ごとに最適 effort を docs で明文化 + 自動 router

---

## 7 原則の相互依存

```
[#3 Client Zero (= 自社で実証)]
        ↓ 武器化して
[#2 Workplace OS 化 (= 21 競合を束ねる立場)]
        ↓ 実現するために
[#1 Interactive UI (= chat 内完結)]
        ↓ 高度化のため
[#4 Handoff Bundle (= 全 stack 自動生成)]
        ↓ 精度のため
[#5 High-Res Vision (= ピクセル理解)]
        ↓ 実運用のため
[#6 Budget Control (= コスト破綻回避)]
        ↓ 効率最大化
[#7 Effort Tuning (= 推論深さ最適化)]
```

= **戦略 → 位置取り → UX → 実装 → 精度 → コスト → 効率** の 7 段階段. 戦略層 (#1-#3) と技術層 (#4-#7) のミックス.

---

## 既存 8 設計軸との関係

| 既存軸 | PLATFORM_EVOLUTION 7 原則の augmentation 関係 |
| --- | --- |
| PHILOSOPHY (why) | 原則 3 (Client Zero) で「自社実証 = 営業資料」のミッション拡張 |
| AI_DEV (how) | 原則 6 (Budget) + 原則 7 (Effort) で「実装の効率化」を補強 |
| AI_CHARACTER (who) | (直接関連なし — character は人格) |
| IMBUE (how it feels) | 原則 5 (High-Res Vision) で「UI 知覚の精度」を補強 |
| COLLAB_AI (how it evolves) | 原則 1 (Interactive UI) + 原則 6 (Budget) で「AI 協業の運用」を拡張 |
| MCP_AUTH (how it opens) | 原則 1 (`ui://` リソース) + 原則 2 (orchestration server) で「公開境界」を補強 |
| AI_VIDEO (how it appears) | 原則 5 (High-Res Vision) で「動画解像度の正確性」を補強 |
| VIBE_CODING (how it stays responsible) | 原則 4 (Handoff Bundle) で「全 stack 自動化の責任設計」を補強 |

= 8 軸中 7 軸に対して 1+ 原則ずつ augmentation を提供. AI_CHARACTER のみ非介入 (専門領域非侵犯).

---

## 自分株式会社 既存ベースライン評価

| 原則 | 現状 | gap |
| --- | --- | --- |
| #1 Interactive UI | △ (chat 機能あり / inline widget なし) | MCP `ui://` 未実装 |
| #2 Workplace OS | △ (21 競合機能統合済 / orchestration 不在) | orchestrator-hub 未実装 |
| #3 Client Zero | ✅ (12 fleet + OPS-28 + 9 設計軸) | エンタープライズ営業資料化なし |
| #4 Handoff Bundle | △ (cross-instance-pr が原型 / Supabase スキーマ統合なし) | bundle ディレクトリ構造未定義 |
| #5 High-Res Vision | △ (Playwright screenshot あり / 解像度設定なし) | 2576px 設定 + ui_regression_check.py なし |
| #6 Budget Control | ❌ (quota-monitor.yml はあるが task_budget 未使用) | task_budget.ts 未実装 |
| #7 Effort Tuning | ❌ (全 EF で effort 未指定) | effort_router.ts 未実装 |

= **2.0/7** ベースライン (#3 のみ完全 / 残 6 原則は部分または未実装).

---

## チェックリスト (新機能 PR 時)

- [ ] **#1 Interactive UI**: chat 内完結する UX 設計か?
- [ ] **#2 Workplace OS**: 21 競合の orchestration 視点を含むか?
- [ ] **#3 Client Zero**: 自社実証データを資料化できるか?
- [ ] **#4 Handoff Bundle**: 全 stack (Flutter + Supabase + EF + Test) を 1 bundle で渡せるか?
- [ ] **#5 High-Res Vision**: 2576px 解像度 + Opus 4.7 で UI 正確性検証済か?
- [ ] **#6 Budget Control**: 該当 EF / GHA に task_budget 設定済か?
- [ ] **#7 Effort Tuning**: effort パラメータを機能特性に合わせて選択済か?

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_platform_evolution.py` (将来追加):
- 全 EF の effort パラメータ使用率
- task_budget 設定済 EF / 未設定 EF レポート
- `ui://` リソース公開数
- orchestrator-hub アクション数
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携)

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-28 | Win版#132 part 67 | 軸確立 (docs + Rule [PLATFORM-31]) | — | 2.0/7 |
| 2026-04-29 | Win版#132 part 74 | Codex#2 へ `task_budget` + `effort_router` 同時 cross-instance-pr (= 1 PR 2 原則 第 1 例) | (#6 + #7 完成は Codex#2 受領後 4.0/7) | 2.0/7 (PR 受領で **4.0/7** 想定) |
| 2026-04-29 | Win版#132 part 75 | `docs/CLIENT_ZERO_CASE_STUDY.md` 新規 (10 セクション / 12 fleet 構成 / 4 日 8 軸 / dogfood 5 例 / Phase 計画 / Use Case 3 種 / NEC pattern 模倣) | #3 Client Zero dogfood | 2.0 → **3.0/7** |
| 2026-04-29 | Win版#132 part 76 | `docs/HANDOFF_BUNDLE_SPEC.md` 新規 (= 全 stack 統合委譲形式 / ディレクトリ構造 + 6 Step flow + README フォーマット + 3 Use Case) | #4 Handoff Bundle dogfood | 3.0 → **4.0/7** |
| 2026-04-29 | Win版#132 part 77 | `docs/handoff-bundles/20260429_feature_review_scheduled_task/` 新規 (= Bundle 第 1 適用 / README + routing + workflow skeleton + py skeleton + config.json + SCHEDULE_TASKS.md 更新) | #4 Bundle 第 1 適用 (= 形式 → 即適用) | 4.0/7 (継続) |

**次回ターゲット**:
- #6 task_budget 統合: `_shared/task_budget.ts` → Codex#2 cross-instance-pr 候補
- #7 effort_router: `_shared/effort_router.ts` → Codex#2 cross-instance-pr 候補
- #3 Client Zero 営業資料化: `docs/CLIENT_ZERO_CASE_STUDY.md` → Win版 territory
- #2 orchestrator-hub: 新 EF skeleton → Codex#2 cross-instance-pr 候補
- #1 MCP `ui://` リソース: VSCode版 cross-instance-pr 候補

---

*Win版#132 part 67 / 2026-04-28 起票 / NotebookLM e89d2ca7 "Anthropic Evolution: Claude Apps, Opus 4.7, and Enterprise Expansion" 蒸留 / Rule [PLATFORM-31] / 9 番目の設計軸 (= 戦略 + 技術ミックス層 / Workplace OS 化 playbook)*
