# Codex 並行開発ワークフロー

> 目的: Claude Code 10 インスタンスに、Codex 2 インスタンスを固定 worktree で追加し、横断調査 / 修正PR / CI・同期・運用 / レビュー補助を衝突少なく並行処理する。

## 1. インスタンス割当

| インスタンス | worktree | branch | 主担当 | 補助先 |
| --- | --- | --- | --- | --- |
| Codex#1 | `.claude/worktrees/instance-codex1` | `codex/codex1-wip` | 横断調査 / 修正PR / SQL・migration レビュー補助 | PS#3 / Win版 |
| Codex#2 | `.claude/worktrees/instance-codex2` | `codex/codex2-wip` | CI / 同期 / 運用 / EF(Deno)・GHA レビュー補助 | PS#1 / PS#5 / PS#6 |

Codex は Claude Code の代替司令塔ではなく、横断調査・修正PR・レビュー補助・CI/同期/運用まわりの補助枠として扱う。設計判断、cross-instance-pr、memory consolidation、最終統合判断は Claude Code 側に残す。

## 2. 起動手順

```bash
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex1
git fetch origin main
git rebase origin/main
codex
```

```bash
cd C:/Users/kanta/GitHub/my_web_app/.claude/worktrees/instance-codex2
git fetch origin main
git rebase origin/main
codex
```

未作成の環境では main repo から次を実行する。

```bash
cd C:/Users/kanta/GitHub/my_web_app
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex1
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex2
```

Git Bash / WSL が使える環境では、既存の Bash 版も利用できる。

```bash
bash .claude/scripts/setup-instance-worktree.sh codex1
bash .claude/scripts/setup-instance-worktree.sh codex2
```

## 3. 作業ルール

- main repo (`C:/Users/kanta/GitHub/my_web_app`) は直接編集しない。
- uncommitted 変更を長時間残さない。stash ではなく小さい commit か WIP commit で退避する。
- 原則は担当 branch に push する。

```bash
git push -u origin codex/codex1-wip
git push -u origin codex/codex2-wip
```

`git push origin HEAD:main` は、競合確認、test/lint、Claude Code 統合確認が終わった場合のみ使う。

## 4. 責任境界

Codex#1 が触る範囲:

- `supabase/migrations/**/*.sql`
- SQL seed / data backfill
- 横断調査結果の最小限の docs / handoff
- SQL生成に必要な最小限の docs / handoff

Codex#2 が触る範囲:

- `supabase/functions/**`
- algorithm / batch / scraper 改善
- `.github/workflows/**` の小規模補助
- CI / 同期 / 運用まわりの修正PR

共通して避ける範囲:

- UI / design 判断
- アーキテクチャ方針の変更
- WBS / memory の直接大規模編集
- 他インスタンスの担当ファイル

## 5. 正本チェック

Codex 作業開始時は、実装前に次を確認する。

- GitHub Issue / PR が実行単位として存在するか。なければ handoff に明記する。
- WBS / Notion の進捗・依存関係と矛盾していないか。
- NotebookLM に残すべき判断履歴や設計意図があるか。
- Slack に通知すべきブロッカー、handoff、緊急調整があるか。
- 同一ファイル、同一 DB スキーマ、同一 Edge Function、同一 workflow を他インスタンスが触っていないか。

## 6. WBS 連携

Codex CLI から WBS MCP を直接使えない場合は、作業完了時に次のどちらかで連携する。

1. `docs/cross-instance-prs/YYYYMMDD_codex<N>_<title>.md` に handoff を作る。
2. Claude Code 側へ WBS 更新を依頼する。

handoff には最低限、目的、変更ファイル、実行した検証、残リスク、次に見るべきインスタンスを記録する。

## 7. 推奨検証

SQL / migration:

```bash
supabase db lint
```

EF(Deno):

```bash
deno lint supabase/functions/<function-name>/index.ts
deno check supabase/functions/<function-name>/index.ts
```

Flutter 影響がある場合:

```bash
flutter analyze
```

検証不可の場合は、handoff に「未実行理由」と「依頼先」を明記する。

## 6. Codex に出すべきタスクの判断基準 (Win版#132 part 53 追加)

### 背景

2026-04-28 (OPS-28 1 日サイクル実証日) の振り返りで、**Win版が起票した cross-instance-pr 4 件のうち
Codex 担当 0 件 / 全 4 件が PS#1 + PS#5 (Claude) に集中** していた。Codex#1 / Codex#2 の固定枠を
fleet manifest で確保したのに routing が無く、Codex の役割が形骸化していた。

OPS-28 charter の AI ツール役割では Codex = 「横断調査 / 修正 PR / CI/同期/運用 / レビュー補助」
だが、**何を Codex に投げて何を Claude が握るか** の境界が曖昧だった。本セクションでこれを
明文化する。

### 判定 5 質問 (5 秒で Codex/Claude 振り分け)

タスク発生時、以下 5 つの質問に答える。**1 つでも YES = Claude / 全部 NO = Codex**:

```
Q1. 設計判断 / 既存設計と異なる選択肢の trade-off 検討が必要?
Q2. cross-instance 調整 (cross-instance-pr 起票や複数 owner との調整)?
Q3. memory / docs/ 軸 (PHILOSOPHY/AI_DEV/AI_CHARACTER/IMBUE/COLLAB_AI/MCP_AUTH/OPS-28) の更新?
Q4. 不確実性 / 「なぜそうしたか」を docs に残す価値ある判断?
Q5. user の文脈 / 過去判断履歴を読み解く必要 (= NotebookLM Master Brain 連携要)?
```

全部 NO → **Codex に出す** (= 機械的 / template ベース / 既存 pattern の複製)

### 典型 Codex 案件 (= 全部 NO のはず)

| カテゴリ | 例 | 期待時間 |
| --- | --- | --- |
| **SQL DDL / migration** | `CREATE TABLE foo (...)` を template ベースで書く | 5-15 min |
| **seed migration** | AI 大学 provider seed の type 別 boilerplate 適用 | 5-10 min |
| **Algorithm 最適化** | N+1 query → 集計 1 回 / バッチ size 調整 | 30-60 min |
| **大規模 refactor (500+ 行)** | dart format / lint cascade / pattern 全件適用 | 30-90 min |
| **CI fix** | yml の typo / output format 修正 / matrix 値追加 | 15-30 min |
| **既存 pattern 複製** | 新 EF action skeleton (既存 hub の case 文を新規 action に展開) | 15-30 min |

### 典型 Claude 案件 (= 1 つでも YES のはず)

| カテゴリ | 例 | なぜ Claude |
| --- | --- | --- |
| **設計判断** | 「memo-reactions を core-hub に統合するか別 EF か」 | trade-off + 既存設計理解 |
| **cross-instance-pr 起票** | OPS-28 改善トリガー検出 → 提案 | 文脈 + 複数 owner 整合 |
| **memory consolidation** | feedback_correction の追加 / shadow rule | 過去判断との整合 |
| **新軸ドキュメント** | docs/IMBUE_PATTERNS.md / docs/MCP_AUTH_*.md 等 | NotebookLM 由来の概念蒸留 |
| **アーキテクチャ判断** | 12 並行運用の routing 設計 (= 本セクション自体) | 全体俯瞰 + future-proof |
| **on-call hotfix の root cause 特定** | production 404 → どの commit / どの worktree か | 12 instance 横断調査 |

### Codex への handoff template (Win版が起票)

`docs/cross-instance-prs/YYYYMMDD_<title>_codex<N>.md` に以下を含める:

```markdown
## 起票背景
[なぜこのタスクが必要か / Claude が判断した root cause]

## 判定 5 質問の答え
- Q1 設計判断: NO (= 既存 pattern 適用のみ)
- Q2 cross-instance 調整: NO
- Q3 軸 docs 更新: NO
- Q4 docs に残す判断: NO (= mechanical)
- Q5 NotebookLM 連携: NO
→ **全 NO = Codex 適合**

## 既存 pattern (= Codex が複製する template)
[file path + line range / 既存 case 文 / 既存 migration 等]

## 期待アウトプット
- 変更ファイル: [list]
- 検証コマンド: [supabase db lint / deno lint / flutter analyze]
- 期待検証結果: [No errors / specific output]

## 完了条件
- [ ] 検証コマンド全部 pass
- [ ] git commit + push origin HEAD:main
- [ ] Win版 (起票者) が memory に記録 (Codex は memory 触らない)
```

### 推奨初回 handoff 候補 (本 part 起票時点)

1. **Codex#1 (SQL/algorithm)** — `scripts/audit_hub_migration_completeness.py` (PS#5 S75 実装) の
   検出ロジックを SQL 集計 view 化 (= mechanical SQL 移植)
2. **Codex#2 (refactor)** — Win版 part 50 で追加した `memo.react.list` / `memo.react.toggle`
   の test fixture (synthetic memo_reactions row) を `_smoke_test.py` 形式で書き起こし
3. **Codex#1 or #2** — `mcp_auth_guard.ts` (Win版 part 49 skeleton) の `validateBearer` 内
   TODO 6 項目のうち、jose lib import + JWKS fetch + cache 部分 (= mechanical)

これらは全 5 質問 NO = 機械的 template 適用なので Codex に振るのが routing 最適。

### 振り分け失敗時の救済

Codex に出したが想定と違う結果 → cross-instance-pr に「Claude (Win版/PS#1/PS#5) で再構築」
セクション追加して即 reroute。Codex の output が test 駆動で間違いに気づきやすい設計
(= 期待検証コマンドを必ず明記する) を維持する。

---

*Win版#132 part 53 追加 / 2026-04-28*

## 7. Harness Engineering Intake (NotebookLM bc58b50b / 2026-04-30)

### 背景

NotebookLM `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
「Codex vs Claude Code: The Ultimate AI Development Synergy」の要点は、個別エージェントの性能比較ではなく、
**正しい答えを出しやすい開発環境を設計する Harness Engineering** である。

本プロジェクトでは、Claude Code 10 枠 + Codex 2 枠 + GitHub Actions + NotebookLM を次の役割で固定する。

| 面 | 主担当 | 完了条件 |
| --- | --- | --- |
| 問題設定 / 設計判断 | Claude Code | handoff に判断理由・代替案・検証方針が残る |
| 横断実装 / SQL / migration / UI確認 | Codex#1 | clean worktree の PR と deterministic check が残る |
| CI / deploy / sync / Edge Function / GHA | Codex#2 | red check が green になり、再発防止メモが残る |
| 外部記憶 / Master Brain | NotebookLM | ノート由来の知見が WBS・Issue・docs・workflow のいずれかに反映される |
| 真実の場 | GitHub Actions | lint / test / deploy / sync の結果で成否を判定する |

### 5 レーン運用

NotebookLM の示す「AI agent synergy」は、次の 5 レーンに分けて WBS 上へ流す。

| レーン | 実装先 | 初回確認 |
| --- | --- | --- |
| Agent-in-agent / MCP | Claude Code が設計、Codex#2 が CI 化 | MCP/connector 設定がドキュメント化され、手動操作なしに疎通確認できる |
| Codex browser / UI QA | Codex#1 | UI 変更 PR にスクリーンショット・console エラー確認・必要なら Playwright が付く |
| StatusLine / PreCompact / hooks | Claude Code | session start / pre-compact / post-tool-use のどこで品質ゲートを置くか決まる |
| Worktrees / Memory / long-running state | Codex#1/#2 | 固定 worktree と担当 branch が WBS/Issue と一致する |
| Skill activation / tool search | Claude Code + Codex | 使う skill/tool を session start で宣言し、不要なコンテキスト展開を避ける |

### セッション開始チェック

Codex #1/#2 は作業開始時に次を実施する。

1. `python scripts/codex_session_check.py` で branch / upstream / dirty state / worktree / sandbox snapshot を確認する。
2. `python scripts/ai_tool_watch.py --print-only` で Claude Code / Codex 公式情報を確認する。
3. WBS の上位 20 件を見て、期限超過・CI失敗・同期ズレ・手動作業が反復している項目を優先する。
4. 役割境界に従い、Codex#1 は横断実装 / UI検証 / SQL、Codex#2 は CI / deploy / sync を優先する。
5. NotebookLM 由来の提案は、Issue / PR / docs / workflow / hook のどれかに落ちるまで完了扱いにしない。
6. 作業完了後、PR URL・検証結果・残タスクを WBS/Issue へ同期できる形で残す。

`codex_session_check.py` は Codex CLI 0.125.0 系の permission profile / session state 改善を運用に反映する
ための最小ハーネスである。Codex アプリ内部の権限状態を推測せず、実際の Git worktree と環境変数に
露出している情報だけを記録する。

### 再配分ルール

- 同じ種類の CI 失敗が 2 回以上続く場合、Codex#2 に「再発防止 workflow 化」を振る。
- UI/console エラーが本番で再発する場合、Codex#1 に「browser QA + screenshot gate」を振る。
- cross-instance 競合、設計判断、NotebookLM の概念蒸留が必要な場合、Claude Code に戻す。
- 手動確認が 3 回以上出る WBS タスクは、スケジュールタスク・GitHub Actions・Edge Function の候補として起票する。
## Current 2-Instance Override (2026-05-05)

Canonical flow is now Claude Code #1 (Windows app) + Codex #1 (Windows app).
This document keeps older Codex#2 / PS#1-6 / multi-worktree guidance as
legacy history only. New Codex work should use one Codex Windows app instance,
one active branch, and one shared dev server unless the user explicitly asks for
an exception.
