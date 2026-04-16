-- Cerebras AI 初期コンテンツシード (2026-04-16)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('cerebras', 'overview', 'Cerebras 概要',
$$## Cerebras — Wafer-scale AI コンピュート革命

Cerebras は 2016 年創業の AI チップ企業。独自の **Wafer-scale テクノロジー**で GPU の限界を超えた超高速・低レイテンシーの LLM 推論・ファインチューニングを実現します。

### 企業背景
- **本社**: サンフランシスコ、カリフォルニア
- **資金**: シリーズE (>$2.5B 評価)
- **主要投資家**: Benchmark、Qualcomm、Google、等

### Wafer-scale テクノロジーとは
従来の GPU は数千個のコアを持つチップですが、Cerebras の **CS-2 ウェハスケールシステム**は **262,500 個のコアを 1 つのシリコンウェハに統合**。これにより：

- **通信遅延の大幅削減** → 高速度推論
- **メモリ帯域幅の飛躍的増加** → より大規模モデルを低レイテンシーで実行
- **電力効率の向上** → コスト削減

### 主要サービス

#### 1. **Cerebras Inference** (クラウドAPI)
- REST/gRPC インターフェース
- Llama 3.3 70B / Mistral など複数モデルをホスト
- **超低レイテンシー**: <100ms、ほぼ GPU より低い
- 従来の GPU 推論の 5〜10 倍高速

#### 2. **Cerebras Studio** (開発プラットフォーム)
- ローカル開発環境
- PyTorch / Hugging Face Transformers 互換
- ファインチューニング・評価・デバッグ
- Wafer-scale 環境をシミュレーション

#### 3. **Cerebras Cloud Services** (エンタープライズ)
- 専用リソース確保・SLA対応
- VPC 統合・エアギャップデプロイ
- ホワイトグローブサポート

### 2026 年の最新動向
- **Q1 リリース**: 第3世代ウェハスケールチップ発表
- **エコシステム拡大**: 主要 SaaS プロバイダーとの統合検討中
- **価格改定**: 競争力を高めるため従来比 30% 低価格化$$,
'https://www.cerebras.ai/',
'2026-04-16',
1),

('cerebras', 'models', 'Cerebras モデル一覧 (2026)',
$$## Cerebras でホストされているモデル一覧

Cerebras Inference プラットフォームでは以下のモデルが利用可能です。

| モデル | パラメーター数 | コンテキスト | 推論時間 (平均) | 特徴・用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Llama 3.3 70B** | 70B | 8K | <50ms | 汎用・推論最適化版 |
| **Mistral Large** | 123B | 128K | <100ms | 長文・推論タスク |
| **Mixtral 8x22B** | 141B (MoE) | 64K | <120ms | Sparse・高速 |
| **Cerebras-Llama-7B** | 7B | 8K | <5ms | 超軽量・エッジ対応 |

### Cerebras 独自モデル
#### **Cerebras-Llama** シリーズ
- 公式 Llama をウェハスケール用に最適化
- 同一容量で従来比 20〜40% 高速化
- オープンウェイト版も提供

### ファインチューニング
Cerebras Studio で以下の技術をサポート：
- **LoRA** (低ランク適応)
- **QLoRA** (量子化版)
- **Instruction Tuning** (タスク最適化)
- **継続学習** (新データへの段階的適応)

### 推論スペック (CS-2)
- **ピークスループット**: 36 petaFLOPs
- **メモリ容量**: 40GB HBM2E
- **メモリ帯域幅**: 20 PB/s (GPU の 50 倍)
- **レイテンシー**: <5ms (Llama-7B)$$,
'https://docs.cerebras.ai/models/',
'2026-04-16',
2),

('cerebras', 'api', 'Cerebras API 入門 (2026)',
$$## Cerebras Inference API を始める

### ステップ 1: アカウント作成
[Cerebras Console](https://cloud.cerebras.ai) にアクセス。Google / GitHub / Email で登録。

### ステップ 2: API キー取得
Console → **API Keys** → **Create New Key** → コピー

### ステップ 3: Python SDK をインストール
\`\`\`bash
pip install cerebras-cloud-sdk
\`\`\`

### ステップ 4: 推論を実行
\`\`\`python
from cerebras_cloud_sdk import Cerebras

client = Cerebras(api_key="csk_XXXXXXXXXX...")

response = client.messages.create(
    model="llama-3.3-70b",
    max_tokens=1024,
    system="You are a helpful AI assistant.",
    messages=[
        {"role": "user", "content": "Wafer-scale とは何ですか？"}
    ]
)

print(response.content[0].text)
\`\`\`

### cURL での使用例
\`\`\`bash
curl https://api.cerebras.ai/v1/messages \\
  -H "Authorization: Bearer csk_XXXXXXXXXX..." \\
  -H "Content-Type: application/json" \\
  -d '{
    "model": "llama-3.3-70b",
    "max_tokens": 1024,
    "messages": [
      {"role": "user", "content": "こんにちは"}
    ]
  }'
\`\`\`

### 料金体系 (2026年4月)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **Llama 3.3 70B** | $0.40 | $0.40 |
| **Mistral Large** | $0.50 | $0.50 |
| **Cerebras-Llama-70B** | $0.35 | $0.35 |
| **Llama-7B** | $0.05 | $0.05 |

#### 無料トライアル
- **初回**: $25 クレジット (3ヶ月有効)
- **スターティング**: 月額 $10 (最大 100M tokens)
- **プロフェッショナル**: オーダーメイド (月額 $500〜)

### ドキュメント & リソース
- **公式 API Docs**: https://docs.cerebras.ai/
- **GitHub リポジトリ**: https://github.com/CerebasAI/cerebras-sdk
- **コミュニティ Discord**: https://discord.gg/cerebras
- **チュートリアル**: https://learn.cerebras.ai/

### ベストプラクティス
1. **バッチリクエスト** - 複数の推論をまとめて送信 (スループット最適化)
2. **ストリーミング** - `stream=true` で応答を段階的に取得
3. **キャッシング** - 同一プロンプトの繰り返しに対応 (準備中)
4. **エラー処理** - Rate Limit (429) と Timeout (504) に対応

### ファインチューニング API
\`\`\`python
# Cerebras で独自データでファインチューニング
job = client.finetune.create(
    model="llama-3.3-70b",
    training_data="s3://my-bucket/training.jsonl",
    num_epochs=3,
    learning_rate=1e-4
)
print(f"Job ID: {job.id}")
print(f"Status: {job.status}")
\`\`\`$$,
'https://docs.cerebras.ai/api/',
'2026-04-16',
3)

ON CONFLICT DO NOTHING;
