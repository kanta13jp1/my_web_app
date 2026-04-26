-- PS#3 S66: AI大学 226→227社化 — Clay 追加
-- Clay: AI GTMデータプラットフォーム / セールスエンリッチメント / 100+データプロバイダー統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'clay',
  'overview',
  'Clay — AI GTMデータプラットフォーム (100+データプロバイダー統合/Claygent/セールスエンリッチメント)',
  $$## Clay — AI GTMデータプラットフォーム

**カテゴリ**: GTM (Go-to-Market) Intelligence / Sales Enrichment / AI Data Platform
**設立**: 2021年 / 本社: San Francisco, CA / 資金調達: ~$62M (Sequoia / Meritech / a16z)
**特徴**: 100+データプロバイダーのデータを1つに統合し、AIで見込み客情報を自動エンリッチする次世代セールスインテリジェンスプラットフォーム
**ユーザー**: GTMチーム / BDR / セールスエンジニア / RevOps / グロースマーケター
**評価**: 9/9

### 概要
Clay は **「セールスのためのスプレッドシート × AI」** とも称される革命的なGTMデータプラットフォーム。従来はApollo.io / ZoomInfo / Clearbit など複数のデータプロバイダーにそれぞれ高額なサブスクリプションを払い、データを手動でマージしていた。Clay はこれを **100+データプロバイダーのウォーターフォール統合** で解決し、さらに **Claygent** (AI Webリサーチエージェント) でLLMがWebを調査してカスタムデータを自動生成する。2024〜2025年のSaaS界で最も注目されるGTMツールの1つ。

### 主な機能

**データエンリッチメント (100+ソース)**
| カテゴリ | データプロバイダー |
|---------|-----------------|
| 連絡先情報 | Apollo / Hunter / Clearbit / Lusha |
| 会社情報 | Crunchbase / PitchBook / LinkedIn |
| 技術スタック | BuiltWith / Wappalyzer / Datanyze |
| 求人情報 | LinkedIn Jobs / Indeed (採用意向判断) |
| ニュース | Diffbot / NewsAPI (最新動向) |
| Web | Claygent (AI独自調査) |

**ウォーターフォールエンリッチメント**
```
メールアドレスを探す場合:
1st: Apollo.io で検索 → 見つかれば採用、見つからなければ→
2nd: Hunter.io で検索 → 見つかれば採用、見つからなければ→
3rd: Clearbit で検索 → 見つかれば採用、見つからなければ→
4th: Claygent (AIがWebリサーチ) → 発見率最大化
→ 複数ソースを自動試行して最高カバレッジを実現
```

**Claygent (AI Webリサーチエージェント)**
- カスタムプロンプトでAIがWebを自律調査
- 例: 「この会社のCTOが最近ブログで言及した技術課題は?」
- 例: 「この担当者がLinkedInで最近いいねしたコンテンツのトップ3は?」
- 例: 「この会社はSlack/Teamsどちらを使っているか?」
- → 従来データベースに存在しないカスタムデータを即座に生成

**パーソナライズドアウトリーチ**
- エンリッチデータ → LLM (GPT-4o/Claude) → 個別パーソナライズメール自動生成
- Webhookで Outreach / Salesloft / HubSpot / Instantly に直接配信
- A/Bテスト変数生成 / スパムスコア最適化

### ワークフロー例 (ICP→メール送信まで全自動)
```
1. CSVインポート / Apollo搜索 / LinkedIn URLリスト
2. Clay Table で自動エンリッチ:
   - 会社規模・資金調達・技術スタック (BuiltWith)
   - 担当者メール (Apollo→Hunter→Clearbitウォーターフォール)
   - 最近の会社ニュース (Diffbot)
3. Claygent: 「なぜ自分株式会社に興味があるか」の角度をAIが調査
4. GPT-4oが個別パーソナライズメール生成
5. Instantlyで一括配信 + 返信追跡
6. HubSpotにコンタクトと活動履歴を自動同期
```

### 競合との差別化
| 項目 | Clay | Apollo.io | ZoomInfo | Outreach |
|------|------|----------|----------|---------|
| データプロバイダー数 | **100+** | 1 (自社DB) | 1 (自社DB) | ❌ |
| AI研究エージェント | ✅ Claygent | ❌ | ❌ | ❌ |
| カスタムデータ | ✅ 無制限 | ❌ | ❌ | ❌ |
| ウォーターフォール | ✅ | ❌ | ❌ | ❌ |
| 価格/コスパ | ★★★★★ | ★★★ | ★★ | ★★ |
| 学習コスト | 中 | 低 | 低 | 低 |

### 導入コスト
- **Free**: 月100クレジット / 基本エンリッチ / Claygent限定
- **Starter**: 月$149 / 2,000クレジット / 全データプロバイダー
- **Explorer**: 月$349 / 10,000クレジット / Claygent無制限 / Webhook
- **Pro**: 月$800 / 50,000クレジット / チーム5名 / 優先サポート
- **Enterprise**: カスタム / 無制限 / SSO / 専任CSM$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'clay',
  'api',
  'Clay API — テーブル操作・エンリッチ実行・Webhook連携・Claygent呼び出し (Python)',
  $$## Clay API

### 概要
Clay は REST API + Webhook でテーブル操作・エンリッチ実行を外部から制御できる。

### セットアップ
```bash
# Clay → Settings → API Keys でキー取得
export CLAY_API_KEY="your_api_key_here"
export CLAY_BASE="https://api.clay.com/v1"
```

### テーブル操作 (Python)
```python
import requests
import os

CLAY_API_KEY = os.environ["CLAY_API_KEY"]
CLAY_BASE = os.environ["CLAY_BASE"]

HEADERS = {
    "Authorization": f"Bearer {CLAY_API_KEY}",
    "Content-Type": "application/json",
}

def list_tables() -> list:
    """Clayワークスペース内のテーブル一覧"""
    resp = requests.get(f"{CLAY_BASE}/tables", headers=HEADERS)
    resp.raise_for_status()
    return resp.json().get("tables", [])

def add_rows(table_id: str, rows: list) -> dict:
    """テーブルに行を追加 (エンリッチ自動開始)"""
    resp = requests.post(
        f"{CLAY_BASE}/tables/{table_id}/rows",
        json={"rows": rows},
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# テーブル一覧
tables = list_tables()
for t in tables:
    print(f"{t['name']} (ID: {t['id']})")

# 見込み客リストをClayテーブルに追加 (エンリッチ自動開始)
result = add_rows(
    table_id="table_abc123",
    rows=[
        {
            "company_name": "ABC株式会社",
            "website": "https://abc.co.jp",
            "linkedin_url": "https://linkedin.com/company/abc",
        },
        {
            "company_name": "XYZ テクノロジー",
            "website": "https://xyz-tech.com",
        },
    ],
)
print(f"追加行数: {result['added_count']}")
```

### Webhook受信 (エンリッチ完了後)
```python
import flask

app = flask.Flask(__name__)

@app.route("/clay-webhook", methods=["POST"])
def handle_clay_enrichment():
    """Clayエンリッチ完了後のWebhook受信"""
    data = flask.request.json
    enriched_rows = data.get("rows", [])

    for row in enriched_rows:
        company = row.get("company_name")
        email = row.get("email")  # ウォーターフォール結果
        tech_stack = row.get("technologies", [])
        recent_news = row.get("recent_news")
        claygent_insight = row.get("custom_ai_research")  # Claygent結果

        if email:
            # HubSpotにコンタクト追加
            add_to_hubspot({
                "email": email,
                "company": company,
                "properties": {
                    "tech_stack": ",".join(tech_stack[:5]),
                    "clay_insight": claygent_insight,
                },
            })
            print(f"✅ {company} ({email}) → HubSpot追加完了")
        else:
            print(f"⚠️ {company}: メール取得失敗")

    return {"status": "ok"}

def add_to_hubspot(contact: dict) -> None:
    hubspot_url = "https://api.hubapi.com/crm/v3/objects/contacts"
    # ... HubSpot API呼び出し
    pass
```

### Claygent API (AI Webリサーチ)
```python
def run_claygent(table_id: str, column_name: str, prompt_template: str) -> dict:
    """Claygent (AI Webリサーチエージェント) をAPIから実行"""
    resp = requests.post(
        f"{CLAY_BASE}/tables/{table_id}/enrichments/claygent",
        json={
            "column_name": column_name,
            "prompt": prompt_template,  # {{company_name}} などの変数使用可
        },
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# 各会社のAI活用状況をClaygentで調査
result = run_claygent(
    table_id="table_abc123",
    column_name="ai_usage_analysis",
    prompt_template="""
    {{company_name}} ({{website}}) のWebサイト・採用ページ・LinkedInを調査して:
    1. 現在使用しているAIツール (あれば)
    2. AI/自動化に関する最近の採用ポジション
    3. CTOまたは技術ブログで言及されたAI課題
    を200文字以内で日本語でまとめてください。
    """,
)
print(f"Claygent実行開始: {result['job_id']}")
```

### GHA × Clay 週次リード生成パイプライン
```yaml
# .github/workflows/weekly-lead-generation.yml
# 毎週月曜 09:00 JST → Clay API → ICPリード発掘 → HubSpot追加
steps:
  - name: Add ICP leads to Clay for enrichment
    env:
      CLAY_API_KEY: ${{ secrets.CLAY_API_KEY }}
    run: python scripts/weekly_lead_generation.py --table-id ${{ vars.CLAY_TABLE_ID }}
  - name: Wait for enrichment (5 min)
    run: sleep 300
  - name: Export enriched leads to HubSpot
    run: python scripts/export_clay_to_hubspot.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'clay',
  'models',
  'Clay AI技術詳細 — Claygentアーキテクチャ + ウォーターフォールエンジン + Sequoia $62M調達',
  $$## Clay AI 技術詳細

### Claygent のアーキテクチャ
```
[Claygentの処理フロー]

入力: カスタムプロンプト + 対象レコード (company/person データ)
       ↓
Context Builder:
  - レコードの既存フィールドを変数展開 ({{company_name}}, {{linkedin_url}} 等)
  - プロンプトを実行可能なリサーチタスクに変換
       ↓
Research Agent (ReAct ループ):
  - Web Search (Bing/Google) でキーワード検索
  - 上位ページをスクレイプして内容を抽出
  - LinkedIn / GitHub / Crunchbase を優先参照
  - 関連情報が見つかるまで最大5ステップ繰り返し
       ↓
Synthesis (GPT-4o / Claude 3.5):
  - 収集情報をプロンプト指定フォーマットに整理
  - 確信度スコア (High/Medium/Low) を付与
  - ソースURLリストを生成
       ↓
出力: カスタムフィールド値 + 確信度 + ソースURL
```

### ウォーターフォールエンジンの仕組み
```
[コスト最適化ウォーターフォール]

目標: メールアドレス取得 (精度 > コスト)

Step 1: 無料/安価なソース (Apollo Free tier)
  → 見つかればコスト $0.01 で完了
  → 見つからなければ次へ

Step 2: 中コストソース (Clearbit / Hunter)
  → クレジット 2-5 消費
  → 見つかれば採用

Step 3: 高精度ソース (Lusha / Kaspr)
  → クレジット 10-20 消費
  → 見つかれば採用

Step 4: Claygent (AI独自調査)
  → クレジット 30-50 消費
  → 最高コスト・最高カバレッジ

→ ウォーターフォールで平均コストを最小化しながら発見率最大化
→ 従来: 各サービスに月$500-2000 × 複数 → Clay: 月$349 で全サービス統合
```

### データプロバイダー統合数の競争優位
```
2026年現在の主要GTMツール データプロバイダー数:
- Clay: 100+
- Apollo.io: 1 (自社データベースのみ)
- ZoomInfo: 1 (自社データベースのみ)
- Clearbit: 1 (自社データベースのみ)
- Lusha: 1 (自社データベースのみ)

→ Clayのモートは「統合数」ではなく「ウォーターフォールロジック + Claygent」
→ 各データプロバイダーへのAPIコストをClay内部で分散 → ユーザーは単一料金で全利用
```

### Sequoia / a16z / Meritech 投資背景
- **$62M調達** (2024年): Sequoia Capital リード
- **NPS 72**: セールスコミュニティで異常に高い満足度
- **成長率**: 2023→2024年 ARR 3倍 (非公開 / セールスコミュニティ情報)
- **Virality**: GTMエンジニア・RevOps界隈での口コミ拡散が極めて強い

### 自分株式会社での活用可能性
- **採用候補者調査**: Claygentで候補者のGitHub/ブログ/OSS貢献を自動調査 → カルチャーフィット評価
- **投資家アウトリーチ**: VCパートナー情報をClay + Claygentで調査 → パーソナライズドPitch送信
- **競合190社モニタリング**: competitors テーブルの会社をClay経由で定期エンリッチ → 資金調達/採用動向検出
- **B2B顧客獲得**: ICP (スタートアップCTO/PMM) をClay経由で自動エンリッチ → パーソナライズドコールドメール
- **AI大学コンテンツ**: Claygentで各AIプロバイダーの最新ニュース・機能アップデートを週次収集$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 226→227社化: Clay 追加',
  'PS#3 S66。Clay (AI GTMデータプラットフォーム/100+データプロバイダーウォーターフォール/Claygent AI Webリサーチエージェント/セールスエンリッチメント/Sequoia/$62M/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
