-- PS#3 S68: AI大学 231→232社化 — Aisera 追加
-- Aisera: エンタープライズAIサービス管理 / AISM / ITサポート自動解決 / 会話AI / AI Copilot

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aisera',
  'overview',
  'Aisera — エンタープライズAI Service Management (ITIT/HR自動解決/LLM独自学習/Gladstone/$90M)',
  $$## Aisera — エンタープライズAI Service Management

**カテゴリ**: Enterprise AI / IT Service Management / Conversational AI / Employee Experience
**設立**: 2017年 / 本社: Palo Alto, CA / 資金調達: ~$90M (Gladstone Investment / True Ventures / Menlo Ventures / Norwest)
**評価額**: ~$500M+ (推定) / 顧客: 500+ エンタープライズ / ユーザー数: 50M+ 従業員
**特徴**: Generative AI + 独自LLM (AISM-LLM) でITサポート・HRサービス・カスタマーサービスを自動解決。ServiceNow/Jira/Workday と深く統合し、IT問い合わせの80%以上を自動解決する
**ユーザー**: IT部門 / HR部門 / CSチーム / 大企業従業員 (Fortune 500)
**評価**: 8/9

### 概要
Aisera は **「エンタープライズ向けAI Service Management (AISM)」** のパイオニア。2017年という早期から企業向けAIサポート自動化に特化し、ChatGPT登場前から独自のNLP/MLモデルをエンタープライズデータで訓練してきた。

2023年以降はGenerative AIを全面統合し、**「AiseraGPT」** として刷新。OpenAI/Google/Anthropic のLLMに加え、Aisera独自の **AISM-LLM** (業務ドメイン特化ファインチューニングモデル) を組み合わせて、エンタープライズデータに対して高精度な自動回答・自動実行を提供する。

### 主な機能

**AISM (AI Service Management) コア**
| カテゴリ | 自動解決できること |
|---------|------------------|
| **IT Support** | パスワードリセット / VPNアクセス / ソフトウェアプロビジョニング / ネットワーク問題 |
| **HR** | 有給申請 / 福利厚生照会 / 給与計算質問 / オンボーディング / 退職手続き |
| **Customer Service** | 注文状況 / 返金処理 / アカウント問題 / 製品FAQ |
| **Finance** | 経費精算 / 予算照会 / 支払いステータス |

**AiseraGPT (Generative AI統合)**
- 従業員の自然言語問い合わせ → LLMで意図理解 → 自動解決
- 「私のMacBookのBluetooth設定をリセットして」→ Jamf連携で自動実行
- マルチターン会話でコンテキストを維持
- 社内ナレッジベース (Confluence/SharePoint) から自動学習

**AI Copilot (エージェント機能)**
- エージェント向け: 複雑な問い合わせを人間エージェントに渡す際に関連情報・推奨アクションを自動提示
- 解決時間を平均 **40%短縮**
- ナレッジギャップを自動検出 → コンテンツ作成を提案

**AISM-LLM (独自モデル)**
- エンタープライズ業務データ (ITチケット / HRクエリ / 社内ポリシー) でファインチューニング
- 汎用LLMより業務固有クエリで高精度
- オンプレミス / プライベートクラウドデプロイ対応 (金融 / 医療向け)

### 導入実績
- **自動解決率**: IT問い合わせ 80%+ 自動解決
- **CSAT向上**: 平均 25%向上
- **TCO削減**: ヘルプデスクコスト 40-60%削減
- **主要顧客**: Autodesk / Zoom / McAfee / Dartmouth-Hitchcock (医療) / 多数の Fortune 500

### 競合との差別化
| 項目 | Aisera | Moveworks | ServiceNow AI | Intercom AI |
|------|--------|----------|--------------|-------------|
| IT自動実行 | ✅ | ✅ | ✅ | ❌ |
| HR統合 | ✅ | ✅ | △ | ❌ |
| CS自動化 | ✅ **強み** | △ | △ | ✅ |
| 独自LLM | ✅ AISM-LLM | ❌ | △ | ❌ |
| オンプレ対応 | ✅ | △ | ✅ | ❌ |
| 設立年 | **2017年** | 2016年 | — | 2011年 |

### 導入コスト
- **Enterprise Only**: 年間契約 / 従業員数またはチケット数ベース課金
- 概算: 1,000名規模で年間$200K〜$400K
- Moveworks比較: 同価格帯 / CSサポートに強みあり$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aisera',
  'api',
  'Aisera API — AI Service Management自動化・チケット解決・Webhook統合 (Python/TypeScript)',
  $$## Aisera API / 統合

### 概要
Aisera は REST API + Webhook でITSM/HRシステムと統合。会話AI・自動アクション・レポートを外部から呼び出せる。

### セットアップ
```bash
export AISERA_API_KEY="your_api_key_here"
export AISERA_TENANT_ID="your_tenant_id"
export AISERA_BASE="https://api.aisera.com/v1"
```

### 会話セッション作成 (チャット)
```python
import requests
import os

AISERA_API_KEY = os.environ["AISERA_API_KEY"]
AISERA_TENANT_ID = os.environ["AISERA_TENANT_ID"]
AISERA_BASE = os.environ["AISERA_BASE"]

HEADERS = {
    "Authorization": f"Bearer {AISERA_API_KEY}",
    "X-Tenant-ID": AISERA_TENANT_ID,
    "Content-Type": "application/json",
}

def create_session(user_email: str, channel: str = "api") -> str:
    """Aisera会話セッションを作成してsession_idを返す"""
    resp = requests.post(
        f"{AISERA_BASE}/sessions",
        json={
            "user": {"email": user_email},
            "channel": channel,
        },
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()["session_id"]

def send_message(session_id: str, message: str) -> dict:
    """Aisera AIに質問を送信して回答と自動アクションを受信"""
    resp = requests.post(
        f"{AISERA_BASE}/sessions/{session_id}/messages",
        json={"text": message},
        headers=HEADERS,
    )
    resp.raise_for_status()
    data = resp.json()
    return {
        "response": data.get("response", {}).get("text", ""),
        "actions_taken": data.get("actions", []),
        "resolution_status": data.get("resolution_status"),
        "confidence": data.get("confidence", 0.0),
    }

# ITサポートリクエストの自動処理
session_id = create_session("tanaka@jibun.co.jp")
result = send_message(session_id, "会社のVPNに繋がらなくなりました。Cisco AnyConnectがエラーを出しています")
print(f"Aisera回答: {result['response']}")
print(f"自動実行アクション: {result['actions_taken']}")
print(f"解決ステータス: {result['resolution_status']}")
```

### チケット自動解決チェック
```python
def check_ticket_resolution(ticket_id: str) -> dict:
    """ServiceNow/Jira チケットの自動解決ステータスを確認"""
    resp = requests.get(
        f"{AISERA_BASE}/tickets/{ticket_id}/resolution",
        headers=HEADERS,
    )
    resp.raise_for_status()
    data = resp.json()
    return {
        "auto_resolved": data.get("auto_resolved", False),
        "resolution_method": data.get("resolution_method"),
        "time_to_resolve_seconds": data.get("time_to_resolve"),
        "csat_score": data.get("csat_score"),
    }

# 解決率レポート (ダッシュボード用)
def get_resolution_stats(start_date: str, end_date: str) -> dict:
    """期間内の自動解決率・CSAT・コスト削減を取得"""
    resp = requests.get(
        f"{AISERA_BASE}/analytics/resolution-stats",
        headers=HEADERS,
        params={"start": start_date, "end": end_date},
    )
    resp.raise_for_status()
    return resp.json()
```

### Webhook受信 (Aisera → 自システム)
```python
import flask
import hmac
import hashlib

app = flask.Flask(__name__)

@app.route("/aisera-webhook", methods=["POST"])
def handle_aisera_event():
    """Aisera イベントのWebhook受信"""
    # 署名検証
    signature = flask.request.headers.get("X-Aisera-Signature", "")
    body = flask.request.get_data()
    expected = hmac.new(
        os.environ["AISERA_WEBHOOK_SECRET"].encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(signature, f"sha256={expected}"):
        return flask.abort(401)

    event = flask.request.json
    event_type = event.get("event_type")

    if event_type == "ticket.auto_resolved":
        # 自動解決時 → 解決ログをSupabaseに保存
        log_resolution_to_supabase(event["ticket"])

    elif event_type == "ticket.escalated":
        # エスカレーション → Slackに通知
        notify_slack_escalation(event["ticket"])

    return {"status": "ok"}
```

### ServiceNow統合設定
```json
{
  "integrations": {
    "servicenow": {
      "instance_url": "https://your-instance.service-now.com",
      "username": "aisera_integration",
      "password_secret": "SNOW_PASSWORD",
      "auto_resolve_categories": [
        "password_reset",
        "vpn_access",
        "software_install"
      ],
      "escalation_categories": [
        "hardware_failure",
        "security_incident",
        "data_breach"
      ]
    }
  }
}
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'aisera',
  'models',
  'Aisera AI技術詳細 — AISM-LLM独自モデル + Generative AI統合 + エンタープライズAI Service Management進化',
  $$## Aisera AI 技術詳細

### AISM-LLM (独自エンタープライズLLM)
```
[Aisera のLLM戦略: Foundation + Domain-Specific]

汎用LLM (GPT-4o / Claude 3.5 / Gemini 1.5):
  - 一般的な質問回答・文章生成
  - パブリック知識: 製品FAQ / 一般ITトラブルシュート

AISM-LLM (Aisera独自):
  - エンタープライズ業務データでファインチューニング済み
  - 学習データ: 顧客のITチケット履歴 / HRポリシー文書 / 社内ナレッジベース
  - 特化領域: 企業固有の手順・システム名・略語を正確に理解
  - 例: 「Oracle ERP R12のユーザー権限申請手順」を社内標準フローで回答

オーケストレーション層:
  - クエリの複雑さ・機密性・ドメインに応じてLLMを自動選択
  - 機密データ → AISM-LLM (社内処理、クラウドLLM非使用)
  - 一般質問 → GPT-4o (コスト効率優先)
```

### Generative AI統合アーキテクチャ
```
[AiseraGPT リクエスト処理フロー]

従業員入力 (Slack / Teams / Web ポータル / メール)
       ↓
Query Understanding:
  - Aisera独自NLU (2017年から7年分のエンタープライズデータ学習)
  - 意図分類: ITリクエスト / HRクエリ / CSサポート / 一般質問
  - エンティティ抽出: ユーザー / システム / 緊急度 / カテゴリ
  - 感情分析: フラストレーション高 → 人間エスカレーション優先
       ↓
Knowledge Retrieval (RAG):
  - 社内ナレッジベース (Confluence / SharePoint / Guru)
  - 過去の解決済みチケット (類似ケース参照)
  - ITSMシステム状態 (現在のインシデント/メンテナンス情報)
       ↓
LLM Synthesis (AISM-LLM + GPT-4o):
  - 取得した知識を基に自然言語回答を生成
  - 実行可能なアクションがある場合はアクションプランを生成
  - 信頼スコア計算 (0.0〜1.0)
       ↓
Action Execution (System Integration):
  信頼スコア > 0.85 → 自動実行 (人間承認不要)
  信頼スコア 0.6〜0.85 → 確認メッセージ送信
  信頼スコア < 0.6 → 人間エージェントにエスカレーション
       ↓
Resolution & Learning:
  - 解決結果をフィードバック (強化学習)
  - 新規ナレッジギャップを検出 → コンテンツチーム通知
```

### エンタープライズAI Service Management 市場
```
2017-2019: ルールベース時代
  → If-Then ルールエンジン / FAQ検索 / 単純チケット振り分け
  → 自動解決率: ~20-30%

2020-2022: ML時代
  → BERT / GPT-2ベースの意図分類
  → 自動解決率: ~40-50%
  → Aisera / Moveworks が先行

2023-2024: Generative AI統合
  → GPT-4 / Claude 3 / Gemini をオーケストレーション
  → 複雑な多段階タスクの自動実行
  → 自動解決率: **70-85%**
  → Creator Studio / ノーコードビルダーの普及

2025-2026以降: Agentic AI
  → 単一タスク解決から「新入社員オンボーディング全自動」へ
  → マルチシステム横断エージェント (AD + Okta + Workday + M365 を並行操作)
  → 人間は「承認」だけに集中
```

### 自分株式会社での活用可能性
- **スタートアップ期は対象外**: Aisera は500名以上の大企業専用 / 中小企業プランなし
- **アーキテクチャ参考**: Aisera の「信頼スコアによる自動実行/確認/エスカレーション」3段階分岐を自分株式会社のAIエージェント設計に応用
- **競合分析**: Aisera vs Moveworks の差別化 (CSサポートに強いAisera / ITサポート特化Moveworks) → 自分株式会社のポジション設計に参考
- **AI大学コンテンツ**: エンタープライズAI導入事例の代表例として / Zoom・Autodesk 等の大企業導入事例が説得力高
- **将来展望**: 自分株式会社がB2B企業向け展開時のベンチマーク (「SMB向けAisera」ポジション)$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 231→232社化: Aisera 追加',
  'PS#3 S68。Aisera (エンタープライズAI Service Management/AISM-LLM独自モデル/IT問い合わせ80%自動解決/ServiceNow統合/AiseraGPT/Gladstone/Menlo/$90M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
