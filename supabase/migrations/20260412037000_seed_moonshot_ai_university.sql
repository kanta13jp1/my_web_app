-- Windows版#60: Moonshot AI (moonshot) — AI大学41社目
-- Kimi モデル・128K超長文コンテキスト特化・中国発グローバルAI

INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
  ('moonshot', 'overview',
   'Moonshot AI — 超長文コンテキスト特化 Kimi AI',
   E'## Moonshot AI とは\n\nMoonshot AI は**超長文処理・長文理解**に特化したAI企業。\n北京拠点、2023年創業。元 Google Brain・清華大学の研究者が設立。\n\n代表モデル「Kimi」は最大**200万トークン**のコンテキスト長を誇る。\n\n## 特徴\n\n### 長文処理の圧倒的優位性\n\n| 強み | 詳細 |\n|------|------|\n| **超長コンテキスト** | 200万トークン (GPT-4の約16倍) |\n| **長文精度** | LOST IN THE MIDDLE 問題を独自技術で解決 |\n| **ファイル理解** | PDF・Word・Excel などを一括処理 |\n| **コスト効率** | 長文処理のコストパフォーマンスが業界最高 |\n| **日本語対応** | 高精度の日本語理解・生成 |\n\n## 主な用途\n\n- 長大なドキュメント・研究論文の要約\n- 法律文書・契約書の分析\n- コードベース全体のレビュー\n- 書籍・レポート全体を前提にした Q&A\n- 長時間の会議録・議事録処理\n\n## 実績\n\n- シリーズB: $3億ドル調達 (2024年)\n- 評価額: $25億ドル\n- Kimi は中国で ChatGPT と並ぶ人気AIアシスタント\n- 月間アクティブユーザー: 3000万人超',
   '2026-04-13'),

  ('moonshot', 'models',
   'Moonshot AI モデル一覧 (2026年4月現在)',
   E'## Kimi (moonshot-v1-128k)\n\n現行フラッグシップモデル。128Kトークンの長文コンテキスト対応。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 128K トークン |\n| 対応言語 | 中国語・英語・日本語 等 |\n| 用途 | 汎用チャット・長文分析 |\n| 価格 (input) | ¥0.012/1K (人民元) |\n\n## moonshot-v1-32k\n\nコスト効率重視の中規模モデル。短中文の会話・生成に最適。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 32K トークン |\n| 価格 (input) | ¥0.024/1K |\n| 価格 (output) | ¥0.024/1K |\n\n## moonshot-v1-8k\n\n高速・低コストのライト版。シンプルタスクに最適。\n\n| スペック | 値 |\n|---------|----|\n| コンテキスト長 | 8K トークン |\n| 価格 (input) | ¥0.012/1K |\n\n## Kimi Explorer (2024年公開)\n\n長文向けにさらに拡張した研究版。**200万トークン**コンテキスト対応。\n現在はAPIより先にWebアプリで提供中。\n\n## 競合比較 (長文処理)\n\n| 指標 | Kimi (128K) | Claude 3.5 (200K) | GPT-4o (128K) |\n|------|-------------|-------------------|----------------|\n| コンテキスト長 | 128K | 200K | 128K |\n| 長文精度 | ◎ | ◎ | ○ |\n| 価格 | ◎ (低コスト) | △ | △ |\n| 日本語 | ○ | ◎ | ◎ |',
   '2026-04-13'),

  ('moonshot', 'api',
   'Moonshot AI API ガイド',
   E'## API アクセス\n\n**Moonshot AI API** は OpenAI 互換形式で提供。Python SDK もOpenAI SDK を流用可能。\n\n```\nベースURL: https://api.moonshot.cn/v1\n認証: Authorization: Bearer {API_KEY}\n```\n\n## OpenAI SDK で使用 (推奨)\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_MOONSHOT_API_KEY",\n    base_url="https://api.moonshot.cn/v1"\n)\n\n# 長文ドキュメント処理の例\nresponse = client.chat.completions.create(\n    model="moonshot-v1-128k",\n    messages=[\n        {\n            "role": "system",\n            "content": "あなたは優秀な文書分析AIです。"\n        },\n        {\n            "role": "user",\n            "content": f"以下の文書全体を要約してください:\\n\\n{long_document_content}"\n        }\n    ],\n    temperature=0.3\n)\nprint(response.choices[0].message.content)\n```\n\n## ファイルアップロード (Files API)\n\n```python\n# PDFやWordをそのままアップロードして処理\nfile_obj = client.files.create(\n    file=open("contract.pdf", "rb"),\n    purpose="file-extract"\n)\n\n# ファイル内容を取得してコンテキストとして使用\nfile_content = client.files.content(file_obj.id)\n```\n\n## 主要エンドポイント\n\n```http\n# テキスト生成\nPOST /v1/chat/completions\nAuthorization: Bearer {API_KEY}\n\n{\n  "model": "moonshot-v1-128k",\n  "messages": [\n    {"role": "user", "content": "200ページの報告書を3点で要約して"}\n  ],\n  "max_tokens": 4096,\n  "stream": true\n}\n```\n\n## 料金 (2026年4月)\n\n| モデル | Input | Output |\n|--------|-------|--------|\n| moonshot-v1-8k | ¥0.012/1K | ¥0.012/1K |\n| moonshot-v1-32k | ¥0.024/1K | ¥0.024/1K |\n| moonshot-v1-128k | ¥0.060/1K | ¥0.060/1K |\n\n※ 人民元建て。新規登録で無料クレジット付与あり\n\n## APIキー取得\n\n1. https://platform.moonshot.cn にアクセス\n2. 「ログイン → APIキー管理」でキー発行\n3. 国際版は英語UIで利用可能\n\n## 日本語リソース\n\n- 公式サイト: https://kimi.moonshot.cn\n- API docs: https://platform.moonshot.cn/docs\n- 開発者コミュニティ: Discord / X @MoonshotAI',
   '2026-04-13')
ON CONFLICT (provider, category) DO UPDATE
  SET title = EXCLUDED.title,
      content = EXCLUDED.content,
      published_at = EXCLUDED.published_at;
