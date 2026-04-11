-- DeepSeek 初期コンテンツシード (2026-04-11)
-- 中国発の高コスパOSSモデルとして急速に注目されているDeepSeekの概要・モデル・APIを収録
-- Claude Schedule ai-university-update タスクが毎週 news カテゴリを上書き更新する

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('deepseek', 'overview', 'DeepSeek 概要',
$$中国のDeepSeek社が開発するオープンソースAI。**圧倒的なコスト効率**と**高い推論能力**で2024〜2025年に世界的な注目を集めました。GPT-4o・Claude 3.5 Sonnetと肩を並べる性能を大幅低コストで提供。

## 主要製品

- **DeepSeek-V3**: MoEアーキテクチャの最新フラッグシップ（6710億パラメータ、実効37B稼働）
- **DeepSeek-R1**: Chain-of-Thoughtに特化した推論モデル。o1に匹敵する数学・コーディング性能
- **DeepSeek-Coder**: コード生成特化モデル（V2まで）
- **DeepSeek-V2**: 高効率MoE（236Bパラメータ、実効21B）

## 強み

- **オープンソース**: モデルウェイトを MIT ライセンスで公開（商用利用可）
- **超低コスト API**: GPT-4o の約 1/30 の料金で同等性能
- **MoE アーキテクチャ**: 推論時に全パラメータを使わず効率的
- **中国語・英語両対応**: アジア市場での高い精度$$,
'https://www.deepseek.com/', '2026-01-01', 1),

('deepseek', 'models', 'DeepSeek モデル一覧 (2026)',
$$## DeepSeek-V3 / R1 シリーズ

| モデル | パラメータ | 実効パラメータ | 用途 |
| :--- | :--- | :--- | :--- |
| **DeepSeek-V3** | 671B (MoE) | 37B | 汎用・最高精度 |
| **DeepSeek-R1** | 671B (MoE) | 37B | 推論・数学・コード |
| **DeepSeek-R1-Zero** | 671B (MoE) | 37B | 強化学習ベース推論 |
| **DeepSeek-V3 (7B)** | 7B | 7B | 軽量・エッジ向け |
| **DeepSeek-R1 (8B)** | 8B | 8B | 軽量推論モデル |

## MoE (Mixture of Experts) の特徴

- 671B全パラメータのうち **37B のみ推論時に活性化**
- 計算コストを抑えつつ大規模モデルの品質を実現
- **AIME 2024**: o1 と同等スコア (79.8% vs 79.2%)
- **SWE-bench**: GPT-4o を上回るコード修正能力

## オープンソース活用

```bash
# Ollama でローカル実行
ollama run deepseek-r1:7b

# Hugging Face からダウンロード
pip install transformers
# → deepseek-ai/DeepSeek-R1 をロード
```$$,
'https://github.com/deepseek-ai/DeepSeek-V3', '2026-01-01', 2),

('deepseek', 'api', 'DeepSeek API 入門',
$$## DeepSeek API の始め方

DeepSeek API は **OpenAI 互換**なので既存コードからの移行が簡単です。

```python
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_DEEPSEEK_API_KEY",
    base_url="https://api.deepseek.com/v1"
)

response = client.chat.completions.create(
    model="deepseek-chat",   # deepseek-chat = V3, deepseek-reasoner = R1
    messages=[{"role": "user", "content": "AIとは何ですか？"}]
)
print(response.choices[0].message.content)
```

## 推論モデル (R1) の利用

```python
# deepseek-reasoner = DeepSeek-R1 (thinking 付き)
response = client.chat.completions.create(
    model="deepseek-reasoner",
    messages=[{"role": "user", "content": "フィボナッチ数列の100番目を求めよ"}]
)
# response.choices[0].message.reasoning_content に思考プロセスが入る
```

## 料金 (2026年1月時点)

| モデル | 入力 (キャッシュヒット) | 入力 (通常) | 出力 |
| :--- | :--- | :--- | :--- |
| **deepseek-chat (V3)** | $0.014 / 100万token | $0.14 / 100万token | $0.28 / 100万token |
| **deepseek-reasoner (R1)** | $0.14 / 100万token | $0.55 / 100万token | $2.19 / 100万token |

GPT-4o ($2.50/100万入力token) と比較して **約1/18 のコスト**。$$,
'https://api-docs.deepseek.com/', '2026-01-01', 3)

ON CONFLICT DO NOTHING;
