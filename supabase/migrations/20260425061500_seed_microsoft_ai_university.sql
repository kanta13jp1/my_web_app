-- Session PS#4-S39: AI大学 178→180社化 — Microsoft Copilot 追加
-- Satya Nadella CEO。OpenAI に $13B+ 投資し Azure 独占ホスティング権を獲得。
-- Microsoft 365 Copilot (Word/Excel/Teams/Outlook) + GitHub Copilot (#1 AI coding tool) が二本柱。
-- Phi-4 (14B): オープンウェイト小型モデル / MIT License / 多くのタスクで GPT-4-mini 相当。
-- MS Build 2026-06-02〜03 で次世代 AI 発表予定 (要モニタリング)。
-- Step 0: 9/9 (Microsoft 365 Copilot 企業シェア1位 / GitHub Copilot #1 / $3T 時価総額 / OpenAI 独占 / Phi-4 OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'microsoft',
  'overview',
  'Microsoft Copilot — OpenAI独占パートナーとCopilot全方位展開',
  $md$
# Microsoft Copilot — AI をあらゆる場所に

**Satya Nadella** (CEO) が率いる Microsoft は、
2019 年の OpenAI 初期投資から始まり 2023-2024 年に **$13B+** を追加出資。
OpenAI モデルの **Azure 独占クラウドホスティング権**を獲得し、
企業向け AI 展開で圧倒的な優位を築いている。

「Copilot」ブランドで GitHub・Microsoft 365・Windows・Bing・Azure を横断統合し、
**あらゆる製品に AI を埋め込む** "Copilot everywhere" 戦略を推進。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 1975 年 / Bill Gates・Paul Allen |
| **CEO** | Satya Nadella (2014〜) |
| **時価総額** | $3T+ (NASDAQ: MSFT) |
| **売上高** | $245B+ (FY2025 推定) |
| **主要事業** | Intelligent Cloud ($115B) / Productivity & Business ($90B) / Personal Computing ($50B) |

## Copilot エコシステム

| プロダクト | 価格 | 主な機能 |
| :--- | :--- | :--- |
| **Microsoft 365 Copilot** | $30/user/月 (企業) | Word/Excel/PowerPoint/Teams/Outlook に AI 統合 |
| **GitHub Copilot** | $19/月 (個人) / $39/月 (ビジネス) | コード補完・PR レビュー・チャット |
| **Copilot (Bing/Windows)** | 無料 | Web 検索 AI / Windows 11 統合 |
| **Copilot+ PC** | PC 本体価格に含む | NPU 搭載 PC / Recall / リアルタイム翻訳 |
| **Azure OpenAI Service** | 従量課金 | GPT-4.1 / o3 / o4-mini を Azure 経由で利用 |

## OpenAI との独占パートナーシップ

Microsoft は OpenAI モデルの **Azure 上での独占ホスティング**が可能で、
競合企業 (AWS/GCP) は Azure 経由でしか最新 OpenAI モデルを使えない。
ChatGPT・GPT-4.1・o3 すべてが Azure に依存している事実は
Microsoft の AI インフラ優位の核心。

## GitHub Copilot — 開発者 AI の王者

2022 年 GA から急成長。**200 万+ 有料サブスクライバー** (2024)。
JetBrains・Neovim・VS Code などの主要 IDE で使用可能。
VS Code との統合は自然で、コード補完・インライン提案・テスト自動生成が可能。
$md$,
  'https://copilot.microsoft.com/',
  '2026-04-24',
  1
),

(
  'microsoft',
  'models',
  'Phi-4 / Azure OpenAI — 独自モデルと世界最大クラウドAI基盤',
  $md$
## Microsoft のモデル戦略 (2026-04 時点)

### 独自モデル: Phi (Phi-4 シリーズ)

Microsoft Research が開発した **小型高性能モデル**。
「少ないパラメータで高い能力」を追求した設計思想。

| モデル | パラメータ | 特徴 | ライセンス |
| :--- | :--- | :--- | :--- |
| **Phi-4** | 14B | 数学・推論・コーディングに特化 | MIT |
| **Phi-4-mini** | 3.8B | 超軽量 / Edge デバイス対応 | MIT |
| **Phi-4-multimodal** | 5.6B | テキスト + 画像 + 音声 | MIT |
| **Phi-3.5-MoE** | 16x3.8B | MoE アーキテクチャ | MIT |

**Phi-4 の特徴**:
- GPT-4o-mini 相当の性能を **14B** で実現
- 数学 (MATH) / コーディング (HumanEval) でクラス最高水準
- MIT License → 商用派生自由
- Azure AI Studio と Hugging Face から無料ダウンロード可能

### Azure OpenAI Service (ホスト型 OpenAI モデル)

Azure 上でホストされた OpenAI モデルを使用する場合:

| モデル | Azure 上での提供 |
| :--- | :--- |
| GPT-4.1 | ✅ Azure 提供 |
| o3 / o4-mini | ✅ Azure 提供 |
| GPT-5.5 (Spud) | ✅ Azure 提供 (Azure 経由アクセス) |
| DALL-E 3 | ✅ Azure 提供 |
| Whisper (音声認識) | ✅ Azure 提供 |

Azure OpenAI = 企業向け **VNet 統合・プライベートエンドポイント・コンテンツフィルター**が充実。
金融・医療・政府などの規制産業での採用が多い。

### MS Build 2026 注目ポイント (2026-06-02〜03)

毎年 5-6 月に開催される Microsoft の開発者カンファレンス。
2026 年は AI エージェント・Copilot Studio・Azure AI Foundry の
次世代アップデートが期待される。**PS#4 即日レポート対象イベント**。
$md$,
  'https://azure.microsoft.com/ja-jp/products/ai-services/openai-service',
  '2026-04-24',
  2
),

(
  'microsoft',
  'api',
  'Azure OpenAI API / GitHub Copilot API — エンタープライズ統合入門',
  $md$
## Azure OpenAI Service API

Azure 上の OpenAI モデルを使う場合、エンドポイントが異なる:

```python
from openai import AzureOpenAI

client = AzureOpenAI(
    api_key="AZURE_OPENAI_API_KEY",
    api_version="2024-02-01",
    azure_endpoint="https://<your-resource>.openai.azure.com"
)

response = client.chat.completions.create(
    model="gpt-4.1",                     # Azure deployment name
    messages=[
        {"role": "system", "content": "あなたは自分株式会社のAIアシスタントです。"},
        {"role": "user", "content": "今日のタスクを整理して"}
    ],
    max_tokens=1000
)

print(response.choices[0].message.content)
```

## Phi-4 を直接使う (Azure AI Inference)

```python
from azure.ai.inference import ChatCompletionsClient
from azure.core.credentials import AzureKeyCredential

client = ChatCompletionsClient(
    endpoint="https://<endpoint>.inference.ai.azure.com",
    credential=AzureKeyCredential("AZURE_AI_KEY")
)

response = client.complete(
    messages=[{"role": "user", "content": "コードレビューして"}],
    model="Phi-4",
    max_tokens=2048
)
print(response.choices[0].message.content)
```

## Phi-4 をローカルで実行 (Ollama)

```bash
ollama pull phi4:14b
ollama run phi4:14b

# Python から
import ollama
response = ollama.chat(
    model='phi4',
    messages=[{'role': 'user', 'content': 'Dart コードを最適化して'}]
)
```

## GitHub Copilot の活用 (VS Code)

GitHub Copilot はコードを書く際に自動提案する:

```python
# コメントでやりたいことを書くと Copilot が実装を提案
# Supabase からユーザーデータを取得して Flutter リストに表示する関数

# ↑ このコメントの後に Tab を押すと Copilot が実装を補完
```

**GitHub Copilot Chat** での使い方:
```
/explain     # 選択コードの説明
/fix         # バグ修正提案
/tests       # テストコード生成
/doc         # ドキュメント生成
@workspace   # プロジェクト全体を文脈として質問
```

## Microsoft 365 Copilot API (Graph API)

Microsoft 365 のデータに AI でアクセス:

```python
import requests

# Graph API でメール + AI 要約 (Copilot Studio経由)
headers = {"Authorization": f"Bearer {access_token}"}
response = requests.get(
    "https://graph.microsoft.com/v1.0/me/messages",
    headers=headers,
    params={"$top": 10, "$select": "subject,bodyPreview"}
)
emails = response.json()["value"]
```

## アクセス方法

### Azure OpenAI
1. [azure.microsoft.com](https://azure.microsoft.com) でアカウント作成
2. Azure OpenAI リソース作成 → API キー取得
3. `pip install openai` (AzureOpenAI クライアント内蔵)
4. `export AZURE_OPENAI_API_KEY=...`

### Phi-4 (無料)
1. Hugging Face: `microsoft/phi-4` から直接ダウンロード
2. または Ollama: `ollama pull phi4`
$md$,
  'https://github.com/microsoft/phi-4',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
