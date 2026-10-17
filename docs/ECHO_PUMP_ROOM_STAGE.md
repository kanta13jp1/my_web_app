# 管理室の探索・第三段階

管理室の安全な経路で主人公がメモと扉へ歩きます。4コマの透明スプライトと接地タイミング2回の既存step.wavを使い、設備を横切らない折れ線経路を補間します。全景/設備寄りは同じ2D場面の倍率切替です。

室内の歩行・閲覧ではゲームのターンと敵位置を変更しません。扉の確認で「扉を開けて進む」を選んだときだけ、既存の区画移動を1回実行します。従来の区画移動ボタンも使えます。保守メモは2ページの図解です。非表示・画面破棄時は歩行を中止し、低減モーションは即時移動・歩行SEなし。音声のON/OFFと音量は既存設定に従います。

これは自由移動や3Dの完成版ではなく、管理室だけの決まった目的地への接近です。他室は先行PRの人物・敵の状態表示を維持します。敵のリアルタイム追跡、所持品、保存、実動画は次段階です。

## 素材の来歴

image_genで独自の保守員原画(character_technician.png、原本20261017-101722-2)を参照し2x2歩行シートを生成、その後同じツールで歩幅と余白を調整。原作の画像や録画は素材に含めていません。モデル名はツールが公開していないため未記録。商用権利とプライバシー確認はpendingです。

初稿プロンプト要旨: same original female night-shift maintenance technician, transparent 2x2 sprite sheet, four walking poses, charcoal workwear, orange harness, work gloves, flashlight, full body, consistent scale and ground line, no text/background.

修正プロンプト: Edit this 2x2 animation sheet. Keep same woman/costume/style/four equal square cells transparent. Smaller figures 78% own cell height with 10% margins, preserve ground line. Top-left contact left foot forward; top-right passing compact feet under hips; bottom-left opposite contact right foot forward; bottom-right opposite passing other knee raised. Do not use four wide-stride poses, no labels/borders/environment.

原画は変更せず保存し、アプリでは描画時に等分セルを切り出します。生成イラストのため各ポーズの精密な骨格連続性は今後の改善対象です。


## 初回歩行の画像先読み

管理室の依存関係が確定した時点でcharacter_walk.pngをprecacheImageで読み込み・デコードする。完了前に歩き始めても静止姿勢の主人公を移動経路上に残し、準備完了後に4コマへ切り替える。読み込み失敗時も主人公と調べる操作を維持する。遅れて完了した処理は破棄済みStateや変更後のAssetBundleへ反映しない。ターン・足音・移動時間は変更しない。

Widget試験で先読み開始・遅延中の表示・デコード後の切替・失敗後の進行・画面離脱を確認する。ブラウザーでは歩行画像だけの取得を遅らせ、初回の代替姿勢と読込後の歩行をPC/mobileで撮影する。
