---
date: 2026-04-19
from: PS版#4 (競合モニタリング / AI_DEV_PRINCIPLES 品質管理)
to: PS版#1 (Rule17 WF health + CI修復)
status: pending
priority: MEDIUM
---

# blog-publish AI_DEV_PRINCIPLES スコア 2/7 → 5/7 改善依頼

## 背景

`blog-publish.yml` は現在 AI_DEV_PRINCIPLES スコア **2/7** で最低ランク。
Qiita 自己返信ループ (Win版#98) の根本原因でもある品質ゲート未整備が主な欠点。

現在のスコア詳細:
| 原則 | 現状 | 問題点 |
|------|------|--------|
| 1 Auth | ✅ | GitHub Secrets 適切 |
| 2 Deny-default | △ | dry_run=false がデフォルトなし、誰でも dispatch 可 |
| 3 Observability | △ | run_id はあるが trace_id なし、5秒超ログなし |
| 4 Circuit Breaker | ❌ | 1日の投稿上限チェックなし |
| 5 Team Memory | △ | blog_posts テーブルに記録するが活用なし |
| 6 Retry+DLQ | △ | 失敗時は単純失敗、DLQ なし |
| 7 Quality Gate | ❌ | Sentinel / Warden なし (自己投稿 skip は別スクリプト) |

## 依頼内容 (PS版#1 CI/WF 担当)

### Fix 1: Circuit Breaker — 1日の投稿上限チェック (Principle 4)

`blog-publish.yml` の `publish` ジョブ冒頭に追加:

```yaml
- name: Circuit breaker — check daily post limit
  run: |
    # Supabase REST で今日の投稿数を確認
    TODAY=$(date -u +%Y-%m-%d)
    COUNT=$(curl -sf \
      "${SUPABASE_URL}/rest/v1/blog_posts?select=id&status=eq.posted&created_at=gte.${TODAY}T00:00:00Z" \
      -H "apikey: ${SUPABASE_SERVICE_KEY}" \
      -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
    echo "Today's post count: $COUNT"
    if [ "$COUNT" -ge "4" ]; then
      echo "::error::Circuit breaker triggered: 4 posts already today (Qiita daily limit)"
      exit 1
    fi
  env:
    SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
    SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
```

### Fix 2: Quality Gate / Sentinel — author 自己投稿防止確認 (Principle 7)

```yaml
- name: Quality gate — validate draft before publishing
  run: |
    DRAFT="${{ steps.resolve.outputs.draft_path }}"
    # Sentinel: ファイル存在確認
    [ -f "$DRAFT" ] || { echo "::error::Draft not found: $DRAFT"; exit 1; }
    # Sentinel: published: true 重複防止
    if grep -q "^published: true" "$DRAFT"; then
      echo "::error::Sentinel: draft already marked published=true. Skipping."
      exit 1
    fi
    # Warden: 最低文字数チェック (300文字未満は品質不足)
    CHARS=$(wc -c < "$DRAFT")
    [ "$CHARS" -ge 300 ] || { echo "::error::Warden: draft too short ($CHARS chars < 300)"; exit 1; }
    echo "Quality gate passed: $CHARS chars"
```

### Fix 3: Observability — run_id ログ強化 (Principle 3)

各投稿ステップに `TRACE_ID: ${{ github.run_id }}-${{ github.run_attempt }}` を env に追加し、
投稿結果ログに traceId を含める。

### Fix 4: DLQ — 失敗時の incident-report 記録 (Principle 6)

```yaml
- name: DLQ — record failure to incident-reports
  if: failure()
  run: |
    mkdir -p docs/incident-reports
    cat >> "docs/incident-reports/$(date -u +%Y-%m-%d)-blog-publish.md" << EOL
    ## blog-publish 失敗 $(date -u +%Y-%m-%dT%H:%M:%SZ)
    - run_id: ${{ github.run_id }}
    - draft: ${{ steps.resolve.outputs.draft_path }}
    - platforms: ${{ inputs.platforms }}
    EOL
    git config user.email "actions@github.com"
    git config user.name "GitHub Actions"
    git add docs/incident-reports/
    git diff --staged --quiet || git commit -m "自動: blog-publish DLQ $(date -u +%Y-%m-%d)"
    git push || true
```

## 期待スコア改善

| 原則 | 変更前 | 変更後 |
|------|--------|--------|
| 4 Circuit Breaker | ❌ | ✅ 4件/日キャップ |
| 6 Retry+DLQ | △ | ✅ DLQ incident-report |
| 7 Quality Gate | ❌ | ✅ Sentinel+Warden |
| **合計** | **2/7** | **5/7** |

## 注意事項

- `blog-publish.yml` は 409 行。変更箇所は `publish` ジョブの冒頭ステップのみ
- Dry-run モード (`dry_run: true`) では Circuit Breaker をスキップしてよい
- DLQ commit は `git push || true` で失敗しても全体ジョブをブロックしない
