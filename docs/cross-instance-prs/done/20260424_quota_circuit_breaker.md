---
date: 2026-04-24
from: PS版#4 S33 (競合モニタリング / 開発プロセス設計)
to: Win版 + PS版#1
status: open
priority: 🔴 最優先 (Quota停止ループ 現在進行中リスク)
deadline_win: 2026-04-25
deadline_ps1: 2026-04-26
---

# Quota Circuit Breaker 実装 handoff — Win版 + PS#1

## 背景

Claude Code の Quota 制限に達すると以下が発生する:
1. GHA cron が `claude schedule` を呼び出し → 429/503 エラー
2. GHA retry 3回 → ループしてエラーが積み上がる
3. 全 scheduled タスクが停止 → 開発ログ欠損・CS 返信停止

設計書: `docs/DEV_PROCESS_MULTI_AI.md` §10 に完全仕様を記載済 (commit 499e4ce9)。
本 PR は実装タスクを Win版 / PS#1 に分配する handoff。

---

## Win版 担当タスク

### #1 ai_quota_status テーブル migration 🔴 2026-04-25

```sql
-- supabase/migrations/20260425000000_create_ai_quota_status.sql

CREATE TABLE IF NOT EXISTS public.ai_quota_status (
  provider       TEXT PRIMARY KEY,
  is_limited     BOOLEAN NOT NULL DEFAULT FALSE,
  limited_since  TIMESTAMPTZ,
  reset_estimate TIMESTAMPTZ,
  notes          TEXT,
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- 初期行
INSERT INTO public.ai_quota_status (provider)
VALUES ('anthropic'), ('openai'), ('google')
ON CONFLICT DO NOTHING;

-- RLS: service_role のみ書き込み / anon 読み取り可
ALTER TABLE public.ai_quota_status ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_read" ON public.ai_quota_status
  FOR SELECT USING (true);

CREATE POLICY "service_write" ON public.ai_quota_status
  FOR ALL USING (auth.role() = 'service_role');

-- 手動フラグ操作用コメント
-- UPDATE public.ai_quota_status SET is_limited=TRUE, limited_since=NOW(), notes='Max plan limit' WHERE provider='anthropic';
-- UPDATE public.ai_quota_status SET is_limited=FALSE, reset_estimate=NULL, notes=NULL, updated_at=NOW() WHERE provider='anthropic';
```

### #5 ✅ GEMINI_API_KEY + SLACK_WEBHOOK_URL — 設定済 (2026-04-24)

~~GitHub リポジトリ Settings > Secrets and variables > Actions に追加~~
→ ユーザー確認済: 両 Secret は既に設定されている。Win版 作業不要。

### #7 cs_queue テーブル 🟢 2026-05-07 (任意)

Claude quota 時に CS 返信を退避するキューテーブル。
詳細: `docs/DEV_PROCESS_MULTI_AI.md` §10-3 cs-check lite mode 参照。

---

## PS#1 担当タスク

### #2 cs-check.yml quota pre-check 追加 🔴 2026-04-26

`.github/workflows/cs-check.yml` の `claude schedule` ステップ前に挿入:

```yaml
- name: Check Claude quota status
  id: quota
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  run: |
    RESP=$(curl -sf \
      "${SUPABASE_URL}/rest/v1/ai_quota_status?provider=eq.anthropic&select=is_limited" \
      -H "apikey: ${SUPABASE_ANON_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" || echo '[{"is_limited":false}]')
    IS_LIMITED=$(echo "$RESP" | python3 -c "import sys,json; data=json.load(sys.stdin); print(str(data[0].get('is_limited',False)).lower())" 2>/dev/null || echo "false")
    echo "is_limited=$IS_LIMITED" >> "$GITHUB_OUTPUT"

- name: Run claude cs-check
  if: steps.quota.outputs.is_limited != 'true'
  run: claude --dangerously-skip-permissions -p "..."  # 既存コマンド

- name: Lite mode (quota limited)
  if: steps.quota.outputs.is_limited == 'true'
  run: |
    echo "⚠️ Claude quota limited — cs-check skipped. Manual review required."
    # Slack 通知 (SLACK_WEBHOOK_URL 設定済 → 即実装可)
    curl -sf -X POST "$SLACK_WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d '{"text":"⚠️ Claude quota limited — cs-check skipped ('"$(date -u +%Y-%m-%dT%H:%M:%SZ)"')"}'
```

### #3 daily-report.yml quota pre-check 追加 🔴 2026-04-26

cs-check.yml と同パターン。`claude schedule` ステップ前に quota pre-check を追加。
lite mode: AI 分析ステップを `echo "⚠️ Skipped — quota limited"` に差し替え。

### #4 quota-monitor.yml 自動フラグ設定 🔴 2026-04-28

既存の `quota-monitor.yml` に `if: failure()` ステップを追加:

```yaml
- name: Auto-flag quota exceeded
  if: failure()
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
  run: |
    curl -sf -X PATCH \
      "${SUPABASE_URL}/rest/v1/ai_quota_status?provider=eq.anthropic" \
      -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"is_limited":true,"limited_since":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","notes":"Auto-flagged by quota-monitor.yml"}'
```

### #6 pr-auto-review / github-issue-fix quota skip 🟡 2026-04-30

`pr-auto-review.yml` と `github-issue-fix.yml` にも quota pre-check ステップを追加。
限定モード: `quota-limited` ラベルを PR に付与して終了。

---

## 実装後の確認手順

```bash
# 1. テーブル確認
curl "$SUPABASE_URL/rest/v1/ai_quota_status?select=*" -H "apikey: $ANON_KEY"

# 2. 手動フラグ ON テスト
UPDATE ai_quota_status SET is_limited=TRUE WHERE provider='anthropic';

# 3. GHA workflow を手動実行 → quota limited メッセージ確認
gh workflow run cs-check.yml

# 4. フラグ解除
UPDATE ai_quota_status SET is_limited=FALSE WHERE provider='anthropic';
```

---

## 設計詳細参照

- `docs/DEV_PROCESS_MULTI_AI.md` §10 (Circuit Breaker 完全仕様)
- `docs/DEV_PROCESS_MULTI_AI.md` §11 (実装 Backlog 全 #1-8)
- `docs/DEV_PROCESS_MULTI_AI.md` §12 (各 AI セットアップ状態)

commit: 499e4ce9
