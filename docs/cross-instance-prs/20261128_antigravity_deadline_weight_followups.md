---
date: 2026-11-28
from: Claude Code (WEB版 cloud session)
to: Antigravity (L1) / repository owner
status: handoff
priority: medium
---

# /deadline-weight「締め切りの重さ」— 後続作業の引き継ぎ

WEB版クラウドセッションを終了するにあたり、未了のぶんを Antigravity (L1) へ引き継ぐ。
本体の実装は完了・CI グリーン・main へマージ済み。残るのは **本番反映** と **未実行の検証** の 2 系統。

## 完了済み (このセッション)

- PR: <https://github.com/kanta13jp1/my_web_app/pull/6496>
- Branch: `claude/feature-addition-szmu6a`
- 追加されたもの:
  - `supabase/migrations/20261128093000_create_deadline_weight_tables.sql`
    — `deadline_weight_items` / `deadline_weight_settings` (どちらも RLS で `auth.uid() = user_id` に閉じる / `anon` 権限なし)
  - `lib/models/deadline_weight_models.dart` — `(items, settings, now)` を取る純粋関数層
  - `lib/services/deadline_weight_service.dart` / `lib/pages/deadline_weight_page.dart`
  - `lib/data/home_tool_catalog.dart` / `lib/main.dart` / `test/routes/app_route_names.dart` へ route + 導線登録
  - `test/services/deadline_weight_test.dart` — 純粋ロジック単体 + 画面 widget 4 ケース
- 設計判断は実装前に `/grill-me` で 8 問確定済み (核 / データ源 / 体感化の軸 / 可処分時間の決め方 / 置き場所 / 必要時間 / 不足時の振る舞い / 検証範囲)。
- CI: 39 チェック 全グリーン。`flutter analyze` 0 件。

## 引き継ぎ 1: Supabase 本番への migration 適用 (必須 / 未了)

`20261128093000_create_deadline_weight_tables.sql` が本番に適用されるまで、画面は開いても
テーブルが無く読み書きに失敗する。適用後、ログイン状態で `/#/deadline-weight` を開き、

1. 締め切りを 1 件追加できる
2. 曜日ごとの可処分時間を保存できる
3. 保存後に「手を動かせるのは あと◯時間」が更新される

ことを確認する。既存テーブル・既存カラムへの変更は含まれていないため、ロールバックは
新規 2 テーブルの drop で足りる。

## 引き継ぎ 2: デザイン / アクセシビリティ監査 (未実行)

`docs/DESIGN_ACCESSIBILITY_AUDIT.md` の Audit Procedure が未実行。クラウドセッションには
Design plugin も実機ブラウザも無く、スクリーンショットを撮れなかったため。
PR 本文には `Design-Plugin-Status: not-run` と理由を明記してあり、**実行していない監査を
pass とは書いていない**。このゲートは advisory なのでマージは止まっていない。

確認してほしい点:

- 判定を色 (緑 / 琥珀 / 橙 / グレー) で出しているが、テキストラベル併記で色依存を避けられているか
- `LinearProgressIndicator` と背景 (`DesignTokens.surface3`) のコントラスト
- 「打てる手」3 択 (`OutlinedButton` の `Wrap`) のフォーカス順とタップ領域
- 曜日スライダー (`Slider`, max=1440, divisions=48) のキーボード操作とラベル読み上げ

実施したら PR #6496 本文の `## Design Accessibility Audit` セクションを
`python scripts/check_design_accessibility_audit.py --emit-snippet` の形式で実測値に置き換える。

## 引き継ぎ 3: 既存データからの取り込み (スコープ外として後回し)

`/grill-me` で「専用テーブルに自分で登録」を選び、既存データ連携は後続に回した。
候補は `life_goals.target_date` と `wbs_tasks(instance='user').end_date`。

注意点:

- 純粋関数層 (`lib/models/deadline_weight_models.dart`) は変更せず、取り込みは service / page 側で完結させる
- 既存データに `required_minutes` 相当が無いため、取り込み時にユーザーへ聞く必要がある
- 重複取り込みの防止方法 (取り込み元 id を持つか等) は実装前に要相談

## 設計上の注意 (レビュー時に見てほしい)

- **当日分は経過時間で按分する**。12:00 に開けばその日の設定の半分、21:00 なら 1/8。
  夜に見ると残りが少なく出るのは意図した仕様 (体感に合わせるため) で、バグではない。
- **判定しきい値 1.5 倍**(「間に合う」と「ギリギリ」の境界) は経験則であり実測ではない。
- 遠すぎる期日で回り続けないよう `maxLookaheadDays = 730` で打ち切る。それより先の期日は
  可処分時間を過小に見積もる。
- 日付の加算は `DateTime(y, m, d + 1)` で行い、`Duration(days: 1)` の DST ずれを避けている。

## このセッションからは実行できなかったこと

- Antigravity の直接操作 (Computer Use ツールがクラウドセッションに提供されていない)
- Remote Control 経由のフォルダ接続 (`kanta` の 3 フォルダはいずれも
  `not_available` = そのコンピュータがクラウドセッションに提供していない状態)
- `flutter analyze` / `flutter test` のローカル実行 (コンテナに Flutter SDK なし / 検証は CI のみ)
