-- Preferred Networks (PLaMo) 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('pfn', 'overview', 'Preferred Networks (PLaMo) 概要',
$$**Preferred Networks (PFN)** は 2014 年に東京で設立された、日本を代表する AI・機械学習企業。深層学習フレームワーク **Chainer** の開発元として知られ、トヨタ・ファナック・NTT などと大型提携。2024 年以降は独自の日本語ファウンデーションモデル **PLaMo™** シリーズを開発・提供している。

**PLaMo™ Prime** は **100% 日本製** の LLM で、日本語コーパスを中心にスクラッチから学習。同社独自の高性能 GPU/AI アクセラレータでトレーニングし、日本語特有のニュアンス・業界専門用語・敬語を高精度に扱える。**PLaMo Translate** は日本語 ↔ 英語/中国語等の翻訳特化モデル。

## 主要サービス

- **PLaMo™ Prime** — クラウド API (有料) + PLaMo Chat (assistant)
- **PLaMo™ Translate** — 高精度日本語翻訳 LLM
- **PLaMo Lite** — エッジ・組込み向け軽量版
- **MN-Core** — PFN 独自 AI アクセラレータ (PLaMo 推論インフラ)

## 強み

- **日本国産 foundation model の先駆者** (PFN が業界リード)
- **業界特化ファインチューニング**: 金融・医療・製造業にカスタマイズ提供
- **MN-Core インフラ**: GPU 依存しない自社チップで推論コスト最適化
- **翻訳特化モデル**: PLaMo Translate が GENIAC 金融ベンチで SOTA
- **大学・研究機関連携**: 東大・京大との共同研究で先端研究出力$$,
'https://www.preferred.jp/en/business/genai', '2026-04-18', 1),

('pfn', 'models', 'Preferred Networks (PLaMo) モデル一覧 (2026)',
$$## PLaMo ファミリー

| モデル | パラメータ | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **PLaMo Prime** | 100B+ | 日本語フラッグシップ | ビジネス・業界特化 |
| **PLaMo 2** | 8B / 13B | 中規模汎用 | 対話・要約・翻訳 |
| **PLaMo Translate** | 8B | 日↔英/中/他翻訳特化 | 機械翻訳・多言語化 |
| **PLaMo Lite** | 2B | エッジ・オンデバイス | モバイル・組込み |

## 特徴的な機能

- **100% 日本語ネイティブ** (スクラッチ学習 / 外国語モデルの fine-tune ではない)
- **業界特化版** 提供 (金融・医療・製造・自動車)
- **ファインチューニング / RAG カスタマイズ** を個別商談で提供
- **PLaMo Chat** (B2B assistant) でエンタープライズ導入実績多数
- **論文・研究公開**: 金融評価ベンチマーク (japanese-lm-fin-harness) を OSS 公開$$,
'https://www.preferred.jp/ja/business/genai', '2026-04-18', 2),

('pfn', 'api', 'Preferred Networks API 入門',
$$## PLaMo API の始め方

```python
# PLaMo API (REST・OpenAI SDK 互換)
import requests

response = requests.post(
    "https://api.plamo.preferred.jp/v1/chat/completions",
    headers={
        "Authorization": "Bearer YOUR_PLAMO_API_KEY",
        "Content-Type": "application/json",
    },
    json={
        "model": "plamo-prime",
        "messages": [
            {"role": "system", "content": "金融業界に詳しい日本語アシスタントです。"},
            {"role": "user", "content": "日銀の金融政策決定会合の重要論点を3つ挙げて"},
        ],
        "temperature": 0.7,
        "max_tokens": 1024,
    },
)

print(response.json()["choices"][0]["message"]["content"])
```

## PLaMo Translate API

```python
# PLaMo Translate — 日本語翻訳特化
response = requests.post(
    "https://api.plamo.preferred.jp/v1/translate",
    headers={"Authorization": "Bearer YOUR_PLAMO_API_KEY"},
    json={
        "source_lang": "ja",
        "target_lang": "en",
        "text": "このAIは日本語と英語の翻訳精度が業界最高水準です。",
    },
)
print(response.json()["translated_text"])
```

## 料金 (2026年4月時点・商談ベース)

- **PLaMo Prime API**: エンタープライズ商談 (月額契約 or 従量課金)
- **PLaMo Translate**: 従量課金 (文字数ベース)
- **PLaMo Chat**: 月額 B2B プラン
- **研究者向け無料枠**: 大学・NPO・個人研究で申請可能
- **オンプレミス提供**: MN-Core サーバーの自社設置も可

## 参考リンク

- 公式サイト: <https://www.preferred.jp/en/>
- GenAI 事業: <https://www.preferred.jp/en/business/genai>
- PLaMo Chat: <https://plamo.preferred.jp/chat>
- GitHub: <https://github.com/pfnet>
- 金融評価ハーネス: <https://github.com/pfnet-research/japanese-lm-fin-harness>$$,
'https://www.preferred.jp/en/business/genai', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
