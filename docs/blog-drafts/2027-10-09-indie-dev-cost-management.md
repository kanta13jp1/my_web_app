---
title: "個人開発のコスト管理 — $0から$100/月のスタック設計"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発のコスト管理 — $0から$100/月のスタック設計

「気づいたら月$500かかってた」を防ぐ。フェーズ別に最適化したコスト設計を公開する。

## 開発初期 ($0/月): 無料枠フル活用

```
スタック:
  フロントエンド: Flutter Web → Firebase Hosting (無料 1GB/月)
  バックエンド:   Supabase Free Tier
    - DB: 500MB
    - Edge Functions: 500K 実行/月
    - Auth: 50K MAU
    - Storage: 1GB
  AI API:        Claude Haiku (最安値: $0.80/M tokens)
  メール:        Resend Free (100通/日)
  CI/CD:         GitHub Actions (2,000分/月)
```

**無料枠の罠**:

```
Supabase Free: 1週間アクティビティなし → DB一時停止
→ 対策: 週1でヘルスチェック GHA cron を設定
  on:
    schedule:
      - cron: '0 9 * * MON'
  steps:
    - run: curl -sf "$SUPABASE_URL/functions/v1/health-check"
```

## ユーザー獲得期 ($10-30/月): 最小コスト拡張

```
追加コスト:
  Supabase Pro: $25/月
    - DB: 8GB
    - Edge Functions: 2M 実行/月
    - ブランチ機能 (preview 環境)
    - 1週間停止なし
  合計: ~$25/月
```

**Claude API コスト最適化**:

```dart
// haiku / sonnet の使い分けで 80% コスト削減
String selectModel(String taskType) {
  return switch (taskType) {
    'classification' => 'claude-haiku-4-5',     // $0.80/M: 分類・短文
    'summarization'  => 'claude-haiku-4-5',     // $0.80/M: 要約
    'analysis'       => 'claude-sonnet-4-6',    // $3/M: 分析・推論
    'generation'     => 'claude-sonnet-4-6',    // $3/M: コンテンツ生成
    _                => 'claude-haiku-4-5',
  };
}
```

**Prompt Caching で 89% 削減**:

```python
# システムプロンプトをキャッシュ (Claude API)
messages = [
  {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": system_prompt,  # 長いシステムプロンプト
        "cache_control": {"type": "ephemeral"}  # キャッシュ対象
      },
      {
        "type": "text",
        "text": user_input
      }
    ]
  }
]
# 2回目以降: キャッシュ hit → 入力トークンコスト 90% 削減
```

## 成長期 ($50-100/月): 規模に応じた最適化

```
コスト内訳:
  Supabase Pro:    $25/月 (固定)
  Firebase:        $5-20/月 (Hosting + Functions)
  Claude API:      $10-30/月 (ユーザー数次第)
  Resend:          $20/月 (10K通/月 Pro)
  Vercel/CF Pages: $0 (無料枠で足りる)
  合計:            $60-95/月
```

**コスト監視 GHA**:

```yaml
# 週次コストレポート
on:
  schedule:
    - cron: '0 9 * * MON'

jobs:
  cost-report:
    steps:
      - name: Claude API usage
        run: |
          USAGE=$(curl -s "https://api.anthropic.com/v1/usage" \
            -H "x-api-key: $ANTHROPIC_API_KEY")
          echo "Input tokens: $(echo $USAGE | jq '.input_tokens')"
          echo "Output tokens: $(echo $USAGE | jq '.output_tokens')"
```

## コスト設計の原則

```
1. 無料枠を使い切る前に課金しない
2. AI API は haiku → sonnet の段階的アップグレード
3. ストレージは CDN キャッシュで API コール削減
4. 週次コスト監視 → 異常値で Slack 通知
5. 月$100 超えたら課金モデル見直し (有料プラン or 機能制限)
```

**ROI 計算**:

```
月$100 のインフラ ÷ 有料ユーザー単価 (¥980/月)
→ 損益分岐: 約 14ユーザー (~$100 ÷ ~$7/user)
→ 20ユーザーで黒字化できる規模
```

個人開発のコスト管理は「いかに無料枠を活用しながら、課金の閾値を高く保つか」が核心。月$100 以内で数百 MAU を捌けるスタックは十分に実現可能。

