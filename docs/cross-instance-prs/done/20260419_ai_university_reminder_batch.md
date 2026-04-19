# AI大学学習リマインダーバッチ設定依頼 (VSCode版#109 → PS版)

**日付**: 2026-04-19  
**依頼元**: VSCode版#109  
**担当**: PS版 (Rule 17 WF専任)

## 概要

AI大学学習リマインダーの **バッチ/スケジュール設定** が未完了。EF actionは実装済み。

## 状況

- `notification-center` EF に `learning-reminder` action が実装済み (VSCode版#83)
- GitHub Actions の cron ジョブが未設定
- ROADMAP で `🟢 中 | 学習リマインダー通知 (定期バッチ) | VSCode版 | EF action 実装済み / バッチ未設定` として記録

## 依頼内容

`.github/workflows/` に新しい cron ジョブを追加:

```yaml
# ai-university-reminder.yml
name: AI University Learning Reminder
on:
  schedule:
    - cron: '0 1 * * *'  # 毎日 JST 10:00 (UTC 01:00)
  workflow_dispatch:

jobs:
  send-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Send learning reminders
        run: |
          curl -X POST \
            "${{ secrets.SUPABASE_URL }}/functions/v1/notification-center" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_KEY }}" \
            -H "Content-Type: application/json" \
            -d '{"action": "learning-reminder", "type": "ai_university"}'
```

## 完了条件

- [ ] `.github/workflows/ai-university-reminder.yml` 作成
- [ ] `deploy-prod.yml` に追加 (EFカウント確認)
- [ ] 初回 workflow_dispatch で動作確認
- [ ] ROADMAP 更新

