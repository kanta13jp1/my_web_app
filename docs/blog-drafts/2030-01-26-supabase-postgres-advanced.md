---
title: "Supabase Postgres 上級編 — Partitioning・Full-Text Search・Generated Columns・Triggers"
tags: flutter,dart,個人開発,AI
published: true
---

## はじめに

Supabase の基本的な CRUD に慣れたら、PostgreSQL の上級機能を活用してパフォーマンスと保守性を一気に引き上げられる。本稿ではテーブルパーティショニング、全文検索、generated columns、そして trigger + pg_notify によるリアルタイム通知まで、実運用で役立つパターンを解説する。

---

## 1. テーブルパーティショニング（日付範囲）でログデータ管理

大量ログを 1 テーブルに詰め込むとクエリが遅くなる。日付範囲パーティショニングで古いデータを分離しよう。

```sql
-- 親テーブルをパーティション宣言
CREATE TABLE user_events (
  id          BIGSERIAL,
  user_id     UUID NOT NULL,
  event_type  TEXT NOT NULL,
  payload     JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
) PARTITION BY RANGE (created_at);

-- 月ごとの子テーブルを作成
CREATE TABLE user_events_2026_04
  PARTITION OF user_events
  FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');

CREATE TABLE user_events_2026_05
  PARTITION OF user_events
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- 各パーティションにインデックスを張る（自動継承されない）
CREATE INDEX ON user_events_2026_04 (user_id, created_at DESC);
CREATE INDEX ON user_events_2026_05 (user_id, created_at DESC);
```

クエリは親テーブルに対して実行すれば、PostgreSQL が自動的に対象パーティションだけをスキャンする（パーティションプルーニング）。古い月のパーティションは `DETACH PARTITION` してアーカイブするだけで削除コストがゼロだ。

---

## 2. tsvector + GIN インデックスで日本語全文検索（pg_bigm）

PostgreSQL の標準 FTS は日本語に弱い。`pg_bigm` 拡張でバイグラムインデックスを使う。

```sql
-- pg_bigm 拡張を有効化（Supabase の場合 SQL Editor で実行）
CREATE EXTENSION IF NOT EXISTS pg_bigm;

-- 検索対象カラムに bigm インデックス
CREATE INDEX articles_title_bigm_idx ON articles
  USING gin (title gin_bigm_ops);

CREATE INDEX articles_body_bigm_idx ON articles
  USING gin (body gin_bigm_ops);

-- 検索クエリ
SELECT id, title, ts_rank(to_tsvector('simple', body), query) AS rank
FROM articles,
     to_tsquery('simple', '個人開発 & Flutter') AS query
WHERE title LIKE '%Flutter%'
   OR body LIKE '%個人開発%'
ORDER BY rank DESC
LIMIT 20;
```

実務では `tsvector` カラムを generated column として持たせると更新が自動化できる（次節参照）。

---

## 3. Generated Columns でフロントエンド計算ロジックを DB 側に移す

金額の税込計算や文字列の正規化など、フロントで毎回計算していた処理を DB の generated column に移すと一貫性が保ちやすい。

```sql
CREATE TABLE products (
  id            BIGSERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  price_ex_tax  NUMERIC(10,2) NOT NULL,
  tax_rate      NUMERIC(4,3) NOT NULL DEFAULT 0.10,

  -- STORED generated column: 変更のたびに自動計算
  price_incl_tax NUMERIC(10,2) GENERATED ALWAYS AS
    (ROUND(price_ex_tax * (1 + tax_rate), 2)) STORED,

  -- 全文検索用 tsvector を自動生成
  search_vector  TSVECTOR GENERATED ALWAYS AS
    (to_tsvector('simple', name)) STORED
);

-- search_vector に GIN インデックス
CREATE INDEX products_search_idx ON products USING gin (search_vector);
```

Flutter 側では `price_incl_tax` をそのまま表示するだけでよく、税率変更時もフロントのコード変更が不要になる。

---

## 4. Trigger + pg_notify でリアルタイムイベント通知

Supabase Realtime は内部で `pg_notify` を使っている。自前のビジネスロジック trigger からも同じ仕組みで通知できる。

```sql
-- 注文ステータス変更を通知する trigger
CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status <> OLD.status THEN
    PERFORM pg_notify(
      'order_updates',
      json_build_object(
        'order_id', NEW.id,
        'old_status', OLD.status,
        'new_status', NEW.status,
        'updated_at', NOW()
      )::text
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_trigger
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_status_change();
```

Flutter 側では Supabase Realtime チャンネルを購読してリアルタイムに UI を更新できる。

---

## 5. EXPLAIN ANALYZE でクエリ最適化

遅いクエリを発見したら `EXPLAIN ANALYZE` で実行計画を確認する。

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.id, u.email, COUNT(t.id) AS task_count
FROM users u
LEFT JOIN tasks t ON t.user_id = u.id
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.id, u.email
ORDER BY task_count DESC
LIMIT 50;
```

出力例で注目すべきポイント:

- `Seq Scan` → インデックスが使われていない → `CREATE INDEX` を検討
- `Hash Join` vs `Nested Loop` → 結合方法の確認
- `Buffers: shared hit=X read=Y` → キャッシュヒット率（hit/(hit+read) が高いほど良い）
- `actual rows` vs `estimated rows` の乖離 → `ANALYZE` でテーブル統計を更新

```sql
-- テーブル統計を更新（自動 autovacuum が遅れている場合）
ANALYZE users;
ANALYZE tasks;
```

---

## まとめ

| 機能 | 効果 |
|------|------|
| パーティショニング | 大テーブルの検索高速化・アーカイブ簡素化 |
| pg_bigm | 日本語全文検索の実用化 |
| Generated Column | ビジネスロジックの DB 集約・一貫性確保 |
| Trigger + pg_notify | カスタムイベントのリアルタイム配信 |
| EXPLAIN ANALYZE | ボトルネック特定と最適化 |

Supabase は PostgreSQL の生の力を使えるのが最大の強みだ。フロントエンドの計算をどんどん DB に移譲することで、Flutter 側のコードがシンプルになり、複数クライアント間の一貫性も自然に保たれる。
