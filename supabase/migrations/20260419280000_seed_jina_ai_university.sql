-- PS版#3 Session 1: Jina AI — 検索基盤特化 AI (embeddings/reranking/reader)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'jina_ai',
  'overview',
  'Jina AI — 検索基盤の専門家',
  E'## Jina AI とは\n\nJina AI は 2020 年にベルリンで創業した AI スタートアップ。\n「Search Foundation（検索基盤）」を核に、**埋め込みモデル・リランキングモデル・Web 読み込み API** を開発・提供している。\n\nLLM の回答品質を左右する **RAG（Retrieval-Augmented Generation）** パイプラインのコア部品として世界中の開発者に採用されており、GitHub Star 数や Hugging Face ダウンロード数で高い評価を受けている。\n\n## 主な特徴\n\n- **長文対応**: OpenAI small モデルの 32 倍の文書長を 1 ドキュメントで処理可能\n- **多言語対応**: 100 言語以上をネイティブサポート\n- **同一 API キーで全サービス**: embeddings / reranking / reader / classifier を 1 キーで利用\n- **無料枠あり**: Free プランで即時試用可能\n\n## 創業・資金調達\n\n- 設立: 2020 年（ベルリン）\n- 創業者: Han Xiao（CEO）、Xuanwei Shen（CTO）\n- 累計調達: 約 3,750 万ドル（Series A 含む）',
  '2026-04-19'
),
(
  'jina_ai',
  'models',
  'Jina AI モデル一覧',
  E'## Embeddings\n\n### jina-embeddings-v3（最新推奨）\n- **パラメータ**: 570M\n- **コンテキスト**: 8,192 tokens\n- **次元数**: 最大 1,024\n- **料金**: $0.02 / 1M tokens\n- **特徴**: タスクアダプター対応（query, passage, classification, separation）、LoRA 統合\n\n### jina-embeddings-v2-base-en\n- 旧世代・軽量・高速、英語特化\n\n---\n\n## Reranking\n\n### jina-reranker-v3（最新推奨）\n- **パラメータ**: 0.6B\n- **特徴**: 多言語対応、長文文書への高精度スコアリング\n- **用途**: 検索結果の精度向上、RAG パイプラインの品質向上\n\n### jina-reranker-v2-base-multilingual\n- 安定版、本番利用に実績あり\n\n---\n\n## Reader API\n\n### jina-reader\n- URL を渡すと Markdown 形式で内容を返す\n- LLM が Web ページを読む際のプリプロセッサとして活用\n- エンドポイント: `https://r.jina.ai/{URL}`\n\n---\n\n## Classifier API\n\n- ラベルと入力を渡すと分類スコアを返す\n- Zero-shot 分類も可能',
  '2026-04-19'
),
(
  'jina_ai',
  'api',
  'Jina AI API 使い方',
  E'## 認証\n\n```bash\ncurl https://api.jina.ai/v1/embeddings \\\n  -H "Authorization: Bearer jina_xxxxxxxxxxxxxxxxxxxxxxxx" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "jina-embeddings-v3",\n    "input": ["RAG パイプラインに最適", "ベクトル検索で活用"]\n  }''\n```\n\n## 料金プラン\n\n| プラン | 月額 | RPM | TPM | 並行リクエスト |\n|--------|------|-----|-----|----------------|\n| Free | 0 | 100 | 100K | 2 |\n| Paid | 従量課金 | 500 | 2M | 50 |\n| Premium | 要問い合わせ | 5,000 | 50M | 500 |\n\n**Embeddings**: $0.02 / 1M tokens  \n**Reranking**: $0.02 / 1M tokens  \n**Reader**: 無料（レート制限あり）\n\n## Python SDK\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="jina_xxxxxxxx",\n    base_url="https://api.jina.ai/v1"\n)\n\nresponse = client.embeddings.create(\n    model="jina-embeddings-v3",\n    input=["Hello, Jina!"]\n)\nprint(response.data[0].embedding[:5])\n```\n\n## 活用シーン\n\n- **RAG**: ドキュメント埋め込み → ベクトル DB 格納 → reranker で精度 UP\n- **セマンティック検索**: jina-embeddings-v3 + コサイン類似度\n- **Web 読み込み**: jina-reader で LLM に URL を食わせる',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
