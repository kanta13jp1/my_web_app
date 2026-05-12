# Win Codex hand off: #768 AI 生活リセット プランナー (= part 156)

> **From**: Win Claude (= part 156)
> **To**: Win Codex
> **Priority**: medium
> **Issue**: [#768](https://github.com/kanta13jp1/my_web_app/issues/768)
> **Spec**: [`docs/AI_LIFE_RESET_PLANNER_SPEC.md`](../AI_LIFE_RESET_PLANNER_SPEC.md)
> **推定工数**: 8h
> **期限**: 2026-05-15 (= 10 day)

## Summary

Gemini 整理術 (= NotebookLM `579bd686-f17e-414a-894f-822f29b5c11e`) を応用した AI 生活リセット planner 機能の実装. 既存 ライフマネジメント (= life_goals / habit_tracker / daily_habits / kanban_board / WBS) を AI が横断 read → 「今日の最小一手」生成 + WBS / 日次タスク登録.

## Hand off scope (= 5 件 / 8h)

1. **migration**: `YYYYMMDDHHMMSS_create_life_reset_plans.sql`
   - table: `life_reset_plans` (= id / user_id / scope / generated_at / payload jsonb / wbs_task_ids[] / habit_task_ids[] / outcome_metrics / status / trace_id)
   - RLS: user own only (= `auth.uid() = user_id`)
   - index: `(user_id, generated_at DESC)`
   - 工数: 1h

2. **EF action**: `lifestyle-hub.life_reset.generate_plan`
   - 入力: `{ user_id, scope: 'time'|'money'|'health'|'study'|'work'|'all', max_minutes_per_task: 15 }`
   - 出力 schema (= spec §4 #3 参照): KGI / CSF / KPI / today_min_task / this_week_avoid / new_habit_count
   - LLM: `ai-hub.provider.chat` 経由 (= Gemini / Claude / OpenAI fallback)
   - LLM prompt 内: NotebookLM `579bd686` 由来 8 原則を inline 引用 (= hallucination 防止)
   - rate limit: 1 user / 1 day cap = 1 plan 生成 (= 「再生成」 button は 確認 dialog 経由)
   - 工数: 3h

3. **Flutter UI**: `life_goals_page.dart` 内 tab 追加 (= 案 A 推奨)
   - tab `🔄 Reset Plan` 新規
   - scope dropdown (= 5 + all)
   - 「生成」 button → EF call (= ローディング 5-10s)
   - 結果 4 section: KGI / CSF / KPI / 今日の最小タスク
   - action button: 「WBS 登録」「日次タスクへ追加」「再生成」
   - 「やらないこと」 section (= 折りたたみ)
   - 工数: 3h

4. **dart format + flutter analyze**: 0.5h
   - `dart format <abs-path> --set-exit-if-changed` (= [DART-FORMAT] 遵守 / 絶対パス + pipe なし)
   - `flutter analyze` 0 issue
   - 動作確認 (= 開発環境)

5. **migration apply + EF deploy + 本番 smoke test**: 0.5h
   - `supabase db push`
   - `supabase functions deploy lifestyle-hub`
   - 本番で 1 plan 生成確認 (= my-web-app-b67f4.web.app)

## 受け入れ条件 (= Issue #768 / 4 件)

- [ ] ユーザーの現状から AI が生活リセット計画を生成できる
- [ ] 生成結果に KGI / CSF / KPI / 今日の最小タスク が含まれる
- [ ] 継続系タスクは 1 つずつ習慣化する設計 (= `new_habit_count: 1` hard cap)
- [ ] 生成タスクを WBS または日次タスクに登録できる

## ルール遵守 check

- [x] [EF-FIRST] (= 既存 lifestyle-hub action 追加 / Flutter widget は表示+操作のみ)
- [x] [EF-CAP-50] (= 新 EF 不要 / 50 維持)
- [x] [REAL-DATA] (= life_goals / wbs_tasks / habit_tracker 既存実データ参照)
- [x] [DART-FORMAT] (= 絶対パス + pipe なし)
- [ ] [DYNAMIC-CLAIM] cap 遵守 (= 本 task 1 件 / Codex 着手時 wbs.claim_task)
- [ ] [WORKDIR-ISOLATION] (= Codex 自前 worktree 内作業)

## 関連

- spec: `docs/AI_LIFE_RESET_PLANNER_SPEC.md` (= 9 section / 9 原則 / NOT to do 7 + MUST do 9)
- 既存 page: `lib/pages/life_goals_page.dart` / `lib/pages/life_goals_kpi_page.dart` / `lib/pages/daily_habits_page.dart`
- 既存 EF: `supabase/functions/lifestyle-hub/` (= 110 action) / `supabase/functions/ai-hub/` (= LLM backbone)
- NotebookLM: `579bd686-f17e-414a-894f-822f29b5c11e` (= 8 Gemini Tips for Organizing Your Space and Life)

## 起票元 part

- part 156 / Win Claude / 2026-05-05
- chain merge (= depth 5 → 0 リセット) 後の副 task 第 2 件
- 第 1 件: ROADMAP append (= PR #2039 merged) + WBS UI fix (= PR #2040 merged)
