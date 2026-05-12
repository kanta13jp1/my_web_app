---
title: "個人開発ローンチチェックリスト — Product Hunt・HN・SNS 同時展開"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発ローンチチェックリスト — Product Hunt・HN・SNS 同時展開

初回ローンチを最大化するための実行済みチェックリストをまとめる。ローンチ当日は判断疲れを防ぐために事前準備がすべて。

## ローンチ前 (1週間前)

```markdown
## インフラ確認
- [ ] 本番 URL にアクセスできる (HTTPS 必須)
- [ ] エラーモニタリング (Sentry / Supabase Logs) 稼働中
- [ ] DB バックアップ自動化済み
- [ ] レート制限 (Edge Function throttle) 設定済み

## 素材準備
- [ ] OGP 画像 (1200×630px)
- [ ] デモ動画 (60秒以内)
- [ ] スクリーンショット 3枚以上
- [ ] キャッチコピー (50文字以内)
- [ ] "3つの価値" 文章 (bullet 3行)
```

## Product Hunt 投稿テンプレート

```markdown
## Tagline (60文字以内)
Notion + MoneyForward + Slack を1つに統合した AI ライフ OS

## Description
【問題】ツールが多すぎて情報が分散
【解決】自分株式会社: 21競合の機能を1アプリに集約
【差別化】AI が毎日の判断を自動化

## First Comment (自己紹介 + 開発背景)
こんにちは！個人開発者のかんたです。
[開発背景を100-200文字で]
今日だけ無料プランのストレージを2倍にします → [URL]
```

## HN Show HN テンプレート

```markdown
Show HN: [アプリ名] – [一行説明] ([URL])

[技術スタック: Flutter Web + Supabase]
[解決する問題を1段落]
[数字で示す: ユーザー数 / 機能数 / 開発期間]
[フィードバック歓迎の一言]
```

## ローンチ当日の GHA 自動化

```yaml
# .github/workflows/launch-day.yml
on:
  workflow_dispatch:
    inputs:
      launch_url:
        required: true

jobs:
  post-x:
    steps:
      - name: Post launch tweet
        run: |
          curl -X POST "$SUPABASE_EF_URL/post-x-update" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
            -d "{\"message\": \"ローンチしました！ ${{ inputs.launch_url }} #buildinpublic\"}"
```

## まとめ

```
インフラ      → エラー監視 + レート制限 を事前設定
素材          → OGP + 動画 + キャッチコピー (ローンチ当日は作らない)
PH 投稿       → tagline 60文字以内 + first comment で人間味を出す
HN            → Show HN: フォーマット厳守 + 技術詳細を添える
SNS 自動化    → GHA でツイート・投稿を自動化し作業ゼロに
```

ローンチ当日は「実行」だけ。準備をすべて前日までに完了させる。
