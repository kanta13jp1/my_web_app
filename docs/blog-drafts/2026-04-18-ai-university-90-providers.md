---
title: "自分株式会社の AI大学が90社対応に — fal.ai と Fish Audio を追加"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: false
---

# 自分株式会社の AI大学が90社対応に — fal.ai と Fish Audio を追加

## はじめに

自分株式会社の **AI大学** 機能が **90プロバイダー対応** に到達しました。

今回追加した2社は、テキスト生成とは異なるモダリティで急成長中のプラットフォームです:

- **fal.ai** — 1,000+ 生成AIモデルを1つのAPIキーで呼び出せる GPU クラウド
- **Fish Audio** — 70+ 言語対応の TTS・即時ボイスクローン

## fal.ai とは

fal.ai は **生成メディア統合 API プラットフォーム**です。

画像・動画・音声・3D を1つのAPIキーで統一インターフェースで呼び出せます。

```python
import fal_client

result = fal_client.subscribe("fal-ai/flux/schnell", {
    "prompt": "A futuristic cityscape at sunset",
})
print(result["images"][0]["url"])
```

注目モデル:

| モデル | モダリティ | 特徴 |
|--------|-----------|------|
| **Seedance 2.0** | 動画 | 1080p・物理シミュレーション |
| **FLUX.1** | 画像 | 業界最高品質の画像生成 |
| **Stable Audio Open** | 音楽 | オープンソース音楽生成 |
| **TripoSR** | 3D | 2秒で2D→3D変換 |

自分株式会社では **Free Tier** に分類。ユースケース: プロトタイプ・コンテンツ生成・マルチモーダルAIアプリ。

## Fish Audio とは

Fish Audio は **音声 AI 専業プラットフォーム**です。

```bash
curl -X POST "https://api.fish.audio/v1/tts" \
  -H "Authorization: Bearer $FISH_AUDIO_API_KEY" \
  -d '{"text": "こんにちは", "reference_id": "voice_id"}'
```

主な機能:

- **即時ボイスクローン**: 数秒のサンプルから新しい声を作成
- **70+ 言語**: 日本語含む多言語 TTS
- **リアルタイムストリーミング**: 生成中に再生開始
- **Fish Speech S1**: OSS フラッグシップモデル (自社ホスティング可)

自分株式会社では **Free Tier** に分類。ユースケース: 音声アシスタント・会話AI・多言語コンテンツ。

## 4-Tier 自動ルーティングとの位置づけ

```
Free      : DeepSeek, Groq, SiliconFlow, DeepInfra, fal.ai, Fish Audio
Budget    : Together AI, Fireworks, Moonshot, Arcee AI
Performance: OpenAI, Google, Nebius, Perplexity
Premium   : Claude, GPT-4o, Gemini Ultra
```

fal.ai と Fish Audio はいずれも **テキストチャット以外のモダリティ** を主軸とするため、
通常の `provider.chat` ルーティングとは別に、マルチモーダルタスク専用のルートとして位置づけています。

## 90社への道のり

| 日付 | プロバイダー数 | 主な追加 |
|------|-------------|---------|
| 4月上旬 | 9社 | Google, OpenAI, Anthropic など主要LLM |
| 4月中旬 | 54社 | 中国・欧州・特化型 |
| 4月17日 | 77社 | 動画AI (Runway/Suno/Luma/Kling) |
| 4月18日 | 88社 | SiliconFlow, Novita AI, DeepInfra, Nebius |
| **4月18日** | **90社** | **fal.ai, Fish Audio** |

## まとめ

AI大学 90社対応で、テキスト生成だけでなく画像・動画・音声・3Dまで網羅できるようになりました。
無料で体験できます: https://my-web-app-b67f4.web.app/

次回は **95社突破** を目指します。

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #AI大学
