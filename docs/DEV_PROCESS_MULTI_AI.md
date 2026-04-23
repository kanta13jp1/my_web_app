# Multi-AI 開発プロセス — Claude Code 集中リスク分散設計

**策定**: 2026-04-24 (Win版#132 part 3)
**前提**: Claude Code 依存度を下げ、Codex / Gemini Code Assist / GitHub Copilot / NotebookLM を並列活用することで、単一 AI vendor ダウン時も開発継続できる体制を構築する。

---

## 1. なぜ Claude Code 単独依存が危険か

### 観測事例

| # | 事象 | 影響 |
|---|------|------|
| 1 | Max プラン 5h limit hit → "resets 4am" | 全 10 インスタンス一斉停止 / 夜間 dev 不能 |
| 2 | Context compaction ループ (Win版#131 part 16→17) | 記憶断片化で同じ修正を繰り返す |
| 3 | summary resume 後の大規模タスク注入 | 再 compaction 発生 (PS#3 S26 教訓) |
| 4 | Anthropic API outage (2026-Q1 数回観測) | cross-instance-pr 作成不能 / deploy 監視停止 |
| 5 | $200/月 単一ベンダー課金集中 | 値上げ or プラン改変 = 即 dev 体制崩壊 |

### リスクの本質

- **SPOF (単一障害点)**: 10 インスタンス全てが Anthropic API に依存
- **Context ceiling**: Claude Code は 1M token までだが、実質 200K で劣化開始
- **判断の均質化**: 全判断が Claude の訓練分布 (丁寧・防御的・仮説多め) に寄る
- **課金の天井**: Max プランでも月 $200 の ceiling が実作業 ceiling

---

## 2. 新プロセス: 4-AI 協調 (Claude / Gemini / Codex / Copilot)

### 基本原則

1. **Claude Code = CEO / アーキテクト**: 判断・統合・memory 管理のみ使用 (全 dev 時間の 10-20%)
2. **Gemini Code Assist = 長文 refactor / codebase review**: 500+ 行の一括変更 (30%)
3. **OpenAI Codex = 単機能実装 / algorithm / SQL**: 明確に仕様確定したコード生成 (20%)
4. **GitHub Copilot = inline completion**: エディタ内の即時補完 (30%)
5. **NotebookLM = リサーチ / ドキュメント分析**: 深い調査・競合21社調査 (10%)

### task routing matrix (強制)

| task 種別 | Primary | Secondary | Claude Code の役割 |
|-----------|---------|-----------|--------------------|
| AI大学 provider 追加 (Migration SQL seed) | **Codex** | Gemini | routing 判断のみ |
| AI大学 provider UI 登録 (registry + _providerMeta) | **Copilot** (pattern match) | Gemini | 整合性レビュー |
| Migration 新規 (DDL + seed) | **Codex** (SQL 特化) | Copilot | migration 命名則確認 |
| Flutter widget 新規 | **Gemini Code Assist** (DESIGN.md 参照) | Copilot | design-skills gate |
| Flutter widget 修正 (数行) | **Copilot inline** | — | 不使用 |
| Flutter 大規模 refactor (500+ 行) | **Gemini** (長 context) | — | 事前レビュー |
| EF (Deno) 新 action 追加 | **Codex** + Copilot | — | integration テスト |
| EF (Deno) hub 統合 refactor | **Gemini** | Copilot | dependency 分析 |
| GHA workflow (yml) 修正 | **Codex** | Copilot | 不使用 (静的) |
| Shell script (bash / python) | **Codex** | Copilot | 不使用 |
| ドキュメント執筆 (docs/) | **Gemini** (長文) or 手書き | Copilot | 構成レビューのみ |
| 競合 21 社調査 | **NotebookLM Deep Research** | — | 統合レポート |
| アーキテクチャ判断 | **Claude Code** (独占) | — | 主役 |
| memory/ consolidation | **Claude Code** | — | 主役 |
| cross-instance-pr 作成 | **Claude Code** | — | 主役 |
| commit message / PR description | **Codex** (短) or Claude (長) | — | Co-Authored-By |
| Deploy 監視 / Rule17 WF health | **Claude Code** (PS#1 専任) | — | 主役 |
| design review (Playwright + DESIGN.md) | **Claude Code** (VSCode design-skills) | — | 主役 |

### 見分け方: 「Claude を使うべきか」判定フロー

```text
[タスク発生]
  ↓
Q1: 複数インスタンス間の調整が必要? → YES → Claude Code
  ↓ NO
Q2: 判断 / 戦略 / trade-off 検討? → YES → Claude Code
  ↓ NO
Q3: 既存 pattern の繰り返し? → YES → Codex or Copilot
  ↓ NO
Q4: 500+ 行の一括変更? → YES → Gemini Code Assist
  ↓ NO
Q5: 深いリサーチ (3+ ファイル or 外部 URL)? → YES → NotebookLM
  ↓ NO
→ Copilot inline で完結
```

---

## 3. 役割別 AI 割当の具体ルール

### 3.1 AI大学 provider 追加 (現状最多タスク)

**旧 (Claude 全依存)**:
1. Claude Code が migration SQL を全て書く (3 category × 50-100 行 = 300 行)
2. Claude Code が registry / _providerMeta / _quizzes / _fallback を 4 箇所編集
3. Claude Code が commit + push
= **1 provider = 約 30K tokens 消費**

**新 (multi-AI)**:
1. **Claude Code**: 「次に追加すべき provider は v0 / Windsurf」判断のみ (500 tokens)
2. **NotebookLM Deep Research**: provider の公式サイト + Crunchbase + TechCrunch 3-5 ソース調査 → サマリ生成 (0 Claude tokens)
3. **Codex**: 既存 seed migration を template にして SQL 生成 (Claude 不使用)
4. **Copilot inline**: registry.dart / _providerMeta / _quizzes / _fallback の 4 箇所を pattern 補完 (Claude 不使用)
5. **Claude Code**: 最終レビュー + commit message (2K tokens)
= **1 provider = 約 3K tokens (10 倍節約)**

### 3.2 Flutter widget 新規 (design gate 必須)

**旧**:
- Claude が DESIGN.md 参照しながら widget 生成
- 全コードを context に載せる

**新**:
- **VSCode 版 Claude Code**: design-skills subagent で DESIGN.md 参照 + 構造設計 (skill 内)
- **Gemini Code Assist**: 実コード生成 (DESIGN.md を context に投入)
- **Copilot**: 細部の tweak
- Claude は最終 review + dart format check のみ

### 3.3 EF (Deno) 新 action 追加

**旧**:
- Claude が hub index.ts に action block を追加

**新**:
- **Codex**: 既存 action block を template に新 case branch 生成
- **Claude Code**: authz / deny-by-default / trace_id 原則チェック
- **deploy**: PS#1 が Rule17 で監視 (Claude 使用)

---

## 4. Fallback plan: Claude Code 全停止時

**契機**:
- Anthropic API outage
- Max プラン limit hit
- 契約変更 / 値上げ

**継続可能な作業**:

| 作業 | 代替 tool | 備考 |
|------|-----------|------|
| AI大学 provider 追加 | Codex + Copilot | 既存 150 社の template で 80% 自動化可 |
| Migration 作成 | Codex | SQL 特化モデルで問題なし |
| Flutter 小修正 | Copilot | エディタ内完結 |
| Flutter 大規模 refactor | Gemini Code Assist | 長 context 得意 |
| GHA workflow 修正 | Codex | yml 静的なので AI 判断不要 |
| 競合モニタリング | NotebookLM | Deep Research 自動化 |
| deploy 監視 | GitHub Actions log 手動確認 | PS#1 スクリプト化済 |

**Claude Code 必須タスク (代替不能)**:
- アーキテクチャ大判断 (hub 統合 / EF-CAP-50 遵守判断)
- cross-instance-pr 作成
- memory/ consolidation
- design review (Playwright + design-skills subagent)

→ **Claude 停止時はこれらを 48h pause**。他 AI で継続できる作業を優先進行。

---

## 5. 実装: 各 AI への引き渡しプロトコル

### 5.1 Codex への引き渡し (migration / EF / script)

```bash
# template を示して指示する例
codex "以下の seed migration template を参考に、provider='cognition' (Devin AI) の
seed SQL を 3 category (overview/models/use_cases) で生成。
template: supabase/migrations/20260424220000_seed_v0_ai_university.sql"
```

### 5.2 Gemini Code Assist への引き渡し (大規模 refactor)

```bash
# VSCode 内で Gemini Code Assist 拡張機能経由
# 全 lib/pages/ 配下の DESIGN token 適用を依頼
# @workspace context 指定で 500+ ファイル解析
```

### 5.3 GitHub Copilot の活用 (inline)

- CLAUDE.md 不要 (プロジェクト pattern を file context から学習)
- エディタで 1-5 行単位の補完に徹する
- 大きな判断が必要な箇所では使わない (頻繁に間違う)

### 5.4 NotebookLM Deep Research の活用

```bash
notebooklm source add-research "Cognition AI Devin autonomous coding agent 2026"
notebooklm research wait
notebooklm ask "Devin の差別化軸と料金体系を 3 point で"
# 出力をそのまま Codex に seed SQL 生成依頼で投入
```

---

## 6. 移行計画 (3 段階)

### Phase 1 (即日): 認知転換
- [x] 本ドキュメント作成
- [ ] CLAUDE.md の AI 振り分け早見表を本ドキュメントへの link に置換
- [ ] 各インスタンスの instance-roles で「Claude 必須」タスクを明示

### Phase 2 (1 週間): tool セットアップ検証
- [ ] Codex CLI / ChatGPT Desktop の動作確認
- [ ] Gemini Code Assist VSCode 拡張の context 投入手順確立
- [ ] Copilot の suggestions 品質測定 (Flutter / Dart / Deno それぞれ)

### Phase 3 (1 ヶ月): KPI 計測
- [ ] Claude Code token 消費量 week 比較 (移行前 vs 移行後)
- [ ] Claude 依存率 (全 commit のうち Claude 主導 vs 他 AI 主導)
- [ ] 目標: Claude token 月 50% 削減 / 他 AI で代替可能率 70%+

---

## 7. 自分株式会社の哲学との整合性

### Philosophy 9 原則チェック

| 原則 | 適合性 |
|------|--------|
| 1. CEO 感 (最終決定権) | ✅ Claude = CEO として判断のみ / 他 AI = 実務担当 |
| 2. ミッション駆動 | ✅ 「開発継続性」がミッション / SPOF 除去は直接貢献 |
| 3. 優しい mentor | ✅ 各 AI の特性を理解した routing = mentor 的判断 |
| 4. 6 部署バランス | ✅ Tech 部 (開発) の負荷分散 = 他部署への時間配分改善 |
| 5. 商品=ユーザー価値 | ✅ Anthropic outage 時もサービス改善継続可 = ユーザー連続的価値 |
| 6. 資本=時間 | ✅ Claude 依存削減で夜間 / limit 後も作業可 = 時間資本増加 |
| 7. 資産負債 BS | ✅ 「Claude 依存 = 負債」と認識 → 分散 = 負債削減 |
| 8. KPI=昨日の自分 | ✅ token 消費量と他 AI 代替率の計測で自己改善 |
| 9. ゴール=IPO / ウェルビーイング | ✅ 単一 vendor 依存 = IPO 時のリスク開示項目 / 分散で健全化 |

**9/9 ✅** — 本プロセス変更は自分株式会社哲学に完全適合。

---

## 8. 参考: 競合 21 社の AI 多様化事例

- **Cursor**: OpenAI + Anthropic + Gemini の multi-LLM routing (ユーザー選択可)
- **Replit Agent 4**: Claude Sonnet (主) + GPT-4o (fallback) + DALL-E (画像) の multi-model
- **v0 by Vercel**: OpenAI + Anthropic mix
- **Windsurf (Cascade)**: 自社 fine-tune + Claude + GPT-4o

**示唆**: 成功する AI 製品ほど single-vendor 依存を避けている。自分株式会社の開発プロセスも同じ原則に従うべき。

---

## 9. 更新履歴

- **2026-04-24 (Win版#132 part 3)**: 初版作成。Claude Code 単一依存リスク顕在化 (context compaction ループ + Max limit reset) を受けて策定。
- **2026-04-24 (PS版#4)**: §10-11 追加。Scheduled Tasks 停止ループ防止 (Circuit Breaker) + 実装 Backlog 策定。
- **2026-04-24 (PS版#2)**: §13 追加。T-1 dispatch の Claude Code 完全無依存化 + multi-AI resilience 設計補完。

---

## 10. Scheduled Tasks 停止ループ防止 — Circuit Breaker 設計 (PS#4追記)

> **発端**: Claude quota 超過 → GHA scheduled タスクが Claude Schedule を呼び出し続ける →
> エラーを繰り返す → Anthropic API に不要な負荷 + GHA 分が無駄消費。

### 10-1. 現状の問題フロー

```
quota 超過
    ↓
GHA cron (毎時/毎朝) → claude code schedule → 429/503 エラー
    ↓                        ↑
    └────── GHA retry 3回 ───┘
    ↓
GitHub Actions runs 消費 + エラーメール + ループ継続
    ↓
次のcronトリガー → 同じエラー繰り返し
```

### 10-2. 解決策: 3層 Circuit Breaker

#### Layer 1: Supabase `ai_quota_status` テーブル (Win版担当)

```sql
-- 担当: Win版 / 期限: 2026-04-25
-- supabase/migrations/YYYYMMDD_create_ai_quota_status.sql
CREATE TABLE IF NOT EXISTS public.ai_quota_status (
  provider     TEXT PRIMARY KEY,
  is_limited   BOOLEAN NOT NULL DEFAULT FALSE,
  limited_since TIMESTAMPTZ,
  reset_estimate TIMESTAMPTZ,
  notes        TEXT,
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.ai_quota_status (provider)
VALUES ('anthropic'), ('openai'), ('google')
ON CONFLICT DO NOTHING;

-- RLS: service_role のみ書き込み可 / anon は読み取り可
ALTER TABLE public.ai_quota_status ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public read" ON public.ai_quota_status FOR SELECT USING (true);
CREATE POLICY "service write" ON public.ai_quota_status FOR ALL
  USING (auth.role() = 'service_role');
```

#### Layer 2: GHA pre-check ステップ (PS#1担当)

**全ての Claude Schedule 呼び出しを含む workflow に追加**:

```yaml
# cs-check.yml / daily-report.yml / competitor-monitoring / pr-auto-review 等
jobs:
  run:
    steps:
      - name: Check Claude quota status
        id: quota
        run: |
          RESP=$(curl -sf \
            "${{ secrets.SUPABASE_URL }}/rest/v1/ai_quota_status?provider=eq.anthropic&select=is_limited" \
            -H "apikey: ${{ secrets.SUPABASE_ANON_KEY }}" || echo '[{"is_limited":false}]')
          IS_LIMITED=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['is_limited'])" 2>/dev/null || echo "false")
          echo "is_limited=$IS_LIMITED" >> $GITHUB_OUTPUT

      - name: Run Claude Schedule (skip if quota limited)
        if: steps.quota.outputs.is_limited != 'true'
        run: claude ...

      - name: Fallback (lite mode)
        if: steps.quota.outputs.is_limited == 'true'
        run: |
          echo "⚠️ Claude quota limited — running lite mode"
          # タスク別の lite 処理 (後述)
```

#### Layer 3: 自動フラグ設定 (`quota-monitor.yml` 改修・PS#1担当)

```yaml
# quota-monitor.yml に追加: Claude API 連続失敗でフラグ自動 ON
- name: Auto-flag quota exceeded
  if: failure()  # claude schedule step が失敗した場合
  run: |
    curl -s -X PATCH \
      "${{ secrets.SUPABASE_URL }}/rest/v1/ai_quota_status?provider=eq.anthropic" \
      -H "apikey: ${{ secrets.SUPABASE_SERVICE_KEY }}" \
      -H "Content-Type: application/json" \
      -d '{"is_limited":true,"limited_since":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","notes":"Auto-flagged by quota-monitor.yml"}'
```

### 10-3. 各ワークフロー別 Lite Mode 設計

| Workflow | 通常モード | Lite モード (quota 停止時) |
|----------|-----------|--------------------------|
| `cs-check.yml` | Claude AI返信 | 未返信チケット数 → Supabase `cs_queue` に記録<br>Slack通知: "CS queue: N件 (Claude quota limited)" |
| `daily-report.yml` | GHA統計 + Claude AI分析 | GHA統計のみ出力<br>AI分析 = "⚠️ Skipped (Claude quota limited)" |
| `competitor-monitoring` | WebSearch + Claude分析 | スキップ<br>PS#4 次セッションで対応 |
| `pr-auto-review` | Claude PR review | スキップ (PR に "⚠️ quota limited" ラベル付与) |
| `github-issue-fix` | Claude Issue自動修正 | スキップ (Issue に "quota-limited" ラベル付与) |
| `infra-health-check.yml` | curl + jq のみ | **影響なし** (Claude 不使用) |
| `ai-university-update.yml` | GHA Python RSS | **影響なし** (Claude 不使用) |
| `deploy-prod.yml` | CI + build | **影響なし** (Claude 不使用) |
| `horse-racing-update.yml` | scraper | **影響なし** (Claude 不使用) |

### 10-4. Gemini API Fallback (一部タスク向け)

quota 停止時も AI を使いたいタスク (cs-check / daily AI分析) 向け:

```bash
# GitHub Secret に追加: GEMINI_API_KEY (Google AI Studio 無料枠)
# Gemini 3.1 Flash-Lite = $0.25/M input / $1.50/M output (Claude の 1/10 以下)

# fallback LLM 呼び出しヘルパー
call_gemini() {
  local prompt="$1"
  curl -sf "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"contents\":[{\"parts\":[{\"text\":\"$prompt\"}]}]}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['candidates'][0]['content']['parts'][0]['text'])"
}
```

### 10-5. 手動 Quota フラグ操作 (緊急時手順)

**quota 超過を検知したら即実行**:

```sql
-- Supabase Dashboard > SQL Editor
UPDATE public.ai_quota_status
SET is_limited    = TRUE,
    limited_since = NOW(),
    reset_estimate = NOW() + INTERVAL '8 hours',
    notes         = 'Manual: quota hit YYYY-MM-DD HH:MM JST'
WHERE provider = 'anthropic';
```

**Claude 復旧後**:

```sql
UPDATE public.ai_quota_status
SET is_limited     = FALSE,
    reset_estimate = NULL,
    notes          = 'Restored YYYY-MM-DD HH:MM JST'
WHERE provider = 'anthropic';
```

---

## 11. 実装 Backlog (担当インスタンス + 期限)

| # | タスク | 担当 | 期限 | 優先度 | 依存 |
|---|--------|------|------|-------|------|
| 1 | `ai_quota_status` テーブル migration 作成 | **Win版** | 2026-04-25 | 🔴 緊急 | — |
| 2 | `cs-check.yml` quota pre-check + lite mode | **PS#1** | 2026-04-26 | 🔴 | #1 |
| 3 | `daily-report.yml` quota pre-check + lite mode | **PS#1** | 2026-04-26 | 🔴 | #1 |
| 4 | `quota-monitor.yml` 自動フラグ設定ロジック | **PS#1** | 2026-04-28 | 🔴 | #1 |
| 5 | `GEMINI_API_KEY` secret 追加 + 動作確認 | **Win版** | 2026-04-28 | 🟡 | #1 |
| 6 | `pr-auto-review` / `github-issue-fix` quota skip | **PS#1** | 2026-04-30 | 🟡 | #1 |
| 7 | `cs_queue` テーブル + 復旧後一括処理 | **Win版** | 2026-05-07 | 🟢 | #1 |
| 8 | Slack Incoming Webhook quota alert | **Win版** | 2026-05-07 | 🟢 | — |
| 9 | KPI 計測 (token 削減率 week 比較) | **PS#4** | 2026-05-15 | 🟢 | — |

**cross-instance-pr 発行**: `docs/cross-instance-prs/20260424_quota_circuit_breaker.md`

---

## 12. 他 AI ツール別現在のセットアップ状態

| AI | 用途 | セットアップ状態 | アクセス方法 |
|----|------|----------------|------------|
| **GitHub Copilot** | inline補完 / Chat | ✅ VS Code統合済 | Editor内 |
| **OpenAI Codex** | SQL / GHA / EF Deno | ✅ Web + CLIあり | `codex` CLI / Web |
| **Gemini Code Assist** | 長文refactor | ✅ VS Code拡張 | Editor内 |
| **NotebookLM** | リサーチ / URL分析 | ✅ CLI認証済 | `notebooklm` CLI |
| **Gemini API (direct)** | schedule fallback LLM | 🔧 **要 secret 追加** | `GEMINI_API_KEY` |
| **Slack** | quota alert通知 | 🔧 **要 Webhook設定** | Incoming Webhook |
| **Notion AI** | 草案作成 (human review後) | ⚠️ 5/4課金開始 | Web |

---

## 13. PS#2 T-1 Dispatch の Claude Code 完全無依存化 (PS#2追記)

### 結論

**T-1 blog dispatch は Claude Code quota に完全無依存** ✅

- `gh workflow run blog-publish.yml` → GHA は Claude CLI を呼ばない
- `blog-publish.yml` 自体は ANTHROPIC_API_KEY を使わない (schedule-hub EF 経由でのみ呼ぶが、dispatch 自体は curl のみ)
- Claude quota 枯渇中でも T-1 dispatch は正常継続可能

### scripts/t1-dispatch.sh (2026-04-24 新設)

Claude Code 不使用で dispatch → URL 抽出 → orphan branch merge → push を完結させるスクリプト。

```bash
# Claude Code 停止中でも実行可能:
bash scripts/t1-dispatch.sh "2026-04-26-ai-vendor-dependency-portfolio-bs-framework"
```

### PS#2 担当タスクの Claude 依存度マップ

| タスク | Claude Code 必要? | 代替手段 |
|-------|-----------------|---------|
| T-1 dispatch | ❌ 不要 | `scripts/t1-dispatch.sh` |
| 4-tag cap チェック | ❌ 不要 | `grep '^tags:'` |
| orphan branch merge | ❌ 不要 | `git merge` + `git push` |
| ROADMAP 追記 | ❌ 不要 | `cat >>` |
| Qiita rate limit チェック | ❌ 不要 | `gh run view --log` |

**→ PS#2 は Claude quota 枯渇時も全タスク継続可能。**

### 関連ファイル

- `docs/multi-ai-resilience.md` — 3層 Resilience 設計全体図
- `docs/cross-instance-prs/20260424_multi_ai_fallback.md` — P0/P1 実装タスク (各インスタンス向け)
