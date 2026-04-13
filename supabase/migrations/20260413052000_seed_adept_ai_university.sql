-- Windows版#69: AI大学55社目 — Adept AI (ACT/Fuyu)
-- PCブラウザ/デスクトップを操作するAIエージェント先駆者。Fuyu-8BはOSS公開。

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order, is_active)
VALUES
(
  'adept',
  'overview',
  'Adept AI とは',
  E'## Adept AI とは\n\nAdept AIは**2022年にサンフランシスコで創業**された、コンピューターを自律操作するAIエージェントの先駆的企業。\n「Attention Is All You Need」論文の共著者である**Ashish VaswaniとNiki Parmar**、そして元OpenAI副社長の**David Luan**が設立した。\n単なるテキスト生成ではなく、**ブラウザやデスクトップアプリを人間と同じように操作する**「AIチームメイト」の実現を目指した。\n\n総調達額は**4億1,500万ドル**（シリーズA 6,500万ドル＋シリーズB 3億5,000万ドル）。\n2024年6月、Amazon.comが共同創業者チームを引き抜く「リバース・アクワイヤー」を実施し、AdeptのマルチモーダルモデルとデータセットをAmazonがライセンス取得した（FTCが審査）。\nAdeptは独立企業として継続し、2024年の年間収益は約7,500万ドルに達している。\n\n## 主要プロダクト\n- **ACT-1**: 2022年発表。Webブラウザ・デスクトップ内でのタスク実行に特化した初の大規模汎用エージェント\n- **ACT-2**: Fuyu基盤のアップグレード版。フォーム入力・請求書処理・スケジュール自動化に対応\n- **Fuyu-8B**: 2023年10月にオープンソース公開。専用画像エンコーダー不要のデコーダー専用マルチモーダルモデル\n- **Fuyu-Heavy**: エンタープライズ向けプロプライエタリ版。Amazonのデジタルエージェント基盤に採用\n\n## 強み\n- **ブラウザ・PC操作エージェントの先駆者**: OpenAI Operatorより2年以上早く実用化\n- **UI理解に特化したアーキテクチャ**: スクリーンショットのUI要素をネイティブに解釈\n- **Fuyu-8B (Apache 2.0)**: ファインチューニング可能なOSSモデルとして公開済み\n- **Amazon連携**: AWS上のエンタープライズ自動化ソリューションとして展開中\n\n> 公式: https://www.adept.ai/ | Fuyu-8B: https://adept.ai/blog/fuyu-8b/',
  'https://www.adept.ai/',
  '2026-04-13',
  1,
  true
),
(
  'adept',
  'models',
  'Adept AI モデル一覧 (2026年)',
  E'## Adept AI モデルラインナップ\n\n| モデル | 種別 | 特徴 | 用途 |\n| :--- | :--- | :--- | :--- |\n| **ACT-1** | エージェント (2022) | 初の大規模汎用PCエージェント。ブラウザ・デスクトップを操作 | Webスクレイピング・フォーム入力・自動化タスク |\n| **ACT-2** | エージェント (2023) | Fuyu-Heavy基盤。請求書・文書処理に特化 | 財務・物流・医療の業務自動化 |\n| **Fuyu-8B** | マルチモーダルLLM (OSS) | 画像エンコーダー不要。任意解像度対応。<100ms応答 | VQA・UIグラウンディング・スクリーン理解 |\n| **Fuyu-Heavy** | マルチモーダルLLM (商用) | Fuyu-8Bの大型版。Amazonにライセンス供与済み | エンタープライズ自動化・クラウドエージェント |\n\n## Fuyu アーキテクチャの革新点\n\n従来のマルチモーダルモデル（CLIP画像エンコーダー＋LLMデコーダー）と異なり、\nFuyuは**画像パッチを線形投影してトランスフォーマー第1層に直接入力**するデコーダー専用設計。\n\n- **任意解像度**: スクリーンショットや文書の解像度に関わらずそのまま入力可能\n- **100ms以下の応答**: 大規模画像でも高速処理\n- **UIグラウンディング**: ボタン・テキストボックスなどUI要素の座標を精度よく特定\n- **ファインチューニング容易**: Apache 2.0ライセンスで完全商用利用可能\n\n## HuggingFace 利用\n\n```\nadept/fuyu-8b (HuggingFace Hub)\nライセンス: Apache 2.0\nパラメータ: 8B\n```\n\n> モデル詳細: https://huggingface.co/adept/fuyu-8b | ブログ: https://adept.ai/blog/fuyu-8b/',
  'https://huggingface.co/adept/fuyu-8b',
  '2026-04-13',
  2,
  true
),
(
  'adept',
  'api',
  'Adept AI API 入門 (Fuyu-8B)',
  E'## Adept AI の利用方法\n\nAdeptの公開APIは**エンタープライズ向けの問い合わせ販売**のみで、一般向けAPIキーは提供されていない。\ただし、**Fuyu-8B はHuggingFaceでOSS公開**されており、`transformers` ライブラリで直接利用可能。\n\n## Fuyu-8B Python サンプル (HuggingFace)\n\n```python\nfrom transformers import FuyuProcessor, FuyuForCausalLM\nfrom PIL import Image\nimport requests\n\n# モデル・プロセッサーのロード\nmodel_id = "adept/fuyu-8b"\nprocessor = FuyuProcessor.from_pretrained(model_id)\nmodel = FuyuForCausalLM.from_pretrained(model_id, device_map="auto")\n\n# 画像とテキストプロンプトを準備\nimage_url = "https://example.com/screenshot.png"\nimage = Image.open(requests.get(image_url, stream=True).raw)\ntext_prompt = "このスクリーンショットの「ログイン」ボタンはどこにありますか？"\n\n# 推論実行\ninputs = processor(text=text_prompt, images=image, return_tensors="pt")\ngeneration_output = model.generate(**inputs, max_new_tokens=100)\nresponse = processor.batch_decode(generation_output, skip_special_tokens=True)[0]\nprint(response)\n```\n\n## 料金 (2026年4月時点)\n\n| 利用形態 | 料金 |\n| :--- | :--- |\n| **Fuyu-8B (OSS)** | 無料 (自己ホスト、Apache 2.0) |\n| **Fuyu-Heavy / ACT-2 (エンタープライズ)** | 要問い合わせ (年間契約) |\n| **Amazon経由 (AWS)** | AWS Bedrock等で展開予定 |\n\n## エンタープライズ問い合わせ\n\n```\nメール: contact@adept.ai\n公式: https://www.adept.ai/\nユースケース: 財務・物流・医療の業務自動化\n```\n\n> API詳細: https://www.adept.ai/ | Fuyu-Heavy: https://www.adept.ai/blog/adept-fuyu-heavy/',
  'https://www.adept.ai/',
  '2026-04-13',
  3,
  true
)

ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  updated_at = now();
