-- CoreWeave 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('coreweave', 'overview', 'CoreWeave 概要',
$$CoreWeave は AI ネイティブ企業向けの GPU クラウドプラットフォーム。OpenAI / Meta / Perplexity 等の超大手 AI 企業の本番推論インフラを支える業界トップクラスの NVIDIA GPU プロバイダー。

2024 年 NASDAQ 上場後、NVIDIA の最新世代 GPU (H100 → B200/B300 → Vera Rubin) を最速で大規模展開する戦略で差別化。

2026 年 3 月に Perplexity との multi-year 戦略パートナーシップを発表。Inworld Router 等のサードパーティ inference ゲートウェイを通じて OpenAI 互換 API も利用可能。

## 主要サービス
- **GPU クラウド**: H100 / B200 / B300 / 今後 Vera Rubin NVL72 + Vera CPU rack
- **AI Inference platform**: 大規模・低遅延・predictable cost
- **Kubernetes ネイティブ**: K8s + InfiniBand networking で multi-node 推論
- **CoreWeave Solutions**: AI / cloud tools for creative industries

## 強み
- **NVIDIA Vera Rubin NVL72** (2026 後半): 業界最速展開予定
- **InfiniBand**: ノード間超低遅延 (大規模 inference 必須)
- **Reserved pricing**: 持続トラフィック向けに最適コスト
- **Enterprise 顧客**: OpenAI / Meta / Perplexity 等 Tier 1$$,
'https://www.coreweave.com/', '2026-04-19', 1),

('coreweave', 'models', 'CoreWeave モデル・GPU 一覧 (2026)',
$$## NVIDIA GPU 提供ラインナップ

| GPU | 提供開始 | 用途 | 特徴 |
| :--- | :--- | :--- | :--- |
| **H100** | 2023〜 | LLM 推論・学習 | 業界標準 |
| **HGX B300** | 2026 | 大規模推論 | 第3世代 Hopper 後継 |
| **B200** | 2025 | 高効率推論 | 価格性能比優秀 |
| **Vera Rubin NVL72** | 2026 H2 (予定) | 巨大モデル推論 | 業界初の大規模 deploy |
| **Vera CPU rack** | 2026 H2 (予定) | エージェント AI | reasoning 特化 |

## モデルアクセスパターン
- **直接 GPU**: K8s + Kubeflow / vLLM / SGLang で自前デプロイ
- **Inworld Router 経由**: OpenAI 互換 API で hundreds of models
- **OpenAI / Anthropic 経由**: CoreWeave インフラで動く既存サービスを利用

## 特徴的な機能
- **InfiniBand networking**: 8 NIC per node = 大規模並列推論
- **Predictable cost**: reserved pricing で月額固定
- **Tier 1 セキュリティ**: SOC 2 / HIPAA / FedRAMP-ready
- **Kubernetes-native**: 標準ツールチェーン互換$$,
'https://www.coreweave.com/solutions/ai-inference', '2026-04-19', 2),

('coreweave', 'api', 'CoreWeave API 入門',
$$## CoreWeave Cloud で AI 推論を始める

CoreWeave は GPU クラウドのため、API は **K8s ベース** + **vLLM/SGLang デプロイ**が標準。OpenAI 互換 chat API は Inworld Router 等のゲートウェイ経由で提供される。

```bash
# CoreWeave Cloud Account 作成
# kubectl で K8s クラスタアクセス
kubectl apply -f vllm-llama-deployment.yaml
```

## vLLM デプロイ例 (Llama 3.3 70B)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-llama-70b
spec:
  template:
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
        - --model=meta-llama/Llama-3.3-70B-Instruct
        - --tensor-parallel-size=8
        resources:
          limits:
            nvidia.com/gpu: 8  # H100 x8
```

## 料金 (2026年時点)
- **H100**: $2.39 / hr (on-demand) — 業界平均より低価格
- **B200**: $3.49 / hr (on-demand)
- **B300**: 詳細問い合わせ
- **Reserved pricing**: 1〜3 年契約で大幅 discount
- **Inworld Router 経由 LLM**: 各モデル provider rate (CoreWeave インフラ料金は内包)

## 公式リソース
- [CoreWeave Inference Docs](https://docs.coreweave.com/cloud-tools/coreweave-kubernetes/getting-started)
- [Inworld Router 経由利用](https://inworld.ai/)$$,
'https://docs.coreweave.com/', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
