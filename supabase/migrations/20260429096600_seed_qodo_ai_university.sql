-- PS#3 S125: AI大学 344→345社化 — Qodo (旧CodiumAI / AIテスト生成・PR-Agent・コードレビュー)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'qodo', 'overview',
  'Qodo — 旧CodiumAI・AIテスト生成・PR-Agent・コードレビュー自動化・OSS (9/9)',
  $$## Qodo とは

**Qodo**（旧称: **CodiumAI**）は **テスト生成・PR レビュー・コード品質** に特化した AI コーディングツール。2024年に CodiumAI からリブランディング。「**コードを書く AI**」より「**コードの品質を保証する AI**」に特化した珍しいポジション。

**PR-Agent**（GitHub PR の自動レビュー・要約・改善提案）と**テスト生成**が主力機能。どちらもオープンソースで公開されており、GitHub で合計 **20k+ スター**を獲得。

## Qodo の主要プロダクト

```
Qodo のプロダクトライン:

  1. Qodo Gen (旧 Codium):
     ・IDE 拡張 (VS Code / JetBrains)
     ・テストコード自動生成 (関数を見てテスト提案)
     ・コードの振る舞い分析 → エッジケース発見
     ・テストカバレッジ向上支援

  2. Qodo Merge (旧 PR-Agent): [OSS]
     ・GitHub PR の自動レビュー
     ・PR サマリー自動生成
     ・コード変更の影響範囲分析
     ・セキュリティ問題の指摘
     ・GitHub Actions / GitLab CI / Bitbucket 対応

  3. Qodo Cover:
     ・テストカバレッジの可視化
     ・カバレッジギャップの特定
     ・テスト追加の優先度付け
```

## PR-Agent の機能 (OSS)

PR-Agent は自分株式会社でも既に活用中の概念:

```yaml
# GitHub Actions での PR-Agent 設定例
- name: PR-Agent
  uses: Codium-ai/pr-agent@main
  env:
    OPENAI_KEY: ${{ secrets.OPENAI_KEY }}
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  with:
    pr_description: true    # PR説明を自動生成
    pr_review: true         # コードレビュー
    pr_code_suggestions: true  # 改善提案
```

**自動実行コマンド**:
- `/describe`: PR の説明を自動生成
- `/review`: コードレビューを実行
- `/improve`: コード改善提案を生成
- `/ask "質問"`: PR に関する質問

## テスト生成の強み

Qodo Gen のテスト生成は他ツールと一線を画す:

1. **振る舞い分析**: コードが「何をするか」を理解
2. **エッジケース発見**: 境界値・例外ケース・ハッピーパスを網羅
3. **テスト説明付き**: なぜそのテストが必要かを説明
4. **カバレッジ考慮**: 既存テストのギャップを埋める

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | Qodo Gen 基本 + PR-Agent OSS |
| Teams | $19/人 | 無制限 + 高度機能 |
| Enterprise | 要問い合わせ | SSO / 監査ログ / オンプレ |

**PR-Agent 自体は MIT OSS** — 無料でセルフホスト可能

## 自分株式会社との関連

自分株式会社の `claude-agent-review.yml` は PR の自動レビューを実装済み。Qodo Merge (PR-Agent) のアーキテクチャ・プロンプト設計は、この GHA ワークフローの改善参考になる。特に「/describe・/review・/improve の 3 コマンド分離」は Claude API を使った PR レビューシステムに適用できる。
$$,
  'https://qodo.ai',
  NOW(),
  345
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
