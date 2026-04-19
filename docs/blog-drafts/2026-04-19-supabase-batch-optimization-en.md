---
title: "Cutting a 26-Minute Supabase Batch Job to Near Zero — The prev_fetched Flag Pattern"
tags: Supabase,PostgreSQL,Python,buildinpublic,webdev
published: false
---

# Cutting a 26-Minute Supabase Batch Job to Near Zero

## The Problem

A horse-racing prediction batch job was taking 26 minutes on every run. The culprit: re-fetching historical race data for every horse on every run — even for horses we'd already fetched data for.

The data doesn't change. Why keep re-fetching?

## The Fix: A Single Boolean Column

```sql
ALTER TABLE horse_entries
  ADD COLUMN prev_history_fetched boolean DEFAULT false;
```

Python batch:

```python
def fetch_horse_histories(conn, race_id: int) -> None:
    cur = conn.cursor()

    # Only fetch unfetched horses
    cur.execute("""
        SELECT he.id, he.horse_id
        FROM horse_entries he
        WHERE he.race_id = %s
          AND he.prev_history_fetched = false
    """, (race_id,))
    entries = cur.fetchall()

    for entry_id, horse_id in entries:
        try:
            history = scrape_previous_race(horse_id)
            upsert_history(conn, horse_id, history)
        except Exception as e:
            print(f"Horse {horse_id} 404/skip: {e}")
        finally:
            # Mark as fetched regardless of success/failure
            cur.execute("""
                UPDATE horse_entries
                SET prev_history_fetched = true
                WHERE id = %s
            """, (entry_id,))
            conn.commit()
```

Key insight: mark as fetched **even on 404 errors**. A horse that doesn't exist won't exist next run either — no point retrying.

## Results

| Run | Before | After |
|-----|--------|-------|
| First run | 26 min | 26 min (same) |
| Second run onward | 26 min | **~0 sec** |
| 404 horses retried | Every run | **Never** |

## Generalizing the Pattern

Any "fetch once, never changes" data benefits from this pattern:

```sql
ALTER TABLE <table>
  ADD COLUMN <field>_fetched boolean DEFAULT false,
  ADD COLUMN <field>_fetched_at timestamptz;
```

Criteria:
- Data is idempotent (same input → same result)
- Re-fetching is expensive or slow
- Failures don't need retries (or you want explicit retry logic)

For data that _does_ need refreshing, add an expiry:

```sql
WHERE NOT prev_history_fetched
   OR prev_history_fetched_at < NOW() - INTERVAL '30 days'
```

## Conclusion

"Process everything every run" is a common batch antipattern. One boolean column makes subsequent runs instant. The cost is a single extra column and one `UPDATE` per row on first fetch.

---
Building in public: https://my-web-app-b67f4.web.app/
#Supabase #PostgreSQL #Python #buildinpublic
