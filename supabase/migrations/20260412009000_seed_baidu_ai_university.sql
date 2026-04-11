-- Baidu AI (ERNIE) コンテンツシード
-- AI大学: Baidu プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: 中国最大AI企業 / ERNIE Bot API公開済み / 中国語・多言語対応 / グローバル展開する日本企業に必須知識

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('baidu', 'overview', 'Baidu AI (ERNIE / 文心一言) 概要',
$$Baidu (百度) は1999年に北京で創業された中国最大の検索エンジン企業であり、中国のAI分野のリーダーです。2023年に発表した **ERNIE Bot (文心一言)** は中国版 ChatGPT として数千万ユーザーを獲得し、現在はグローバルに API を公開しています。

ERNIE (Enhanced Representation through kNowledge IntEgration) は知識グラフと大規模言語モデルを組み合わせたアーキテクチャが特徴で、特に**中国語の理解・生成精度**において世界最高水準です。Baidu は中国語 AI のデファクトスタンダードとして企業・政府・教育機関で広く採用されています。

## 主要サービス
- **ERNIE Bot** — 消費者向け AI チャットアシスタント (中国最大ユーザー数)
- **Wenxin API (文心 API)** — ERNIE モデルを API 経由で利用するクラウドプラットフォーム
- **ERNIE 4.0 / Speed / Lite** — 精度・速度・コストのバリエーションモデル
- **ERNIE-ViLG** — テキスト→画像生成 (中国語プロンプト特化)
- **Qianfan (千帆) Platform** — エンタープライズ AI 開発プラットフォーム

## 強み
- **中国語 AI の最高精度**: 中国語理解・文書処理・コード生成で国内 No.1 水準
- **知識グラフ統合**: 5.5億以上の知識エンティティをモデルに組み込み、事実誤認が少ない
- **中国市場特化**: 中国規制・コンプライアンス対応 — 中国進出する企業に必須
- **グローバル API**: 国外開発者も Baidu AI Cloud 経由で利用可能
- **マルチモーダル対応**: テキスト・画像・音声・動画を統合処理$$,
'https://yiyan.baidu.com/', '2026-04-12', 1),

('baidu', 'models', 'Baidu ERNIE モデル一覧 (2026)',
$$## ERNIE シリーズ (テキスト生成)

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **ERNIE 4.0 Ultra** | 128K | 最高精度・複雑な推論・長文理解 | 高難度タスク・分析 |
| **ERNIE 4.0 Turbo** | 128K | 高精度・高速バランス型 | 汎用・ビジネス用途 |
| **ERNIE Speed** | 128K | 低コスト・高速 | 大量処理・チャット |
| **ERNIE Lite** | 128K | 超低コスト・軽量 | 分類・要約・簡単な QA |
| **ERNIE Tiny** | 4K | オンデバイス向け超軽量 | エッジ推論 |

## マルチモーダルモデル

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **ERNIE 4.0 VL** | 画像+テキスト理解 | 文書解析・OCR・VQA |
| **ERNIE-ViLG 3.0** | テキスト→画像生成 (中国語特化) | 広告・コンテンツ制作 |
| **ERNIE音楽** | テキスト→音楽生成 | BGM・効果音 |

## 特化機能

```text
文档智能 (文書 AI): PDF・Word・Excel を自動解析して Q&A 対応
知识库 (ナレッジベース): 社内文書を RAG で自動回答
代码生成 (コード生成): Python・Java・JavaScript 等に対応
```

## 中国語処理能力の比較

| 能力 | ERNIE 4.0 | GPT-4 | 優位性 |
| :--- | :--- | :--- | :--- |
| 中国語文書理解 | 最高 | 高 | ERNIE が優位 |
| 中国法規・制度知識 | 最高 | 中 | ERNIE が大幅優位 |
| 中国語コード生成 | 最高 | 高 | 同等〜ERNIE優位 |
| 英語・多言語 | 高 | 最高 | GPT-4 が優位 |$$,
'https://cloud.baidu.com/doc/WENXINWORKSHOP/index.html', '2026-04-12', 2),

('baidu', 'api', 'Baidu ERNIE API 入門',
$$## Wenxin API の始め方

[cloud.baidu.com](https://cloud.baidu.com/) でアカウント作成後、API Key を取得して利用できます。

```python
import requests
import json

# アクセストークン取得
def get_access_token(api_key: str, secret_key: str) -> str:
    url = f"https://aip.baidubce.com/oauth/2.0/token"
    params = {
        "grant_type": "client_credentials",
        "client_id": api_key,
        "client_secret": secret_key
    }
    response = requests.post(url, params=params)
    return response.json()["access_token"]

API_KEY = "your-api-key"
SECRET_KEY = "your-secret-key"
token = get_access_token(API_KEY, SECRET_KEY)

# ERNIE 4.0 Turbo でテキスト生成
url = f"https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/ernie-4.0-turbo-8k?access_token={token}"

payload = {
    "messages": [
        {"role": "user", "content": "人工知能の最新動向について日本語で説明してください。"}
    ],
    "temperature": 0.7,
    "max_output_tokens": 1024
}

response = requests.post(url, json=payload)
result = response.json()
print(result["result"])
```

## ストリーミング応答

```python
import requests, json

token = get_access_token(API_KEY, SECRET_KEY)
url = f"https://aip.baidubce.com/rpc/2.0/ai_custom/v1/wenxinworkshop/chat/ernie-4.0-turbo-8k?access_token={token}"

payload = {
    "messages": [{"role": "user", "content": "中国のAI産業の現状を教えてください。"}],
    "stream": True  # ストリーミング有効化
}

with requests.post(url, json=payload, stream=True) as response:
    for line in response.iter_lines():
        if line:
            data = line.decode("utf-8").replace("data: ", "")
            if data != "[DONE]":
                chunk = json.loads(data)
                print(chunk.get("result", ""), end="", flush=True)
```

## Python SDK (qianfan)

```python
import qianfan  # pip install qianfan

# 環境変数で認証
import os
os.environ["QIANFAN_ACCESS_KEY"] = "your-access-key"
os.environ["QIANFAN_SECRET_KEY"] = "your-secret-key"

# ERNIE 4.0 Turbo でチャット
chat_comp = qianfan.ChatCompletion()
response = chat_comp.do(
    model="ERNIE-4.0-Turbo-8K",
    messages=[{"role": "user", "content": "百度のAI戦略について教えてください。"}]
)
print(response["body"]["result"])
```

## 料金 (2026年4月時点, 人民元 → 参考円換算)

| モデル | 入力 (1M tokens) | 出力 (1M tokens) |
| :--- | :--- | :--- |
| **ERNIE 4.0 Ultra** | ¥100 (約2,000円) | ¥300 (約6,000円) |
| **ERNIE 4.0 Turbo** | ¥20 (約400円) | ¥60 (約1,200円) |
| **ERNIE Speed** | ¥2 (約40円) | ¥6 (約120円) |
| **ERNIE Lite** | 無料 | 無料 |

- **無料枠**: ERNIE Lite は無制限無料 / ERNIE Speed は月 200万 tokens 無料
- SDK: `pip install qianfan` / REST API は curl / requests で利用可
- 注意: 中国アカウントでの利用が必要な場合あり。日本法人名義でも登録可能$$,
'https://cloud.baidu.com/doc/WENXINWORKSHOP/s/Nlks5zkzu', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Baidu ERNIE 追加 (18社目)',
  'Baidu (ERNIE Bot / 文心一言) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、ERNIE 4.0 Ultra/Turbo/Speed/Lite モデル・Wenxin API・qianfan SDK・中国語特化の強みを収録。AI大学プロバイダー数 17社→18社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
