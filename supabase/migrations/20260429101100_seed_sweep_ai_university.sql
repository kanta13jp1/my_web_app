-- PS#3 S126: AI大学 346→347社化 — Sweep AI (GitHub Issue→PR自動生成 / OSS AIエンジニア)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'sweep-ai', 'overview',
  'Sweep AI — GitHub Issue→PR自動生成・AIジュニアエンジニア・OSS・小タスクの自動実装 (9/9)',
  $$## Sweep AI とは

**Sweep AI** は **GitHub Issue を読んで自動的に PR を作成する**「AI ジュニアエンジニア」サービス。「@sweep」とメンションするだけで、Issue の内容を理解してコードを書き、PR を作成する。

OSS プロジェクトとして公開されており、**GitHub で 7k+ スター**を獲得。小規模バグ修正・テスト追加・リファクタリングなどの**定型タスクの自動化**に特化。

## Sweep AI の使い方

```
Sweep の基本フロー:

  1. GitHub Issue を作成:
     「sweep: ユーザー登録APIのバリデーションエラーハンドリングを改善してください」

  2. Sweep が自動実行:
     ・Issue を読んで意図を理解
     ・関連コードを検索・分析
     ・修正案を実装
     ・テストコードも追加

  3. PR が自動作成:
     ・変更内容の説明付き
     ・テスト結果
     ・レビュー依頼

  4. 人間がレビュー・マージ
```

## 対応タスク例

- **バグ修正**: 「sweep: ログインページでメールアドレスが空の場合にエラーが表示されない」
- **テスト追加**: 「sweep: UserService の単体テストを追加して」
- **リファクタリング**: 「sweep: auth.ts の関数を小さく分割して」
- **ドキュメント**: 「sweep: README に API エンドポイントの説明を追加して」
- **依存更新**: 「sweep: deprecated な lodash 関数を ES2023 の標準に置き換えて」

## 技術的な仕組み

```
Sweep のアーキテクチャ:

  コンテキスト収集:
    ・コードベース全体をインデックス化 (Vector DB)
    ・Issue の内容から関連ファイルを特定
    ・変更影響範囲を分析

  実装:
    ・GPT-4 / Claude でコード生成
    ・既存コードスタイルを学習・踏襲
    ・テストコードも自動生成

  PR 作成:
    ・GitHub API で直接 PR 作成
    ・CI テスト結果を確認
    ・失敗時は自動修正を試みる
```

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| OSS | $0 | Public リポジトリ (GPT-3.5) |
| Pro | $19 | Private リポジトリ (GPT-4) |
| Team | $12/人 | チーム利用 |

## 限界と適用範囲

**得意**:
- 小〜中規模の明確なタスク (50〜200 行以内の変更)
- 既存パターンの踏襲が必要なタスク
- テスト追加・バグ修正

**苦手**:
- 大規模なアーキテクチャ変更
- 複数ファイルにまたがる複雑な変更
- 曖昧・不明確な要件

## 自分株式会社との関連

Sweep AI の「Issue → PR 自動生成」は `github-issue-fix.yml` GHA ワークフローと同じコンセプト。自分株式会社が独自実装した自動 Issue 修正は Sweep の OSS 実装を参考にして設計された。Sweep の限界（小タスク特化）を理解することで、自社ワークフローの適切な使い分けができる。
$$,
  'https://sweep.dev',
  NOW(),
  347
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
