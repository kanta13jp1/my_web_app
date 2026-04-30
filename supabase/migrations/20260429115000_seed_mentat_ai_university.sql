-- PS#3 S129: AI大学 352→353社化 — Mentat (CLIコーディングAI / git統合 / コードベース全体理解)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'mentat', 'overview',
  'Mentat — CLI コーディングエージェント・コードベース全体理解・git 統合・複数ファイル編集 (9/9)',
  $$## Mentat とは

**Mentat** はターミナルで動作する AI コーディングエージェント。**コードベース全体を理解した上で複数ファイルを同時編集**するのが特徴で、2023年に登場した初期の自律コーディングエージェントの一つ。

「Mentat」という名前は Frank Herbert の小説「デューン」に登場する人間コンピューターに由来。コードを「考える」エージェントというコンセプトを体現している。

## Mentat の中核機能

```
Mentat のアーキテクチャ:

  Context Management:
    ・プロジェクト全体の構造を把握
    ・関連ファイルを自動選択してコンテキストに含める
    ・/include, /exclude でファイル管理
    ・変更履歴を追跡

  Multi-file Editing:
    ・1回の指示で複数ファイルを同時変更
    ・diff 形式で変更内容を提示
    ・変更前に確認プロンプト (対話型)

  Git Integration:
    ・git 管理下のプロジェクトで動作
    ・変更を自動的に git add/commit
    ・コミットメッセージを自動生成
```

## 対話的なワークフロー

```bash
# インストール
pip install mentat

# プロジェクトルートで起動
cd my-project
mentat

# Mentat との対話例
> lib/auth_service.dart lib/pages/login_page.dart
  ↑ 対象ファイルを指定

> "ログイン時のエラーハンドリングを改善して"

Mentat: 以下の変更を行います:
  lib/auth_service.dart: try/catch ブロックを追加
  lib/pages/login_page.dart: エラーメッセージ表示を追加

変更を適用しますか? [y/n]: y
✓ 2ファイルを変更しました
```

## Aider との比較

| 項目 | Mentat | Aider |
|------|--------|-------|
| インターフェース | 対話型 CLI | CLI + git |
| ファイル選択 | 手動 + 自動 | repo-map 自動 |
| git 統合 | △ (基本的) | ◎ (自動コミット) |
| SWE-bench | 未測定 | Top tier |
| 開発状況 | メンテナンス縮小 | 活発 |
| 特徴 | シンプルな対話 | 高精度な修正 |

## 歴史的意義

Mentat は **2023年の自律コーディングエージェント黎明期**に登場し、「LLM がコードベース全体を理解して修正できる」という概念を早期に実証した。その後 Aider、Devin、Claude Code など多くのツールに影響を与えた。

現在は Aider や Claude Code に市場を譲りつつあるが、「コードベース全体理解型エージェント」の先駆者として AI 開発史に名を残す。

## 自分株式会社との関連

自分株式会社の 12 インスタンスフリートは Mentat が提唱した「コードベース全体を理解した上で複数ファイルを同時編集する」コンセプトの大規模進化形態。各インスタンスが専任領域のファイルを理解・編集する分散型アーキテクチャは、Mentat の単一エージェントモデルを並列に拡張したものと見なせる。
$$,
  'https://github.com/AbanteAI/mentat',
  NOW(),
  353
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
