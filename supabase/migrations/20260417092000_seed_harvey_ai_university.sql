-- Windowsアプリ版#68: Harvey AI 大学コンテンツ seed
-- 法律・プロフェッショナルサービス特化AI — $11B評価・最大法律AIプラットフォーム

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

('harvey', 'overview',
'Harvey AI: 法律・プロフェッショナルサービス向け最大AIプラットフォーム',
$$# Harvey AI

Harveyは**法律・会計・コンサルティング専門のAIプラットフォーム**。
A&O Shearman・PwCなど世界トップの法律事務所・監査法人が採用する業界特化型AIのパイオニア。
2023年創業ながら2026年に評価額$11Bに達した急成長スタートアップ。

## 設立背景

- **創業**: 2023年、Winston Weinberg (ex-OpenAI) × Gabriel Pereyra (ex-Google DeepMind/Meta AI)
- **資金調達**: $300M+ (OpenAI Fund / Sequoia Capital / GIC 等)
- **評価額**: $11B (2026年3月 — $200M調達時)
- **哲学**: 「汎用AIではなく、法律プロフェッショナルに特化したAIで生産性を10×にする」

## 主要ユースケース

| 領域 | 具体的な用途 |
|------|-------------|
| **契約レビュー** | M&A契約・NDA・雇用契約の自動分析・リスク抽出 |
| **リーガルリサーチ** | 判例検索・法令調査・規制解釈 |
| **デューデリジェンス** | M&A・IPO向け大量文書の自動精査 |
| **コンプライアンス** | 規制変更への適応・コンプライアンスチェック |
| **ドキュメント作成** | 法的文書の下書き・修正提案 |

## 採用企業

- **法律事務所**: A&O Shearman, Weil, LathamなどAm Law 100の50%超
- **プロフェッショナルサービス**: PwC (世界展開), Centerview Partners
- **企業法務**: 大手Fortune 500の法務部門

## モデル戦略

HarveyはOpenAI/Anthropicの基盤モデルを**法律データで継続的ファインチューニング**。
「法律ドメイン専門モデル」として、汎用AIより高精度な法的推論を実現。
$$,
'https://www.harvey.ai/',
'2026-04-17', 1),

('harvey', 'models',
'Harvey のモデル体系とアーキテクチャ',
$$# Harvey モデル体系

## アーキテクチャの特徴

Harveyは「汎用LLM × 法律ファインチューニング × RAG」の3層構造:

```
Layer 1: 基盤モデル (OpenAI GPT-4.1 / Anthropic Claude)
Layer 2: 法律データ継続ファインチューニング
         (判例・法令・契約書・論文 数億件)
Layer 3: RAGシステム
         (顧客の案件資料・内規・過去判断をリアルタイム参照)
```

## 主要モデル・機能

| 機能 | 説明 | 対象ユーザー |
|------|------|-------------|
| **Harvey Core** | 法律文書の分析・要約・質問応答 | 全プロフェッショナル |
| **Harvey Research** | 判例・法令の深堀り調査 | 弁護士・パラリーガル |
| **Harvey Drafting** | 契約書・法的文書の生成・修正 | 企業法務・弁護士 |
| **Harvey Due Diligence** | M&A向け大量文書精査 | M&Aアドバイザー |
| **Harvey Compliance** | 規制対応・コンプライアンスチェック | コンプライアンス担当 |

## 精度の根拠

- 法律ハルシネーション率が汎用モデルより大幅低下
- 判例引用の正確性: 引用した判例が実在し内容が正確
- 契約リスク抽出: 法律専門家のレビューと90%以上の一致率

## 他の法律AIとの比較

| ツール | 種別 | 強み |
|--------|------|------|
| **Harvey** | フルプラットフォーム | 法律特化・エンタープライズ統合 |
| Clio Duo | 中小事務所向け | 案件管理統合 |
| Thomson Reuters CoCounsel | リーガルリサーチ | Westlaw統合 |
| Lexis+ AI | リーガルリサーチ | LexisNexis統合 |
$$,
'https://www.harvey.ai/platform',
'2026-04-17', 2),

('harvey', 'api',
'Harvey Developer API: 法律AIを自アプリに統合',
$$# Harvey Developer API

## 概要

Harvey APIにより、法律事務所・SaaSが**Harveyの法律AI能力を自社アプリに埋め込む**ことが可能。
REST APIで契約分析・法的QA・文書生成をプログラムから呼び出せる。

## API エンドポイント

```python
import httpx

# Harvey Assistant API
client = httpx.Client(
    base_url="https://api.harvey.ai/v1",
    headers={
        "Authorization": f"Bearer {HARVEY_API_KEY}",
        "Content-Type": "application/json"
    }
)

# 契約書分析リクエスト
response = client.post("/analyze", json={
    "document": "契約書テキスト or base64エンコードPDF",
    "task": "risk_extraction",  # or: "summary", "qa", "drafting"
    "jurisdiction": "JP",  # 日本法
    "output_format": "structured"
})

risks = response.json()["risks"]
```

## 利用シーン (自分株式会社 × Harvey 統合案)

```dart
// Supabase Edge Functionからの呼び出し例
// supabase/functions/legal-assistant/index.ts

const response = await fetch('https://api.harvey.ai/v1/analyze', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${Deno.env.get('HARVEY_API_KEY')}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    document: contractText,
    task: 'risk_extraction',
    jurisdiction: 'JP',
  }),
});
```

## プラン・コスト

| プラン | 対象 | 特徴 |
|--------|------|------|
| **Enterprise** | 大手法律事務所・PwC等 | カスタム価格・専任サポート |
| **Professional** | 中規模事務所 | 席単位の月額課金 |
| **API** | SaaS開発者 | リクエスト単位課金 (要問い合わせ) |

## Developer向けドキュメント

- API Reference: `developers.harvey.ai`
- Authentication: OAuth 2.0 / API Key
- Rate Limits: Enterprise契約により異なる
$$,
'https://developers.harvey.ai/guides/introduction',
'2026-04-17', 3),

('harvey', 'news',
'Harvey AI 最新ニュース (2026-04-17)',
$$# Harvey AI 最新動向 (2026-04-17)

## 主要アップデート

### $200M調達・評価額$11Bに到達 (2026年3月)
GICとSequoia Capital共同リードで$200Mを調達。法律AIとして史上最大の評価額。
「AIが法律業界を再定義する」との確信をもとに積極投資を継続。

### PwCグローバル展開
PwC (世界4大会計事務所の一角) がHarveyをグローバル展開。
PwCの30万人以上のプロフェッショナルがHarveyを日常業務に活用。

### Am Law 100の50%超が採用
アメリカ最大手法律事務所100社のうち50社以上がHarveyを導入。
法律業界でのAI採用速度が他業界を圧倒。

### Harvey Research v3リリース
判例検索精度の大幅向上。不正確な引用（ハルシネーション）をほぼゼロに。
法律専門家の「AIは間違いが怖い」という最大の不安を解消。

## 日本市場への示唆

- 日本の法律事務所・企業法務でのAI活用は欧米比で2-3年遅れ
- 日本語法令・日本法判例に対応したローカライズが課題
- 「法務管理」機能 (`lib/pages/`) との連携でユーザー価値向上の余地あり

## このプロジェクトへの応用

- **legal-assistant EF**: Harvey APIを `tools-hub` の新actionとして追加可能
- **LP掲載**: 「法務管理」コア機能のバックエンドとしてHarveyをアピール材料に
- **AI大学コンテンツ**: 法律AIという新ジャンルを開拓 (競合は未対応が多い)
$$,
'https://www.harvey.ai/blog',
'2026-04-17', 4)

ON CONFLICT (provider, category) DO UPDATE
  SET content = EXCLUDED.content,
      source_url = EXCLUDED.source_url,
      published_at = EXCLUDED.published_at,
      updated_at = now();
