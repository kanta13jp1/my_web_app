---
date: 2026-04-20
from: PS版#4 (競合モニタリング S12)
to: Win版 (ai-hub / lifestyle-hub)
status: pending
priority: LOW
deadline: 2026-06-30 (MoneyForward GA / Gemini 廃止 完了後)
---

# lifestyle-hub に栄養管理 軽量 action 追加の提案 — 栄養管理疲れ層の受け皿

## 背景 (PS版#4 S12 調査結果)

競合 21社 の Liven (栄養/健康カテゴリ) を深掘りしたところ:

1. **Liven 固有の 2026 新発表は検出されず** (ブランド要再確認)
2. 栄養管理アプリ市場は commodity 化済:
   - あすけん: **1,000万会員** / AI 栄養士「未来」/ 食事画像解析
   - カロミル: **600万+** / AI 食品画像 → 栄養素自動計算
   - NEWTRISH (ウェルナス): 個別栄養最適食 AI
   - MyFitnessPal: グローバル 14M+ 食品 DB

**結論**: 栄養管理**専用アプリ**路線には進まない (philosophy 原則 4 = 6 部署バランス違反)。
ただし、健康部署 (人生 6 部署の一つ) の **1 action レベル** で軽量実装は価値あり。
あすけん/カロミルから「記録疲れ」で離脱した層が潜在マーケット。

---

## 提案: `lifestyle-hub` に 2 action 追加

既存 `lifestyle-hub` (EF 残枠を活用) に以下 2 action 追加:

### Action 1: `nutrition.log_meal`

**入力**:
```json
{
  "action": "nutrition.log_meal",
  "meal_type": "breakfast|lunch|dinner|snack",
  "description": "鮭塩焼き・ご飯・味噌汁・卵焼き",
  "image_url": "https://..." // optional (ai-hub multimodal で解析)
}
```

**処理**:
1. `ai-hub:analyze_food_text` or `ai-hub:analyze_food_image` で PFC 推定
2. `daily_nutrition_logs` テーブルに INSERT (user_id + date + meal_type ユニーク)
3. 日次合計を `nutrition_summary_view` で集計

**差別化**:
- あすけん = 入力必須 / UX が重い
- 自分株式会社 = **自然文 1 行 + 画像 optional** で ai-hub が推定 (入力負荷 1/10)

### Action 2: `nutrition.summary`

**入力**:
```json
{ "action": "nutrition.summary", "date_range": "7d|30d" }
```

**出力**:
- PFC 平均・目標達成率
- CEO 感コメント (原則 1): 「鮭中心だが土曜の揚げ物で脂質 +30%。月曜は野菜中心がおすすめ」
- 昨日の自分比較 (原則 8): 「昨日 タンパク質 65g → 今日 70g (+8%)」

---

## Philosophy 9 原則 チェック

1. **CEO 感** ✅: 自動ロック入力不要・ユーザーが「今日は記録スキップ」を選べる
2. **ミッション駆動** ✅: 健康部署 KPI = 「昨日より栄養バランス」
3. **優しい mentor** ✅: 「鮭塩焼きは青魚に近い! 今週 EPA バランス良好」
4. **6 部署バランス** ✅: 健康部署の 1 機能として位置づけ(専用アプリ化しない)
5. **商品=ユーザー価値** ✅: 入力 1 行 = 時間削減
6. **資本=時間** ✅: あすけん 比で 1/10 入力負荷
7. **資産/負債バランス** ✅: 健康資産 可視化
8. **KPI=昨日の自分** ✅: 比較コメント内蔵
9. **ウェルビーイング** ✅: 栄養疲れさせない UX

**→ 9/9 達成 → 即実装可**

## AI-DEV 7 原則 チェック

1. Auth ✅: ai-hub 継承
2. Deny-by-default ✅: RLS で user_id 一致のみ
3. Trace ✅: `trace_id` 既存
4. Cost CB ✅: ai-hub 4 段階 guard 継承
5. Team memory ✅: `nutrition_effectiveness_score` 導入可 (あとでも可)
6. Retry/DLQ ✅: ai-hub 既存
7. Quality gate ✅: PFC 数値異常 (e.g., 1食 10000kcal) で reject

**→ 7/7 達成 → 即実装可**

---

## 実装規模見積

| ファイル | 変更量 | 所要時間 |
|--------|-------|--------|
| `supabase/functions/lifestyle-hub/index.ts` | +80 lines (2 action) | 30 min |
| `supabase/migrations/YYYYMMDD_create_nutrition_logs.sql` | +40 lines | 15 min |
| `lib/services/nutrition_service.dart` | +120 lines | 45 min |
| `lib/pages/nutrition_page.dart` (軽量 UI) | +200 lines | 60 min |
| **合計** | — | **約 2.5 時間** |

---

## 優先度

🟢 **LOW** — 以下の先行タスク完了後に着手:

1. ✅ Gemini 3.1 Flash-Lite 移行 (2026-06-01 廃止期限)
2. ✅ MoneyForward 個人向け カウンター対策 (2026-07 GA)
3. ✅ Slack Agentforce LP 反映
4. ✅ Google I/O 2026 同日対応

それらが片付いた 2026-06 下旬 以降で着手推奨。

---

## 参考

- [あすけん 1000万会員記念発表](https://www.asken.jp/)
- [カロミル (農水省 紹介)](https://www.maff.go.jp/j/syokuiku/network/movie/0005.html)
- [NEWTRISH (ウェルナス)](https://wellnas.biz/contents/newtrish_app/)

生成: PS版#4 | 2026-04-20 深夜 (S12)
