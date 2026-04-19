-- PS版#3 Session 9: Oxen AI — ML データのためのバージョン管理システム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'oxen_ai',
  'overview',
  'Oxen AI — 機械学習データのための Git ライクなバージョン管理',
  E'## Oxen AI とは\n\nOxen AI は 2022 年設立のサンフランシスコ発スタートアップ。\n「**ML データの Git**」をコンセプトに、\n画像・テキスト・CSV など大容量 ML データセットをバージョン管理するプラットフォーム。\n\nGit は数行のコード変更に最適化されているが、100GB の画像データセットには向いていない。\nOxen は Git のインターフェースを維持しながら大容量データを効率的に扱う。\n\n累計調達 $3.5M+。Oxen Hub (GitHub 的な公開リポジトリ) でコミュニティ形成中。\n\n## Git との違い\n\n| 観点 | Git | Oxen |\n|------|-----|------|\n| **最適化対象** | テキストコード | 画像/CSV/Parquet/JSON |\n| **大容量ファイル** | Git LFS (遅い・複雑) | ネイティブ高速 |\n| **データ閲覧** | raw テキストのみ | 画像プレビュー・表形式CSV表示 |\n| **差分表示** | テキスト diff | 行/列レベルの データ diff |\n| **クローン速度** | 遅い | 部分クローン (必要ファイルのみ) |\n\n## 主な特徴\n\n- **oxen clone / push / pull**: Git 同様のコマンドで動作\n- **部分クローン**: 必要なファイルや行だけを取得\n- **データ diff**: CSV の行追加/削除/変更を可視化\n- **Oxen Hub**: 公開データセットのマーケットプレイス\n- **スキーマ管理**: CSV/Parquet のカラム型を追跡\n- **ブランチ**: データセットも git flow でブランチ管理\n\n## 活用事例\n\n- **学習データのバージョン管理**: v1/v2/v3 のデータセットを追跡\n- **チーム共同アノテーション**: 複数人がデータに加えた変更をマージ\n- **実験の再現性**: モデルとデータを同一コミットに紐付け\n- **LLM 評価データ管理**: QA ペアをバージョン管理で継続改善',
  '2026-04-20'
),
(
  'oxen_ai',
  'models',
  'Oxen AI 機能・コマンド一覧',
  E'## コアコマンド\n\n```bash\n# リポジトリ初期化\noxen init\noxen remote add origin https://hub.oxen.ai/my-org/dataset\n\n# ファイルを追加してコミット\noxen add images/  # 画像フォルダを丸ごと追加\noxen add train.csv\noxen commit -m "v1.0 - initial dataset"\noxen push origin main\n\n# クローン (部分クローンも可)\noxen clone https://hub.oxen.ai/my-org/dataset\noxen clone --shallow  # 最新版のみ (履歴なし)\noxen clone --subset "images/train/*.jpg"  # 特定パスのみ\n```\n\n## データ差分の確認\n\n```bash\n# CSV の行レベル diff\noxen diff train.csv\n# → Added: 150 rows, Removed: 3 rows, Modified: 12 rows\n\n# ブランチで実験\noxen checkout -b experiment-augmentation\noxen add augmented_data/\noxen commit -m "add augmented images"\noxen merge main\n```\n\n## Python API\n\n```python\nfrom oxen import RemoteRepo\n\n# Oxen Hub のリポジトリに接続\nrepo = RemoteRepo(\"my-org/ai-university-dataset\")\n\n# ファイル一覧\nfiles = repo.ls(\"train/\")\nprint(files)\n\n# 特定バージョンのファイルをダウンロード\nrepo.download(\"train.csv\", revision=\"v1.0\")\n\n# CSV を DataFrame として読み込み\nimport pandas as pd\ndf = pd.read_csv(repo.get_url(\"train.csv\"))\n```\n\n## Oxen Hub の主な公開データセット\n\n| データセット | 規模 | 用途 |\n|-------------|------|------|\n| ImageNet-1k | 1.2M 画像 | CV 学習 |\n| LLM Eval QA | 50k QA ペア | LLM 評価 |\n| RLHF Feedback | 200k ペア | Preference データ |\n| Text Embeddings | 10M テキスト | RAG 実験 |\n\n## データフレームサポート\n\n- **CSV / TSV**: 行レベル diff・列型スキーマ追跡\n- **Parquet**: 大容量列指向データ\n- **JSONL**: LLM 学習データ (instruction/output フォーマット)\n- **画像**: JPEG/PNG プレビュー + BBox アノテーション表示\n- **音声**: MP3/WAV のメタデータ追跡\n\n## 料金\n\n- **OSS CLI**: 完全無料 (セルフホスト可)\n- **Oxen Hub 無料**: 10GB プライベート\n- **Oxen Hub Pro**: $15/月 (100GB)\n- **Enterprise**: 要相談 (プライベートクラスタ)',
  '2026-04-20'
),
(
  'oxen_ai',
  'api',
  'Oxen AI 使い方',
  E'## インストール\n\n```bash\n# macOS/Linux\nbrew install oxen-ai/tap/oxen\n\n# Windows\nwinget install Oxen.Oxen\n\n# Python クライアント\npip install oxen\n\n# 認証\noxen config --set user.email "your@email.com"\noxen config --set user.name "Your Name"\n# Oxen Hub でトークン取得後:\nexport OXEN_TOKEN="your_api_token"\n```\n\n## LLM 評価データセットの構築\n\n```bash\n# 1. データセットリポジトリ作成\nmkdir ai-eval-dataset && cd ai-eval-dataset\noxen init\noxen remote add origin https://hub.oxen.ai/kanta13jp1/ai-eval\n\n# 2. 評価データを CSV で管理\ncat > eval_data.csv << EOF\nquestion,expected,category\nAnthropicとは？,Claude開発のAI安全性企業,company_info\nRAGとは？,検索拡張生成,technical_term\nGPT-4oとは？,OpenAIの最新マルチモーダルモデル,model_info\nEOF\n\noxen add eval_data.csv\noxen commit -m "initial eval dataset v1.0"\noxen push origin main\n```\n\n## Python で評価データを管理・更新\n\n```python\nimport oxen\nimport pandas as pd\nfrom oxen import LocalRepo\n\nrepo = LocalRepo(\"./ai-eval-dataset\")\n\n# 既存データ読み込み\ndf = pd.read_csv(\"eval_data.csv\")\n\n# 新しい評価データを追加\nnew_rows = [\n    {\"question\": \"LangChainとは？\", \"expected\": \"LLMアプリフレームワーク\", \"category\": \"technical_term\"},\n    {\"question\": \"Qdrantとは？\", \"expected\": \"Rust製ベクターDB\", \"category\": \"technical_term\"},\n]\ndf = pd.concat([df, pd.DataFrame(new_rows)], ignore_index=True)\ndf.to_csv(\"eval_data.csv\", index=False)\n\n# コミット\nrepo.add(\"eval_data.csv\")\nrepo.commit(\"add 2 new evaluation cases\")\nrepo.push()\n\n# 差分確認\nprint(repo.diff(\"eval_data.csv\"))\n# → Added: 2 rows\n```\n\n## W&B Weave との統合 (評価データ管理)\n\n```python\nimport oxen\nimport weave\n\nweave.init("ai-university")\n\n# Oxen Hub から評価データを取得\nfrom oxen import RemoteRepo\noxen_repo = RemoteRepo("kanta13jp1/ai-eval")\noxen_repo.download("eval_data.csv")\n\nimport pandas as pd\ndf = pd.read_csv("eval_data.csv")\n\n# Weave Dataset として登録\ndataset = weave.Dataset(\n    name="ai_university_eval",\n    rows=df.to_dict("records")\n)\n\n# → Oxen がデータのバージョン管理\n# → Weave がモデルの評価・トレースを管理\n```\n\n## 活用シーン\n\n- **AI 大学評価データ管理**: QA ペアを Oxen でバージョン管理 + Weave で評価\n- **競馬データ履歴**: レース結果 CSV を全期間バージョン管理\n- **チームアノテーション**: 複数人が付けたラベルを branch + merge で統合',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
