-- PS版#3 Session 10: Argilla — LLM データアノテーション・フィードバック収集プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'argilla',
  'overview',
  'Argilla — LLM 学習データのアノテーション・品質管理OSS',
  E'## Argilla とは\n\nArgilla は 2021 年設立のスペイン発スタートアップ。\n**LLM の学習データ品質を向上させる**ためのオープンソース・データアノテーション・プラットフォーム。\n\n「データ中心 AI (Data-centric AI)」のアプローチを実践するためのツールとして、\n特に RLHF (人間フィードバックによる強化学習) や SFT (教師あり微調整) の\n学習データ収集・品質管理に特化している。\n\nOSS で GitHub スター 4,000+。Hugging Face が Argilla チームを採用 (2024年)。\n現在は Hugging Face のエコシステムに深く統合されている。\n\n## 主な特徴\n\n- **テキストアノテーション**: 分類・NER・関係抽出・QA 等\n- **LLM フィードバック**: 人間が AI 出力を評価・比較 (RLHF データ)\n- **アクティブラーニング**: 不確実なサンプルを優先してアノテーション\n- **チームコラボレーション**: 複数アノテーターの作業を統合\n- **Hugging Face 統合**: データセットを直接 HF Hub へプッシュ\n\n## 活用事例\n\n- **RLHF データ収集**: 人間が AI 回答 A/B を比較して好みを記録\n- **SFT データ作成**: Instruction-following データを人間がキュレーション\n- **RAG 評価**: 検索結果の関連性を人間がラベル付け\n- **バイアス検出**: モデル出力の偏りを人間が発見・記録\n- **多言語データ**: 日本語 LLM 学習データの品質管理',
  '2026-04-20'
),
(
  'argilla',
  'models',
  'Argilla 機能・データ形式一覧',
  E'## コアコンセプト: Records & Fields\n\n### Dataset タイプ\n\n| タイプ | 用途 | 例 |\n|--------|------|----|\n| **TextClassification** | テキスト分類 | センチメント/カテゴリ |\n| **TokenClassification** | NER/品詞 | エンティティ抽出 |\n| **Text2Text** | 生成評価 | 要約・翻訳品質 |\n| **FeedbackDataset** | LLM 出力評価 | RLHF・SFT データ |\n\n### FeedbackDataset — LLM 評価専用\n\n```python\nimport argilla as rg\n\n# 1. データセット定義\ndataset = rg.FeedbackDataset(\n    fields=[\n        rg.TextField(name="prompt", title="ユーザーの質問"),\n        rg.TextField(name="response_a", title="モデルAの回答"),\n        rg.TextField(name="response_b", title="モデルBの回答"),\n    ],\n    questions=[\n        rg.RatingQuestion(\n            name="quality",\n            title="回答の質 (1=悪い, 5=優秀)",\n            values=[1, 2, 3, 4, 5]\n        ),\n        rg.RankingQuestion(\n            name="preference",\n            title="どちらの回答が好ましい？",\n            values=["response_a", "response_b"]\n        ),\n        rg.TextQuestion(\n            name="feedback",\n            title="改善点があれば記述"\n        ),\n    ]\n)\n```\n\n### Hugging Face 統合\n\n```python\n# Argilla → HF Hub への直接プッシュ\ndataset.push_to_huggingface("kanta13jp1/ai-university-rlhf")\n\n# HF Hub → Argilla への読み込み\ndataset = rg.FeedbackDataset.from_huggingface("kanta13jp1/ai-university-rlhf")\n```\n\n## アノテーションワークフロー\n\n1. **データ準備**: LLM が生成した回答を Record として追加\n2. **アノテーション**: Web UI でチームが評価\n3. **品質管理**: Inter-annotator Agreement でばらつきを検出\n4. **エクスポート**: JSONL/CSV/HF Dataset 形式でエクスポート\n5. **学習**: エクスポートデータでファインチューニング (Predibase 等)\n\n## 料金\n\n- **OSS (セルフホスト)**: 完全無料 (Docker で起動)\n- **Argilla Cloud**: 無料枠あり (Public Workspaces)\n- **Enterprise**: 要相談 (オンプレ・SLA)',
  '2026-04-20'
),
(
  'argilla',
  'api',
  'Argilla 使い方',
  E'## インストール\n\n```bash\n# Docker でセルフホスト\ndocker run -d \\\n  --name argilla \\\n  -p 6900:6900 \\\n  argilla/argilla-quickstart:latest\n# → http://localhost:6900 (admin/12345678)\n\n# Python クライアント\npip install argilla\n```\n\n## LLM 回答の評価データ収集\n\n```python\nimport argilla as rg\nfrom anthropic import Anthropic\n\n# Argilla に接続\nrg.init(api_url="http://localhost:6900", api_key="admin.apikey")\n\nclient = Anthropic()\n\n# 評価用データセット定義\ndataset = rg.FeedbackDataset(\n    fields=[\n        rg.TextField(name="question"),\n        rg.TextField(name="answer"),\n    ],\n    questions=[\n        rg.RatingQuestion(\n            name="accuracy",\n            title="回答の正確さ (1-5)",\n            values=[1, 2, 3, 4, 5]\n        ),\n        rg.LabelQuestion(\n            name="category",\n            title="回答のカテゴリ",\n            labels=["excellent", "good", "fair", "poor"]\n        ),\n    ]\n)\ndataset.push_to_argilla(name="claude-evaluation", workspace="default")\n\n# AI 大学の質問に Claude が回答 → アノテーション待ちキューに追加\nquestions = [\n    "Pineconeとは何ですか？",\n    "LangChainの主な機能は？",\n    "RAGの仕組みを説明してください",\n]\n\nrecords = []\nfor q in questions:\n    response = client.messages.create(\n        model="claude-sonnet-4-6",\n        max_tokens=512,\n        messages=[{"role": "user", "content": q}]\n    )\n    records.append(rg.FeedbackRecord(\n        fields={"question": q, "answer": response.content[0].text}\n    ))\n\ndataset.add_records(records)\nprint(f"{len(records)} 件をアノテーション待ちキューに追加")\n```\n\n## アノテーション完了データをエクスポート\n\n```python\nimport argilla as rg\n\nrg.init(api_url="http://localhost:6900", api_key="admin.apikey")\n\n# アノテーション済みデータを取得\ndataset = rg.FeedbackDataset.from_argilla("claude-evaluation")\nannotated = dataset.filter_by(response_status="submitted")\n\n# Hugging Face にプッシュ (Predibase でファインチューニングに使用)\nannotated.push_to_huggingface("kanta13jp1/claude-sft-data")\n\n# またはローカルに JSONL で保存\nimport json\nwith open("sft_data.jsonl", "w") as f:\n    for record in annotated.records:\n        f.write(json.dumps({\n            "prompt": record.fields["question"],\n            "completion": record.fields["answer"],\n            "rating": record.responses[0].values["accuracy"]\n        }, ensure_ascii=False) + "\\n")\n```\n\n## 活用シーン\n\n- **AI 大学 QA データ構築**: プロバイダー知識の正確な QA ペアを人手でキュレーション\n- **Claude EF 改善**: EF の出力を Argilla で評価 → Predibase でファインチューン\n- **多言語評価**: 日本語 AI 回答の品質を日本語話者がアノテーション',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
