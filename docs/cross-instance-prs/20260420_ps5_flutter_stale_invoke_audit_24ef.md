# 🚨 CRITICAL: Flutter stale invoke audit — 24 EF broken pages (PS#6 → PS#5)

**Date**: 2026-04-20
**From**: PS版#6 (instance-ps6) — S18 audit
**To**: PS版#5 (on-call bug fix 専任)
**Priority**: 🔴🔴 CRITICAL (home ダッシュボードの主要ツール機能が 404)

## Summary

PS#6 S15/S16/S17 で 23 EF を削除したが、**audit filter bug** で Flutter 側
page level の invoke を見逃した。更に追加削除候補 13 件も同様に stale invoke
を持つ。**合計 24 EF** が Flutter → Edge Function 404 状態。

既に `home_tool_catalog.dart` で登録されている機能も含まれており、
**ユーザーが home からツールを開くと 404** になっている。

## Audit bug 背景

PS#6 の削除判定 script は:

```python
r = subprocess.run(['grep', '-rn', f"'{ef}'", 'lib/', '--include=*.dart'])
hits = [l for l in r.stdout.splitlines() if 'invoke' in l or 'functions/' in l]
```

という filter を使っていた。しかし:

```dart
// multi-line invoke パターン
await supabase.functions.invoke(
  'notify-feature-request',  // ← この行には "invoke" が含まれない
  body: payload,
);
```

のように **EF 名が引数行にある場合** は filter に引っかからず 0 件と判定。

正しい audit は filter なしで `lib/pages/*_page.dart` に EF 名出現を直接数える:

```python
r = subprocess.run(['grep', '-rn', f"'{ef}'", 'lib/', '--include=*.dart'])
real = [l for l in r.stdout.splitlines() if 'pages/' in l and '_page.dart' in l]
```

## 影響 EF 一覧 (24 件)

### A. 既に source 削除済・Flutter 未移行 (11 件・🔴🔴 緊急)

| EF | 削除 commit | Flutter page 修正必要 | target hub action |
| --- | --- | --- | --- |
| daily-judgment | 5f51eff4 (S16) | lib/pages/daily_judgment_page.dart:23 | ai-hub:judgment.get |
| development-achievements | 5f51eff4 (S16) | lib/pages/development_achievements_page.dart:25 | core-hub:achievements.list |
| personal-dashboard | 36634705 (S17) | lib/pages/personal_dashboard_page.dart:62 | core-hub:personal.dashboard |
| app-analytics-dashboard | 36634705 (S17) | lib/pages/app_analytics_dashboard_page.dart:31 | core-hub:analytics.summary |
| growth-share-signal | 36634705 (S17) | lib/pages/growth_share_signal_page.dart:38 | growth-hub:share.track |
| growth-achievement-summary | 36634705 (S17) | lib/pages/growth_achievement_summary_page.dart:36 | growth-hub:achievement.list |
| video-ad-generator | 36634705 (S17) | lib/pages/video_ad_generator_page.dart:32 | growth-hub:video_ad.create |
| viral-growth-engine | 36634705 (S17) | lib/pages/viral_ad_generator_page.dart:62 | growth-hub:engine.run |
| referral-program | 36634705 (S17) | lib/pages/referral_program_page.dart:33,37 | growth-hub:referral.create |
| analyze-reality | 36634705 (S17) | lib/pages/analyze_reality_page.dart:38 + reality_check_page.dart:208 | ai-hub:analyze.reality |
| virtual-organization | 36634705 (S17) | lib/pages/virtual_organization_page.dart:47,51 | ai-hub:org.get |

**注**: 削除前から deploy-prod の deploy 行は既に無かったため、削除前から 404 だった可能性大 (PS#6 による実害ではなく、過去の移行忘れを露呈させただけ)。

### B. 未削除・Flutter 未移行 (13 件・🟠 高優先)

PS#6 は今 session で削除を見送った 13 件。**こちらも deploy 行なしなので 404 疑い**:

| EF | Flutter page | target hub action |
| --- | --- | --- |
| ab-testing-manager | lib/pages/ab_testing_manager_page.dart:42,68 | enterprise-hub:ab.create |
| agent-department-manager | lib/pages/agent_department_manager_page.dart:32 | TBD (enterprise-hub?) |
| agent-performance-monitor | lib/pages/agent_performance_monitor_page.dart:32 | TBD (enterprise-hub?) |
| calendar-events | lib/pages/calendar_events_page.dart:58,107,129 | app-hub:calendar.create / calendar.list |
| chat-messaging | lib/pages/team_chat_page.dart:46,74,98 | app-hub:chat.send / chat.list |
| competitor-feature-sync | lib/pages/competitor_feature_sync_page.dart:32,61 | enterprise-hub:competitor.sync |
| goal-tracker | lib/pages/goal_tracker_page.dart:66,70,99,135,156 | tools-hub:goal.* |
| habit-tracker | lib/pages/habit_tracker_page.dart:39,63,82 | tools-hub:habit.* |
| invoice-generator | lib/pages/invoice_generator_page.dart:44,70 | social-commerce-hub:invoice.create |
| music-collaboration | lib/pages/music_collaboration_page.dart:32 | app-hub:music.sessions |
| poll-survey | lib/pages/poll_survey_page.dart:42,77,97 | tools-hub:poll.create / poll.vote |
| reading-list | lib/pages/reading_list_page.dart:32,150 | tools-hub:reading.add / reading.list |
| time-tracker | lib/pages/time_tracker_page.dart:52,76,96,164 | app-hub:time.start / time.list |

### C. S16 既 handoff 済 (再掲・1 件)

- `notify-feature-request` → lib/pages/admin/feedback_list_page.dart:79,84 → core-hub:notify.feature

## 修正テンプレ (A/B 全 24 件共通)

### Dart 側 (各 page)

```dart
// Before
await supabase.functions.invoke(
  'calendar-events',
  body: {'action': 'list', ...},
);

// After
await supabase.functions.invoke(
  'app-hub',
  body: {'action': 'calendar.list', ...},
);
```

ペイロードの `action` フィールドは hub の case 文 (例: `case "calendar.list":`) に合わせる。

### GHA / workflow (ある場合)

`feedback-issue-resolved.yml:126` のような curl 呼び出しは:

```bash
# Before
curl -X POST ".../functions/v1/notify-feature-request" \
  -d '{...}'

# After
curl -X POST ".../functions/v1/core-hub" \
  -d '{"action": "notify.feature", ...}'
```

## 優先度推奨

| Priority | EFs | 理由 |
| --- | --- | --- |
| 🔴🔴 CRITICAL | calendar-events, time-tracker, goal-tracker, habit-tracker, reading-list, music-collaboration | home_tool_catalog 登録済 = ユーザー目線で壊れて見える |
| 🔴 HIGH | personal-dashboard, app-analytics-dashboard, daily-judgment, development-achievements | admin/analytics 中核機能 |
| 🟠 MEDIUM | growth-share-signal, growth-achievement-summary, referral-program, video-ad-generator, viral-growth-engine | growth 系 (内部運用) |
| 🟡 LOW | ab-testing-manager, agent-department-manager, agent-performance-monitor, competitor-feature-sync, analyze-reality, virtual-organization, invoice-generator, poll-survey, notify-feature-request, chat-messaging | dev/internal 系 |

## PS#6 の今後の対応

- 残 13 件 (B) の source 削除は **PS#5 の Flutter 修正完了後** まで見送り
- audit filter bug は `feedback_correction_20260420_ef_audit_filter_bug.md` に記録
- 将来の EF cleanup は必ず `lib/pages/*_page.dart` 直接 grep で確認

## 関連

- S15 (d5b1e3f2): 5 EF 削除 — admin-notification-hub + 4 件 (これら 5 件はこの audit では safe だった可能性, 別途確認推奨)
- S16 (5f51eff4): 5 EF 削除 — daily-judgment / development-achievements 含む (上記 11 件の 2)
- S17 (36634705): 13 EF 削除 — 9/13 が stale invoke 残存
- S16 notify-feature-request handoff: 先発 cross-instance-pr

## Philosophy alignment

- 原則 5 (商品=ユーザー価値): 24 ツール機能の破壊経路を一括修正 → UX 大回復
- 原則 7 (資産=負債): 見えない負債 (deploy 0 + source 残の half-migration) 可視化
- 原則 3 (優しい mentor): audit bug を公開し同種の失敗を防ぐ
