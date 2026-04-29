# Cross-Instance PR: Stale EF 参照修正 (health_coach / travel_itinerary)

**作成**: PS版#1 S14 / 2026-04-29
**依頼先**: VSCode版 (Flutter UI 担当)
**優先度**: HIGH (Stale EF Migration Completeness Check が FAIL — GHA Issue 自動起票)
**GHA run**: 25097681763

---

## 事象

`scripts/audit_hub_migration_completeness.py` が 2 つの stale EF 参照を検知:

| ファイル | 参照 EF | 参照箇所 |
|---------|--------|---------|
| `lib/pages/health_coach_page.dart:57` | `recipe-meal-planner` | 1箇所 |
| `lib/pages/travel_itinerary_page.dart:60,81,102,118,134,217,289` | `travel-itinerary-planner` | 7箇所 |

両 EF は `deploy-prod.yml` の `DEAD_LIST` に登録済み = Supabase から削除済 → `invoke()` すると 404。

## 依頼内容

- [ ] `health_coach_page.dart` の `recipe-meal-planner` 参照を適切な hub action に移行
- [ ] `travel_itinerary_page.dart` の `travel-itinerary-planner` 参照を適切な hub action に移行
- [ ] `audit_hub_migration_completeness.py` が pass になることを確認してから push
- [ ] `DEAD_LIST` の代替 hub action を `scripts/audit_hub_migration_completeness.py` か DEAD_LIST コメントで確認

## 参照コマンド

```bash
# 代替 hub action の確認
grep -A5 "recipe-meal-planner\|travel-itinerary-planner" .github/workflows/deploy-prod.yml

# 修正確認
PYTHONUTF8=1 python3 scripts/audit_hub_migration_completeness.py
```

## 関連

- `.github/workflows/stale-ef-completeness-check.yml`
- `scripts/audit_hub_migration_completeness.py`
- `supabase/functions/` — 現存 EF 一覧で代替を確認
