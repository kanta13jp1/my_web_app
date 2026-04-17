-- Tencent (Hunyuan) 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('tencent', 'overview', 'Tencent Hunyuan 概要',
$$Tencent Hunyuan は中国 Tencent (騰訊) 社の AI 基盤モデルブランド。テキスト・画像・動画・3D の **マルチモーダル全方位** で大規模オープンソースモデルを公開し、中国 BAT の中で最もオープンソース貢献度が高い AI 部門として知られる。

2025年公開の **Hunyuan-Large** (389B MoE / 52B activated / 256K context) は当時最大級のオープンソース MoE モデル。2026年公開の **Hunyuan Image 3.0** (80B) は世界最大のオープンソース画像生成モデルとして話題となった。動画モデル **HunyuanVideo** (13B+) も Open Source 動画モデル最大級。3D 生成は専用 API として企業向けに公開されている。

## 主要サービス
- **Hunyuan-Large**: 389B MoE LLM (オープンソース)
- **Hunyuan Image 3.0**: 80B 画像生成 (Tencent Hunyuan Community License)
- **HunyuanVideo**: 13B+ 動画生成 (オープンソース)
- **Hunyuan 3D**: 3D アセット生成 (Tencent Cloud API)
- **Hunyuan Turbo**: 軽量化された高速版 (チャット用)
- **Hunyuan Compact (0.5B–7B)**: 端末向け小型モデル (4種類)

## 強み
- **オープンソース最大級**: テキスト/画像/動画すべてSOTA級OSSモデル公開
- **マルチモーダル統合**: 単一企業で全モダリティをカバー
- **Tencent Cloud 統合**: WeChat/QQ などの実装ノウハウ反映
- **256K context** (Hunyuan-Large) — 長コンテキスト対応$$,
'https://hunyuan.tencent.com/', '2026-04-17', 1),

('tencent', 'models', 'Tencent Hunyuan モデル一覧 (2026)',
$$## Hunyuan LLM シリーズ

| モデル | パラメータ | コンテキスト | 特徴 |
| :--- | :--- | :--- | :--- |
| **Hunyuan-Large** | 389B MoE / 52B 活性 | 256K | OSS最大級MoE / 数学・コード強い |
| **Hunyuan-Turbo** | 非公開 | 32K | 高速・低コスト商用版 |
| **Hunyuan-Pro** | 非公開 | 32K | 高精度商用版 |
| **Hunyuan-Compact 0.5B/1.8B/4B/7B** | 0.5–7B | 128K | エッジ・端末向け |

## マルチモーダルモデル

| モデル | タイプ | 特徴 |
| :--- | :--- | :--- |
| **Hunyuan Image 3.0** | 画像生成 (80B) | 世界最大OSS画像モデル |
| **HunyuanVideo** | 動画生成 (13B+) | OSS最大級動画モデル |
| **Hunyuan 3D 2.0** | 3D生成 | 1枚画像→3Dメッシュ |
| **Hunyuan-Audio** | 音声合成 | 多言語TTS |

## 特徴的な機能
- **Mixture of Experts (MoE)**: 389B総量から52Bだけ活性化 (高効率)
- **GQA (Grouped-Query Attention)**: 推論メモリ削減
- **オープンソース License**: 商用利用可 (Tencent Hunyuan Community License)
- **HuggingFace 公開**: 全モデルが HuggingFace でダウンロード可能$$,
'https://github.com/Tencent-Hunyuan', '2026-04-17', 2),

('tencent', 'api', 'Tencent Hunyuan API 入門',
$$## Tencent Cloud API の始め方

```python
import tencentcloud.common.credential as credential
from tencentcloud.hunyuan.v20230901 import hunyuan_client, models

# 認証
cred = credential.Credential("YOUR_SECRET_ID", "YOUR_SECRET_KEY")
client = hunyuan_client.HunyuanClient(cred, "ap-guangzhou")

# チャット呼び出し
req = models.ChatCompletionsRequest()
req.Model = "hunyuan-pro"
req.Messages = [{"Role": "user", "Content": "Hello"}]
resp = client.ChatCompletions(req)
print(resp.Choices[0].Message.Content)
```

## オープンソースモデルを直接実行 (Hugging Face)

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

tokenizer = AutoTokenizer.from_pretrained("tencent/Tencent-Hunyuan-Large")
model = AutoModelForCausalLM.from_pretrained(
    "tencent/Tencent-Hunyuan-Large",
    device_map="auto",
    torch_dtype="auto"
)
```

## 料金 (Tencent Cloud, 2026年4月時点)
- **Hunyuan-Lite**: 無料 (制限付き)
- **Hunyuan-Standard**: ¥0.0045 / 1K input tokens
- **Hunyuan-Pro**: ¥0.03 / 1K input tokens, ¥0.10 / 1K output
- **Hunyuan-Turbo**: ¥0.015 / 1K input, ¥0.05 / 1K output
- **Hunyuan 3D API**: 従量課金 (生成1回ごと)

## 主要エンドポイント
- `ChatCompletions` — テキスト生成 (OpenAI互換)
- `TextToImage` — Hunyuan Image 画像生成
- `SubmitHunyuan3DJob` — 3D生成ジョブ送信
- `SubmitHunyuanImageJob` — 動画生成ジョブ送信

## 認証
Tencent Cloud Console で SecretId/SecretKey を発行。中国本土外からも利用可能 (Tencent Cloud International)。$$,
'https://cloud.tencent.com/document/product/1729', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
