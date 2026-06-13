# アクセシビリティ QA チェックリスト (CFO 実験グラフ)

CFO 室「表示モード実験 詳細グラフ」(折れ線=標準維持率 / 面=週次イベント)の
スクリーンリーダー読み上げを実機で確認する手順。自動テストは Semantics 契約
(label / value / liveRegion)を検証するが、**実 AT (支援技術) の読み上げ挙動は
実機確認が必要**(自動テストでは代替できない)。

## 自動テストでカバー済み (CI)

- `test/widgets/display_mode_experiment_card_test.dart`
  - 選択点が `Semantics.value` に反映される(折れ線・面の両方)。
  - 選択時に `Semantics.isLiveRegion == true`(変更アナウンスの前提)。
  - 矢印キー(↑→ / ↓←)で選択点が移動し value が更新される。

## 実機チェック (リリース前 / 該当変更時に手動)

本番は Flutter **Web** のため、まず Web + スクリーンリーダーを優先。

### NVDA (Windows / Chrome・Edge) — 必須

1. NVDA 起動 → 本番 <https://my-web-app-b67f4.web.app/> を開く。
2. CFO 室 → 実験カードの「グラフを拡大」を開く。
3. Tab で折れ線グラフにフォーカス → 「標準維持率の推移グラフ。矢印キーで…」と読み上げ。
4. → / ← を押すたびに「06-08 の標準維持率 80 パーセント」等が**都度**読み上げられる。
5. 面グラフでも同様に「初期解決 N 件 切替 M 件」が読み上げられる。

### VoiceOver (macOS / Safari)

1. Cmd+F5 で VoiceOver ON → 本番を開く。
2. VO+矢印でグラフへ移動 → label を読み上げ。
3. 矢印キーで選択移動 → value 変化がアナウンスされる。

### TalkBack (Android / Chrome) — モバイル Web

1. TalkBack ON → 本番を開く。
2. グラフへスワイプフォーカス → label 読み上げ。
3. タップで点を選択 → value がアナウンスされる(キーボード接続時は矢印移動も)。

## 記録

確認したら下表に日付/AT/ブラウザ/結果を追記する。
**自動 (CI widget test)** 行は機械検証済み。**実 AT 行**は読み上げ音声の確認が
必要で自動テストでは代替できないため、実機を持つ担当者が実施して追記する。

| 日付 | AT | ブラウザ | 結果 | 備考 |
|------|----|---------|------|------|
| 2026-06-13 | 自動 (CI widget test) | flutter test | ✅ | `display_mode_experiment_card_test.dart`: 折れ線/面の両方で `Semantics.value` + `flagsCollection.isLiveRegion` を検証。矢印キー移動で value 更新も検証。 |
| (未実施・要実機) | NVDA | Chrome/Edge | - | リリース前に担当者が実施 → 結果追記 |
| (未実施・要実機) | VoiceOver | Safari | - | 同上 |
| (未実施・要実機) | TalkBack | Chrome (Android) | - | 同上 |
