# cross-instance-pr: AI大学 公民モジュール MVP (civics 学部 + 教材 seed)

- **宛先**: L2 = VSCode + Codex (実装/SQL lane)
- **起票**: L3 = VSCode + Claude Code (Win Claude / part 240e / 2026-06-03)
- **優先度**: medium
- **設計元**: [`docs/AI_UNIVERSITY_CIVICS_MODULE.md`](../AI_UNIVERSITY_CIVICS_MODULE.md) (kokkaimap.jp 相当を AI大学 civics 学部として / user 依頼)
- **pattern**: Architect-Implementer ③ (設計=L3 / 適用=L2)

## 背景

user 依頼 = kokkaimap.jp (国会議員マップ) 相当機能の取り込み → AI大学の **civics 学部 (政治・選挙リテラシー)** として教育コンテンツ先行で実装。**Phase 1+2 (MVP) のみ**が本 handoff。Phase 3 (地図UI) / Phase 4 (国会会議録 live同期) は別 Issue + 中立性ゲート (spec §3-4 参照)。

データ駆動階層 (学部→学科→content) なので **Flutter 変更不要**で AI大学に学部が出現しドリルダウン可能になる。スキーマ確認済: `university_faculties` (faculty_code UNIQUE NOT NULL), `university_departments` (UNIQUE(faculty_id,department_code)), `ai_university_content` (provider/category/title/content NOT NULL + faculty_id/department_id nullable)。

## 依頼内容 (migration 1 本 author + 適用)

ファイル名: `supabase/migrations/$(date +%Y%m%d%H%M%S)_seed_civics_faculty_content.sql` ([命名規約](../DEVELOPMENT_ACHIEVEMENTS_FORMAT.md))。additive + idempotent。下記 SQL をベースに使用:

```sql
-- AI大学 civics 学部 (政治・選挙リテラシー) + 4 学科 + 教育コンテンツ seed
-- 設計: Win Claude part 240e / docs/AI_UNIVERSITY_CIVICS_MODULE.md / 適用: Win Codex (L2)
-- 中立性: 全政党等価・出典必須・議員評点なし ([AI-CHARACTER-24])

-- 1) civics 学部
INSERT INTO university_faculties (faculty_code, name_ja, name_en, description, emoji, sort_order, is_active)
VALUES ('civics', '政治・選挙リテラシー学部', 'Faculty of Civics & Electoral Literacy',
        '国会の仕組み・議員・政策・選挙制度を中立的に学ぶ (kokkaimap.jp モデルの教育版)', '🏛️', 55, true)
ON CONFLICT (faculty_code) DO NOTHING;

-- 2) 4 学科
INSERT INTO university_departments (faculty_id, department_code, name_ja, name_en, description, emoji, sort_order, is_active)
SELECT f.id, d.department_code, d.name_ja, d.name_en, d.description, d.emoji, d.sort_order, true
FROM university_faculties f
CROSS JOIN (VALUES
  ('diet_structure', '国会の仕組み学科', 'Diet Structure',  '二院制・法案成立過程・委員会の役割', '🏛️', 10),
  ('diet_members',   '国会議員学科',     'Diet Members',     '衆参議員・会派・選挙区の調べ方',     '👥', 20),
  ('policy_themes',  '政策テーマ学科',   'Policy Themes',    '物価・教育・環境などテーマ別の論点', '📋', 30),
  ('election',       '選挙制度学科',     'Electoral System', '選挙の仕組み・投票・一票の価値',     '🗳️', 40)
) AS d(department_code, name_ja, name_en, description, emoji, sort_order)
WHERE f.faculty_code = 'civics'
ON CONFLICT (faculty_id, department_code) DO NOTHING;

-- 3) 教育コンテンツ seed (出典付き・中立 / provider='civics_literacy')
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active, faculty_id, department_id)
SELECT 'civics_literacy', c.category, c.title, c.content, c.source_url, now()::date, c.sort_order, true, f.id, d.id
FROM university_faculties f
JOIN university_departments d ON d.faculty_id = f.id
CROSS JOIN (VALUES
  ('diet_structure','overview','国会の二院制と法案成立の流れ',
   '日本の国会は衆議院と参議院からなる二院制です。法律案は委員会審査→本会議議決を経て、両院で可決されると成立します。衆議院の優越などの仕組みを公式サイトで確認しましょう。出典: 衆議院・参議院 公式。','https://www.shugiin.go.jp/',10),
  ('diet_members','overview','国会議員の調べ方 (公式データの読み方)',
   '議員の所属会派・選挙区・任期は衆参の公式議員一覧で確認できます。発言は国会会議録検索システムで検索可能です。特定議員の評価ではなく、一次情報の確認方法を身につけましょう。出典: 国会会議録検索システム。','https://kokkai.ndl.go.jp/',10),
  ('policy_themes','overview','政策テーマから国会を読む',
   '物価・教育・環境など関心テーマで会議録を横断検索すると、各党の論点を中立に比較できます。賛否どちらも一次情報で確認することが重要です。出典: 国会会議録検索システム。','https://kokkai.ndl.go.jp/',10),
  ('election','overview','選挙制度の基礎 (小選挙区比例代表並立制)',
   '衆議院は小選挙区比例代表並立制、参議院は選挙区+比例代表です。一票の価値や投票方法の基礎を総務省の解説で学べます。出典: 総務省 選挙。','https://www.soumu.go.jp/senkyo/senkyo_s/',10)
) AS c(dept_code, category, title, content, source_url, sort_order)
WHERE f.faculty_code = 'civics' AND d.department_code = c.dept_code
  AND NOT EXISTS (SELECT 1 FROM ai_university_content x WHERE x.provider = 'civics_literacy' AND x.title = c.title);
```

## 受け入れ条件

1. `supabase db push` 成功 (additive / 既存破壊なし)。
2. AI大学 `/ai-university-faculty` に「政治・選挙リテラシー学部」が表示され、4 学科 → 教材へドリルダウンできる (Flutter 変更不要)。
3. 再適用 idempotent (重複 insert なし)。
4. 全コンテンツに出典 URL あり・特定政党/議員の評点や推奨を含まない ([AI-CHARACTER-24] 中立性)。

## 備考 / スコープ外

- 教材は必要に応じ Codex が拡充可 (中立・出典必須・[REAL-DATA])。
- Phase 3 (kokkaimap風 地図UI / 郵便番号「あなたの選挙区」/ AI要約表示 via `ai-hub` summarize.text) と Phase 4 (国会会議録 API live 同期 / rate-limit 数秒間隔 + キャッシュ) は **本 handoff に含めない**。中立性ポリシー + user GO 後に別 Issue。
- 完了時: 本 file を `docs/cross-instance-prs/done/` へ移動。
