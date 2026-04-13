-- Windows版#67: AI大学54社目 — Naver (HyperCLOVA X / CLOVA X)
-- 韓国最大テック企業Naverが開発。100言語対応・韓国語最強LLM

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'naver',
  'overview',
  'Naver AI (HyperCLOVA X) とは',
  E'## Naver AI (HyperCLOVA X) とは\n\n**Naver** は韓国最大のインターネット企業 (韓国のGoogle)。\n2021年に**HyperCLOVA** (82Bパラメータ) を発表し、韓国語AIのリーダーとして台頭。\n2023年には**HyperCLOVA X** にアップグレードし、100言語・マルチモーダル対応のエンタープライズAIを提供。\n\n### 企業概要\n- 設立: 1999年 (韓国・城南市)\n- 時価総額: 約300億ドル (2024年)\n- 従業員: 約16,000人\n- AI部門: NAVER CLOVA (AIプラットフォーム) + NAVER Labs\n- 日本法人: LINE (LINEヤフーと統合)\n\n### 主要AIサービス\n- **HyperCLOVA X**: 企業向けフラッグシップLLM (100言語・マルチモーダル)\n- **CLOVA X**: 一般ユーザー向けAIアシスタント (ChatGPT競合)\n- **CLOVA Studio**: 開発者向けAPIプラットフォーム\n- **CLOVA Note**: AI議事録・要約ツール\n- **CLOVA Dubbing**: 動画の多言語自動吹き替え\n- **CLOVA OCR**: 文書AI (名刺・領収書・身分証)\n- **CLOVA Voice**: TTS (テキスト読み上げ) API\n- **NAVER 検索AI**: 検索エンジンへのAI統合\n\n### 強み\n- **韓国語最強**: 韓国語データで世界最大規模の学習\n- **日本語対応**: LINE経由の日本市場展開\n- **エンタープライズ実績**: 삼성(Samsung)/현대(Hyundai)等の大企業向け導入\n- **搭載インフラ**: NEVERクラウド (韓国シェアNo.1) との統合\n\n> 公式: https://clova.ai/ | CLOVA Studio: https://clovastudio.naver.com/',
  'https://clova.ai/',
  '2026-04-13',
  1,
  true
),
(
  'naver',
  'models',
  'Naver AI モデル一覧',
  E'## Naver AI モデル一覧\n\n### HyperCLOVA X シリーズ\n| モデル | パラメータ | 特徴 | 用途 |\n| --- | --- | --- | --- |\n| **HyperCLOVA X** | 非公開 (推定100B+) | 韓国語SOTA・マルチモーダル | エンタープライズ |\n| **HyperCLOVA X-Mini** | 非公開 | 軽量・低レイテンシー | APIサービス |\n| **HyperCLOVA (初代)** | 82B | 韓国語専用 | レガシー |\n\n### CLOVA API 機能モデル\n| 機能 | モデル | 説明 |\n| --- | --- | --- |\n| **Text Generation** | HCX-003 | チャット・文章生成 |\n| **Embedding** | bge-m3 | 多言語ベクター埋め込み |\n| **OCR** | CLOVA OCR | 文書認識・フォーム抽出 |\n| **TTS** | CLOVA Voice | 120以上の音声スタイル |\n| **STT** | CLOVA Speech | 韓国語・日本語・英語 |\n| **Translation** | Papago NMT | 15言語の機械翻訳 |\n\n### HyperCLOVA X の特徴技術\n```\n多言語対応:\n- 100言語のテキスト理解・生成\n- 韓国語・日本語・英語・中国語を特に高品質サポート\n- Papago (翻訳エンジン) と統合した多言語処理\n\nマルチモーダル:\n- テキスト + 画像の同時入力\n- 表・グラフの解析\n- 文書レイアウト理解 (OCR統合)\n\nGrounding (事実性向上):\n- NAVER 検索エンジンとリアルタイム連携\n- 最新ニュース・知識を参照した回答生成\n```\n\n### エンタープライズ実績\n```\n導入企業例:\n- 삼성SDS (Samsung): コールセンターAI\n- CJ ENM: コンテンツ推薦\n- 신한카드 (Shinhan Card): 金融アドバイザーAI\n- 현대자동차 (Hyundai): 製造業向け文書解析\n```',
  'https://clovastudio.naver.com/',
  '2026-04-13',
  2,
  true
),
(
  'naver',
  'api',
  'Naver CLOVA Studio API 利用方法',
  E'## Naver CLOVA Studio API 利用方法\n\n### 認証\n```bash\n# APIキー取得: https://clovastudio.naver.com/\nexport NAVER_CLOVA_API_KEY="your_api_key"\nexport NAVER_CLOVA_GATEWAY_KEY="your_gateway_key"\n```\n\n### テキスト生成 (HyperCLOVA X)\n```python\nimport requests\n\nheaders = {\n    "X-NCP-CLOVASTUDIO-API-KEY": NAVER_CLOVA_API_KEY,\n    "X-NCP-APIGW-API-KEY": NAVER_CLOVA_GATEWAY_KEY,\n    "Content-Type": "application/json; charset=utf-8"\n}\n\npayload = {\n    "messages": [\n        {\n            "role": "system",\n            "content": "당신은 친절한 AI 어시스턴트입니다."\n        },\n        {\n            "role": "user",\n            "content": "인공지능의 미래에 대해 설명해주세요."\n        }\n    ],\n    "topP": 0.8,\n    "topK": 0,\n    "maxTokens": 256,\n    "temperature": 0.5,\n    "repeatPenalty": 5.0,\n    "stopBefore": [],\n    "includeAiFilters": True\n}\n\nresponse = requests.post(\n    "https://clovastudio.stream.naver.com/testapp/v1/chat-completions/HCX-003",\n    headers=headers,\n    json=payload\n)\nprint(response.json())\n```\n\n### エンベディング (多言語ベクター)\n```python\n# 日本語テキストのベクター化\npayload = {\n    "text": "自然言語処理の基礎について教えてください",\n    "model": "bge-m3"\n}\nresponse = requests.post(\n    "https://clovastudio.stream.naver.com/testapp/v1/api-tools/embedding/bge-m3",\n    headers=headers,\n    json=payload\n)\nvector = response.json()["result"]["embedding"]\nprint(f"ベクター次元数: {len(vector)}")\n```\n\n### OCR API (領収書・名刺)\n```python\nimport base64\n\nwith open("receipt.jpg", "rb") as f:\n    image_base64 = base64.b64encode(f.read()).decode()\n\npayload = {\n    "images": [{"format": "jpg", "name": "receipt", "data": image_base64}],\n    "requestId": "my_request_001",\n    "version": "V2",\n    "timestamp": 0\n}\nresponse = requests.post(\n    "https://ocr.apigw.ntruss.com/general/v1/ocr",\n    headers={**headers, "X-OCR-SECRET": "your_ocr_secret"},\n    json=payload\n)\n```\n\n### リソース\n- CLOVA Studio: https://clovastudio.naver.com/\n- APIドキュメント: https://api.ncloud-docs.com/docs/ai-naver-clovastudio\n- CLOVA X (一般): https://clova-x.naver.com/\n- Papago (翻訳): https://developers.naver.com/docs/papago/',
  'https://clovastudio.naver.com/',
  '2026-04-13',
  3,
  true
),
(
  'naver',
  'news',
  'Naver AI 最新情報',
  E'## Naver AI 最新情報 (2026-04-13)\n\n### 注目トピック\n- **HyperCLOVA X グローバル展開**: 韓国語のみから100言語対応に拡張。東南アジア・日本市場への展開を加速\n- **CLOVA X 一般公開**: ChatGPT競合の一般向けAIアシスタント。韓国でのシェアが急拡大\n- **検索AIの革新**: NAVER検索にHyperCLOVA Xを統合。従来のキーワード検索から対話型検索へ\n- **LINE AIとの統合**: LINEヤフーとの統合により、日本市場向けAIサービス強化\n- **AI コードアシスタント**: CLOVA X for Developers (GitHub Copilot競合) を開発者向けに提供\n- **CLOVA Note 進化**: 会議の議事録自動生成が日本語にも完全対応\n- **Naver Cloud Platform AI**: クラウドサービスとLLMの統合でエンタープライズ市場を開拓\n\n### 日本市場との関係\n**LINEヤフー (旧 LINE + Yahoo Japan)**:\n- LINEメッセンジャーのAI機能強化 (LINE AI Assistant)\n- Yahoo! JAPANの検索AIにHyperCLOVA X技術を活用\n- 日本語LLMの重要なプレイヤーとして存在感を増す\n\n### 韓国AIエコシステム\n| 企業 | モデル | 特徴 |\n| --- | --- | --- |\n| **Naver** | HyperCLOVA X | 韓国語No.1・検索統合 |\n| **Kakao** | KoGPT | カカオトーク統合 |\n| **LG AI Research** | EXAONE | 製造・エンタープライズ |\n| **Samsung** | Gauss | オンデバイスAI |\n\n> 公式: https://clova.ai/ | API: https://clovastudio.naver.com/ | CLOVA X: https://clova-x.naver.com/',
  'https://clova.ai/',
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
