-- daily-development (Claude Code, 2026-09-08): ユーザーマニュアルのインポート手順を実装コードと突き合わせて修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ユーザーマニュアルのインポート手順を実装と突き合わせ修正',
  'user_manual_page.dart のインポート手順6件のうち4件が import_page.dart の実装（sourceType ごとの許可拡張子・列名マッチング）と一致せず実行不可能だった。Notion は ZIP でなく解凍後の .csv を選ぶよう修正、MoneyForward は日本語ヘッダー（内容・メモ等）を認識する xlsx インポート経路に置き換え、X (Twitter) と GitHub は未対応拡張子のため Markdown 手動変換の代替手順に修正。特にMoneyForwardは列不一致により取り込み0件の無言失敗になっていた。コード変更なし・flutter analyze / 既存widget testで確認。',
  '2026-09-08'
)
ON CONFLICT DO NOTHING;
