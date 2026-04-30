-- PS#3 S124: AI大学 342→343社化 — Sourcegraph Cody (コードベース全体を理解するAIアシスタント)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'sourcegraph-cody', 'overview',
  'Sourcegraph Cody — コードベース全体を理解するAIアシスタント・大規模リポジトリ対応・OSS (9/9)',
  $$## Sourcegraph Cody とは

**Sourcegraph Cody** は **Sourcegraph** が開発する AI コーディングアシスタント。最大の特徴は**コードベース全体を理解した上で回答**できる点。GitHub Copilot や Cursor が開いているファイル周辺のコンテキストに限定されるのに対し、Cody は**数百万行規模のリポジトリ全体を検索・参照**して回答する。

Sourcegraph は元々**コードサーチエンジン**として著名な企業。そのコード検索技術を AI と組み合わせることで、「コードベース全体を知っている AI」を実現した。

## Cody のコアコンセプト

```
Cody のコンテキスト収集:

  Keyword Search (BM25):
    ・コードベース全体をキーワード検索
    ・関数名・変数名・コメントから関連コードを発見

  Vector Search (Embeddings):
    ・セマンティック検索でコードの意味を理解
    ・「似たパターン」「類似ロジック」を発見

  File Path Search:
    ・ファイル名・ディレクトリ構造から推測
    ・設定ファイル・テストファイルを自動発見

  → 複数の検索結果を組み合わせてコンテキスト構築
  → LLM (Claude / GPT-4) に渡して回答生成
```

## 主要機能

- **Chat**: コードベース全体に関する質問・説明
- **Autocomplete**: ファイル内コード補完
- **Commands**: よく使う操作のショートカット
  - `/explain`: 選択コードの説明
  - `/test`: テストコード生成
  - `/doc`: ドキュメント生成
  - `/fix`: バグ修正提案
- **Custom Commands**: 独自コマンドを定義可能

## 大規模リポジトリでの強み

| シナリオ | Cody | Copilot |
|----------|------|---------|
| 「この関数はどこで呼ばれてる？」 | 全体検索で発見 | 開いたファイルのみ |
| 「このエラーの原因は？」 | 関連コード全参照 | 限定的 |
| 「認証の実装パターンは？」 | 既存実装を参照 | 汎用回答 |
| 「このAPIの使い方は？」 | 内部使用例を参照 | ドキュメント参照 |

## 対応 LLM

- **Anthropic Claude** (claude-sonnet-4-6, claude-haiku-4-5)
- **OpenAI GPT-4o**
- **Google Gemini**
- **ローカルモデル** (Enterprise のみ)

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | 基本機能 + 制限あり |
| Pro | $9 | 無制限 Chat + 補完 |
| Enterprise | $19/人 | オンプレ / SSO / カスタムモデル |

## IDE 対応

- VS Code (拡張機能)
- JetBrains 全製品
- Neovim
- Web UI (ブラウザから利用可)

## OSS としての Cody

- **GitHub**: Cody のコアは MIT ライセンスで公開
- **Sourcegraph 本体**: エンタープライズ向け / OSS 版あり
- **コミュニティ**: 活発な Plugin / 拡張エコシステム

## 自分株式会社との関連

Cody の「コードベース全体を検索してコンテキストを構築」するアプローチは、自分株式会社の memory-search-hub EF 設計（BM25 + ベクトル検索のハイブリッド）と類似。Cody の実装を参考に RAG パイプラインの設計を改善できる。
$$,
  'https://sourcegraph.com/cody',
  NOW(),
  343
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
