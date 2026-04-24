-- Session PS#4-S40: AI大学 184→185社化 — Bolt.new (StackBlitz)
-- Eric Simons (CEO) の StackBlitz が 2024-10 にリリース。
-- WebContainers (ブラウザ内 Node.js) 技術でフルスタック開発をオンライン完結。
-- 初月 450 万プロジェクト作成 / 150 万+ ユーザー。
-- Claude Sonnet 3.5 / GPT-4.1 / Gemini 2.0 を選択可能。
-- Step 0: 8.5/9 (WebContainers独自技術 / 初月450万PJ / Lovable/v0と並ぶvibe-coding三強)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'bolt_new',
  'overview',
  'Bolt.new — ブラウザ内 Node.js で動くフルスタック開発環境',
  $md$
# Bolt.new — WebContainers でブラウザが開発環境になる

**Eric Simons** (CEO) と **Albert Pai** (CTO) が創業した **StackBlitz** の主力プロダクト。
2024 年 10 月のリリースから 1 ヶ月で **450 万プロジェクト** が作成された。

最大の技術的差別化は **WebContainers**: ブラウザ内で本物の Node.js を実行する特許技術。
npm パッケージのインストール・ファイルシステム操作・プロセス実行がすべてブラウザで完結する。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **会社** | StackBlitz Inc. |
| **CEO** | Eric Simons |
| **創業** | 2012 年 |
| **本社** | San Francisco, CA |
| **調達** | $86M 累計 (2022 Series A $25M 含む) |
| **Bolt.new リリース** | 2024-10 |
| **ユーザー数** | 1.5M+ (2024-11 時点) |

## 主要機能

### 1. WebContainers — ブラウザ内 Node.js

StackBlitz の独自特許技術。**ローカルにインストール不要** で:
- `npm install` が動く
- Express / Vite / Next.js / Astro などが動く
- ファイルシステムの読み書き
- ターミナル操作

これにより Bolt.new は他の AI コーディングツールが苦手とする
**バックエンドを含む本格的な Web アプリ** を生成できる。

### 2. AI によるフルスタック生成

自然言語 → 動くアプリへの変換:

```
「React + Express のタスク管理アプリを作って。
  データは SQLite に保存。
  REST API で CRUD 操作。
  Tailwind でデザイン。」

→ Bolt.new が完全に動くアプリを即座に生成
→ ブラウザ上でそのまま動作確認可能
```

### 3. 差分適用 (Apply Diffs)

生成したコードへの変更を **差分として適用**。
全体再生成ではなく変更箇所のみを更新するため高速。

### 4. 外部サービス統合

- **Netlify** / **Vercel** への 1 クリックデプロイ
- **GitHub** への自動 push
- **Supabase** / **Firebase** との統合

## vibe-coding 三強の比較

| ツール | 技術的基盤 | 強み | 弱み |
| :--- | :--- | :--- | :--- |
| **Bolt.new** | WebContainers (ブラウザ内 Node.js) | バックエンド含む完全フルスタック | 複雑な DB 設計は苦手 |
| **Lovable** | Claude + Supabase 統合 | Supabase 統合の深さ / 本番品質 | Node.js/npm の自由度が低い |
| **v0 (Vercel)** | Next.js / shadcn/ui | UI コンポーネント品質 | バックエンドが弱い |

## WebContainers 技術の革新性

```
従来のオンライン IDE: クラウドサーバーにコードを送って実行
                         ↓
                   レイテンシ・コスト・スケール問題

WebContainers:   ブラウザ内で直接実行 (WASM + ServiceWorker)
                         ↓
                   レイテンシゼロ / オフライン可能 / サーバー不要
```

Node.js を WebAssembly でコンパイルして ServiceWorker 経由で実行する革新的アーキテクチャ。
$md$,
  'https://bolt.new/',
  '2026-04-24',
  1
),

(
  'bolt_new',
  'models',
  'Bolt.new のモデル — Claude / GPT-4.1 / Gemini 切替戦略',
  $md$
## Bolt.new のモデル構成 (2026-04 時点)

### サポートモデル

| モデル | 特徴 | 推奨用途 |
| :--- | :--- | :--- |
| **Claude Sonnet 4.6** | コーディング最高品質 | デフォルト / 複雑な実装 |
| **Claude Haiku 4.5** | 高速・低コスト | 軽微な修正 / プロトタイプ |
| **GPT-4.1** | 数学・API 設計 | アルゴリズム重視タスク |
| **Gemini 2.0 Flash** | 超高速 | 大量のコード生成 |

デフォルトは **Claude Sonnet** 系。
Anthropic のコーディング能力が vibe-coding 用途で最高評価を受けている。

### StackBlitz AI SDK — プログラマブル統合

```typescript
// StackBlitz SDK を使って自前の AI ツールを構築
import { sdk } from '@stackblitz/sdk';

// Bolt.new プロジェクトを埋め込む
sdk.embedProjectId('my-container', 'bolt-new-project-id', {
  openFile: 'src/App.tsx',
  view: 'both'  // editor + preview
});
```

### WebLLM — ローカル実行の可能性

WebContainers と WebLLM を組み合わせて
**完全オフラインの AI コーディング環境** を構築する実験が進行中。
将来的にはインターネット接続なしでもAI コーディングが可能になる見込み。

### モデル切り替えの使い方

```
Bolt.new の画面右上 → モデルドロップダウン → 選択

各モデルのトークン消費量:
- Claude Sonnet 4.6: ~2x トークン消費 (品質高)
- Gemini Flash: ~0.5x トークン消費 (速度優先)
```
$md$,
  'https://stackblitz.com/blog/bolt-new',
  '2026-04-24',
  2
),

(
  'bolt_new',
  'api',
  'Bolt.new 実践入門 — プロジェクト作成・デプロイ・StackBlitz SDK',
  $md$
## Bolt.new の使い方 (2026-04 時点)

### プロジェクトを始める

```
1. bolt.new にアクセス
2. テキストボックスに要件を入力
3. または URL パターン: bolt.new/~/[template]
   - bolt.new/~/react    → React プロジェクト
   - bolt.new/~/nextjs   → Next.js
   - bolt.new/~/astro    → Astro
   - bolt.new/~/node     → Node.js Express
```

### 効果的なプロンプト

**フルスタックアプリの例**:
```
Node.js + Express バックエンドと React フロントエンドで
リアルタイムチャットアプリを作って。

要件:
- Socket.io でリアルタイム通信
- ユーザー名入力 → チャット入室
- メッセージ履歴は SQLite に保存
- Tailwind CSS でモダンなチャット UI
- モバイル対応
```

**既存コードの改善**:
```
このコードをリファクタリングして:
1. TypeScript に型を追加
2. エラーハンドリングを強化
3. ユニットテストを追加 (Vitest 使用)
```

### GitHub にエクスポート

```
1. Bolt.new の "Export" ボタン → "Export to GitHub"
2. リポジトリ名を入力 → 自動で push
3. ローカルでクローンしてカスタム開発:

git clone https://github.com/username/my-bolt-project
cd my-bolt-project
npm install
npm run dev
```

### Netlify/Vercel へのデプロイ

```
1. Bolt.new の "Deploy" ボタン
2. Netlify または Vercel を選択
3. ワンクリックで本番 URL を取得

または手動:
npm run build
npx netlify deploy --prod --dir=dist
```

### StackBlitz SDK で Bolt を埋め込む

```html
<!-- HTML に埋め込む場合 -->
<script type="module">
  import sdk from 'https://unpkg.com/@stackblitz/sdk@1/bundles/sdk.m.js';

  sdk.openProject({
    title: 'My Bolt Project',
    template: 'node',
    files: {
      'index.js': 'console.log("Hello from WebContainers!")',
      'package.json': JSON.stringify({
        scripts: { start: 'node index.js' }
      })
    }
  });
</script>
```

### 料金プラン

| プラン | 価格 | 内容 |
| :--- | :--- | :--- |
| **Free** | $0/月 | 基本機能 / 月次制限あり |
| **Pro** | $20/月 | 無制限生成 / 優先処理 |
| **Teams** | $50/月 | チーム機能 / 管理者ダッシュボード |

**無料プランでも** 十分な量の生成が可能。
月 $20 の Pro プランで無制限に利用可能。

## ユースケース別の選択ガイド

```
npm パッケージをフルに使いたい       → Bolt.new ✅
Supabase 統合を深く使いたい           → Lovable ✅
UI コンポーネントだけ欲しい          → v0 (Vercel) ✅
本格的な AI コーディングアシスト     → Cursor / Claude Code ✅
学習・実験目的                         → Replit ✅
```

## アクセス方法

1. [bolt.new](https://bolt.new) にアクセス (アカウント不要で即使用可能)
2. または GitHub アカウントでログイン (プロジェクト保存・履歴管理)
$md$,
  'https://docs.bolt.new/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
