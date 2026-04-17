---
title: "フロンティアAI2選をAI大学に追加 — 拡散LLM・空間知能 (76社目)"
tags: AI,LLM,個人開発,Flutter,buildinpublic
published: false
---

# フロンティアAI2選 — Inception Labs (Mercury) と World Labs をAI大学に追加

自分株式会社の AI大学に **Inception Labs** と **World Labs** を追加し、登録プロバイダーが **76社** になりました。どちらも 2025〜2026年に登場した "次世代AI" の代表格です。

---

## Inception Labs — 世界初の商用 拡散 LLM

### 何が違うのか

従来の LLM はトークンを**左から右へ1つずつ**生成します。Inception Labs の **Mercury** は「拡散モデル (Diffusion)」をテキスト生成に応用し、**全トークンを並列生成**します。

| 指標 | 従来 Transformer | Mercury (dLLM) |
|------|-----------------|----------------|
| 生成方式 | 逐次 (auto-regressive) | 並列 (diffusion) |
| 速度 | ベースライン | **5〜10倍高速** |
| 精度 (MMLU) | 同等レベル | SOTA相当 |

### Mercury 2 (2026/02)

- 128K コンテキスト対応
- OpenAI 互換 API (ドロップイン移行可)
- **Azure AI Foundry** でも提供
- Free tier: 10M tokens/月

```python
# OpenAI SDK そのまま使える
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_INCEPTION_KEY",
    base_url="https://api.inceptionlabs.ai/v1"
)

response = client.chat.completions.create(
    model="mercury-2",
    messages=[{"role": "user", "content": "Supabase Edge Function を書いて"}]
)
```

---

## World Labs — Fei-Fei Li が拓く「空間知能」

### 創業背景

ImageNet の生みの親、スタンフォード大学教授 **Fei-Fei Li** が 2024年に創業。$1B (約 1500億円) を調達し、"Spatial Intelligence (空間知能)" という新分野を開拓中。

### World API (2026/01)

テキスト・画像・動画から **3D 世界**を生成する Large World Models (LWM):

- USD / glTF など業界標準フォーマット出力
- **Embodied AI・ロボット訓練**に直接利用可能
- シミュレーション環境の自動生成

```typescript
// World Labs API (概念コード)
const world = await worldlabs.generate({
  prompt: "東京のオフィスビル 25階の会議室",
  format: "gltf",
  physics: true,
});
// → 3D メッシュ + 物理シミュレーション対応シーン
```

---

## AI大学 76社の全体像

```
フロンティアAI:
  inception_labs → Mercury (拡散LLM)   ✅ 新規 (75社目)
  world_labs     → World API (空間知能) ✅ 新規 (76社目)
```

今後の注目候補:
- **Huawei Pangu** (中国 BAT 最後の1社)
- **Magic.dev** (100M context LTM-2)
- **Physical Intelligence** (π ロボット基盤モデル)

---
AI大学 76社を無料で学習できる自分株式会社: <https://my-web-app-b67f4.web.app/>
#AI #LLM #個人開発 #buildinpublic #FlutterWeb
