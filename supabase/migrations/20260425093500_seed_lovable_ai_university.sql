-- Session PS#4-S40: AI大学 183→184社化 — Lovable (GPT Engineer後継)
-- Anton Osika (CEO) が 2023 年 GPT Engineer として創業 → 2024 年 Lovable にリブランド。
-- 自然言語からフルスタック React アプリを生成。Claude + Supabase 統合が強み。
-- $50M Series A (Balderton Capital / 2025-01) / 評価額 $250M+。
-- "Superhuman full-stack engineer" — プログラマー不要の vibe-coding プラットフォーム。
-- Step 0: 8.5/9 (vibe-coding 旗手 / Supabase公式パートナー / $250M評価)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'lovable',
  'overview',
  'Lovable — プロンプトでフルスタックアプリを作る vibe-coding の旗手',
  $md$
# Lovable — 「超人的なフルスタックエンジニア」を誰にでも

**Anton Osika** (CEO, 元 Epidemic Sound) が 2023 年に GPT Engineer として創業。
2024 年に **Lovable** へリブランドし、「誰でも本格的な Web アプリを作れる」を実現した。

技術者でなくても Supabase バックエンド + React フロントエンドを持つ
本番グレードのアプリを自然言語だけで構築できる。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **前身** | GPT Engineer / GPT Engineer App (2023) |
| **現社名** | Lovable (Lovable Technologies AB) |
| **CEO** | Anton Osika |
| **本社** | Stockholm, Sweden |
| **調達** | $50M Series A (Balderton Capital / 2025-01) |
| **評価額** | $250M+ (2025) |

## 主要機能

### 1. 自然言語 → フルスタックアプリ

```
「タスク管理アプリを作って。
 ユーザー認証あり。
 タスクに期限・優先度・タグをつけられる。
 Supabase に保存して。」

→ Lovable が React + Supabase の完全なアプリを自動生成
```

### 2. Supabase ネイティブ統合

Supabase を公式パートナーとして採用。ボタン一つで:
- PostgreSQL テーブル自動作成
- Row Level Security (RLS) ポリシー設定
- Auth (email/Google/GitHub) 統合
- Edge Functions 生成

### 3. GitHub 双方向同期

生成したコードを GitHub リポジトリに自動 push。
GitHub からコードを取り込んで Lovable で続きを開発することも可能。

### 4. リアルタイムプレビュー

編集するたびに即座にプレビューが更新。
「ボタンを右上に移動して」「色を青にして」など細かい UI 調整も自然言語で。

## vibe-coding という新パラダイム

Lovable は **vibe-coding** の代表格。
アンドレッセン・ホロウィッツ (a16z) が 2025 年に命名した概念:

> 「コードを書かず、振る舞い (vibe) を伝えてアプリを作る」

非エンジニアの起業家・デザイナー・PM が
週末 2 日で MVP を作れるようになった。

## 競合との位置づけ

| ツール | 特徴 | 向き不向き |
| :--- | :--- | :--- |
| **Lovable** | フルスタック / Supabase 統合 | Web アプリ全般 |
| **Bolt.new** | WebContainers / npm 対応 | Node.js 重視 |
| **v0 (Vercel)** | React UI 特化 | UI コンポーネント |
| **Replit** | 多言語 / クラウド IDE | 学習・実験 |
$md$,
  'https://lovable.dev/',
  '2026-04-24',
  1
),

(
  'lovable',
  'models',
  'Lovable のモデル — Claude Sonnet + カスタム微調整モデル',
  $md$
## Lovable のモデル構成 (2026-04 時点)

### 主力モデル: Claude Sonnet シリーズ (Anthropic)

Lovable は **Anthropic の Claude** をコア生成モデルとして採用。
コーディング精度・長文理解・React/TypeScript 生成品質が選択理由。

| モデル | 用途 |
| :--- | :--- |
| Claude Sonnet 4.6 | デフォルト生成 / UI コンポーネント |
| Claude Opus 4.7 | 複雑なアーキテクチャ設計 (Pro+ のみ) |

### GPT Engineer → Lovable のモデル進化

```
2023-05  GPT Engineer 公開 (GPT-3.5/4 ベース)
         → GitHub 50k+ Stars → 最速成長 OSS の一つ
2023-09  Web 版 GPT Engineer App リリース
2024-03  Lovable にリブランド
2024-H2  Claude Sonnet 3.5 採用 → 品質が大幅向上
2025     Claude Sonnet 4.x / Opus 4.x 対応
```

### カスタム技術: Lovable の固有能力

Lovable はモデルを使うだけでなく、独自の技術を積み重ねている:

**1. Supabase スキーマ自動設計**
- 自然言語の要件から PostgreSQL スキーマを自動生成
- 正規化・インデックス・RLS ポリシーを自動設定

**2. TypeScript 型整合性チェック**
- 生成コードに型エラーがあれば自動修正ループ
- ESLint / Prettier の設定も自動適用

**3. デプロイパイプライン**
- Lovable ホスティング (独自 CDN)
- または Vercel / Netlify への自動デプロイ設定生成

### OSS ルーツ: GPT Engineer

GPT Engineer の OSS 版は GitHub で 52k+ Stars (2025)。
研究者・教育者向けに引き続き無料公開されている。

```bash
# GPT Engineer OSS 版を使う場合
pip install gpt-engineer
gpte "タスク管理 CLI アプリを作って"
```
$md$,
  'https://github.com/AntonOsika/gpt-engineer',
  '2026-04-24',
  2
),

(
  'lovable',
  'api',
  'Lovable 実践入門 — プロジェクト作成・Supabase統合・GitHub連携',
  $md$
## Lovable の使い方 (2026-04 時点)

### プロジェクト作成の流れ

```
1. lovable.dev にアクセス → サインアップ (GitHub 認証)
2. "Start building" → テキストボックスに要件を入力
3. Lovable が React + Tailwind + TypeScript のアプリを生成
4. プレビューで確認 → 追加の指示でイテレーション
```

### 効果的なプロンプトの書き方

**基本パターン**:
```
[アプリの種類] を作って。
機能:
- [機能 1]
- [機能 2]
デザイン: [スタイル指定]
データ: Supabase に保存する
```

**実例 (家計簿アプリ)**:
```
シンプルな家計簿 Web アプリを作って。
機能:
- 収入・支出の登録 (金額・カテゴリ・日付・メモ)
- 月別集計グラフ (棒グラフ)
- カテゴリ別円グラフ
- CSV エクスポート
デザイン: モダンで明るい。カード UI。
Supabase でデータを保存し、ユーザー認証を付ける。
```

### Supabase 統合手順

```
1. Supabase プロジェクト作成 (supabase.com)
2. Lovable の "Integrations" → "Connect Supabase"
3. Supabase プロジェクト URL + anon key を入力
4. "Generate database schema" → テーブル自動作成
5. RLS ポリシーも自動設定される
```

### GitHub 連携

```
1. Lovable の "..." メニュー → "Connect GitHub"
2. リポジトリを選択または新規作成
3. 以降、Lovable での変更が自動で commit → push
4. ローカルで `git clone` してカスタム開発も可能
```

### 料金プラン

| プラン | 価格 | メッセージ数 |
| :--- | :--- | :--- |
| **Free** | $0/月 | 5 messages/日 |
| **Starter** | $25/月 | 100 credits (1 message ≒ 1 credit) |
| **Pro** | $100/月 | 500 credits + 優先処理 |
| **Teams** | 要問合せ | カスタム |

**Starter $25/月** が個人開発者の標準。月 100 回の生成で MVP から本番まで十分。

### このプロジェクトへの応用

```
「自分株式会社アプリの新機能: 習慣トラッカーページを作って。
 既存のデザイントークン: オレンジ (#FF6B00) とインディゴ (#4F46E5)
 Flutter っぽいカード UI、Supabase の habits テーブルと連携」

→ Lovable が React 版プロトタイプを生成
→ そのコンポーネント設計を参考に Flutter 実装
```

## アクセス方法

1. [lovable.dev](https://lovable.dev) でアカウント作成
2. GitHub アカウントで認証
3. 無料プランでまず試す (1 日 5 回まで)
$md$,
  'https://docs.lovable.dev/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
