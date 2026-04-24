-- Windowsアプリ進行: Harvey AI大学に「法律AI」ジャンルの導入教材を追加

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order
)
VALUES (
  'harvey',
  'tutorial',
  '法律AIの始め方: 汎用LLMと何が違うか',
  $$# 法律AIの始め方

## まず押さえるポイント

法律AIは「文章をうまく書くAI」ではなく、**契約レビュー・リーガルリサーチ・Due Diligence という実務フローに合わせて設計されたAI** です。

Harvey を入口に学ぶときは、次の順で見ると理解しやすくなります。

1. **契約レビュー**  
   リスク条項の抽出、修正文案の候補、交渉ポイントの整理
2. **リーガルリサーチ**  
   争点ごとの論点整理、判例・法令の探索、要約
3. **Due Diligence**  
   大量文書の横断確認、抜け漏れ検知、確認事項の洗い出し

## 汎用LLMとの違い

| 観点 | 汎用LLM | 法律AI |
|---|---|---|
| 入口 | 会話・要約・一般生成 | 契約・案件・論点・法域 |
| 期待される出力 | 読みやすさ・発想 | リスク整理・論点抽出・確認観点 |
| 評価軸 | 速さ・自然さ | 実務の再利用性・レビュー効率 |

## このアプリでの学び方

- AI大学トップの **法律AI** ジャンルから Harvey を開く
- overview / models / api / news に加えて、この tutorial を読む
- 法務・コンプライアンス画面の Harvey タブで、実際のレビュー導線も確認する

## ひとこと

競合がまだ薄いので、**「法律AIを一つの独立ジャンルとして学ぶ」** こと自体が差別化になります。まずは Harvey で、法律実務に最適化されたAIの見方をつかむのが近道です。
$$,
  'https://www.harvey.ai/platform',
  '2026-04-24',
  5
)
ON CONFLICT (provider, category) DO UPDATE
SET title = EXCLUDED.title,
    content = EXCLUDED.content,
    source_url = EXCLUDED.source_url,
    published_at = EXCLUDED.published_at,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();
