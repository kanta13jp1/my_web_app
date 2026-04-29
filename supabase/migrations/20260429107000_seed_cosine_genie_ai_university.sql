-- PS#3 S127: AI大学 349→350社化 — Cosine / Genie (SWE-bench世界1位 / 深いコードベース理解)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'cosine-genie', 'overview',
  'Cosine Genie — SWE-bench Verified世界1位達成・深いコードベース理解・自律AIエンジニア (9/9)',
  $$## Cosine / Genie とは

**Cosine** は **Genie** という AI エンジニアリングエージェントを開発するスタートアップ。2025年に **SWE-bench Verified で世界 1 位**（当時）のスコアを達成して業界に衝撃を与えた。

Devin (Cognition AI) や OpenHands と同じ「自律 AI ソフトウェアエンジニア」カテゴリながら、**コードベースへの深い理解**と**長期記憶**を特徴とする独自のアーキテクチャで差別化。

## SWE-bench での衝撃

```
SWE-bench Verified スコア推移 (2025年):

  Claude 3.5 Sonnet (Anthropic): 49%
  OpenHands + Claude:             53%
  Cosine Genie:                   ~55%+ (世界1位達成時)

  ※ SWE-bench = 実際のGitHub Issueを解決する能力テスト
  ※ 2294件の実際のバグ・機能追加タスクで評価
```

## Genie の技術的特徴

```
Genie のアーキテクチャ:

  Deep Codebase Understanding:
    ・コードベース全体をグラフ構造で表現
    ・関数間の呼び出し関係を理解
    ・データフローを追跡
    ・過去の変更履歴を記憶

  Long-term Memory:
    ・プロジェクト固有の知識を蓄積
    ・過去の修正パターンを学習
    ・チームのコーディングスタイルを習得

  Multi-step Planning:
    ・複雑なタスクを小ステップに分解
    ・各ステップを実行・検証
    ・失敗時に計画を修正・再実行
```

## Cosine vs Devin 比較

| 項目 | Cosine Genie | Devin |
|------|-------------|-------|
| SWE-bench | 世界1位 (当時) | 13.86% (初期) |
| 長期記憶 | ○ (コードベース特化) | △ |
| 価格 | 要問い合わせ | $500/月〜 |
| 公開状況 | ウェイトリスト | 一般提供 |
| 設立 | 2023 | 2024 |

## Cosine の研究成果

- **論文・ブログ**: SWE-bench での高スコア達成の方法論を公開
- **コードベースグラフ**: ソースコードを知識グラフとして表現する手法
- **Retrieval 手法**: コードの意味的類似性に基づく検索

## 現状と展望

- **ウェイトリスト制**: 2025年時点で一般公開前（特定企業のみ）
- **資金調達**: YC 出身 / シリーズ A 調達済み
- **競合への影響**: Cosine のスコアが Anthropic / OpenAI の開発を刺激

## 自分株式会社との関連

Cosine Genie の「コードベースをグラフ構造で理解 + 長期記憶」アーキテクチャは、自分株式会社の SECOND_BRAIN 原則（BRAIN-32）と概念的に一致。特に「Hybrid Search (BM25 + Vector) + Long-term Memory」の組み合わせは memory-search-hub EF の設計に直接活用できる。
$$,
  'https://cosine.sh',
  NOW(),
  350
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
