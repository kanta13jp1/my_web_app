# cross-instance-pr: Multi-AI フォールバック — GHA quota guard 追加 [Done]

**from**: PS版#5 (on-call)
**to**: PS版#1 (CI/CD 担当) または VSCode版
**date**: 2026-04-24
**priority**: medium
**deadline**: 2026-04-30

## 背景

Claude quota 枯渇 → GHA schedule タスクがエラーループ。
`cs-check.yml` には quota guard 追加済み (PS#5 S33 / 2026-04-24)。
以下のワークフローに同じパターンで quota guard を追加する。

## 依頼内容

各ワークフローの jobs.<job>.steps 先頭に以下ステップを追加し、
AI依存ステップに `if: steps.quota_check.outputs.anthropic_available == 'true'` を付ける。

### Quota Guard テンプレート (cs-check.yml から抜粋)

```yaml
- name: Quota Guard — Anthropic circuit breaker check
  id: quota_check
  env:
    SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
  run: |
    RESPONSE=$(curl -s \
      -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
      -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
      "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_circuit_breaker?provider=eq.anthropic&select=state,expires_at" \
      --max-time 5 2>/dev/null || echo "[]")
    STATE=$(echo "$RESPONSE" | jq -r '.[0].state // "closed"' 2>/dev/null || echo "closed")
    EXPIRES=$(echo "$RESPONSE" | jq -r '.[0].expires_at // ""' 2>/dev/null || echo "")
    if [ "$STATE" = "open" ] && [ -n "$EXPIRES" ]; then
      NOW=$(date -u +%s)
      EXP=$(date -u -d "$EXPIRES" +%s 2>/dev/null || echo "9999999999")
      [ "$EXP" -lt "$NOW" ] && STATE="closed" && echo "⏰ CB expired → closed"
    fi
    if [ "$STATE" = "open" ]; then
      echo "⚠️ Anthropic quota exceeded — AI steps skipped"
      echo "anthropic_available=false" >> $GITHUB_OUTPUT
    else
      echo "✅ Anthropic available"
      echo "anthropic_available=true" >> $GITHUB_OUTPUT
    fi
```

### 対象ファイルとスキップ対象ステップ

| ファイル | スキップ対象ステップ | 代替動作 |
|---------|---------------------|---------|
| `blog-draft.yml` | ブログ草稿生成 step | スキップ (quota 回復後に手動実行) |
| `ai-university-update.yml` | AI大学コンテンツ更新 step | スキップ (古いコンテンツ維持) |
| `daily-report.yml` | AI分析/コメント生成 step | データ集計のみ記録して commit |
| `blog-engagement.yml` | AI返信生成 step | スキップ (自己ループ防止とも兼用) |

## 参考実装

`cs-check.yml` の "Quota Guard" + "Step 2" の `if:` 条件を参照。

## 受け入れ条件

- [ ] 上記4ワークフローに quota guard 追加
- [ ] quota open 時は AI step をスキップし exit 0 で正常終了 (エラーループ防止)
- [ ] quota check 失敗 (Supabase 到達不可) 時は closed 扱いでスキップしない

## ✅ 完了 (VSCode版 S16 2026-04-29)
- commit: 0565cabf8
- blog-draft/ai-university-update/daily-report/blog-engagement 4 workflow に quota guard 追加
