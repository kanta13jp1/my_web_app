# 5インスタンス + マルチAI並行開発 — 競合防止ガイド

作成日: 2026-03-30
最終更新: 2026-04-19 (Windowsアプリ版#104 — 📱スマホ版追加・5インスタンス制へ)
管理: PowerShell インスタンス (全体管理)

---

## インスタンス分担

| インスタンス | 担当領域 (write) | 専任責務 |
| --- | --- | --- |
| **VSCode版** | `lib/` (Dart/Flutter UI) + `supabase/functions/` (EF) + `docs/DESIGN.md` | Rule 16 Web/モバイル表示修正 / Rule 19 UI改善ツールチェーン / `flutter analyze 0エラー` / `deno lint 0エラー` |
| **Windowsアプリ版** | `docs/` (DESIGN.md除く) + `supabase/migrations/` (seed + schema 両方) | Rule 10 (docs全件分析) 主担当 / AI大学プロバイダー追加 / seed データ管理 / 動画編集 |
| **PowerShell版** | `.github/workflows/` + `.mcp.json` + `docs/MULTI_INSTANCE_COORDINATION.md` | Rule 17 CI/CD最適化 / Schedule タスク owner / クォータ監視管理 / MCP設定管理 / 全ブランチ CI 監視 / GitHub PR・Issue管理 |
| **WEB版** | (write 不可・GitHub MCP のみ) | ブログ・競合リサーチ (notebooklm/dart/flutter 不可) |
| **📱 スマホ版 (新)** | (write 不可・GitHub MCP のみ) | **実機 UAT** (iOS Safari/PWA/touch gesture) / モバイル不具合トリアージ / GitHub Issue 自動作成 / 軽量 PR (1ファイル数行) / 重い修正は VSCode版/Win版に handoff |

### 📱 スマホ版 ワークフロー

**強み**: Playwright で再現困難な iOS Safari の細かい挙動・PWA install 動作・touch gesture の実機検証

**専用 skill**: `.claude/skills/mobile-bug-triage/SKILL.md` (Issue テンプレ + WCAG/Touch target チェックリスト 8 項目)

**3 段階フロー**:

1. **Phase A: 不具合発見 → Issue 化 (5分)**
   - ユーザーがスマホ実機で screenshot 撮影
   - スマホ版が画像分析 → `mcp__plugin_github_github__create_issue` で構造化 Issue 作成
   - ラベル: `mobile-bug` `priority:<level>` 自動付与

2. **Phase B: 修正分岐**
   - **軽量 (1ファイル数行)**: スマホ版が GitHub MCP で直接 PR 作成
   - **重い (lint cascade / 多ファイル)**: `docs/cross-instance-prs/YYYYMMDD_mobile_<title>.md` で VSCode版に handoff

3. **Phase C: デプロイ後再検証**
   - スマホ版が WebFetch + ユーザー実機確認
   - OK なら Issue close (`mcp__plugin_github_github__update_issue`)

### モバイル特化バグ早見表

| 症状 | 原因 | 修正担当 |
| --- | --- | --- |
| 横スクロール発生 | viewport overflow | VSCode版 |
| FAB 押せない | bottom safe-area 不足 | スマホ版 (簡単) |
| キーボード起動で input 隠れる | resizeToAvoidBottomInset | VSCode版 |
| iOS で 100vh 画面外 | CSS env(safe-area-inset-bottom) | VSCode版 (web/index.html) |
| Touch target 小さい | `IconButton` minSize | スマホ版 (簡単) |
| Dark mode contrast 不足 | DESIGN.md token 違反 | VSCode版 (Rule 12) |
| PWA install ボタン出ない | manifest.json 不備 | Win版 (web/) |

### フォールバック AI ツール (Claude 制限時のみ)

> 通常は Claude Code 3インスタンスのみ使用。Claude 429 / 月次 $50 超過時のみフォールバック発動。

| ツール | 発動条件 | ファイル種別 |
| --- | --- | --- |
| Gemini Code Assist | Claude 429 / $50超過 | `.dart` |
| CODEX CLI (OpenAI) | Claude 429 / $50超過 | `.py` / `.ts` |
| GitHub Copilot | Claude 429 / $50超過 + 常時PRレビュー | `.yml` / `.sql` / `.md` |
| NotebookLM | **常時使用必須 (Rule 21)** | 全種別 (3ファイル以上/URL分析/競合調査) |

### 緊急横断権限（Blocking 解消）

担当インスタンスを待てない場合、非 owner インスタンスは以下の手順で変更提案をコミットできる:

1. `docs/cross-instance-prs/YYYYMMDD_<内容>.md` を作成し変更内容を記述
2. 担当インスタンスが次セッション冒頭で採否を判断してマージ or クローズ
3. 緊急性が高い場合はコードを直接修正しコミットメッセージに `[cross-instance: <担当>版 に要確認]` を付記

### 変更禁止領域（厳守）

| インスタンス | 変更禁止 |
| --- | --- |
| VSCode版 | `docs/` (DESIGN.md は own), `.github/` |
| Windowsアプリ版 | `lib/`, `supabase/functions/`, `.github/` |
| PowerShell版 | `lib/`, `supabase/functions/`, `docs/` (MULTI_INSTANCE_COORDINATION.md は own) |


### 全インスタンス共有領域（例外）

以下のファイル・ディレクトリはインスタンスに関わらず全員が read/write 可:

| パス | 理由 | 書き込みルール |
| --- | --- | --- |
| `memory/` (全ファイル) | `/wrap-up` で全インスタンスが学習を永続保存する共有メモリ領域 | ファイル名に session 識別子を付けて衝突回避 (例: `feedback_success_YYYYMMDD_ps.md`) |
| `docs/GROWTH_STRATEGY_ROADMAP.md` | 全インスタンスがセッション記録を末尾追記する成長記録 | **追記のみ** (既存セクション編集は Windowsアプリ版 に限定) / 末尾に `## <インスタンス名> YYYYMMDD` ヘッダーで追記 |
| `docs/cross-instance-prs/` | 横断変更提案の投函ボックス (上記「緊急横断権限」で使用) | 任意のインスタンスが `YYYYMMDD_<内容>.md` を作成可 |
| `.github/COMPRESSED_PROMPT_V3.md` | 全インスタンス共通のプロンプト辞書 | 数値更新・タスクステータス変更は全インスタンス可 / 構造変更は PowerShell版 が担当 |

---

## 競合防止ルール

### 必須手順 (作業開始時)

```bash
git stash
git pull --rebase origin main
git stash pop
```

### コミット単位の原則

- 各インスタンスは担当領域のファイルのみ `git add` する
- `git add -A` や `git add .` は使わず、ファイル指定でステージング
- プッシュ前に `git status` で余分なファイルが含まれていないか確認

### マイグレーションファイルの番号帯 (重複防止)

同日に複数インスタンスが seed ファイルを作成すると version 番号が衝突する。
**各インスタンスは以下の番号帯を使用すること**:

| インスタンス | 番号帯 | 例 |
| --- | --- | --- |
| **Schedule (自動)** | `000010` ~ `000499` | `20260401000040_seed_session432j.sql` |
| **VSCode** | `000500` ~ `000699` | `20260401000500_seed_vscode.sql` |
| **Windowsアプリ** | `000700` ~ `000899` | `20260401000700_seed_windows.sql` |
| **PowerShell (全体管理)** | `000900` ~ `000999` | `20260401000900_seed_ps8_ps9.sql` |

> **注意**: `supabase/migrations/` の version は `schema_migrations` テーブルの PK。
> 重複があると `supabase db push` が `duplicate key value` エラーで失敗する。
> 衝突を発見したら PowerShell インスタンスが高い番号帯へリナンバーして即コミット。

### 競合が発生した場合

```bash
git rebase --continue   # コンフリクト解決後
git rebase --abort      # リベースをやめて元に戻す場合
```

---

## スケジュールタスク一覧 (Claude Code Schedule)

> **Owner: PowerShell版** — Schedule タスクの定義・追加・変更は PowerShell版 が担当。
> 実行時の成果物 (`docs/daily-reports/`, `docs/cs-notes/`, etc.) は各インスタンスの owned scope に書き込む。

| タスク | スケジュール | 担当機能 |
| --- | --- | --- |
| `daily-report` | 毎日 09:00 JST | Actions生成レポート確認 → AI分析追記 → X投稿(失敗時のみ) |
| `cs-check` | 毎時 :07 | CS対応 / PR自動レビュー / ヘルスチェック |
| `github-issue-fix` | 毎日 10:00 JST | Open Issue → EF UI導線追加 / analyze エラー修正 → クローズ |
| `weekly-sns-draft` | 毎週月曜 09:00 JST | SNSドラフト + Zenn記事ネタ + 依存脆弱性チェック |
| `pr-auto-review` | 3時間毎 | セキュリティ/パフォ/バグ観点のPRレビュー |
| `competitor-monitoring` | 毎日 07:00 JST | 競合21社の可用性 + 最新ニュース調査 |
| `infra-health-check` | 毎時 :30 | `health-check` EF + Firebase Hosting 確認 |
| `dependency-audit` | 毎週月曜 08:00 JST | `pub outdated` + Deno import バージョン検査 |
| `blog-draft` | 毎日 08:00 JST | 直近7日コミット → ブログ下書き → `blog_posts` テーブル登録 |

> GitHub Actions と **並行・補完**する関係。Actions がデータ収集・投稿を担当し、Claude Schedule が AI分析・コード修正を担当。

---

## データベーステーブル管理

### 主要テーブル一覧

| テーブル | 用途 | 担当インスタンス |
| --- | --- | --- |
| `user_profiles` | ユーザープロフィール (is_admin含む) | PowerShell (スキーマ管理) |
| `schedule_task_runs` | Schedule実行ログ | PowerShell (スキーマ管理) |
| `blog_posts` | ブログ投稿管理 | PowerShell (スキーマ管理) |
| `development_achievements` | 開発実績 | Windowsアプリ/PowerShell |
| `agents` / `agent_tasks` | 仮想AI組織 | PowerShell (スキーマ管理) |
| `teams` / `team_memberships` | チームワークスペース | PowerShell (スキーマ管理) |
| `growth_plans` | 競合比較進捗データ | Windowsアプリ (データ更新) |

### RLS ポリシー設計原則

- `service_role`: 全テーブルで全操作可能 (Schedule タスクが使用)
- `authenticated` + `is_admin = true`: 管理者向けテーブル読み書き
- `auth.uid() = user_id`: 一般ユーザーの自己データアクセス

---

## よくあるエラーと対処法

### push が rejected された場合

```bash
git pull --rebase origin main
# コンフリクトを解決してから
git push origin main
```

### flutter analyze エラーが出た場合

```bash
flutter analyze lib/ 2>&1 | grep "error:" | head -20
```

エラーがある場合はそのファイルを修正してから commit する。

### Edge Function の呼び出しが失敗する場合

- Claude Code Web環境ではプロキシによりブロックされることがある
- その場合は git log ベースのフォールバックを使用する

---

## 実装済み機能チェックリスト

### Schedule タスクが自動実行する機能

- [x] 毎時: CS対応 (FAQ返信・バグ修正・エスカレーション)
- [x] 毎時: Edge Function UI カバレッジチェック・自動ページ生成
- [x] 毎時: GitHub PR 自動レビュー
- [x] 毎時: コードレビュー → GitHub Issue 自動発行
- [x] 毎時: インフラヘルスチェック
- [x] 毎日: 日次レポート生成 (schedule_task_runs 記録含む)
- [x] 毎日: X (@kanta13jp1) 自動投稿
- [x] 毎日: 競合モニタリング
- [x] 毎日: ブログ下書き自動生成 (Zenn/Qiita/note 等)
- [x] 毎週: SNS投稿ドラフト + 脆弱性チェック

### 管理者ダッシュボード機能

- [x] Schedule タスク実行状況 (ScheduleTaskMonitorCard)
- [x] 登録ユーザー管理 (get-admin-users Edge Function)
- [x] Edge Function 一覧 + UI導線状況 (EdgeFunctionStatusPage)
- [x] 競合モニタリング (CompetitorMonitoringCard)
- [x] 成長指標ダッシュボード (GrowthCommandCenter)
