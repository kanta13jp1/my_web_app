---
title: "中国 AI 最前線 — Tencent Hunyuan と ByteDance Doubao を AI大学に追加 (74社目)"
tags: AI,LLM,個人開発,Flutter,Supabase
published: true
---

# 中国 AI 最前線 — Tencent Hunyuan と ByteDance Doubao を AI大学に追加

自分株式会社の AI大学に、中国 AI の雄 **Tencent (騰訊)** と **ByteDance (字節跳動)** を追加し、登録プロバイダーが 74社になりました。

中国 BAT のうち Baidu はすでに登録済み。今回の追加で「中国主要 AI 企業 3社」がそろいました。

## Tencent Hunyuan — OSS 最大級のマルチモーダル AI

### 特徴

Tencent の AI ブランド **Hunyuan** は、テキスト・画像・動画・3D の全モダリティで大規模オープンソースモデルを公開している点が際立っています。

| モデル | 規模 | 特徴 |
|--------|------|------|
| **Hunyuan-Large** | 389B MoE (52B activated) | 当時最大級 OSS MoE / 256K context |
| **Hunyuan Image 3.0** | 80B | 世界最大 OSS 画像生成モデル |
| **HunyuanVideo** | 13B+ | OSS 最大級動画モデル |
| **Hunyuan 3D 2.0** | — | 1枚画像 → 3D メッシュ生成 |
| **Hunyuan Compact** | 0.5B〜7B | エッジ/端末向け 4種類 |

### 開発者から見た強み

- **真のオープンソース**: 単一企業でテキスト/画像/動画すべて SOTA 級 OSS 公開
- **256K コンテキスト** (Hunyuan-Large) — 長文処理に強い
- **WeChat/QQ の実装ノウハウ** が反映されたエンタープライズ向けの安定性

### API 利用

```python
# Tencent Cloud SDK でのアクセス例
from tencentcloud.hunyuan.v20230901 import hunyuan_client, models

# テキスト生成 (Hunyuan-Turbo が高速・低コスト)
req = models.ChatCompletionsRequest()
req.Model = "hunyuan-turbo"
req.Messages = [{"Role": "user", "Content": "Deno + Supabase の Edge Function を書いて"}]
```

---

## ByteDance Doubao — TikTok 運営会社の「Agent Era」モデル

### 特徴

TikTok を運営する ByteDance の AI ブランド **Doubao (豆包)**。2026年2月リリースの **Doubao 2.0** は「Agent Era」を掲げ、多段階タスクの自律実行に特化した次世代モデルです。

| モデル | 特徴 |
|--------|------|
| **Seed 2.0 Pro** | 最高精度・長コンテキスト対応 |
| **Seed 2.0 Lite** | 軽量・高速 |
| **Seed 2.0 Mini** | エッジ向け最小モデル |
| **Seed 2.0 Code** | コード特化 |
| **Seedance 2.0** | TikTok 統合動画生成 |

### 価格競争力

Doubao は API コストで GPT-5.2 の **3.7 倍安い** と言われており、大量処理が必要なバッチ処理に有利です。

```typescript
// Doubao API 呼び出し例 (Supabase Edge Function)
const response = await fetch('https://ark.cn-beijing.volces.com/api/v3/chat/completions', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${Deno.env.get('DOUBAO_API_KEY')}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    model: 'doubao-seed-1-6-250615',
    messages: [{ role: 'user', content: 'こんにちは！' }],
  }),
});
```

---

## AI大学 74社の全体マップ

今回の追加で「中国 BAT + ByteDance」が完成:

```
中国 AI (4社):
  baidu (百度) → ERNIE Bot  ✅ 登録済
  tencent (騰訊) → Hunyuan  ✅ 新規追加 (73社目)
  bytedance (字節跳動) → Doubao ✅ 新規追加 (74社目)
```

全74社は以下カテゴリでカバー:
- **LLM Big Tech**: Google, OpenAI, Anthropic, Microsoft, Meta, xAI
- **中国 AI**: Baidu, Tencent, ByteDance, DeepSeek, Qwen, Moonshot, Zhipu
- **画像・動画生成**: Runway, Suno, Ideogram, Udio, Luma, Kling, Pika, Hedra, HeyGen, Recraft, Krea
- **インフラ**: NVIDIA, Hugging Face, OpenRouter, Ollama, Together AI, Fireworks AI

## まとめ

- Tencent Hunyuan: **OSS 最大級のマルチモーダル AI**。テキスト/画像/動画/3D を一社でカバー
- ByteDance Doubao: **Agent Era 特化 + 業界最安値級**。TikTok との統合が強み

どちらも日本語対応済みで、個人開発での API 利用ハードルが低い点は注目です。

---
AI大学 74社を無料で学習できる自分株式会社: <https://my-web-app-b67f4.web.app/>
#AI #LLM #中国AI #個人開発 #buildinpublic
