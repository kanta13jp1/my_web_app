# Fleet 12 → 2 instance 移行ログ — 2026-05-04 (Win版#132 part 130)

## 移行理由

User 要望 (= 2026-05-04):
> 開発環境のメモリーやトークン使用量の制限があるため、開発フローについて、
> Claude Code 1 インスタンス (Windowsアプリ版)、CodeX 1 インスタンス (Windowsアプリ版) の
> 2 インスタンス制に変更したい

## 制約 background

- **token 消費量**: 12 instance × 毎ターン inject (= CLAUDE.md 464 行 + inject-rules 372 行) = 隠れたコスト
  (= part 128 Karpathy 80 行 KPI 識別 / Issue [#1974](https://github.com/kanta13jp1/my_web_app/issues/1974))
- **メモリ制約**: 12 worktree + 12 home directory + 12 NotebookLM session = ローカル RAM / disk 圧迫
- **運用負荷**: User が 12 instance を並列管理 = 認知負荷大

## 移行決定

| 項目 | 旧 (12 instance) | 新 (2 instance) |
| --- | --- | --- |
| Claude Code | VSCode / Win / PS#1-6 / WEB / スマホ = 10 instance | **Win版 (Claude Code)** = 1 instance |
| Codex CLI | Codex#1 / Codex#2 + ad-hoc = 多数 | **Win版 (Codex CLI)** = 1 instance |
| 合計 | **12 instance** | **2 instance** |

## 役割統合 mapping

### Win版 (Claude Code) ← 統合先 7 旧 instance

| 旧 instance | 旧担当 | 継承 |
| --- | --- | --- |
| Win版 (現在) | docs / migration schema / 動画 pipeline | ✅ 継続 |
| VSCode版 | UI/design / Flutter UI / EF | ✅ 継承 |
| PS版#1 | Rule17 WF health / instance config oversight | ✅ 継承 (skill `rule17-wf-health` を Win Claude が呼ぶ) |
| PS版#3 | AI 大学コンテンツ追加 (260+ 社) | ✅ 継承 (skill `ai-university-add-provider` を Win Claude が呼ぶ) |
| PS版#4 | 競合モニタリング (172+ 社) | ✅ 継承 (= GHA cron + 手動追加) |
| WEB版 | リモート PR / Issue 管理 | ✅ 継承 (= GitHub MCP) |
| 📱 スマホ版 | 実機 UAT triage | ✅ 継承 (= GitHub MCP + skill `mobile-bug-triage`) |

### Win版 (Codex CLI) ← 統合先 5 旧 instance

| 旧 instance | 旧担当 | 継承 |
| --- | --- | --- |
| Codex#1 | 横断調査 / 修正PR / SQL レビュー | ✅ 継承 |
| Codex#2 | CI / 同期 / 運用 / EF Deno / GHA | ✅ 継承 |
| PS版#2 | T-1 ブログ dispatch (= dev.to / Qiita) | ✅ 継承 (= scripts/t1-dispatch.sh 実行) |
| PS版#5 | EF 整理 / stale 移行 / anon-guard / bulk 修正 | ✅ 継承 |
| PS版#6 | 競馬予想モデル / worktree 整理 | ✅ 継承 |

## 既存 in-flight 作業の扱い

### git worktree (= 87 個)

| カテゴリ | 数 | 扱い |
| --- | --- | --- |
| `.claude/worktrees/instance-<role>` (旧 12 fixed) | 12 | 残存 / dormant / 新作業停止 |
| `.claude/worktrees/codex*-*` (Codex ad-hoc) | ~30 | 順次 main merge or 削除 (= Win Codex が lazy cleanup) |
| `.claude/worktrees/claude/<part-name>` (Claude part-specific) | ~40 | merge 後 prune (`git worktree prune`) |
| `C:/tmp/my_web_app_*` (= 一時) | ~5 | 削除推奨 |

### cross-instance-pr (= `docs/cross-instance-prs/`)

旧 instance 宛 (= ~70 ファイル) は以下:

- **未処理 (root)** — Win Claude が代理処理 or done/ 移動
- **完了 (done/)** — そのまま履歴保持

### 既存 PR / Issue (= GitHub)

- 担当 instance 名が title / body に含まれていても **そのまま** (= 履歴として価値あり)
- 新規 Issue 起票時は「Win版 (Claude Code) / Win版 (Codex CLI)」のみ使用

## 移行手順 (= 本 part 内 + 後続 part で段階完了)

### Phase 1 (= 本 part / DONE):
- ✅ `docs/MULTI_INSTANCE_FLEET.md` 全面 rewrite (229 → ~140 行)
- ✅ 本ドキュメント `docs/FLEET_2_INSTANCE_TRANSITION.md` 新規

### Phase 2 (= 本 part / DONE):
- ✅ `~/.claude/hooks/inject-rules.txt` の `[INSTANCE]` `[WORKDIR-ISOLATION]` `[INSTANCE-ROLES]` 3 rule を 2 instance 化
- ✅ `CLAUDE.md` の 12 instance 関連 section を 2 instance 化

### Phase 3 (= 本 part / DONE):
- ✅ `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` update (= 2 instance に縮小しても 7 原則は維持)
- ✅ `docs/AI_FALLBACK_RUNBOOK.md` update (= フォールバック表 2 行化)

### Phase 4 (= 本 part / DONE):
- ✅ `docs/cross-instance-prs/20260504_fleet_consolidation_to_2_instances.md` 起票 (= 旧 instance 達への retirement 通知)

### Phase 5 (= 後続 part / lazy update):
- ⏳ 残 ~510 doc の grep + 段階的更新
- ⏳ skill description 更新 (= rule17-wf-health / t1-blog-dispatch / mobile-bug-triage / cross-instance-pr / hook-rule-audit / session-start-check)
- ⏳ 87 worktree の lazy cleanup (= Win Codex 担当)

## 完了基準

- [x] 新 fleet manifest が 2 instance + dormant 9 を明示
- [x] inject-rules.txt 行数削減 (= 3 rule の 12 instance 列挙除去)
- [x] CLAUDE.md の `[WORKDIR-ISOLATION]` `[INSTANCE-ROLES]` table が 2 行化
- [x] `docs/AI_FLEET_SYNERGY_PLAYBOOK.md` の「12 instance」全置換
- [x] cross-instance-pr 起票
- [x] memo + ROADMAP commit + push

## Rollback 手順

万一「2 instance では運用に支障」と判明した場合:

1. `git revert <part-130-commit>` で本移行 commit を取消
2. 該当 worktree を `git pull --rebase origin main` で再同期
3. 該当 instance home dir で session 再開
4. cross-instance-pr で fleet 全体に rollback 通知

旧 12 instance の **物理的 worktree / branch は削除していない** ため、rollback コストは小.

## 関連

- [`docs/MULTI_INSTANCE_FLEET.md`](./MULTI_INSTANCE_FLEET.md) — 新 manifest
- [`docs/AI_FLEET_SYNERGY_PLAYBOOK.md`](./AI_FLEET_SYNERGY_PLAYBOOK.md) — 7 原則
- [`docs/AI_FALLBACK_RUNBOOK.md`](./AI_FALLBACK_RUNBOOK.md) — fallback
- Issue [#1974](https://github.com/kanta13jp1/my_web_app/issues/1974) — CLAUDE.md 80 行 KPI (= 関連 context cost 削減)
- part 128 memo — Karpathy AI 外部脳 dogfood map
