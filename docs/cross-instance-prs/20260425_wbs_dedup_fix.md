# Cross-Instance PR: WBS 重複データ修正

**From**: PS#2 S29  
**To**: Win版  
**Priority**: High  
**Created**: 2026-04-25

---

## 問題

`wbs.priority_for_instance` / `wbs.rebalance_suggest` が不正確なデータを返している。

### 症状

```
codex: 451 open tasks  (実態: ~30件程度と推定)
user:  154 open tasks  (「司法書士・税理士契約」が9件以上の重複)
ps2:    34 open tasks  (「法人形態の決定」重複あり)
```

### 根本原因

`supabase/migrations/20260425203000_*.sql` (推定) の cartesian INSERT:

```sql
-- 問題のパターン (推定)
INSERT INTO wbs_tasks (title, category, instance, ...)
SELECT title, category, unnest(ARRAY['codex','user','ps2',...]), ...
FROM source_tasks;
-- → 同一タスクが全インスタンス分だけ生成される
```

### 確認方法

```sql
SELECT title, COUNT(*) as cnt, array_agg(id) as ids
FROM wbs_tasks
WHERE status != 'completed'
GROUP BY title, instance
HAVING COUNT(*) > 1
ORDER BY cnt DESC
LIMIT 20;
```

---

## 修正案 (Win版が判断)

### Option A: 重複削除 (推奨)

```sql
-- 同一 (title, instance) の最古の行を残し、後から追加された重複を削除
DELETE FROM wbs_tasks
WHERE id IN (
  SELECT id FROM (
    SELECT id,
      ROW_NUMBER() OVER (
        PARTITION BY title, instance, category
        ORDER BY created_at ASC
      ) as rn
    FROM wbs_tasks
    WHERE status != 'completed'
  ) ranked
  WHERE rn > 1
);
```

### Option B: 移行済みマーク

重複タスクを `status='cancelled'` に変更 (削除ではなく)。

---

## 影響範囲

- `wbs.rebalance_suggest` の rescue_score が正常化
- `wbs.priority_for_instance` の top_5 が真に実行可能なタスクになる
- workload distribution が実態を反映するようになる

---

## 副次発見: PS#2 WBS 誤割当 (S24 既報)

PS#2 の top tasks が全て `business-legal` (法人形態決定/司法書士契約) になっている。  
これは PS#2 = T-1 dispatch 専任 なのに business-legal タスクが誤割当されている。

修正: `instance='ps2'` の `business-legal` タスクを `instance='win'` または `instance='user'` に再割当。

---

## 関連

- `memory/project_20260425_ps2_s24.md` — WBS ps2 誤割当 (S24 初報)
- inject-rules.txt `[WBS-DEDUP]` rule 追加済み (PS#2 S29)
