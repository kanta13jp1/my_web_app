-- PS版#3 Session 2: Baichuan AI (百川智能) — 医療 AI 特化の中国大規模モデル
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'baichuan',
  'overview',
  'Baichuan AI (百川智能) — 医療 AI 特化の中国 LLM プロバイダー',
  E'## Baichuan AI とは\n\nBaichuan AI（百川智能）は 2023 年に設立された中国の AI スタートアップ。\n元 Sogou（搜狗）CEO の **王小川（Wang Xiaochuan）** が創業し、中国版 OpenAI を目指す。\n\n当初は汎用 LLM（Baichuan-2, Baichuan-4）を開発していたが、2024〜2026 年にかけて**医療 AI に特化**し、業界最高水準の医療 LLM シリーズを構築。\n\n## 主な特徴\n\n- **医療 AI 特化**: 診断支援・医学知識 QA・臨床文書生成\n- **HealthBench Hard #1**: Baichuan-M3 (235B) が業界最高スコア達成\n- **オープンソース**: Apache 2.0 ライセンスで weights 公開\n- **W4 量子化対応**: コンシューマーグレード GPU でも動作\n\n## 資金調達\n\n- 2023年: 3億ドル超の資金調達\n- 出資: Alibaba、Tencent、Xiaomi、百度（Baidu）など\n- 評価額: 10 億ドル超（ユニコーン）',
  '2026-04-19'
),
(
  'baichuan',
  'models',
  'Baichuan AI モデル一覧',
  E'## Baichuan-M3（最新・推奨）\n\n- **パラメータ**: 235B（Qwen3 アーキテクチャベース）\n- **特化領域**: 医療・臨床・健康相談\n- **強化学習**: 医療ドメイン特化の RL で訓練\n- **HealthBench Hard**: #1 ランキング達成（2026年）\n- **ライセンス**: Apache 2.0\n- **デプロイ**: HuggingFace / Dr7.ai API / 私有デプロイ\n\n## Baichuan-M1（先代）\n\n- 医療シナリオ向けオープンソース LLM\n- 低リソース環境向け（W4 量子化対応）\n- arXiv 論文: 2502.12671\n\n## Baichuan-4（汎用）\n\n- 最上位の汎用 LLM\n- 中国語・英語バイリンガル対応\n- エンタープライズ向け商用 API\n\n## Baichuan-2（旧世代）\n\n- 13B / 53B パラメータ\n- オープンソース（Community License）\n- GitHub: baichuan-inc/Baichuan2',
  '2026-04-19'
),
(
  'baichuan',
  'api',
  'Baichuan AI API 使い方',
  E'## API アクセス方法\n\n### 1. Dr7.ai API（Baichuan-M3 医療モデル）\n\nBaichuan-M3 は Dr7.ai 経由で API アクセス可能。医療特化のエンドポイント。\n\n```bash\ncurl -X POST "https://api.dr7.ai/v1/chat/completions" \\\n  -H "Authorization: Bearer YOUR_DR7_API_KEY" \\\n  -H "Content-Type: application/json" \\\n  -d ''{\n    "model": "baichuan-m3",\n    "messages": [\n      {"role": "user", "content": "高血圧の一次治療薬として推奨されるのは？"}\n    ]\n  }''\n```\n\n### 2. Baichuan 公式 API（汎用モデル）\n\n```python\nimport baichuan_sdk as bc\n\nbc.api_key = "YOUR_BAICHUAN_API_KEY"\n\nresponse = bc.ChatCompletion.create(\n    model="Baichuan4",\n    messages=[{"role": "user", "content": "こんにちは"}]\n)\nprint(response.choices[0].message.content)\n```\n\n### 3. HuggingFace（自己ホスト）\n\n```bash\npip install transformers torch\n```\n\n```python\nfrom transformers import AutoTokenizer, AutoModelForCausalLM\n\ntokenizer = AutoTokenizer.from_pretrained("baichuan-inc/Baichuan2-13B-Chat")\nmodel = AutoModelForCausalLM.from_pretrained("baichuan-inc/Baichuan2-13B-Chat")\n```\n\n## 料金\n\n- 汎用 API: 従量課金（Baichuan 公式プラットフォーム登録必要）\n- 医療 API: Dr7.ai プランに準拠\n- オープンソース: 無料（セルフホスト）\n\n## 活用シーン\n\n- **医療 QA ボット**: 患者向け症状説明・薬剤情報\n- **臨床文書**: 診断書・退院サマリーの下書き生成\n- **中国語医療コンテンツ**: 中国語での医療情報提供',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
