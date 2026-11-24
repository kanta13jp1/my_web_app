# 残響ポンプ室 キャラクター表示

主人公と敵を別々の現在地パネルに表示する。設備保守員と音を追う異形は本作用の生成原画で、参考ゲームの画像は使用しない。従来の一人称企画から、今回の見取り図版で人物を視認できる表現へ段階的に変更した。

- 移動・体力・敵位置・封鎖・脱出で560msのスライドとフェード。常時ループなし。
- 初期管理室は安全、探索先と敵が隣接していれば接近注意。管理室では隣接でも安全を維持。
- 通電中は機械音の区画と耳・矢印で誘導先を表示。封鎖後は格子と鍵、脱出時は主人公成功表示。別区画の敵を同室の遭遇として描かない。
- 画像取得失敗でも代替アイコン、現在地・状態・Semanticsを保持。低減モーション/accessibleNavigationで時間0。2倍文字と320px幅を検証。
- ゲーム規則・敵AI・音声再生・保存方式は変更しない。

## 制作

Built-in image_gen、生成モデル名はツール非公開。原本PNGを無加工で使用、透明RGBA。画像2点合計3,267,168bytes。SHA-256と寸法はassets/echo_pump/CHARACTER_PROVENANCE.json。商用権利・プライバシーの確認状態はpendingで保持し、AI生成だけを権利保証にしない。今回は実装候補とPR、マージ/配信は別段階。

### 主人公の生成プロンプト

Use case: stylized-concept. Asset type: original web survival-horror game character cutout, for Echo Pump Room set in a storm flooded pumping station. One solitary adult female maintenance technician, full body including boots, neutral alert standing pose, 3/4 view facing right. Short practical dark hair, faded slate-blue waterproof work jacket, orange safety harness, rubber boots, tool pouch, small flashlight held pointed down. Realistic painterly cinematic game concept rendering, restrained desaturated teal and amber highlights, strong readable silhouette, visible face and hands, industrial night mood but subject clear. Entire single figure centered with generous transparent margin all around, no environment, genuinely transparent background. No lettering, logos, watermark, firearms, franchise costumes, existing game characters. Original everyday facility worker rather than combat soldier.

### 敵の生成プロンプト

Use case: stylized-concept. Asset type: original web survival-horror creature cutout for Echo Pump Room, storm flooded industrial pumping station. A single full-body tall hunched acoustic stalker, original nonhuman creature, asymmetrical black mineral-and-rubber hide, water-stained layered ribs resembling worn pump bellows, long heavy forearms, bowed head with several small amber sensory slits instead of a human face. Restrained eerie silhouette, non-gory, no blood, no exposed organs. Neutral looming pose in 3/4 view facing left, entire feet visible, generous transparent margins. Cinematic realistic painterly game concept art, desaturated deep blue-gray with muted amber rim light, visible silhouette against genuine transparent background. No environment, text, logo, watermark, weapons, franchise monsters or recognizable existing characters.
