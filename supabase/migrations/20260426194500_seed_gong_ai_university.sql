-- PS#3 S61: AI大学 217→218社化 — Gong.ai 追加
-- Gong.ai: AI営業インテリジェンス / 通話録音・分析・コーチング / $7.25B評価額 / エンタープライズ特化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gong',
  'overview',
  'Gong — AI営業インテリジェンスプラットフォーム (通話録音・分析・コーチング / $7.25B評価額)',
  $$## Gong — AI営業インテリジェンスプラットフォーム

**カテゴリ**: Revenue Intelligence / Sales AI / Conversation Intelligence
**設立**: 2015年 / 本社: San Francisco, CA / 評価額: **$7.25B (2021年)** / 資金調達: $584M
**特徴**: 営業通話・メール・デモを AI で分析し、勝率向上・コーチング・予測精度改善を実現
**ユーザー**: エンタープライズセールスチーム / SDR / AE / セールスマネージャー / RevOps
**評価**: 9/9

### 概要
Gong は**Revenue Intelligence (収益インテリジェンス) カテゴリを創造した企業**。営業担当の通話・Zoom/Teams デモ・メール・Slack メッセージを全て録音・分析し、AI がパターンを学習して「なぜ案件が勝てた/負けたか」「どのセールストークが効果的か」「危険な案件はどれか」を可視化する。Salesforce / HubSpot などの CRM データと統合して予測精度を大幅に改善。エンタープライズ向けに特化しており、顧客は LinkedIn / Spotify / HubSpot / DocuSign など Fortune 500 クラス。

### 主な特長
- **会話インテリジェンス**: 営業通話を録音・文字起こし・分析 / トーク比率・モノローグ・質問数を可視化
- **Deal Intelligence**: 案件ごとのリスクスコア・停滞検出・次のアクション提案
- **Forecast Intelligence**: AI 予測 vs 担当者予測の乖離を検出 / 四半期末の予測精度向上
- **Coaching Intelligence**: Top performer の通話パターンをチーム全体にスケール
- **Engagement Intelligence**: メール開封・返信・リンククリックを追跡してバイヤー意図を分析
- **Pipeline Intelligence**: 案件停滞・競合言及・チャンピオン離職などのアラート
- **Gong Engage**: AI が次のアクション・メールテンプレートを自動提案
- **Gong Forecast**: CRM データ + 会話データを統合した AI 予測モデル

### 競合他社との差別化
| 機能 | Gong | Clari | Chorus.ai (ZoomInfo) | Salesloft |
|------|------|-------|---------------------|-----------|
| 会話インテリジェンス | ✅ 業界最高 | △ | ✅ | △ |
| 予測精度 | ✅ AI+会話統合 | ✅ | ❌ | ❌ |
| コーチング | ✅ | △ | ✅ | ✅ |
| メール自動化 | ✅ Engage | ❌ | ❌ | ✅ |
| SMB 対応 | ❌ Enterprise only | △ | △ | ✅ |

Gong の強みは**会話データ × CRM データ × AI の完全統合 + エンタープライズ信頼性**。

### 実績・ROI 指標
- 平均勝率向上: **+21%** (Gong 顧客平均)
- 予測精度: 従来 CRM 比 **+46%**
- 新人営業の立ち上がり期間: **40% 短縮**
- 使用企業: **3,000+ 社** (LinkedIn / Spotify / DocuSign / Shopify 等)

### 導入コスト
- **Enterprise プランのみ** (SMB 向け提供なし)
- 年間契約 / ユーザーあたり $1,200〜$1,600/年 (一般的な見積もり)
- 最小契約規模: 約 50 席以上が推奨
- 詳細は要問い合わせ (公式価格非公開)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gong',
  'api',
  'Gong API — 営業通話データ取得・分析・CRM統合 REST API (Python)',
  $$## Gong API

### セットアップ
```bash
# Gong Admin → Company Settings → API → Access Key 作成
# Base URL: https://us-55023.api.gong.io (リージョンにより異なる)
pip install requests
export GONG_ACCESS_KEY="your_access_key"
export GONG_ACCESS_KEY_SECRET="your_secret"
```

### 認証 (Basic Auth)
```python
import requests
import os
import base64

ACCESS_KEY = os.environ["GONG_ACCESS_KEY"]
SECRET = os.environ["GONG_ACCESS_KEY_SECRET"]
BASE_URL = "https://us-55023.api.gong.io"  # リージョンに応じて変更

def get_headers() -> dict:
    credentials = base64.b64encode(f"{ACCESS_KEY}:{SECRET}".encode()).decode()
    return {
        "Authorization": f"Basic {credentials}",
        "Content-Type": "application/json",
    }
```

### 通話一覧取得
```python
def get_calls(from_date: str, to_date: str) -> list:
    """指定期間の通話一覧取得"""
    resp = requests.get(
        f"{BASE_URL}/v2/calls",
        headers=get_headers(),
        params={
            "fromDateTime": from_date,  # ISO 8601: "2026-04-01T00:00:00Z"
            "toDateTime": to_date,
        },
    )
    resp.raise_for_status()
    return resp.json().get("calls", [])

# 今週の通話
from datetime import datetime, timedelta
today = datetime.utcnow()
week_ago = today - timedelta(days=7)
calls = get_calls(week_ago.isoformat() + "Z", today.isoformat() + "Z")
for c in calls:
    print(f"{c['started']} | {c['title']} | {c['duration']}s")
```

### 通話詳細 + トランスクリプト取得
```python
def get_call_transcript(call_id: str) -> dict:
    resp = requests.post(
        f"{BASE_URL}/v2/calls/transcript",
        headers=get_headers(),
        json={"filter": {"callIds": [call_id]}},
    )
    resp.raise_for_status()
    transcripts = resp.json().get("callTranscripts", [])
    return transcripts[0] if transcripts else {}

def get_call_stats(call_id: str) -> dict:
    """通話の話者統計・トーク比率取得"""
    resp = requests.post(
        f"{BASE_URL}/v2/calls/extensive",
        headers=get_headers(),
        json={
            "filter": {"callIds": [call_id]},
            "contentSelector": {
                "exposedFields": {
                    "parties": True,
                    "trackers": True,
                    "interaction": True,  # トーク比率・質問数
                }
            },
        },
    )
    resp.raise_for_status()
    return resp.json().get("calls", [{}])[0]

# 通話分析
stats = get_call_stats("call_id_here")
interaction = stats.get("interaction", {})
print(f"担当者トーク比率: {interaction.get('speakers', [{}])[0].get('talkRatio', 0)*100:.1f}%")
```

### 案件リスク分析
```python
def get_deals_at_risk() -> list:
    """リスクフラグが立っている案件一覧"""
    resp = requests.post(
        f"{BASE_URL}/v2/deals",
        headers=get_headers(),
        json={
            "filter": {"dealStageCategory": ["open"]},
            "contentSelector": {
                "exposedFields": {
                    "crm": True,
                    "gong": {"warnedAbout": True},  # リスクアラート
                }
            },
        },
    )
    resp.raise_for_status()
    deals = resp.json().get("deals", [])
    # リスクありの案件のみ抽出
    at_risk = [d for d in deals if d.get("gong", {}).get("warnedAbout")]
    return at_risk

risky_deals = get_deals_at_risk()
for deal in risky_deals:
    print(f"{deal['crm']['title']} — リスク: {deal['gong']['warnedAbout']}")
```

### GHA 週次セールスレポート
```yaml
# .github/workflows/weekly-sales-intelligence.yml
# 毎週月曜 09:00 JST → Gong API → docs/sales-reports/ に保存
steps:
  - name: Generate weekly sales intelligence report
    env:
      GONG_ACCESS_KEY: ${{ secrets.GONG_ACCESS_KEY }}
      GONG_ACCESS_KEY_SECRET: ${{ secrets.GONG_ACCESS_KEY_SECRET }}
    run: python scripts/weekly_sales_report.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gong',
  'models',
  'Gong AI モデル — Revenue AI Engine + Deal Scoring + Forecast Model + Coaching AI',
  $$## Gong AI 技術詳細

### Revenue AI Engine の構成要素

| AI コンポーネント | 役割 | 学習データ |
|----------------|------|---------|
| **Conversation AI** | 通話文字起こし・感情分析・話者分離 | 数十億分の B2B 営業通話 |
| **Deal Scoring AI** | 案件勝率スコア (0-100) / リスク検出 | 数百万件の Deal 勝敗データ |
| **Forecast AI** | 四半期着地予測 / Bottom-up 集計 | CRM + 通話データ統合モデル |
| **Coaching AI** | Top Performer パターン抽出 / スコアカード | 社内上位 20% の通話分析 |
| **Engagement AI** | バイヤー意図スコア / マルチチャネル追跡 | メール/会議/ビデオ行動データ |

### Deal Scoring のシグナル
Gong が「案件リスク」を判断する際に使う主要シグナル:
- **会話停滞**: 14日以上 Next Step の言及なし
- **チャンピオン不在**: 意思決定者との接点がない
- **競合言及増加**: 競合他社名の言及が前回より増加
- **感情変化**: バイヤーのセンチメントがネガティブ化
- **エンゲージメント低下**: メール返信率・会議出席率の低下
- **タイムライン変更**: 「来四半期」「予算確保後」などの遅延ワード検出

### Coaching Intelligence の仕組み
```
Step 1: Top Performer 特定
  → 勝率 / ASP / Ramp Time が上位 20% の担当者を自動選出

Step 2: 成功パターン学習
  → 質問頻度 / トーク比率 / 発言タイミング / 使用フレーズを分析

Step 3: スコアカード生成
  → 全担当者の通話を自動採点 (トピックカバレッジ / 競合対応 / ネクストステップ設定)

Step 4: マネージャーへのアラート
  → 「田中AEの通話でネクストステップが設定されていない件が増加」
```

### Gong の生成 AI 活用 (2025〜2026)
- **Gong Engage AI**: メールドラフト自動生成 / バイヤーの LinkedIn / メールを分析してパーソナライズ
- **Deal Summary**: 案件の全コンテキストを 1 クリックで要約
- **Call Brief**: 通話前に担当者向けの「この顧客について知るべきこと」を自動生成
- **Ask Gong**: 「今月クローズリスクが高い案件は?」など自然言語でデータを問い合わせ

### 自分株式会社での活用可能性
- **スタートアップ期**: Enterprise 専用のため直接採用は難しい → 競合比較教材として活用
- **AI 大学コンテンツ**: 「スタートアップが知るべき B2B セールス AI ツール」記事の核心事例
- **X 投稿ネタ**: Gong の ROI データ (勝率+21% / 予測精度+46%) は引用価値が高い
- **競合分析**: Fireflies.ai (中小向け) vs Gong (エンタープライズ) の棲み分け解説
- **プロダクト設計**: 将来の「自分株式会社 セールス機能」に Revenue Intelligence 要素を検討$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 217→218社化: Gong 追加',
  'PS#3 S61。Gong (AI営業インテリジェンス / Revenue Intelligence カテゴリ創造 / $7.25B評価 / Deal+Forecast+Coaching AI / Gong API / 勝率+21% / 9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
