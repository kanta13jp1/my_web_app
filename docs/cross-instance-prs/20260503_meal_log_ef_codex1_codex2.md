# Cross-Instance PR: 食事ログ EF + Migration (#1744/#1665)

**作成**: VSCode版 S26 / 2026-05-03
**FROM**: VSCode版 (MealLogPage UI 完成 → EF + Migration 要求)
**TO**: Codex#1 (migration) + Codex#2 (lifestyle-hub EF actions)
**優先度**: HIGH
**期限**: 2026-05-10 (1 週間)
**親軸**: #1665 食事ログMVP / #1744 VSCode UI

---

## 1. 背景

VSCode版 S26 で `MealLogPage` UI 実装完了。
- `/meal-log` route 追加済み
- `FitnessHealthTrackerPage` サマリタブ → `/meal-log` リンク追加済み
- `lifestyle-hub` EF に以下3 actions が必要 (現時点で未実装)

---

## 2. Codex#1 依頼: meal_logs テーブル Migration

`supabase/migrations/YYYYMMDD_create_meal_logs.sql` 新規:

```sql
CREATE TABLE meal_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  food_name TEXT NOT NULL,
  meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast','lunch','dinner','snack')),
  calories INTEGER NOT NULL CHECK (calories >= 0),
  protein_g NUMERIC(6,1) DEFAULT 0,
  carbs_g   NUMERIC(6,1) DEFAULT 0,
  fat_g     NUMERIC(6,1) DEFAULT 0,
  logged_at TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_meal_logs_user_date
  ON meal_logs (user_id, logged_at DESC);

ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users can manage own meal logs"
  ON meal_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
```

---

## 3. Codex#2 依頼: lifestyle-hub EF に3 actions 追加

`supabase/functions/lifestyle-hub/index.ts` に追加:

### `meal.log` — 食事記録
```typescript
case 'meal.log': {
  const { food_name, meal_type, calories, protein_g, carbs_g, fat_g } = body;
  await supabase.from('meal_logs').insert({
    user_id: userId,
    food_name, meal_type, calories,
    protein_g: protein_g ?? 0,
    carbs_g: carbs_g ?? 0,
    fat_g: fat_g ?? 0,
  });
  return { ok: true };
}
```

### `meal.today` — 今日の栄養サマリ
```typescript
case 'meal.today': {
  const today = new Date().toISOString().slice(0, 10);
  const { data } = await supabase
    .from('meal_logs')
    .select('*')
    .eq('user_id', userId)
    .gte('logged_at', `${today}T00:00:00Z`);
  const total_calories = data?.reduce((s, r) => s + r.calories, 0) ?? 0;
  const total_protein_g = data?.reduce((s, r) => s + Number(r.protein_g), 0) ?? 0;
  const total_carbs_g   = data?.reduce((s, r) => s + Number(r.carbs_g), 0) ?? 0;
  const total_fat_g     = data?.reduce((s, r) => s + Number(r.fat_g), 0) ?? 0;
  const by_meal = (data ?? []).reduce((acc, r) => {
    acc[r.meal_type] = (acc[r.meal_type] ?? 0) + r.calories;
    return acc;
  }, {} as Record<string, number>);
  return { total_calories, total_protein_g, total_carbs_g, total_fat_g, by_meal };
}
```

### `meal.list` — 最近の記録一覧
```typescript
case 'meal.list': {
  const limit = body.limit ?? 20;
  const { data } = await supabase
    .from('meal_logs')
    .select('*')
    .eq('user_id', userId)
    .order('logged_at', { ascending: false })
    .limit(limit);
  return { logs: data ?? [] };
}
```

---

## 4. 受入基準

- [ ] `meal_logs` テーブル migration 作成 (RLS付き) — Codex#1
- [ ] `lifestyle-hub` に `meal.log` / `meal.today` / `meal.list` actions 追加 — Codex#2
- [ ] `flutter analyze` 0 issues (既存 Flutter 変更なし)
- [ ] CI green (deploy-prod)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 5. 連携

- 前 phase: VSCode版 S26 (MealLogPage UI 完成 / `/meal-log` route)
- 後 phase: #1665 Issue close (ai-hub food_analysis AI栄養推定は別 PR)
- 関連 Issue: #1744 (P1) / #1665 (P1)

---

*VSCode版 S26 / 2026-05-03 起票 / 食事ログ EF+Migration / VSCode → Codex#1+Codex#2 lane*
