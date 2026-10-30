# 灯守の甲板訓練 — 独立境界

倉庫公開1.0.2270は変更しない。住民素材の納品待ちの間に、独立ブランチで戦闘の状態モデルと描画境界だけを準備する。ゲーム導線・レンダラ・公開はまだ追加していない。

## 一戦

通常攻撃、ガード、必殺技の3操作。予告後にガードすると被弾を防ぎ、反撃と必殺ゲージを得る。攻撃の連打だけでは24秒で敗北する。意図的にガードと攻撃を組み合わせた勝利は45〜90秒を目標に調整し、モデル試験で実測する。初期HPや必殺の効果はこの一戦だけの値で、資材・人口・EXPへ変換しない。

`model.mjs`
は戦闘状態を引数・戻り値で渡す純粋なモジュール。集落モデル、localStorage、Date、Three.jsに依存しない。攻撃の確定はsimulation内のimpact時刻で行い、アニメーション完了では確定しない。二重入力はcooldown/pendingで抑止する。pauseはsimulation時刻を止め、background復帰の大きなdeltaは受け付けない。再開時はホスト側の前フレーム時刻もリセットする。

## 描画・カメラの予定境界

- 遅延読込するentry/controllerが唯一のRAFを所有し、foregroundの最大50ms
  deltaをモデルへ渡す。集落の保存値を受け取らず、開始/勝利/敗北/中断/再挑戦で集落を書き換えない。
- `createTrainingScene({host, signal, onFailure, reducedMotion})` が
  `render(snapshot, events)`, `resize()`, `dispose()`
  を返す予定。描画層からゲーム報酬・戦闘コマンドを送らない。
- 独自の人型mesh/親子関節を `createHero()`
  に隔離し、将来GLBへ交換可能にする。海上の訓練人形、甲板、軽い接地影を用意する。2D
  PNGを3Dモデルの代わりにしない。
- カメラdirectorは通常の安定した斜め追従、命中時の小さな寄り、必殺時の短い切替、勝敗時の引きを扱う。両者・予告を見失わず、回転を抑え、reduced-motion/演出短縮時は固定の安定構図へ戻す。
- WebGL2不可・contextlost・読込失敗時はDOMの理由表示と集落へ戻る操作を残す。背景タブではpause、復帰は明示再開。イベント購読はAbortController、resize
  observer/RAF/audio/GPU資源を終了時に解放する。

## 技術・検証計画

Three.js候補0.186.0は公式registryで存在確認済み（MIT）。導入・同梱は未実施。core/addonsの版を揃えて同一origin配信し、LICENSEを保持する。初期集落では3Dを読み込まない。目標は追加転送2MB以内、3万triangles、60draw
calls、DPR1.5以下、粒子128以下。いずれも今は目標であり測定済みではない。

公開前に実ブラウザの勝利/敗北/中断、旧保存不変、連打、375x667を含むPC/スマホ、拡大文字、reduced-motion、背景復帰、contextloss、20回開始終了の資源解放と実画面を検証する。実機Safariは未検証として区別する。住民版と独立したPR・通常レビュー・全CI・固定base/SHA/allowlist限定公開を通す。

公式出典:
[WebGLRenderer](https://threejs.org/docs/pages/WebGLRenderer)、[cleanup](https://threejs.org/manual/pages/cleanup.html)、[固定候補版registry](https://registry.npmjs.org/three/0.186.0)。
