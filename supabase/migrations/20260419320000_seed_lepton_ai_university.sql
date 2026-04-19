-- PS版#3 Session 3: Lepton AI (NVIDIA DGX Cloud Lepton) — NVIDIA傘下の高速推論基盤
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'lepton',
  'overview',
  'Lepton AI (NVIDIA DGX Cloud Lepton) — NVIDIA傘下の超高速推論プラットフォーム',
  E'## Lepton AI とは\n\nLepton AI は元 Alibaba VP の **Yangqing Jia（賈揚清）** が 2023 年に創業した AI 推論スタートアップ。\n2025 年 4 月に **NVIDIA が数億ドルで買収**し、現在は **NVIDIA DGX Cloud Lepton** として提供されている。\n\n独自の高速 LLM 推論エンジン **「Tuna」** を搭載し、毎日 **200 億トークン以上・100 万枚以上の画像** を処理する大規模インフラを運営。\n\n## 主な特徴\n\n- **Tuna エンジン**: LLM 推論速度 600+ tokens/sec（業界最速水準）\n- **NVIDIA GPU 直接接続**: DGX Cloud との深い統合\n- **デベロッパーファースト**: Python framework で AI サービスを数行でデプロイ\n- **グローバル GPU ネットワーク**: 世界中の NVIDIA GPU にアクセス\n- **スケール**: 20B tokens/day + 1M+ images/day 処理実績\n\n## 経緯\n\n- 2023 年: Yangqing Jia 創業（元 PyTorch / Caffe 開発者）\n- 初期調達: $11M（CRV・Fusion Fund 出資）\n- 2025 年 4 月: **NVIDIA が買収**（数億ドル規模）\n- 現在: NVIDIA DGX Cloud Lepton として展開',
  '2026-04-19'
),
(
  'lepton',
  'models',
  'Lepton AI 対応モデル・Tuna エンジン',
  E'## Tuna エンジン（独自高速推論）\n\n| 特性 | 値 |\n|------|----|\n| スループット | **600+ tokens/sec** |\n| 処理規模 | 20B tokens/day |\n| 画像処理 | 1M+ images/day |\n| アーキテクチャ | NVIDIA GPU 最適化専用 |\n\n## 対応 LLM（OpenAI 互換 API）\n\n| モデル | 用途 |\n|--------|------|\n| Llama 3.3 70B / 8B | 汎用推論 |\n| Mistral 7B / Large | 多言語 |\n| Qwen 2.5 72B | 中英バイリンガル |\n| DeepSeek V3 | 高性能 reasoning |\n| Gemma 2 27B | Google OSS |\n\n## 画像生成（Diffusion）\n\n- FLUX.1 (Black Forest Labs)\n- Stable Diffusion XL\n- SDXL-Turbo（高速版）\n\n## GPU インフラ\n\n- H100 / H200 / GB200 (Blackwell)\n- A100 / A10G\n- NVIDIA DGX Cloud 直結\n- 世界複数リージョン',
  '2026-04-19'
),
(
  'lepton',
  'api',
  'Lepton AI API 使い方',
  E'## Python SDK でのデプロイ\n\n```python\nfrom leptonai.photon import Photon\n\nclass MyService(Photon):\n    def init(self):\n        from transformers import pipeline\n        self.pipe = pipeline("text-generation", model="gpt2")\n\n    @Photon.handler\n    def run(self, query: str) -> str:\n        return self.pipe(query)[0]["generated_text"]\n\n# ローカルで起動\nif __name__ == "__main__":\n    p = MyService()\n    p.launch()\n```\n\n## OpenAI 互換 LLM API\n\n```python\nfrom openai import OpenAI\n\nclient = OpenAI(\n    api_key="YOUR_LEPTON_API_KEY",\n    base_url="https://llama3-3-70b.lepton.run/api/v1/"\n)\n\nresponse = client.chat.completions.create(\n    model="llama3-3-70b",\n    messages=[{"role": "user", "content": "Hello!"}]\n)\nprint(response.choices[0].message.content)\n```\n\n## CLI デプロイ\n\n```bash\npip install leptonai\nlep login\nlep photon run -n my-llm --model hf:meta-llama/Llama-3.3-70B-Instruct\n```\n\n## 料金\n\n- 従量課金 (GPU 時間ベース)\n- NVIDIA DGX Cloud と統合\n- Free tier あり（開発・テスト用）\n\n## 活用シーン\n\n- **高速 LLM 推論**: Tuna で 600+ tokens/sec\n- **カスタムモデルデプロイ**: HuggingFace から直接\n- **画像生成 API**: FLUX / SDXL を本番スケール',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
