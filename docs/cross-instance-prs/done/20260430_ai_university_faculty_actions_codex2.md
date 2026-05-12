# Cross-Instance PR: ai-hub に 学部/学科 4 actions 追加

**作成**: Win版#132 part 93 / 2026-04-30
**FROM**: Win版 (User 要望 + schema 設計)
**TO**: Codex#2 (EF / Deno / GHA 補助 territory)
**優先度**: HIGH (= VSCode UI PR の前提)
**期限**: 2026-05-04 (5 日)
**親軸**: AI 大学拡張 + EF-FIRST + EF-CAP-50
**完了**: Codex #1 Windows app / PR TBD / 2026-05-07 — 4 actions + Deno unit coverage

---

## 1. 背景

User 要望: AI 大学 学部/学科 hierarchy.

Win territory done (= phase 1):
- schema migration `20260430020000_create_university_faculties_departments.sql`
- 5 学部 / 22 学科 seed

Codex#2 territory (= phase 6 / 本 PR):
- ai-hub に **学部/学科 4 actions** 追加
- VSCode UI PR の前提 (= UI が EF を呼ぶ)

## 2. 期待する actions (= ai-hub/index.ts に追加)

### 2.1 `university.faculty_list`

**input**: `{}` (= 引数なし)

**output**:
```json
{
  "faculties": [
    {
      "id": "uuid",
      "faculty_code": "ai",
      "name_ja": "AI 学部",
      "name_en": "Faculty of AI",
      "description": "AI モデル...",
      "emoji": "🤖",
      "sort_order": 10,
      "department_count": 7,
      "content_count": 380
    },
    ...
  ]
}
```

= 全 active 学部 list. department_count + content_count を集計済で返す (= UI 表示用).

```sql
SELECT f.id, f.faculty_code, f.name_ja, f.name_en, f.description, f.emoji, f.sort_order,
       (SELECT count(*) FROM university_departments d WHERE d.faculty_id = f.id AND d.is_active = true) AS department_count,
       (SELECT count(*) FROM ai_university_content c WHERE c.faculty_id = f.id AND c.is_active = true) AS content_count
FROM university_faculties f
WHERE f.is_active = true
ORDER BY f.sort_order, f.faculty_code;
```

### 2.2 `university.department_list`

**input**: `{ faculty_code: string }` または `{ faculty_id: uuid }`

**output**:
```json
{
  "faculty": { "id": "...", "faculty_code": "cloud", "name_ja": "クラウド学部", ... },
  "departments": [
    {
      "id": "uuid",
      "department_code": "aws",
      "name_ja": "AWS 学科",
      "name_en": "Department of AWS",
      "description": "Amazon Web Services...",
      "emoji": "🟠",
      "sort_order": 10,
      "provider_count": 7,
      "content_count": 7
    },
    ...
  ]
}
```

```sql
SELECT d.id, d.department_code, d.name_ja, d.name_en, d.description, d.emoji, d.sort_order,
       (SELECT count(DISTINCT provider) FROM ai_university_content c WHERE c.department_id = d.id AND c.is_active = true) AS provider_count,
       (SELECT count(*) FROM ai_university_content c WHERE c.department_id = d.id AND c.is_active = true) AS content_count
FROM university_departments d
WHERE d.faculty_id = (SELECT id FROM university_faculties WHERE faculty_code = $1)
  AND d.is_active = true
ORDER BY d.sort_order, d.department_code;
```

### 2.3 `university.provider_by_department`

**input**: `{ department_code: string, faculty_code: string }` または `{ department_id: uuid }`

**output**:
```json
{
  "department": { ... },
  "providers": [
    { "provider": "aws_ec2", "content_count": 1 },
    { "provider": "aws_s3", "content_count": 1 },
    ...
  ]
}
```

= **既存 provider grid 表示用**. provider 単位 group by.

### 2.4 `university.content_by_faculty`

**input**: `{ faculty_code: string, limit?: number, offset?: number }`

**output**: 既存 `university.content_all` と同形式 / faculty filter 付.

= 学部 home 「最近の更新」セクション用.

## 3. EF カウント影響

= **action 追加のみ / 新規 EF 作成なし** → EF カウント増えない (= Rule [EF-CAP-50] 影響なし).

## 4. 実装場所

`supabase/functions/ai-hub/index.ts` の switch case に追加:

```typescript
case "university.faculty_list": {
  // 上記 SQL を invoke
  const { data, error } = await supabaseAdmin
    .from("university_faculties")
    // ...
  return json({ faculties: data });
}

case "university.department_list": {
  const facultyCode = body.faculty_code as string;
  // ...
}

// 同様に provider_by_department / content_by_faculty
```

## 5. 受入基準

- [ ] 4 actions 実装 + integration test (= `supabase/functions/ai-hub/test/university_faculty.test.ts` 新規 / 既存 ai-hub test 同型)
- [ ] deno lint 0 issues
- [ ] deno test pass
- [ ] action invoke のレスポンス時間 < 500ms (= count 集計遅延 ≤ 0.5s)
- [ ] cross-instance-pr 完了時 `done/` 移動

## 6. VSCode UI PR との連携

VSCode が UI 実装する前提 = 本 PR が **先行マージ必須**. Codex#2 5 日 / VSCode 7 日 の order.

---

*Win版#132 part 93 / 2026-04-30 起票 / ai-hub に 学部/学科 4 actions / Win → Codex#2 lane*
