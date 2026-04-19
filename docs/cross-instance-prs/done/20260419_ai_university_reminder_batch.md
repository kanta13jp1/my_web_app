# AI大学 学習リマインダーバッチ設定 依頼 (PS版担当)

**作成**: VSCode版#111 / 2026-04-19
**宛先**: PowerShell版
**優先度**: 中

## 概要

AI大学の学習リマインダー通知をバッチで送る GitHub Actions cron job を設定する。

## 現状

- `notification-center` Edge Function に `send_study_reminders` action が実装済み
- 3日以上未学習ユーザーへのリマインダー送信ロジックあり
- **未設定**: GitHub Actions cron schedule で定期実行するワークフローがない

## 依頼内容

`.github/workflows/ai-university-reminder.yml` を作成して以下を実装:

```yaml
name: AI大学 学習リマインダー
on:
  schedule:
    - cron: '0 1 * * *'  # 毎日 JST 10:00 (UTC 01:00)
  workflow_dispatch:

jobs:
  send-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Send AI university reminders
        run: |
          curl -X POST \
            "${{ secrets.SUPABASE_URL }}/functions/v1/notification-center" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_KEY }}" \
            -H "Content-Type: application/json" \
            -d '{"action": "send_study_reminders"}'
        env:
          SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
```

## 確認事項

1. `notification-center` EF の `send_study_reminders` action が存在するか grep確認
2. `SUPABASE_URL` / `SUPABASE_SERVICE_KEY` secrets が GitHub に設定済みか確認
3. EF 50本制限: 新規EF不要 (既存 notification-center の action追加なので問題なし)
4. `flutter analyze` / `deno lint` への影響なし (GHA yml のみ)

## 完了条件

- workflow yml が main にマージ済み
- workflow_dispatch で手動テスト成功
- このファイルを `done/` に移動
