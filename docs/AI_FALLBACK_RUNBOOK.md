# AI Fallback Runbook — 自分株式会社

> 作成: 2026-04-24 (PS#6 S26)  
> 目的: Claude Code quota 制限時に開発・自動化が完全停止しないための手順書

---

## クイックリファレンス: 今何が使えないか確認

```bash
# Claude Code 残量確認 (claude.ai/settings → Usage)
# GHA quota-monitor.yml の最新ラン確認
gh run list --workflow=quota-monitor.yml --limit 1
```

---

## シナリオ 1: Claude Code CLI quota 超過

**症状**: `claude` コマンドが "rate limit" / "quota exceeded" を返す

### 開発作業のフォールバック順位

| 作業種別 | Primary | Fallback 1 | Fallback 2 |
|---------|---------|-----------|-----------|
| コード補完・小修正 (5分以内) | GitHub Copilot (VS Code) | Copilot Chat | 手動 |
| Dart/Flutter ファイル編集 | GitHub Copilot | Gemini Code Assist (VS Code拡張) | Codex CLI |
| 大規模リファクタリング (500行+) | Gemini Code Assist | Codex | 手動分割 |
| SQL / アルゴリズム最適化 | Codex CLI | Gemini | 手動 |
| 設計・戦略・ルール判断 | claude.ai (WEBブラウザ版) | NotebookLM | ドキュメント参照 |
| EF cleanup / hub migration | claude.ai (WEB版) | Codex | 手動 |
| Dart format チェック | `dart format .` (CLI直接) | CI確認 | — |

### Codex CLI セットアップ (未設定の場合)

```bash
# インストール (OpenAI API Key 必要)
npm install -g @openai/codex
export OPENAI_API_KEY="sk-..."

# 使用例
codex "lib/pages/home_page.dart の fetchData() にエラーハンドリングを追加して"
codex "supabase/functions/tools-hub/index.ts に action=habit.list を追加"
```

### Gemini Code Assist セットアップ (VS Code)

```text
1. VS Code → Extensions → "Gemini Code Assist" インストール
2. Google アカウントでサインイン
3. Copilot 同様にインライン補完・チャットが使える
4. 無料プラン: 個人開発には十分な quota
```

### インスタンス別フォールバック割当

| インスタンス | Claude quota 超過時の代替 |
|------------|------------------------|
| VSCode版 | Copilot + Gemini Code Assist (ローカル環境) |
| Win版 | Copilot + Codex CLI + NotebookLM |
| PS版 | Codex CLI (スクリプト実行) |
| WEB版 | claude.ai web ブラウザ (同一プラン内の別セッション枠) |
| スマホ版 | GitHub Copilot Mobile + Copilot in GitHub Web |

---

## シナリオ 2: GitHub Actions での Anthropic API quota 超過

**影響ワークフロー**: `claude-agent-review.yml` のみ

**対応済み** (2026-04-24 PS#6 S26): Gemini 1.5 Flash への自動フォールバック実装済み。

| 状態 | 挙動 |
|-----|------|
| Anthropic OK | Claude sonnet-4-6 でレビュー |
| Anthropic quota 超過 → Gemini OK | Gemini 1.5 Flash でレビュー |
| 両方 quota 超過 | スキップ (PR ブロックなし) |

**GEMINI_API_KEY 設定手順** (未設定の場合):

```text
1. aistudio.google.com → API Keys → Create API Key
2. GitHub → Settings → Secrets → GEMINI_API_KEY に追加
3. 無料枠: 1分15リクエスト / 1日1500リクエスト (個人開発には十分)
```

---

## シナリオ 3: Schedule タスクの quota 対応

### 現状の GHA ワークフロー — Claude 依存度

| ワークフロー | Claude 依存 | quota 超過時の挙動 |
|------------|------------|-----------------|
| `cs-check.yml` | **なし** | 影響なし ✅ |
| `daily-report.yml` | **なし** | 影響なし ✅ |
| `ai-university-update.yml` | **なし** (RSS only) | 影響なし ✅ |
| `quota-monitor.yml` | **なし** (監視のみ) | 影響なし ✅ |
| `claude-agent-review.yml` | あり → Gemini fallback | Gemini でカバー ✅ |
| `blog-engagement.yml` | optional | スキップ (コメント返信なし) ⚠️ |
| `horse-racing-update.yml` | **なし** | 影響なし ✅ |
| `wbs-staleness-audit.yml` | **なし** | 影響なし ✅ |

**結論**: スケジュールタスクの大半はすでに Claude 非依存。`blog-engagement.yml` のコメント返信 AI 生成のみ停止するが、非クリティカル。

### Claude Code CLI ベースのタスク (手動代替手順)

以下のタスクは元々 Claude Code CLI を前提としているが、フォールバック可能:

**daily-report AI 分析セクション**:
```bash
# Claude unavailable → 手動でコメントを追記するだけでOK
# または quota-monitor.yml の出力を参照して手動 commit
git add docs/daily-reports/$(date +%Y-%m-%d).md
git commit -m "自動: 日次レポート $(date +%Y-%m-%d) [manual]"
```

**EF cleanup / hub migration** (PS#6 担当):
```bash
# Codex で代替
codex "supabase/functions/ の DEAD_LIST 削除対象ディレクトリを特定して削除スクリプトを生成"
# または claude.ai WEBブラウザ版を使う (同じAPIキーだが別枠)
```

---

## シナリオ 4: 複数 AI ツールの同時quota超過 (最悪ケース)

**対応手順**:

1. **GitHub Copilot は独立課金** → Claude/Gemini 停止中も使える
2. **NotebookLM** → Google アカウントで無料、Claude と独立
3. **Notion AI** → Notion プランに含まれる、Claude と独立
4. **手動開発** → 以下を参照

```bash
# 最小限の手動開発ループ
dart format lib/             # フォーマット
flutter analyze              # 静的解析
git add -p                   # 差分確認
git commit -m "..."
git push origin ps-main:main
```

---

## Slack / Notion へのアラート設定 (推奨)

### quota-monitor.yml でのアラート強化

現在の `quota-monitor.yml` は Supabase に記録するのみ。Slack webhook でプッシュ通知を追加推奨:

```yaml
# quota-monitor.yml に追加するステップ
- name: Slack Alert on High Usage
  if: steps.anthropic.outputs.usage_pct > 80
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK_URL }}" \
      -H 'Content-type: application/json' \
      -d '{"text": "⚠️ Claude quota 80% 超過 — Gemini/Codex に切り替えてください"}'
```

### Notion での quota トラッキング (オプション)

```text
Notion Database: "AI Quota Log"
- Date: 日付
- Claude Usage %: quota 使用率
- Status: Normal / Warning / Critical
- Fallback: Active AI ツール
毎日 quota-monitor.yml の結果を手動または自動でここに記録
```

---

## 開発プロセス — 平常時 vs quota 超過時

### 平常時 (Claude Code 利用可能)

```text
Claude Code CLI (設計・編集) 
  + GitHub Copilot (補完)
  + NotebookLM (リサーチ)
  + GHA (自動化 — Claude 非依存)
```

### Claude quota 超過時

```text
Gemini Code Assist / Codex CLI (編集メイン)
  + claude.ai WEB版 (設計判断・限定的)
  + GitHub Copilot (補完)
  + NotebookLM (リサーチ)
  + GHA (変わらず全自動) ← 影響なし
```

### 全 AI quota 超過時 (最悪ケース)

```text
GitHub Copilot (補完のみ)
  + 手動 dart format / flutter analyze
  + NotebookLM (Google 無料枠)
  + GHA (変わらず全自動) ← 影響なし
```

---

## GEMINI_API_KEY 取得手順

1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. 「Get API key」→「Create API key in new project」
3. キーをコピー
4. GitHub repo → Settings → Secrets and variables → Actions → New secret
   - Name: `GEMINI_API_KEY`
   - Value: `AIza...`
5. `claude-agent-review.yml` が自動的に使用開始

---

## チェックリスト — Quota 超過発生時

- [ ] `quota-monitor.yml` の最新ランで使用率確認
- [ ] `GEMINI_API_KEY` が GitHub Secrets に設定済みか確認
- [ ] VS Code に Gemini Code Assist 拡張インストール済みか確認
- [ ] Codex CLI が使える状態か確認 (`codex --version`)
- [ ] GHA 自動ワークフローは継続稼働中か確認 (影響なし)
- [ ] claude.ai WEB版の残量を確認 (CLI と別枠の可能性あり)
