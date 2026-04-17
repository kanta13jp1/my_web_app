-- SambaNova 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('sambanova', 'overview', 'SambaNova 概要',
$$SambaNova Systems は 2017 年に Stanford 大学出身のエンジニア達によって設立された米国パロアルト本拠の AI インフラ企業。独自のリコンフィギュラブル・データフロー・ユニット (RDU) と呼ばれるチップ設計思想で、GPU に依存しない高速 AI 推論プラットフォームを提供する。

2026 年 2 月には最新チップ **SN50** を発表。競合比 **5 倍高速** の推論速度と、エージェント型ワークロードで **3 倍のコスト効率** を実現。同年 3 月には Intel とのパートナーシップを発表し、$350M の追加調達 (累計 11 億ドル超) を達成した。

## 主要サービス

- **SambaNova Cloud** — Llama 3.3 / DeepSeek-R1 / Qwen 等をホストするインファレンス API
- **SN50 データフロー・チップ** — 専用 RDU アーキテクチャで 200+ tokens/sec を実現
- **SambaNova Suite** — オンプレミス向けエンタープライズ AI プラットフォーム
- **ai-starter-kit** — Llama / RAG / エージェント構築用 OSS テンプレート集

## 強み

- GPU 比 **5 倍の推論速度**・**3 倍の電力効率**
- **OpenAI API 互換** — 数分で既存アプリをポータブル移植可能
- Llama 405B を業界最速クラスで提供 (秒間 200+ tokens)
- 開発者無料枠 ($5 クレジット・30M+ tokens/Llama 8B)
- Meta / AWS / Intel との戦略提携$$,
'https://sambanova.ai/', '2026-04-17', 1),

('sambanova', 'models', 'SambaNova モデル一覧 (2026)',
$$## SambaNova Cloud ホスティングモデル

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Llama 3.3 70B** | 128K | Meta 最新汎用 LLM | 対話・要約・汎用タスク |
| **Llama 3.3 8B** | 128K | 軽量版 Llama | エージェント・高頻度呼出 |
| **Llama 3.1 405B** | 128K | 世界最速クラス (200+ tok/s) | 高精度推論 |
| **DeepSeek-R1** | 128K | オープンソース推論特化 | コーディング・数学 |
| **Qwen 2.5 72B** | 128K | 中国語・多言語強み | アジア向けサービス |

## SN50 チップ仕様 (2026年2月リリース)

- **RDU アーキテクチャ** — データフロー型再構成可能チップ
- **推論速度**: 競合 GPU 比 **5 倍**
- **コスト効率**: エージェント推論で **3 倍節約**
- **電力効率**: GPU 比 **3 倍**
- **パートナー**: Meta Llama API / AWS Bedrock 連携

## 特徴的な機能

- OpenAI Chat Completions API 互換
- ストリーミング出力対応
- ツール呼び出し (Function Calling) 対応
- JSON モード対応
- エンタープライズ向け専用デプロイ (SambaNova Suite)$$,
'https://docs.sambanova.ai/', '2026-04-17', 2),

('sambanova', 'api', 'SambaNova API 入門',
$$## SambaNova API の始め方

```python
# OpenAI SDK で SambaNova Cloud に接続 (OpenAI 互換 API)
import openai

client = openai.OpenAI(
    api_key="YOUR_SAMBANOVA_API_KEY",
    base_url="https://api.sambanova.ai/v1",
)

response = client.chat.completions.create(
    model="Meta-Llama-3.3-70B-Instruct",
    messages=[
        {"role": "system", "content": "あなたは親切なアシスタントです。"},
        {"role": "user", "content": "JEPA と LLM の違いを教えて"}
    ],
    temperature=0.7,
    max_tokens=1024,
)

print(response.choices[0].message.content)
```

## 料金 (2026年4月時点)

- **Free Tier**: $5 クレジット (Llama 8B で 3,000万 tokens 相当、3ヶ月有効)
- **Developer Tier**: 従量課金 (入力 / 出力別)
- **Enterprise**: Contact Sales (オンプレミス SambaNova Suite 含む)
- **OpenAI 互換エンドポイント**: `https://api.sambanova.ai/v1/chat/completions`

## 参考リンク

- 公式サイト: <https://sambanova.ai/>
- ドキュメント: <https://docs.sambanova.ai/>
- 料金ページ: <https://cloud.sambanova.ai/plans/pricing>
- APIキー発行: <https://cloud.sambanova.ai/apis>
- OSS スターターキット: <https://github.com/sambanova/ai-starter-kit>$$,
'https://docs.sambanova.ai/', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
