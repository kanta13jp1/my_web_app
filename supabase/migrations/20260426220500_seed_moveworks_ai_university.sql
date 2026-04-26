-- PS#3 S67: AI大学 229→230社化 — Moveworks 追加
-- Moveworks: エンタープライズAI自動化 / ITサポート自動化 / 100+システム統合 / ServiceNow連携

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'moveworks',
  'overview',
  'Moveworks — エンタープライズAI自動化 (ITサポート/HR/Finance自動解決/100+システム統合/$830M)',
  $$## Moveworks — エンタープライズAI自動化プラットフォーム

**カテゴリ**: Enterprise AI / IT Service Management / Employee Experience Platform
**設立**: 2016年 / 本社: Mountain View, CA / 資金調達: ~$305M (Kleiner Perkins / Tiger Global / Iconiq)
**評価額**: ~$2.1B (2021年 Series C) → Microsoftが~$830Mで買収提案 (2024年 非公式)
**特徴**: 従業員のITサポート・HR・Finance問い合わせをAIが自動解決。ServiceNow/Jira/WorkdayなどEnterprise SaaSと深く統合
**ユーザー**: 大企業 (Fortune 500) / IT部門 / HR部門 / 従業員全般
**評価**: 8/9

### 概要
Moveworks は **「エンタープライズ版ChatGPT + IT自動化」** ともいえる企業向けAIプラットフォーム。従業員が「Slackで質問するだけで」ITチケット・パスワードリセット・ソフトウェアリクエスト・HR手続き・支出精算を自動解決する。社内の100+システム (ServiceNow / Jira / Workday / SAP / Active Directory等) と深く統合し、ヘルプデスク業務の**75%以上を自動解決**する実績を持つ。

2024年に **Creator Studio** (ノーコードAIエージェントビルダー) を追加し、IT担当者が独自の自動化フローを構築できるようになった。

### 主な機能

**AI従業員サポート (コア機能)**
| カテゴリ | 自動解決できること |
|---------|------------------|
| **ITサポート** | パスワードリセット / VPNアクセス / ソフトウェアインストール / デバイス設定 / WiFi問題 |
| **HRサポート** | 有給残高確認 / 福利厚生案内 / 出産・育休手続き / オンボーディング / 退職手続き |
| **Finance** | 支出精算承認 / 予算確認 / 発注依頼 / 請求書照合 |
| **コンプライアンス** | ポリシー案内 / セキュリティ研修状況 / アクセス申請 |

**Creator Studio (2024)**
- ノーコードで業務特化AIエージェントを構築
- 「このプロセスを自動化して」と自然言語で指定 → フロー自動生成
- 既存API / データベース / SaaSへのコネクター (200+)

**Moveworks Enterprise Search**
- 社内の全ドキュメント (Confluence/SharePoint/Google Drive/Notion) を横断検索
- 「Q3の財務報告はどこ?」→ 即座に該当ドキュメントとセクションを提示
- 回答に必ずソースドキュメントのリンクを付与

**Agentic AI (2024)**
- 多段階タスクを自律実行: 「新入社員のITセットアップを全部やって」
- Active Directory + Okta + Workday + M365 を横断して一連の操作を自動実行
- 人間のApproval が必要な箇所のみ通知して確認を求める

### 導入実績
- **Fortune 500** 企業の主要顧客
- **平均解決率**: 75%+ の問い合わせを人間不介入で自動解決
- **MTTR短縮**: 平均解決時間 4.5時間 → 11分 (Broadcom社事例)
- **主要顧客**: Broadcom / Autodesk / Palo Alto Networks / Hearst / DocuSign

### 競合との差別化
| 項目 | Moveworks | ServiceNow AI | Zendesk AI | Glean |
|------|----------|--------------|-----------|-------|
| IT自動実行 | ✅ 高度 | ✅ | △ | ❌ |
| HR統合 | ✅ | △ | ❌ | ❌ |
| 自動解決率 | **75%+** | 40-60% | 40% | N/A |
| ノーコードビルダー | ✅ | ✅ | △ | ❌ |
| エンタープライズ統合数 | **200+** | 多数 | 100+ | 多数 |
| 導入コスト | 高 (年契約) | 高 | 中 | 高 |

### 導入コスト
- **Enterprise Only**: 年間契約 / 従業員数ベース課金
- 概算: 1,000名規模で年間$300K〜$500K
- 中小企業向けプランは非提供 (500名以上推奨)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'moveworks',
  'api',
  'Moveworks API — AI自動化アクション・Creator Studio・Slack/Teams統合 (Python/TypeScript)',
  $$## Moveworks API / 統合

### 概要
Moveworks は REST API + Webhook で外部システムと統合。Creator Studio でカスタムアクションを定義できる。

### セットアップ
```bash
# Moveworks Partner Portal → API キー発行
export MOVEWORKS_API_KEY="your_api_key_here"
export MOVEWORKS_BASE="https://api.moveworks.ai/rest/v1"
export MOVEWORKS_BOT_TOKEN="your_bot_token"
```

### メッセージ送信 API (従業員への通知)
```python
import requests
import os

MOVEWORKS_API_KEY = os.environ["MOVEWORKS_API_KEY"]
MOVEWORKS_BOT_TOKEN = os.environ["MOVEWORKS_BOT_TOKEN"]
MOVEWORKS_BASE = os.environ["MOVEWORKS_BASE"]

HEADERS = {
    "Authorization": f"Bearer {MOVEWORKS_API_KEY}",
    "Content-Type": "application/json",
}

def send_message_to_user(user_email: str, message: str, rich_actions: list = None) -> dict:
    """Moveworks経由で従業員にSlack/Teamsメッセージを送信"""
    payload = {
        "message": {
            "parts": [
                {
                    "type": "text",
                    "text": message,
                }
            ]
        },
        "recipients": [{"identifier": user_email, "type": "email"}],
    }
    if rich_actions:
        payload["message"]["parts"].append({
            "type": "actions",
            "actions": rich_actions,
        })
    resp = requests.post(
        f"{MOVEWORKS_BASE}/messages/send",
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# 新機能リリースを全社員に通知
send_message_to_user(
    user_email="tanaka@jibun.co.jp",
    message="✅ 自分株式会社アプリが v3.2 にアップデートされました。新機能: AI予算アドバイス / 競合比較ダッシュボード",
    rich_actions=[
        {"type": "button", "text": "アップデート内容を見る", "url": "https://my-web-app-b67f4.web.app/changelog"},
        {"type": "button", "text": "今すぐ確認", "url": "https://my-web-app-b67f4.web.app/"},
    ],
)
```

### Creator Studio API (カスタムプラグイン)
```python
def trigger_custom_plugin(plugin_name: str, user_email: str, params: dict) -> dict:
    """Creator Studioで作成したカスタムプラグインをAPI経由でトリガー"""
    resp = requests.post(
        f"{MOVEWORKS_BASE}/plugins/{plugin_name}/trigger",
        json={
            "user": {"email": user_email},
            "parameters": params,
        },
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# 「AI大学コース完了時に次のコースを推薦する」カスタムプラグイン
result = trigger_custom_plugin(
    plugin_name="ai-university-course-recommender",
    user_email="user@example.com",
    params={
        "completed_provider": "openai",
        "score": 85,
        "next_category": "development-tools",
    },
)
```

### Webhook受信 (Moveworks → 自システム)
```python
import flask
import hmac
import hashlib

app = flask.Flask(__name__)

@app.route("/moveworks-webhook", methods=["POST"])
def handle_moveworks_event():
    """Moveworksからのイベント受信"""
    # 署名検証
    signature = flask.request.headers.get("X-Moveworks-Signature")
    body = flask.request.get_data()
    expected_sig = hmac.new(
        os.environ["MOVEWORKS_WEBHOOK_SECRET"].encode(),
        body,
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(signature, f"sha256={expected_sig}"):
        return flask.abort(401)

    event = flask.request.json
    event_type = event.get("type")

    if event_type == "ticket.resolved":
        # チケット解決時 → Supabaseにログ記録
        ticket_id = event["ticket"]["id"]
        resolution = event["ticket"]["resolution"]
        log_to_supabase(ticket_id, resolution)

    return {"status": "ok"}
```

### Slack Bot 統合 (Moveworks ← Slack)
```
Slack ワークスペースに Moveworks Bot を追加:
  1. IT管理者: Moveworks ダッシュボード → Integrations → Slack → "Add to Slack"
  2. 全従業員が @Moveworks にDMで質問可能

使用例:
  従業員: @Moveworks VPNが繋がらない
  Moveworks AI: 以下を試してください:
    1. Cisco AnyConnect を再起動
    2. [自動] Okta認証トークンをリフレッシュしました ✅
    3. 上記で解決しない場合: #it-support にエスカレート

  従業員: @Moveworks 有給残何日残ってる?
  Moveworks AI: Workdayを確認しました。2026年4月26日現在:
    有給: 12日 / 夏季休暇: 5日 / 慶弔: 3日 (残)
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'moveworks',
  'models',
  'Moveworks AI技術詳細 — LLMオーケストレーション + 200+システム統合 + Microsoft買収戦略',
  $$## Moveworks AI 技術詳細

### AIアーキテクチャ (LLM オーケストレーション)
```
[Moveworks のリクエスト処理フロー]

従業員の自然言語入力 (Slack/Teams/Web)
       ↓
Intent Recognition (Moveworks独自NLU):
  - 意図分類: ITリクエスト / HRクエリ / Finance / 一般Q&A
  - エンティティ抽出: ユーザー名 / システム名 / 日付 / 金額
  - 曖昧な場合: 確認質問を自動生成
       ↓
Orchestration Layer (LLMによる計画生成):
  - 必要なアクションステップを計画
  - 例: 「VPN設定 → Active Directory確認 → Cisco AnyConnect再設定 → テスト」
  - 各ステップで必要な権限・承認を事前チェック
       ↓
System Integration (200+ コネクター):
  - ServiceNow: チケット作成・更新・照会
  - Active Directory / Okta: ユーザー・グループ管理
  - Workday / SAP: HR・Finance データ取得
  - Jira / Confluence: 開発・ドキュメント
  - Microsoft 365 / Google Workspace
  (必要に応じて複数システムを並行操作)
       ↓
Human-in-the-Loop (必要時のみ):
  - 権限不足 / 高リスクアクション → 承認者にSlack通知
  - 承認ワンクリック → 自動実行再開
       ↓
Result & Learning:
  - 実行結果を従業員に報告
  - 成功/失敗パターンをモデルにフィードバック
```

### Moveworks独自NLU vs 汎用LLM
```
汎用LLM (GPT-4/Claude) の課題:
  → 「Oracleのアクセス権を申請して」を受け取ると
  → 「申請方法を教えます: ①...②...」と説明するだけ
  → 実際にシステムにアクセスして申請を実行することはできない

Moveworks のアプローチ:
  → 意図「Oracleアクセス申請」を検出
  → ServiceNow にアクセスリクエストチケットを自動作成
  → 承認者 (IT部門マネージャー) にSlackで通知
  → 承認後 → Active DirectoryのOracleグループにユーザーを追加
  → 完了をリクエスト者のSlackに自動報告
  → 人間は承認ボタン1クリックのみ
```

### Microsoft買収との戦略的文脈
```
2024年 Microsoft による Moveworks 買収交渉 (~$830M):

Microsoft の動機:
  - Microsoft 365 Copilot (Teams/Outlook/Excel AI) の弱点: IT自動化実行力
  - Moveworks の 200+コネクター + 自動解決75%+ を統合したい
  - Copilot Studio (ノーコードビルダー) の強化
  - ServiceNow への対抗: M365 エコシステム内でITSMを完結

Moveworks の競合優位:
  - 6年間蓄積したエンタープライズITデータ (最強のモート)
  - Fortune 500 顧客リストと長期契約
  - Creator Studio でエンドツーエンドの自動化を実現

→ AI自動化のエンタープライズ市場は2025〜2030年に急拡大予測
```

### 自分株式会社での活用可能性
- **スタートアップ期の活用は難易度高**: Moveworks は大企業向け / 500名以下は対象外
- **参照モデルとして**: Moveworks のアーキテクチャ (Intent → Plan → Execute → Approve) を自分株式会社のAIエージェント設計に応用
- **競合分析**: tools-hub のアクション設計 (wbs.xxx / page.xxx) は Moveworks の「従業員向けAI操作」コンセプトと類似 → 参考に
- **将来展望**: 自分株式会社がEnterprise向けに展開する際のベンチマーク (「Moveworksの中小企業版」ポジション)
- **AI大学コンテンツ**: エンタープライズAI導入事例の代表例として紹介 / Broadcom社の MTTR 4.5h→11min 事例がコンテンツとして強力$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 229→230社化: Moveworks 追加',
  'PS#3 S67。Moveworks (エンタープライズAI自動化/ITサポート75%自動解決/200+システム統合/Creator Studio/Kleiner Perkins/$305M/$2.1B評価/Microsoft~$830M買収交渉/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
