# [緊急] require_trailing_commas 36件エラー → deploy-prod 修正依頼

## 現状
- VSCode版#104 が prefer_const → warning 降格をpush済み
- しかし deploy-prod 依然 failure
- 真因: require_trailing_commas 36件 (24ファイル)

## dart fix 禁止
dart fix --apply は prefer_const_constructors 修正時に腐敗を起こした:
- `const const const Color(...)` 多重化
- `Colors.const red` (Colors. の後にconstが挿入)
- 16進数値内に const 挿入 (`0x0ff55c5const 00`)
→ `git checkout -- lib/` でリバートした

## 修正方法
Python script または手動で trailing comma を exact position に挿入:

```
lib/pages/access_control_page.dart:139:51
lib/pages/ai_agent_page.dart:181:49
lib/pages/ai_company_builder_page.dart:342:64
lib/pages/analytics_export_page.dart:171:59
lib/pages/danshari_page.dart:174:63
lib/pages/elearning_course_manager_page.dart:216:63
lib/pages/election_strategy_page.dart:553:72
lib/pages/election_strategy_page.dart:713:59
lib/pages/election_strategy_page.dart:930:65
lib/pages/email_template_builder_page.dart:114:59
lib/pages/habit_gamification_page.dart:282:44
lib/pages/medical_notes_page.dart:314:65
lib/pages/mental_check_page.dart:252:65
lib/pages/news_rss_aggregator_page.dart:148:67
lib/pages/onboarding_page.dart:168:69
lib/pages/onboarding_page.dart:196:75
lib/pages/real_estate_tracker_page.dart:460:53
lib/pages/real_estate_tracker_page.dart:539:59
lib/pages/recipe_meal_planner_page.dart:190:51
lib/pages/recipe_meal_planner_page.dart:193:59
lib/pages/rewards_page.dart:71:25
lib/pages/support_tickets_page.dart:103:71
lib/pages/team_workspace_page.dart:600:61
lib/pages/thought_interrupt_diagnosis_page.dart:39:30
lib/pages/thought_interrupt_diagnosis_page.dart:75:69
lib/pages/thought_interrupt_diagnosis_page.dart:98:68
lib/pages/thought_interrupt_diagnosis_page.dart:124:70
lib/pages/time_tracker_page.dart:331:65
lib/pages/two_factor_auth_page.dart:235:65
lib/pages/voice_memo_transcriber_page.dart:355:55
lib/pages/wiki_database_page.dart:268:51
lib/pages/wiki_database_page.dart:271:59
lib/pages/wiki_database_page.dart:352:59
lib/pages/wiki_database_page.dart:373:72
lib/pages/workflow_automation_page.dart:182:51
lib/pages/workflow_automation_page.dart:315:65
```

## 修正後手順
1. dart format lib/ --set-exit-if-changed → OK確認
2. flutter analyze (exit code 0 確認)
3. git add → commit → push

