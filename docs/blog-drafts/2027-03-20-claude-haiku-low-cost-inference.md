---
title: "Claude haiku で低コスト AI 推論を設計する — 競馬AI で学ぶ実践パターン"
tags: AI,個人開発,automation,postgresql
published: true
---

# Claude haiku で低コスト AI 推論を設計する — 競馬AI で学ぶ実践パターン

Claude haiku は安くて速い。しかし「安いから使う」だけでは設計にならない。競馬AI予測システム (11因子 / DQS スコア) の実装を通じて、haiku を最大限に活かすパターンを公開します。

## モデル選択の原則

```
Claude opus 4.7:  最高品質・高コスト → アーキテクチャ判断・複雑な設計
Claude sonnet 4.6: バランス型      → コードレビュー・中程度の推論
Claude haiku 4.5:  高速・低コスト  → 定型推論・バッチ処理・ルーティン
```

**判断基準**: そのタスクに「深い理解」が必要か？
- 11因子の数値を受け取って予測テキストを生成する → **haiku で十分**
- 競馬AIの因子設計を考える → **sonnet 以上が必要**

## 競馬AI での haiku 適用

```typescript
// supabase/functions/schedule-hub/index.ts (schedule-hub アクション内)

const CLAUDE_MODELS = {
  haiku: 'claude-haiku-4-5-20251001',  // 定型推論
  sonnet: 'claude-sonnet-4-6',          // 複雑な推論
};

async function predictRace(raceData: RaceInput): Promise<string> {
  // 11因子スコアが揃っていれば haiku で予測
  const model = raceData.dataQualityScore >= 7
    ? CLAUDE_MODELS.haiku
    : CLAUDE_MODELS.sonnet;  // データ品質が低い場合は sonnet で補完

  const response = await anthropic.messages.create({
    model,
    max_tokens: 800,  // haiku は短文が得意 → トークン数を制限
    messages: [{
      role: 'user',
      content: buildPredictionPrompt(raceData),
    }],
  });

  return response.content[0].text;
}
```

## プロンプト設計: haiku に最適化

haiku は短い、構造化された入力で最もパフォーマンスが出る:

```typescript
function buildPredictionPrompt(data: RaceInput): string {
  return `
競馬予測専門家として、以下のデータを分析して予測順位を出力せよ。

<<<RACE_DATA>>>
レース名: ${data.raceName}
出走頭数: ${data.horseCount}

馬データ (11因子スコア):
${data.horses.map(h => `
  ${h.name}: 総合${h.totalScore}点
  - 上がり3F: ${h.finalLapScore} | 前走着順: ${h.prevRankScore}
  - 騎手: ${h.jockeyScore} | 体重変化: ${h.weightScore}
  - オッズ: ${h.oddsScore} | タイム: ${h.timeScore}
  - 人気: ${h.popularityScore} | 着差: ${h.marginScore}
  - 前走間隔: ${h.freshnessScore} | 馬齢: ${h.agePenaltyScore}
  - データ品質: ${h.dataQualityScore}/17
`).join('')}
<<<END>>>

出力形式: 予測順位1-3位を理由とともに。200字以内。
`;
}
```

`<<<RACE_DATA>>>...<<<END>>>` ブロックでプロンプトインジェクション防御。出力形式を明示することで haiku でも一定品質を維持。

## バッチ処理: 並列実行で速度向上

```typescript
// 複数レースを並列処理
async function predictAllRaces(races: RaceInput[]): Promise<PredictionResult[]> {
  // haiku は並列実行が得意 (sonnet/opus より rate limit が緩い)
  const batchSize = 5;
  const results: PredictionResult[] = [];

  for (let i = 0; i < races.length; i += batchSize) {
    const batch = races.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(race => predictRace(race).catch(e => ({ error: String(e) })))
    );
    results.push(...batchResults as PredictionResult[]);
    
    // rate limit 対策: バッチ間に短い待機
    if (i + batchSize < races.length) {
      await new Promise(r => setTimeout(r, 200));
    }
  }

  return results;
}
```

## コスト計算: haiku vs sonnet

```
1レース予測コスト (入力 ~800 tokens / 出力 ~200 tokens):

haiku:   $0.25/M input + $1.25/M output
  = (800 × 0.00000025) + (200 × 0.00000125) = $0.00045/予測

sonnet:  $3.00/M input + $15.00/M output
  = (800 × 0.000003) + (200 × 0.000015) = $0.0054/予測

→ haiku は sonnet の約 1/12 のコスト

1日50レース予測:
  haiku:  $0.0225/日 = $0.675/月
  sonnet: $0.27/日  = $8.10/月
```

月$7.4 の差は小さいが、スケールすると効いてくる。

## DQS (データ品質スコア) でモデルを動的に切り替え

```typescript
type ModelTier = 'haiku' | 'sonnet' | 'opus';

function selectModel(dqs: number, factorCount: number): ModelTier {
  if (dqs >= 12 && factorCount >= 10) return 'haiku';   // 品質高→haiku
  if (dqs >= 8) return 'sonnet';                        // 品質中→sonnet
  return 'sonnet';                                      // 品質低→sonnet (opusは不要)
}
```

DQS が高い = データが揃っている = 単純な数値分析 → haiku で十分。
DQS が低い = 欠損データ多い = 文脈推論が必要 → sonnet に昇格。

## まとめ

Claude haiku を使いこなすポイント:
1. **定型・構造化タスクに限定** — 創造性や深い推論が不要な場面で使う
2. **プロンプトを短く構造化** — 入力トークンを減らして速度もコストも下げる
3. **出力形式を明示** — 200字以内など制約を与えると haiku でも品質安定
4. **DQS / コンテキスト量でモデルを動的切り替え** — haiku 固定にしない
5. **バッチ並列処理** — haiku の低レイテンシを活かす

「安いから haiku」ではなく、「このタスクは haiku で十分」という判断が設計の核心。
