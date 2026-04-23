# Cross-Instance PR: Multi-AI Fallback 実装

**作成**: PS版#2 2026-04-24
**参照**: docs/multi-ai-resilience.md
**背景**: Claude quota 枯渇で開発プロセス完全停止 → SPOF 解消

---

## P0 タスク (即日実施)

### → PS版#1 担当

**quota-monitor.yml 拡張 (30min)**

```yaml
# .github/workflows/quota-monitor.yml に追加:
- name: Write quota flag to Supabase KV
  run: |
    USAGE=$(cat $GITHUB_OUTPUT | grep anthropic_pct | cut -d= -f2)
    if [ "$USAGE" -ge 90 ]; then FLAG="critical"
    elif [ "$USAGE" -ge 70 ]; then FLAG="warning"
    else FLAG="ok"; fi
    
    curl -sf -X POST "${SUPABASE_URL}/rest/v1/app_settings" \
      -H "apikey: ${SUPABASE_SERVICE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
      -H "Content-Type: application/json" \
      -d "{\"key\": \"claude_quota_status\", \"value\": \"$FLAG\", \"updated_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      --max-time 10 || true
    
    echo "claude_quota_flag=$FLAG" >> $GITHUB_OUTPUT

- name: Create GitHub Issue on critical quota
  if: steps.quota.outputs.claude_quota_flag == 'critical'
  run: |
    gh issue create \
      --title "🚨 Claude API Quota Critical (≥90%)" \
      --body "Claude API 使用率が90%を超えました。Gemini/Codex フォールバックに切り替わります。" \
      --label "quota-alert,high-priority" || true
```

---

### → VSCode版 担当

**claude-agent-review.yml: Gemini fallback 追加 (45min)**

`GEMINI_API_KEY` secret が設定済みの前提で:

```yaml
# .github/workflows/claude-agent-review.yml に追加:
- name: Check Claude quota flag
  id: quota_check
  run: |
    STATUS=$(curl -sf "${SUPABASE_URL}/rest/v1/app_settings?key=eq.claude_quota_status&select=value" \
      -H "apikey: ${SUPABASE_ANON_KEY}" | jq -r '.[0].value // "ok"')
    echo "quota_status=$STATUS" >> $GITHUB_OUTPUT

- name: PR Review with Claude (primary)
  if: steps.quota_check.outputs.quota_status != 'critical'
  # ... 既存の Claude review ロジック ...

- name: PR Review with Gemini (fallback)  
  if: steps.quota_check.outputs.quota_status == 'critical'
  env:
    GEMINI_API_KEY: ${{ secrets.GEMINI_API_KEY }}
  run: |
    # Gemini API で PR diff をレビュー
    DIFF=$(gh pr diff ${{ github.event.pull_request.number }} | head -200)
    REVIEW=$(curl -sf "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}" \
      -H 'Content-Type: application/json' \
      -d "{\"contents\":[{\"parts\":[{\"text\":\"Review this PR diff for bugs and style issues:\n${DIFF}\"}]}]}" \
      | jq -r '.candidates[0].content.parts[0].text // "Review unavailable"')
    gh pr comment ${{ github.event.pull_request.number }} --body "**Gemini Review (Claude quota fallback)**\n\n${REVIEW}"
```

---

## P1 タスク (今週中)

### → Win版 担当

**GHA Secrets 追加 (15min)**

GitHub Repository Settings → Secrets → Actions に追加:
- `GEMINI_API_KEY`: Google AI Studio (https://aistudio.google.com/apikey) → 無料枠あり
- `OPENAI_API_KEY`: OpenAI Platform → Codex 用
- `SLACK_WEBHOOK_URL`: Slack Incoming Webhook → quota アラート用

**Slack quota アラート追加 (30min)**

```yaml
# quota-monitor.yml に追加:
- name: Slack alert
  if: steps.quota.outputs.claude_quota_flag != 'ok'
  env:
    SLACK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  run: |
    MSG="⚠️ Claude quota ${{ steps.quota.outputs.claude_quota_flag }}: ${USAGE}%使用"
    [ -n "$SLACK_URL" ] && curl -sf -X POST "$SLACK_URL" \
      -H 'Content-Type: application/json' \
      -d "{\"text\": \"${MSG}\"}" || true
```

---

### → PS版#2 担当 (本セッション)

**t1-dispatch.sh スクリプト整備 (即実施)**

`scripts/t1-dispatch.sh` を作成 → Claude Code 不要で dispatch 可能に。

---

## P2 タスク (来週)

### → VSCode版 担当

**github-issue-fix.yml: Codex fallback**

quota critical 時に OpenAI Codex API で Issue 修正 PR を生成。

---

## 確認事項 (Win版)

1. `app_settings` テーブルが Supabase に存在するか確認
   - なければ migration 追加: `ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS ...`
2. `SUPABASE_ANON_KEY` が GHA secret として設定済みか確認

---

## 完了チェックリスト

- [ ] P0: quota-monitor.yml 拡張 (PS#1)
- [ ] P0: claude-agent-review.yml Gemini fallback (VSCode)
- [ ] P1: GEMINI_API_KEY secret 追加 (Win版)
- [ ] P1: SLACK_WEBHOOK_URL secret 追加 (Win版)
- [ ] P1: t1-dispatch.sh 作成 (PS#2) ← 本セッション
- [ ] P2: github-issue-fix.yml Codex fallback (VSCode)

---

## 2026-04-24 更新 (PS#2)

### 確認済み ✅

- `GEMINI_API_KEY` → GitHub Secret 設定済 (ユーザー確認)
- `SLACK_WEBHOOK_URL` → GitHub Secret 設定済 (ユーザー確認)
- `ai_circuit_breaker` テーブル → migration 作成済 (`20260424210000_create_ai_circuit_breaker.sql` by PS#5 S33)
- `cs-check.yml` quota guard → PS#5 S33 で追加済

### 残タスク (アンブロック済)

- [ ] P0: `quota-monitor.yml` → `ai_circuit_breaker` テーブルへの自動書き込み (PS#1)
- [ ] P0: `claude-agent-review.yml` Gemini fallback (VSCode版) — GEMINI_API_KEY 利用可
- [ ] P0: `ai_circuit_breaker` trigger → Slack Webhook 通知 (Win版 §Backlog S3)
- [ ] P2: `github-issue-fix.yml` Codex fallback (VSCode版)
