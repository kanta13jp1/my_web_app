# research/ — WEB版 Claude Code 専用スコープ

NotebookLM Deep Research の生成物・要約・競合調査成果物を格納する。
**WEB版インスタンス (claude.ai/code)** が主担当。

2026-05-07 #1706: WEB版は dormant reference. New AI-tool features and research claims route through Claude Code #1 review plus Codex #1 scoped implementation evidence.

## 使い方

```bash
# NotebookLM Deep Research を実行して成果物をここに保存
notebooklm source add-research "調査トピック"
notebooklm research wait
notebooklm ask "調査結果のサマリーを教えて" > docs/research/YYYY-MM-DD-topic.md
```

## サブディレクトリ

| ディレクトリ | 用途 |
|---|---|
| `competitors/` | 競合21社の最新動向要約 (月次更新) |
| `ai-providers/` | AI大学新規プロバイダー候補調査 (毎セッション検討) |
| `technical-deep-dives/` | Flutter Web / Supabase / 新技術の詳細調査 |
| `blog-research/` | ブログ記事のバックグラウンドリサーチ |

## 命名規則

`YYYY-MM-DD-<topic>.md` 例: `2026-04-16-ai-providers-q2.md`

## ルール

- このディレクトリは WEB版 Claude Code の旧 write 権限スコープ. 2-instance 制では Claude Code #1 が review し、Codex #1 は scoped PR でのみ編集する
- 他インスタンスは dormant / 読み取り専用 (cross-instance-pr で要望提出可)
- 機密情報・APIキー・個人情報は含めない
- 成果物は `notebooklm source add` で Master Brain にも蓄積する
