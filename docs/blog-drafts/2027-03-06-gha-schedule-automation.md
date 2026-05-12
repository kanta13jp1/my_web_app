---
title: "GitHub Actions Schedule で月$0の自動化インフラを作る"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# GitHub Actions Schedule で月$0の自動化インフラを作る

このプロジェクトでは GitHub Actions の schedule トリガーで以下を完全自動化しています。費用: $0/月。Claude Code / Supabase / Firebase / AI の組み合わせで、ソロ創業者が「寝ている間も動くインフラ」を作った設計を公開します。

## 動いている自動化タスク一覧

| workflow | スケジュール | 内容 |
|---|---|---|
| `daily-report.yml` | 毎日 9:00 JST | KPI集計→Slack通知 |
| `cs-check.yml` | 毎時 | サポートチケット確認→AI返信 |
| `blog-publish.yml` | workflow_dispatch | T-1 ブログ投稿 |
| `ai-university-update.yml` | 毎日 6:00 JST | RSS収集→Supabase更新 |
| `competitor-monitoring.yml` | 毎日 3:00 JST | 競合21社 可用性チェック |
| `health-monitor.yml` | 30分毎 | インフラヘルスチェック |
| `claude-agent-review.yml` | PR 作成時 | AI コードレビュー |
| `wbs-staleness-audit.yml` | 毎週月曜 | タスク停滞検出 |

## 基本構造: schedule トリガー

```yaml
name: Daily Report
on:
  schedule:
    - cron: '0 0 * * *'  # UTC 0:00 = JST 9:00
  workflow_dispatch:      # 手動実行も可能

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate report
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
        run: |
          # Supabase Edge Function を呼び出してデータ取得
          REPORT=$(curl -sf \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
            "$SUPABASE_URL/functions/v1/schedule-hub" \
            -d '{"action":"digest.run"}')
          echo "$REPORT" | jq .
```

## cs-check.yml: AI カスタマーサポート

```yaml
name: CS Check
on:
  schedule:
    - cron: '0 * * * *'  # 毎時実行

jobs:
  cs-check:
    runs-on: ubuntu-latest
    steps:
      - name: Get unread tickets
        id: tickets
        run: |
          TICKETS=$(curl -sf \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_KEY }}" \
            "${{ secrets.SUPABASE_URL }}/functions/v1/get-support-tickets")
          echo "tickets=$TICKETS" >> $GITHUB_OUTPUT
          
      - name: AI reply via Claude
        if: steps.tickets.outputs.tickets != '[]'
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # 未返信チケットを Claude に送って返信生成
          python scripts/cs_auto_reply.py \
            --tickets '${{ steps.tickets.outputs.tickets }}'
```

## GHA 無料枠の使い方

```
無料枠: 2,000 分/月 (パブリックリポジトリは無制限)

現在の消費:
  daily-report: 5分/日 × 30日 = 150分
  cs-check: 2分/回 × 24回 × 30日 = 1,440分
  health-monitor: 1分/回 × 48回 × 30日 = 1,440分
  合計: ~3,030分

→ 有料プラン不要 (パブリックリポジトリ)
  または: cs-check を 2時間毎に変更 → 720分に削減
```

このプロジェクトはパブリックリポジトリなので無料枠無制限。プライベートなら cs-check の頻度を落として 2,000分以内に収める。

## 失敗時の通知設計

```yaml
- name: Report on failure
  if: failure()
  run: |
    curl -X POST "${{ secrets.SLACK_WEBHOOK }}" \
      -H 'Content-type: application/json' \
      --data "{\"text\": \"❌ ${{ github.workflow }} failed: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}\"}"
```

失敗時は Slack 通知。成功は静か、失敗だけ騒ぐ設計。毎回通知すると無視するようになる。

## Supabase Edge Function との組み合わせ

```
GHA (スケジューラー)
  ↓ HTTP POST
Supabase Edge Function (ロジック実行)
  ↓ SQL
PostgreSQL (データ永続化)
  ↓ Realtime
Flutter Web (リアルタイム表示)
```

ロジックを EF に置くことで:
- GHA はトリガーのみ (= yml がシンプル)
- EF をローカルで単独テスト可能
- 複数の GHA workflow が同じ EF を共有できる

## workflow_dispatch + inputs でセミ自動化

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'Blog draft path (JA)'
        required: true
      platforms:
        description: 'Platforms (devto,qiita)'
        default: 'devto'
        
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Publish blog post
        run: |
          python scripts/blog_publish.py \
            --draft "${{ inputs.draft_path }}" \
            --platforms "${{ inputs.platforms }}"
```

`blog-publish.yml` はこのパターン。AI が `gh workflow run` で自動 dispatch し、人間は URL 確認するだけ。

## 3ヶ月運用の実績

- 延べ実行回数: 約 3,000 回
- 失敗率: 2.1% (主に外部 API タイムアウト)
- 人手介入: 月 3-5 回 (429 rate limit / API キー期限切れ)
- コスト: $0 (パブリックリポジトリ無料枠内)

## まとめ

GHA Schedule で月$0インフラを作るポイント:
1. **スケジューラーとしてのみ使う** — ロジックは Supabase EF に置く
2. **失敗時のみ通知** — 成功は静か
3. **パブリックリポジトリ** なら無料枠無制限 (機密情報は Secrets に)
4. **workflow_dispatch + inputs** でセミ自動化 → AI が dispatch、人間が確認

「寝ている間も動くインフラ」はサーバーを持たなくても作れる。GHA + Supabase の組み合わせはソロ創業者の最強インフラです。
