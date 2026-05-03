-- PS#3 S149: AI大学 Devin 2026 Documentation追加 (Issue #1798)
-- Source: f985728b Devin Documentation Release Notes 2026

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'devin', 'enterprise_2026',
  'Devin Enterprise 2026 — Teams機能・ACL・Audit Log・Memory・Knowledge Base本番運用完全ガイド (10/10)',
  $$## Devin Enterprise 2026 とは

**Devin** (Cognition AI) は2025年〜2026年にかけて**エンタープライズ向け機能**を大幅強化。単なる「自律エンジニア」から**チーム全体のAIエンジニア管理プラットフォーム**へと進化した。

## Enterprise 主要機能

```
[Teams & ACL]
  ・組織・チーム・プロジェクト単位でDevinを管理
  ・Role-based Access Control (RBAC) でアクセス制御
  ・複数のDevinインスタンスをチームで共有
  ・タスクの割り当てと進捗追跡ダッシュボード

[Knowledge Base]
  ・コードベース・ドキュメントをDevinに「記憶」させる
  ・社内ルール・コーディング規約を事前学習
  ・過去の修正パターンを蓄積して精度を向上
  ・プロジェクト固有の文脈をコンテキストに自動追加

[Audit Log]
  ・Devinの全アクション（コード変更・APIコール・ファイル操作）を記録
  ・コンプライアンス要件（SOC2/ISO27001）に対応
  ・「誰がいつどのDevinにどのタスクを依頼したか」を追跡
  ・異常なアクションパターンを検出してアラート

[Memory System]
  ・セッション間で学習した内容を永続保持
  ・「このプロジェクトではXではなくYを使う」を記憶
  ・チームメンバーからのフィードバックを学習
  ・時間とともに精度が向上するAdaptive AI
```

## Devin 2026 パフォーマンス指標

| 指標 | 2024年3月 | 2026年5月 |
|------|-----------|-----------|
| SWE-bench Verified | 13.86% | **~55%** |
| 独立完遂率 | 基本タスク | 中〜複雑タスク |
| 対応言語 | Python中心 | 15+ 言語 |
| 統合ツール | GitHub | GitHub/Jira/Linear/Slack |

## 自律性レベルの定義 (Devin 2026)

```
Level 1: Supervised  → 全操作をユーザーが確認
Level 2: Guided     → 重要な決断のみ確認
Level 3: Autonomous → バックグラウンドで完全実行
Level 4: Fleet      → 複数Devinが協調して大規模タスク (近未来)
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 開発ツール / AIエージェント / 自律AIエンジニア学科
- **関連プロバイダー**: Cursor / Claude Code / GitHub Copilot / SWE-bench
- **実用的示唆**: DevinのKnowledge Base機能 = 自分株式会社のmemory/MEMORY.md戦略と同型
  → 「AIへの記憶移譲」がエンタープライズでも標準化しつつある
$$,
  'https://docs.devin.ai/',
  '2026-01-01',
  97
)
ON CONFLICT (provider, category) DO NOTHING;
