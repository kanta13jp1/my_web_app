---
title: "Claude Haiku for Low-Cost AI Inference: Patterns from a Horse Racing Prediction System"
tags: ai,automation,postgresql,indiedev
published: true
---

# Claude Haiku for Low-Cost AI Inference: Patterns from a Horse Racing Prediction System

Haiku is fast and cheap. But "cheap, so use it" isn't a design strategy. Here are the actual patterns from building a horse racing prediction system with 11 scoring factors — how to extract maximum value from haiku and when to upgrade.

## Model Selection Principle

```
Claude Opus 4.7:   highest quality, highest cost → architecture decisions, complex design
Claude Sonnet 4.6: balanced                      → code review, moderate reasoning
Claude Haiku 4.5:  fast, cheap                   → routine inference, batch processing
```

**Decision rule**: Does this task require *deep understanding*?
- Take 11 numeric scores, generate a prediction text → **haiku is sufficient**
- Design the 11-factor scoring system → **needs sonnet or above**

## Haiku in the Horse Racing AI

```typescript
const CLAUDE_MODELS = {
  haiku: 'claude-haiku-4-5-20251001',
  sonnet: 'claude-sonnet-4-6',
};

async function predictRace(raceData: RaceInput): Promise<string> {
  // High data quality = straightforward numeric analysis → haiku
  const model = raceData.dataQualityScore >= 7
    ? CLAUDE_MODELS.haiku
    : CLAUDE_MODELS.sonnet;  // low quality = more inference needed

  const response = await anthropic.messages.create({
    model,
    max_tokens: 800,
    messages: [{
      role: 'user',
      content: buildPredictionPrompt(raceData),
    }],
  });

  return response.content[0].text;
}
```

## Prompt Design for Haiku

Haiku performs best with short, structured, explicit inputs:

```typescript
function buildPredictionPrompt(data: RaceInput): string {
  return `
You are a horse racing prediction specialist. Analyze the data below and output ranked predictions.

<<<RACE_DATA>>>
Race: ${data.raceName}
Starters: ${data.horseCount}

Horses (11-factor scores):
${data.horses.map(h => `
  ${h.name}: total ${h.totalScore}
  - final lap: ${h.finalLapScore} | prev rank: ${h.prevRankScore}
  - jockey: ${h.jockeyScore} | weight change: ${h.weightScore}
  - odds: ${h.oddsScore} | time: ${h.timeScore}
  - popularity: ${h.popularityScore} | margin: ${h.marginScore}
  - rest days: ${h.freshnessScore} | age penalty: ${h.agePenaltyScore}
  - data quality: ${h.dataQualityScore}/17
`).join('')}
<<<END>>>

Output: Top 3 predicted finishers with one-sentence rationale each. Under 150 words.
`;
}
```

`<<<RACE_DATA>>>...<<<END>>>` blocks guard against prompt injection from external data. Explicit output format ("under 150 words") keeps haiku's output consistent.

## Batch Parallelism

```typescript
async function predictAllRaces(races: RaceInput[]): Promise<PredictionResult[]> {
  const batchSize = 5;
  const results: PredictionResult[] = [];

  for (let i = 0; i < races.length; i += batchSize) {
    const batch = races.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(race => predictRace(race).catch(e => ({ error: String(e) })))
    );
    results.push(...batchResults as PredictionResult[]);
    
    if (i + batchSize < races.length) {
      await new Promise(r => setTimeout(r, 200));
    }
  }

  return results;
}
```

Haiku has lower latency and more relaxed rate limits than sonnet/opus — parallel batches work well.

## Cost Math: Haiku vs Sonnet

```
Per prediction (~800 input tokens / ~200 output tokens):

Haiku:   $0.25/M in + $1.25/M out
  = $0.00045 per prediction

Sonnet:  $3.00/M in + $15.00/M out
  = $0.00540 per prediction

→ Haiku costs ~1/12 of Sonnet

50 races/day:
  Haiku:   $0.0225/day = $0.68/month
  Sonnet:  $0.2700/day = $8.10/month
```

$7.40/month difference. Small now, meaningful at scale.

## Dynamic Model Selection via DQS

```typescript
function selectModel(dqs: number, factorCount: number): 'haiku' | 'sonnet' {
  if (dqs >= 12 && factorCount >= 10) return 'haiku';
  return 'sonnet';
}
```

High DQS = complete data = numeric analysis = haiku is enough.  
Low DQS = missing data = requires contextual inference = upgrade to sonnet.

## Summary

Five rules for getting value from haiku:
1. **Routine, structured tasks only.** Don't use it where creativity or deep reasoning matters.
2. **Keep prompts short and structured.** Fewer input tokens = lower cost and faster response.
3. **Specify output format explicitly.** "Under 150 words" keeps haiku's output consistent.
4. **Switch models dynamically based on context quality.** Don't fix everything to haiku.
5. **Parallelize batches.** Low latency plus relaxed rate limits = efficient batch processing.

The insight isn't "haiku is cheap." It's "this task doesn't need more than haiku." That judgment is the design decision.
