---
title: "Supabase Migrationのベストプラクティス — タイムスタンプ命名・衝突回避・seed分離"
tags: Supabase,PostgreSQL,個人開発,buildinpublic,database
published: true
---

# Supabase Migrationのベストプラクティス

## マイグレーションファイルの命名規則

```text
YYYYMMDDXXXXXX_descriptive_name.sql
例: 20260419120000_add_tags_to_notes.sql
```

**XXXXXX は 6桁の連番** — 同日に複数ファイルを作る場合に衝突を防ぐ:

```text
20260419000000_create_users.sql
20260419010000_create_notes.sql
20260419020000_add_tags_to_notes.sql
```

## よくある衝突パターンと対処法

### 問題: 複数インスタンスが同じタイムスタンプを使う

5インスタンスが同時作業すると `20260419000000_xxx.sql` が重複する。

**対処**: git log で直近のタイムスタンプを確認してインクリメントする:

```bash
ls supabase/migrations/ | tail -5
# 20260419040000_fix_feature_releases_routes.sql
# → 次は 20260419050000_ を使う
```

### 問題: `SQLSTATE 42P10` — UNIQUE制約の列指定ミス

```sql
-- ❌ ON CONFLICT (id) だが id に UNIQUE制約がない
INSERT INTO notes (user_id, title)
ON CONFLICT (id) DO UPDATE SET title = EXCLUDED.title;

-- ✅ UNIQUE制約がある列を指定
INSERT INTO notes (user_id, title)
ON CONFLICT (user_id, slug) DO UPDATE SET title = EXCLUDED.title;
```

`ON CONFLICT` の列は必ず UNIQUE制約 or PRIMARY KEY が必要。

### 問題: テーブル名の混在

```sql
-- ❌ Supabase公式例では 'profiles' だがこのプロジェクトは 'user_profiles'
SELECT is_admin FROM profiles WHERE user_id = auth.uid();

-- ✅ 実際のテーブル名を確認してから書く
SELECT is_admin FROM user_profiles WHERE user_id = auth.uid();
```

## seed ファイルの分離

スキーマ変更と初期データは分けて管理する:

```text
# スキーマ
20260419000000_create_ai_university_content.sql

# データ seed
20260419010000_seed_openai_ai_university.sql
20260419020000_seed_anthropic_ai_university.sql
```

seed ファイルの構造:

```sql
-- supabase/migrations/20260419010000_seed_openai_ai_university.sql
INSERT INTO ai_university_content (provider, category, title, content)
VALUES
  ('openai', 'overview', 'OpenAI Overview', '...'),
  ('openai', 'models', 'GPT-4o, o3...', '...')
ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      updated_at = now();
```

`ON CONFLICT DO UPDATE` で冪等性を保証 — 何度でも安全に再実行できる。

## ローカル vs 本番の sync

```bash
# ローカルで適用確認
supabase db reset

# 本番適用 (GitHub Actions経由)
supabase db push --db-url $PROD_DB_URL
```

本番は `deploy-prod.yml` で自動適用される:

```yaml
- name: Apply migrations
  run: supabase db push --db-url ${{ secrets.SUPABASE_DB_URL }}
```

## 開発実績の記録も migration で

機能追加のたびに seed を作る習慣をつける:

```sql
-- 20260419000000_seed_achievements_session160.sql
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('CS自動化', 'Claude Schedule cs-check実装完了', '2026-04-19')
ON CONFLICT DO NOTHING;
```

Supabase 管理画面から開発実績が確認できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #buildinpublic #個人開発 #database
