---
title: "個人開発のコードレビュー自動化 — GHA + Claude API でPRを自動レビュー"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# 個人開発のコードレビュー自動化 — GHA + Claude API でPRを自動レビュー

個人開発でのコードレビュアーは自分だけ。Claude API を GHA に組み込んで、PR 作成時に自動でレビューさせる仕組みを作る。

## なぜ自動レビューが必要か

```
個人開発の問題:
  - レビュアーがいない → バグが本番に入る
  - 自分でセルフレビューしても見落とす
  - 翌日見直そう → 忘れる

解決策:
  PR 作成 → GHA トリガー → Claude API がレビュー → PR コメントに投稿
```

## GHA ワークフロー

```yaml
# .github/workflows/claude-pr-review.yml
name: Claude PR Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
      contents: read

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get PR diff
        id: diff
        run: |
          DIFF=$(git diff origin/${{ github.base_ref }}...HEAD \
            -- '*.dart' '*.ts' '*.sql' \
            | head -c 8000)  # token 制限対策
          echo "diff<<EOF" >> $GITHUB_OUTPUT
          echo "$DIFF" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Claude review
        id: review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          REVIEW=$(curl -s https://api.anthropic.com/v1/messages \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d '{
              "model": "claude-haiku-4-5-20251001",
              "max_tokens": 1024,
              "messages": [{
                "role": "user",
                "content": "以下の diff をレビューしてください。バグ・セキュリティリスク・パフォーマンス問題を指摘してください。良い点も1-2個挙げてください。\n\n```diff\n'"${{ steps.diff.outputs.diff }}"'\n```"
              }]
            }' | jq -r '.content[0].text')
          echo "review<<EOF" >> $GITHUB_OUTPUT
          echo "$REVIEW" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Post review comment
        uses: actions/github-script@v7
        with:
          script: |
            await github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## 🤖 Claude レビュー\n\n${{ steps.review.outputs.review }}`
            });
```

## コスト最適化

```
モデル選定:
  claude-haiku-4-5  → 高速・低コスト ($0.80/MTok input)
  claude-sonnet-4-6 → 高品質・中コスト ($3/MTok input)

diff を 8,000 文字に制限:
  大きな PR は要約して送る
  変更ファイル数が多い場合は重要ファイルのみ抽出

月次コスト試算 (haiku, PR 50本/月, 平均 4,000 文字):
  Input: 50 × 4,000 文字 ≒ 200K tokens × $0.80 = $0.16
  Output: 50 × 1,000 tokens × $4 = $0.20
  合計: 約 $0.36/月 (≒ ¥55)
```

## レビュー品質を上げるプロンプト

```yaml
- name: Claude review
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    curl -s https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d '{
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 1500,
        "system": "あなたは Flutter + Supabase アプリのシニアエンジニアです。セキュリティ・パフォーマンス・Flutter のベストプラクティスに詳しいです。",
        "messages": [{
          "role": "user",
          "content": "PR diff を以下の観点でレビューしてください:\n1. バグ・ロジックエラー\n2. セキュリティリスク (RLS 抜け / 認証漏れ)\n3. Flutter パフォーマンス (rebuild 最小化)\n4. Dart 慣例 (async/await / null safety)\n5. 良い点 (必ず1-2個)\n\n```diff\n${DIFF}\n```"
        }]
      }'
```

## Gemini フォールバック

```yaml
- name: Review with fallback
  run: |
    # Claude が失敗した場合 Gemini にフォールバック
    REVIEW=$(call_claude "$DIFF") || \
    REVIEW=$(call_gemini "$DIFF")
    echo "$REVIEW"
```

## まとめ

```
トリガー  → PR opened/synchronize
diff 取得 → git diff で変更ファイルのみ抽出
Claude   → haiku で低コスト (月 $0.36)
投稿      → PR コメントとして自動投稿
フォールバック → Gemini で冗長性確保
```

個人開発でも「レビュアーがいない問題」は解決できる。月 ¥55 のコストでバグ混入リスクを大幅に下げる。

