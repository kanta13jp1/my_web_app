-- PS#3 S125: AI大学 345→346社化 — CodeRabbit (AI自動PRレビュー / LLMベースコードレビューSaaS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'coderabbit', 'overview',
  'CodeRabbit — AI自動PRレビューSaaS・LLMによる行単位コードレビュー・OSS無料・GitHub/GitLab対応 (9/9)',
  $$## CodeRabbit とは

**CodeRabbit** は **LLM を使った自動 PR コードレビューサービス**。GitHub / GitLab の Pull Request に自動的にコメントを付け、**行単位の詳細なレビュー**・**PR サマリー**・**改善提案**を行う。

**OSS プロジェクトは完全無料**という大胆な戦略で急成長。商業プロジェクトは $12/月/開発者。自分株式会社が使う `claude-agent-review.yml` と同じカテゴリの競合サービス。

## CodeRabbit の仕組み

```
CodeRabbit のレビューフロー:

  PR オープン時 (自動実行):
    1. diff の全ファイルを読み込み
    2. コードの変更意図を推測
    3. PR サマリーを自動生成 (Walkthrough)
    4. ファイルごとにレビューコメントを付加
    5. セキュリティ・パフォーマンス・ベストプラクティスをチェック

  レビューの種類:
    ・actionable: すぐに修正すべき問題
    ・nitpick: 軽微なスタイル・可読性の提案
    ・informational: 参考情報

  対話型レビュー:
    ・@coderabbitai コマンドでチャット
    ・「この箇所をもう少し詳しく説明して」
    ・「代替実装を提案して」
    ・「この変更を承認して」
```

## 自動生成 PR サマリー例

```markdown
## Walkthrough
This PR adds authentication middleware to the Edge Function router.
The changes introduce JWT validation, rate limiting, and audit logging.

## Changes
| File | Summary |
|------|---------|
| `functions/ai-hub/index.ts` | Added JWT validation in request handler |
| `functions/_shared/auth.ts` | New authentication utilities |

## Assessment
- Security: JWT validation correctly implemented ✅
- Performance: Rate limiting may cause latency under high load ⚠️
- Testing: No test coverage for error cases ❌
```

## GitHub Actions 統合

```yaml
# CodeRabbit を GitHub Actions で設定
name: CodeRabbit Review
on: [pull_request]
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: coderabbitai/coderabbit-action@v1
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          openai_api_key: ${{ secrets.OPENAI_API_KEY }}
```

## 料金体系

| プラン | 月額/人 | 対象 |
|--------|---------|------|
| OSS | **$0** | Public リポジトリ |
| Lite | $12 | Private リポジトリ |
| Pro | $19 | 高度機能 + 優先サポート |
| Enterprise | 要問い合わせ | SSO / オンプレ |

**「OSS 無料」戦略**で開発者コミュニティに急速に普及。

## Qodo Merge vs CodeRabbit 比較

| 項目 | CodeRabbit | Qodo Merge |
|------|------------|-----------|
| OSS 無料 | ○ | ○ (PR-Agent OSS) |
| 有料 | $12/月 | $19/月 |
| LLM | GPT-4o / Claude | GPT-4o / Claude |
| 行単位コメント | ◎ | ○ |
| PR サマリー | ◎ | ◎ |
| 対話型 | ○ (@coderabbitai) | ○ (/review等) |
| IDE 統合 | × | ○ (Qodo Gen) |

## 採用実績

- **Redis / MinIO / Airbyte / Cal.com** など著名 OSS プロジェクトで採用
- GitHub Marketplace で **1000+ インストール**
- PR レビュー時間を平均 **60〜80% 削減** との報告

## 自分株式会社との関連

自分株式会社の `claude-agent-review.yml` は Claude API を直接使って PR レビューを実装。CodeRabbit はその SaaS 競合。CodeRabbit の「行単位コメント + PR サマリー + @coderabbitai 対話」の UX を参考に、自社 GHA ワークフローの出力フォーマットを改善できる。
$$,
  'https://coderabbit.ai',
  NOW(),
  346
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
