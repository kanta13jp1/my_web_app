# 記事公開パイプライン自動品質評価ガードレール

Issue: #2648

## 目的

手動レビューを省略した技術記事・ドラフト自動公開パイプラインにおいて、内容の薄い記事・プレースホルダー残存・既公開記事とのトピック重複がそのまま公開されるリスクを遮断し、コミットトレーサビリティ付きの監査ログを自動生成します。

## 既存資産との役割分担

- 既存の [`blog_publish_policy.ts`](../../supabase/functions/schedule-hub/blog_publish_policy.ts)（投稿先プラットフォーム許可リスト制御）および [`.github/workflows/blog-publish.yml`](../../.github/workflows/blog-publish.yml) / [`scripts/validate_blog_draft.py`](../../scripts/validate_blog_draft.py)（公開ジョブ直前の単一ドラフト検査）を補完します。
- 本ガードレール ([`scripts/article_quality_guardrail.py`](../../scripts/article_quality_guardrail.py) / [`.github/workflows/article-publish-quality-guardrail.yml`](../../.github/workflows/article-publish-quality-guardrail.yml)) は PR 変更差分に対して複数記事・Zenn 記事を含むトピック重複検査、プレースホルダー検知、および JSON/Markdown 失敗監査ログ出力を担います。

## 品質基準しきい値

| 項目 | 既定しきい値 | 検証内容 |
| --- | --- | --- |
| タイトル必須 | Frontmatter `title:` または `# ` H1 | 空タイトルや見出し欠落を遮断 |
| 実質本文文字数 (`min_chars`) | `600` 文字以上 | Frontmatter・コードブロック・空白を除いた実質本文量を計測 |
| セクション見出し (`min_h2`) | `## ` 見出し `2` 件以上 | 導入・本論等の章立て構造を担保 |
| スタブ・プレースホルダー | `0` 件 | `TODO` / `TBD` / `FIXME` / `Lorem ipsum` / `Coming soon` / `[作成中]` 等を検知 |
| トピック重複しきい値 | `0.55` 未満 (`duplicate_title` は `1.0`) | 文字 3-gram Jaccard 係数およびトークン・CJK 2-gram コサイン類似度で `docs/blog-drafts/` と `docs/blog/zenn/` を走査（自パスは除外） |

## トレーサビリティとフェイルクローズ契約

- 各対象記事について `git log -n 1` から `commit_sha`・`commit_timestamp`・`commit_subject` と本文 `content_sha256` を記録します。
- いずれかの検証項目が基準未満の場合、CI は **終了コード `1`（fail-closed）** で停止し、JSON 形式および Markdown 形式のエラー監査ログ（失敗理由一覧・最も類似した既存記事トップ 3 のパスと類似度スコアを含む）をアーティファクトおよびジョブサマリーへ保存します。
- 記事ドラフトを変更しない通常の PR では `--changed-since` が対象 `0` 件を検知し、既存アーカイブで無関係 PR が落ちないよう安全にスキップ (`status: skipped`, `rc=0`) します。
