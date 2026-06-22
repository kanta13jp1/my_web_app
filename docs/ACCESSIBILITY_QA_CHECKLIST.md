# アクセシビリティ QA チェックリスト (CFO 実験グラフ + 資産管理カード)

CFO 室「表示モード実験 詳細グラフ」(折れ線=標準維持率 / 面=週次イベント)の
スクリーンリーダー読み上げを実機で確認する手順。自動テストは Semantics 契約
(label / value / liveRegion)を検証するが、**実 AT (支援技術) の読み上げ挙動は
実機確認が必要**(自動テストでは代替できない)。

## 現在ステータス (2026-06-13 / part 295 時点)

- **自動側 (Semantics 契約) は完了**: CI widget テストが label / value / liveRegion /
  矢印キー移動を継続検証(下記)。
- **残るは実機 AT の音声確認のみ**: NVDA / VoiceOver / TalkBack の実読み上げは
  自動化できず、リポジトリ自動化では実行不可。**実機を持つ担当者**が「実機チェック」
  節の手順で実施し、「記録」節の表へ PASS/FAIL を追記する。

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

## 合否基準 (実機)

各 AT で以下を満たせば **PASS**、1 つでも欠ければ **FAIL**(備考に欠落項目を記す):

- [ ] グラフにフォーカス/移動した瞬間に **label**(「…の推移グラフ。矢印キーで…」)が読み上げられる。
- [ ] 点を選択(矢印 or タップ)するたびに **value**(「06-08 の標準維持率 80 パーセント」等)が**都度**読み上げられる(liveRegion)。
- [ ] 別の点へ移動すると**新しい value** が読み上げられる(前の値のまま無音でない)。
- [ ] 折れ線・面の**両方**で上記が成立する。

## 資産管理カード(将来残高予測 / 予算予実)の a11y — part 298 / #3439 #3447

将来残高予測カード・予算/カテゴリ予実カードの Semantics 確認手順。
🔴 **前提**: Flutter Web は「**アクセシビリティを有効にする(Enable accessibility)**」を
`Enter`/`Space` で**押すまでセマンティクスを一切出さない**(読み上げられるだけでは未有効)。
まず有効化してから矢印キーで確認する。**NVDA はクリックでなく矢印/Tab で移動した要素を読む**。

### 確認手順(NVDA / Chrome・Edge)

1. NVDA 起動 → 本番を開く → `Ctrl+Home` → `Tab` 1回 →「Enable accessibility ボタン」を
   **`Enter` で有効化**(押さないと以降すべて無音)。
2. `Tab`/`↓` で将来残高予測カードへ。期間チップ「3ヶ月 / 6ヶ月 / 12ヶ月」がボタンとして読まれる。
3. `↓` でグラフ本体を通過 →「**将来残高予測グラフ。今後Nヶ月の月末残高見込み。… 最小見込み残高は ¥X。…**」
   (`image: true` = role=img の alt として全文)。
4. `↓` で警告 →「**M/D 頃に残高が不足する見込みです。回避には ¥X の追加資金が必要です。**」(liveRegion)。
   チップ切替で**フォーカス移動なしに**自動アナウンスされること。
5. 予算/カテゴリ予実カード: 各行が「**<カテゴリ> ¥実績 / ¥予算 <超過/残り>**」と**1まとまり**で
   読まれる(MergeSemantics)。超過時の合計が liveRegion で読まれる。

### 合否基準(新カード)

- [ ] グラフが role=img として「将来残高予測グラフ。<要約全文>」と読まれる(無音でない)。
- [ ] ショート/安全余裕割れ警告が出現/変化時に自動読み上げ(liveRegion)。
- [ ] 期間チップ・「支払日を見直す」がボタンとして読まれ操作できる。
- [ ] 予算予実の各行が断片化せず 1 文で読まれ、超過合計が自動読み上げ。

### 自動テスト(CI)

- `test/widgets/asset_cashflow_forecast_card_test.dart`: チャートの `image == true` + label prefix、
  警告の `liveRegion` + label を `find.byWidgetPredicate` で検証。
- `test/widgets/asset_category_budget_card_test.dart`: 超過合計の `liveRegion`、行の `MergeSemantics` を検証。

## 資産管理カード(定期固定費 / 定期取引の自動検出)の a11y — part 301 / #3475 #3478 #3479

定期固定費カード(`RecurringFixedCostCard`)と定期取引の自動検出カード
(`AssetRecurringTransactionSuggestionCard`)の Semantics 確認手順。両カードとも各行の
**情報(名称・周期・金額・引落元)を `MergeSemantics` で 1 ノードに集約**し、**操作ボタンは
集約の外**に置いて各々が独立した操作ノードになるよう実装している。

### 確認手順(NVDA / Chrome・Edge / 前提は上記「Enable accessibility」と同じ)

1. `Tab`/`↓` で定期固定費カードへ。各行が「**<名称>、毎月/隔月(偶数月)N日 / ¥金額 / 振替元: X**」と
   1 まとまりで読まれる。続けて「**<名称> を編集 ボタン**」「**<名称> を削除 ボタン**」が個別に読まれ操作できる。
2. `↓` で定期取引の自動検出カードへ。各候補が「**<名称>、毎月/隔月(偶数月)N日頃、約¥金額、確度 高/中、
   直近Mヶ月分を検出**」と 1 文で読まれる。続けて「**無視 ボタン**」「**固定費に登録 ボタン**」が個別に読まれる。

### VoiceOver (macOS / Safari) / TalkBack (Android / Chrome)

1. VoiceOver: VO+矢印 / TalkBack: スワイプ で各行へ移動 → 上記の集約ラベルが 1 まとまりで読まれる。
2. 操作ボタン(編集/削除 / 無視/固定費に登録)へ移動 → 名称を含む文脈付きラベルが読まれ、ダブルタップで実行。

### 合否基準(part 301 カード)

- [ ] 各行の名称 + 内訳が断片化せず 1 文で読まれる(MergeSemantics)。
- [ ] 操作ボタンが「<名称> を編集/削除」「無視 / 固定費に登録」と**個別に**読まれ操作できる
      (情報の集約ノードに飲み込まれていない)。
- [ ] 検出カードの確度バッジ(高/中)が行ラベルに含まれて読まれる。

### 自動テスト(CI)

- `test/widgets/recurring_fixed_cost_card_test.dart`: 行の集約 `Semantics`(label に名称 + ¥金額)と
  文脈付きツールチップ(`<名称> を編集/削除`)を検証。
- `test/widgets/asset_recurring_transaction_suggestion_card_test.dart`: 行の集約 `Semantics`(label に
  名称 + 確度)、無視/登録ボタンのコールバックを検証。

## 記録

確認したら下表に日付/AT/ブラウザ/結果を追記する。実機担当者は下の
**記入テンプレート**を 1 行コピーして埋める(PASS/FAIL + 欠落項目)。

```text
| YYYY-MM-DD | <NVDA|VoiceOver|TalkBack> | <ブラウザ> | <PASS|FAIL> | <欠落項目 or 所見> |
```

**自動 (CI widget test)** 行は機械検証済み。**実 AT 行**は読み上げ音声の確認が
必要で自動テストでは代替できないため、実機を持つ担当者が実施して追記する。

| 日付 | AT | ブラウザ | 結果 | 備考 |
|------|----|---------|------|------|
| 2026-06-13 | 自動 (CI widget test) | flutter test | ✅ | `display_mode_experiment_card_test.dart`: 折れ線/面の両方で `Semantics.value` + `flagsCollection.isLiveRegion` を検証。矢印キー移動で value 更新も検証。 |
| 2026-06-13 | 自動 (再検証 / part 293) | flutter test | ✅ | フル test スイートで上記 a11y 契約が引き続き green を確認(回帰なし)。**実 AT の音声確認はこの自動検証では代替不可**のため下記実機行は別途必要。 |
| 2026-06-16 | NVDA (実機) | Chrome (build 4526) | ✅ PASS | **将来残高予測カード (#3447)**: グラフが role=img で「将来残高予測グラフ。今後3ヶ月…最小見込み残高は−¥579,277。6/27頃に残高不足の見込み。グラフィック」+ 警告が liveRegion で「6/27 頃に残高が不足する見込みです。回避には ¥579,277…」+「支払日を見直す(マネーカレンダー) ボタン」を実機読み上げ確認。※「Enable accessibility」を Enter で有効化 → 矢印移動で確認(クリックでは無音)。 |
| 2026-06-19 | 自動 (CI widget test / part 301) | flutter test | ✅ | **定期固定費 / 定期取引検出カード**: 行の集約 `Semantics`(名称 + ¥金額 / 名称 + 確度)+ 文脈付きツールチップ(`<名称> を編集/削除`)+ 無視/登録ボタンを検証。実 AT 音声は下記実機行で別途確認。 |
| (未実施・要実機) | NVDA | Chrome/Edge | - | リリース前に担当者が実施 → 結果追記。手順は本書「実機チェック」節。 |
| (未実施・要実機) | VoiceOver | Safari | - | 同上 |
| (未実施・要実機) | TalkBack | Chrome (Android) | - | 同上 |
