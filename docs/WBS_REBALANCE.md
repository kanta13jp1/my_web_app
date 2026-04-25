# WBS タスク動的再分担 (Rebalance) 設計

**策定**: 2026-04-25 (Win版#132 part 17)
**契機**: ユーザー要請「instance 毎にタスク量に偏りがある / 担当作業ない instance が発生 / 各セッションで役割見直し / 滞留タスクを自担当に変更する臨機応変」

---

## 1. 要件分解

| # | 要件 | 実装手段 |
|---|------|---------|
| R1 | session-start で自 instance タスク 0 件を検知 | 既存 `wbs.priority_for_instance` の戻り値 length 判定 |
| R2 | 他 instance の滞留タスク候補リスト | 新 `wbs.rebalance_suggest` action |
| R3 | 自担当に変更 (owner_instance + instance 両方更新) | 新 `wbs.claim_task` action |
| R4 | 監査 / 戻し可能性 | `wbs_rebalance_log` テーブル |

---

## 2. アーキテクチャ

### Session-start flow (改善版)

```
[my_instance] session 開始
   ↓
1. wbs.priority_for_instance(instance=my_instance)
   ├ 件数 ≥ 1 → そのまま着手 (既存挙動)
   └ 件数 = 0 → rebalance.suggest 自動 call
       ↓
2. wbs.rebalance_suggest(my_instance)
   返却: 他 instance の滞留 task 候補 5 件 (stale_score 順)
       ↓
3. AI / user が候補から 1 件選択
       ↓
4. wbs.claim_task(task_id, my_instance, reason)
   - 旧 instance / owner_instance を rebalance log に記録
   - instance + owner_instance を my_instance に更新
   - status を in_progress に
       ↓
5. 通常通り task 着手
```

### Stale 判定 (rebalance 候補スコアリング)

`stale_score` (高い = 緊急で rebalance 推奨):

```python
score = 0
# 1. 期限ペナルティ (deadline 近い / 過ぎている)
if end_date is past:        score += 50  # 大幅遅延
elif end_date < NOW + 3d:   score += 30  # 期限間近
elif end_date < NOW + 7d:   score += 15

# 2. 進捗停滞ペナルティ (last update が古い)
hours_since_update = (NOW - updated_at) / 3600
if hours_since_update > 168: score += 30  # 7 日停滞
elif hours_since_update > 72: score += 20 # 3 日停滞
elif hours_since_update > 24: score += 10 # 1 日停滞

# 3. progress half-way ペナルティ (50-90% で stuck = 最も orphan しやすい)
if 50 <= progress < 90 and hours_since_update > 48: score += 25

# 4. priority bonus
if priority == 'high':   score += 20
elif priority == 'medium': score += 10

# 5. 既に rebalance 済みは下げる (loop 防止)
if last_rebalanced_at and last_rebalanced_at > NOW - 7d:
    score -= 30
```

---

## 3. テーブル / カラム設計

### `wbs_rebalance_log` (新設)

```sql
CREATE TABLE public.wbs_rebalance_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id         uuid REFERENCES public.wbs_tasks(id) ON DELETE CASCADE,
  from_instance   text NOT NULL,          -- 'win' / 'ps3' / 等
  to_instance     text NOT NULL,
  from_owner      text,                   -- owner_instance 旧値
  to_owner        text,                   -- owner_instance 新値
  reason          text,                   -- 'auto_idle_session' / 'manual_review' / 'ai_load_balance'
  stale_score     int,                    -- claim 時点のスコア
  triggered_by    text,                   -- 'session-start' / 'user' / 'cron'
  metadata        jsonb DEFAULT '{}'::jsonb,
  rebalanced_at   timestamptz DEFAULT now()
);

CREATE INDEX idx_wbs_rebalance_log_task ON public.wbs_rebalance_log (task_id, rebalanced_at DESC);
CREATE INDEX idx_wbs_rebalance_log_to_instance ON public.wbs_rebalance_log (to_instance, rebalanced_at DESC);
```

### `wbs_tasks` 拡張カラム

```sql
ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS last_rebalanced_at timestamptz,
  ADD COLUMN IF NOT EXISTS rebalance_count int DEFAULT 0;
```

- `last_rebalanced_at`: 直近 rebalance 時刻 (loop 防止)
- `rebalance_count`: 累計 rebalance 回数 (KPI)

---

## 4. EF Action 設計

### `tools-hub:wbs.rebalance_suggest`

**input**:
```json
{ "action": "wbs.rebalance_suggest", "my_instance": "win", "limit": 5 }
```

**flow**:
1. 自 instance の active task 数 fetch
2. 他 instance の task を stale_score 計算
3. score 高い順 5 件返却

**output**:
```json
{
  "success": true,
  "my_active_count": 0,
  "candidates": [
    {
      "id": "uuid",
      "title": "...",
      "current_instance": "ps3",
      "current_owner": "ps3",
      "category": "business-marketing",
      "progress": 60,
      "end_date": "2026-05-15",
      "updated_at": "2026-04-22T10:00:00Z",
      "stale_score": 75,
      "stale_reasons": ["期限間近 (3 日)", "進捗停滞 (3 日)", "half-way 50-90%"]
    }
  ]
}
```

### `tools-hub:wbs.claim_task`

**input**:
```json
{
  "action": "wbs.claim_task",
  "task_id": "uuid",
  "my_instance": "win",
  "reason": "auto_idle_session",
  "triggered_by": "session-start"
}
```

**flow**:
1. task 取得 → 旧 instance / owner_instance を記録
2. wbs_tasks.instance + owner_instance を my_instance に UPDATE
3. status を in_progress に (blocked/pending → in_progress)
4. last_rebalanced_at = NOW / rebalance_count++
5. wbs_rebalance_log に INSERT
6. **重要**: status='completed' の task は claim 不可 (404)

**guard**:
- 同一 task が直近 7 日以内に既に rebalance 済 → 拒否 (loop 防止)
- 自 instance が既に owner → no-op

---

## 5. 抑制ルール

### 5-1. Rebalance 上限
- 1 session で claim 可能な task = **最大 2 件** (詰込防止)
- 1 task は 7 日以内に再 rebalance 不可

### 5-2. 不可 task
- `status='completed'` (履歴改変防止)
- `category='business-ipo'` の最終 6 task (CEO 専決事項 / Win 固定)
- `priority='high' AND end_date < NOW() + 1d` (期限直前 → 既存担当に集中)

### 5-3. PS#1 / PS#2 / PS#5 の専任タスク保護
- `category LIKE 'rule17-%'` → PS#1 固定 (Rule17 WF health 専任)
- `category LIKE 'blog-%' OR title LIKE '%T-1%'` → PS#2 固定 (T-1 dispatch 専任)
- `severity='urgent' AND category='bug'` → PS#5 固定 (on-call)

---

## 6. KPI

`wbs_rebalance_log` から:
- 月次 rebalance 回数 (instance 別)
- 平均 claim → completed までの時間 (vs 元担当が完了する場合の比較)
- rebalance 後 churn 率 (再 rebalance / 完了 / 失敗)

---

## 7. Philosophy 9/9 ✅

1. **CEO 感** ✅ — 動的再分担で CEO 視点の load balancing
2. **ミッション駆動** ✅ — idle instance 解消で開発速度 up
3. **優しい mentor** ✅ — 「やること無い」instance に積極的支援
4. **6 部署バランス** ✅ — 全 instance フル稼働 = 部署バランス
5. **商品=ユーザー価値** ✅ — 開発速度 = ユーザー価値早期到達
6. **資本=時間** ✅ — instance 時間の無駄消去
7. **資産負債 BS** ✅ — DB row 増加 microbe
8. **KPI=昨日の自分** ✅ — instance 別稼働率 KPI
9. **ゴール=IPO** ✅ — 開発加速 = IPO 早期化

---

## 8. AI-DEV 7/7 ✅

1. **Auth** ✅ — service_role / 既存 admin 経由
2. **Deny-by-default** ✅ — invalid instance / completed task は reject
3. **trace_id** ✅ — wbs_rebalance_log.metadata に session_id 記録
4. **Cost CB** ✅ — AI 不使用 (純 SQL ロジック / コスト 0)
5. **Team memory** ✅ — wbs_rebalance_log = 完全な audit
6. **Checkpoint+retry** ✅ — claim 失敗時は前 owner で継続
7. **Quality gate** ✅ — 抑制ルール (5-2 / 5-3) + 上限 (5-1)

---

## 9. 実装計画 (3 Phase)

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | wbs_rebalance_log + tools-hub 2 actions + wbs_tasks 拡張 | Win | 2026-04-25 |
| 2 | session-start hook (`[WBS-SYNC]` rule 改善 / 0 件で auto-suggest) | PS#1 | 2026-04-30 |
| 3 | KPI dashboard (admin/instance-load) | VSCode | 2026-05-15 |

---

## 10. 改訂履歴

- **2026-04-25 (Win版#132 part 17)**: 初版作成 + Phase 1 実装。
