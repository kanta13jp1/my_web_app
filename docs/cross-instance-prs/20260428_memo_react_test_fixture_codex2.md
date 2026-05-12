# Cross-Instance PR: memo.react.list/toggle test fixture を smoke_test.py 形式で書き起こし

**作成**: Win版#132 part 54 / 2026-04-28
**依頼先**: **Codex#2** (`.claude/worktrees/instance-codex2` / `codex/codex2-wip`)
**優先度**: MEDIUM (regression 防止)
**推定工数**: 30-45 min / 1 Python file

---

## 判定 5 質問の答え

| Q | 答え |
| --- | --- |
| Q1. 設計判断 / trade-off 検討必要? | **NO** (= 既存 fixture pattern の複製) |
| Q2. cross-instance 調整必要? | **NO** (Win版 part 50 実装に対する後付 test) |
| Q3. 軸 docs 更新必要? | **NO** |
| Q4. docs に残す価値ある判断? | **NO** (test 追加のみ) |
| Q5. NotebookLM 連携要? | **NO** |

→ **全 NO = Codex 適合** (docs/CODEX_WORKFLOW.md §6 routing matrix 適用)

---

## 起票背景

Win版#132 part 50 (commit 45590ce4) で `core-hub` に 2 action 追加:
- `case "memo.react.list"`: memo_reactions テーブルから集計 + ip_hash でユーザー履歴
- `case "memo.react.toggle"`: 既存削除 / 新規 INSERT + counts 返却

production hotfix (404 → recover) として急ぎ landed したが、**regression test が
無い** = 後続 PS#5 等が core-hub を触ると memo.react 系を壊しても気づけない。

→ 解決策: 既存の `scripts/video/_smoke_test.py` (Win版 part 37) と同じ pattern で
synthetic memo_reactions row + ip_hash + reaction を fixture 化し、
**core-hub の 2 action を起動して期待 response を assert** する自走 script を作る。

これは **既存 fixture pattern の複製** = Codex#2 (refactor / pattern 適用 専任) の
典型タスク。

## 既存 pattern (= Codex が複製する template)

### 参考 1: scripts/video/_smoke_test.py
- Win版 part 37 で確立した self-contained pytest 不要 smoke test
- 構造:
  ```python
  def test_<feature>():
      # synthetic fixture
      # subprocess or fetch
      # assert response shape
      # cleanup

  if __name__ == "__main__":
      cases = [("name", test_<feature>)]
      for name, fn in cases:
          try: fn(); print(f"[PASS] {name}")
          except AssertionError as e: print(f"[FAIL] {name}: {e}"); raise SystemExit(1)
  ```

### 参考 2: core-hub 2 action の入出力 contract
Win版#132 part 50 commit 45590ce4 の `supabase/functions/core-hub/index.ts` を読む:

**memo.react.list 入力**:
```json
{"action": "memo.react.list", "memo_id": <int>}
```
**memo.react.list 出力**:
```json
{"reactions": {"👍": N, "❤️": N, ...}, "userReactions": ["👍", ...]}
```

**memo.react.toggle 入力**:
```json
{"action": "memo.react.toggle", "memo_id": <int>, "reaction": "👍"}
```
**memo.react.toggle 出力**:
```json
{"reactions": {...}, "counts": {...}, "userReactions": [...], "added": <bool>}
```

### 参考 3: smoke test の execute path
- ローカル supabase を起動できないので、**HTTP layer は mock** する設計
- `validateBearer` 等 deno 固有 API も mock
- 純粋に "given JSON in → expected JSON out" を Deno 単体実行で test
- もしくは Supabase Cloud の preview branch 経由で fetch する route も検討

## 期待アウトプット

新 file: `supabase/functions/core-hub/_smoke_test.ts`

```typescript
// core-hub action smoke tests — synthetic fixtures, no Supabase server required
//
// Usage: deno test --allow-all supabase/functions/core-hub/_smoke_test.ts
//
// Win版#132 part 54 (codex#2 handoff) — adds regression coverage for the
// memo.react.list / memo.react.toggle actions Win版#132 part 50 added.

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("memo.react.list returns zero counts when no rows exist", () => {
  // synthetic admin client with empty memo_reactions
  // call action via internal handler
  // assert reactions.👍 === 0
});

Deno.test("memo.react.toggle adds new reaction", () => {
  // synthetic admin client with empty memo_reactions
  // call toggle with reaction="👍"
  // assert added === true
  // assert reactions.👍 === 1
});

Deno.test("memo.react.toggle removes existing reaction", () => {
  // synthetic admin client with 1 row (memo_id=1, ip_hash=X, reaction="👍")
  // call toggle with same memo_id + reaction
  // assert added === false
  // assert reactions.👍 === 0
});

Deno.test("memo.react.toggle rejects invalid reaction", async () => {
  // synthetic admin client
  // call toggle with reaction="invalid"
  // assert response.status === 400
});

Deno.test("memo.react.list ignores rows with non-allowlisted reaction", () => {
  // historical rows with reaction outside allowlist
  // assert they don't show up in reactions counts
});
```

ip_hash 計算 (sha256(x-forwarded-for)) は test 内で再現する必要あり。
Codex#2 が deno crypto API で実装する。

## 完了条件

- [ ] `supabase/functions/core-hub/_smoke_test.ts` 新規 (5 test 以上)
- [ ] `deno test --allow-all supabase/functions/core-hub/_smoke_test.ts` exit 0
- [ ] `deno lint --config supabase/functions/deno.json supabase/functions/core-hub/_smoke_test.ts` pass
- [ ] git commit + push origin HEAD:main
- [ ] 起票者 (Win版) が memory に記録 — Codex#2 は memory 触らない

## OPERATIONS_CHARTER 整合

- 改善トリガー #2 (NotebookLM 残すべき判断) は不要 (mechanical test)
- 5 正本層 #1 (Issues/PR 完了判定) = 後続 PR が memo.react 系を壊しても CI で検出

---

*Win版#132 part 54 / 2026-04-28 起票 / Codex routing matrix 初回適用*
