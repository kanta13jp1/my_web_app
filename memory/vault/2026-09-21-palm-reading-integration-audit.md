---
title: "手相AI占い 実装保全・統合監査 2026-09-21"
type: implementation-audit
status: pending-review
date: 2026-09-21
tags: ["palm-reading", "flutter", "supabase", "rls", "privacy", "integration"]
related: ["[[OBSIDIAN_INGEST_PIPELINE]]"]
---

# 手相AI占い 実装保全・統合監査

## 結論

手相AI占いの未保存実装は `codex/palm-reading-history-20260823` の隔離作業ツリーで保全した。2026-09-21 の棚卸し時点で `main`、同名のリモートブランチ、手相専用PRには未統合だった。古い `codex/palm-reading-history-20260822` は重複実装と `supabase/.temp` 差分を含むため変更せず残した。

既存5ファイルには改行コード変換による約1万行の見かけ差分があった。手相機能の実質差分だけを抽出して再適用し、他機能の行をコミット対象から除外した。

## 実装範囲

- Flutter: 左右の手の選択、撮影ガイド、カメラ/写真選択、明示同意、鑑定結果、履歴、同じ手の前回比較、削除、ログイン導線、レスポンシブ表示。
- Edge Function: `palm_reading.analyze` / `palm_reading.delete`、認証、UUIDによる冪等化、MIMEマジック検証、オフライン保護、利用量/予算ゲート、安全な構造化出力。
- Database/Storage: 所有者限定履歴、非公開画像バケット、4 MB上限、JPEG/PNG/WebP限定、本人だけのSELECT、サービスロールだけの書き込み。
- 安全表示: 手相を娯楽として明示し、病気・障害・妊娠・寿命・死期・自殺などの断定を出力後にも除外する。

## 証拠

### 2026-08-23 に完了済みの隔離検証

- 対象Flutterテスト: 32件成功。
- `flutter analyze --no-pub`: 問題なし。
- Deno: 7件成功、lint/check成功。
- 隔離Postgres: 新規マイグレーション適用成功、DB lint/advisors問題なし。
- SQL契約テスト: 行履歴と画像の所有者分離、クライアント読み取り専用、サービスロール書き込み、非公開4 MBバケット、索引、所有者パス制約を確認。
- 実Auth/Data API/Storage検証: 所有者RLS、アップロード、本人限定署名URL、後片付け成功。

これらは過去の隔離環境で得た証拠であり、現在の `main` とのマージ結果の証拠ではない。現行統合はGitHub Actionsのマージ参照で再検証する。

### 2026-09-21 の現行監査

- 最新 `origin/main` (`032bd4565`) へリベースし、現行のfail-closed AI action registryへ `palm_reading.analyze` / `palm_reading.delete` を認証必須として登録した。
- ホームの機能カタログに加え、`feature_releases`へ `/palm-reading`を重複防止付きで登録し、「最近追加された機能」から遷移できるようにした。
- 未公開マイグレーションは現在の履歴順に合わせて `20260921041500_create_palm_reading_history.sql` へ改名した。
- Supabaseの2026-04-28破壊的変更を確認。新規 `public` テーブルはData API利用のため明示的GRANTが必要になる。本実装は `authenticated` にSELECT、`service_role` に必要権限を同一マイグレーションで明示している。
- ローカル資源は空きディスク1.63 GiB、空きRAM0.43 GiB、RAM使用97%でクラウド必須。Flutter/Deno/Docker/ブラウザ検証はローカルで再実行しない。
- 実写真の外部AI送信、課金、本番公開は実施していない。

## 本当に残る条件

1. PRのGitHub Actionsが現行 `main` とのマージ参照で成功すること。
2. 認証、Database、RLS、Storage、Edge Functionの差分を人がレビューし承認すること。
3. マージと本番公開は別承認とし、この監査では実行しないこと。
4. 本番利用前に、テスト画像だけで同意・鑑定・履歴・同じ手の比較・削除をステージング確認すること。

## 用語集

- **RLS (Row Level Security)**: データベース行ごとに「誰が読めるか」を制限する仕組み。本実装では本人の履歴だけを読める。
- **非公開バケット**: URLを知るだけでは画像を取得できないStorage領域。
- **署名URL**: 短時間だけ有効な画像閲覧URL。履歴表示時に本人向けに生成する。
- **Edge Function**: クライアントに秘密鍵を置かず、認証・AI呼び出し・保存を仲介するサーバー処理。
- **冪等性**: 同じ要求を再送しても同じ結果を返し、二重課金や二重保存を避ける性質。
- **MIMEマジック検証**: 拡張子だけでなくファイル先頭バイトを調べ、JPEG/PNG/WebPの実体を確認すること。
- **同じ手の比較**: 左手は左手、右手は右手の直前データだけと比較する方式。
- **マージ参照**: PRの変更を最新 `main` に仮想的に重ねたGitHub上の検証対象。
- **限定コミット**: この機能と監査記録だけを明示的にステージし、他タスクの差分を含めないコミット。

## 参照

- Supabase changelog: https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically

<!-- PR番号とクラウドCI結果は作成後に追記する。 -->
