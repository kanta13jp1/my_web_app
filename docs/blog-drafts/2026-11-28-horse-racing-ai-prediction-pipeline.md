---
title: "競馬AI予測パイプライン — PostgreSQL + Claude で馬券推奨を自動化する"
tags: AI,個人開発,競馬,postgresql
published: true
---

# 競馬AI予測パイプライン — PostgreSQL + Claude で馬券推奨を自動化する

競馬の予測にAIを使うプロジェクトを半年間続けています。単純な「過去成績→予測」ではなく、**データ品質の整備→特徴量エンジニアリング→Claude による推論→ランキング生成**という多段パイプラインになっています。

## アーキテクチャ概要

```
netkeiba スクレイプ → PostgreSQL (horse_races / horse_entries)
                   → fetch_horse_racing.py (日次バッチ)
                   → Supabase Edge Function (ai-hub: horse.predict)
                   → Claude haiku (推論)
                   → horse_race_predictions_ensemble (結果保存)
                   → evaluate_accuracy.ts (週次評価)
```

## データ品質スコア (DQS)

予測精度の大半はデータ品質で決まります。15フィールドを採点して DQS (0-100) を算出しています：

```sql
-- data_quality_score の計算例
(
  CASE WHEN weight IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN weight_diff IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN last_3f IS NOT NULL THEN 15 ELSE 0 END +
  CASE WHEN prev_last_3f IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN jockey_id IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN trainer_id IS NOT NULL THEN 10 ELSE 0 END +
  CASE WHEN odds IS NOT NULL THEN 15 ELSE 0 END +
  ...
) AS data_quality_score
```

DQS 60未満のエントリーは予測をスキップします。ノイズを下げるためです。

## 特徴量: ランキングスコアの計算

8つの要素を加重スコアリングしてランキングを決定します：

| 要素 | 重み | 根拠 |
|---|---|---|
| 過去複勝率 | 25% | 最も安定した指標 |
| 上がり3F (last_3f) | 20% | 末脚の強さ |
| オッズ逆数 | 15% | 市場の知恵 |
| 騎手勝率 | 15% | ジョッキーファクター |
| 馬体重変化 | 10% | コンディション |
| 上がり3F前走比較 | 10% | 成長 or 衰退トレンド |
| ベストタイム | 5% | タイム能力の天井 |

## Claude による推論プロンプト

スコアだけでなく Claude に「説明」を生成させています：

```typescript
const prompt = `
あなたは競馬の予測専門家です。

【レース情報】
${raceInfo}

【出走馬データ】
${horseData}

以下の観点で上位3頭を推薦してください：
1. データ品質スコアが70以上の馬を優先
2. 持ち時計と上がり3Fを重視
3. 馬体重の急変動 (±10kg超) はリスク要因として明示
4. 推薦理由を各馬100字以内で説明

出力形式: JSON
`;
```

`<<<USER_DATA>>>` ブロックでレースデータを囲み、プロンプトインジェクションを防いでいます。

## N+1問題の解決

初期実装では1レースにつき2クエリ × 50レース = 100クエリという問題がありました。

```typescript
// Before: N+1
for (const race of races) {
  const entries = await db.from('horse_entries').eq('race_id', race.id);
  const predictions = await db.from('predictions').eq('race_id', race.id);
}

// After: バッチクエリ
const raceIds = races.map(r => r.id);
const [allEntries, allPredictions] = await Promise.all([
  db.from('horse_entries').in('race_id', raceIds),
  db.from('predictions').in('race_id', raceIds),
]);
// Map でインデックス化 → O(1) ルックアップ
const entriesByRace = new Map(raceIds.map(id => [
  id, allEntries.filter(e => e.race_id === id)
]));
```

100クエリ → **3クエリ** に削減。評価バッチが10倍速くなりました。

## 週次精度評価

`evaluate_accuracy.ts` が週次でモデルの精度を評価します：

```typescript
type AccuracyResult = {
  total_races: number;
  top3_accuracy: number;    // 推薦上位3頭に複勝馬が含まれる率
  rank1_accuracy: number;   // 1位推薦が複勝馬である率
  avg_dqs: number;          // 評価対象の平均DQS
};
```

## 現在の精度

- top3_accuracy: **52%** (複勝馬が上位3頭に入る確率)
- rank1_accuracy: **31%** (単純ランダムは20%)
- 評価対象: DQS ≥ 70 のレースのみ

まだ改善中ですが、ランダム比較で有意に優れていることは確認できています。

## まとめ

競馬AI予測で学んだ最大の教訓は「**精度よりもデータ品質の整備を先にやれ**」です。DQS を導入してノイズレースを除外するだけで、精度が10ポイント以上向上しました。AIモデルの改良よりも、データパイプラインの整備が先です。
