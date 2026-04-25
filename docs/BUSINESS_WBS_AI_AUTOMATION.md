# 事業化 WBS + AI 自動レビュー/分解 設計

**策定**: 2026-04-25 (Win版#132 part 11)
**契機**: ユーザー要請「事業化に必要なタスクを WBS化 + ガントチャート + AI レビュー gate + Stale 自動分解」
**前提**: 既存 `wbs_tasks` テーブル + `project-gantt` page + `tools-hub:wbs.*` actions

---

## 1. 要件分解

| # | 要件 | 実装手段 |
|---|------|---------|
| R1 | 事業化に必要なタスクを WBS化 | `wbs_tasks` に `category='business'` で 50+ task seed |
| R2 | ガントチャートで可視化 | 既存 `project-gantt` page で表示 (start_date / end_date / milestone_code) |
| R3 | AI レビュー完了で次タスクへ進行 | `ai_review_status` カラム + `wbs-ai-review.yml` GHA cron |
| R4 | 1 日進捗 0 で AI 自動細分化 | `wbs-stale-subdivide.yml` GHA cron + AI breakdown → wbs.add_task |

→ **既存基盤を最大活用 / 拡張 3 軸 (schema + 2 GHA cron)**。

---

## 2. アーキテクチャ

### 2-1. wbs_tasks 拡張カラム (本 commit Phase 1)

```sql
ALTER TABLE public.wbs_tasks
  ADD COLUMN IF NOT EXISTS parent_task_id uuid REFERENCES public.wbs_tasks(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS ai_review_status text DEFAULT 'pending',
    -- 'pending' / 'requested' / 'approved' / 'rejected' / 'manual_override'
  ADD COLUMN IF NOT EXISTS ai_review_notes text,
  ADD COLUMN IF NOT EXISTS ai_reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS depends_on uuid[] DEFAULT ARRAY[]::uuid[],
    -- 前提タスク UUID 配列 (全 approved になるまで unblock しない)
  ADD COLUMN IF NOT EXISTS auto_subdivided_at timestamptz,
    -- 最後に AI subdivide された時刻 (重複分解防止)
  ADD COLUMN IF NOT EXISTS stale_threshold_hours int DEFAULT 24;
    -- task ごとに変更可 (基本 24h / 大規模タスクは 168h 等)
```

### 2-2. AI Review フロー (R3)

```
User: wbs.update_progress(progress=100) で task 完了
   ↓
trigger: ai_review_status を 'pending' → 'requested' に自動変更
   ↓
GHA cron `wbs-ai-review.yml` (1h 毎):
  - ai_review_status='requested' の task を fetch
  - 各 task の title/description/progress/category を Gemini Flash に渡す
  - AI が以下を判定:
    * 完了基準 (acceptance criteria) を満たしているか
    * 次工程に渡せる品質か
    * 関連タスクへの影響を確認
  - 結果:
    * approved → status='completed' / depends_on で参照する task を unblock
    * rejected → status='in_progress' に戻す + ai_review_notes に理由
   ↓
unblock された task: status='pending' → 'in_progress' (人間が pickup)
```

#### AI Review Prompt 例

```
あなたは自分株式会社のシニアプロジェクトマネージャーです。
以下の WBS タスクが完了報告されました。レビューしてください。

## タスク
- title: {title}
- description: {description}
- category: {category}
- progress: {progress}%
- start_date / end_date: {start_date} / {end_date}

## 評価軸
1. タスクの完了基準を明示できるか?
2. 関連タスク (parent_task_id / depends_on) に矛盾なく contributes しているか?
3. 品質 / 規模感は妥当か?

## 出力 (JSON)
{
  "decision": "approved" | "rejected",
  "score": 0-100,
  "notes": "短い理由 (200 字以内)",
  "next_actions": ["unblock すべき task の hint"]
}
```

### 2-3. Stale 自動分解フロー (R4)

```
GHA cron `wbs-stale-subdivide.yml` (毎朝 09:00 JST):
  - 以下条件の task を fetch:
    * status='in_progress'
    * progress < 100
    * updated_at < NOW() - (stale_threshold_hours hours)
    * auto_subdivided_at IS NULL OR auto_subdivided_at < NOW() - INTERVAL '7 days'
      (= 7日以内に既に分解されたものは再分解しない)
  - 各 stale task を AI (Gemini Flash) に渡す
  - AI が「より小さい 3-7 sub-task」に breakdown:
    * 各 sub-task は 1-3 日で完了可能な粒度
    * 元 task = parent / sub-task = child (parent_task_id でリンク)
  - wbs.add_task で sub-task を投入
  - 元 task の auto_subdivided_at = NOW()
  - Slack `#jibun-quota` に通知 (動きのない task が分解されたよ)
```

#### Subdivide Prompt 例

```
あなたは自分株式会社のシニアプロジェクトマネージャーです。
以下の WBS タスクが 24 時間進捗していません。
理由を推定し、より小さい 3-7 個の sub-task に分解してください。

## 元タスク
- title: {title}
- description: {description}
- category: {category}
- 期限: {end_date}

## 分解の方針
- 各 sub-task は 1-3 日で完了可能な粒度
- 詰まりやすそうな箇所を unblocker から並べる
- 「次の 1 アクション」が明確になる文言

## 出力 (JSON)
{
  "stall_reason": "なぜ詰まっているか推定 (150 字)",
  "sub_tasks": [
    {"title": "...", "description": "...", "estimated_days": 1-3, "priority": "high|medium|low"},
    ...
  ]
}
```

### 2-4. depends_on の使い方

```sql
-- 例: B2「商標出願」は B1「法人設立」完了後に開始
INSERT INTO wbs_tasks (..., depends_on)
VALUES ('B2 商標出願', ..., ARRAY['<B1 のUUID>']::uuid[]);
```

GHA cron が unblock 時:
```sql
UPDATE wbs_tasks
SET status = 'in_progress'
WHERE status = 'pending'
  AND id IN (
    SELECT id FROM wbs_tasks
    WHERE depends_on != ARRAY[]::uuid[]
      AND NOT EXISTS (
        SELECT 1 FROM unnest(depends_on) dep_id
        WHERE dep_id NOT IN (SELECT id FROM wbs_tasks WHERE status='completed')
      )
  );
```

---

## 3. 事業化タスク seed (Phase 1)

### 3-1. カテゴリ構成 (8 大領域 / IPO まで)

| Category | icon | 範囲 | task 数目安 |
|----------|------|------|-----------|
| `business-legal` | ⚖️ | 法人設立 / 商標 / 利用規約 / 契約 / コンプラ | 8 |
| `business-finance` | 💰 | 資金調達 / 銀行口座 / 会計税務 / 監査 | 8 |
| `business-product` | 🚀 | MVP / Beta → GA / pricing | 8 |
| `business-marketing` | 📢 | LP / SEO / SNS / paid / PR | 8 |
| `business-sales` | 🤝 | B2B 営業 / CS / 契約締結 | 6 |
| `business-hr` | 👥 | 採用 / 評価制度 / 福利厚生 | 6 |
| `business-ops` | 🏢 | オフィス / 機材 / セキュリティ | 4 |
| `business-ipo` | 📈 | 内部統制 / 監査法人 / 主幹事 / 上場審査 | 6 |

→ **合計 54 task** (Phase 1 seed)

### 3-2. 主要マイルストーン (新規 milestone)

| code | name | target_date | goal_users |
|------|------|-------------|-----------|
| `legal-setup` | 法人設立完了 | 2026-09-30 | — |
| `mvp-launch` | MVP 一般公開 | 2026-Q3 | 1,000 |
| `seed-round` | Seed 調達完了 | 2026-12-31 | — |
| `paying-100` | 有料 100 顧客 | 2027-03-31 | 100 paying |
| `series-a` | Series A 完了 | 2027-12-31 | — |
| `audit-ready` | 監査対応完了 | 2028-09-30 | — |
| `ipo-listed` | IPO 上場 | 2029-12-31 | — |

---

## 4. 実装計画 (4 Phase)

| Phase | 内容 | 担当 | 期日 |
|-------|------|------|------|
| **1 (本 commit)** | schema 拡張 + 54 task + 7 milestone seed | Win | 2026-04-25 |
| 2 | `wbs-ai-review.yml` GHA cron (Gemini Flash) | Win | 2026-05-01 |
| 3 | `wbs-stale-subdivide.yml` GHA cron | Win | 2026-05-05 |
| 4 | project-gantt page UI 拡張 (AI review badge / sub-task indent) | VSCode | 2026-05-10 |

---

## 5. AI コスト見積

### Phase 2: AI Review
- 1 日完了 task 数想定: 5 task
- 1 task = 1K input token / 200 output token = ~1.5K total
- Gemini 2.5 Flash: $0.30/1M input / $2.50/1M output
- 1 task ≈ $0.0008 → 月 150 task = **$0.12/月**

### Phase 3: AI Subdivide
- 1 日 stale task 想定: 2-3 task
- 1 subdivide = 800 input / 1500 output = 2.3K total
- 1 task ≈ $0.004 → 月 75 task = **$0.30/月**

→ **計 $0.42/月** (Gemini Flash 無料枠内 / 課金不要)

---

## 6. Philosophy 9/9 ✅

1. **CEO 感**: ✅ AI review 結果は `manual_override` で人間が覆せる
2. **ミッション駆動**: ✅ 事業化 = ミッション直接
3. **優しい mentor**: ✅ stall 検出 → 分解で詰まり解消 = mentor 的支援
4. **6 部署バランス**: ✅ 8 カテゴリで balanced
5. **商品=ユーザー価値**: ✅ 起業速度 = User 早期到達
6. **資本=時間**: ✅ stall 自動検出で時間節約
7. **資産負債 BS**: ✅ AI コスト $0.42/月 = 軽微
8. **KPI=昨日の自分**: ✅ 毎日の task 消化数 = KPI
9. **ゴール=IPO**: ✅ `business-ipo` カテゴリで直接管理

---

## 7. AI-DEV 7/7 ✅ (Phase 2-3 設計時)

1. **Auth**: GEMINI_API_KEY (既設定)
2. **Deny-by-default**: secret 未設定で skip
3. **trace_id**: GHA run_id を `ai_review_notes` に記録
4. **Cost CB**: Gemini Free Tier (RPM 15) 内 / quota fail で skip
5. **Team memory**: `ai_review_notes` / `auto_subdivided_at` が memory
6. **Checkpoint+retry**: failed review は次 cron で retry
7. **Quality gate**: `manual_override` で人間が最終決裁可

---

## 8. UI/UX 設計 (Phase 4 / VSCode 担当)

`project-gantt` page 拡張:

- 各 task に **AI Review Badge** (✅ approved / ⚠️ pending / 🔴 rejected)
- **Stall Indicator** (🐌 24h 進捗 0)
- **Sub-task Hierarchy**: parent/child を indent で表示
- **Manual Override** ボタン: 人間が AI 判定を覆す
- カテゴリ filter (`business-*` のみ表示 / 開発タスクと分離)

---

## 9. 改訂履歴

- **2026-04-25 (Win版#132 part 11)**: 初版作成。事業化 WBS + AI 自動 review/subdivide 4-Phase 設計。
