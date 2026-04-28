# 12-Instance Fleet Manifest — 自分株式会社マルチ AI 並行開発

> このドキュメントは、自分株式会社の開発体制を構成する **10 個の Claude Code インスタンス
> + 2 個の Codex インスタンス = 計 12 並行スロット** の **canonical (唯一の正規) ロスター** である。
>
> 既存の `docs/INSTANCE_CONFIG.md` (3 インスタンス制 / 2026-04-17) /
> `docs/MULTI_INSTANCE_COORDINATION.md` (5 インスタンス制 / 2026-04-19) /
> `docs/instance-constraints.md` (制約発見ログ) は **本ドキュメントが優先**。
> 旧 docs は段階的に本ドキュメントへ統合する (cross-instance-pr to PS#1)。
>
> **位置づけ**: CLAUDE.md `[WORKDIR-ISOLATION]` rule の運用台帳。
> **運用憲章 (5 正本 + 6 AI 役割 + 監査)**: [`docs/OPERATIONS_CHARTER.md`](./OPERATIONS_CHARTER.md) を併せて参照。本ドキュメントは物理層 (worktree/branch 割当) / OPERATIONS_CHARTER は論理層 (運用ポリシー)。

---

## 12 スロット (固定 worktree 名)

### 10 Claude Code インスタンス

| スロット | worktree path | branch | 推奨モデル | 主担当領域 |
| --- | --- | --- | --- | --- |
| **VSCode版** | `.claude/worktrees/instance-vscode` | `claude/vscode-wip` | claude-haiku-4-5 (Auto) / sonnet-4-6 (重い設計) | `lib/` Flutter UI + `supabase/functions/` EF |
| **Win版** (本ドキュメント実行者) | `.claude/worktrees/instance-win` | `claude/win-wip` | claude-haiku-4-5 (Auto) / sonnet-4-6 | `docs/` (DESIGN.md 除く) + `supabase/migrations/` schema + 動画パイプライン |
| **PS版#1** | `.claude/worktrees/instance-ps1` | `claude/ps1-wip` | haiku-4-5 / sonnet-4-6 (設計時) | Rule 17 — `.github/workflows/` 健全性 / インスタンス設定 oversight |
| **PS版#2** | `.claude/worktrees/instance-ps2` | `claude/ps2-wip` | haiku-4-5 (`/fast`) | T-1 ブログ dispatch (dev.to / Qiita) |
| **PS版#3** | `.claude/worktrees/instance-ps3` | `claude/ps3-wip` | haiku-4-5 (`/fast`) | AI 大学コンテンツ追加 (260 社運用) |
| **PS版#4** | `.claude/worktrees/instance-ps4` | `claude/ps4-wip` | haiku-4-5 / sonnet-4-6 | 競合モニタリング (172 社 sitemap / pricing / japan_presence) |
| **PS版#5** | `.claude/worktrees/instance-ps5` | `claude/ps5-wip` | haiku-4-5 | EF 整理・stale EF 移行・anon-guard 等の bulk 修正 |
| **PS版#6** | `.claude/worktrees/instance-ps6` | `claude/ps6-wip` | haiku-4-5 | 競馬予想モデル + worktree 整理 |
| **WEB版** | (worktree なし — GitHub MCP のみ) | — | sonnet-4-6 (variable) | リモート PR / Issue 管理 (Flutter / Deno / git ローカル不可) |
| **📱 スマホ版** | (worktree なし — GitHub MCP のみ) | — | sonnet-4-6 (画像分析重視) | 実機 UAT (iOS Safari / PWA / touch gesture) → Issue 自動化 |

### 2 Codex インスタンス (新規スロット)

| スロット | worktree path | branch | モデル | 主担当領域 |
| --- | --- | --- | --- | --- |
| **Codex#1** | `.claude/worktrees/instance-codex1` | `codex/codex1-wip` | GPT-5.2-Codex | 横断調査 / 修正 PR / SQL・migration レビュー補助 |
| **Codex#2** | `.claude/worktrees/instance-codex2` | `codex/codex2-wip` | GPT-5.2-Codex | CI / 同期 / 運用まわり / EF(Deno)・GHA レビュー補助 |

> **既存 Codex worktree の扱い**: 現在 `C:/Users/kanta/GitHub/my_web_app_ci_fix` /
> `_horse_fix` / `_version_fix` / `_wbs_sync` の 4 本が ad-hoc に存在する。
> これらは Codex#1 / Codex#2 の 2 スロットに段階的に統合する (移行プランは末尾参照)。

---

## 役割分担マトリクス (write 権限の境界)

| 領域 | 主担当 | 副 (overflow 時) | 完全禁止 |
| --- | --- | --- | --- |
| `lib/` Flutter UI | VSCode版 | Gemini Code Assist / Copilot (補助) | Win版 / 全 PS版 / Codex#1 / Codex#2 |
| `supabase/functions/` EF | VSCode版 | Win版 (動画スクリプト系のみ) | 全 PS版 (workflow/seed/AI 大学経由のみ) |
| `supabase/migrations/` | Win版 (schema) / PS#3-#5 (seed) | VSCode版 (新機能伴う schema) | — |
| `.github/workflows/` | PS#1 | PS#5 (緊急時) | VSCode版 / Win版 / Codex |
| `docs/DESIGN.md` | VSCode版 | (なし) | 全他 |
| `docs/` (DESIGN.md 除く) | Win版 | PS#1 (rule docs) | — |
| `scripts/video/` 動画パイプライン | Win版 | (なし) | — |
| ブログ drafts (`docs/blog-drafts/`) | PS#2 | Win版 (技術系のみ) | — |
| AI 大学コンテンツ | PS#3 | Win版 (NotebookLM 由来のみ) | — |
| 競合 172 社 (`competitors` table 系) | PS#4 | (なし) | — |
| EF stale 移行 / anon-guard | PS#5 | (なし) | — |
| 競馬モデル (`horse_*` table 系 / fetch スクリプト) | PS#6 | Codex#2 (アルゴリズム / レビュー補助) | — |
| **横断調査 / 修正 PR / レビュー補助** | **Codex#1** | Codex#2 | — |
| **CI / 同期 / 運用まわり** | **Codex#2** | Codex#1 | — |
| GitHub Issue / PR (リモート) | WEB版 / スマホ版 | 全インスタンス | — |

---

## 12 スロットの並行性ルール

### 1. ファイル衝突回避

各スロットは上表の **主担当領域のみ** を write する。副担当領域に踏み込むときは
事前に `docs/cross-instance-prs/YYYYMMDD_<title>.md` を起票して主担当に通知。

### 2. branch push と main 統合

全スロットはまず担当 branch に push する。`origin/main` への直 push は、競合確認・検証・統合判断が終わった場合のみ行う。

```bash
git fetch origin main
git log HEAD..origin/main --oneline   # 並行 push を検知
git pull --rebase origin main          # 衝突時は手動 resolve
git push -u origin HEAD                # まず担当 branch を更新
# 統合確認後のみ:
git push origin HEAD:main
```

### 3. Codex 特有の運用

Codex はユーザーが手動で起動する CLI / IDE プラグインのため、以下のルール:

- **Codex は session を持たない** → 1 task 完了後 git commit + push まで実施したら
  Claude Code に hand-off (= 検証・PR 作成は Claude が担う)
- **CLAUDE.md 全文を context に投入できない** → 各タスクの起動時に
  `docs/cross-instance-prs/YYYYMMDD_codex_<title>.md` で要件 + 既存 pattern を要約
- **flutter analyze / deno lint は Codex 自身が走らせる** (合格まで commit しない)
- **メモリ管理は Claude Code 担当** → `memory/` には Codex 自身が書き込まない /
  完了後 Claude が memory に記録

### 4. 推奨モデル別タスク routing

| タスク種別 | 推奨スロット |
| --- | --- |
| 設計判断 / 戦略 / cross-instance-pr 起票 / memory consolidation | **Win版 / VSCode版** (Claude 専任) |
| 大きめの実装 / 既存設計に沿った機能追加 | **Claude Code** 各担当 worktree |
| Flutter UI 実装 (新規 / 中規模) | VSCode版 + Gemini Code Assist / Copilot |
| Flutter UI 大規模 refactor (500+ 行) | VSCode版 + Gemini Code Assist |
| EF 新規実装 | VSCode版 |
| EF アルゴリズム最適化 (N+1 / 集計ロジック) | VSCode版 / Codex#2 レビュー補助 |
| Migration 新規 (schema) | Win版 |
| Migration seed (AI 大学 / 競合) | PS#3 / PS#4 |
| 修正 PR / 横断調査 / レビュー補助 | **Codex#1** |
| GHA workflow 修正 / CI fix / 同期運用 | PS#1 / **Codex#2** |
| ブログ dispatch | PS#2 |
| IDE 内の短距離実装 / テスト追加 | GitHub Copilot |
| 外部 SaaS 確認 / ブラウザ操作 / 長めの手順実行 | Manus AI |
| 判断履歴 / 設計意図 / 学びの集約 | NotebookLM |
| 競馬モデル | PS#6 / Codex#2 (協働) |
| リモート PR レビュー / 緊急 hotfix (1 行) | WEB版 / スマホ版 |

---

## main repo との関係

```text
C:/Users/kanta/GitHub/my_web_app                      [main]              ← push target only / 編集禁止
├── .claude/worktrees/instance-vscode                 [claude/vscode-wip]
├── .claude/worktrees/instance-win                    [claude/win-wip]
├── .claude/worktrees/instance-ps1                    [claude/ps1-wip]
├── .claude/worktrees/instance-ps2                    [claude/ps2-wip]
├── .claude/worktrees/instance-ps3                    [claude/ps3-wip]
├── .claude/worktrees/instance-ps4                    [claude/ps4-wip]
├── .claude/worktrees/instance-ps5                    [claude/ps5-wip]
├── .claude/worktrees/instance-ps6                    [claude/ps6-wip]
├── .claude/worktrees/instance-codex1                 [codex/codex1-wip]
└── .claude/worktrees/instance-codex2                 [codex/codex2-wip]

C:/Users/kanta/GitHub/my_web_app_ps                   [ps-main]            ← レガシー (PS版#1 が定常使用 - 検証中)
C:/Users/kanta/GitHub/my_web_app_win                  [win-main]           ← レガシー (Win版が定常使用 - 検証中)
```

---

## Codex 4 worktree → 2 スロット統合プラン (移行)

現状 ad-hoc な codex worktree:
- `C:/Users/kanta/GitHub/my_web_app_ci_fix` [`codex/ci-final-field-fix`]
- `C:/Users/kanta/GitHub/my_web_app_horse_fix` [`codex/horse-learning-loop`]
- `C:/Users/kanta/GitHub/my_web_app_version_fix` [`codex/fix-header-version-badge`]
- `C:/Users/kanta/GitHub/my_web_app_wbs_sync` [`codex/fix-wbs-issue-sync`]

### 移行手順 (User 操作 / 1 回のみ)

```bash
# Step 1: 既存 codex worktree を main に rebase + merge
for d in my_web_app_ci_fix my_web_app_horse_fix my_web_app_version_fix my_web_app_wbs_sync; do
  cd C:/Users/kanta/GitHub/$d
  git fetch origin main
  git pull --rebase origin main
  git push origin HEAD:main 2>&1 | tail -2
done

# Step 2: ad-hoc worktree を削除
cd C:/Users/kanta/GitHub/my_web_app
git worktree remove --force C:/Users/kanta/GitHub/my_web_app_ci_fix
git worktree remove --force C:/Users/kanta/GitHub/my_web_app_horse_fix
git worktree remove --force C:/Users/kanta/GitHub/my_web_app_version_fix
git worktree remove --force C:/Users/kanta/GitHub/my_web_app_wbs_sync

# Step 3: 標準 codex slot を作成
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex1
powershell -ExecutionPolicy Bypass -File .claude/scripts/setup-instance-worktree.ps1 codex2
```

### 移行後の運用

- Codex#1 タスク開始時 → `cd .claude/worktrees/instance-codex1 && git pull --rebase origin main`
- Codex#2 タスク開始時 → `cd .claude/worktrees/instance-codex2 && git pull --rebase origin main`
- 完了時 → `git push -u origin codex/codex1-wip` / `git push -u origin codex/codex2-wip`
- Claude Code (Win版) が memory/ + cross-instance-pr で結果を記録

---

## ベースライン健全性チェック

セッション開始時に以下を確認:

```bash
# 12 スロット全部の HEAD と main との乖離を確認
git worktree list
git for-each-ref --format='%(refname:short) %(committerdate:relative)' refs/heads/claude refs/heads/codex \
  | column -t
```

期待値:
- すべてのスロットが直近 1 週間以内に commit がある (= 死んでいない)
- main との commit 差分が 50 件未満 (= rebase が遅延していない)

---

## 改訂履歴

| 日付 | 変更 | 担当 |
| --- | --- | --- |
| 2026-04-28 | 初版 (10 Claude + 2 Codex = 12 スロット fleet manifest) | Win版#132 part 44 |
