-- ByteDance (Doubao / Seed) 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('bytedance', 'overview', 'ByteDance Doubao 概要',
$$ByteDance (字節跳動) は TikTok / 抖音 を運営する世界最大級のテック企業で、AI ブランド **Doubao (豆包)** と基盤モデル **Seed** シリーズを公開している。2026年2月に発表された **Doubao 2.0** は「Agent Era (エージェント時代)」をテーマに、複雑な多段階タスクの自律実行に特化した次世代モデル。

中国国内月間アクティブユーザー1億超のチャットアプリ Doubao を持ち、TikTok の動画 AI 編集 / TikTok Effects の生成 AI 機能でも基盤として使われる。**Volcengine** クラウドプラットフォームで企業向け API を提供。

## 主要サービス
- **Doubao (豆包)**: 中国向けチャットアプリ (1億+ MAU)
- **Seed 2.0 シリーズ**: Pro / Lite / Mini / Code 4種類の基盤モデル
- **Seedance 2.0**: 動画生成モデル (TikTok 統合)
- **Volcengine API**: Doubao/Seed モデルの企業向け API
- **Doubao TTS**: 多言語音声合成 (40+ 言語)

## 強み
- **業界最安値級 API**: Seed 2.0 Pro は GPT-5.2 比で入力 3.7倍 / 出力 5.9倍安い
- **Agent 特化**: 多段階タスク自律実行に最適化
- **TikTok 連携**: 巨大コンテンツプラットフォームの実装ノウハウ
- **多言語対応**: 中国語に加え英語・日本語も実用レベル$$,
'https://www.doubao.com/', '2026-04-17', 1),

('bytedance', 'models', 'ByteDance Seed モデル一覧 (2026)',
$$## Seed 2.0 シリーズ (2026年2月リリース)

| モデル | 用途 | 特徴 |
| :--- | :--- | :--- |
| **Seed 2.0 Pro** | フロンティア推論 / 複雑エージェント | 最高精度・GPT-5.2競合 |
| **Seed 2.0 Lite** | 一般プロダクション | バランス型・コスト効率 |
| **Seed 2.0 Mini** | 大量バッチ処理 | 高スループット・超低コスト |
| **Seed 2.0 Code** | ソフトウェア開発 | コード生成特化 |

## マルチモーダルモデル

| モデル | タイプ | 特徴 |
| :--- | :--- | :--- |
| **Seedance 2.0** | 動画生成 | TikTok統合・ハイクオリティ |
| **Seed Image** | 画像生成 | 中国語プロンプト最強 |
| **Skylark Audio** | 音声合成 (TTS) | 多言語・感情表現 |
| **Doubao Vision** | 画像理解 | OCR・チャート理解 |

## 特徴的な機能
- **Agent Era 設計**: ツール使用・自律タスク実行が標準サポート
- **OpenAI 互換 API**: 既存 OpenAI SDK でほぼそのまま動作
- **Volcengine 統合**: クラウドDB・ストレージとシームレス連携
- **無料利用枠**: Doubao アプリは中国国内で完全無料$$,
'https://www.volcengine.com/product/doubao', '2026-04-17', 2),

('bytedance', 'api', 'ByteDance Volcengine API 入門',
$$## Volcengine Ark API の始め方

```python
from openai import OpenAI

# Volcengine Ark API は OpenAI 互換
client = OpenAI(
    api_key="YOUR_VOLCENGINE_API_KEY",
    base_url="https://ark.cn-beijing.volces.com/api/v3"
)

response = client.chat.completions.create(
    model="doubao-seed-2-0-pro",  # または ep-XXXXX (エンドポイントID)
    messages=[
        {"role": "user", "content": "こんにちは。"}
    ]
)
print(response.choices[0].message.content)
```

## Seedance 2.0 動画生成

```python
import requests

url = "https://ark.cn-beijing.volces.com/api/v3/contents/generations/tasks"
headers = {"Authorization": "Bearer YOUR_API_KEY", "Content-Type": "application/json"}
data = {
    "model": "doubao-seedance-2-0",
    "content": [
        {"type": "text", "text": "サイバーパンク街の夜景を歩く猫"},
        {"type": "image_url", "image_url": {"url": "https://..."}}
    ]
}
response = requests.post(url, json=data, headers=headers)
print(response.json())  # task_id を返す
```

## 料金 (2026年4月時点)
- **Seed 2.0 Pro**: ¥3 / 100万 input tokens (約 $0.47) — **GPT-5.2 比 3.7倍安**
- **Seed 2.0 Lite**: ¥0.6 / 100万 input tokens
- **Seed 2.0 Mini**: ¥0.15 / 100万 input tokens (バッチ最安)
- **Seedance 2.0**: 動画 1本 ¥1.0〜
- **Doubao TTS**: ¥0.003 / 1000文字

## 主要エンドポイント
- `chat.completions` — テキスト生成 (OpenAI互換)
- `embeddings` — 埋め込み生成
- `contents.generations.tasks` — 動画生成 (非同期)
- `images.generations` — Seed Image 画像生成
- `audio.speech` — Skylark TTS

## 認証
Volcengine Console で API Key 発行 (中国本土外からも申請可能)。Doubao 公式アプリは別途中国の電話番号が必要だが、API 利用は国際展開済み。$$,
'https://www.volcengine.com/docs/82379/1099455', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
