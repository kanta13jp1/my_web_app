# 灯守の甲板訓練 — 独立3D試作

本番の住民版1.0.2271は変更しない。この変更は開発・検証・Draft
PRまで。新3D版のmainマージと公開は未許可。

## 遊びと境界

約45〜90秒の一対一。攻撃 / ガード /
灯の一閃の3操作。予兆中にガードして被弾を防ぎ、反撃と必殺ゲージを得る。早すぎるガードは切れ、攻撃連打だけでは敗北する。先行の純粋モデル9テストを維持。結果はsimulationのimpact時刻で確定し、描画や演出完了に依存しない。

訓練は一時sessionのみ。集落model/save/経済のimportもlocalStorage書込みもない。人口7人など旧保存から入り直せる。勝敗・中断・再挑戦・reloadで資材/人口/EXP/建物を変更しない。集落へ戻れば農園の既存通常時間処理が続く。

## 表現と操作

Three.jsの実メッシュ/親子関節で制作した独自の灯守（顔・髪・コート・スカーフ・ブーツ・真鍮の道具）と貝殻浮標の訓練人形、木の甲板。静的部品をjoint内でmaterial別にbatchして描画回数を抑える。2D
PNG/billboardや外部モデルは使わない。createHero境界を将来のGLB差替え点にする。

待機呼吸、踏込み、腕/道具の攻撃、ガード、被弾、勝利姿勢。必殺は短い寄り/追従/引きと海色の輪・光の軌跡・粒子。敵の予兆はDOM文字とパドルの構えで示し、全画面点滅をしない。reduced-motionと任意の短縮ではカメラ/水面/粒子等を抑える。背景はpauseし、復帰後は明示再開。音は初期OFF、明示ON時だけ短い生成音。DOMボタン/キーボード/文字予告/長い予告補助を保持。

WebGL2/素材失敗やcontext
lossは理由と再読込/再挑戦/集落への戻り口を表示。低い高さと拡大文字では可読性と操作到達を優先してページが伸びる。

## 配信とライセンス

公式npm
three0.186.0を正確に固定し、lockの公式integrityで検証する。coreとrendererは同版。`npm ci --ignore-scripts`後に`node scripts/build_sea_shelter_arena.mjs`を実行し、vendorの同一origin
module2個とMIT
LICENSEを生成する。生成物をGitへ重複コミットしない。訓練開始操作までengineを読み込まず、集落の初期loadにも追加しない。

独立Webビルドでは上記生成をFlutter
buildの前に実行する。既にbuild済みなら同scriptへ`build/web`を渡して出力できる。将来の限定公開ではこの生成とvendor/ライセンス存在・版・容量guardをdeploy前に組み込む必要がある。本PRで自動配信を有効にせず、公開workflowや権限を変更しない。

目標：初期追加3D転送2MB未満、三角形3万以下、drawcalls60以下、DPR最大1.5、粒子最大128。現時点は目標で、実測はCI証跡へ追記する。実機iPhone
Safariの性能は保証しない。

## 検証

純粋model9件：連打/早すぎるguard/成功guard/必殺一回消費/勝敗/45〜90秒戦略/pause/不正delta/stop/tie。ユーザーI/Oは3ケース：旧7人保存→lazy入場→guard/必殺勝利→再挑戦/戻る、初回→敗北/pause/背景/時計変化/7viewport/拡大文字/reload、engine失敗→明示reload復旧→実WebGL
contextloss→再挑戦/戻る。別component
contractで実Three20生成破棄とGPUgeometry/texture/observer/canvas/global
listenerを計測。集落の既存20model/32browser/Flutter導線とlifecycleも回帰確認する。

現在：軽量local
model9/9とformat/lint成功。実ブラウザ・GPU・転送・画像監査はCI待ち。Designプラグイン/実機Safari/ATは未実施。

公式出典：[WebGLRenderer](https://threejs.org/docs/pages/WebGLRenderer.html)、[cleanup](https://threejs.org/manual/pages/cleanup.html)、[固定版registry](https://registry.npmjs.org/three/0.186.0)。WebGLRendererはWebGL2を必要とする。Unity6.3のiOS対応を否定する判断ではなく、今回の軽い独立Web画面にThreeを選択した。

初回CIでr186にmin配布ファイルがないことを検出した。公式tarballの実ファイル一覧とintegrityを再確認し、固定esbuild-wasm0.28.2（公式npm/MIT、build専用）でcore/rendererのESMをminifyする。LICENSEを保持し同一originへ出力。最初の失敗は未実行の描画試験の代わりに成功扱いしない。
