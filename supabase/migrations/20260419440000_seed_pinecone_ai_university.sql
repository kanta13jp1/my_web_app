-- PS版#3 Session 7: Pinecone — RAG・セマンティック検索向けベクターデータベース
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'pinecone',
  'overview',
  'Pinecone — RAG・セマンティック検索に特化したクラウドネイティブベクター DB',
  E'## Pinecone とは\n\nPinecone は 2019 年設立のニューヨーク発スタートアップ。\n**ベクターデータベース（Vector Database）** の先駆者として、AI アプリケーションの「長期記憶」を担うインフラを提供。\n\nLLM に文脈を与える **RAG (Retrieval-Augmented Generation)** の普及とともに急成長。\n評価額 $750M、累計調達 $138M+。\n\n## 主な特徴\n\n- **高速 ANN 検索**: 数億ベクターを数ミリ秒で検索\n- **フルマネージド**: インフラ管理不要・スケールアップ自動\n- **ハイブリッド検索**: 密ベクター + スパース検索の組み合わせ\n- **メタデータフィルタリング**: ユーザーID・日付などで検索結果を絞り込み\n- **Serverless**: 使用量に応じた従量課金・無料枠あり\n\n## 活用事例\n\n- **RAG チャットボット**: 社内文書・FAQ を埋め込んで LLM に文脈提供\n- **セマンティック検索**: キーワードでなく「意味」で検索\n- **推薦エンジン**: ユーザー行動ベクターで類似コンテンツ推薦\n- **重複検出**: テキスト・画像の類似度計算で重複コンテンツを特定',
  '2026-04-20'
),
(
  'pinecone',
  'models',
  'Pinecone インデックス・機能一覧',
  E'## インデックス種類\n\n| タイプ | 特徴 | 用途 |\n|--------|------|------|\n| **Serverless** | 自動スケール・使用量課金 | 推奨・本番 |\n| **Pod-based** | 専用リソース・予測可能コスト | 大規模固定ワーク |\n\n## 検索アルゴリズム\n\n- **Dense Vector**: Embedding モデルの浮動小数点ベクター (cosine / euclidean / dotproduct)\n- **Sparse Vector**: BM25 などのスパース表現（キーワード重視）\n- **Hybrid**: Dense + Sparse の加重組み合わせ\n\n## メタデータフィルタリング\n\n```python\n# ユーザー固有データのみ検索\nresults = index.query(\n    vector=query_embedding,\n    filter={\n        "user_id": {"$eq": "user_123"},\n        "category": {"$in": ["AI", "Tech"]},\n        "created_at": {"$gte": "2026-01-01"}\n    },\n    top_k=5\n)\n```\n\n## Pinecone Inference API\n\n- 埋め込みモデル内蔵 (multilingual-e5-large など)\n- テキスト → ベクター変換を Pinecone 内で完結\n\n## 料金\n\n| プラン | 月額 | 内容 |\n|--------|------|------|\n| Starter | $0 | 2GBストレージ・1インデックス |\n| Standard | 従量 | $0.033/1M ベクター書込 |\n| Enterprise | 要相談 | SLA・HIPAA・プライベート |',
  '2026-04-20'
),
(
  'pinecone',
  'api',
  'Pinecone API 使い方',
  E'## インストール\n\n```bash\npip install pinecone-client openai\nexport PINECONE_API_KEY="YOUR_API_KEY"\n```\n\n## インデックス作成 & ベクター挿入\n\n```python\nfrom pinecone import Pinecone, ServerlessSpec\nfrom openai import OpenAI\n\npc = Pinecone(api_key="YOUR_PINECONE_KEY")\n\n# サーバーレスインデックス作成\nif "ai-university" not in [i.name for i in pc.list_indexes()]:\n    pc.create_index(\n        name="ai-university",\n        dimension=1536,  # text-embedding-3-small の次元数\n        metric="cosine",\n        spec=ServerlessSpec(cloud="aws", region="us-east-1")\n    )\n\nindex = pc.Index("ai-university")\nclient = OpenAI()\n\n# テキストをベクターに変換して挿入\ntexts = [\n    "Anthropic は Claude を開発する AI 安全性企業",\n    "OpenAI は GPT-4 を開発した先駆的 AI 企業",\n    "Deepgram は音声認識に特化した AI スタートアップ"\n]\n\nbatch = []\nfor i, text in enumerate(texts):\n    embedding = client.embeddings.create(\n        input=text, model="text-embedding-3-small"\n    ).data[0].embedding\n    batch.append({"id": str(i), "values": embedding, "metadata": {"text": text}})\n\nindex.upsert(vectors=batch)\n```\n\n## セマンティック検索（RAG 用）\n\n```python\n# 質問をベクター化して検索\nquery = "音声認識 API はどれがいい？"\nquery_emb = client.embeddings.create(\n    input=query, model="text-embedding-3-small"\n).data[0].embedding\n\nresults = index.query(\n    vector=query_emb,\n    top_k=3,\n    include_metadata=True\n)\n\n# 取得したコンテキストを LLM に渡す\ncontext = "\\n".join([r["metadata"]["text"] for r in results["matches"]])\nresponse = client.chat.completions.create(\n    model="gpt-4o-mini",\n    messages=[\n        {"role": "system", "content": f"以下の情報を参考に答えてください:\\n{context}"},\n        {"role": "user", "content": query}\n    ]\n)\nprint(response.choices[0].message.content)\n```\n\n## 活用シーン\n\n- **AI 大学 RAG 強化**: プロバイダー情報をベクター化して質問応答\n- **ノート検索**: ユーザーのメモをセマンティック検索で即発見\n- **競合情報検索**: 競合 21 社のデータをベクター化して比較分析',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
