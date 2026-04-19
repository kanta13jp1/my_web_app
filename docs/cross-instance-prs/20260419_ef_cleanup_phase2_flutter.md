---
date: 2026-04-19
from: Windowsアプリ版#122
to: PowerShell版#5 (on-call)
status: pending
priority: medium
---

# EF cleanup 第2弾 - Flutter コードから 40 dead EF 呼出を削除

## 概要

Win版#120 で 84 dead EF directory を削除した。残り 40 EFs は Flutter コードから `functions.invoke()` で呼ばれているため directory を残してある (削除すると 404 エラーになる)。

これら 40 EFs は **deploy-prod.yml の delete リスト** に入っている = 本番から既に削除済み = `functions.invoke()` 呼出は **404 エラーで失敗中**。

PS版#5 (on-call) で Flutter 側を修正 → directory 削除 → 第2弾 cleanup 完了。

## 依頼内容

各 EF について以下のいずれかの対応を選択して実施:

### 対応パターン A: 本物機能を別 EF/hub に統合
- 例: `daily-judgment` → `ai-hub:daily.judge` に action 追加
- 例: `notify-feature-request` → `email-service` ... もう削除済 → 別 EF へ
- ai-hub / core-hub / growth-hub / app-hub / schedule-hub / tools-hub のいずれかに統合

### 対応パターン B: 機能廃止 (UI ごと削除)
- 該当 page を削除
- main.dart routes 削除
- home_tool_catalog 削除

### 対応パターン C: 一時的にエラーハンドリング (機能を残しつつ呼出 stub)
- 呼出箇所を try/catch で包んで silent fail
- TODO コメントで「将来 hub に統合予定」

## 対応対象 40 EFs

| # | EF | 推定対応パターン |
|---|---|---|
| 1 | ab-testing-manager | A → `growth-hub:ab.test` |
| 2 | admin-notification-hub | A → `admin-hub:notify` |
| 3 | agent-department-manager | A → `core-hub:agent.dept` |
| 4 | agent-performance-monitor | A → `admin-hub:agent.perf` |
| 5 | ai-university-badges | A → `ai-hub:university.badges` |
| 6 | ai-university-content | A → `ai-hub:university.content` |
| 7 | ai-university-streaks | A → `ai-hub:university.streaks` |
| 8 | analyze-reality | B (UI 不在の可能性) |
| 9 | app-analytics-dashboard | A → `admin-hub:app.analytics` |
| 10 | calendar-events | A → `app-hub:calendar.events` |
| 11 | chat-messaging | A → `app-hub:chat.messaging` |
| 12 | competitor-feature-sync | B (PS版#4 競合モニタリングと統合検討) |
| 13 | daily-judgment | A → `ai-hub:daily.judge` (重要機能・要慎重) |
| 14 | data-export-manager | A → `admin-hub:data.export` |
| 15 | development-achievements | A → `growth-hub:dev.achievements` |
| 16 | gemini-election-analysis | A → `ai-hub:election.analyze` |
| 17 | generate-daily-challenges | A → `growth-hub:daily.challenges` |
| 18 | goal-tracker | A → `app-hub:goal.tracker` |
| 19 | growth-achievement-summary | A → `growth-hub:achievement.summary` |
| 20 | growth-acquisition | A → `growth-hub:acquisition` |
| 21 | growth-command-center | A → `growth-hub:command.center` |
| 22 | growth-import-commit | A → `growth-hub:import.commit` |
| 23 | growth-import-preview | A → `growth-hub:import.preview` |
| 24 | growth-share-signal | A → `growth-hub:share.signal` |
| 25 | habit-tracker | A → `app-hub:habit.tracker` |
| 26 | invoice-generator | A → `app-hub:invoice.generate` |
| 27 | landing-ab-test | A → `growth-hub:landing.ab` |
| 28 | memo-reactions | (deploy-prod に残してある可能性 → 要確認) |
| 29 | music-collaboration | A → `media-hub:music.collab` |
| 30 | note-comments | (deploy-prod に残してある可能性 → 要確認) |
| 31 | notify-feature-request | A → `growth-hub:feature.notify` |
| 32 | personal-dashboard | A → `core-hub:personal.dashboard` |
| 33 | poll-survey | A → `app-hub:poll.survey` |
| 34 | pomodoro-timer | A → `app-hub:pomodoro` |
| 35 | reading-list | A → `app-hub:reading.list` |
| 36 | referral-program | A → `growth-hub:referral` |
| 37 | time-tracker | A → `app-hub:time.tracker` |
| 38 | video-ad-generator | A → `media-hub:video.ad` |
| 39 | viral-growth-engine | A → `growth-hub:viral` |
| 40 | virtual-organization | A → `enterprise-hub:vorg` |

## 関連ファイル

- `.claude/tmp/risky.txt` (本リストの元データ)
- `.github/workflows/deploy-prod.yml` (delete リスト + deploy 対象)
- `lib/` 各 page (`functions.invoke('NAME')` 呼出箇所)
- `supabase/functions/<hub>/index.ts` (action 追加先)

## 推奨手順 (1 EF ずつ)

```
1. EF を選ぶ (依存少ないものから・例: poll-survey)
2. grep -rn "functions.invoke('<NAME>'" lib/ → 呼出箇所特定 (通常 1-3 箇所)
3. パターン A 採用なら hub の index.ts に action 追加 (router 分岐 + EF コードを copy)
4. Flutter 側で 'NAME' → '<hub>' + body 構造化
5. flutter analyze 0 / deno lint 0
6. supabase/functions/<NAME>/ ディレクトリを git rm -r
7. deploy-prod.yml の delete リストから <NAME> 行削除
8. commit (1 EF = 1 commit) + push
```

## 完了条件

- [ ] 40 EFs 全て Flutter 呼出を削除 or hub action 経由に変更
- [ ] supabase/functions/ から 40 EF directory 削除
- [ ] deploy-prod.yml の delete リストから 40 行削除
- [ ] flutter analyze 0 エラー
- [ ] deno lint clean
- [ ] 各 EF deploy 後の本番動作確認 (該当 page 開いて 200 確認)

## Win版#120 の判定基準 (参考)

- deploy-prod.yml の delete リストに入っている = 本番から既に削除済み
- かつ Flutter コード (lib/) から `functions.invoke('NAME')` 参照ゼロ = SAFE 削除可
- 40 EFs = まだ Flutter から呼ばれている = Flutter 修正後に削除可

宛先インスタンスが完了したら `done/` に移動してください。
