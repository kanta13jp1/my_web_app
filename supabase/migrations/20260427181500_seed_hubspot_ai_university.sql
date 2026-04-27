-- PS#3 S76: AI大学 247→248社化 — HubSpot AI (Breeze) 追加
-- HubSpot AI: CRM × AI統合 / Breeze Copilot+Agents / 無料プランあり / SMB向け / Salesforce対抗

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hubspot_ai',
  'overview',
  'HubSpot AI (Breeze) — CRM×AI統合 (Breeze Copilot / Breeze Agents / 無料プラン / SMB向け / Salesforce対抗)',
  $$## HubSpot AI (Breeze) — CRM × AI プラットフォーム

**カテゴリ**: CRM AI / Marketing AI / Sales AI / Customer Service AI / SMB向け
**開発元**: HubSpot, Inc.
**本社**: Cambridge, Massachusetts
**設立**: 2006年 (Brian Halligan + Dharmesh Shah)
**上場**: NYSE: HUBS (2014年〜)
**売上**: 約$25億/年 (2025年度)
**AI ブランド**: Breeze (2024年9月発表)
**日本法人**: HubSpot Japan 株式会社 (東京)
**評価**: 8/9

### 概要
HubSpot AI は 2024年9月に発表された **「Breeze」** ブランドのもと、HubSpot CRM 全体に AI を統合したプラットフォーム。Salesforce Einstein と異なり **無料プランから AI 機能を利用できる** 点が中小企業・スタートアップに支持される大きな差別化要因。

**Inbound Marketing の発明者**: HubSpot は「コンテンツマーケティング」「インバウンドマーケティング」の概念を普及させた企業。現在はマーケティング・セールス・カスタマーサービスを統合した CRM スイートに AI を組み込んでいる。

**日本での普及**: HubSpot Japan は2013年に設立。日本語コンテンツが充実しており、中小〜中堅企業でのマーケティングオートメーション基盤として普及している。

### Breeze AI 製品群

**1. Breeze Copilot**
- HubSpot UI 内に常駐するAIアシスタント
- CRM データを参照しながら自然言語でタスクを実行
- 使用例:
  - 「山田商事の商談履歴を要約して」
  - 「次週のフォローアップメールの下書きを作成して」
  - 「今月の KPI ダッシュボードを作成して」
- 全 Hub (Marketing / Sales / Service / Content) で使用可

**2. Breeze Agents (自律AIエージェント)**
| エージェント | 機能 |
|------------|------|
| Content Agent | SEO記事 / LP / メール / SNS投稿を自動生成 |
| Prospecting Agent | ターゲット企業リストの調査・メール作成 |
| Customer Agent | 問い合わせの自動対応・エスカレーション判断 |
| Social Agent | SNS投稿案の生成・スケジューリング |

**3. Breeze Intelligence**
- 200M+ 企業データベースから見込み客情報を自動補完
- Web訪問者の企業特定 (Buyer Intent)
- CRMデータのクリーニング・重複統合

**4. AI コンテンツ生成**
- Blog / LP / 広告コピー / メールのAI生成
- SEO提案: 検索ボリューム・難易度スコアを参照した記事案
- A/Bテストの候補バリアント自動生成

### HubSpot vs Salesforce 比較

| 項目 | HubSpot (Breeze) | Salesforce (Einstein) |
|------|-----------------|---------------------|
| ターゲット | SMB / スタートアップ | エンタープライズ |
| 無料プラン | ✅ 充実 | ❌ (基本有料) |
| AI機能の開始価格 | 無料〜$20/月 | $150+/user/月 |
| 導入のしやすさ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| カスタマイズ性 | 中 | 高 |
| 日本語サポート | ✅ 充実 | ✅ 充実 |
| マーケティング機能 | ✅ 強い | △ |
| エンタープライズ機能 | △ | ✅ 強い |

### 価格プラン
| プラン | 月額/ユーザー | AI機能 |
|--------|-------------|--------|
| Free | $0 | Breeze Copilot (制限付き) |
| Starter | $20 | Breeze Copilot フル / 基本AI |
| Professional | $100 | Breeze Agents / AI コンテンツ |
| Enterprise | $150 | Breeze Intelligence / 高度分析 |

### 自分株式会社との関連性
```
競合21社との関係:
  自分株式会社の競合21社にはHubSpotは含まれていないが、
  マーケティング自動化・CRM機能を提供する点でバリューチェーンが重複

AI大学コンテンツとしての価値:
  「HubSpot vs Salesforce: 中小企業はどちらのCRM AIを選ぶべきか」
  「Breeze Agents で営業チームの業務を自動化する方法」
  日本のSMB向けマーケティング記事として高い検索需要

将来シナリオ:
  自分株式会社ユーザー (経営者・営業) が HubSpot と連携したい場合
  → HubSpot API × 自分株式会社のSupabase連携機能の需要が発生$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hubspot_ai',
  'api',
  'HubSpot API — REST API / Contacts・Deals CRUD / Breeze AI Endpoints / Supabase連携パターン',
  $$## HubSpot API / 統合ガイド

### 概要
HubSpot は REST API を提供しており、コンタクト・商談・メール送信・フォーム・コンテンツ管理などをプログラムから操作できる。

### 認証
```python
# Private App Access Token (推奨)
# Settings > Integrations > Private Apps で作成

HUBSPOT_API_KEY = "pat-na1-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

headers = {
    "Authorization": f"Bearer {HUBSPOT_API_KEY}",
    "Content-Type": "application/json",
}
BASE_URL = "https://api.hubapi.com"
```

### コンタクト (顧客) 操作
```python
import requests

def create_contact(email: str, first_name: str, last_name: str, company: str) -> dict:
    """新規コンタクトを作成"""
    response = requests.post(
        f"{BASE_URL}/crm/v3/objects/contacts",
        headers=headers,
        json={
            "properties": {
                "email": email,
                "firstname": first_name,
                "lastname": last_name,
                "company": company,
            }
        },
    )
    return response.json()

def get_contacts(limit: int = 10) -> list[dict]:
    """コンタクト一覧を取得"""
    response = requests.get(
        f"{BASE_URL}/crm/v3/objects/contacts",
        headers=headers,
        params={
            "limit": limit,
            "properties": "email,firstname,lastname,company,hs_lead_status",
        },
    )
    return response.json().get("results", [])

def update_contact(contact_id: str, properties: dict) -> dict:
    """コンタクトを更新"""
    response = requests.patch(
        f"{BASE_URL}/crm/v3/objects/contacts/{contact_id}",
        headers=headers,
        json={"properties": properties},
    )
    return response.json()

# 使用例: Supabase の新規ユーザーを HubSpot に同期
new_user = {"email": "taro@example.com", "first_name": "太郎", "last_name": "山田", "company": "自分株式会社"}
contact = create_contact(**new_user)
print(f"HubSpot Contact ID: {contact['id']}")
```

### 商談 (Deals) 管理
```python
def create_deal(deal_name: str, amount: float, stage: str, contact_id: str) -> dict:
    """商談を作成してコンタクトに関連付け"""
    # 商談を作成
    deal = requests.post(
        f"{BASE_URL}/crm/v3/objects/deals",
        headers=headers,
        json={
            "properties": {
                "dealname": deal_name,
                "amount": str(amount),
                "dealstage": stage,  # "appointmentscheduled" / "qualifiedtobuy" / "closedwon"
                "closedate": "2026-12-31",
            }
        },
    ).json()

    # 商談とコンタクトを関連付け
    requests.put(
        f"{BASE_URL}/crm/v4/objects/deals/{deal['id']}/associations/contacts/{contact_id}/3",
        headers=headers,
    )
    return deal
```

### Webhook (HubSpot → Supabase)
```typescript
// Supabase Edge Function: HubSpot Webhook を受信
// HubSpot でフォーム送信・商談更新時に自動呼び出し

Deno.serve(async (req: Request) => {
  // HubSpot Webhook の署名検証
  const signature = req.headers.get("X-HubSpot-Signature-v3") ?? "";
  const body = await req.text();

  // 署名検証 (省略: HMAC-SHA256)
  const events = JSON.parse(body);

  for (const event of events) {
    if (event.subscriptionType === "contact.creation") {
      // 新規コンタクト → Supabase に保存
      const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
      const supabase = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );

      await supabase.from("crm_contacts").upsert({
        hubspot_id: event.objectId,
        email: event.properties?.email,
        source: "hubspot_webhook",
        synced_at: new Date().toISOString(),
      });
    }
  }

  return new Response(JSON.stringify({ ok: true }));
});
```

### Breeze AI API (コンテンツ生成)
```python
def generate_blog_post(topic: str, keywords: list[str]) -> dict:
    """Breeze AI でブログ記事を生成"""
    response = requests.post(
        f"{BASE_URL}/content/v1/ai/generate",
        headers=headers,
        json={
            "contentType": "BLOG_POST",
            "topic": topic,
            "keywords": keywords,
            "language": "ja",
            "tone": "professional",
            "length": "MEDIUM",
        },
    )
    return response.json()

# 使用例
post = generate_blog_post(
    topic="AIを活用した中小企業の業務効率化",
    keywords=["AI", "業務自動化", "中小企業", "DX"],
)
print(post.get("content", ""))
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'hubspot_ai',
  'models',
  'HubSpot AI 技術詳細 — Breeze Intelligence設計 / Inbound AIアーキテクチャ / Marketing Automation × AI / 日本市場戦略',
  $$## HubSpot AI 技術詳細

### Breeze AI アーキテクチャ

```
[Breeze AI の技術構成]

HubSpot CRM データ層
  ├── コンタクト (顧客情報)
  ├── 商談 (Deals)
  ├── マーケティングデータ (メール開封率・広告etc)
  └── カスタマーサービス (チケット)
      ↓
Breeze Intelligence (データエンリッチメント)
  ├── Clearbit / ZoomInfo 等の外部データ統合 (200M+社)
  ├── Buyer Intent: Web訪問から購買意欲を推定
  └── データクレンジング: 重複除去・情報補完
      ↓
Breeze AI エンジン (LLM層)
  ├── OpenAI GPT-4 (主要モデル — HubSpotはMicrosoft Azure AI利用)
  ├── カスタムファインチューニング (マーケティング特化)
  └── RAG: CRMデータを文脈に注入
      ↓
製品層
  ├── Copilot (会話型AI)
  ├── Agents (自律実行AI)
  └── AI Features (各Hubに組み込まれたAI機能)
```

### Inbound Marketing × AI の仕組み

```
[HubSpot が定義する「AI-Powered Inbound」]

従来のインバウンド:
  コンテンツ作成 (週に数本) → SEO → 読者獲得 → リード育成 (手動)

AI-Powered インバウンド:
  Breeze Content Agent → 週100本のSEO記事を自動生成
       ↓
  Breeze Intelligence → Web訪問企業を特定・スコアリング
       ↓
  Breeze Prospecting Agent → ターゲットに合わせたメール自動送信
       ↓
  Breeze Customer Agent → 24時間自動対応
       ↓
  人間の営業担当 → 高確度の商談のみに集中

→ 「少人数チームで大企業並みのマーケティング活動」を実現
```

### Marketing Automation の進化

```
[世代別比較]

第1世代 (2006-2015): ルールベース自動化
  if メール開封 then フォローアップメール送信 (3日後)
  → シンプルな条件分岐

第2世代 (2015-2022): スコアリング + セグメンテーション
  ページ訪問 (+5点) + フォーム送信 (+20点)
  → スコア50点以上 → 営業担当に通知

第3世代 (2023〜): AI駆動の予測とパーソナライゼーション
  各リードの行動パターン → AIが最適なコンテンツ・タイミングを予測
  → 1対1のパーソナライズドな顧客体験をスケールで実現

HubSpot Breeze (2024〜): 自律エージェント
  Content Agent / Prospecting Agent / Customer Agent が自律実行
  → 人間は意思決定のみに集中
```

### 日本市場戦略

```
HubSpot Japan の強み:
  1. 日本語コンテンツ: ブログ・ウェビナー・認定資格 (HubSpot Academy) が日本語化
  2. 無料CRM: 中小企業のIT予算が限られる日本市場に最適
  3. パートナーエコシステム: 国内の Marketing Agency がHubSpot認定パートナーに

日本企業の採用傾向:
  スタートアップ〜中堅企業 (従業員50〜500名) に多い
  「Salesforceは高い / 機能が多すぎる → HubSpotで始める」
  SaaS企業のマーケティング基盤として標準ツール化

競合:
  Salesforce (エンタープライズ) / Microsoft Dynamics (ERP統合) /
  Zoho CRM (低価格) / kintone (国産)
```

### 自分株式会社との関連性

```
1. AI大学コンテンツの活用価値:
   「HubSpot Breeze で無料からAIマーケティング自動化を始める方法」
   「HubSpot vs Salesforce: スタートアップが選ぶべきCRM AI」
   → 日本の起業家・スタートアップ向けコンテンツとして高需要

2. 機能比較の観点:
   自分株式会社の「6部署バランス」原則 (PHILOSOPHY.md)
   → マーケティング部署の機能として HubSpot 的な CRM/MA 機能を
     将来実装する際の参考アーキテクチャ

3. API統合候補:
   将来の有料プラン向けに HubSpot CRM との連携機能を提供
   → 「自分株式会社でリード管理 → HubSpot に自動同期」
   → 経営者ユーザーのワークフロー効率化に直結
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 247→248社化: HubSpot AI (Breeze) 追加',
  'PS#3 S76。HubSpot AI Breeze (CRM×AI統合/Breeze Copilot+4種Agents/Breeze Intelligence 200M+社DB/無料プランあり/Inbound Marketing発明者/日本語対応/SMB向けSalesforce対抗/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
