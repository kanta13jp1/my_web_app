---
title: "GitHub Actions 自動化パイプライン設計 — ブログ投稿から動画生成まで"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# GitHub Actions 自動化パイプライン設計 — ブログ投稿から動画生成まで

個人開発で「運用コスト」を下げるために、繰り返し作業を GitHub Actions で完全自動化しました。ブログ投稿・動画生成・競合モニタリング・インフラヘルスチェックがすべて cron で動いています。

## 全体ワークフロー構成

```
毎日 06:00 JST
  ├── daily-report.yml       → KPI取得 → Slack通知
  ├── cs-check.yml           → 未返信チケット → AI返信
  └── ai-university-update.yml → RSSフィード → DB更新

毎週日曜 JST
  ├── evaluate-predictions.yml → 競馬AI精度評価
  └── weekly-sns-draft.yml    → X投稿下書き生成

手動 / PR連動
  ├── blog-publish.yml       → dev.to + Qiita 投稿
  ├── deploy-prod.yml        → Firebase Hosting デプロイ
  └── video-pipeline.yml     → NotebookLM → ElevenLabs → 動画生成
```

## blog-publish.yml の設計

```yaml
on:
  workflow_dispatch:
    inputs:
      draft_path:
        description: 'JA draft path'
      draft_path_en:
        description: 'EN draft path'
      platforms:
        description: 'devto,qiita'
        default: 'devto'
      dry_run:
        description: 'true = skip actual post'
        default: 'false'
```

手動 dispatch で JA/EN ペアを同時投稿。`dry_run` で投稿内容を事前確認できる。

重要な設計決定: **orphan branch パターン**。

```yaml
jobs:
  publish:
    steps:
      - name: Update published:true
        run: |
          sed -i 's/^published: false/published: true/' "${{ inputs.draft_path }}"
          git commit -m "published: ${{ inputs.draft_path }}"
          git push origin HEAD:blog-publish/${{ github.run_id }}-$(date +%Y%m%d-%H%M%S)
```

`published: true` の更新を専用 branch に push → Claude Code が merge。この方式でブランチ競合が起きない。

## video-pipeline.yml の設計

AI動画コンテンツを完全自動生成するパイプライン:

```yaml
steps:
  - name: Generate script via NotebookLM
    run: notebooklm ask "$TOPIC" > script.md

  - name: Generate audio via ElevenLabs
    run: |
      curl -X POST "https://api.elevenlabs.io/v1/text-to-speech/$VOICE_ID" \
        -H "xi-api-key: $ELEVENLABS_KEY" \
        -d "{\"text\": \"$(cat script.md)\"}" \
        > audio.mp3

  - name: Generate video via Remotion
    run: npx remotion render VideoTemplate --props='{"audioFile":"audio.mp3"}'

  - name: Upload to storage
    run: supabase storage upload videos/$(date +%Y%m%d).mp4 output/video.mp4
```

NotebookLM でスクリプト → ElevenLabs で音声 → Remotion で動画。全部 GHA で自動化。

## cs-check.yml: AIカスタマーサポート

```yaml
on:
  schedule:
    - cron: '0 */6 * * *'  # 6時間毎

steps:
  - name: Get pending tickets
    run: |
      TICKETS=$(curl -s "$SUPABASE_URL/functions/v1/get-support-tickets" \
        -H "Authorization: Bearer $SERVICE_KEY")

  - name: AI reply via Claude
    run: |
      echo "$TICKETS" | claude --model claude-haiku-4-5 \
        "Reply to these support tickets in Japanese. Be helpful and specific."
```

6時間毎にチケットを確認 → haiku で返信草案 → EF 経由で投稿。Claude Haiku を使うことでコストを最小化。

## 設計原則

**1. Claude 非依存設計**  
cron タスクは Claude API に依存しない。API outage でも継続動作する。haiku は使うが、`claude-agent-review.yml` のような設計・判断タスクとは分離。

**2. dry_run 必須**  
すべての dispatch workflow に `dry_run` input。新 workflow は必ず dry_run で検証してから本番投入。

**3. run-level concurrency 設定**  
deploy-prod は `cancel-in-progress: false` で queuing。blog-publish はキャンセル許可 (同一ドラフトの二重投稿防止は Step 2.3 の pre-check で担う)。

## まとめ

個人開発で GHA 自動化を最大化すると、「自分がやること」が劇的に減ります。私の場合、ブログ投稿・CS対応・競合監視・動画生成のルーティン作業がほぼゼロになりました。残るのは「何を作るか」の判断だけです。それが CEO 専任化の本質です。
