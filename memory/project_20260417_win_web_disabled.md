# WEB版廃止 — 3インスタンス制に復帰 (2026-04-17 Windowsアプリ版)

## 発生した問題

WEB版 Claude Code (claude.ai/code) で本セッションに以下が実発生:

1. **GitHub MCP 切断 3回** (利用可→切断→利用可→切断→利用可)
2. **Stream idle timeout - partial response received** — WebFetch + file edits 並列時
3. **INSTANCE_CONFIG.md 不存在と誤認** — file read 失敗 → 新規作成試行 (role 境界違反)
4. **推奨プロンプトが INSTANCE_CONFIG.md 直接編集を指示** (PowerShell版の owner であり WEB版 scope 外)

## 根本原因

- v2.1.110 の "MCP tool calls hanging when server connection drops" 修正は **ローカル版 (Claude Code CLI) 向け**
- WEB版 (claude.ai/code) は別ランタイムで同修正が適用されず構造的に不安定
- WEB版の制約 (notebooklm・flutter analyze・deno lint・gh/git CLI 全て不可) に GitHub MCP 不安定が加わり実用性が著しく低下

## 対応内容 (commit 95c385a4)

**5ファイル全編集・149削除・29追加**:
- `docs/MULTI_INSTANCE_COORDINATION.md`: タイトル 4→3・WEB版行削除
- `docs/INSTANCE_CONFIG.md`: WEB版制約カタログ・役割分担・推奨プロンプト・モード推奨行を全削除
- `docs/README.md`: 4インスタンス → 3インスタンス
- `CLAUDE.md`: Rule 14/21/22 の WEB版参照削除・Agent Teams 行修正 (41→66プロバイダー)
- `.github/COMPRESSED_PROMPT_V3.md`: ヘッダー 4→3・スコープ表から WEB版削除

## WEB版担当の再配分

| 旧 WEB版担当 | 新担当 |
|------------|-------|
| `docs/research/` + `docs/blog-drafts/` | Windowsアプリ版 (既に docs/ owner) |
| GitHub MCP PR・Issue 管理 | PowerShell版 (gh CLI 使用可) |
| ブログ英語翻訳・品質レビュー | PowerShell版 or 廃止検討 |
| Opus 4.7 アーキテクチャレビュー | Windowsアプリ版/PowerShell版 |

## 過去の経緯

- **PS版#52 (2026-04-13)**: Web版廃止 → 3インスタンス体制移行
- **PS版#Multi-AI (2026-04-16)**: WEB版復活・Opus 4.7 アーキテクチャレビュー用途
- **Windowsアプリ版#Opus47-2 (2026-04-17)**: **再度 WEB版廃止** (本対応)

## 再検討条件

WEB版を復活させる場合の要件:
1. GitHub MCP 切断が発生しない (v2.1.110相当の安定化修正が WEB ランタイムに適用)
2. `git`/`gh` CLI 相当の操作が WEB版でも可能になる
3. notebooklm CLI or 同等機能が利用可能になる

上記が満たされない限り、3インスタンス制 (VSCode / Windowsアプリ / PowerShell) を継続。

## 次回タスク候補

1. **PowerShell版** が INSTANCE_CONFIG.md/MULTI_INSTANCE_COORDINATION.md の cross-instance 変更を承認
2. **VSCode版** が lib/pages/{admin/quota_dashboard_page,ai_assistant_chat_page}.dart の DESIGN.md トークン変更を commit
3. **Windowsアプリ版** が AI大学 67社目候補評価 (Harvey AI / Typeface / Writer)
