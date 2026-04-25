# Cross-Instance PR: wbs.rebalance_suggest category_filter 追加

**From**: PS#2 S30  
**To**: Win版  
**Priority**: Medium  
**Created**: 2026-04-25

---

## 問題

`wbs.rebalance_suggest(my_instance="ps2")` の top-5 が常に `business-legal` タスクになる。

PS#2 の [DYNAMIC-CLAIM] ルールでは `business-legal` は禁止カテゴリのため、PS#2 が引き取れるタスクが一件も出てこない。

### 症状

```
candidates[0]: business-legal (stale_score=20 "priority=high")
candidates[1]: business-legal (stale_score=20)
candidates[2]: business-legal (stale_score=20)
candidates[3]: business-legal (stale_score=20)
candidates[4]: business-product (stale_score=20)
```

### 根本原因

`stale_score` が `priority=high` → +20 を加点するため、high-priority の business-legal タスクが常に上位に来る。instance ごとの引き取り禁止カテゴリが考慮されていない。

---

## 修正案

### Option A: `allowed_categories` パラメータ追加 (推奨)

```typescript
// tools-hub/index.ts の wbs.rebalance_suggest action
const allowed_categories = body.allowed_categories as string[] | undefined;

// クエリに条件追加
if (allowed_categories && allowed_categories.length > 0) {
  query = query.in('category', allowed_categories);
}
```

呼び出し側:
```bash
curl ... -d '{
  "action":"wbs.rebalance_suggest",
  "my_instance":"ps2",
  "allowed_categories":["marketing","docs","seo","product"]
}'
```

### Option B: `exclude_categories` パラメータ追加

```bash
-d '{"action":"wbs.rebalance_suggest","my_instance":"ps2","exclude_categories":["business-legal","business-finance","ipo"]}'
```

---

## 影響範囲

- `wbs.rebalance_suggest` EF action のみ変更
- [DYNAMIC-CLAIM] rule が実際に機能するようになる
- 他インスタンスへの影響なし (パラメータ未指定時は既存動作を維持)

---

## 関連

- `memory/project_20260425_ps2_s30.md` — S30 発見
- inject-rules.txt `[DYNAMIC-CLAIM]` — PS#2 引き取り可カテゴリ定義
