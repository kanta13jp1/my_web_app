---
title: "個人開発者のマーケティング戦略 — Product Hunt / X / dev.to"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発者のマーケティング戦略 — Product Hunt / X / dev.to

「作ったものが誰にも使われない」が最も多い失敗パターン。作りながら広める3つのチャネル戦略を公開する。

## 個人開発マーケティングの現実

```
よくある失敗:
  作る (3ヶ月) → 公開 → 誰も来ない (1週間) → 諦める

正しい順序:
  作りながら広める → 公開前にユーザーが待っている状態を作る
```

## チャネル1: dev.to でオーガニック流入を作る

```
dev.to の特性:
  - SEO が強い (Google 1ページ目に入りやすい)
  - 英語技術記事は全世界に届く
  - アカウント維持コスト: $0
  - 投稿 100本で月 5,000〜10,000 PV
```

**戦略: 競合名 + 技術名のキーワードを狙う**:

```
記事タイトル例:
  "Supabase vs Firebase: Which to Choose for Flutter in 2026"
  "Flutter Web vs React: Performance Comparison"
  "Claude API vs OpenAI: Cost and Capabilities for Indie Devs"

→ 競合の検索ボリュームに乗れる
→ 自社製品の言及を自然に組み込む
```

**GHA で週次自動化**:

```yaml
# 毎週月曜にドラフトチェック
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  check-drafts:
    steps:
      - run: |
          COUNT=$(find docs/blog-drafts -name "*-en.md" \
            | xargs grep -l "^published: false" | wc -l)
          if [ "$COUNT" -gt 2 ]; then
            echo "⚠️ 未投稿 $COUNT 本 — 今週中に投稿を"
          fi
```

## チャネル2: X (Twitter) でビルドインパブリック

```
#buildinpublic の効果:
  - 作る過程を見せる → ユーザーが応援者になる
  - 失敗を投稿する → 最もリツイートされる
  - KPI を公開する → 信頼感が上がる
```

**週次 KPI 投稿テンプレート**:

```
今週の #buildinpublic 進捗 📊

MAU: 234 (+12%↑)
MRR: ¥23,400 (+8%↑)
新規記事: 3本

今週やったこと:
- Supabase Auth MFA 実装
- Flutter Web パフォーマンス改善 (LCP 3.2s→1.8s)
- dev.to 記事 3本投稿

来週の目標:
- Product Hunt 登録準備
- ユーザーインタビュー 2件

#flutter #supabase #個人開発
```

**GHA で毎週自動投稿**:

```yaml
# 毎週月曜に KPI を X に自動投稿
on:
  schedule:
    - cron: '0 9 * * MON'
jobs:
  post-weekly-kpi:
    steps:
      - name: Get KPI from Supabase
        run: |
          KPI=$(curl -s "$SUPABASE_URL/functions/v1/kpi-weekly" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY")
          echo "MAU=$(echo $KPI | jq '.mau')" >> $GITHUB_ENV
      - name: Post to X
        run: |
          curl -X POST "$SUPABASE_URL/functions/v1/post-x-update" \
            -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
            -d "{\"text\": \"今週の進捗 #buildinpublic MAU: $MAU\"}"
```

## チャネル3: Product Hunt で一気に認知を獲得

```
Product Hunt ローンチのタイミング:
  - 火〜木 (月・金・土日は避ける)
  - PST 00:01 から24時間カウント
  - 事前に 50 人以上のサポーターを準備

準備チェックリスト:
  ✅ ランディングページ完成
  ✅ デモ動画 60秒 (サイレント + 字幕)
  ✅ Product Hunt ページのキャッチコピー (60文字以内)
  ✅ 画像素材 5枚 (1200×630px)
  ✅ サポーターへの事前連絡 (Launch前日 + 当日朝)
```

**Product Hunt 当日の対応**:

```
9:00 AM PST: ローンチ通知 → Twitter/Slack/Discord で拡散
12:00 PM:    コメントに全て返信 (返信率が順位に影響)
18:00 PM:    進捗共有 "Currently #X on Product Hunt 🚀"
24:00 AM:    集計 → 結果をツイート (何位でも公開)
```

## 3チャネルの予算配分

```
個人開発者の時間配分 (週20時間として):
  開発:            12時間 (60%)
  dev.to 記事:      3時間 (15%)
  X #buildinpublic: 1時間 ( 5%)
  Product Hunt準備: 1時間 ( 5%)
  ユーザー対応:     3時間 (15%)
```

## まとめ

```
長期のオーガニック流入 → dev.to 技術記事 (SEO)
コミュニティ形成       → X #buildinpublic (週次KPI公開)
一点突破の認知獲得     → Product Hunt ローンチ
自動化                 → GHA で KPI 投稿・ドラフトリマインダー
```

「作ってから広める」ではなく「作りながら広める」。dev.to で信頼を積み、X で経過を見せ、Product Hunt で一気に認知を取る。この3点セットが個人開発のマーケティングの基本形。

