-- PS#3 S81: AI大学 257→258社化 — LM Evaluation Harness (EleutherAI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lm_eval_harness', 'overview',
  'LM Evaluation Harness — EleutherAI製LLMベンチマーク標準ツール (OpenLLM Leaderboard基盤 / MMLU/HumanEval/GSM8K / GitHub 7k+ / 9/9)',
  $## LM Evaluation Harness とは

**LM Evaluation Harness** は EleutherAI が開発する LLM の学術ベンチマーク評価フレームワーク。**Hugging Face OpenLLM Leaderboard** の評価基盤として使われており、業界標準の評価ツール。

## 主要ベンチマーク

| ベンチマーク | タスク | 指標 |
|------------|------|------|
| **MMLU** | 大学レベル知識 57 分野 | Accuracy |
| **HellaSwag** | 文章補完 (常識推論) | Accuracy |
| **TruthfulQA** | 事実性・幻覚 | Truth × Info |
| **HumanEval** | Python コード生成 | Pass@k |
| **GSM8K** | 小学算数 (8学年レベル) | Accuracy |
| **ARC (Easy/Challenge)** | 小中学理科 | Accuracy |
| **WinoGrande** | 代名詞解決 / 常識 | Accuracy |
| **BIG-Bench Hard** | 難問 / 複合推論 | CoT Accuracy |
| **MATH** | 高校・大学数学 | Accuracy |
| **DROP** | 段落推論 + 数値計算 | F1 / EM |

## OpenLLM Leaderboard との関係

```
Hugging Face OpenLLM Leaderboard
        ↓
LM Evaluation Harness でベンチマーク評価
        ↓
6指標: ARC / HellaSwag / MMLU / TruthfulQA / Winogrande / GSM8K
        ↓
スコアの平均 → 総合ランキング

公開モデルはすべてこの6指標で比較可能
```

## few-shot 評価の仕組み

```
0-shot: モデルに何も見せず直接質問
  "Who was the first president of the United States?"
  → 事前学習知識のみで回答

few-shot: 例題を数問見せてから質問
  "Q: Who was the first president? A: George Washington
   Q: What is H2O? A: Water
   Q: Who wrote Hamlet? A:"
  → 文脈内学習 (In-Context Learning) で精度向上

標準: MMLU=5-shot, GSM8K=5-shot (Chain-of-Thought), HumanEval=0-shot
```

## エコシステム

- **GitHub**: 7,000+ Stars / EleutherAI 公式
- **ライセンス**: MIT
- **対応**: 60+ LLM 評価タスク / 200+ ベンチマークデータセット
- **統合**: Hugging Face Hub / vLLM / OpenAI API / ローカルモデル

## 自分株式会社での活用

| シーン | ベンチマーク | 目的 |
|--------|-----------|------|
| **モデル選定** | MMLU + HumanEval | 候補モデルの客観比較 |
| **ファインチューニング効果測定** | GSM8K + TruthfulQA | 学習前後の変化確認 |
| **ローカル vs API 品質比較** | 全指標 | コスト最適化の判断材料 |
| **日本語モデル評価** | JCommonsenseQA + JMMLU | 日本語 LLM 選定 |$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lm_eval_harness', 'api',
  'LM Evaluation Harness 実践 — ローカルモデル評価・OpenAI API評価・カスタムタスク作成・日本語ベンチマーク',
  $## インストール

```bash
pip install lm_eval

# または GPU 対応版
pip install lm_eval[vllm]

# 最新版 (GitHub から)
pip install git+https://github.com/EleutherAI/lm-evaluation-harness.git
```

## ローカルモデルの評価

```bash
# Hugging Face モデルを MMLU (5-shot) で評価
lm_eval \
  --model hf \
  --model_args pretrained=meta-llama/Meta-Llama-3-8B-Instruct \
  --tasks mmlu \
  --num_fewshot 5 \
  --device cuda:0 \
  --batch_size 8 \
  --output_path ./results/llama3-8b-mmlu

# 複数タスク一括評価
lm_eval \
  --model hf \
  --model_args pretrained=meta-llama/Meta-Llama-3-8B-Instruct \
  --tasks mmlu,hellaswag,truthfulqa_mc1,gsm8k,humaneval \
  --num_fewshot 5,10,0,5,0 \
  --device cuda:0 \
  --output_path ./results/llama3-8b-full
```

## vLLM バックエンドで高速評価

```bash
# vLLM で大幅高速化 (GPU がある場合推奨)
lm_eval \
  --model vllm \
  --model_args pretrained=meta-llama/Meta-Llama-3-8B-Instruct,tensor_parallel_size=1 \
  --tasks mmlu \
  --num_fewshot 5 \
  --batch_size auto \
  --output_path ./results/llama3-8b-vllm
```

## OpenAI API モデルの評価

```bash
# GPT-4o を MMLU で評価
export OPENAI_API_KEY="sk-..."

lm_eval \
  --model openai-chat-completions \
  --model_args model=gpt-4o \
  --tasks mmlu \
  --num_fewshot 5 \
  --output_path ./results/gpt4o-mmlu

# Claude API 評価
lm_eval \
  --model anthropic-chat-completions \
  --model_args model=claude-3-5-sonnet-20241022 \
  --tasks gsm8k \
  --num_fewshot 5
```

## Python API でプログラマティックに評価

```python
import lm_eval
from lm_eval import evaluator

# モデルを Python から評価
results = evaluator.simple_evaluate(
    model="hf",
    model_args="pretrained=meta-llama/Meta-Llama-3-8B-Instruct",
    tasks=["mmlu", "gsm8k"],
    num_fewshot=5,
    batch_size=8,
    device="cuda",
)

# 結果の取得
for task_name, task_results in results["results"].items():
    print(f"\n=== {task_name} ===")
    for metric, score in task_results.items():
        if metric != "alias":
            print(f"  {metric}: {score:.4f}")
```

## 日本語ベンチマーク

```bash
# 日本語ベンチマーク (lm-eval-harness-ja)
pip install lm-eval[ja]

# JCommonsenseQA: 日本語常識推論
# JMMLU: 日本語 MMLU
# JSQuAD: 日本語読解
lm_eval \
  --model hf \
  --model_args pretrained=llm-jp/llm-jp-3-3.7b \
  --tasks jcommonsenseqa,jmmlu \
  --num_fewshot 3 \
  --device cuda:0
```

## カスタムタスク作成

```yaml
# my_custom_task.yaml
task: jibun_kaisha_qa
dataset_path: json
dataset_kwargs:
  data_files:
    test: ./data/jibun_qa_test.jsonl
doc_to_text: "Q: {{question}}\nA:"
doc_to_target: "{{answer}}"
doc_to_choice: null
metric_list:
  - metric: exact_match
    aggregation: mean
    higher_is_better: true
num_fewshot: 3
```

```bash
# カスタムタスクで評価
lm_eval \
  --model hf \
  --model_args pretrained=my-finetuned-model \
  --tasks my_custom_task \
  --include_path ./custom_tasks/
```

## 評価結果の比較 (ファインチューニング前後)

```python
import json
import pandas as pd

# ベースモデルの結果
with open("./results/llama3-8b-base/results.json") as f:
    base_results = json.load(f)

# ファインチューニング後の結果
with open("./results/llama3-8b-finetuned/results.json") as f:
    ft_results = json.load(f)

tasks = ["mmlu", "gsm8k", "hellaswag"]
comparison = []
for task in tasks:
    base_score = base_results["results"][task].get("acc,none", 0)
    ft_score = ft_results["results"][task].get("acc,none", 0)
    comparison.append({
        "task": task,
        "base": f"{base_score:.4f}",
        "finetuned": f"{ft_score:.4f}",
        "delta": f"{(ft_score - base_score):+.4f}",
    })

df = pd.DataFrame(comparison)
print(df.to_string(index=False))
```$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lm_eval_harness', 'models',
  'LM Evaluation Harness 技術詳解 — ベンチマーク設計思想・MMLU/GSM8K/HumanEval詳細・汚染問題・日本語LLM評価比較',
  $## ベンチマーク設計の哲学

EleutherAI の評価原則:

```
1. 再現性 (Reproducibility)
   すべての評価はオープンソース / 誰でも同じ結果を得られる
   → OpenLLM Leaderboard の信頼性の根拠

2. 広い能力カバレッジ
   単一タスクではなく認知能力全体を測定
   → MMLU (知識) + HellaSwag (常識) + HumanEval (コード) + GSM8K (数学)

3. few-shot の標準化
   N-shot を固定することで公平な比較を確保
   → MMLU=5shot が業界標準

4. contamination 問題への対処
   ベンチマークデータがモデルの学習データに含まれている問題
   → 評価数値が実際の能力を反映しない可能性
```

## MMLU の詳細

**Massive Multitask Language Understanding** (Hendrycks et al., 2021):

```
57 分野の4択問題:
  STEM系: 数学/物理/化学/コンピュータ科学/医学/etc.
  社会科学: 経済学/法律/政治学/etc.
  人文系: 歴史/哲学/etc.
  その他: 一般常識/etc.

形式:
  Question: Which of the following is NOT a valid Python data type?
  A. list   B. tuple   C. array   D. dict
  Answer: C

スコア解釈:
  Random baseline: 25% (4択)
  Human expert:    ~89%
  GPT-3.5 (2023):  70%
  GPT-4 (2023):    86%
  Llama-3-70B:     82%
  Llama-3-8B:      68%
```

## GSM8K の詳細

**Grade School Math 8K** (Cobbe et al., 2021):

```
小学算数文章題 8,500 問
Chain-of-Thought (CoT) で評価することが多い

例題:
  Janet's ducks lay 16 eggs per day.
  She eats 3 for breakfast. She bakes muffins for friends every day
  with 4 eggs. She sells the remainder at $2/egg.
  How much does she make every day?

正解:
  Step 1: Eggs remaining = 16 - 3 - 4 = 9
  Step 2: Revenue = 9 × $2 = $18

スコア解釈:
  GPT-3 (なしCoT): 35%
  GPT-3 (CoT):     56%
  GPT-4:           92%
  Llama-3-8B (CoT): 75%
  → CoTあり/なしでスコアが大きく異なる
```

## HumanEval の詳細

**OpenAI HumanEval** (Chen et al., 2021):

```
164 の Python コーディング問題
Pass@k で評価 (k個生成して1つでも正解なら合格)

例題:
  def has_close_elements(numbers: List[float], threshold: float) -> bool:
      """ Check if in given list of numbers, are any two numbers closer to each other
          than given threshold. """

採点:
  生成コードを unittest で自動実行
  → 全テストケース通過でスコア1

スコア解釈:
  Random:       0%
  GPT-4:        67% (Pass@1)
  Claude-3.5:   92% (Pass@1)
  Llama-3-8B:   62% (Pass@1)
  CodeLlama-34B: 73% (Pass@1)
```

## データ汚染 (Contamination) 問題

```
問題: ベンチマーク問題がモデルの学習データに含まれていると
      スコアが高くなる (暗記している可能性)

検出方法:
1. n-gram 重複チェック
2. Membership Inference Attack
3. 新しいベンチマーク問題への性能転移を確認

2024年以降の動向:
  → 静的ベンチマークへの不信感
  → 動的評価 (問題が毎回変わる) が注目される
  → Chatbot Arena (人間評価) の価値が再評価
```

## 自分株式会社 モデル評価フロー

```
Phase 1: 候補モデル絞り込み (lm-eval で自動)
  対象: Llama-3-8B / Qwen2.5-7B / Gemma-2-9B / llm-jp-3-3.7b
  タスク: mmlu, gsm8k, hellaswag
  所要: 2〜4時間 (A100 1枚)

Phase 2: 上位モデルの詳細評価
  追加: jmmlu, jcommonsenseqa (日本語)
  + DeepEval で RAG 品質も評価

Phase 3: ファインチューニング効果確認
  前後で mmlu, gsm8k スコアを比較
  → catastrophic forgetting がないか確認
  (ファインチューニング後に汎用能力が下がっていないか)

Phase 4: 本番投入判断
  全指標でベースモデル比 -3% 以内 → OK
  それ以上の低下 → LoRA rank 下げ or データ見直し
```$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 257→258社化: LM Evaluation Harness 追加',
  'PS#3 S81。LM Evaluation Harness (EleutherAI製LLMベンチマーク/OpenLLM Leaderboard基盤/MMLU/HumanEval/GSM8K/HellaSwag/TruthfulQA/日本語ベンチマーク/few-shot評価/GitHub 7k+/MIT/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
