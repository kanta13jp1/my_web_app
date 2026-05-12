-- PS#3 S121: AI大学 337→338社化 — v0.dev (Vercel / UI生成AI / React+Tailwind / シャドウイング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'v0-dev', 'overview',
  'v0.dev — Vercel製AI UI生成・プロンプトでReact+Tailwindコンポーネント即時生成・本番品質 (9/9)',
  $$## v0.dev とは

**v0.dev** は **Vercel** が開発した **AI UI コンポーネント生成サービス**。自然言語のプロンプトを入力するだけで、**React + Tailwind CSS** を使った本番品質の UI コンポーネントが即座に生成される。

「**デザインのプロトタイプ作成**」から「**実際の本番コンポーネント**」まで一気通貫で生成できる点が特徴。Next.js / Vercel エコシステムとの深い統合が強み。

## v0.dev のコアコンセプト

```
v0.dev のワークフロー:

  1. プロンプト入力:
     「ダッシュボードのメトリクスカード」
     「認証フォーム (ソーシャルログイン付き)」
     「商品一覧グリッド (フィルター付き)」

  2. 生成結果:
     ・React コンポーネント (TypeScript)
     ・Tailwind CSS スタイリング
     ・shadcn/ui コンポーネント活用
     ・レスポンシブ対応

  3. 反復改善:
     ・チャットでフォローアップ指示
     ・「ボタンを青にして」「モバイル対応を強化」
     ・バリエーション生成

  4. エクスポート:
     ・コードをコピー → プロジェクトに貼り付け
     ・npm install で依存関係追加
     ・そのまま本番で動作
```

## 技術的な特徴

- **shadcn/ui ベース**: 高品質な Radix UI コンポーネントを活用
- **Tailwind CSS**: ユーティリティファーストで一貫したスタイリング
- **TypeScript**: 型安全なコンポーネント生成
- **アクセシビリティ**: ARIA 属性・キーボード操作を標準搭載
- **ダークモード**: 自動対応

## 料金体系

| プラン | 月額 | 生成回数 |
|--------|------|----------|
| Free | $0 | 月200クレジット |
| Premium | $20 | 月5000クレジット |
| Team | $30/人 | チーム共有 |

## ユースケース

1. **デザイナー → エンジニアへのハンドオフ**: Figma のかわりに v0 でコードを渡す
2. **MVP 開発**: LP・管理画面・フォームを高速プロトタイプ
3. **教育**: コンポーネント設計パターンの学習
4. **インスピレーション**: 既存 UI のリデザイン案を複数生成して選ぶ

## エコシステムとの統合

- **Next.js App Router**: v0 生成コードは Next.js に最適化
- **Vercel Deploy**: 生成→デプロイまでVercel上で完結
- **shadcn/ui CLI**: `npx shadcn@latest add` で依存コンポーネント自動インストール

## v0.dev vs 競合比較

| 項目 | v0.dev | Bolt.new | Figma Make |
|------|--------|----------|-----------|
| 出力 | React コンポーネント | フルスタックアプリ | Figma デザイン |
| 特化 | UI コンポーネント | アプリ全体 | デザイン |
| フレームワーク | React/Next.js | マルチフレームワーク | — |
| 料金 | $20/月 | $20/月 | Figma プランに含む |

## 急成長の背景

2023年末の公開以来、フロントエンド開発者の間で爆発的に普及。「**shadcn/ui + v0 の組み合わせ**」が 2024〜2025 年のフロントエンド開発スタンダードになりつつある。X (旧Twitter) で毎日 v0 の生成物が共有され、コミュニティが活発。

## 自分株式会社との関連

v0.dev のアプローチ (プロンプト → 本番品質コンポーネント) は、Flutter Web 開発においても参考になる。特に UI コンポーネントのプロトタイプ検討時に活用でき、「デザインシステム + AI 生成」の組み合わせで開発速度を大幅向上できる。
$$,
  'https://v0.dev',
  NOW(),
  338
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
