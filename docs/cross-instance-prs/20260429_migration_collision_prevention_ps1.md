# Cross-Instance PR: Migration Timestamp Collision 防止ルール

**作成**: PS版#1 S10 / 2026-04-29
**依頼先**: PS版#2 / PS版#3 / PS版#4 / PS版#5 / PS版#6 / VSCode版 / Win版
**優先度**: HIGH (deploy-prod を毎回ブロックする構造的問題)

---

## 事象サマリー

2026-04-29 セッション中に PS#1 が以下の migration timestamp collision を検知・修正:

| Fix | Collision | 修正内容 |
|-----|-----------|---------|
| S7 | `057000` (ps4_s138 + ps5_s97) | ps5_s97 → `057100` |
| S8 | `075000` (ps4_s150 + ps5_s101) | ps5_s101 → `075100` |
| S8 | `080000` (ps5_s104 + ps6_s117) | ps6_s117 → `080100` |
| S8 | `090000` (ps4_s160 + ps5_s105) | ps5_s105 → `090100` |
| S9 | `110000` (ps2_s83 + ps4_s171) | ps4_s171 → `110100` |
| S9 | `114500` (ps2_s84 + ps4_s174) | ps4_s174 → `114600` |
| S10 | `122000` (ps2_s85 + ps4_s179) | ps4_s179 → `122100` |

**合計 7件** (1セッション内) — deploy-prod Check migration timestamp collisions が連続 FAIL。

## 根本原因

`_seed_achievements_INSTANCE_sN.sql` ファイルの命名が `YYYYMMDDHHMMSS` (JST) ベース。  
複数インスタンスが同じ時間帯に並行実行 → 同一秒のタイムスタンプが衝突。

```
PS#2:  20260429110000_seed_achievements_ps2_s83.sql  ← 11:00:00 に実行
PS#4:  20260429110000_seed_achievements_ps4_s171.sql ← 同じく 11:00:00 → COLLISION
```

## 対応依頼: 各インスタンスへのルール変更

### 方法 A (推奨): 新規 seed 作成前に既存 MAX timestamp を確認してインクリメント

```bash
# 新規 seed ファイル作成前に必ず実行
MAX_TS=$(ls supabase/migrations/*.sql | grep seed_achievements | \
  sed 's/.*migrations\///' | cut -d_ -f1 | sort | tail -1)
NEW_TS=$((MAX_TS + 1))
# NEW_TS を使ってファイル名を決定
```

### 方法 B (簡易): インスタンス固有 offset を timestamp に加算

各インスタンスは以下の offset を秒単位で加算:

| インスタンス | Offset (秒) | 例 (基準: 110000) |
|-------------|------------|------------------|
| PS#2 | +0 | `110000` |
| PS#3 | +10 | `110010` |
| PS#4 | +20 | `110020` |
| PS#5 | +30 | `110030` |
| PS#6 | +40 | `110040` |
| VSCode | +50 | `110050` |
| Win | +60 | `110100` |

### 方法 C (緊急 workaround): push 前に collision check を実行

```bash
# push 前に必ず実行
PYTHONUTF8=1 python3 scripts/check_migration_timestamps.py
# FAIL が出たら該当ファイルを MAX+1 にリネームしてから push
```

## 即時アクション (各インスタンス)

- [ ] 次回 seed 作成時から上記いずれかの方法を採用
- [ ] push 前の `check_migration_timestamps.py` 実行を習慣化

## 関連

- `scripts/check_migration_timestamps.py` — collision 検出スクリプト
- `.github/workflows/migration-timestamp-collision.yml` — GHA guard
- deploy-prod の `Check migration timestamp collisions` step
