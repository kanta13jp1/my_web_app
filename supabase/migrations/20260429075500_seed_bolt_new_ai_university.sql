-- PS#3 S120: AI大学 335→336社化 — Bolt.new (StackBlitz / ブラウザ完結フルスタック AI 開発)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bolt-new', 'overview',
  'Bolt.new — StackBlitz製ブラウザAI開発環境・自然言語でフルスタックアプリ即時生成・デプロイ (9/9)',
  $$## Bolt.new とは

**Bolt.new** は **StackBlitz** が開発する**ブラウザ完結型 AI フルスタック開発環境**。自然言語でプロンプトを入力するだけで、React / Vue / Next.js / Node.js などのフルスタックアプリが即座に生成・実行・デプロイされる。

**インストール不要・ローカル環境不要**が最大の特徴。ブラウザ内で Node.js が動作する **WebContainers** 技術（StackBlitz の独自技術）を活用し、本物の npm パッケージをブラウザ内で実行する。Replit Agent の直接競合。

## Bolt.new の技術基盤

```
Bolt.new のアーキテクチャ:

  WebContainers (StackBlitz独自技術):
    ・ブラウザ内で Node.js を実行 (WebAssembly ベース)
    ・npm install がブラウザ内で完結
    ・ファイルシステム仮想化
    ・ネットワーク仮想化

  AI エンジン:
    ・Claude 3.5 Sonnet (主要モデル)
    ・コード生成 + デバッグ + 説明
    ・エラー自動修正ループ

  対応フレームワーク:
    ・React / Next.js / Remix
    ・Vue / Nuxt.js
    ・Svelte / SvelteKit
    ・Node.js / Express
    ・Astro / Vite
```

## 主要機能

- **自然言語アプリ生成**: 「ToDoアプリを作って」→ 即座にフルスタック実装
- **リアルタイムプレビュー**: 右ペインで即座に動作確認
- **エラー自動修正**: エラー発生 → AI が原因特定 → 自動修正
- **Netlify/Vercel 直接デプロイ**: ボタン1つで本番公開
- **コード編集**: AI 生成後に手動編集も可能
- **履歴管理**: プロジェクトの変更履歴を保持

## 料金体系

| プラン | 月額 | トークン/月 |
|--------|------|------------|
| Free | $0 | 15万トークン |
| Pro | $20 | 1000万トークン |
| Team | $50/人 | 無制限 |

## ユースケース

1. **プロトタイプ作成**: アイデアを数分で動くアプリに
2. **学習**: フレームワークを触りながら学ぶ
3. **デモ**: クライアントへの提案用デモを即作成
4. **ハッカソン**: 短時間でMVPを完成させる

## Bolt.new vs Replit Agent 比較

| 項目 | Bolt.new | Replit Agent |
|------|----------|--------------|
| 技術基盤 | WebContainers | クラウドVM |
| 得意分野 | フロントエンド重視 | フルスタック |
| デプロイ | Netlify/Vercel | Replit hosting |
| オフライン | ブラウザキャッシュ | 不可 |
| 料金 | $20/月 | $20/月 |

## 急成長の背景

2024年後半から急成長し、数ヶ月で数百万ユーザーに。**「バイブコーディング」** （雰囲気でコードを書く）ムーブメントの火付け役の1つ。プログラミング未経験者でもアプリが作れると話題になり、Hacker News / ProductHunt で連日トップを獲得。

## 自分株式会社との関連

Bolt.new のアプローチ（自然言語→即時アプリ）は、自分株式会社が目指す「誰でも AI と協調して価値を生み出せる」体験と直結。Flutter Web との組み合わせで、ラピッドプロトタイピングの教育コンテンツとして活用できる。
$$,
  'https://bolt.new',
  NOW(),
  336
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
