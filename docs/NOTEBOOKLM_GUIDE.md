# NotebookLM 実践ガイド — 3 層メモリ + DBS + Master Brain

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L236-388 を移行 (= Karpathy 80 行 KPI 達成).
> Karpathy 4 サイクル (Ingest / Compile / Query / Lint) との対応は [`docs/SECOND_BRAIN_PRINCIPLES.md`](SECOND_BRAIN_PRINCIPLES.md) 参照.

---

## 3 層メモリシステム

| 層 | ツール | 用途 |
| --- | --- | --- |
| **L1: セッション内** | claude-mem (SQLite + Gemini 圧縮) | 全ツール使用を自動記録 / ベクター検索 |
| **L2: セッション間** | 自作 auto-capture hooks (= md ファイル) + repo `memory/` | git commit 履歴 / instance 間共有 |
| **L3: プロジェクト横断** | NotebookLM Master Brain (= `jibun-master-brain` notebook) | 深い調査 / 長期アーキテクチャ知識 |

**claude-mem Worker 起動**: セッション開始前に `npx claude-mem start` (Bun 必須). Worker 未起動でも hook はスキップで動作継続.

---

## アカウント運用 — 2 アカウント分離 (= part 266b 2026-06-11 確立)

NotebookLM は Google アカウント単位で notebook が分かれる。CLI は `NOTEBOOKLM_HOME` 環境変数で
認証・context・browser_profile を**丸ごとディレクトリ分離**できる (CLI `paths.py` 正本 / `--storage` 単独は context.json が共有されるため不可):

| 用途 | アカウント | NOTEBOOKLM_HOME | 主な notebook |
| --- | --- | --- | --- |
| **本プロジェクト (my_web_app)** | kanta13jp@gmail.com | `C:\Users\kanta\.notebooklm-gmail` (= `.claude/settings.json` env で自動適用) | `jibun-master-brain` (= ID `ea6cff25...` / Shared) |
| 他プロジェクト | k-umezawa@ml-mightylink.com | default `~/.notebooklm` (= env 未設定時) | Mighty Skill-Bridge / Mighty-Link 系 |

- **初回 setup**: `NOTEBOOKLM_HOME=C:\Users\kanta\.notebooklm-gmail notebooklm login` (browser OAuth = user 操作)。
- **罠 1**: CLI は login 中アカウントを表示しない (`status` / `auth check` とも cookie domain のみ) → 「notebook 不存在」はまず**アカウント違い**を疑い、`notebooklm list` の notebook 群で指紋確認。
- **罠 2**: `use <name>` が fail しても後続 `source add` は現行 context の notebook へ着地する → `use` 成功を verify してから add (part 266 で誤着地→`source delete -y` 削除の実例)。
- **罠 3**: `use` の解決は **notebook ID prefix のみ** (title マッチ不可 / CLI v0.3.4 `helpers.py` 実測) → `notebooklm use ea6cff25` のように ID 先頭で指定する。
- **未監査**: GHA 側 (notebooklm-video-pipeline 等) は `NOTEBOOKLM_AUTH_JSON` secret 経由 — どちらのアカウントで生成された secret かの監査は別タスク。

---

## セッション開始 ritual (= Master Brain 参照)

セッション冒頭で必ず以下を確認:

```text
~/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory/MEMORY.md
```

前回の成功パターン / 禁止事項 / 新規発見を読む.

**アーキテクチャ・意思決定・好みの質問には必ず Master Brain に問い合わせる**:

```bash
notebooklm use ea6cff25   # = jibun-master-brain (use は ID prefix のみマッチ / title 不可 v0.3.4 実測)
notebooklm ask "過去の意思決定: [質問内容]"
```

例: 「なぜ Supabase を選んだか」「Edge Function の設計方針は」「過去に試して失敗したアプローチは何か」.

---

## ゼロトークンリサーチ — `/deep-research` 委譲必須

以下のいずれかに該当する場合は **必ず** `notebooklm` CLI を使う:

| 条件 | Claude 直接消費 | NotebookLM 委譲後 |
| --- | --- | --- |
| 3 ファイル以上を同時に読む | ~150K tokens | ~5K tokens |
| URL を分析する | ~60K tokens | ~2K tokens |
| 競合 21 社のリサーチ | ~80K tokens | ~3K tokens |
| ドキュメント全体を俯瞰する | ~100K tokens | ~4K tokens |

### native CLI コマンド (推奨)

```bash
# ノートブック作成 → ソース追加 → 質問 → 成果物生成
notebooklm create "My Research Project"
notebooklm source add "./transcript.md"
notebooklm source add "https://example.com/doc"
notebooklm source add --type youtube "https://youtube.com/watch?v=..."
notebooklm ask "3 つの主要テーマは?"

# 成果物を自動生成 (= Google インフラで無料処理)
notebooklm generate slide-deck "要点をスライドにまとめて"
notebooklm generate flashcards "重要用語を中心に"
notebooklm generate mind-map
notebooklm generate data-table "主要概念を比較"
notebooklm generate audio "deep dive focusing on key findings" --wait
notebooklm generate quiz "難易度中程度"
notebooklm generate infographic
notebooklm download slide-deck

# Web Deep Research (= 自律 Web 調査 + レポート)
notebooklm source add-research "advanced Flutter Web performance optimization 2026"
notebooklm research wait
notebooklm ask "調査結果のサマリーを教えて"
```

### ラッパースクリプト (互換)

```bash
PYTHONUTF8=1 python notebooklm_research.py --setup
PYTHONUTF8=1 python notebooklm_research.py "競合 21 社の最新動向"
PYTHONUTF8=1 python notebooklm_research.py --files lib/pages/landing_page.dart docs/DESIGN.md --query "UI と設計の整合性"
PYTHONUTF8=1 python notebooklm_research.py --url "https://..." --query "要約して"
```

認証未完了:

```bash
pip install "notebooklm-py[browser]"
playwright install chromium
notebooklm login
```

---

## DBS フレームワーク (= エキスパート skill 構築)

NotebookLM Deep Research で収集した知識をカスタム skill に変換する手順:

1. **Deep Research 実行**: `notebooklm source add-research "対象ドメインの専門的なクエリ"` で数百ページ自律調査
2. **DBS で分類**:
   - **D (Direction)** = 意思決定ツリー / 手順 / エラー回復 → `SKILL.md` の core
   - **B (Blueprints)** = テンプレート / ガイドライン / 分類 rule → サポートファイル
   - **S (Solutions)** = API 呼出 / データ処理 / 計算 確定的 code → script
3. **`/skill-creator`** で skill 化

---

## skill 管理

```bash
notebooklm skill install   # ~/.claude/skills/ にインストール
notebooklm skill status
notebooklm skill show
notebooklm skill uninstall
```

- プロジェクト skill: `.claude/skills/<name>/SKILL.md` (= repo 共有)
- 個人 skill: `~/.claude/skills/<name>/SKILL.md` (= 全プロジェクト)

---

## セッション終了 ritual (= `/wrap-up`)

作業完了後、**必ず** `/wrap-up` skill を実行:

1. ローカル `memory/` 保存:
   - 成功パターン → `memory/feedback_success_YYYYMMDD.md`
   - 失敗 / 禁止事項 → `memory/feedback_correction_YYYYMMDD.md`
   - 新規発見 → `memory/project_YYYYMMDD_<part>.md`
2. **NotebookLM Master Brain に source 追加** (= 認証済時のみ):

   ```bash
   notebooklm use jibun-master-brain
   notebooklm source add "./memory/feedback_success_YYYYMMDD.md"
   notebooklm source add "./memory/project_YYYYMMDD.md"
   ```

3. 未完了タスク → `MEMORY.md` 末尾コメント
4. **次回タスク候補 3-5 件** を優先度付き表で提示 (= 必須 / `.claude/commands/wrap-up.md` Step 6 参照)

これを怠るとセッション間記憶が消え、同じ失敗を繰り返す.

---

## NotebookLM セットアップ

- インストール: `pip install "notebooklm-py[browser]"` + `playwright install chromium`
- 認証: `notebooklm login` (= ブラウザ Google ログイン / 1 度のみ)
- skill: `notebooklm skill install`
- 確認: `notebooklm status` or `PYTHONUTF8=1 python notebooklm_research.py --setup`
- **Windows 必須**: `PYTHONUTF8=1` (= CP932 エンコードエラー回避)
- cookie 期限切れ: `notebooklm login` 再認証 (30 秒)
- **cookie ファイル保護**: `~/.notebooklm/storage_state.json` は **絶対に git commit しない** (= Google セッション情報)

---

## 関連

- [`docs/SECOND_BRAIN_PRINCIPLES.md`](SECOND_BRAIN_PRINCIPLES.md) — Karpathy 4 サイクル + Memex 哲学
- [`docs/CODEX_MEMORY_AUTOMATIONS.md`](CODEX_MEMORY_AUTOMATIONS.md) — 25 自動化 task ownership
- [`.claude/commands/wrap-up.md`](../.claude/commands/wrap-up.md) — wrap-up skill 詳細
- `scripts/wiki_compile.py` — Karpathy Compile cycle (part 132)
- `scripts/memory_ingest.py` — Karpathy Ingest cycle (part 111)
- `scripts/knowledge_vault_lint.py` — Karpathy Lint cycle (part 105)
