# 支出分類の比較ノート

## 対象と状態

Issue #5505。既存の12カテゴリを使い、合成メモ14件を各2回、ルール辞書と非公式BERT/NLIエンジンで比較する。実データ・APIキーをページへ送らない。表示対象は保存済みの実測であり、利用者の任意メモをライブ推論する機能ではない。候補の自動適用・記帳・認証設定の変更はない。

実モデル結果は `web/labs/expense-comparison/results.json` に検証後に収録する。存在しなければ測定未完了。ページ・記事はレビュー待ちであり、main・本番反映は別途確認する。

## 使い方

1. 配信後は `/labs/expense-comparison/index.html` を開く（合成データの閲覧にログイン不要）。
2. 「メモを選ぶ」で合成サンプルを選ぶ。
3. 辞書とBERTの候補、要確認表示、検証用の参照カテゴリを比較する。
4. 測定回を切り替え、未校正スコアとHTTP往復時間を確認する。
5. 「測定条件と確認できていないこと」を開き、元データ・実行記録を参照する。自分の明細は資産管理画面で別途確認する。

## 一次資料と設計判断

- BERT実装: [typed-decision-bert](https://github.com/hawkymisc/typed-decision-bert/tree/5a5af4ebd99c8b7db9f227d4d46216d668c2cc8f)。MIT。非公式PoCで、学習済みJevBERTではなく公開NLIモデルを使用する。API形式の互換と判断品質・確率校正を分ける。
- 重み: `MoritzLaurer/bge-m3-zeroshot-v2.0`、revision `9abf1c8aaeb82a2447809c20753ed0b106b76652`。上流manifestのファイルSHA-256をfetch-modelで検証する。
- Jwenv: [固定jev.js](https://huggingface.co/spaces/kishida/jwenv-demo/blob/8263b814fde5ca11e47718a7ac82945639c02d8d/dist/qwen3-engine/src/jev.js)。A〜Hの8選択肢が上限で12カテゴリを拒否する。今回はカテゴリ統合や複数段階分類で測定条件を変えず未測定とした。GPU動作・オフライン・速度は検証していない。
- 共有図の「forward 1回」はJwenvの候補読み出し説明であり、独自Jev本体の非公開実装を立証しない。出力層の削減をモデル全体の速度倍率に置き換えない。

## 測定契約

`fixtures.json` は固定版 `JevInstantClassifierService` の12カテゴリ・順序付き辞書を抽出したもの。参照元SHAとソースハッシュを保存する。ルール候補は同じ先頭一致方式で再生し、Dart実行時間や正答確率とは呼ばない。合成14件のうち3件には正解を置かない。データは学習に使わず、結果を見てプロンプトや参照ラベルを変更しない。

実モデル呼出しはGitHub Ubuntu CPU・2スレッド・127.0.0.1で実行。モデル読込後の初回を含め全28回を保存し、再試行・外れ値除外はしない。HTTP JSON往復はモデルロードを除き、前処理・待ち行列・推論・JSON変換を含む。クラウドJevやWebGPUの速度とは直接比較できない。

モデルID、候補集合、有限性、範囲、分布合計を検証。失敗は候補なしとして保持し、全28回有効でなければ測定jobを失敗させる。`confidence`は未校正であり、既存Jev用の閾値を移植しない。

## 再現と検証

`.github/workflows/expense-bert-comparison.yml` は結果未収録時に固定上流・重みを取得し、HTTP実測とブラウザ検証を実行する。結果収録後は入力と測定コードのSHA-256一致を確認し、不用意な再ダウンロード・再推論を避ける。

契約: `python -B -m unittest discover -s scripts/expense_comparison -p 'test_*.py' -v`。
ブラウザ: `python test/e2e/expense_comparison.py`。PC/390pxで正常候補、曖昧サンプル、測定回切替、503・不正JSON契約、回復を検証。保存済み結果がない場合はモック応答であり画面証拠を生成しない。実測結果のある場合だけスクリーンショットを保存する。

ローカルモデルの新規取得は約1.1GB以上と実行メモリが必要。今回のWindows端末では資源不足のためクラウドのみ使用する。測定サービスはloopbackに限定し、job終了時に所有PIDを終了する。
