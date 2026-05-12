-- PS#3 S148: AI大学 389→390社化 — GPQA Diamond (Google DeepMind/EleutherAI / 博士レベル科学問題 / フロンティアモデル推論能力評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gpqa', 'overview',
  'GPQA Diamond (Google DeepMind/EleutherAI) — 博士レベル科学問題・フロンティアモデル推論能力の業界標準評価 (10/10)',
  $$## GPQA とは

**GPQA** (Graduate-Level Google-Proof Q&A) は **Google DeepMind・EleutherAI・NYU** が
2023年11月に発表した、**博士レベルの科学問題をAIが解けるか**を測定するベンチマーク。
「Googleで検索しても答えが見つからない」高難度問題を専門家が作成し、
**フロンティアモデルの深層推論能力**を評価する。

## GPQA の設計背景

```
MMLU / TruthfulQA の限界:
  ・MMLU: 57分野の大学入試・資格試験レベル → GPT-4が86%で「飽和」
  ・TruthfulQA: ハルシネーション評価 → パターン化が進んで飽和
  ・共通問題: Webに答えが存在 → 訓練データ汚染のリスク

GPQA の解決策:
  ・「Googleで検索しても解けない」問題のみ採用:
    - 生物学・化学・物理学の博士課程レベル
    - 専門家でも30分以上かかる問題
    - Web上の既存ドキュメントに直接回答なし
  ・専門家クロスバリデーション:
    - 問題作者以外の同分野専門家が解いて正答率65%以上
    - 人間の専門家平均: 約65%（Diamondサブセット）
```

## データセット構成

| 項目 | 詳細 |
|------|------|
| 総問題数 | 448 問 |
| Diamond サブセット | 198 問（最高難度） |
| 対象分野 | 生物学 / 化学 / 物理学 |
| 形式 | 4択問題 |
| 人間専門家正答率 | 65.0%（Diamondは65.5%） |
| ランダム正答率 | 25.0% |

## サブセット構成

- **GPQA Extended** (448問): 全問題
- **GPQA Main** (300問): ノイズ除去後
- **GPQA Diamond** (198問): 最高品質・最高難度（業界標準）

## スコア推移

| モデル | GPQA Diamond スコア | 達成時期 |
|--------|-------------------|----------|
| GPT-4 (2023) | 35.7% | 2023/11 |
| Claude 3 Opus | 50.4% | 2024/03 |
| GPT-4o | 53.6% | 2024/05 |
| Claude 3.5 Sonnet | 59.4% | 2024/06 |
| Claude 3.7 Sonnet (thinking) | **84.8%** | 2025/02 |
| o3 (OpenAI) | **87.7%** | 2025/04 |
| Claude Opus 4.7（推定） | ~88%+ | 2026/05 |

**人間専門家 65.5% を大幅に超えた** Claude 3.7 Sonnet / o3 は
「特定の科学領域でAIが人間専門家を超えた」最初の証拠の一つ。

## なぜ GPQA が重要か

1. **飽和しにくい設計**: Web汚染なし + 博士レベル → 長期間有効な評価指標
2. **推論能力の純粋測定**: 暗記では解けない → 真の推論・演繹能力が必要
3. **Anthropic差別化**: Claude 3.7の"Extended Thinking"機能が84.8%を実現
   → 深層推論モードの有効性を証明
4. **AGI近接指標**: 人間専門家超えは「超人的AI」議論の具体的根拠

## Diamondサブセットの問題例（概念）

```
化学系問題の例（概念）:
  「分子 X を合成する際、触媒 A の条件下で起こる
   立体選択性のメカニズムを説明せよ。
   4択のうち正しいメカニズムを選べ。」

  → Web検索では直接答えが見つからない
  → 有機化学の深い理解が必要
  → 博士課程の問題集にも載っていないレベル
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 学術研究 / AIベンチマーク学部 / 推論・科学問題解決学科
- **関連プロバイダー**: MMLU（大学レベル）/ GPQA（博士レベル）/ ARC-Challenge（高校レベル）
- **実用的示唆**: Claudeの"Extended Thinking"（= /think モード）がGPQAスコアを20%以上向上
  → 自分株式会社でも重要判断にはThinkingモード推奨
$$,
  'https://arxiv.org/abs/2311.12022',
  '2023-11-01',
  95
)
ON CONFLICT (provider, category) DO NOTHING;
