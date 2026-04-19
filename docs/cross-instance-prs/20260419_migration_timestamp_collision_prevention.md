# Migration Timestamp Collision 防止 (全インスタンス必須)

**発行**: instance-ps5 S3 (2026-04-19 22:30 JST)
**優先度**: 🔴 HIGH — 本日 #537〜#545 = 計 9件 CI 失敗の根本原因
**対象**: Win版 / PS版#3 / PS版#6 / VSCode版 — migration を作成する全インスタンス

## 問題

複数インスタンスが同日に migration を作成すると、タイムスタンプ (YYYYMMDDHHMMSS) が衝突する。
`supabase db push` は `schema_migrations_pkey` で unique constraint 違反となり CI が fail。

本日の衝突例:
- `20260419220000` — add_ai_feedback_source_guitar vs seed_hyperbolic
- `20260419230000` — seed_anyscale vs seed_achievements_ps6_horse_racing
- `20260419340000` — seed_deepgram vs seed_hyperbolic (renameミスで再衝突)

## 必須対応 (次回 migration 作成前に必ず実施)

```bash
# 最後に使われたタイムスタンプを確認してから次のタイムスタンプを決定
ls supabase/migrations/ | sort | tail -5
# → 最大値 + 10000 以上を使う
```

インスタンス別推奨タイムスタンプ帯 (衝突防止):
| インスタンス | 推奨帯 |
|---|---|
| Win版 | YYYYMMDD**00**XXXX |
| PS版#3 (AI大学) | YYYYMMDD**10**XXXX |
| PS版#6 (競馬/バッチ) | YYYYMMDD**20**XXXX |
| PS版#5 (on-call) | YYYYMMDD**30**XXXX |
| VSCode版 | YYYYMMDD**40**XXXX |

または、常に `ls supabase/migrations/ | sort | tail -1` で最大値確認後に +1 する。

## 完了確認
- [ ] Win版 — 次回 migration 作成時に `ls ... | sort | tail -5` 確認
- [ ] PS版#3 — 同上
- [ ] PS版#6 — 同上
- [ ] 全インスタンス — タイムスタンプ帯の予約制を検討
