# Core/Leaf 境界 + 3 層ナレッジ分離 — 自分株式会社 Vibe Coding 許可マトリクス

> このドキュメントは、自分株式会社の **12 instance fleet が編集してよい範囲** を **物理的境界** として明示する **必守原則** である.
>
> **2 軸同時 dogfood**:
> - **VIBE_CODING 原則 #1** (Trunk/Leaf 厳格分離) → コア (人間管理) vs リーフ (12 fleet 全委任) の境界
> - **SECOND_BRAIN 原則 #1** (階層型ナレッジ厳格分離) → Layer 1 (immutable) / Layer 2 (evolving wiki) / Layer 3 (schema) の 3 層
>
> = 両軸の概念が **重なる** ため、本 docs で **統合表現** = 1 doc で 2 軸同時押上.

---

## なぜ必要か

12 instance × 数百 commit/日 で AI が production code を直接書く状況下、**「どこなら AI に全委任 OK か / どこは人間が守るか」** を **物理的境界** として明示しないと:

- AI が schema (= DB migration) を勝手に書き換え → 全機能連鎖破壊
- AI が core docs (= 設計軸 docs) を勝手に refactor → 設計言語が崩壊
- AI が design system (= DESIGN.md) を勝手に変更 → UI 統一性崩壊

逆に、明示すれば:
- リーフ (= widget / EF action 単発 / seed) は **AI 全委任** で 12 fleet 並列高速開発
- コア (= schema / _shared / 設計軸) は **人間管理** で安定性担保

= **境界の明示そのものが Vibe Coding を成立させる前提条件**.

---

## 統合層 (= VIBE_CODING + SECOND_BRAIN 統合表現)

| 統合層 | VIBE_CODING 表現 | SECOND_BRAIN 表現 | AI 編集可能? |
| --- | --- | --- | --- |
| **Tier 0** | Schema (= AI 動作ルール) | Layer 3 (schema) | **❌ CEO 専任** |
| **Tier 1** | Core (= 他が依存) | Layer 1 (immutable) + Layer 2 重要 file | **❌ 人間レビュー必須** |
| **Tier 2** | Leaf (= 単独機能) | Layer 2 (evolving wiki) 通常 file | **✅ AI 全委任 OK** |
| **Tier 3** | (Vibe Coding 対象外 = 自動生成) | Layer 1 (immutable source) | **△ 出力は自動 / 編集は AI 不可** |

= 4 階層. AI 全委任 OK な範囲は **Tier 2 のみ**.

---

## Tier 0: Schema (CEO 専任 / 編集禁止)

**定義**: AI fleet 全体の動作ルールを定める file. 1 行変更で 12 instance 全員の振舞いが変わる.

### 該当 file

- `~/.claude/hooks/inject-rules.txt` (= 毎ターン注入される rule / 全 instance 共通)
- `CLAUDE.md` (= プロジェクト Facts + hook table / 全 instance 共通)
- `docs/OPERATIONS_CHARTER.md` (= 12 fleet 運用憲章 / 5 正本 + 6 役割 + 5 監査)
- `docs/CODEX_WORKFLOW.md` (= Codex routing 5 質問 matrix)
- `docs/MULTI_INSTANCE_FLEET.md` (= 12 スロット roster + worktree paths)
- `docs/PHILOSOPHY.md` 等 設計軸 9 docs (= PHILOSOPHY/AI_DEV/AI_CHARACTER/IMBUE/COLLAB_AI/MCP_AUTH/AI_VIDEO/VIBE_CODING/PLATFORM_EVOLUTION/SECOND_BRAIN)
- `docs/DESIGN.md` 等 design system docs

### AI 編集ポリシー

❌ **AI 直接編集禁止**. CEO が手動で更新.

例外:
- ✅ AI が **新軸** (= NotebookLM 蒸留 → 新 docs/<NAME>_PRINCIPLES.md) を **追加** する場合は OK (= 既存軸を破壊しない範囲)
- ✅ AI が hook table に Rule [N] を **append** する場合は OK
- ❌ AI が既存 Rule の文言を refactor / merge / rename するのは NG

---

## Tier 1: Core (人間レビュー必須)

**定義**: 他の機能 / instance / migration が依存する基盤 file. 変更には影響範囲分析が必要.

### 該当 file

#### Backend (Supabase)
- `supabase/migrations/*.sql` の **schema 変更** (= CREATE TABLE / ALTER TABLE / RLS policy)
- `supabase/functions/_shared/*.ts` (= 共通モジュール / ai_character_preamble / mcp_auth_guard / ai_action_schema)
- `supabase/functions/<hub>/index.ts` (= hub 化 EF の routing layer)

#### Frontend (Flutter)
- `lib/main.dart` (= routing 設計 / 全 page entry)
- `lib/widgets/global_*.dart` (= GlobalHeader, GlobalFooter 等 / 全 page で使用)
- `lib/services/*.dart` (= Supabase / API クライアント)

#### Infrastructure
- `.github/workflows/deploy-prod.yml` (= 本番 deploy)
- `.github/workflows/cs-check.yml` (= CS automation)
- `firebase.json` / `pubspec.yaml` / `package.json` (= 全 build 影響)

#### Docs (Layer 1 immutable source)
- `memory/session_summary*.md` (= 過去のセッション総括)
- `memory/feedback_correction_*.md` (= 失敗パターン / 永久保持)
- NotebookLM Master Brain (= 外部 / 編集はソース追加のみ)
- claude-mem 圧縮ベクトル (= 自動生成 / 編集不可)

### AI 編集ポリシー

❌ **AI 単独編集禁止 / cross-instance-pr 経由必須**. CEO レビュー後 merge.

例外:
- ✅ schema 変更で **seed migration のみ** (= CREATE TABLE なし) なら Tier 2 扱い
- ✅ migration が WBS update / data backfill のみなら Tier 2 扱い
- ❌ RLS policy 変更 / table schema 変更は必ず Tier 1

---

## Tier 2: Leaf (AI 全委任 OK)

**定義**: 単独機能 / 単独 widget / 単独 action / 単独 seed. 他から import / 参照されない.

### 該当 file

#### Backend (Supabase)
- `supabase/functions/<hub>/<action>.ts` (= 既存 hub 内の **追加 action** / 単独機能)
- `supabase/migrations/YYYYMMDDxxxxxx_seed_*.sql` (= データ seed のみ / schema 変更なし)
- `supabase/migrations/YYYYMMDDxxxxxx_update_wbs_*.sql` (= WBS 進捗更新)

#### Frontend (Flutter)
- `lib/widgets/<single_widget>.dart` (= 他 widget から import されない単発 widget)
- `lib/pages/<single_page>.dart` (= main.dart から 1 routing のみ)
- `lib/data/<seed_data>.dart` (= 静的データ / hardcoded)

#### Generated Content
- `docs/blog-drafts/*.md` (= AI 生成記事 / T-1 dispatch 用)
- `docs/daily-reports/*.md` (= Schedule 自動生成)
- `docs/cs-notes/*.md` (= CS 自動生成)
- `docs/competitor-reports/*.md` (= 競合モニタリング自動生成)

#### Tests
- `test/widget_test.dart` 系 (= 単体テスト / 失敗しても本番影響なし)
- `integration_test/*.dart` (= E2E テスト / 仕様確認)

### AI 編集ポリシー

✅ **12 fleet 全委任 OK**. cross-instance-pr 不要 / 直接 commit & push.

ただし:
- VIBE_CODING #5 (Minimal E2E Tests) で 24h soak 安定確認は必須
- 失敗時は **roll forward / new commit** (= 過去 commit を amend しない / part 65 教訓)

---

## Tier 3: Auto-Generated (= 編集不可 / 出力のみ)

**定義**: AI / cron / pipeline が自動生成し、人間も AI も **編集してはいけない** file.

### 該当 file

- `web/sitemap.xml` (= GHA cron で自動生成)
- `docs/flutter-analyze-cache.json` (= cs-check が毎時更新)
- `docs/ticket-cache.json` (= GHA が毎時更新)
- `docs/schedule-logs/*.json` (= Schedule 実行ログ)
- `videos/*.mp4` (= notebooklm-video-pipeline.yml 出力)
- `~/.claude/projects/.../memory/claude-mem/*.db` (= claude-mem 自動圧縮)

### AI 編集ポリシー

❌ **AI も人間も編集禁止**. ソース (= cron / pipeline / migration) を変更すれば自動再生成される.

---

## memory/ 配下の Tier マッピング (= SECOND_BRAIN 主軸)

memory/ は **per-Windows-user local** (= `~/.claude/projects/.../memory/`). 全 file が Layer 2 だが、内部で更に分かれる:

| ファイル種 | Tier | 編集ポリシー |
| --- | --- | --- |
| `MEMORY.md` (= index) | Tier 1 (Core) | AI append OK / 既存行編集禁止 |
| `MEMORY_<period>.md` (= archive) | Tier 1 (Core / immutable) | **編集禁止** (= ローテ後は読取専用) |
| `log.md` (= Daily Log) | Tier 0 (Schema 相当 / append-only) | **append のみ** / 既存行編集禁止 |
| `project_*.md` (= Atomic Notes) | Tier 2 (Leaf) | AI 編集 OK |
| `query_artifact_*.md` (= Query 永続化) | Tier 2 (Leaf) | AI 編集 OK / 既存セクション維持推奨 |
| `feedback_correction_*.md` (= 失敗パターン) | Tier 1 (Core / immutable) | **編集禁止** (= 永久保持 / Layer 1) |
| `session_summary*.md` | Tier 1 (Core / immutable) | **編集禁止** (= Layer 1) |
| `query_artifact_TEMPLATE.md` | Tier 0 (Schema 相当) | **編集禁止** (= テンプレ) |

= memory/ 内でも **Tier 0/1/2** が混在. 編集ポリシーは file 種ごとに異なる.

---

## チェックリスト (新規 PR / 編集時)

PR 作成者が **必ず** 以下をチェック:

- [ ] 編集対象 file は **どの Tier** か?
- [ ] Tier 0 / 1 なら **cross-instance-pr 経由** か CEO レビュー予定があるか?
- [ ] Tier 2 なら **直接 commit OK** で 24h soak 計画あるか?
- [ ] Tier 3 を編集していないか? (= NG / ソース変更で対応)
- [ ] schema 変更を含む場合、`supabase/migrations/` で **新規 migration** か (= 既存編集 NG)?
- [ ] memory/ 編集時、`MEMORY_*.md` archive / `feedback_correction_*` / `session_summary*` を編集していないか?

---

## 既存 9 設計軸 + メタ軸との関係

| 軸 | 本 docs との関係 |
| --- | --- |
| **VIBE_CODING #1** (Trunk/Leaf 分離) | 本 docs = #1 dogfood. baseline 4.5 → 5.5/7 |
| **SECOND_BRAIN #1** (3 層ナレッジ分離) | 本 docs = #1 dogfood. baseline 3.5 → 4.0/7 |
| **MCP_AUTH #1** (DCR) | mcp_oauth_clients table = Tier 1 / 編集レビュー必須 |
| **OPS-28 charter** | 5 正本層 (Issues / WBS / NotebookLM / Slack / worktree) = Tier 0/1 |
| **PLATFORM_EVOLUTION #4** (Handoff Bundle) | bundle = 全 Tier を 1 PR でハンドオフする pattern |

= 5 軸に明示的接続. 1 doc で 2 軸 dogfood + 3 軸 augmentation.

---

## 整合性監査 (定期セルフレビュー)

`scripts/check_tier_compliance.py` (将来追加):
- git log から **Tier 0 編集** を抽出 → CEO レビュー有無確認
- **Tier 1 編集** が cross-instance-pr 経由か確認
- Tier 3 file の手動編集を検出
- 違反検出時は GitHub Issue 自動作成 (= COLLAB_AI Verifier-Generator + OPS-28 改善トリガー連携)

---

## 実装履歴

| 日付 | part | 実装 | 達成原則 | baseline |
| --- | --- | --- | --- | --- |
| 2026-04-29 | Win版#132 part 72 | `docs/CORE_LEAF_BOUNDARY.md` 新規 (4 Tier 統合表現 + memory/ 内部 Tier マッピング + チェックリスト + 整合性監査) | VIBE_CODING #1 + SECOND_BRAIN #1 同時 dogfood | VIBE 4.5→**5.5**/7, BRAIN 3.5→**4.0**/7 |

---

*Win版#132 part 72 / 2026-04-29 起票 / VIBE_CODING #1 + SECOND_BRAIN #1 同時 dogfood / 1 doc で 2 軸押上 第 1 例 / 4 Tier 統合表現 (Schema / Core / Leaf / Auto-Generated) / memory/ 内部 Tier マッピング*
