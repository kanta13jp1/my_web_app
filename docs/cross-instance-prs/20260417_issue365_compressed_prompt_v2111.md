# cross-instance-pr: Issue #365 COMPRESSED_PROMPT_V3.md v2.1.111反映

作成: Windowsアプリ版 (2026-04-17)
宛先: PowerShell版 + VSCode版
状態: done (PR作成済)

## 経緯

Issue #365 は PowerShell版 担当指定。`docs/INSTANCE_CONFIG.md` は既に 2026-04-17 の PowerShell版セッションで v2.1.111 対応済 (変更ログ line 692 記載)。

一方 `.github/COMPRESSED_PROMPT_V3.md` は **未更新** (4インスタンス記載のまま / v2.1.111 機能なし / `claude-opus-4` 旧モデル参照 / WEB版記載継続) のため、Windowsアプリ版から docs-only の同期更新を実施。

## 変更内容

1. ヘッダー: 「4インスタンス」→「3インスタンス」+ WEB版廃止(2026-04-17) 明記
2. instance表: WEB版行を打ち消し線で廃止化 / 残3インスタンスに Opus 4.7 + `/effort high` 推奨追加 / PS版担当に `docs/INSTANCE_CONFIG.md` 明示
3. Claude最新機能テーブル: v2.1.111 新機能 5件追加 (`/effort xhigh`, `/ultrareview`, `/less-permission-prompts`, PowerShell tool, Windows SessionStart hook) + `/recap`・Routines・Adaptive Thinking 補強
4. AI選択フロー: 「ブログ/競合リサーチ」担当を WEB版→Windowsアプリ版に変更
5. バージョンチェック表: WEB版行を削除
6. 参照先: `docs/instance-constraints.md` → `docs/INSTANCE_CONFIG.md` に変更 (旧ファイルは段階的廃止)

## 担当外領域への注意

本セッションはWindowsアプリ版 (担当 `docs/` + `supabase/migrations/`)。`.github/COMPRESSED_PROMPT_V3.md` は元来 PowerShell版 領域だが、docs-only更新 (GHA定義変更なし / コード変更なし) のため PR経由で実施。PS版 レビュー推奨。

## 確認ポイント (PS版)

- `docs/INSTANCE_CONFIG.md` は既反映済 → 追加作業不要
- 本PRはマージ後に PS版 `/recap` で確認可
- `/less-permission-prompts` 実行と `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` テストは依然 PS版の未完タスク (Issue #365 原文に明記)

## 関連

- Issue #365: `[制約変更] Claude Code v2.1.111 新機能を INSTANCE_CONFIG.md に反映依頼`
- INSTANCE_CONFIG.md 変更ログ: 2026-04-17 PowerShell版 (line 692)
- `docs/instance-constraints.md` 段階的廃止 → `docs/INSTANCE_CONFIG.md` に一本化
