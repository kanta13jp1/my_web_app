---
title: "Supabaseバッチ処理の26分→0秒最適化 — prev_history_fetchedフラグパターン"
tags: Supabase,PostgreSQL,Python,個人開発,buildinpublic
published: false
---

# Supabaseバッチ処理の26分→0秒最適化

## 問題: 毎回26分かかるバッチ処理

競馬予想バッチで「前走情報取得」ステップが毎回26分かかっていた。原因は**同じ馬の前走情報を毎回再取得**していたこと。

一度取得すれば変わらないデータなのに、なぜ毎回？

## 解決策: フラグカラムで「取得済み」を記録

```sql
-- マイグレーション
ALTER TABLE horse_entries
  ADD COLUMN prev_history_fetched boolean DEFAULT false;
```

Pythonバッチ側:

```python
def fetch_horse_histories(conn, race_id: int) -> None:
    cur = conn.cursor()

    # 未取得の馬のみ対象
    cur.execute("""
        SELECT he.id, he.horse_id
        FROM horse_entries he
        WHERE he.race_id = %s
          AND he.prev_history_fetched = false
    """, (race_id,))
    entries = cur.fetchall()

    for entry_id, horse_id in entries:
        try:
            history = scrape_previous_race(horse_id)  # 外部スクレイピング
            upsert_history(conn, horse_id, history)
        except Exception as e:
            print(f"Horse {horse_id} 404/skip: {e}")
        finally:
            # 成功・失敗問わずフラグを立てる
            cur.execute("""
                UPDATE horse_entries
                SET prev_history_fetched = true
                WHERE id = %s
            """, (entry_id,))
            conn.commit()
```

**ポイント**: 404エラー (馬が存在しない) でもフラグを立てる。次回以降スキップできる。

## 効果

| | 最適化前 | 最適化後 |
|--|---------|---------|
| 初回実行 | 26分 | 26分 (同じ) |
| 2回目以降 | 26分 | **ほぼ0秒** |
| 404馬の再試行 | あり (毎回失敗) | **なし** |

## パターンの応用

このフラグパターンは「一度取得したら変わらないデータ」全般に使える:

```sql
-- 汎用パターン
ALTER TABLE <table>
  ADD COLUMN <field>_fetched boolean DEFAULT false,
  ADD COLUMN <field>_fetched_at timestamptz;
```

条件:
- データが冪等 (同じ入力で同じ結果)
- 再取得が不要 or コストが高い
- 失敗時は後でリトライしたくない

## まとめ

バッチ処理の「毎回全件処理」はよくあるアンチパターン。`_fetched` フラグを1カラム追加するだけで初回以降のコストをゼロにできる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #Python #buildinpublic #個人開発
