-- PS#3 S64: AI大学 222→223社化 — Writesonic 追加
-- Writesonic: AIコピーライティング / Chatsonic / Botsonic / Article Writer 6 / 100+言語

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'writesonic',
  'overview',
  'Writesonic — AIコピーライティング (Chatsonic/Article Writer 6/Botsonic/100+言語/SurferSEO統合)',
  $$## Writesonic — AIコピーライティングプラットフォーム

**カテゴリ**: AI Writing / Copywriting / Content Marketing / Chatbot Builder
**設立**: 2021年 / 本社: San Francisco, CA / 資金調達: ~$2.6M (Seed) + YC S21
**特徴**: SEO最適化コンテンツを高速生成するAIライティングツール。GPT-4ベースで100+言語対応
**ユーザー**: マーケター / コンテンツクリエイター / SEO担当者 / スタートアップ / 代理店
**評価**: 8/9

### 概要
Writesonic は **「プロ品質のマーケティングコンテンツを秒速で」** を実現するAIライティングプラットフォーム。単なるテキスト生成を超えて、SEO最適化・マルチチャネル配信・チャットボット構築まで一気通貫で提供。競合の Jasper AI / Copy.ai より価格が安く、SurferSEO連携でSEOライティングに強みがある。2023年に **Chatsonic** (ChatGPT互換 + Google検索連携) と **Botsonic** (ノーコードチャットボットビルダー) を追加し、機能を大幅拡張。

### 主な機能

**コンテンツ生成**
- **Article Writer 6**: URL / キーワード → SEO最適化済み長文記事を自動生成 (3,000〜6,000語)
- **Landing Page Writer**: ヒーロー/特長/CTA/FAQ を一括生成
- **Ad Copy Generator**: Google Ads / Facebook Ads / LinkedIn Ads 向けコピー
- **Email Writer**: コールドメール / ニュースレター / フォローアップメール
- **Product Description**: EC向け商品説明文 (Amazon/Shopify フォーマット対応)
- **Social Media Posts**: Twitter/X / LinkedIn / Instagram キャプション
- **Paraphraser**: 既存テキストを10+トーンでリライト

**AI Chat / 検索統合**
- **Chatsonic**: ChatGPT互換チャット + Google リアルタイム検索 + 画像生成 (Stable Diffusion / DALL-E)
- **Sonic Editor**: Google Docs風AIエディタ / コマンド1行でコンテンツ拡張・要約・翻訳

**チャットボット構築**
- **Botsonic**: ノーコードでカスタムAIチャットボット構築 / 自社ドキュメント学習 / Webサイト埋め込み
- GPT-4 ベース / Zapier連携 / Slack / WhatsApp 対応

### SEO統合
```
SurferSEO + Writesonic 連携フロー:
1. ターゲットキーワード入力
2. SurferSEO が競合上位30記事を分析 → コンテンツスコア基準を算出
3. Writesonic が基準に沿った記事を生成 (見出し構成 / LSIキーワード / 文字数)
4. SurferSEOエディタでリアルタイムスコアを見ながら微調整
5. 公開 → Googleランキング平均Top5以内

→ 従来のSEO記事作成 (8〜10時間) → AI活用で 30〜60分に短縮
```

### 対応言語・トーン
- **100+言語**: 日本語 / 英語 / スペイン語 / フランス語 / ドイツ語 / ポルトガル語 etc.
- **25+ライティングトーン**: Professional / Casual / Witty / Empathetic / Inspirational etc.

### 競合との差別化
| 機能 | Writesonic | Jasper AI | Copy.ai | ChatGPT |
|------|-----------|-----------|---------|---------|
| SEO最適化 | ✅ (SurferSEO) | ✅ (Surfer) | △ | ❌ |
| リアルタイム検索 | ✅ Chatsonic | ❌ | ❌ | ✅ (有料) |
| チャットボット | ✅ Botsonic | ❌ | ❌ | ❌ |
| 価格 | **安** | 高 | 中 | 中 |
| 長文記事 | ✅ 6,000語+ | ✅ | △ | △ |
| 日本語品質 | ★★★★ | ★★★★ | ★★★ | ★★★★★ |

### 導入コスト
- **Free**: 月10,000語 / Chatsonic 25回 / Botsonic 100メッセージ
- **Individual**: 月$16 / 無制限ワード / GPT-4 / Chatsonic / Botsonic
- **Standard**: 月$79 / チーム5名 / ブランドボイス / API
- **Enterprise**: カスタム / SSO / 優先サポート / カスタムモデル$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'writesonic',
  'api',
  'Writesonic API — コンテンツ自動生成・Chatsonic・Botsonic埋め込み (Python)',
  $$## Writesonic API

### 概要
Writesonic REST API でコンテンツ生成をプログラムから自動化。StandardプランあるいはEnterpriseプランで利用可能。

### セットアップ
```bash
# Writesonic → Settings → API Key でキー取得
export WRITESONIC_API_KEY="your_api_key_here"
export WRITESONIC_BASE="https://api.writesonic.com/v2"
```

### 記事自動生成
```python
import requests
import os

API_KEY = os.environ["WRITESONIC_API_KEY"]
BASE = os.environ["WRITESONIC_BASE"]

HEADERS = {
    "accept": "application/json",
    "content-type": "application/json",
    "X-API-KEY": API_KEY,
}

def generate_article(topic: str, primary_keyword: str, language: str = "ja") -> dict:
    """Article Writer 6 でSEO最適化記事を生成"""
    payload = {
        "enable_html": False,
        "save_draft": True,
        "article_title": topic,
        "article_intro": f"{primary_keyword}について詳しく解説します。",
        "search_queries": [primary_keyword],
        "brand_voice_id": None,
        "outline": None,
    }
    resp = requests.post(
        f"{BASE}/business/content/article-writer-6/",
        params={"engine": "premium", "language": language, "n": 1},
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# 自分株式会社 ブログ記事自動生成
article = generate_article(
    topic="AI統合ライフマネジメントの未来 2026年版",
    primary_keyword="AI ライフマネジメント",
)
print(article[0]["article"])
```

### ランディングページ自動生成
```python
def generate_landing_page(product_name: str, description: str) -> dict:
    payload = {
        "product_name": product_name,
        "product_description": description,
        "tone_of_voice": "Professional",
    }
    resp = requests.post(
        f"{BASE}/business/content/landing-pages/",
        params={"engine": "premium", "language": "ja", "n": 1},
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

lp = generate_landing_page(
    product_name="自分株式会社",
    description="Notion・MoneyForward・Slack など21競合の機能を1つに統合するAIライフマネジメントアプリ",
)
print(lp[0]["landing_page"])
```

### Chatsonic API (会話型 AI + 検索)
```python
def chatsonic_chat(message: str, enable_google_results: bool = True) -> str:
    """Chatsonic API でリアルタイム検索付き会話"""
    payload = {
        "enable_google_results": enable_google_results,
        "enable_memory": False,
        "input_text": message,
        "history_data": [],
    }
    resp = requests.post(
        f"{BASE}/business/content/chatsonic",
        params={"engine": "premium", "language": "ja"},
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json().get("message", "")

# 最新AIニュースを取得してAI大学コンテンツに活用
latest_news = chatsonic_chat("2026年のAI業界の最新動向を3つ教えて")
print(latest_news)
```

### Botsonic 埋め込み (Flutter Web)
```dart
// Botsonic チャットウィジェットをFlutter WebViewに埋め込み
// pubspec.yaml: webview_flutter: ^4.0.0

import 'package:webview_flutter/webview_flutter.dart';

class BotsonicWidget extends StatelessWidget {
  final String botId;
  const BotsonicWidget({required this.botId, super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString('''
        <html><body>
        <script>
          (function(d, t) {
            var g = d.createElement(t), s = d.getElementsByTagName(t)[0];
            g.src = "https://widget.writesonic.com/CDN/lib/botsonic.js";
            g.onload = function() { Botsonic.init("$botId"); };
            s.parentNode.insertBefore(g, s);
          })(document, "script");
        </script>
        </body></html>
      ''');
    return WebViewWidget(controller: controller);
  }
}
```

### GHA × Writesonic 週次コンテンツ生成
```yaml
# .github/workflows/weekly-content-generation.yml
# 毎週月曜 08:00 JST → Writesonic でブログ記事を自動生成 → PR作成
steps:
  - name: Generate weekly blog post
    env:
      WRITESONIC_API_KEY: ${{ secrets.WRITESONIC_API_KEY }}
    run: python scripts/generate_weekly_blog.py
  - name: Create PR with generated content
    uses: peter-evans/create-pull-request@v5
    with:
      title: "blog: AI週次記事 自動生成"
      branch: auto/weekly-blog-${{ github.run_number }}
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'writesonic',
  'models',
  'Writesonic AI技術詳細 — GPT-4/Claude統合 + Article Writer 6エンジン + SEO最適化アーキテクチャ',
  $$## Writesonic AI 技術詳細

### Article Writer 6 のアーキテクチャ
```
入力: トピック + キーワード + ターゲット国
       ↓
Research Phase (Chatsonic):
  - Google リアルタイム検索で上位30記事を収集
  - 競合記事のH1/H2/H3構造を分析
  - 平均文字数・LSIキーワード密度を算出
       ↓
Outline Generation (GPT-4):
  - 競合より網羅的なアウトライン生成
  - SurferSEO NLP recommendationsを取り込む
       ↓
Content Generation (GPT-4 Turbo):
  - セクションごとに高品質テキスト生成
  - ファクトチェック: 主張に引用元を自動付与
  - 内部リンク提案: 既存記事との関連度スコアリング
       ↓
SEO Optimization:
  - タイトルタグ / メタディスクリプション最適化
  - 見出しにキーワード自然挿入 (詰め込み回避)
  - 画像ALT提案 / スキーママークアップ追加
       ↓
出力: SEO最適化済み記事 (HTML/Markdown)
```

### モデル選択戦略
```
Writesonic が内部で使用するモデル:

テンプレート系 (Ad/Social/短文):
→ GPT-3.5 Turbo: 高速・低コスト・十分な品質

長文コンテンツ (Article Writer 6):
→ GPT-4 Turbo: 論理的一貫性・ファクト精度

リアルタイム検索連携 (Chatsonic):
→ GPT-4 + Bing/Google Search API: 最新情報取得

ユーザー設定 (Enterpriseプラン):
→ Claude 3.5 Sonnet / GPT-4o / カスタムモデル選択可
```

### Writesonic vs 競合AIライティングツール (2026年)
| 評価項目 | Writesonic | Jasper AI | Copy.ai | Rytr |
|---------|-----------|-----------|---------|------|
| 長文記事品質 | ★★★★ | ★★★★★ | ★★★★ | ★★★ |
| SEO連携 | ★★★★★ | ★★★★★ | ★★★ | ★★ |
| チャットボット | ★★★★★ | ❌ | ★★★ | ❌ |
| 価格/コスパ | ★★★★★ | ★★★ | ★★★★ | ★★★★ |
| 日本語品質 | ★★★★ | ★★★★ | ★★★ | ★★★ |
| API | ✅ | ✅ | ✅ | ✅ |

### 自分株式会社での活用可能性
- **AI大学 コンテンツ自動化**: Writesonic API → 各プロバイダーの「活用ガイド」記事を週次自動生成
- **ブログ SEO**: Article Writer 6 + SurferSEO で競合21社比較記事を高速量産
- **LP コピー**: Landing Page Writer でユーザーセグメント別LPを自動生成 (A/Bテスト用)
- **Botsonic**: AI大学ページにカスタムチャットボットを埋め込み → 「○○について教えて」に自動回答
- **多言語展開**: 100+言語対応で海外向けコンテンツを同時生成 (EN/ZH/KO/ES)
- **メール自動化**: Email Writer → 新規ユーザーへのオンボーディングメール系列自動生成$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 222→223社化: Writesonic 追加',
  'PS#3 S64。Writesonic (AIコピーライティング/Article Writer 6/Chatsonic Google検索連携/Botsonic ノーコードチャットボット/SurferSEO統合/100+言語/GPT-4/YC S21/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
