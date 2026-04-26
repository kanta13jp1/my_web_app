-- PS#3 S63: AI大学 221→222社化 — Beautiful.ai 追加
-- Beautiful.ai: AIプレゼンビルダー / Smart Slides自動調整 / デザイン品質担保 / 企業向け

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beautiful-ai',
  'overview',
  'Beautiful.ai — AIプレゼンビルダー (Smart Slides自動調整 / デザイン品質担保 / 企業向け)',
  $$## Beautiful.ai — AIプレゼンビルダー

**カテゴリ**: AI Presentation / Design Automation / Enterprise Productivity
**設立**: 2016年 / 本社: San Francisco, CA / 資金調達: ~$11M
**特徴**: AI が自動でスライドレイアウトを最適化し、「デザインセンスがなくてもプロ品質」を実現
**ユーザー**: セールスチーム / コンサルタント / スタートアップ / マーケター
**評価**: 7/9

### 概要
Beautiful.ai は**「デザインの民主化」**を AI で実現するプレゼンテーションツール。従来の PowerPoint / Google Slides では、コンテンツを追加するたびにレイアウトが崩れてデザイン調整に時間がかかる問題があった。Beautiful.ai の **Smart Slides** はコンテンツの変化を AI が検知し、自動でレイアウトを最適化する。デザイナー不在でもブランドガイドラインに沿ったプロ品質のスライドを高速作成できる。競合の Gamma (テキスト→スライド一括生成) より細かいコントロールが可能で、PowerPoint より遥かに美しい仕上がり。

### 主な特長
- **Smart Slides**: コンテンツ追加・削除時にレイアウトを AI が自動最適化 (崩れない)
- **AI プレゼン生成**: トピックを入力するだけでスライド全体を自動生成
- **Brandfetch 統合**: 企業名を入力するだけでブランドカラー・ロゴを自動取得してスライドに適用
- **デザインテンプレート**: 60+ プロ品質テンプレート / 全てカスタマイズ可
- **チームブランド管理**: 企業ロゴ・カラー・フォントをチーム全体で統一管理
- **Analytics**: スライドの閲覧データ (誰が・いつ・どのスライドを見たか) を追跡
- **Zoom/Teams 統合**: 画面共有なしにプレゼン内でビデオ通話
- **PowerPoint export**: 最終的には .pptx でエクスポートして従来ツールにも対応

### Smart Slides の仕組み
```
従来 (PowerPoint/Slides):
  テキスト追加 → レイアウト崩れ → 手動でサイズ・位置調整 → 時間浪費

Beautiful.ai Smart Slides:
  テキスト追加 → AI が「テキストが増えた」を検知
             → フォントサイズ自動縮小 or カラム分割 or 次スライドへ自動溢れ
             → 常に視覚的に最適なレイアウトを維持
```

### プレゼンテーションタイプ別テンプレート
- **Sales Deck**: 課題提示 / ソリューション / 差別化 / 価格 / CTA
- **Pitch Deck**: 問題 / 市場 / プロダクト / ビジネスモデル / チーム / 資金用途
- **Status Report**: KPI ダッシュボード / 進捗 / 課題 / Next Steps
- **Case Study**: 顧客背景 / 課題 / 施策 / 結果 / 次のアクション
- **Training Material**: 概要 / セクション / クイズ / まとめ

### 競合との差別化
| 機能 | Beautiful.ai | Gamma | Canva | Google Slides |
|------|------------|-------|-------|--------------|
| AI 生成 | ✅ (詳細制御) | ✅ (一括生成) | ✅ | △ |
| 自動レイアウト | ✅ Smart Slides | △ | △ | ❌ |
| デザイン品質 | ★★★★★ | ★★★★ | ★★★★ | ★★★ |
| 企業ブランド管理 | ✅ | ❌ | ✅ | △ |
| Analytics | ✅ | ❌ | ❌ | ❌ |
| PowerPoint export | ✅ | ✅ | ✅ | ✅ |
| 価格 | 中 | 安 | 安〜中 | 無料 |

### 導入コスト
- **Pro**: 月 $12/月 (年払い) / AI 生成 / Smart Slides / 全テンプレート
- **Team**: 月 $40/ユーザー / ブランド管理 / Analytics / 共同編集 / 管理コンソール
- **Enterprise**: カスタム / SSO / 高度な権限 / 優先サポート / カスタムテンプレート$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beautiful-ai',
  'api',
  'Beautiful.ai API — プレゼン自動生成・テンプレート操作・Analytics取得 (Python)',
  $$## Beautiful.ai API

### 概要
Beautiful.ai は Enterprise プランで REST API を提供。プレゼン作成の自動化・CMS 連携・社内ワークフロー統合が可能。

### セットアップ
```bash
# Enterprise プラン → Settings → API で API Key 発行
export BEAUTIFUL_AI_API_KEY="your_api_key_here"
export BEAUTIFUL_AI_BASE="https://api.beautiful.ai/v1"
```

### プレゼン一覧取得
```python
import requests
import os

API_KEY = os.environ["BEAUTIFUL_AI_API_KEY"]
BASE = os.environ["BEAUTIFUL_AI_BASE"]

HEADERS = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

def list_presentations() -> list:
    resp = requests.get(f"{BASE}/presentations", headers=HEADERS)
    resp.raise_for_status()
    return resp.json().get("data", [])

presentations = list_presentations()
for p in presentations:
    print(f"{p['title']} — 更新: {p['updatedAt']} — スライド数: {p['slideCount']}")
```

### テンプレートからプレゼン自動生成
```python
def create_from_template(template_id: str, title: str, slides_data: list) -> dict:
    """テンプレートを基にプレゼンを自動生成"""
    payload = {
        "templateId": template_id,
        "title": title,
        "slides": slides_data,  # 各スライドのコンテンツ
    }
    resp = requests.post(f"{BASE}/presentations", json=payload, headers=HEADERS)
    resp.raise_for_status()
    return resp.json()

# Sales Deck 自動生成
new_pres = create_from_template(
    template_id="sales-deck-v3",
    title=f"自分株式会社 提案資料 {datetime.now().strftime('%Y-%m')}",
    slides_data=[
        {
            "slideType": "title",
            "content": {
                "title": "自分株式会社 × AI ライフマネジメント",
                "subtitle": "Notion・Money Forward・Slack を 1 つに統合",
            },
        },
        {
            "slideType": "problem",
            "content": {
                "headline": "現代人が抱える「ツール疲れ」",
                "bullets": [
                    "平均 8 種類のサービスを毎日使い分ける",
                    "情報がツール間でサイロ化",
                    "月額コストが 3 万円超",
                ],
            },
        },
        {
            "slideType": "solution",
            "content": {
                "headline": "1 つのアプリで全てを管理",
                "bullets": [
                    "AI が 21 競合の全機能を統合",
                    "月額 980 円〜",
                    "セットアップ 3 分",
                ],
            },
        },
    ],
)
print(f"作成: {new_pres['id']} — {new_pres['shareUrl']}")
```

### Analytics データ取得
```python
def get_presentation_analytics(presentation_id: str) -> dict:
    """プレゼンの閲覧データ取得"""
    resp = requests.get(
        f"{BASE}/presentations/{presentation_id}/analytics",
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

analytics = get_presentation_analytics("pres_id_here")
print(f"総閲覧数: {analytics['totalViews']}")
print(f"ユニーク閲覧者: {analytics['uniqueViewers']}")
for slide in analytics["slides"]:
    print(f"  スライド {slide['index']}: 平均{slide['avgTimeSpent']}秒")
```

### GHA 週次 Sales Deck 自動更新
```yaml
# .github/workflows/weekly-sales-deck-update.yml
# 毎週月曜 09:00 JST → KPI を取得 → Beautiful.ai プレゼン自動更新
steps:
  - name: Update weekly sales deck
    env:
      BEAUTIFUL_AI_API_KEY: ${{ secrets.BEAUTIFUL_AI_API_KEY }}
      SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
    run: python scripts/update_sales_deck.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'beautiful-ai',
  'models',
  'Beautiful.ai AI技術 — Smart Slides エンジン + AI生成 + Gamma/Canva/Gamma比較',
  $$## Beautiful.ai AI 技術詳細

### Smart Slides エンジンの技術
```
Smart Slides = Layout Intelligence System

コンポーネントベース設計:
- 各スライドは「コンポーネント」の集合 (テキスト/画像/チャート/アイコン)
- コンポーネントは親コンテナの制約 (サイズ/位置) に従って自動調整
- コンテンツ変化 → 制約ソルバーが最適レイアウトを再計算 (CSS Grid + AI ヒューリスティック)

自動調整ルール (例):
- テキストが 5 行超 → フォントサイズ段階的縮小 (最小 12pt)
- テキストが 10 行超 → 自動的に 2 カラムレイアウトに変換
- 画像追加 → テキストエリアを自動縮小して画像スペース確保
- 箇条書き 7 項目超 → 次スライドへ自動分割提案
```

### AI プレゼン生成フロー
```
1. ユーザーが「トピック + 目的 + 想定聴衆」を入力
2. GPT-4 がスライド構成 (アジェンダ) を自動設計
3. GPT-4 が各スライドのコピーライティングを生成
4. Smart Slides エンジンが各スライドのレイアウトを自動選択
5. Brandfetch API でユーザー企業のブランドを自動適用
6. 完成したプレゼンを Beautiful.ai エディタで編集可能な状態で提供
```

### Brandfetch 統合
```
企業名またはドメインを入力:
「apple.com」→ Apple のロゴ・カラー (#000000 + #f5f5f7) を自動取得してスライドに適用
「notion.so」→ Notion のブランドをスライドに反映

→ 競合分析スライドや顧客向け提案書を作る際に効果的
```

### AI プレゼン生成ツール比較 (2026年)
| ツール | 生成方式 | デザイン品質 | カスタマイズ | 価格 |
|--------|---------|------------|------------|------|
| **Beautiful.ai** | Smart Slides + AI | ★★★★★ | ★★★★ | 中 |
| **Gamma** | テキスト→一括生成 | ★★★★ | ★★★ | 安 |
| **Tome** | AI ストーリーテリング | ★★★★ | ★★★ | 中 |
| **Pitch** | コラボ特化 + AI | ★★★★ | ★★★★ | 中 |
| Canva | AI + テンプレート | ★★★ | ★★★★★ | 安〜中 |
| PowerPoint Copilot | Microsoft 統合 | ★★★ | ★★★★ | 高 (M365) |

### 自分株式会社での活用可能性
- **投資家向け Pitch Deck**: Beautiful.ai で視覚的に優れた資料を高速作成 → IPO準備フェーズに貢献
- **顧客提案書**: Sales Deck テンプレート + データ自動挿入 で営業効率化
- **AI 大学コンテンツ**: 各 AI プロバイダーの比較スライドを Beautiful.ai で作成 → PDF embed
- **週次 KPI レポート**: GHA → Supabase データ取得 → Beautiful.ai API でスライド自動更新
- **採用資料**: 会社説明資料を Beautiful.ai で作成 → ブランド統一 / オンライン共有 URL$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 221→222社化: Beautiful.ai 追加',
  'PS#3 S63。Beautiful.ai (AIプレゼンビルダー / Smart Slides自動レイアウト最適化 / Brandfetch統合 / Analytics / Enterprise API / ~$11M / 7/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
