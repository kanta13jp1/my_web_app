-- AI大学: Lmsys (Chatbot Arena) コンテンツ seed
-- Windows版#63 2026-04-16

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'lmsys',
  'overview',
  'Lmsys / Chatbot Arena とは',
  E'## Lmsys / LMSYS Org とは\n\nLMSYS Org（Large Model Systems Organization）は、UC Berkeley を中心とした研究グループ。\n**Chatbot Arena** の運営で世界的に知られており、AIモデルの公正な評価基盤として機能している。\n\n## 主な成果\n\n| プロジェクト | 概要 |\n|---|---|\n| **Chatbot Arena** | 人間によるブラインド比較でモデルをEloレーティング評価 |\n| **Vicuna** | LLaMAベースの高性能チャットモデル（オープンソース） |\n| **FastChat** | LLMサービング・デプロイフレームワーク |\n| **SGLang** | 構造化生成のための高速推論フレームワーク |\n\n## なぜ重要か\n\n- **透明性の象徴**: GPT/Claude/Gemini を同条件で比較できる唯一の公開ベンチマーク\n- **学術的中立性**: 商業的バイアスなしにモデルを評価\n- **オープン**: 全データ・コードをGitHubで公開\n- **影響力**: AI業界のモデル選定に直接影響するEloランキングを管理',
  'https://lmsys.org/',
  '2026-04-16',
  1,
  true
),
(
  'lmsys',
  'models',
  'Lmsys のモデル・プロジェクト',
  E'## 主要モデル・プロジェクト\n\n### Vicuna シリーズ\n\n| モデル | パラメータ | ベース | 特徴 |\n|---|---|---|---|\n| Vicuna-7B | 7B | LLaMA | GPT-3.5に近い性能・軽量 |\n| Vicuna-13B | 13B | LLaMA | 高品質な会話性能 |\n| Vicuna-33B | 33B | LLaMA | GPT-4に近い品質 |\n\n### Chatbot Arena ELO ランキング（参考）\n\nArenaでは毎日数十万回の比較が行われ、常時更新されるEloレーティングで\nモデルの実力を可視化している。トップは常に GPT-4o / Claude 3.5 / Gemini 1.5 Pro が競っている。\n\n### FastChat フレームワーク\n\n```bash\n# FastChat でモデルをサーブ\npip install fastchat\npython -m fastchat.serve.cli --model-path vicuna-7b-v1.5\n```\n\n### SGLang（推論加速）\n\n- RadixAttention によるKVキャッシュ再利用\n- 通常の推論より最大5倍高速\n- 構造化出力（JSON/正規表現）のネイティブサポート',
  'https://github.com/lm-sys/FastChat',
  '2026-04-16',
  2,
  true
),
(
  'lmsys',
  'api',
  'Chatbot Arena API・FastChat の使い方',
  E'## FastChat API の使い方\n\nFastChat は OpenAI 互換 API として動作するため、既存コードをほぼそのまま使える。\n\n### セットアップ\n\n```bash\npip install fastchat\n\n# コントローラー起動\npython -m fastchat.serve.controller\n\n# モデルワーカー起動\npython -m fastchat.serve.model_worker --model-path vicuna-7b-v1.5\n\n# OpenAI互換APIサーバー起動\npython -m fastchat.serve.openai_api_server --host 0.0.0.0 --port 8000\n```\n\n### Python での呼び出し (OpenAI SDK互換)\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="EMPTY",\n    base_url="http://localhost:8000/v1"\n)\n\nresponse = client.chat.completions.create(\n    model="vicuna-7b-v1.5",\n    messages=[{"role": "user", "content": "Hello!"}]\n)\nprint(response.choices[0].message.content)\n```\n\n## Chatbot Arena でのモデル比較\n\nhttps://arena.lmsys.org/ でブラウザから直接2モデルの匿名比較が可能。\n\n## Together AI 経由での Vicuna API\n\nVicuna は Together AI でもホスティングされており、APIキーで利用可能:\n\n```python\nclient = OpenAI(\n    api_key="<TOGETHER_API_KEY>",\n    base_url="https://api.together.xyz/v1"\n)\nresponse = client.chat.completions.create(\n    model="lmsys/vicuna-13b-v1.5",\n    messages=[{"role": "user", "content": "Hello!"}]\n)\n```',
  'https://github.com/lm-sys/FastChat',
  '2026-04-16',
  3,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = now();
