# LP登録率改善: 10仮説の検証計画

## 目的

初回訪問者が価値を理解し、登録前に1件試し、提案を保存するために登録を完了するまでの離脱を減らす。
最終指標は `signup_complete / view`、先行指標は `hero_cta`、`trial`、`save_cta`、`signup_submit` とする。

## 実験方式

- 訪問者を10仮説のいずれかと `control` / `treatment` に安定割当する。
- `treatment` は10施策をすべて有効化する。
- `control` は割り当てられた仮説の施策だけを無効化し、残り9施策は有効化する。
- 割当はSharedPreferencesへ保存し、再訪時にも同じ条件を表示する。
- QAでは `?lp_hypothesis=h01&lp_variant=control` のように条件を固定できる。QA指定は保存済み割当を上書きしない。

## 仮説一覧

| ID | 仮説 | Treatment | Control | 主な先行指標 | 実装検証 |
| --- | --- | --- | --- | --- | --- |
| H01 | 得られる成果を先に伝えるとCTA率が上がる | 「仕事・学習・お金の次の1件をAIが1分で決める」 | 統合機能中心の説明 | `hero_cta / view` | 自動テスト済み |
| H02 | 目的を選べると体験開始率が上がる | 仕事・学習・お金のセグメント | 目的選択なし | `intent`, `trial / view` | 自動テスト済み |
| H03 | 登録前に価値を体験すると登録開始率が上がる | AI体験を登録より先に表示 | 登録を体験より先に表示 | `signup_submit / view` | 表示順テスト済み |
| H04 | Googleを共通の1タップ主導線にし、メール入力を代替へ下げると認証完了率が上がる | Google主導線 + Magic Link代替 + パスワード折りたたみ | Google主導線 + Magic Link代替 + パスワード表示 | `signup_complete / signup_submit` | UI・復旧・保留データの自動テスト対象 |
| H05 | 料金不安を先に解消するとCTA率が上がる | 無料コア・カード不要・いつでも停止 | ヒーローに保証表示なし | `hero_cta / view` | 自動テスト済み |
| H06 | 利用後の具体像を見せると体験率が上がる | 入力→AI提案→翌日再開の実例 | 実例セクションなし | `trial / view` | 自動テスト済み |
| H07 | 実数の証拠をCTA近くに置くと登録率が上がる | 登録者・公開メモ・実装数を上段表示 | 同じ実数を後段表示 | `signup_submit / view` | 表示位置テスト済み |
| H08 | データ利用への不安を解消すると完了率が上がる | メール非公開・Stripe管理・Privacy導線 | 保証表示なし | `signup_complete / signup_submit` | 自動テスト済み |
| H09 | モバイル固定CTAで登録機会損失が減る | 720px未満で固定CTA | 固定CTAなし | `mobile_signup_submit / mobile_view` | 390pxテスト済み |
| H10 | 登録後に残る価値を明示すると保存意欲が上がる | 提案・履歴・明日の続きを明示 | 一般的な保存文言 | `save_cta / trial` | 自動テスト済み |

## 計測イベント

イベントキーは次の形式で `app_analytics.source_details` に日次集計する。

```text
lp_exp_h01_treatment_view
lp_exp_h01_treatment_mobile_view
lp_exp_h01_treatment_hero_cta
lp_exp_h01_treatment_trial
lp_exp_h01_treatment_signup_submit
lp_exp_h01_treatment_mobile_signup_submit
lp_exp_h01_treatment_signup_complete
```

利用できる主要ステージは `view`, `mobile_view`, `hero_cta`, `intent`, `trial`, `save_cta`, `signup_submit`, `mobile_signup_submit`, `signup_complete`, `sticky_cta`。
イベントはブラウザ単位のランダムUUIDと仮説・variant・stageの組み合わせで重複排除し、メール、IP、入力文、回答文は保存しない。

## 効果判定

実装済みであることと、登録率が改善したことは分けて扱う。

1. 各仮説のcontrol/treatmentで100ユニーク表示以上を集める。
2. 各群の主指標の分母が20件以上、両群合計の主指標成功数が10件以上になるまでは結論を保留する。
3. H01/H05は `hero_cta / view`、H02/H06は `trial / view`、H03/H04/H07は `signup_submit / view`、H08は `non-anonymous signup_complete / signup_submit`、H09は `mobile_signup_submit / mobile_view`、H10は `save_cta / trial` で判定する。
4. 主指標で20%以上の相対改善があり、control/treatmentのWilson 95%区間が分離した場合だけ勝者とする。分子が分母を超える矛盾値は `invalid_funnel_data` とし、率を補正・捏造しない。
5. 認証エラー率やページ表示速度が20%以上悪化した施策は、登録率が高くても停止する。
6. サンプル不足の間は先行指標を監視するが、効果実証済みとは表現しない。
7. 2026-08-19の認証基盤変更より前のH04データは、Magic Link主導線かつカスタムSMTP未設定という交絡を含む。変更前後を同じ母集団として勝敗判定せず、Google主導線の本番デプロイ時刻以後を新しい観測期間とする。

## 今回確認したこと

- 10仮説が重複なく定義されている。
- 再訪時の割当が維持される。
- 対照群は割当対象の1施策だけを無効化する。
- 全ファネルイベントキーが許可形式になる。
- 改善版の全10機構が同時に描画される。
- 10種類の対照条件が画面へ反映される。
- 390px幅で固定CTAが表示され、クリックイベントが記録される。
- 390px幅で `mobile_view` と `mobile_signup_submit` が匿名・重複排除で記録される。
- 10仮説のレポートがそれぞれ固有の主要指標を参照する。
- 主指標の分母不足やファネル矛盾時に勝者を宣言しない。
- 既存LP後段のモバイル横方向オーバーフローを解消した。
- SupabaseのGoogle providerが有効で、Site URLとRedirect URLsが本番ドメインを許可していることを管理画面で確認した。
- Supabaseのcustom SMTPが無効であることを確認した。Magic Link主導線の登録完了率を評価できる状態ではないため、Googleを共通の主導線、メールを復旧可能な代替導線へ変更する。
- Magic Linkは送信試行、成功、失敗分類、Google OAuth開始をPIIなしの日次カウンターで分離する。メールアドレス、プロバイダーの生エラー本文、入力内容は保存しない。
- Google認証へ遷移する場合も、登録前AI体験の結果をブラウザローカルに24時間だけ保持し、同じブラウザで認証済みユーザーが戻った場合だけ復元する。

実ユーザーの登録率改善は、デプロイ後に上記サンプル条件を満たしてから判定する。

## 本番観測と次の仮説

2026-08-19 JST 時点のPIIなし本番集計は、LP表示692、体験開始10、保存CTA 1、登録送信2、verified signup 0だった。PR #4599で、AI失敗を成功表示しないこと、trial成功時だけ保存CTAを出すこと、デスクトップ/モバイルでCTAを画面内へ移動することを本番反映した。それでも登録完了が0のため、現在の最狭ボトルネックは保存・登録送信から認証完了への遷移である。

認証設定監査では、Google OAuthと本番Redirect URLは有効、custom SMTPは無効だった。このためH04の旧前提「Magic Linkを主導線」はインフラ条件を満たしておらず、効果なしとは判定できない。Google OAuthを共通baselineの主導線へ変更し、Magic Link失敗時には画面内エラーとGoogle復旧CTAを残す。10仮説はいずれも登録完了と必要サンプルが不足しているため、引き続き `insufficient_data` とする。

この観測からH11「操作前に入力と回答の実例を見せ、クリック直後にローカル提案を返すと、価値の不確実性と待ち時間が減って体験開始率が上がる」を追加する。静的な回答例の表示だけでは `trial` を計上せず、訪問者が例または入力の実行ボタンを押した時だけ計上する。目標はデプロイ後100表示以上を集めた時点で `trial / view >= 3%` とし、それまでは効果実証済みと表現しない。

また、従来の `source_details` は匿名クライアントがread-modify-writeしていたため、RLS拒否と同時更新の上書きが起こり得た。H11以降はSecurity Definer RPCでJSONBキーを原子的に加算し、表示改善と計測信頼性を同時に検証する。
