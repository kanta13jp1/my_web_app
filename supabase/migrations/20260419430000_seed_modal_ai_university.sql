-- PS版#3 Session 7: Modal Labs — Python コードをクラウド GPU に即デプロイ
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'modal',
  'overview',
  'Modal Labs — Python デコレータ1行でクラウド GPU をサーバーレス実行',
  E'## Modal とは\n\nModal は 2021 年設立のニューヨーク発クラウドコンピューティングスタートアップ。\n「**Python デコレータ1行でローカルコードをクラウドで実行**」するという革新的なアプローチで、\nML エンジニア・AI 開発者から急速に支持を集めるサーバーレス GPU プラットフォーム。\n\nエリック・バーンハームソン（元 Stripe エンジニア）が創業。累計調達 $16M+。\n\n## 主な特徴\n\n- **@app.function()**: 既存 Python 関数をデコレータで即クラウド化\n- **GPU 選択自由**: A10G / A100 / H100 など 20+ GPU タイプ\n- **コールドスタート 1〜5秒**: 業界最速クラスのウォームアップ\n- **並列実行**: `.map()` で 1000 並列ジョブを数行で起動\n- **スケジューリング**: cron 形式の定期実行を Python で記述\n- **ボリューム**: 永続ストレージでモデルキャッシュ\n\n## 活用事例\n\n- **LLM 推論**: vLLM / Ollama をクラウド GPU で即サーブ\n- **画像生成**: Stable Diffusion / FLUX をバッチ実行\n- **データ処理**: 大規模 ETL を並列 GPU で高速化\n- **AI API バックエンド**: FastAPI + Modal で ML API を即公開',
  '2026-04-20'
),
(
  'modal',
  'models',
  'Modal 機能・GPU ラインナップ',
  E'## GPU オプション\n\n| GPU | VRAM | 用途 | 料金/時間 |\n|-----|------|------|-----------|\n| T4 | 16GB | 軽量推論 | ~$0.59 |\n| A10G | 24GB | 中規模推論 | ~$1.10 |\n| A100-40GB | 40GB | 大規模訓練 | ~$2.78 |\n| A100-80GB | 80GB | 最大モデル | ~$3.40 |\n| H100 | 80GB | 最高性能 | ~$4.02 |\n\n## 主な機能\n\n### @app.function()\n- 任意の Python 関数をクラウドで実行\n- `gpu=modal.GPU.A100()` で GPU 選択\n- `memory=32768` でメモリ指定\n- `timeout=3600` でタイムアウト設定\n\n### @app.cls()\n- クラスをサービスとして永続化\n- HTTP エンドポイント自動生成\n- keep_warm で常時起動維持\n\n### スケジューリング\n```python\n@app.function(schedule=modal.Period(hours=4))\ndef update_ai_university():\n    ...  # 4時間ごとに自動実行\n```\n\n### Volume (永続ストレージ)\n```python\nvol = modal.Volume.from_name("model-cache", create_if_missing=True)\n@app.function(volumes={"/models": vol})\ndef load_model():\n    # /models にモデルをキャッシュ\n```\n\n## 料金\n\n- **無料枠**: $30/月 クレジット（継続）\n- **従量課金**: 実行時間のみ課金（アイドル時ゼロ）\n- **Enterprise**: 専用クラスタ',
  '2026-04-20'
),
(
  'modal',
  'api',
  'Modal 使い方',
  E'## インストール\n\n```bash\npip install modal\nmodal setup  # ブラウザ認証\n```\n\n## 基本的な GPU 関数\n\n```python\nimport modal\n\napp = modal.App("ai-university-inference")\n\n# CUDA 環境を含むコンテナイメージ\nimage = modal.Image.debian_slim().pip_install(\n    "torch", "transformers", "accelerate"\n)\n\n@app.function(\n    image=image,\n    gpu=modal.GPU.A10G(),  # GPU 選択\n    timeout=600\n)\ndef run_inference(prompt: str) -> str:\n    from transformers import pipeline\n    pipe = pipeline("text-generation", model="gpt2")\n    return pipe(prompt, max_new_tokens=200)[0]["generated_text"]\n\n# ローカルから呼び出し\nif __name__ == "__main__":\n    with app.run():\n        result = run_inference.remote("AI大学の概要を教えて")\n        print(result)\n```\n\n## 並列バッチ処理\n\n```python\n@app.function(gpu=modal.GPU.A10G())\ndef process_item(item: str) -> str:\n    return analyze(item)\n\n@app.local_entrypoint()\ndef main():\n    items = ["item1", "item2", "item3"] * 100  # 300件\n    # 自動で並列実行 (最大1000並列)\n    results = list(process_item.map(items))\n    print(f"処理完了: {len(results)}件")\n```\n\n## FastAPI Web エンドポイント\n\n```python\nfrom fastapi import FastAPI\nweb_app = FastAPI()\n\n@app.function(gpu=modal.GPU.A10G(), keep_warm=1)\n@modal.asgi_app()\ndef fastapi_app():\n    @web_app.post("/generate")\n    async def generate(prompt: str):\n        return {"text": run_model(prompt)}\n    return web_app\n```\n\n## 活用シーン\n\n- **AI 大学コンテンツ生成**: `@app.function(schedule=...)` で定期 AI 生成\n- **競馬予測バッチ**: GPU で高速アンサンブル推論\n- **画像生成 API**: FLUX を Modal でサーブして EF から呼び出し',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
