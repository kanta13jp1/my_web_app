-- PS版#3 Session 3: Krutrim AI — インド初 AI ユニコーン・多言語特化モデル
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'krutrim',
  'overview',
  'Krutrim AI — インド発・22言語対応の AI ユニコーン',
  E'## Krutrim とは\n\nKrutrim（クルトリム）は 2023 年に Ola の創業者 **Bhavish Aggarwal** が設立したインドの AI スタートアップ。\n2024 年 1 月に **インド初 AI ユニコーン** ($10 億評価額) となり、わずか数ヶ月でインド最速ユニコーン記録を達成。\n\n名称はサンスクリット語で「人工物」を意味する。インドの多様な言語・文化に特化した AI モデルを構築し、インド固有の AI エコシステムの確立を目指す。\n\n## 主な特徴\n\n- **22+ インド言語**: ベンガル語・タミル語・マラヤーラム語・グジャラート語・マラーティー語ほか\n- **2 兆トークン訓練**: インド語データを中心に大規模学習\n- **25,000+ 開発者**: アクティブな開発者コミュニティ\n- **2,500 億 API コール**: 累計処理実績\n- **インド AI チップ計画**: Bodhi (AI) / Sarv (汎用) / Ojas (Edge) の 3 種チップを 2026 年以降リリース予定\n\n## 資金調達\n\n- 2024 年 1 月: $50M 調達（評価額 $1B → ユニコーン認定）\n- 出資: Matrix Partners India、Tiger Global ほか\n- 創業者 Bhavish Aggarwal: Ola、Ola Electric に続く 3 社目のユニコーン',
  '2026-04-19'
),
(
  'krutrim',
  'models',
  'Krutrim モデル一覧',
  E'## Krutrim モデル\n\n### Krutrim-1（初代）\n- **訓練データ**: 2 兆トークン（英語 + インド語）\n- **対応言語**: 22+ インド言語の理解 / 10 言語での生成\n- **特徴**: インド文化・法律・医療の知識に強い\n- **ベンチマーク**: HellaSwag / Indic NLP で競合を上回る\n\n### Krutrim SC（Specialized Compute）\n- エンタープライズ向け特化版\n- より高い精度と信頼性\n\n## Krutrim Cloud サービス\n\n| サービス | 内容 |\n|----------|------|\n| **LLM API** | Krutrim モデルへのテキスト API |\n| **翻訳 API** | 英語 ↔ インド語 22 言語 |\n| **音声 API** | インド語 STT / TTS |\n| **動画翻訳** | 英語 → インド語 動画ローカライズ |\n\n## インド AI チップ（2026〜）\n\n| チップ | 用途 |\n|--------|------|\n| **Bodhi** | AI 推論・学習 |\n| **Sarv** | 汎用コンピューティング |\n| **Ojas** | エッジ AI |\n\n※ 2026 年以降の段階的リリース予定',
  '2026-04-19'
),
(
  'krutrim',
  'api',
  'Krutrim API 使い方',
  E'## API アクセス\n\nKrutrim Cloud は 25,000+ 開発者に API を公開。OpenAI 互換エンドポイントを提供。\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_KRUTRIM_API_KEY",\n    base_url="https://cloud.olakrutrim.com/v1"\n)\n\n# インド語での LLM 呼び出し\nresponse = client.chat.completions.create(\n    model="Krutrim-spectre-v2",\n    messages=[\n        {"role": "system", "content": "You are a helpful assistant fluent in Hindi and English."},\n        {"role": "user", "content": "भारत के प्रमुख AI स्टार्टअप के बारे में बताइए"}\n    ]\n)\nprint(response.choices[0].message.content)\n```\n\n## 翻訳 API\n\n```bash\ncurl -X POST "https://cloud.olakrutrim.com/v1/translate" \\\n  -H "Authorization: Bearer YOUR_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "text": "Hello, how are you?",\n    "source_lang": "en",\n    "target_lang": "hi"\n  }''\n```\n\n## 料金\n\n- 登録後に従量課金 (Krutrim Cloud)\n- Developer プラン: 無料枠あり\n- Enterprise: 大量利用向けカスタム料金\n\n## 活用シーン\n\n- **インド市場向けアプリ**: 22 言語対応で全国カバー\n- **多言語チャットボット**: カスタマーサポートの地域化\n- **教育コンテンツ**: インド語 → 英語の教育素材翻訳\n- **農業 AI**: 農家向け現地語情報提供',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
