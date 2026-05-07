# 食事ログ MVP 設計仕様書 (= Issue #1665 / #1269)

> **作成**: Win版#132 part 164 / 2026-05-07
> **From**: Win Claude (= architect / design / docs)
> **To**: Win Codex (= 実装 / migration / EF / Flutter UI 着地)
> **優先度**: high (= P1 / 期限 2026-05-22 残 15 日)
> **関連**: Issue [#1665](https://github.com/kanta13jp1/my_web_app/issues/1665) / Issue [#1269](https://github.com/kanta13jp1/my_web_app/issues/1269) (= parent)

---

## 1. 背景 + ゴール

### 既存資産

- `lib/pages/recipe_meal_planner_page.dart` (= `RecipeMealPlannerPage` / 3 tabs: レシピ / 週間プラン / 買い物リスト / `lifestyle-hub` EF を `recipe.list` + `meal.list_plans` action 経由で利用)
- `lib/pages/health_page.dart` (= `HealthPage`)
- `lib/pages/fitness_health_tracker_page.dart` (= `FitnessHealthTrackerPage`)

### gap

日々の食事記録 (= 朝/昼/夜/間食 / 概算 kcal + 主要栄養素) と栄養バランス可視化はまだ unified UI に統合されていない。`#1269` parent issue は期限切れ (= 2026-05-02) のまま未分割。

### MVP ゴール (= 外部食品 API 不要)

- 朝/昼/夜/間食の食事ログ 入力 + 一覧
- 1 日の概算 kcal + 主要栄養素 (= protein / fat / carb) 合計表示
- 既存 `RecipeMealPlannerPage` (= レシピ/食事プランナー導線) から自然にアクセス可能

---

## 2. アーキテクチャ判断 (= [EF-FIRST] + [EF-CAP-50])

### 2.1 EF: 既存 `lifestyle-hub` 拡張 (= 新規 EF 不要)

`lifestyle-hub` にすでに `recipe.list` + `meal.list_plans` action が存在 = 同 namespace で `meal_log.*` action 追加。

**追加 action 4 件**:

| action | 入力 | 出力 | 説明 |
|--------|------|------|------|
| `meal_log.add` | `{ meal_type, menu_name, store_name?, kcal?, protein_g?, fat_g?, carb_g?, vegetables_note?, salt_note?, logged_at? }` | `{ ok: true, id }` | 食事ログ 1 件追加 |
| `meal_log.list` | `{ from?, to?, limit? }` (= ISO date) | `{ logs: [...], total: N }` | 期間絞込 list / default = 当日 |
| `meal_log.summary_today` | (none) | `{ kcal_total, protein_g_total, fat_g_total, carb_g_total, by_meal_type: { breakfast: kcal, lunch: kcal, dinner: kcal, snack: kcal } }` | 当日 summary |
| `meal_log.delete` | `{ id }` | `{ ok: true }` | 削除 (= owner 確認必須) |

**RLS方針**: `auth.uid() = user_id` で SELECT/INSERT/UPDATE/DELETE 全 gate。Admin client 経由の delete は禁止 (= [feedback_correction_20260504_schedule_hub_admin_writes] 教訓)。

### 2.2 Schema: 新規 `meal_logs` table

```sql
-- supabase/migrations/YYYYMMDDHHMMSS_create_meal_logs.sql
CREATE TABLE IF NOT EXISTS meal_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  menu_name TEXT NOT NULL,
  store_name TEXT,
  kcal INT,
  protein_g NUMERIC(6, 2),
  fat_g NUMERIC(6, 2),
  carb_g NUMERIC(6, 2),
  vegetables_note TEXT,
  salt_note TEXT,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meal_logs_user_id_logged_at_idx
  ON meal_logs (user_id, logged_at DESC);

ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY meal_logs_select_own ON meal_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY meal_logs_insert_own ON meal_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY meal_logs_update_own ON meal_logs FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY meal_logs_delete_own ON meal_logs FOR DELETE
  USING (auth.uid() = user_id);
```

**注意**:
- `kcal` + `*_g` 列は **NULLABLE** (= 概算で記入できないケースあり / MVP 受け入れ条件 #3「外部 API 未設定でもローカル入力だけで動作」)
- `meal_type` は CHECK 制約で 4 種固定 (= 朝/昼/夜/間食 mapping)
- `logged_at` = client 指定 OK / default = NOW (= 「今食べた」即座記録)
- `vegetables_note` / `salt_note` = 自由記述 (= 例: 「サラダ込」「醤油多め」)

### 2.3 UI: `RecipeMealPlannerPage` に 4 番目 tab 追加

**現状**: `length: 3` tab (= レシピ / 週間プラン / 買い物リスト)
**変更**: `length: 4` (= 4 番目「食事ログ」追加)

```dart
_tabController = TabController(length: 4, vsync: this);
```

```dart
// AppBar bottom TabBar
tabs: const [
  Tab(icon: Icon(Icons.restaurant_menu), text: 'レシピ'),
  Tab(icon: Icon(Icons.calendar_today), text: '週間プラン'),
  Tab(icon: Icon(Icons.shopping_cart), text: '買い物リスト'),
  Tab(icon: Icon(Icons.dinner_dining), text: '食事ログ'), // 新規
],
```

---

## 3. UI 設計 (= 食事ログ tab)

### 3.1 レイアウト

```
┌─────────────────────────────────────┐
│ [+ 朝食]  [+ 昼食]  [+ 夜食]  [+ 間食] │ ← 入力 trigger 4 button (DESIGN.md Orange)
├─────────────────────────────────────┤
│ 本日のサマリ                          │
│   合計 kcal: 1820                    │
│   P: 75 g  /  F: 60 g  /  C: 230 g    │
│   朝: 450  昼: 720  夜: 580  間食: 70   │
├─────────────────────────────────────┤
│ 本日のログ                            │
│ ┌─────────────────────────────┐ │
│ │ 🌅 朝 08:30 / カフェラテ + サンドイッチ │ │
│ │   450 kcal / P 18 g / F 22 g / C 45 g │ │
│ │                          [削除]   │ │
│ └─────────────────────────────┘ │
│ ...                                  │
└─────────────────────────────────────┘
```

### 3.2 入力 dialog

`+ 朝食` ボタン → modal dialog:

| Field | Type | Required | Note |
|-------|------|----------|------|
| メニュー名 (`menu_name`) | TextField | ✅ | 必須 |
| 外食チェーン名 (`store_name`) | TextField | ❌ | 「サイゼリヤ」等 |
| 概算 kcal (`kcal`) | NumberField | ❌ | int |
| たんぱく質 g (`protein_g`) | NumberField | ❌ | NUMERIC |
| 脂質 g (`fat_g`) | NumberField | ❌ | NUMERIC |
| 炭水化物 g (`carb_g`) | NumberField | ❌ | NUMERIC |
| 野菜メモ (`vegetables_note`) | TextField | ❌ | 自由記述 |
| 塩分メモ (`salt_note`) | TextField | ❌ | 自由記述 |

「保存」ボタン → `lifestyle-hub` EF `meal_log.add` invoke → 成功時 `_fetchData()` 再 trigger + dialog close + SnackBar 「食事ログ追加しました」。

### 3.3 サマリ section

```dart
Widget _buildMealLogSummary() {
  final kcal = _todaySummary['kcal_total'] ?? 0;
  final p = _todaySummary['protein_g_total'] ?? 0;
  final f = _todaySummary['fat_g_total'] ?? 0;
  final c = _todaySummary['carb_g_total'] ?? 0;
  final byType = _todaySummary['by_meal_type'] as Map<String, dynamic>? ?? {};

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('本日のサマリ', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('合計 $kcal kcal'),
          Text('P: $p g  /  F: $f g  /  C: $c g'),
          const SizedBox(height: 4),
          Text(
            '朝: ${byType['breakfast'] ?? 0}  昼: ${byType['lunch'] ?? 0}  夜: ${byType['dinner'] ?? 0}  間食: ${byType['snack'] ?? 0}',
          ),
        ],
      ),
    ),
  );
}
```

### 3.4 デザイントークン (= [DESIGN.md] 遵守)

- 色: Orange (`#FF6B35` / button) + Indigo (`#3D5AFE` / accent) + Dark (`#0A0A0A` / background)
- 文言: 既存 page との文体統一 (= 「本日の」「合計」「メニュー名」)
- emoji: 4 meal type に icon
  - 🌅 朝食 (breakfast)
  - 🌞 昼食 (lunch)
  - 🌙 夜食 (dinner)
  - 🍪 間食 (snack)

---

## 4. データフロー

```
User → [+ 朝食] tap
     → MealLogInputDialog 表示
     → 入力 + 保存 tap
     → supabase.functions.invoke('lifestyle-hub', { action: 'meal_log.add', ...payload })
     → meal_logs INSERT (RLS auth.uid() check)
     → 200 OK
     → _fetchData() 再 invoke
     → meal_log.list + meal_log.summary_today fresh fetch
     → setState() で UI 更新
```

---

## 5. 受け入れ条件 (= Definition of Done)

### 5.1 機能要件 (= Issue #1665 受け入れ条件 4 項目)

- [ ] ログイン済みユーザーが食事ログを追加・一覧表示できる
- [ ] 1 日の概算 kcal と主要栄養素 (P/F/C) の合計が表示される
- [ ] 外部 API 未設定でもローカル入力だけで動作する (= kcal/g 全 NULLABLE)
- [ ] `dart format --set-exit-if-changed` + `flutter analyze` 0 errors / 0 warnings 通過

### 5.2 アーキ + セキュリティ要件 (= 設計判断)

- [ ] `meal_logs` table + RLS 4 policy 全有効化 (= SELECT/INSERT/UPDATE/DELETE = own only)
- [ ] `lifestyle-hub` EF に 4 action 追加 (= `meal_log.add` / `meal_log.list` / `meal_log.summary_today` / `meal_log.delete`)
- [ ] [EF-CAP-50] 遵守 (= EF count 維持 / 新規 EF なし)
- [ ] Admin client 経由の write 禁止 (= [feedback_correction_20260504_schedule_hub_admin_writes] 教訓)
- [ ] 4 number field の NULL 許容確認 (= 「外部 API 未設定でも動作」)
- [ ] `RecipeMealPlannerPage` に 4 tab 反映 (= `length: 3` → `length: 4`)
- [ ] 「食事ログ」 4 button (= 朝/昼/夜/間食) + 入力 dialog + 一覧 + summary section 全実装
- [ ] DESIGN.md tokens 遵守 (= Orange + Indigo + Dark / 独自色なし / emoji icon mapping)

### 5.3 CI + 配布要件

- [ ] `dart format` pass / `flutter analyze` 0
- [ ] minimal-e2e-gate workflow pass
- [ ] PR description に Issue #1665 close note + spec ファイルへのリンク

---

## 6. Codex 振分 5 質問 matrix (= [INSTANCE-ROLES])

| # | 質問 | 答 | 担当 |
|---|------|-----|------|
| Q1 | Architecture / 設計 needed? | YES (= 本 spec で完了 / hand-off) | Win Claude (本 spec) |
| Q2 | UI/UX design? | YES (= 本 spec で完了 / hand-off) | Win Claude (本 spec) |
| Q3 | NotebookLM intake / triage? | NO | — |
| Q4 | AI 大学 / 競合 update? | NO | — |
| Q5 | Mobile UAT / video? | NO | — |
| **Implementation** (migration + EF + Flutter UI 着地) | **NO design → 実装** | **Win Codex** |

→ 設計 = Win Claude / **実装 = Win Codex** (本 hand-off doc)

---

## 7. Win Codex 実装 step (= 推奨)

1. `supabase/migrations/<YYYYMMDDHHMMSS>_create_meal_logs.sql` 作成 (= §2.2 SQL コピー / 命名 [DEVELOPMENT_ACHIEVEMENTS_FORMAT])
2. `supabase/functions/lifestyle-hub/index.ts` に 4 action 追加 (= §2.1 表 / RLS 自動適用 / no admin client)
3. `lib/pages/recipe_meal_planner_page.dart` 編集 (= §2.3 + §3 / 4 tab + 食事ログ tab + dialog + summary)
4. `dart format <abs-path> --set-exit-if-changed` + `flutter analyze` (= [DART-FORMAT])
5. PR 作成: title `feat(meal-log): MVP 食事ログ統合 (#1665)` / body に本 spec link + 受け入れ条件 checklist

---

## 8. 注意事項

- **[NO-SCOPE-CREEP]**: 本 MVP は **食事ログ + summary のみ**。食品 API 連携 / バーコードスキャン / グラフ可視化 / 週次推移 / 健康指標相関は **Phase 2 以降**。
- **DESIGN.md 遵守**: Orange + Indigo dark 以外の色は禁止。
- **`RecipeMealPlannerPage` regression check**: 既存 3 tab (= レシピ/週間プラン/買い物リスト) の動作劣化なし要確認。
- **Mobile 対応**: `RecipeMealPlannerPage` は mobile build にも含まれるため、`dinner_dining` icon が iOS+Android で正常表示されることを smoke 確認。

---

## 9. 4 軸 alignment

- **PHILOSOPHY-22 9/9 ✅** (= mentor + 6 部署 / KPI に記録 / IPO 準備)
- **AI-DEV-23 7/7 ✅** (= [EF-FIRST] / RLS gate / observability via logged_at + summary action)
- **VIBE-30 7/7 ✅** (= MVP scope 厳守 / Phase 2 拡張余地明示)
- **INDIE-29 7/7 ✅** (= shipping 速度: spec 1 doc → Codex 実装 1 PR / 1 week 完結想定)
- **PLATFORM-31 7/7 ✅** (= 既存 hub action 追加 [最優先] / 新 EF なし)

---

## 10. 関連 doc

- [Issue #1665](https://github.com/kanta13jp1/my_web_app/issues/1665)
- [Issue #1269](https://github.com/kanta13jp1/my_web_app/issues/1269) (= parent)
- [docs/DESIGN.md](docs/DESIGN.md)
- [docs/EDGE_FUNCTION_LIST.md](docs/EDGE_FUNCTION_LIST.md)
- [docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md](docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md)
- [memory/feedback_correction_20260504_schedule_hub_admin_writes](memory/feedback_correction_20260504_schedule_hub_admin_writes.md)
