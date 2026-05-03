-- PS#3 S149: AI大学 Mastering Claude 専門コース追加 (Issue #1806)
-- Source: ed1aac00 Mastering Claude: A Guide to Intelligent Collaboration

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'claude', 'mastering_collaboration',
  'Claude マスタリング — インテリジェント協調の完全ガイド・プロンプト設計から高度なワークフロー構築まで (10/10)',
  $$## Claude をマスターするとは

**Claude** (Anthropic) は単なる「答えを返すAI」ではなく、**思考パートナー・コラボレーター**として設計されている。Claude を最大限活用するには、**対話の設計・文脈の構造化・タスク分解**の技術が必要。

## 協調の5原則

```
[原則1: 文脈の先行提供]
  ❌ 悪い例: 「このコードを直して」
  ✅ 良い例: 「Flutter WebアプリでSupabaseを使っています。
              このエラーはログインページで発生します。
              期待動作はXですが実際はYが起きています: [コード]」
  → 文脈を先に渡すとClaude の回答精度が劇的に向上

[原則2: タスク分解の協働]
  ・複雑なタスクを一度に渡さず、Claude と一緒に分解する
  ・「このタスクをどう分解すべきか教えて」→ Claude の提案を活用
  ・分解後、各サブタスクを順番に依頼
  → 大きなタスクほど協働分解が効果的

[原則3: 反復的な改善]
  ・最初の回答で完璧を求めない
  ・「これを踏まえて〜の観点から改善して」で段階的に精度を上げる
  ・"Constitutional AI"の仕組みを理解して方向修正する
  → 反復がClaude の真の実力を引き出す

[原則4: 制約の明示]
  ・「Dart で書いて」「日本語で」「200字以内で」を必ず指定
  ・出力フォーマット（JSON/Markdown/リスト）を事前指定
  ・禁止事項も明示する（「コードコメントは不要」など）
  → 制約の明示で手戻りを90%削減

[原則5: メタ認知の活用]
  ・「この問題へのアプローチを教えて」でClaude の思考を可視化
  ・「他の解決策はあるか」で視野を広げる
  ・「この回答の信頼度は？」で不確実性を確認
  → Claude に自分自身の思考を問わせる
```

## 高度な協調パターン

| パターン | 使用例 | 効果 |
|--------|--------|------|
| **Roleplay Persona** | 「10年目のFlutter専門家として」 | 専門的視点獲得 |
| **Red Team** | 「この設計の問題点を全て挙げて」 | リスク発見 |
| **Socratic Method** | 「なぜそう思う？」の連鎖 | 深い理解 |
| **Template Fill** | 「このテンプレートを埋めて: [XXX]」 | 一貫性確保 |
| **Chain of Thought** | 「ステップバイステップで考えて」 | 複雑問題解決 |

## Claude のモデル選択ガイド (2026)

```
Haiku 4.5  → 高速・低コスト / 定型処理・分類・短文生成
Sonnet 4.6 → バランス型 / 一般的なコーディング・分析・日常タスク
Opus 4.7   → 最高精度 / 複雑な設計・難問・長文生成・アーキテクチャ判断
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 開発ツール / Claudeエコシステム / 協調AI学科
- **関連プロバイダー**: Claude Code / Anthropic / Prompt Engineering
- **実用的示唆**: 5原則をClaude Codeのプロンプトに適用すると
  CLAUDE.md の1回読みより inject-rules.txt の毎ターン注入の方が遵守率が高い理由と同じ原理
$$,
  'https://docs.anthropic.com/claude/',
  '2026-01-01',
  95
)
ON CONFLICT (provider, category) DO NOTHING;
