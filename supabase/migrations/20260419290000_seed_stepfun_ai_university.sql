-- PS版#3 Session 1: StepFun (阶跃星辰) — MoE アーキテクチャ・OpenAI 互換 API
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'stepfun',
  'overview',
  'StepFun (阶跃星辰) — 次世代 MoE モデルの中国発スタートアップ',
  E'## StepFun とは\n\nStepFun（阶跃星辰）は 2023 年に上海で設立された AI スタートアップ。\n元 Microsoft 副社長の**江大欣（Jiang Daxin）**が創業し、**テキスト・画像・動画・音楽・音声** を横断するマルチモーダル AI モデルを開発している。\n\n「人類を次のステップへ（Step forward）」をビジョンに掲げ、高性能かつコスト効率の高い MoE（Mixture of Experts）モデルで注目を集めている。\n\n## 主な特徴\n\n- **MoE アーキテクチャ**: 196B パラメータ中、1 トークンあたり約 11B のみ活性化 → 高性能・低コスト\n- **256K トークンコンテキスト**: 長文書・長対話に強い\n- **OpenAI 互換 API**: 既存の OpenAI SDK をそのまま流用可能\n- **マルチモーダル**: テキスト・画像・動画・音楽に対応\n\n## 主要マイルストーン\n\n- 2023年: 設立\n- 2024年: Step-1、Step-2 リリース\n- 2025年: Step-3 リリース（フロンティアモデル）\n- 2026年1月: **Step 3.5 Flash** リリース（モバイル・高頻度用途向け）',
  '2026-04-19'
),
(
  'stepfun',
  'models',
  'StepFun モデル一覧',
  E'## Step 3.5 Flash（最新推奨）\n\n- **アーキテクチャ**: Sparse MoE（196B 総パラメータ・11B 活性化）\n- **コンテキスト**: 256K tokens\n- **スループット**: 100–300 tokens/sec\n- **特徴**: モバイル・高頻度インタラクション向けに最適化\n- **ネイティブ Tool Calling**: エージェント構築に対応\n- **入力料金**: $0.10 / 1M tokens\n- **出力料金**: $0.30 / 1M tokens\n- **リリース**: 2026年1月29日\n\n## Step 3（フロンティア）\n\n- **用途**: 高度な推論・研究・エンタープライズ\n- **特徴**: ベンチマーク最高水準（数学・コーディング・科学）\n- **コンテキスト**: 256K tokens\n\n## Step-2（旧世代）\n\n- 安定版、長期サポート中\n\n## マルチモーダルモデル\n\n- **Step-1V**: 画像理解\n- **Step-2V**: マルチモーダル推論\n- **動画・音楽生成**: 独自モデルで対応',
  '2026-04-19'
),
(
  'stepfun',
  'api',
  'StepFun API 使い方',
  E'## エンドポイント\n\nStepFun は OpenAI 互換 API を提供。既存の OpenAI SDK を base_url だけ変えて利用可能。\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_STEPFUN_API_KEY",\n    base_url="https://api.stepfun.com/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="step-3-5-flash",\n    messages=[\n        {"role": "user", "content": "量子コンピュータを小学生に説明して"}\n    ]\n)\nprint(response.choices[0].message.content)\n```\n\n## 料金\n\n| モデル | 入力 | 出力 |\n|--------|------|------|\n| Step 3.5 Flash | $0.10 / 1M | $0.30 / 1M |\n| Step 3 | 要確認 | 要確認 |\n\n## Tool Calling\n\n```python\ntools = [\n    {\n        "type": "function",\n        "function": {\n            "name": "get_weather",\n            "description": "現在の天気を取得",\n            "parameters": {\n                "type": "object",\n                "properties": {"location": {"type": "string"}},\n                "required": ["location"]\n            }\n        }\n    }\n]\n\nresponse = client.chat.completions.create(\n    model="step-3-5-flash",\n    messages=[{"role": "user", "content": "東京の天気は？"}],\n    tools=tools\n)\n```\n\n## 活用シーン\n\n- **AI エージェント**: Tool Calling × 長コンテキストでマルチステップ処理\n- **コードアシスタント**: 高精度なコーディング支援\n- **推論パイプライン**: OpenAI から低コストで移行可能',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
