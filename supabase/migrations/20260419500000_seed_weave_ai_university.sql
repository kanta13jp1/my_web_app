-- PS版#3 Session 9: Weights & Biases Weave — LLM オブザーバビリティプラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'weave',
  'overview',
  'W&B Weave — LLM アプリのデバッグ・評価・改善プラットフォーム',
  E'## W&B Weave とは\n\nWeave は機械学習実験管理ツール **Weights & Biases (W&B)** が提供する\n**LLM アプリケーション特化のオブザーバビリティプラットフォーム**。\n2024 年に W&B の新製品としてローンチ。\n\n「LLM チェーン・エージェントの動作を完全に可視化・評価する」ツールとして\nLangSmith (LangChain 製) の有力対抗馬。W&B が ML エンジニアに深く普及しているため\n既存ユーザーがシームレスに LLM 開発に移行できる。\n\n## LangSmith との比較\n\n| 観点 | W&B Weave | LangSmith |\n|------|----------|----------|\n| **背景** | W&B (ML実験管理大手) | LangChain (LLMフレームワーク) |\n| **強み** | ML実験管理との統合 | LangChain との深い連携 |\n| **フレームワーク依存** | 無し (任意の LLM 対応) | LangChain 依存強め |\n| **UI** | W&B ダッシュボード統合 | 独立 UI |\n| **料金** | W&B プランと統合 | 独立プラン |\n\n## 主な機能\n\n- **Traces**: LLM 呼び出し・チェーン全体のトレース記録\n- **Evals**: カスタム評価指標でモデル出力品質を数値化\n- **Datasets**: 評価データセットのバージョン管理\n- **Leaderboards**: 複数モデル・プロンプトの比較表\n- **Feedback**: 人間フィードバックの収集・管理\n\n## 活用事例\n\n- **RAG パイプライン評価**: 検索精度・回答品質をスコア化\n- **プロンプトバージョン管理**: A/B テストで最良プロンプトを特定\n- **コスト追跡**: API コールのトークン数・費用を可視化\n- **エージェントデバッグ**: ツール呼び出しの成功/失敗を追跡',
  '2026-04-20'
),
(
  'weave',
  'models',
  'W&B Weave 機能・統合一覧',
  E'## コアコンポーネント\n\n### @weave.op() — 関数トレース\n```python\nimport weave\n\nweave.init("my-ai-project")\n\n@weave.op()  # このデコレータで関数を自動トレース\ndef call_llm(prompt: str) -> str:\n    response = client.chat.completions.create(\n        model="gpt-4o",\n        messages=[{"role": "user", "content": prompt}]\n    )\n    return response.choices[0].message.content\n\n# 呼び出すと Weave ダッシュボードに自動記録\nresult = call_llm("AI大学の特徴を教えて")\n```\n\n### Evaluations — 品質評価\n```python\n# 評価データセット定義\ndataset = weave.Dataset(name="ai_university_qa", rows=[\n    {"question": "Anthropic とは？", "expected": "Claude を作る AI 安全性企業"},\n    {"question": "RAG とは？", "expected": "検索拡張生成"},\n])\n\n# スコアリング関数\n@weave.op()\ndef factuality_scorer(output: str, expected: str) -> dict:\n    overlap = len(set(output.split()) & set(expected.split()))\n    score = overlap / max(len(expected.split()), 1)\n    return {"factuality": score}\n\n# 評価実行\nevaluation = weave.Evaluation(dataset=dataset, scorers=[factuality_scorer])\nresults = await evaluation.evaluate(call_llm)\n```\n\n## 対応フレームワーク\n\n- **OpenAI** — API 呼び出しを自動インターセプト\n- **Anthropic** — Claude 呼び出しをトレース\n- **LangChain** — チェーン全体をトレース\n- **LlamaIndex** — RAG パイプラインを可視化\n- **DSPy** — プログラマティックプロンプトの最適化記録\n- **Google Gemini** — Gemini API トレース\n\n## ダッシュボード機能\n\n| 機能 | 内容 |\n|------|------|\n| **Traces** | LLM 呼び出しのツリー表示 (入力/出力/レイテンシ/コスト) |\n| **Evals** | スコア比較表・時系列グラフ |\n| **Datasets** | 評価セットの CRUD + バージョン管理 |\n| **Leaderboard** | モデル/プロンプト比較ランキング |\n\n## 料金\n\n- **Free**: 月 100GB ストレージ・チーム 3 人まで\n- **Pro**: 月額 $50/人〜 (無制限ストレージ)\n- **Enterprise**: 要相談 (SSO/カスタム保持期間)',
  '2026-04-20'
),
(
  'weave',
  'api',
  'W&B Weave 使い方',
  E'## インストール\n\n```bash\npip install weave wandb\nwandb login  # W&B アカウントで認証\n```\n\n## 基本トレース\n\n```python\nimport weave\nfrom anthropic import Anthropic\n\nweave.init("ai-university-monitoring")\nclient = Anthropic()\n\n@weave.op()\ndef ask_claude(question: str) -> str:\n    """Claude に質問してトレースを記録"""\n    response = client.messages.create(\n        model="claude-sonnet-4-6",\n        max_tokens=1024,\n        messages=[{"role": "user", "content": question}]\n    )\n    return response.content[0].text\n\n# 自動トレース開始\nanswer = ask_claude("LlamaIndex の特徴は？")\nprint(answer)\n# → https://wandb.ai/your-project でトレースを確認\n```\n\n## RAG パイプライン全体をトレース\n\n```python\nimport weave\nfrom qdrant_client import QdrantClient\nfrom anthropic import Anthropic\n\nweave.init("rag-pipeline")\nqdrant = QdrantClient(host="localhost", port=6333)\nclaude = Anthropic()\n\n@weave.op()\ndef search_docs(query: str) -> list[str]:\n    """Qdrant でセマンティック検索"""\n    # ... 検索ロジック\n    return [doc.payload["text"] for doc in results]\n\n@weave.op()\ndef generate_answer(question: str, context: list[str]) -> str:\n    """Claude でRAG回答生成"""\n    prompt = f"Context:\\n{chr(10).join(context)}\\n\\nQuestion: {question}"\n    response = claude.messages.create(\n        model="claude-sonnet-4-6",\n        max_tokens=1024,\n        messages=[{"role": "user", "content": prompt}]\n    )\n    return response.content[0].text\n\n@weave.op()\ndef rag_pipeline(question: str) -> str:\n    """RAG 全体フロー (子トレースを含む)"""\n    docs = search_docs(question)\n    return generate_answer(question, docs)\n\n# パイプライン実行 → Weave で全 span 可視化\nresult = rag_pipeline("AI大学で人気のプロバイダーは？")\n```\n\n## 評価パイプライン\n\n```python\nimport weave\nimport asyncio\n\nweave.init("eval-run")\n\ntest_cases = weave.Dataset(name="ai_qa_v1", rows=[\n    {"q": "OpenAI の最新モデルは？", "expected": "GPT-4o"},\n    {"q": "Anthropic の主力は？", "expected": "Claude"},\n])\n\n@weave.op()\ndef accuracy(output: str, expected: str) -> dict:\n    return {"correct": expected.lower() in output.lower()}\n\nevaluation = weave.Evaluation(dataset=test_cases, scorers=[accuracy])\nasyncio.run(evaluation.evaluate(ask_claude))\n# → 正解率・失敗ケースをダッシュボードで確認\n```\n\n## 活用シーン\n\n- **AI 大学 QA 品質管理**: RAG パイプラインの回答精度を継続監視\n- **プロンプト最適化**: A/B テストで最良プロンプトを自動選択\n- **コスト可視化**: Claude / GPT-4o の API コストをリアルタイム追跡',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
