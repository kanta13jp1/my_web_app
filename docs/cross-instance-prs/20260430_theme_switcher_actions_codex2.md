# Cross-Instance PR: ai-hub に theme 関連 3 actions 追加

**作成**: Win版#132 part 100 / 2026-04-30
**FROM**: Win版 (User 要望 + schema 設計)
**TO**: Codex#2 (EF / Deno / GHA territory)
**優先度**: HIGH (= VSCode UI PR の前提)
**期限**: 2026-05-04 (5 日)
**親軸**: テーマ切り替え機能 + EF-FIRST + EF-CAP-50

---

## 1. 背景

User 要望: テーマ切り替え機能.

Win territory done (= phase 1):
- schema migration `20260430080000_create_app_themes.sql`
- 10 theme seed (= app_themes table)
- user_theme_preferences table (= RLS 自身のみ)

Codex#2 territory (= phase 3 / 本 PR):
- ai-hub に **theme 3 actions 追加**
- VSCode UI PR (= phase 2) の前提

## 2. 期待する actions (= ai-hub/index.ts に追加)

### 2.1 `app.theme.list`

**input**: `{}` (= 引数なし)

**output**:
```json
{
  "themes": [
    {
      "id": "uuid",
      "theme_code": "dark_ai",
      "name_ja": "自分株式会社 ダーク",
      "name_en": "Jibun Inc Dark",
      "description": "...",
      "emoji": "🌃",
      "brightness": "dark",
      "primary_color": "#FF6B35",
      "accent_color": "#3949AB",
      "background_color": "#0A0A0A",
      "surface_color": "#1A1A1A",
      "text_color": "#FAFAFA",
      "font_family_ja": "Noto Sans JP",
      "font_family_en": "Inter",
      "border_radius": 8,
      "letter_spacing": 0,
      "line_height": 1.7,
      "preview_image_url": null,
      "reference_url": "docs/DESIGN.md",
      "sort_order": 10
    },
    ...
  ]
}
```

```sql
SELECT * FROM app_themes
WHERE is_active = true
ORDER BY sort_order, theme_code;
```

= 全 active theme catalog 取得. anon でも実行可能 (= RLS select_all).

### 2.2 `app.theme.get_preference`

**input**: `{}` (= auth.uid() 使用)

**output**:
```json
{
  "theme_id": "uuid",
  "theme_code": "minimal_mono",
  "applied_at": "2026-04-30T..."
}
```

実装:
```ts
const { data: { user } } = await supabaseClient.auth.getUser();
if (!user) return json({ theme_code: null }, 200); // 未認証 = client 側 fallback

const { data, error } = await supabaseAdmin
  .from('user_theme_preferences')
  .select('theme_id, applied_at, app_themes!inner(theme_code)')
  .eq('user_id', user.id)
  .maybeSingle();

return json({
  theme_id: data?.theme_id ?? null,
  theme_code: data?.app_themes?.theme_code ?? null,
  applied_at: data?.applied_at ?? null,
}, 200);
```

### 2.3 `app.theme.set_preference`

**input**:
```json
{ "theme_code": "minimal_mono" }
```

**output**:
```json
{ "ok": true, "theme_code": "minimal_mono", "applied_at": "..." }
```

実装:
```ts
const { data: { user } } = await supabaseClient.auth.getUser();
if (!user) return json({ error: 'unauthenticated' }, 401);

const themeCode = (body as any).theme_code as string;
if (!themeCode) return json({ error: 'theme_code required' }, 400);

// theme 存在確認
const { data: theme, error: themeErr } = await supabaseAdmin
  .from('app_themes')
  .select('id, theme_code')
  .eq('theme_code', themeCode)
  .eq('is_active', true)
  .maybeSingle();
if (themeErr || !theme) return json({ error: 'theme not found' }, 404);

// upsert (= 1 user 1 theme)
const { data, error } = await supabaseAdmin
  .from('user_theme_preferences')
  .upsert({
    user_id: user.id,
    theme_id: theme.id,
    applied_at: new Date().toISOString(),
  }, { onConflict: 'user_id' })
  .select('theme_id, applied_at')
  .single();

return json({ ok: true, theme_code: themeCode, applied_at: data?.applied_at }, 200);
```

## 3. EF カウント影響

= **action 追加のみ / 新規 EF 作成なし** → EF カウント増えない (= Rule [EF-CAP-50] 影響なし).

## 4. 受入基準

- [ ] 3 actions 実装 + integration test (`supabase/functions/ai-hub/test/theme.test.ts` 新規)
- [ ] anon (= unauthenticated) でも `app.theme.list` 実行可能
- [ ] `app.theme.get_preference` / `set_preference` は auth 必須
- [ ] deno lint 0 issues
- [ ] deno test pass
- [ ] レスポンス時間 < 300ms
- [ ] cross-instance-pr 完了時 `done/` 移動

## 5. VSCode UI PR との連携

VSCode UI 実装 (= phase 2 / 別 PR) は本 PR の **先行マージ必須**.

順序: Codex#2 5 日 (= 5/4) → VSCode 7 日 (= 5/7).

---

*Win版#132 part 100 / 2026-04-30 起票 / テーマ切り替え EF actions / Win → Codex#2 lane*
