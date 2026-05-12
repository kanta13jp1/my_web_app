---
title: "Supabase Migrations 上級編 — 本番環境でのゼロダウンタイム・スキーマ変更"
tags: supabase,個人開発,flutter,AI
published: true
---

# Supabase Migrations 上級編 — 本番環境でのゼロダウンタイム・スキーマ変更

本番 PostgreSQL でのスキーマ変更は慎重さが必要です。ロック競合・長時間のテーブルスキャン・ロールバック不能な変更がサービスを止めます。本記事では Supabase の Migration ベストプラクティスをゼロダウンタイム視点で解説します。

## Supabase Migration の基礎

Supabase は `supabase/migrations/` ディレクトリ内の SQL ファイルを順番に実行します。

```
supabase/migrations/
  20260101000000_create_users.sql
  20260102000000_add_profile_fields.sql
  20260103000000_create_posts.sql
```

タイムスタンプが実行順を決めます。1度適用した migration は再実行されません。

```bash
# ローカルで適用
supabase db push

# 本番に適用
supabase db push --db-url postgresql://...
```

## ロックを避けるカラム追加

### ❌ 危険: NOT NULL + DEFAULT なしのカラム追加

```sql
-- テーブル全体をロック + 全行スキャン発生
ALTER TABLE posts ADD COLUMN view_count INTEGER NOT NULL DEFAULT 0;
```

`NOT NULL DEFAULT` を同時に付けると PostgreSQL 12 未満ではテーブル全行書き換えが発生します。

### ✅ 安全: 段階的カラム追加

```sql
-- Step 1: NULL 許可でカラム追加 (瞬時完了)
ALTER TABLE posts ADD COLUMN view_count INTEGER;

-- Step 2: バックグラウンドでデフォルト値を埋める (バッチ処理)
UPDATE posts SET view_count = 0
WHERE view_count IS NULL AND id BETWEEN 1 AND 10000;
-- ... バッチ繰り返し

-- Step 3: NOT NULL 制約追加 (PostgreSQL 15+は NOT VALID で高速化可)
ALTER TABLE posts ALTER COLUMN view_count SET NOT NULL;
ALTER TABLE posts ALTER COLUMN view_count SET DEFAULT 0;
```

PostgreSQL 11+ では `ADD COLUMN ... DEFAULT` は即時完了しますが、NULL 不許可の変更は注意が必要です。

## インデックスのゼロダウンタイム作成

通常の `CREATE INDEX` はテーブルに共有ロックをかけます。

```sql
-- ❌ 書き込みをブロックする (大テーブルでは数分〜数十分)
CREATE INDEX idx_posts_user_id ON posts(user_id);

-- ✅ ゼロダウンタイム (CONCURRENTLY)
CREATE INDEX CONCURRENTLY idx_posts_user_id ON posts(user_id);
```

`CONCURRENTLY` は2倍の時間がかかりますが、書き込みをブロックしません。Supabase migration では必ず使いましょう。

```sql
-- migration ファイル内
-- インデックス作成はトランザクション外で実行が必要
-- Supabase は自動でトランザクションを外す場合があります
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_posts_created_at
  ON posts(created_at DESC);
```

## 外部キー制約の安全な追加

```sql
-- ❌ テーブルロック + 全行チェック
ALTER TABLE comments ADD CONSTRAINT fk_comments_posts
  FOREIGN KEY (post_id) REFERENCES posts(id);

-- ✅ 2ステップで安全に
-- Step 1: NOT VALID で制約追加 (既存行はチェックしない)
ALTER TABLE comments ADD CONSTRAINT fk_comments_posts
  FOREIGN KEY (post_id) REFERENCES posts(id)
  NOT VALID;

-- Step 2: バックグラウンドで既存行を検証 (ShareUpdateExclusiveLock のみ)
ALTER TABLE comments VALIDATE CONSTRAINT fk_comments_posts;
```

## カラムの型変更

型変更はほぼすべてのケースでテーブルロックが発生します。安全な方法は新カラムを使う方法です。

```sql
-- ❌ 直接の型変更はロック
ALTER TABLE events ALTER COLUMN metadata TYPE jsonb USING metadata::jsonb;

-- ✅ 段階的な型変更 (新旧カラム並走)
-- Step 1: 新カラム追加
ALTER TABLE events ADD COLUMN metadata_jsonb jsonb;

-- Step 2: トリガーで同期
CREATE OR REPLACE FUNCTION sync_metadata()
RETURNS TRIGGER AS $$
BEGIN
  NEW.metadata_jsonb = NEW.metadata::jsonb;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sync_metadata_trigger
  BEFORE INSERT OR UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION sync_metadata();

-- Step 3: バックフィル
UPDATE events SET metadata_jsonb = metadata::jsonb WHERE metadata_jsonb IS NULL;

-- Step 4: アプリを新カラムに切り替え後、旧カラムを削除
ALTER TABLE events DROP COLUMN metadata;
ALTER TABLE events RENAME COLUMN metadata_jsonb TO metadata;
```

## ロールバック戦略

Supabase migrations は実行後にロールバックファイルが存在しません。ロールバックは手動 SQL で対応します。

```sql
-- down migration (別ファイルで管理)
-- 20260103000000_create_posts_down.sql
DROP TABLE IF EXISTS posts;
```

実際のプロダクション運用では以下のパターンが安全です。

```sql
-- 本番適用前に必ずステージング環境でテスト
-- 大きな変更は Feature Flag でアプリ側をロールアウト可能にする

-- migration 例: Feature Flag カラム追加
ALTER TABLE users ADD COLUMN IF NOT EXISTS new_dashboard_enabled BOOLEAN DEFAULT FALSE;

-- 問題発生時のロールバック
ALTER TABLE users DROP COLUMN IF EXISTS new_dashboard_enabled;
```

## CI/CD での Migration 自動チェック

```yaml
# .github/workflows/migration-check.yml
name: Migration Safety Check
on: [pull_request]

jobs:
  migration-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install squawk
        run: pip install squawk-cli
      - name: Lint migrations
        run: |
          for f in supabase/migrations/*.sql; do
            echo "Checking $f"
            squawk "$f"
          done
```

[Squawk](https://squawkhq.com/) は以下の危険なパターンを検出します。

- `ADD COLUMN NOT NULL DEFAULT` (旧 PG バージョン)
- インデックス作成の `CONCURRENTLY` 欠如
- `DROP TABLE` / `DROP COLUMN` の確認なし

## Row Level Security (RLS) Migration の注意点

```sql
-- RLS 有効化は即時だが、既存ポリシーのない状態で有効化すると全行アクセス不可になる
-- ✅ 正しい順序: ポリシー定義 → RLS 有効化
CREATE POLICY "Users can read own data"
  ON profiles FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own data"
  ON profiles FOR UPDATE
  USING (auth.uid() = user_id);

-- ポリシー定義後に RLS を有効化
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
```

## パフォーマンス計測

```sql
-- migration 適用時間を見積もる
EXPLAIN (ANALYZE, BUFFERS)
SELECT count(*) FROM posts WHERE view_count IS NULL;

-- テーブルサイズ確認
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
  pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
  pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## まとめ

本番 PostgreSQL の安全な Migration チェックリストです。

| 操作 | 安全な方法 |
|---|---|
| カラム追加 | `NULL`許可で追加 → バックフィル → `NOT NULL`化 |
| インデックス作成 | `CONCURRENTLY` 必須 |
| 外部キー追加 | `NOT VALID` → `VALIDATE CONSTRAINT` |
| 型変更 | 新カラム並走 → 切り替え → 旧削除 |
| RLS 有効化 | ポリシー定義 → `ENABLE ROW LEVEL SECURITY` |

ゼロダウンタイム Migration をマスターすれば、サービスを止めずに継続的にスキーマを進化させられます。

---

*自分株式会社では Flutter + Supabase で日本の21競合SaaSを1つに統合するライフマネジメントアプリを開発しています。開発の舞台裏を発信中 → [@kanta13jp1](https://x.com/kanta13jp1)*
