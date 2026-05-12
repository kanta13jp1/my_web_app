-- PS#3 S120: AI大学 334→335社化 — Windsurf (Codeium AI IDE / VS Code fork / Cascade エージェント)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'windsurf', 'overview',
  'Windsurf — Codeium製AI IDE・Cascade Agentで自律コーディング・Cursor対抗 (GitHub / 9/9)',
  $$## Windsurf とは

**Windsurf** は **Codeium** が開発する AI ネイティブ IDE（旧称: Codeium IDE）。VS Code をフォークした独自エディタで、**Cascade** と呼ばれるエージェントがコードベース全体を理解しながら**自律的にコーディング・デバッグ・ファイル編集**を行う。

Cursor の直接競合であり、**無料プランが手厚い**（Codeium の強み）ことで急速に普及。月 $15 の個人プランで Cascade Agent が使い放題。チームプランは $35/月/ユーザー。

## Windsurf の特徴

```
Windsurf のコアコンセプト:

  Cascade (エージェントシステム):
    ・Flows: 自律的なタスク実行フロー
    ・Deep Context Engine: コードベース全体を深く理解
    ・Multi-file editing: 複数ファイルを横断した一括編集
    ・Terminal integration: コマンド実行・エラー自動修正
    ・Browser preview: UIの即時プレビュー

  エディタ機能:
    ・VS Code ベース (拡張機能互換)
    ・Autocomplete: AI補完 (Codeium の強み)
    ・Chat: コードについての質問・説明
    ・Supercomplete: 長い補完ブロック生成
```

## Codeium の歴史と Windsurf

- **Codeium 創業 (2022)**: GitHub Copilot の強力な無料代替として登場
- **AI補完の品質**: 70+ 言語対応、IDE プラグイン（VS Code / JetBrains / Vim等）
- **Windsurf リリース (2024)**: エージェント機能を統合した独自 IDE として進化
- **急成長**: 数ヶ月で数十万ユーザーを獲得、Cursor の主要競合に

## 料金体系

| プラン | 月額 | 特徴 |
|--------|------|------|
| Free | $0 | 基本補完 + Cascade 限定利用 |
| Pro | $15 | Cascade Agent 無制限 + GPT-4o/Claude |
| Team | $35/人 | 管理機能 + SSO + 優先サポート |

## Windsurf vs Cursor 比較

| 項目 | Windsurf | Cursor |
|------|----------|--------|
| ベース | VS Code fork | VS Code fork |
| エージェント | Cascade | Composer |
| 無料枠 | 手厚い | 限定的 |
| 月額 Pro | $15 | $20 |
| 企業向け | ○ | ○ |

## 開発者の評価

- **「無料で使えるのが最大の魅力」** — 個人開発者・学生に支持
- **「Cascade の自律性が高い」** — 複雑なタスクをほぼ自動で完結
- **「VS Code 拡張が使える」** — 移行コストが低い

## 自分株式会社との関連

Windsurf は **VSCode版インスタンス**の代替ツール候補。Codeium の無料補完は既に多くのインスタンスで活用されており、Windsurf への移行でエージェント機能が強化される可能性がある。
$$,
  'https://codeium.com/windsurf',
  NOW(),
  335
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
