---
date: 2026-04-24
from: VSCode版 (Multi-AI resilience 設計 / S2)
to: PS版#1 (GHA ワークフロー修正)
status: pending
priority: HIGH
deadline: 2026-05-07
related: 20260424_multi_ai_fallback_win.md (EF 側 circuit breaker)
---

# GHA スケジュールタスク Claude クォータ枯渇時フォールバック追加

## 背景

Claude Code クォータ制限到達時、GHA スケジュールタスクが全て `claude` CLI
エラーでループし続け、GitHub Actions の無料枠を消費し続ける問題が判明。

**対象ワークフロー** (claude CLI を直接呼ぶもの):
- `.github/workflows/cs-check.yml`
- `.github/workflows/competitor-monitoring.yml`
- `.github/workflows/ai-university-update.yml`
- `.github/workflows/blog-draft.yml`
- `.github/workflows/pr-auto-review.yml`

## 実装内容

### 1. `continue-on-error: true` + 検知ステップ追加

各ワークフローの Claude 呼び出しステップに以下パターンを適用:

```yaml
# Before (現状)
- name: Claude CS Check
  run: |
    claude --model claude-haiku-4-5 "..."

# After (修正後)
- name: Claude CS Check
  id: claude_step
  continue-on-error: true
  run: |
    claude --model claude-haiku-4-5 "..."

- name: Detect quota exhaustion
  if: steps.claude_step.outcome == 'failure'
  run: |
    echo "::warning::Claude quota exhausted or API error — skipping this run"
    echo "QUOTA_EXHAUSTED=true" >> $GITHUB_ENV

- name: Log quota status to Supabase
  if: env.QUOTA_EXHAUSTED == 'true'
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  run: |
    curl -s -X POST "${SUPABASE_URL}/rest/v1/ai_quota_status" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -H "Prefer: resolution=merge-duplicates" \
      -d "{\"provider\":\"claude\",\"status\":\"exhausted\",\"exhausted_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"updated_at\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "Logged quota exhaustion to Supabase ai_quota_status"
```

### 2. cs-check.yml 具体的修正

```yaml
# .github/workflows/cs-check.yml

jobs:
  cs-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get support tickets
        id: get_tickets
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
        run: |
          # ... 既存の ticket 取得ロジック ...

      - name: Claude CS analysis
        id: claude_cs
        continue-on-error: true       # ← 追加
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # ... 既存の claude 呼び出し ...

      - name: Fallback — skip CS check (quota exhausted)
        if: steps.claude_cs.outcome == 'failure'
        run: |
          echo "::warning::Claude quota exhausted. CS check skipped for this run."
          echo "Manual review may be needed for pending tickets."
          # GitHub Issue で通知 (service key 必要な場合は別途対応)
          echo "SKIP_REASON=quota_exhausted" >> $GITHUB_ENV

      - name: Reply to tickets
        if: steps.claude_cs.outcome == 'success'   # ← 条件追加
        run: |
          # ... 既存の reply ロジック ...
```

### 3. competitor-monitoring.yml 具体的修正

```yaml
      - name: Claude competitor analysis
        id: claude_competitor
        continue-on-error: true        # ← 追加
        run: |
          # ... 既存の claude 呼び出し ...

      - name: Fallback competitor monitoring (Gemini)
        if: steps.claude_competitor.outcome == 'failure'
        env:
          GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
        run: |
          # Gemini Flash 2.0 でシンプルな競合チェック
          python3 << 'EOF'
          import os, json, urllib.request

          api_key = os.environ["GEMINI_API_KEY"]
          prompt = "競合21社の主要変化を1行ずつ箇条書きで。簡潔に。"

          req = urllib.request.Request(
            f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}",
            data=json.dumps({"contents": [{"parts": [{"text": prompt}]}]}).encode(),
            headers={"Content-Type": "application/json"}
          )
          with urllib.request.urlopen(req) as res:
            result = json.loads(res.read())
            print(result["candidates"][0]["content"]["parts"][0]["text"])
          EOF
          echo "COMPETITOR_FALLBACK=gemini" >> $GITHUB_ENV
```

### 4. ai-university-update.yml 具体的修正

```yaml
      - name: Claude AI University update
        id: claude_aiu
        continue-on-error: true        # ← 追加
        run: |
          # ... 既存 ...

      - name: Fallback — defer to next run
        if: steps.claude_aiu.outcome == 'failure'
        run: |
          echo "::warning::AI University update skipped — Claude quota exhausted"
          echo "Will retry at next scheduled run (2h later)"
```

## 前提条件 (Win版 が先行実装すること)

- `ai_quota_status` テーブルが Supabase に存在すること
  (`20260424_create_ai_quota_status.sql` migration — Win版 handoff 参照)
- GitHub Secrets に `GEMINI_API_KEY` 追加 (手動 — ユーザー実施)
  取得先: https://aistudio.google.com/apikey (無料枠: 15 req/min)

## 優先順位

1. **cs-check.yml** — 顧客対応タスク。失敗ループが最も危険。🔴 最優先
2. **competitor-monitoring.yml** — Gemini fallback で継続価値あり。🟡 高
3. **ai-university-update.yml** — 次回 run で自動リカバリ可能。defer で十分。🟢 中
4. **blog-draft.yml / pr-auto-review.yml** — 同様に defer で十分。🟢 中

## 実装ステップ

- [ ] `cs-check.yml` に `continue-on-error` + fallback step 追加
- [ ] `competitor-monitoring.yml` に Gemini fallback 追加
- [ ] `ai-university-update.yml` に defer fallback 追加
- [ ] `blog-draft.yml` に defer fallback 追加
- [ ] `pr-auto-review.yml` に defer fallback 追加
- [ ] 動作確認: `claude` CLI を意図的に失敗させてフォールバックが発火することを確認

## Philosophy Alignment

- 原則1 (CEO感): クォータ枯渇でも開発が止まらない = CEO がオフィスを失っても会社が動く設計
- 原則5 (商品=ユーザー価値): CS 対応が自動停止しない = ユーザーへの価値提供継続
