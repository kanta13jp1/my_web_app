-- PS版#3 Session 10: Dify — ノーコード LLM ワークフロービルダー (OSS)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'dify',
  'overview',
  'Dify — ノーコードで LLM アプリを構築するオープンソースプラットフォーム',
  E'## Dify とは\n\nDify は 2023 年設立の中国・アメリカ発スタートアップ。\n**ノーコード・ローコードで LLM アプリケーション**を構築できる\nオープンソース・プラットフォーム。GitHub スター 80,000+。\n\n「AI エンジニア不要で、誰でも AI アプリを作れる」をビジョンに、\nビジュアルワークフロービルダー・RAG パイプライン・エージェントを\nブラウザ上で組み立てられる。\n\n累計調達 $21M+。セルフホスト可能なため企業の内製化にも最適。\n\n## LangChain との違い\n\n| 観点 | Dify | LangChain |\n|------|------|----------|\n| **インターフェース** | ビジュアル GUI | コード (Python) |\n| **対象ユーザー** | 非エンジニア〜上級者 | 中〜上級エンジニア |\n| **RAG 構築** | GUIでドラッグ&ドロップ | コードで記述 |\n| **モデル対応** | 全主要 LLM | 全主要 LLM |\n| **OSS** | ✅ Apache 2.0 | ✅ MIT |\n\n## 主な特徴\n\n- **ワークフロービルダー**: ノードをドラッグして複雑なチェーンを構築\n- **Knowledge Base (RAG)**: PDF/Web/CSV をアップロードするだけで RAG 完成\n- **エージェント**: ツール呼び出しエージェントを GUI で設計\n- **Prompt IDE**: プロンプトのバージョン管理・A/B テスト\n- **API 公開**: 作成したアプリを REST API として即公開\n\n## 活用事例\n\n- **社内チャットボット**: 社内ドキュメントを Knowledge Base に登録して RAG\n- **カスタマーサポート**: FAQを学習した自動回答ボット\n- **コンテンツ生成**: ブログ/SNS投稿の自動生成ワークフロー\n- **データ処理**: CSV を読み込んで分析・要約するバッチ処理',
  '2026-04-20'
),
(
  'dify',
  'models',
  'Dify 機能・ノードタイプ一覧',
  E'## ワークフロービルダーのノード\n\n### 基本ノード\n\n| ノード | 機能 | 使用例 |\n|--------|------|--------|\n| **LLM** | テキスト生成 | 質問回答・要約・翻訳 |\n| **Knowledge Base** | RAG 検索 | 社内文書から情報取得 |\n| **Code** | Python/JS 実行 | データ変換・API コール |\n| **HTTP Request** | 外部 API 呼び出し | Supabase・Slack 連携 |\n| **IF/ELSE** | 条件分岐 | 回答タイプで処理分岐 |\n| **Iteration** | ループ処理 | リスト各要素を処理 |\n| **Template** | テキスト整形 | プロンプト動的構築 |\n\n### 対応 LLM (2026年)\n\n- **OpenAI**: GPT-4o / o1 / o3\n- **Anthropic**: Claude Sonnet 4.6 / Opus\n- **Google**: Gemini 2.5 Pro / Flash\n- **Meta**: Llama 3.1 (Ollama 経由)\n- **Mistral**: Mistral Large / Small\n- **ローカル**: Ollama / LM Studio 接続\n\n### Knowledge Base (RAG)\n\n```text\nアップロード対応フォーマット:\n- PDF / Word / PowerPoint\n- Markdown / TXT / HTML\n- CSV / JSON\n- Notion / GitHub\n\n設定オプション:\n- チャンクサイズ (200〜2,000 トークン)\n- オーバーラップ (0〜500 トークン)\n- 埋め込みモデル選択\n- ベクターDB (Weaviate/Qdrant/Pinecone)\n```\n\n### Prompt IDE\n\n- システムプロンプトのバージョン管理\n- A/B テスト (複数プロンプトの比較)\n- 変数挿入 `{{variable_name}}`\n- ユーザーフィードバック収集\n\n## API・SDK\n\n```bash\n# 作成したアプリを REST API として呼び出し\ncurl -X POST https://api.dify.ai/v1/chat-messages \\\n  -H "Authorization: Bearer YOUR_APP_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d \'{"query": "AI大学とは？", "conversation_id": "", "user": "user123"}\'\n```\n\n## 料金\n\n- **OSS セルフホスト**: 完全無料 (Docker Compose)\n- **Dify Cloud 無料**: 200 メッセージ/月\n- **Professional**: $59/月 (5,000 メッセージ)\n- **Team**: $159/月 (無制限)',
  '2026-04-20'
),
(
  'dify',
  'api',
  'Dify 使い方',
  E'## セルフホスト起動\n\n```bash\n# Docker Compose で起動 (推奨)\ngit clone https://github.com/langgenius/dify.git\ncd dify/docker\ncp .env.example .env\n# .env で LLM API キーを設定\ndocker-compose up -d\n# → http://localhost/install で初期設定\n```\n\n## RAG アプリの構築 (ノーコード)\n\n```text\n1. Knowledge Base 作成\n   → 「ナレッジ」→「作成」→ ファイルアップロード\n   → チャンクサイズ設定 → 埋め込み実行\n\n2. チャットボット作成\n   → 「スタジオ」→「アプリを作成」→「チャットボット」\n   → オーケストレーション設定でナレッジを選択\n   → LLM ノードで Claude / GPT-4o を選択\n   → 「公開」でURL発行\n\n3. API 経由で Flutter アプリと統合\n   → API キーを取得 → EF から呼び出し\n```\n\n## Python SDK でワークフロー実行\n\n```python\nfrom dify_client import ChatClient\n\nclient = ChatClient(api_key="YOUR_APP_API_KEY")\nclient.base_url = "http://localhost/v1"  # セルフホストの場合\n\n# チャットメッセージ送信\nresponse = client.create_chat_message(\n    query="AI大学のベクターDBを比較してください",\n    user="user123",\n    conversation_id="",  # 新規会話\n    response_mode="blocking"\n)\nprint(response["answer"])\nprint(f"Tokens: {response[\'metadata\'][\'usage\'][\'total_tokens\']}")\n```\n\n## ワークフローをコードで呼び出し\n\n```python\nfrom dify_client import WorkflowClient\n\nclient = WorkflowClient(api_key="YOUR_WORKFLOW_KEY")\nclient.base_url = "http://localhost/v1"\n\n# ワークフロー実行 (入力変数を渡す)\nresult = client.run(\n    inputs={\n        "provider_name": "Anthropic",\n        "language": "ja",\n    },\n    user="batch-processor"\n)\nprint(result["data"]["outputs"])\n```\n\n## Supabase Edge Function との統合\n\n```typescript\n// supabase/functions/ai-assistant/index.ts\nimport { serve } from "https://deno.land/std@0.177.0/http/server.ts"\n\nserve(async (req) => {\n  const { question } = await req.json()\n\n  // Dify API (セルフホスト or クラウド) に問い合わせ\n  const response = await fetch("https://api.dify.ai/v1/chat-messages", {\n    method: "POST",\n    headers: {\n      "Authorization": `Bearer ${Deno.env.get("DIFY_API_KEY")}`,\n      "Content-Type": "application/json",\n    },\n    body: JSON.stringify({ query: question, user: "aisst", conversation_id: "" }),\n  })\n\n  const data = await response.json()\n  return new Response(JSON.stringify({ answer: data.answer }), {\n    headers: { "Content-Type": "application/json" },\n  })\n})\n```\n\n## 活用シーン\n\n- **AI 大学コンテンツ強化**: プロバイダー情報を Knowledge Base に登録して質問応答\n- **ノーコード RAG**: エンジニアなしで社内ドキュメント検索ボットを構築\n- **EF 代替**: 複雑なワークフローを Dify で組んで EF からコール',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
