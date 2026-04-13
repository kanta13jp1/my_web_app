-- Windows版#64: AI大学48社目 — Databricks (DBRX / Mosaic)
-- データ・AI統合プラットフォーム。オープンソースMoEモデルDRBXで注目

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'databricks',
  'overview',
  'Databricks とは',
  E'## Databricks とは\n\nDatabricks はデータエンジニアリング・データサイエンス・AIを統合する**レイクハウスプラットフォーム**。\n2023年にMosaic MLを買収し、独自LLM「DBRX」を開発・公開した。\n\n### 企業概要\n- 設立: 2013年 (Apache Sparkの生みの親が創業)\n- 本社: サンフランシスコ\n- 評価額: 約620億ドル (2024年)\n- 従業員: 7,000人以上\n\n### AI関連の主要サービス\n- **DBRX**: オープンソースMixture-of-Experts LLM\n- **Mosaic AI**: モデル訓練・ファインチューニング・サービング\n- **MLflow**: オープンソースMLOpsプラットフォーム (業界標準)\n- **Delta Lake**: データレイクハウスのストレージレイヤー\n- **Databricks AI/BI**: AIを活用したビジネスインテリジェンス\n\n### 強み\n- データからAIまでワンストップ (ETL→モデル訓練→デプロイ→監視)\n- Apache Spark / MLflow / Delta Lake のオープンソースコミュニティ\n- エンタープライズセキュリティ・ガバナンス\n- GPU クラスタの自動スケーリング\n\n> 公式: https://www.databricks.com/',
  'https://www.databricks.com/',
  '2026-04-13',
  1,
  true
),
(
  'databricks',
  'models',
  'Databricks モデル一覧',
  E'## Databricks モデル一覧\n\n### DBRX (自社開発 LLM)\n| モデル | パラメータ | 特徴 | ライセンス |\n| --- | --- | --- | --- |\n| **DBRX Instruct** | 132B (36B active) | MoEフラッグシップ | Databricks Open |\n| **DBRX Base** | 132B (36B active) | ベースモデル | Databricks Open |\n\n### MoE (Mixture of Experts) アーキテクチャ\n```\n総パラメータ: 132B\nアクティブパラメータ: 36B (推論時)\nエキスパート数: 16 (うち4つが各トークンで活性化)\nコンテキスト長: 32K トークン\n\n→ 132Bの知識を持ちながら36B相当の計算コストで推論\n```\n\n### Mosaic AI プラットフォーム\n| 機能 | 説明 |\n| --- | --- |\n| **Foundation Model APIs** | 外部モデル (GPT-4o / Claude等) を統一API経由で利用 |\n| **Model Training** | カスタムモデルの分散訓練 (GPU自動割当) |\n| **Fine-tuning** | LoRA / QLoRA でLLMをファインチューニング |\n| **Model Serving** | 低レイテンシーAPIエンドポイント自動構築 |\n| **AI Playground** | モデル比較テスト環境 |\n| **Vector Search** | RAG用ベクターDB (組み込み) |\n| **AI Gateway** | レート制限・コスト管理・監査ログ |\n\n### 料金\n| サービス | 課金単位 |\n| --- | --- |\n| DBRX API | $0.75 / 100万token (入力) |\n| Model Serving | DBU単位 (GPUタイプ依存) |\n| Fine-tuning | GPU時間課金 |',
  'https://www.databricks.com/product/machine-learning',
  '2026-04-13',
  2,
  true
),
(
  'databricks',
  'api',
  'Databricks AI API 利用方法',
  E'## Databricks AI API 利用方法\n\n### 認証\n```bash\nexport DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"\nexport DATABRICKS_TOKEN="your_pat_token"\n```\n\n### Foundation Model APIs (OpenAI互換)\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key=os.environ["DATABRICKS_TOKEN"],\n    base_url=f"{os.environ[''DATABRICKS_HOST'']}/serving-endpoints"\n)\n\nresponse = client.chat.completions.create(\n    model="databricks-dbrx-instruct",\n    messages=[\n        {"role": "user", "content": "Sparkの最適化テクニックを教えて"}\n    ],\n    max_tokens=512\n)\nprint(response.choices[0].message.content)\n```\n\n### MLflow でモデル管理\n```python\nimport mlflow\n\nmlflow.set_tracking_uri("databricks")\n\nwith mlflow.start_run():\n    mlflow.log_param("model", "dbrx-instruct")\n    mlflow.log_metric("accuracy", 0.95)\n    mlflow.pyfunc.log_model("model", python_model=my_model)\n```\n\n### Vector Search (RAG)\n```python\nfrom databricks.vector_search.client import VectorSearchClient\n\nvsc = VectorSearchClient()\nresults = vsc.get_index("main.default.my_index").similarity_search(\n    query_text="機械学習の最新手法",\n    columns=["content", "source"],\n    num_results=5\n)\n```\n\n### リソース\n- APIドキュメント: https://docs.databricks.com/\n- MLflow: https://mlflow.org/\n- DBRX: https://www.databricks.com/blog/introducing-dbrx-new-state-art-open-llm',
  'https://docs.databricks.com/',
  '2026-04-13',
  3,
  true
),
(
  'databricks',
  'news',
  'Databricks 最新情報',
  E'## Databricks 最新情報 (2026-04-13)\n\n### 注目トピック\n- **DBRX**: 2024年3月公開。132B MoEモデルがLlama 2 70BやGrok-1を上回る性能\n- **Mosaic AI Agent Framework**: AIエージェント構築・デプロイの統合フレームワーク\n- **AI/BI Dashboards**: 自然言語でダッシュボード作成。SQLを書かずにデータ分析\n- **Unity Catalog**: データ・AIアセットの統合ガバナンス\n- **Databricks Apps**: カスタムAIアプリをワークスペース内でホスト\n- **評価額620億ドル**: 2024年のシリーズJで史上最大級のAIスタートアップ評価額\n\n### MLflow の業界影響\nDatabricksが開発したMLflow はMLOpsの事実上の標準。\nAWS / Azure / GCP 全てのクラウドで採用されている。\n\n> 公式: https://www.databricks.com/ | DBRX: https://huggingface.co/databricks/dbrx-instruct',
  'https://www.databricks.com/',
  '2026-04-13',
  1,
  true
)
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
