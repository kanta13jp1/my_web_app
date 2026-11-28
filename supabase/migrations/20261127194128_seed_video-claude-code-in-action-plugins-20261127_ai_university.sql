-- AI大学: YouTube 公開動画を埋め込み学習コンテンツとして登録する。

INSERT INTO ai_university_content (
  provider,
  category,
  title,
  content,
  source_url,
  published_at,
  sort_order,
  is_active
)
VALUES (
  'anthropic',
  'video_claude_code_in_action_plugins_20261127',
  'Claude Codeプラグイン配布設計｜導入前フック監査・PLUGIN_ROOT移行・二重実行防止【実践Claude Code #9】',
  $content$# Claude Codeプラグイン配布設計（実践Claude Code #9）

## 学習目標
チームで構築した Skills・Subagents・Hooks・MCP 設定を手動コピペではなく 1 つのインストール単位（Plugin）としてパッケージ化し、導入前のフック・権限監査、`${CLAUDE_PLUGIN_ROOT}` へのパス移行、二重起動防止とクラウド実行との併用まで設計できるようになる。

## ポイント
- **導入とマーケットプレイス**: `/plugin install <name>@<marketplace>` や `/plugin marketplace add your-org/claude-plugins` で共有でき、再読込が必要な場合は `/reload-plugins`（会話再読込警告が出る場合は `--force`）で反映する。`/plugin` の Installed タブから構成確認・無効化・更新・削除を行える。
- **導入前の監査と Hooks 加算仕様**: プラグインは利用者の権限で動作し、コミュニティ掲載＝安全保証ではない。Skills 等は `/plugin-name:skill-name` で衝突しないが、**Hooks は既存設定に重なって両方発火（stack）する**ため、特に `PreToolUse` や `Stop`（外部送信等）を事前確認する。
- **自作 `.claude` のパッケージ化手順**: `<plugin>/` 下に各ディレクトリを複製し、`hooks` だけ `settings.json` から `hooks/hooks.json` へ移行する。その際スクリプトパスは `${CLAUDE_PROJECT_DIR}/.claude/hooks/` から **`${CLAUDE_PLUGIN_ROOT}/hooks/`** へ書き換える（旧パスのままでは他環境で不在となり素通りリスクが生じる）。
- **テスト・重複削除・クラウド併用**: `claude --plugin-dir ./my-plugin` で単発試験し、チーム展開後に元 `.claude` の該当ファイル・`hooks` を削除して二重発火を防ぐ。また自己導入プラグインはクラウドセッションに読み込まれないため、セキュリティ上必須のフックはリポジトリにも残す。

## 練習
現在よく使う自分の設定群を `release-guard-kit` のような 1 プラグインにまとめる想定で、① `.claude-plugin/plugin.json` の `name`（スキル名前空間）、② `${CLAUDE_PLUGIN_ROOT}/hooks/` へ移行すべきスクリプト、③ クラウドセッション用にリポジトリ側へ残す最小安全フックの 3 点を棚卸ししてみてください。

## 動画と出典
- 動画：https://www.youtube.com/watch?v=fj8bpphlJJ0
- 参考：Claude Academy「Plugins」（EN / JA）
  - https://academy.claude.com/courses/claude-code-in-action/plugins
  - https://academy.claude.com/ja/courses/claude-code-in-action/plugins
- 公式公開ガイド：https://code.claude.com/docs/en/plugins/publish#publish-through-your-own-marketplace

公開概要を参考にした独自の日本語解説であり、公式翻訳ではありません。チーム用パッケージ構成（`release-guard-kit`）の図解・練習例は独自制作です。参考講座の映像・音楽は使用していません。ナレーションはAI生成音声です。$content$,
  'https://www.youtube.com/watch?v=fj8bpphlJJ0',
  '2026-11-27',
  0,
  true
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  source_url = EXCLUDED.source_url,
  published_at = EXCLUDED.published_at,
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;
