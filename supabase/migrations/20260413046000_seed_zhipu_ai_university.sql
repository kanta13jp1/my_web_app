-- Windows版#65: AI大学50社目 — Zhipu AI (智谱AI / GLM)
-- 清華大学発。中国AI御三家(Baidu/Alibaba/Zhipu)の一角。GLM-4がフラッグシップ

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'zhipu',
  'overview',
  'Zhipu AI (智谱AI) とは',
  E'## Zhipu AI (智谱AI) とは\n\n**智谱AI (ジーポーAI)** は中国**清華大学**の研究から生まれたAIスタートアップ。\n2019年設立。大規模言語モデル「GLM (General Language Model)」シリーズを開発・提供し、\nBaidu (文心一言) / Alibaba (Qwen) と並ぶ**中国AI御三家**の一角を担う。\n\n### 企業概要\n- 設立: 2019年 (清華大学コンピュータサイエンス学部スピンオフ)\n- 本社: 北京\n- 評価額: 約30億ドル (2024年)\n- 主要モデル: GLM-4 / ChatGLM / CogVideo / CogView\n\n### 主要サービス\n- **GLM-4**: 128Kコンテキスト・マルチモーダル対応フラッグシップLLM\n- **ChatGLM**: オープンソースLLMシリーズ (Hugging Face で数千万DL)\n- **BigModel API**: 開発者向けクラウドAPI (OpenAI互換インターフェース)\n- **GLM-4 Air**: 軽量・高速・低コスト版\n- **GLM-4V**: 画像理解・マルチモーダル対応版\n- **CogVideo**: テキストから動画生成\n- **CogView**: テキストから画像生成\n- **CodeGeeX**: コード生成特化モデル\n\n### 強み\n- 清華大学の研究基盤 (学術的信頼性)\n- **完全オープンソース**: ChatGLMシリーズはHugging Faceで公開\n- 中国語・英語のバイリンガル対応\n- マルチモーダル (テキスト/画像/動画/コード) の幅広いカバレッジ\n- 国内プライバシー規制対応のオンプレミス展開オプション\n\n> 公式: https://www.zhipuai.cn/ | BigModel: https://bigmodel.cn/',
  'https://www.zhipuai.cn/',
  '2026-04-13',
  1,
  true
),
(
  'zhipu',
  'models',
  'Zhipu AI モデル一覧',
  E'## Zhipu AI モデル一覧\n\n### GLM-4 シリーズ (フラッグシップ)\n| モデル | コンテキスト | 特徴 | 用途 |\n| --- | --- | --- | --- |\n| **GLM-4** | 128K | 最高性能・マルチモーダル | 高度推論・長文処理 |\n| **GLM-4 Air** | 128K | 軽量・高速・低コスト | 汎用・コスト重視 |\n| **GLM-4 Flash** | 128K | 超軽量・無料枠あり | プロトタイプ・テスト |\n| **GLM-4V** | 8K | 画像理解対応 | 画像分析・OCR |\n| **GLM-4 Long** | 1M | 超長文コンテキスト | 書類解析・RAG |\n\n### オープンソース ChatGLM シリーズ\n| モデル | パラメータ | ライセンス | 特徴 |\n| --- | --- | --- | --- |\n| **ChatGLM3-6B** | 6B | 商用可 | 軽量・ローカル実行可 |\n| **ChatGLM2-6B** | 6B | 商用可 | 旧世代・安定版 |\n\n### 生成AIモデル\n| モデル | モダリティ | 特徴 |\n| --- | --- | --- |\n| **CogVideo-X** | テキスト→動画 | 6秒・720p動画生成 |\n| **CogView-3** | テキスト→画像 | 高品質画像生成 |\n| **CodeGeeX-4** | コード | 128Kコンテキスト・9言語 |\n\n### 特徴的な機能\n- **GLM-4 AllTools**: Web検索・コード実行・画像生成を統合した関数呼び出し\n- **Emohaa**: 感情サポート特化LLM\n- **CharacterGLM**: キャラクターロールプレイ特化版\n\n### 料金 (BigModel API)\n| モデル | 入力 | 出力 |\n| --- | --- | --- |\n| GLM-4 | ¥0.1 / 1K tokens | ¥0.1 / 1K tokens |\n| GLM-4 Air | ¥0.001 / 1K tokens | ¥0.001 / 1K tokens |\n| GLM-4 Flash | 無料 (レート制限あり) | 無料 |',
  'https://bigmodel.cn/dev/api',
  '2026-04-13',
  2,
  true
),
(
  'zhipu',
  'api',
  'Zhipu AI API 利用方法',
  E'## Zhipu AI API 利用方法 (BigModel)\n\n### 認証\n```bash\n# APIキー取得: https://bigmodel.cn/usercenter/proj-mgmt/apikeys\nexport ZHIPU_API_KEY="your_api_key"\n```\n\n### Python SDK (zhipuai)\n```python\npip install zhipuai\n```\n\n```python\nfrom zhipuai import ZhipuAI\n\nclient = ZhipuAI(api_key="your_api_key")\n\n# チャット (GLM-4)\nresponse = client.chat.completions.create(\n    model="glm-4",\n    messages=[\n        {"role": "user", "content": "Pythonでフィボナッチ数列を生成するコードを書いてください"}\n    ]\n)\nprint(response.choices[0].message.content)\n\n# ストリーミング\nstream = client.chat.completions.create(\n    model="glm-4-air",\n    messages=[{"role": "user", "content": "日本の歴史を簡単に説明して"}],\n    stream=True\n)\nfor chunk in stream:\n    print(chunk.choices[0].delta.content, end="")\n```\n\n### OpenAI 互換 API\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="your_zhipu_api_key",\n    base_url="https://open.bigmodel.cn/api/paas/v4/"\n)\n\nresponse = client.chat.completions.create(\n    model="glm-4",\n    messages=[{"role": "user", "content": "こんにちは"}]\n)\n```\n\n### 画像理解 (GLM-4V)\n```python\nresponse = client.chat.completions.create(\n    model="glm-4v",\n    messages=[{\n        "role": "user",\n        "content": [\n            {"type": "text", "text": "この画像を説明してください"},\n            {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}\n        ]\n    }]\n)\n```\n\n### リソース\n- BigModel API: https://bigmodel.cn/\n- ドキュメント: https://bigmodel.cn/dev/api\n- ChatGLM GitHub: https://github.com/THUDM/ChatGLM3\n- HuggingFace: https://huggingface.co/THUDM',
  'https://bigmodel.cn/dev/api',
  '2026-04-13',
  3,
  true
),
(
  'zhipu',
  'news',
  'Zhipu AI 最新情報',
  E'## Zhipu AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **GLM-4 AllTools**: Web検索・コード実行・画像生成を1モデルで統合。エージェント構築に最適\n- **GLM-4 Long (1Mコンテキスト)**: 超長文処理。100万tokenのコンテキストで書類全文をRAGなしで処理\n- **CogVideo-X**: テキストから6秒の高品質動画生成。Sora競合として注目\n- **CodeGeeX-4**: VS Code拡張として100万+ユーザー。GitHub Copilot の中国版として普及\n- **GLM-4 Flash 無料公開**: 開発者向けに GLM-4 Flash を無料提供。API学習コストをゼロに\n- **評価額30億ドル**: 2024年のシリーズDで30億ドル評価。中国AI三強の地位確立\n- **ChatGLM 累計5,000万DL**: Hugging Faceでの総ダウンロード数が5,000万を突破\n\n### 中国AI三強の比較\n| 項目 | 智谱AI (GLM) | 文心一言 (Baidu) | Qwen (Alibaba) |\n| --- | --- | --- | --- |\n| 創設 | 清華大学系 | Baidu | Alibaba |\n| フラッグシップ | GLM-4 (128K) | ERNIE 4.0 | Qwen2.5-72B |\n| オープンソース | ◎ ChatGLM | △ 一部公開 | ◎ Qwen2.5 |\n| 得意領域 | コード・マルチモーダル | 検索・一般知識 | 長文・多言語 |\n| 動画生成 | CogVideo-X | iRAG | ○ |\n\n### 開発者エコシステム\n- **CodeGeeX**: JetBrains/VS Code/Vim 対応のAIコーディングアシスタント\n- **清华大学との連携**: AMiner (研究者グラフ) やWenZhong知識グラフと統合\n- **エンタープライズ向け**: オンプレミス展開・プライベートデプロイをサポート\n\n> 公式: https://www.zhipuai.cn/ | BigModel: https://bigmodel.cn/ | GitHub: https://github.com/THUDM',
  'https://www.zhipuai.cn/',
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
