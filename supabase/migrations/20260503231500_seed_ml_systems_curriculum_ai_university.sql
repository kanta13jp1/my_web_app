-- PS#3 S150: AI大学 ML Systems AI Engineering Curriculum追加 (Issue #1786)
-- Source: 5e03281b Machine Learning Systems: The AI Engineering Curriculum

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'ml_engineering', 'systems_curriculum',
  'ML Systems エンジニアリングカリキュラム — MLシステム設計・分散学習・MLOps・LLMServing完全ガイド (10/10)',
  $$## ML Systems AI Engineering とは

**ML Systems Engineering**は機械学習モデルの開発だけでなく、**本番環境での大規模運用**
に必要なシステム設計・インフラ・MLOpsを包括するエンジニアリング領域。
AI大学の「データ基盤」と「学術研究」を繋ぐ実践的な架け橋となる学科。

## カリキュラム構成

```
Chapter 1: ML基盤システム設計
  ・フィーチャーストア (Feast / Hopsworks / Tecton)
  ・データパイプライン (Apache Beam / Flink / Spark)
  ・オンライン/オフライン特徴量の一貫性

Chapter 2: 分散学習システム
  ・データ並列学習 (DDP / FSDP)
  ・モデル並列学習 (Tensor/Pipeline Parallel)
  ・勾配チェックポインティング・Mixed Precision (FP16/BF16)
  ・通信最適化 (NCCL / AllReduce / ZeRO)

Chapter 3: LLM Serving基盤
  ・連続バッチ処理 (Continuous Batching) — vLLM/TGI
  ・KVキャッシュ最適化 (PagedAttention)
  ・量子化 (INT8/INT4/GPTQ/AWQ)
  ・投機的デコード (Speculative Decoding)
  ・プレフィルとデコードの分離 (Prefill-Decode Disaggregation)

Chapter 4: MLOps & 評価
  ・A/Bテスト・シャドーデプロイ・カナリアリリース
  ・モデルドリフト検出 (PSI / KL-divergence)
  ・継続学習 (Continual Learning) vs 定期再学習
  ・評価システム: Offline eval → Online eval → Human eval
```

## LLM Serving パフォーマンス指標

| 指標 | 定義 | 目標値 |
|------|------|--------|
| TTFT | Time to First Token | < 500ms |
| TPOT | Time Per Output Token | < 50ms |
| スループット | tokens/sec/GPU | > 1000 |
| GPU利用率 | 平均GPU FLOPS使用率 | > 70% |

## 自分株式会社プロジェクトへの適用

```
1. Supabase Edge Functions (Deno) での LLM Serving 最適化:
   ・Claude API コールの連続バッチ化 (schedule-hub での複数ユーザー処理)
   ・KVキャッシュ活用 (Prompt Caching の有効活用 = Anthropic Beta機能)
   ・TTFT の監視: W&B Weave でトレース → Supabase metrics table に記録

2. AI大学コンテンツ生成パイプライン:
   ・MLOps の評価システム概念を「AI大学コンテンツ品質評価」に適用
   ・Offline eval: SQLでコンテンツ品質スコア計算
   ・Online eval: ユーザーの閲覧時間・クリック率を Supabase で追跡

3. 12インスタンス fleet の ML的解釈:
   ・各インスタンス = 異なる「モデル」(専門化された推論エージェント)
   ・shared memory/ = フィーチャーストア (共有特徴量)
   ・NotebookLM = オフライン評価DB (過去の意思決定を保存)
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: データ基盤 / ML Systems / LLMエンジニアリング学科
- **関連プロバイダー**: Weights & Biases / MLflow / vLLM / Hugging Face / NVIDIA
- **実用的示唆**: 本カリキュラムの「継続バッチ処理」「KVキャッシュ」概念を
  Supabase Edge Functionsに適用することでClaude API コスト 20-40%削減が見込める
$$,
  'https://github.com/mlsys-course/mlsys',
  '2026-01-01',
  92
)
ON CONFLICT (provider, category) DO NOTHING;
