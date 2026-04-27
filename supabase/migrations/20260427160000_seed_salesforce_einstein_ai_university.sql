-- PS#3 S74: AI大学 242→243社化 — Salesforce Einstein 追加
-- Salesforce Einstein: CRM AI基盤 / Einstein 1 Platform / Agentforce自律AIエージェント / セールスフォース・ジャパン強

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'salesforce_einstein',
  'overview',
  'Salesforce Einstein — CRM AI基盤 (Einstein 1 Platform / Agentforce / Einstein Copilot / セールスフォース・ジャパン)',
  $$## Salesforce Einstein — CRM AI プラットフォーム

**カテゴリ**: Enterprise AI / CRM AI / Autonomous Agents / Sales/Service/Marketing AI
**開発元**: Salesforce, Inc.
**本社**: サンフランシスコ, California
**設立**: 1999年 (Salesforce創業) / Einstein: 2016年〜
**売上**: 約$350億/年 (2025年度) / 世界CRM市場シェア1位
**日本法人**: セールスフォース・ジャパン株式会社 (東京)
**主要製品**: Sales Cloud / Service Cloud / Marketing Cloud / Agentforce
**評価**: 8/9

### 概要
Salesforce Einstein は **世界No.1 CRM プラットフォーム** に統合されたAI機能群。2016年に開始し、2023年の「Einstein GPT」、2024年の「Agentforce」と進化を続けている。日本ではセールスフォース・ジャパンが2000社超の大企業・中堅企業に導入実績を持ち、トヨタ・パナソニック・ソニー・NTTデータなどが採用。

**2024年の転換点**: 「Agentforce」の発表により、単なるAIアシスタントから**自律的に行動するAIエージェント**へと進化。「デジタル労働力 (Digital Labor)」としてのAIという新概念を掲げている。

### 製品系譜

```
2016: Einstein (予測AI) — 機会スコアリング・リード優先順位付け
   ↓
2019: Einstein Analytics → Tableau CRM に統合
   ↓
2023: Einstein GPT / Einstein 1 Platform — 生成AI統合
   ↓
2024: Agentforce — 自律AIエージェント / Einstein Copilot
   ↓
2025: Agentforce 2.0 — マルチエージェント連携 / MCP対応
```

### 主要製品詳細

**1. Agentforce (2024〜)**
- 自律的に行動するAIエージェント基盤
- Atlas 推論エンジン: 複雑なタスクを自律的に計画・実行
- 標準エージェント: Sales Agent / Service Agent / Marketing Agent
- カスタムエージェント: ノーコードで業務特化エージェントを構築
- 人間との協調: 重要な判断では人間に確認 (Human-in-the-loop)
- 統合: Data Cloud / Salesforce Flow / Apex コード

**2. Einstein Copilot**
- Salesforce UI 内で使える会話型AIアシスタント
- 「今月の商談を要約して」「次のアクションを提案して」等の自然言語操作
- 全 Salesforce Cloud に統合 (Sales/Service/Marketing/Commerce)
- Data Cloud と連携してリアルタイムデータを参照

**3. Einstein (予測AI)**
- Opportunity Scoring: 商談クローズ確率をAIで予測
- Lead Scoring: リードの優先度をスコアリング
- Next Best Action: 次の最適アクションを提案
- Forecasting: AI by 売上予測の精度向上

**4. Einstein Studio / Bring Your Own Model**
- 社内の独自AIモデルを Salesforce に接続
- Amazon SageMaker / Google Vertex AI / Hugging Face モデルを統合
- Einstein Trust Layer: プライバシーとセキュリティを保証

### Einstein Trust Layer (セキュリティ設計)

```
[データ保護の仕組み]

ユーザーの Salesforce データ
      ↓
Einstein Trust Layer
  ├── 動的グラウンディング: 実データを参照してハルシネーション防止
  ├── データマスキング: PII (個人情報) を自動でマスク
  ├── 有害コンテンツフィルタ
  ├── 監査ログ: AIとのやりとりを全記録
  └── ゼロリテンション: LLMプロバイダーにデータを保存させない約束
      ↓
LLM (OpenAI / Anthropic / Google等 — Salesforce提携)
```

### 日本での導入事例

| 企業 | 用途 | 成果 |
|------|------|------|
| トヨタ自動車 | ディーラー向け営業AI / 顧客対応支援 | 商談クローズ率 +20% |
| パナソニック | B2B営業プロセス自動化 | 営業担当の事務作業 50% 削減 |
| NTTデータ | ITサービス受注管理 / CS対応AI | 対応時間 40% 短縮 |
| ソフトバンク | 法人営業支援 / Agentforce 先行導入 | 提案書作成時間 70% 削減 |

### 自分株式会社での関連性

```
競合分析:
  自分株式会社の21競合 + Salesforce (CRM市場の巨人)
  → Salesforce は BtoB / エンタープライズ特化
  → 自分株式会社は BtoC / 個人・SMB 特化
  → 直接競合ではなくパートナー候補

AI大学コンテンツとしての価値:
  「なぜ大企業の営業チームはChatGPTではなくAgentforceを選ぶのか」
  「Salesforce Einstein の Einstein Trust Layer から学ぶ企業AIセキュリティ」
  日本企業のDX文脈で非常に関心が高いテーマ

将来シナリオ:
  自分株式会社ユーザーが「会社のSalesforceと自分の自分株式会社を連携したい」
  → Salesforce API 連携機能の需要が発生する可能性$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'salesforce_einstein',
  'api',
  'Salesforce Einstein API — REST API / Einstein Platform Services / Agentforce API / Python/TypeScript統合',
  $$## Salesforce Einstein API / 統合ガイド

### 概要
Salesforce は REST API / SOAP API / Bulk API / Streaming API の4種類を提供。Einstein AI機能は Einstein Platform Services API と Agentforce API でアクセスできる。

### 認証 (OAuth 2.0)
```python
import requests

# Salesforce OAuth 2.0 JWT Bearer Flow (Server-to-Server)
import jwt
import time
import os

def get_salesforce_token(
    client_id: str,
    username: str,
    private_key_path: str,
    instance_url: str = "https://login.salesforce.com",
) -> dict:
    """Salesforce OAuth 2.0 JWT Bearer でアクセストークン取得"""
    with open(private_key_path, "r") as f:
        private_key = f.read()

    claim = {
        "iss": client_id,
        "sub": username,
        "aud": instance_url,
        "exp": int(time.time()) + 300,
    }
    token = jwt.encode(claim, private_key, algorithm="RS256")

    response = requests.post(
        f"{instance_url}/services/oauth2/token",
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": token,
        },
    )
    return response.json()  # {"access_token": "...", "instance_url": "..."}
```

### Salesforce REST API 基本操作
```python
class SalesforceClient:
    def __init__(self, access_token: str, instance_url: str):
        self.headers = {
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        }
        self.base = f"{instance_url}/services/data/v59.0"

    def query(self, soql: str) -> list[dict]:
        """SOQL クエリ実行"""
        resp = requests.get(
            f"{self.base}/query",
            headers=self.headers,
            params={"q": soql},
        )
        return resp.json().get("records", [])

    def create_record(self, sobject: str, data: dict) -> str:
        """レコード作成 (例: 新規 Lead 作成)"""
        resp = requests.post(
            f"{self.base}/sobjects/{sobject}",
            headers=self.headers,
            json=data,
        )
        return resp.json().get("id", "")

# 使用例: 見込み顧客リストを Salesforce に登録
sf = SalesforceClient(access_token="...", instance_url="https://xxx.my.salesforce.com")

# リードを取得
leads = sf.query(
    "SELECT Id, Name, Email, LeadScore FROM Lead WHERE Status = 'Open' LIMIT 10"
)

# 新規リードを作成
new_lead_id = sf.create_record("Lead", {
    "FirstName": "太郎",
    "LastName": "山田",
    "Email": "taro@example.com",
    "Company": "自分株式会社",
    "Status": "Open",
})
```

### Einstein Prediction Service API
```python
# Einstein Intent / Sentiment 分類
def classify_intent(text: str, model_id: str, access_token: str) -> dict:
    """テキストの意図を分類 (カスタム Einstein モデル使用)"""
    response = requests.post(
        "https://api.einstein.ai/v2/language/intent",
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        json={
            "document": text,
            "modelId": model_id,
        },
    )
    return response.json()

# 感情分析
result = classify_intent(
    "製品に不満があります。返金をお願いします。",
    model_id="CommunitySentiment",
    access_token="...",
)
# {"probabilities": [{"label": "Negative", "probability": 0.92}, ...]}
```

### Agentforce API (2024〜)
```typescript
// Agentforce エージェントをプログラムから呼び出す
const SALESFORCE_INSTANCE = "https://xxx.my.salesforce.com";
const ACCESS_TOKEN = process.env.SALESFORCE_ACCESS_TOKEN!;

async function runAgentforceAgent(
  agentId: string,
  input: string,
): Promise<string> {
  const response = await fetch(
    `${SALESFORCE_INSTANCE}/services/data/v63.0/einstein/agents/${agentId}/sessions`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${ACCESS_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: { text: input },
      }),
    },
  );
  const data = await response.json();
  return data.reply?.text ?? "";
}

// 使用例: 営業AIエージェントに商談サマリーを依頼
const summary = await runAgentforceAgent(
  "Sales_Summary_Agent",
  "今月クローズした商談のトップ5を要約して",
);
console.log(summary);
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'salesforce_einstein',
  'models',
  'Salesforce Einstein 技術詳細 — Agentforce Atlas推論エンジン / Data Cloud / Einstein Trust Layer / 日本エンタープライズ戦略',
  $$## Salesforce Einstein 技術詳細

### Agentforce: Atlas 推論エンジン

Agentforce の中核となる **Atlas Reasoning Engine** の動作:

```
[Atlas 推論フロー]

ユーザーリクエスト or トリガー (メール受信 / フォーム送信 等)
      ↓
Atlas: タスク分解
  ├── 目標を複数のサブタスクに分解
  ├── 利用可能なツール (Salesforce Actions) を選択
  └── 実行計画を立案
      ↓
Tool Execution (ループ)
  ├── Salesforce データ読み書き (SOQL)
  ├── Flow の実行 (ビジネスロジック)
  ├── 外部API呼び出し (MuleSoft / HTTP)
  └── Einstein Copilot への質問
      ↓
Human-in-the-Loop (必要に応じて)
  → 人間に確認を求めてから実行継続
      ↓
最終回答 / アクション完了
```

### Data Cloud との統合

```
[Salesforce Data Cloud = 統合データ基盤]

データソース:
  Sales Cloud (商談/取引先) +
  Service Cloud (ケース/チャット) +
  Marketing Cloud (メール/広告) +
  外部データ (Snowflake / AWS S3 / Google BigQuery)
      ↓
Data Cloud (リアルタイム統合・CDPとして機能)
  ├── Unified Customer Profile: 顧客情報を1つのプロファイルに統合
  ├── Data Graphs: エンティティ間の関係をグラフ構造で管理
  └── Vector DB: セマンティック検索 (Einstein Semantic Search)
      ↓
Einstein / Agentforce が参照
  → 最新リアルタイムデータに基づいたAI判断
```

### MCP (Model Context Protocol) 対応 (2025〜)

```
[Salesforce × MCP]

2025年: Salesforce が MCP (Anthropic発のオープン規格) を採用
  → Agentforce が Claude / Cursor / GitHub Copilot 等のAIツールから
    Salesforce データに直接アクセス可能に

実用例:
  VSCode + GitHub Copilot でコードを書きながら
  「Salesforce の顧客データを参照してテストデータを生成して」
  → MCP経由で Salesforce に接続 → リアルデータでテスト
```

### Einstein Trust Layer の技術実装

```
[プロンプトエンジニアリング with Trust Layer]

1. Dynamic Grounding (動的グラウンディング)
   元のユーザー質問 + Salesforce リアルタイムデータ → LLMプロンプトに注入
   例:
     ユーザー: 「田中商事の状況を教えて」
     Trust Layer が追加: 「[田中商事の最新商談: X案件 クローズ確率92%
                            最終連絡: 2024-11-15 / 担当: 鈴木]」
     → ハルシネーション防止 / 最新情報に基づく回答

2. PII Masking
   プロンプト内の個人情報を自動マスク → LLMに送信 → 回答後に復元
   例: "山田太郎 (taro@xxx.com)" → "[PERSON_1] ([EMAIL_1])"

3. Zero-Retention Agreement
   Salesforce は主要LLMプロバイダー (OpenAI / Anthropic / Google等) と
   「Salesforceのデータをモデル学習に使用しない」契約を締結
```

### 競合比較: エンタープライズ CRM AI

| 項目 | Salesforce Agentforce | Microsoft Copilot for Sales | HubSpot AI | Oracle AI |
|------|----------------------|---------------------------|-----------|-----------|
| 市場シェア | 1位 (~22%) | 2位 | SMB向け | エンタープライズ |
| AI自律度 | ✅ 自律エージェント | △ コパイロット中心 | △ | △ |
| データ統合 | ✅ Data Cloud | ✅ Microsoft 365 | △ | △ |
| 日本サポート | ✅ 強 (日本法人) | ✅ 強 | △ | ✅ |
| 価格 | 高額 (エンタープライズ) | M365ライセンス込み | 無料〜 | 高額 |

### 自分株式会社との関連性

```
学習リソースとしての価値:

1. Agentforce の設計思想 → 自分株式会社の AI エージェント設計に参照可能
   「Atlas 推論エンジン」= Orchestrator-Subagent パターンの商用実装
   自分株式会社の Claude Schedule + cs-check.yml と本質的に同じ設計

2. Trust Layer の設計 → 将来の企業向けプランで採用できるセキュリティモデル
   「AIが顧客データを処理するがクラウドに送らない」設計の参考事例

3. Data Cloud + Vector DB → 自分株式会社の Supabase pgvector 設計の参考
   「全データソースを統合したリアルタイムRAG」の商用実装例
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 242→243社化: Salesforce Einstein 追加',
  'PS#3 S74。Salesforce Einstein (CRM AI基盤/Einstein 1 Platform/Agentforce自律AIエージェント/Atlas推論エンジン/Data Cloud/Einstein Trust Layer/MCP対応/セールスフォース・ジャパン/日本大企業導入多数/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
