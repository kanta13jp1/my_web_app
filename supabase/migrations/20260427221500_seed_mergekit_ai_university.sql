-- PS#3 S80: AI大学 255→256社化 — Mergekit (LLMモデルマージ)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mergekit', 'overview',
  'Mergekit — GPUなしでLLMモデルをマージするOSSツール (SLERP/TIES/DARE/Task Arithmetic / GitHub 5k+ / 8/9)',
  $## Mergekit とは

**Mergekit** は Charles Goddard (Arcee AI) が開発する LLM モデルマージ専用ツール。複数のファインチューニング済みモデルを**GPUなし・CPU のみ**で合成し、単一の高品質モデルを作成できる。

## モデルマージとは

```
Llama-3-8B-日本語特化 (LoRA ファインチューニング済み)
            +
Llama-3-8B-コーディング特化 (LoRA ファインチューニング済み)
            ↓ Mergekit
Llama-3-8B-日本語コーディング特化 (新しい能力の融合)
```

追加の学習データも GPU も不要。**数時間の学習コストなしで新能力を獲得**。

## 主要マージ手法

| 手法 | 概要 | 特徴 |
|------|------|------|
| **SLERP** | 球面線形補間 / 2モデルの中間点 | 最もシンプル / 安定 |
| **TIES** | Trim-Elect-Sign-Merge / 干渉排除 | 高品質 / 推奨 |
| **DARE** | Drop And REscale / スパース化 | 3モデル以上に有効 |
| **Task Arithmetic** | タスクベクトルの足し算 | 直感的 / 実験向き |
| **Frankenmerge** | 異なるモデルのレイヤーをスタック | 実験的 / 大きなモデル作成可 |
| **Linear** | 単純な線形補間 / 重み付き平均 | 高速 / 基本手法 |

## なぜマージが機能するか

```
LLM の重みは "知識を符号化した高次元ベクトル空間"
ファインチューニングは元のベクトルから "タスクベクトル (ΔW)" だけ移動する

Model A = Base + ΔW_A (日本語知識)
Model B = Base + ΔW_B (コーディング知識)
Merged  = Base + α·ΔW_A + β·ΔW_B
       ≈ 両方の知識を持つモデル

条件: ΔW_A と ΔW_B が直交 (干渉しない) 場合に高品質
TIES/DARE はこの干渉を除去する手法
```

## モデルマージの活用例

| 活用 | 説明 |
|------|------|
| **Frankenmerge で大型化** | 8B × 2 → 16B 相当の能力 |
| **能力の合成** | 日本語 + 数学 + コーディング |
| **過学習の緩和** | 汎用モデルと特化モデルのバランス |
| **コスト削減** | 新規学習 0 円で新能力追加 |

## 自分株式会社での活用

| シーン | マージ戦略 | 期待効果 |
|--------|-----------|---------|
| **日本語 AI アシスタント** | Llama-3-ja + llama-3-instruct (SLERP) | 日本語品質 + 汎用性 |
| **業務特化モデル** | instruct + 社内FAQ学習モデル (TIES) | ゼロコストで業務対応 |
| **マルチ言語** | EN + JA + ZH モデル (DARE) | 3言語同時対応 |$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mergekit', 'api',
  'Mergekit 実践 — YAML設定でSLERP/TIES/DAREマージ・Frankenmerge・Hugging Face Hub保存',
  $## インストール

```bash
pip install mergekit

# または最新版
pip install git+https://github.com/arcee-ai/mergekit.git
```

## SLERP マージ (最もシンプル / 2モデル)

```yaml
# slerp_merge.yml
# Llama-3-8B の日本語モデルと instruct モデルを 50:50 でブレンド
models:
  - model: meta-llama/Meta-Llama-3-8B-Instruct
  - model: llm-jp/llm-jp-3-3.7b  # 日本語特化

merge_method: slerp
base_model: meta-llama/Meta-Llama-3-8B

parameters:
  t:
    # 各レイヤーで補間係数 t を指定 (0=モデル1, 1=モデル2)
    - filter: self_attn  # attention layers
      value: 0.5         # 50:50 ブレンド
    - filter: mlp        # feed-forward layers
      value: 0.3         # 70% instruct, 30% 日本語
    - value: 0.5         # その他は 50:50

dtype: bfloat16
```

```bash
# マージ実行 (GPU 不要 / CPU のみで動作)
mergekit-yaml slerp_merge.yml ./merged-model \
    --allow-crimes \
    --copy-tokenizer \
    --out-shard-size 1B

# 完了後: ./merged-model/ に保存
```

## TIES マージ (推奨 / 3モデル以上)

```yaml
# ties_merge.yml
# 日本語 + コーディング + 数学 の3能力を合成
models:
  - model: meta-llama/Meta-Llama-3-8B
    parameters:
      density: 1.0  # ベースモデルは全重みを使用
      weight: 1.0

  - model: akjindal53244/Llama-3-8B-Instruct-Japanese
    parameters:
      density: 0.7  # 上位 70% の重み変化のみ使用
      weight: 1.0

  - model: meta-llama/CodeLlama-7b-hf
    parameters:
      density: 0.7
      weight: 0.8

  - model: meta-llama/Llama-3-8B-math
    parameters:
      density: 0.7
      weight: 0.6

merge_method: ties
base_model: meta-llama/Meta-Llama-3-8B

parameters:
  normalize: true   # 重みを正規化

dtype: bfloat16
```

## DARE マージ (大規模モデル向け)

```yaml
# dare_merge.yml
models:
  - model: mistralai/Mistral-7B-v0.1
    parameters:
      weight: 1.0
      density: 0.53  # DARE: ランダムにパラメータをドロップ

  - model: HuggingFaceH4/zephyr-7b-beta
    parameters:
      weight: 1.0
      density: 0.53

merge_method: dare_ties  # DARE + TIES の組み合わせ
base_model: mistralai/Mistral-7B-v0.1
dtype: bfloat16
```

## Frankenmerge (異なるアーキテクチャのレイヤーを積み重ね)

```yaml
# frankenmerge.yml
# 2つの 8B モデルのレイヤーを交互に積んで疑似 16B モデルを作成
slices:
  - sources:
      - model: meta-llama/Meta-Llama-3-8B-Instruct
        layer_range: [0, 16]  # 前半 16 レイヤー

  - sources:
      - model: akjindal53244/Llama-3-8B-Instruct-Japanese
        layer_range: [8, 32]  # 後半 24 レイヤー

merge_method: passthrough  # レイヤーをそのまま結合
dtype: bfloat16

# 結果: 32 レイヤー (8B) ではなく 40 レイヤー の "MoE 的" モデル
```

## Hugging Face Hub にアップロード

```python
from huggingface_hub import HfApi

api = HfApi()
api.create_repo("username/my-merged-model", repo_type="model")
api.upload_folder(
    folder_path="./merged-model",
    repo_id="username/my-merged-model",
    repo_type="model",
)
```

## Python API でプログラマティックにマージ

```python
from mergekit.config.models import MergeConfiguration
from mergekit.merge import MergeOptions, run_merge
import yaml

# YAML 文字列から設定を読み込み
config_str = """
models:
  - model: meta-llama/Meta-Llama-3-8B-Instruct
  - model: llm-jp/llm-jp-3-3.7b
merge_method: slerp
base_model: meta-llama/Meta-Llama-3-8B
parameters:
  t: 0.5
dtype: bfloat16
"""

config = MergeConfiguration.model_validate(yaml.safe_load(config_str))
run_merge(
    config,
    out_path="./merged-model",
    options=MergeOptions(
        cuda=False,          # GPU なしで実行
        copy_tokenizer=True,
        allow_crimes=True,
    ),
)
```$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mergekit', 'models',
  'Mergekit 技術詳解 — TIES/DARE数学・タスクベクトル理論・Frankenmerge実績・モデルソープオペラ現象',
  $## タスクベクトル理論

**Ilharco et al. (2023)** が提唱した "タスクベクトル" が Mergekit の理論的基盤:

```
タスクベクトル τ_A = θ_A - θ_base
  θ_A   : ファインチューニング済みモデルの重み
  θ_base: ベースモデルの重み

複数タスクの合成:
  θ_merged = θ_base + α·τ_A + β·τ_B + γ·τ_C

直感: "日本語知識を表す方向" + "コード知識を表す方向" を足す
```

## TIES の数学

**TRIM-ELECT-SIGN-MERGE** の 4 ステップ:

```
Step 1: TRIM (トリミング)
  各モデルの重み変化 τ で、絶対値が小さいものをゼロにする
  → density パラメータで上位 k% だけ残す

Step 2: ELECT (選択)
  各パラメータで複数モデルが "どちらの符号に変化したか" を多数決
  → 過半数の符号を採用

Step 3: SIGN (符号フィルタ)
  多数決の符号と一致しないパラメータをゼロにする
  → 干渉するパラメータを除去

Step 4: MERGE (マージ)
  残ったパラメータの重み付き平均を取る
  θ_merged = θ_base + Σ w_i · τ_i^TRIM,SIGN / Σ [τ_i^TRIM,SIGN ≠ 0]
```

## DARE の仕組み

TIES の前処理として使用:

```python
# DARE: Drop And REscale
for each parameter p in τ:
    if random() < (1 - density):
        p = 0  # ランダムドロップ (スパース化)
    else:
        p = p / density  # ドロップ分をスケールアップ (期待値保存)

# 効果: モデル間の干渉をランダムに解消
# density=0.53 → 47% のパラメータをドロップ
```

## モデルソープオペラ (Model Soup / Frankenmerge 系譜)

```
2022: Model Soup (Wortsman et al.)
  → 同じベースモデルから微調整した複数モデルの平均が汎化性能向上

2023: Task Arithmetic / TIES / DARE
  → より理論的なマージ手法の確立

2024: Frankenmerge / Evolutional Merge
  → 異なるアーキテクチャのレイヤーを組み合わせ
  → 例: llm-jp-3-13b のレイヤーを別モデルに移植

MistralAI の Mixtral 8x7B も広義の "マージ":
  → 8 つの 7B FFN を 1 つのモデルに組み込む (MoE)
```

## Mergekit を使った実績モデル例

```
OpenHermes-2.5-Mistral-7B (人気 merged model)
  Mistral-7B + 複数 instruct データでファインチューニング済みモデルをマージ
  HuggingFace で 200k+ ダウンロード/月

Neural-Chat-7B (Intel製)
  Mistral-7B をベースに SLERP マージ → Llama2-Chat を超えるスコア

EverythingLM-13B
  Llama-2-13B + 数種の特化モデルを TIES マージ
```

## 自分株式会社 段階的マージ戦略

```
Phase 1: 実験 (無料)
  Hugging Face Hub の公開済みマージモデルをダウンロードして評価
  候補: OpenHermes / NeuralDaredevil / Tulu など

Phase 2: カスタムマージ (CPU 8時間程度)
  llm-jp-3-13b (日本語特化) + Meta-Llama-3-8B-Instruct (英語品質)
  → SLERP で日英バランスモデル作成

Phase 3: 本番投入
  LMDeploy or vLLM でサービング
  → OpenAI API 比 90% コスト削減
```

## パラメータ選択ガイド

```
density (TIES/DARE で使用):
  0.5〜0.7: 標準的な設定 / 干渉を適度に排除
  0.3以下: 大きな干渉がある場合 / 品質劣化リスク
  0.9以上: ほぼ全パラメータを使用 = Linear マージに近づく

weight (各モデルへの貢献度):
  等しい場合: 均等な能力合成
  不等の場合: 高 weight のモデルの特性が強く出る

t (SLERP 補間):
  0.0: モデル A のみ
  0.5: 完全な中間
  1.0: モデル B のみ
  レイヤー別に設定可 (attention/mlp で異なる t を指定)
```$,
  NULL, NULL, 3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 255→256社化: Mergekit 追加',
  'PS#3 S80。Mergekit (LLMモデルマージ/SLERP/TIES/DARE/Task Arithmetic/Frankenmerge/GPU不要/タスクベクトル理論/Arcee AI/GitHub 5k+/Apache 2.0/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
