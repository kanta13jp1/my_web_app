# Fleet Scaling Roadmap — 自分株式会社 12 → 24 → 100 instance 拡大計画

> このドキュメントは、自分株式会社の AI fleet を **半年単位** で拡大するための **段階計画** + **CEO 作業時間配分** + **bottleneck analysis** を定義する.
>
> **VIBE_CODING 原則 #7 (Embrace Exponentials)** dogfood. 「AI のタスク処理能力が 7 ヶ月で倍増する未来を見据え、CEO がコードを読むボトルネックになることを意図的に放棄する」原則を **具体的拡大数値** に落とし込む.

---

## なぜ必要か

VIBE_CODING #7 は概念のみで「**いつ何を増やすか**」が未定義だった. 結果:

- 「24 fleet にする」は願望のみ / 着手タイミング不明
- 「100 fleet」が遠い未来扱いで現実的計画なし
- CEO 作業時間配分も「30/30/20/10/10」と原則のみ / 月次の実数値配分なし
- bottleneck (= task_budget / effort_router 未実装) との依存関係不明

= **数値化された roadmap** がないと VIBE_CODING #7 は永久に部分実装止まり.

---

## 現状 (2026-04-29 時点)

### Fleet 構成

| カテゴリ | 数 | 内訳 |
| --- | --- | --- |
| Claude Code | 10 | VSCode / Win / PS#1-#6 / WEB / 📱モバイル |
| Codex CLI | 2 | Codex#1 (横断調査) / Codex#2 (CI・運用) |
| **合計** | **12** | (canonical: docs/MULTI_INSTANCE_FLEET.md) |

### 補助 AI (= fleet 外 / 必要時起動)

- Gemini Code Assist (Google/Flutter/Firebase 系)
- GitHub Copilot (inline / テスト追加)
- Manus AI (ブラウザ操作 / 外部 SaaS 確認)
- NotebookLM (リサーチ / Master Brain / 軸蒸留パイプライン)

### 実測スループット

- 1 セッション = 14 part 達成済 (= Win版#132 / 2026-04-28)
- 1 日累計 = cross-instance-pr 9 件 + 当日完了 4 件 (= part 60 session_summary)
- 4 日間 NotebookLM 蒸留 = 8 軸確立 / 75+ 原則
- = **5-7x スループット** (= 単独 Claude 開発比)

### 既存制約

| 制約 | 影響 | 解消候補 |
| --- | --- | --- |
| WORKDIR-ISOLATION rule | 各 instance 別 worktree 必須 | (制約 = 維持) |
| API quota | claude-haiku-4-5 / claude-sonnet-4-6 月額 | task_budget 実装 (= PLATFORM #6) |
| effort 一律設定 | Opus 高 effort で全機能 = 浪費 | effort_router 実装 (= PLATFORM #7) |
| memory/ inflation | MEMORY.md 32.4KB → 127KB rotation 発生 | hybrid search EF (= SECOND_BRAIN #7) |
| CEO 認知負荷 | 12 fleet を 1 人で管理 | megaprompt routine (= SECOND_BRAIN #6) |

---

## 拡大段階 (= 半年単位 milestone)

### Phase 1: 12 → 18 fleet (2026-Q3 / 6 ヶ月後)

**目標**: 既存 12 fleet 安定運用 + 6 instance 追加 = 18 fleet.

**追加 6 instance**:
| 新 instance | territory | 役割 |
| --- | --- | --- |
| Claude#11 (= AI 大学コンテンツ専任) | `lib/data/ai_university/` | 318+ provider の継続更新 / PS#3 から分離 |
| Claude#12 (= モバイル UI 専任) | `lib/pages/mobile_*` | iOS / Android UA 別の最適化 |
| Codex#3 (= migration 専任) | `supabase/migrations/` | timestamp collision / time-relative drift / RLS audit |
| Codex#4 (= EF refactor 専任) | `supabase/functions/` | EF-CAP-50 維持 / hub 統合継続 |
| PS#7 (= ブログ engagement 専任) | `scripts/blog_engagement.py` | dev.to / Qiita reply (= AUTO-REPLY rule 厳守) |
| Manus AI (= 常時稼働化) | 外部 SaaS / ブラウザ | Slack workspace / Notion API 連携の有人補助 |

**前提条件 (= 拡大ブロッカー解消)**:
- [ ] task_budget 実装完了 (= PLATFORM_EVOLUTION #6 / Codex#2)
- [ ] effort_router 実装完了 (= PLATFORM_EVOLUTION #7 / Codex#2)
- [ ] memory-search-hub EF 実装完了 (= SECOND_BRAIN #7 / Codex#2 / 既に part 70 委譲中)
- [ ] consolidate-memory --lint (= SECOND_BRAIN #4 / PS#1 / 既に part 69 委譲中)
- [ ] Slack workspace 接続 (= OPS-28 SoT 層 #4 活性化)

**スループット予測**: 1.5x (= 12 → 18 fleet) と仮定すれば 1 日累計 cross-instance-pr 13.5 件.

### Phase 2: 18 → 24 fleet (2027-Q1 / 1 年後)

**目標**: 18 → 24 fleet (= +6).

**追加 6 instance**:
| 新 instance | territory | 役割 |
| --- | --- | --- |
| Claude#13 (= 動画パイプライン専任) | `scripts/video/` | AI_VIDEO 6 原則の継続実装 (Realtime Avatar 等) |
| Claude#14 (= Workplace OS 統合専任) | `supabase/functions/orchestrator-hub` | PLATFORM_EVOLUTION #2 の orchestration |
| Claude#15 (= エンタープライズ営業専任) | `docs/sales/` (新規) | Client Zero 資料化 / NEC pattern 模倣 |
| Codex#5 (= MCP server 専任) | `supabase/functions/_mcp_*` | MCP_AUTH 10 原則の継続実装 |
| Codex#6 (= 監査・lint 専任) | `scripts/check_*.py` | 5 軸の compliance script 自動実行 |
| Gemini (常時稼働) | Flutter refactor / 長文 | 大規模リファクタ専任 |

**前提条件**:
- [ ] Phase 1 全完了
- [ ] orchestrator-hub EF 実装 (= PLATFORM #2)
- [ ] CLIENT_ZERO_CASE_STUDY.md (= PLATFORM #3 / Win territory)
- [ ] memory-search-hub MCP server 公開 (= SECOND_BRAIN #7 + MCP_AUTH 10/10 完成)
- [ ] Notion API 接続 (= OPS-28 SoT 層 #2 活性化)

### Phase 3: 24 → 50 fleet (2027-Q4 / 2 年後)

**目標**: 24 → 50 fleet (= +26 / 2x 拡大).

**追加 26 instance** (= 概要):
- Claude × 14 (= 機能領域別の特化 / AI 大学 / 動画 / 競馬 / モバイル各種など)
- Codex × 6 (= 特定 stack 別の専任 / RLS / EF / GHA / migration / docs / test)
- 補助 AI 常時稼働 × 6 (= Gemini / Copilot / Manus / NotebookLM / 新規 AI provider 等)

**前提条件**:
- [ ] Phase 2 全完了
- [ ] AI 大学 500+ provider (= PS#3 拡大)
- [ ] 競合 SaaS 1000+ ベース (= PS#4 拡大)
- [ ] エンタープライズ顧客 N=10+ (= Client Zero 営業実績)
- [ ] 24 fleet 拡大時の bottleneck audit 完了 (= 月次レポート 6 ヶ月分)

### Phase 4: 50 → 100 fleet (2028-Q3 / 3 年後 / IPO 期)

**目標**: 50 → 100 fleet. **AI 駆動経営の世界先進事例** として確立.

**条件**:
- [ ] エンタープライズ顧客 N=100+
- [ ] CEO 作業時間 = 95%+ が「設計判断 / 戦略 / 検証システム」(= コード読まない宣言の実証)
- [ ] 全 9 設計軸 + 2 メタ/戦略軸の baseline 6/7+ 達成
- [ ] PHILOSOPHY 原則 #9 (IPO/ウェルビーイング) ゴールに接続

= **3 年で 12 → 100 = 8.3x** = 7 ヶ月倍増 4 サイクル相当 (= AI のタスク処理能力進化速度に追従).

---

## CEO 作業時間配分 (= 月次実数値目標)

### 現状 (2026-04 時点 / 推定)

| カテゴリ | 配分 | 月次時間 (= 160h 想定) |
| --- | --- | --- |
| 設計軸 docs 更新 / 軸蒸留 | ~25% | ~40h |
| Plan / routing / cross-instance-pr | ~20% | ~32h |
| 本番 UI 検証 (= Playwright + 手動) | ~10% | ~16h |
| NotebookLM 蒸留 | ~5% | ~8h |
| **コードを読む** (= 削減対象) | **~30%** | **~48h** |
| その他 (= バグ triage / 調整) | ~10% | ~16h |

### 目標 (Phase 2 完了 = 2027-Q1)

| カテゴリ | 配分 | 月次時間 |
| --- | --- | --- |
| 設計軸 docs 更新 | **30%** | 48h |
| E2E test シナリオ設計 | **30%** | 48h |
| Plan / routing | **20%** | 32h |
| 本番 UI 検証 | **10%** | 16h |
| NotebookLM 蒸留 + 競合調査 | **10%** | 16h |
| **コードを読む** | **0%** | **0h** ← VIBE #7 完成形 |

= 「**コードを読まない CEO**」を 1 年以内に達成.

### 移行 milestone

- **2026-Q3** (Phase 1 完了): コード読み 30% → 15% (= 半減)
- **2027-Q1** (Phase 2 完了): コード読み 15% → 0% (= 完全放棄)
- **2027-Q4** (Phase 3 完了): その時間を「戦略 / NotebookLM 蒸留」に再配分
- **2028-Q3** (Phase 4): IPO 準備 / 「AI 駆動経営」の対外発信

---

## Bottleneck 分析

### Phase 1 ブロッカー (= 半年以内に解消必要)

| ブロッカー | 影響 | 解消 PR | 担当 | 状態 |
| --- | --- | --- | --- | --- |
| API quota 暴走 | fleet 拡大で月コスト数十万円 | task_budget (PLATFORM #6) | Codex#2 (新規 cross-instance-pr 必要) | 未起票 |
| effort 浪費 | 全機能 high effort で API 浪費 | effort_router (PLATFORM #7) | Codex#2 | 未起票 |
| memory/ inflation | 100+ files 検索が遅い | memory-search-hub (BRAIN #7) | Codex#2 | ⏳ 委譲中 |
| 孤児ノート増殖 | 知識が眠る | consolidate-memory --lint (BRAIN #4) | PS#1 | ⏳ 委譲中 |
| Slack 形骸化 | 通知が機能しない | Slack workspace 接続 | Manus AI | 未着手 |
| ターミナル監視 (= Win版#132 part 85 追加) | CEO の monitoring time 月 20-40h / fleet 拡大時 物理不可能 | Claude Code mobile push 採用 (= /remote-control + /config) | 全 12 fleet (= part 85 cross-instance-pr) | ⏳ 委譲中 |

### Phase 2 ブロッカー

| ブロッカー | 影響 | 解消 |
| --- | --- | --- |
| orchestrator-hub 不在 | 21 競合との差別化弱い | PLATFORM #2 実装 |
| Client Zero 営業資料 不在 | エンタープライズ訴求弱い | PLATFORM #3 / Win territory |
| MCP server 未公開 | Claude Code / Cursor 連携不可 | MCP_AUTH 10/10 完成 |
| Notion 形骸化 | WBS が陳腐化 | Notion API 接続 |

### Phase 3-4 ブロッカー

| ブロッカー | 影響 | 解消 |
| --- | --- | --- |
| 50+ fleet の人事管理 | 役割分担が複雑化 | INSTANCE-ROLES rule の自動 routing |
| 軸が 15+ 個に増殖 | 設計軸 docs が読めない規模 | 軸の階層化 + 整理 (= part 67 で 3 層化済 / 継続) |
| エンタープライズ顧客 SLA | bug 反応速度 | OPS-28 SLA を顧客向けに具体化 |

---

## Scaling 哲学 (= 拡大時の判断基準)

### 拡大すべき時

- 既存 fleet が **同じタスクを並行** している (= 役割重複)
- 1 instance に **複数 territory** 集中している (= 認知負荷大)
- **特定 stack の専門性** が必要 (= MCP / Realtime / Vision 等)
- **時差** で 24h 稼働化したい (= 海外発注的 instance / 将来)

### 拡大すべきでない時

- 既存 fleet の cross-instance-pr が **詰まっている** (= 受領 lane 崩壊)
- task_budget 未実装 (= コスト破綻リスク)
- effort_router 未実装 (= 効率破綻)
- CEO の認知負荷が **既に飽和** (= megaprompt 不在で個別説明)

= **拡大の前に bottleneck 解消**. 順序を間違えると拡大が失敗する.

---

## 連携軸

| 軸 | 連携内容 |
| --- | --- |
| **VIBE_CODING #7** (Embrace Exponentials) | 本 docs = #7 dogfood. baseline 5.5 → 6.5/7 |
| **PLATFORM_EVOLUTION #6** (Budget Control) | task_budget 実装が Phase 1 ブロッカー |
| **PLATFORM_EVOLUTION #7** (Effort Tuning) | effort_router 実装が Phase 1 ブロッカー |
| **SECOND_BRAIN #7** (Hybrid Search) | memory-search-hub が Phase 1 ブロッカー |
| **OPS-28 charter** | 5 SoT 層 (Slack / Notion 接続) が Phase 1-2 ブロッカー |
| **PHILOSOPHY #9** (IPO/ウェルビーイング) | Phase 4 のゴール |
| **PLATFORM_EVOLUTION #3** (Client Zero) | 拡大の営業資料に転用 |

= 7 軸に明示的接続. fleet 拡大 = 全軸の baseline 達成と連動.

---

## 整合性監査 (定期セルフレビュー)

`scripts/audit_fleet_scaling.py` (将来追加):
- 月次 fleet 数 + 月次 cross-instance-pr 件数を集計
- bottleneck list の解消状況を tracking
- CEO 作業時間配分の実数値 (= GitHub commit / Notion task 集計から推定)
- Phase milestone の達成度
- 違反 / 遅延検出時は GitHub Issue 自動作成

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 73 | `docs/FLEET_SCALING_ROADMAP.md` 新規 (4 Phase 計画 + CEO 配分目標 + bottleneck 分析 + scaling 哲学) | VIBE_CODING #7 dogfood | VIBE 5.5 → **6.5/7** |

---

*Win版#132 part 73 / 2026-04-29 起票 / VIBE_CODING #7 (Embrace Exponentials) dogfood / 4 Phase milestone (12→18→24→50→100) / 3 年で 8.3x 拡大計画 / CEO「コード読まない」目標 1 年以内 / Phase 1 ブロッカー 5 件明示 → part 85 で 6 件目 (mobile push) 追加*
