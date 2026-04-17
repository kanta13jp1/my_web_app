-- MiniMax 初期コンテンツシード (2026-04-18)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('minimax', 'overview', 'MiniMax 概要',
$$MiniMax (海螺AI / 稀宇科技) は 2022 年 1 月に中国・上海で設立された **マルチモーダル AI ファンデーションモデル企業**。創業者の閻俊傑 (Yan Junjie) は元 SenseTime で、Alibaba / Tencent / Hillhouse Capital などから累計 10 億ドル超を調達。

2026 年 1 月に **香港証券取引所に上場**し、同年 2 月に **MiniMax-M2.5** + 軽量版 M2.5-Lightning を、3 月に **MiniMax-M2.7** をリリース。テキスト / 音声 / 画像 / 動画 / 音楽を単一プラットフォームで扱えるマルチモーダル AI インフラとして、中国発のグローバルプレーヤーに成長した。

## 主要サービス

- **MiniMax Chat** — M2.x 系 LLM (200K+ トークン長コンテキスト)
- **海螺音声** (Hailuo Voice) — リアルタイム音声合成・クローン
- **Hailuo Video** — テキスト→動画生成 (5〜10秒・1080p)
- **Music Generation API** — 歌詞+BGM 同時生成
- **MiniMax MCP** — Model Context Protocol 公式サーバー

## 強み

- **超長コンテキスト** 200K+ トークン (エージェント・長文処理)
- **全モダリティ統合**: テキスト+音声+画像+動画+音楽を単一 API で提供
- **多言語対応**: 中国語・英語・日本語・韓国語をネイティブサポート
- **Hong Kong 上場企業** のコンプライアンス水準 (商用利用安心)
- Claude MCP 標準対応 (Agent ワークフロー連携)$$,
'https://www.minimax.io', '2026-04-18', 1),

('minimax', 'models', 'MiniMax モデル一覧 (2026)',
$$## MiniMax LLM 系列

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **MiniMax-M2.7** | 256K | 最新フラッグシップ (Mar 2026) | 高精度推論・エージェント |
| **MiniMax-M2.5** | 256K | 汎用モデル (Feb 2026) | 対話・要約・翻訳 |
| **MiniMax-M2.5-Lightning** | 128K | 軽量高速版 | リアルタイム応答・大量処理 |
| **MiniMax-M2-Her** | 200K | 音声対話特化 | 音声アシスタント |

## マルチモーダル系列

- **Hailuo Video** — テキスト→動画 (5-10秒・1080p・日本語プロンプト対応)
- **Hailuo Voice** — TTS + Voice Cloning (日中英 50+ 声質)
- **Music API** — 歌詞+メロディ+BGM 同時生成 (1分未満)
- **Image-01** — テキスト→画像生成

## 特徴的な機能

- **Function Calling** / **JSON モード** / **Streaming** 対応
- **Agent 向け構造化出力** (ツール連鎖実行に最適化)
- **OpenAI Chat Completions API 互換エンドポイント**
- **MCP サーバー公式提供** (Claude / Cursor / Cline 連携)$$,
'https://platform.minimax.io/docs/guides/models-intro', '2026-04-18', 2),

('minimax', 'api', 'MiniMax API 入門',
$$## MiniMax API の始め方

```python
# OpenAI SDK で MiniMax に接続 (OpenAI 互換 API)
import openai

client = openai.OpenAI(
    api_key="YOUR_MINIMAX_API_KEY",
    base_url="https://api.minimax.io/v1",
)

response = client.chat.completions.create(
    model="MiniMax-M2.7",
    messages=[
        {"role": "system", "content": "あなたは親切なアシスタントです。"},
        {"role": "user", "content": "漢字と仮名の起源を200字で説明して"}
    ],
    temperature=0.7,
    max_tokens=2048,
)

print(response.choices[0].message.content)
```

## 料金 (2026年4月時点)

- **MiniMax-M2.7**: $0.60 / 1M input · $3.00 / 1M output
- **MiniMax-M2.5-Lightning**: $0.10 / 1M input · $0.50 / 1M output (超安価)
- **Hailuo Video (1080p)**: $0.10 / 秒
- **Hailuo Voice (TTS)**: $0.006 / 1K文字
- **Music API**: $0.08 / 秒
- **Free Tier**: 月間 100万トークン (M2.5-Lightning)

## 参考リンク

- 公式サイト: <https://www.minimax.io>
- 開発者ポータル: <https://platform.minimax.io>
- ドキュメント: <https://platform.minimax.io/docs/>
- MCP サーバー: <https://github.com/MiniMax-AI/MiniMax-MCP>
- HuggingFace: <https://huggingface.co/MiniMaxAI>$$,
'https://platform.minimax.io/docs/', '2026-04-18', 3)

ON CONFLICT DO NOTHING;
