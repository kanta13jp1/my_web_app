-- PS#4 S67: jp_strength/jp_weakness 補完 Batch 6 (最終・19社)
-- 対象: ov≤4 LOW (物流・エンタメ・Fintech・不動産・旅行・モビリティ)

UPDATE competitors SET
  jp_strength = 'C2C ファッションリセール 世界 No.1 / 日本でも ZOZOTOWN 系ユーザー層に普及 / ブランド品二次流通の信頼性 / $2B IPO',
  jp_weakness = 'EC フリマ特化 / 個人財務・AI・健康・習慣管理なし'
WHERE id = 'poshmark';

UPDATE competitors SET
  jp_strength = 'Google ヘルスケア AI / FitBit 連携 / 電子カルテ統合 AI / Gemini for Health / 医療画像 AI 診断先進',
  jp_weakness = '医療機関 B2B 中心 / 個人ライフ OS としての財務・タスク管理なし / 日本市場参入まだ薄い'
WHERE id = 'google-health';

UPDATE competitors SET
  jp_strength = '日本最大不動産情報サイト / リクルート系で信頼性高 / 新築・中古・賃貸を網羅 / AI マッチング機能追加中',
  jp_weakness = '不動産情報特化 / 個人財務・AI・ライフ OS 機能なし'
WHERE id = 'suumo';

UPDATE competitors SET
  jp_strength = '日本最大旅行・ホテル予約 / 11 万施設掲載 / じゃらん net PAY・ポイント連携 / リクルート系',
  jp_weakness = '旅行・宿泊特化 / 個人財務・健康・習慣管理なし'
WHERE id = 'jalan';

UPDATE competitors SET
  jp_strength = '国内 No.1 高級ホテル・旅館予約 / セレクトキュレーション / 外国人富裕層需要も取込 / プレミアム旅行の標準',
  jp_weakness = '高級旅行特化 / 個人ライフ OS・AI・財務管理なし'
WHERE id = 'ikyu';

UPDATE competitors SET
  jp_strength = '国内フードデリバリー最大手 / 出前館に次ぐ規模 / 自転車・バイク配達 / PayPay・LINEPay 連携 / AI 最適ルート',
  jp_weakness = 'フードデリバリー特化 / 個人ライフ OS・財務・タスク管理なし'
WHERE id = 'ubereats-japan';

UPDATE competitors SET
  jp_strength = '大手宅配便 2 位 / 飛脚ブランドの信頼 / EC 連携・法人向け充実 / 冷蔵便・時間指定対応',
  jp_weakness = '物流特化 / 個人ライフ OS・AI・財務管理なし'
WHERE id = 'sagawa-express';

UPDATE competitors SET
  jp_strength = '日本最大宅配便 / クロネコヤマト / 宅急便コンパクト・EAZY など多様な配送 / EC 最多利用',
  jp_weakness = '物流特化 / 個人 AI・財務・習慣化・ライフ OS 機能なし'
WHERE id = 'yamato-transport';

UPDATE competitors SET
  jp_strength = 'GeForce NOW のクラウドゲーム / PC 品質ゲームをスマホ・低スペック端末で / 月 1100 円から / Steam 連携',
  jp_weakness = 'ゲームストリーミング特化 / 個人ライフ OS・AI・財務管理なし'
WHERE id = 'nvidia-geforce-now';

UPDATE competitors SET
  jp_strength = 'Microsoft Xbox クラウドゲーム / Game Pass Ultimate 含む / PS5 クオリティをスマホで / 月 1320 円',
  jp_weakness = 'ゲームストリーミング特化 / 個人ライフ OS・AI・財務管理なし'
WHERE id = 'xbox-cloud-gaming';

UPDATE competitors SET
  jp_strength = '電動キックボードシェアリング国内 No.1 / 日本 60 都市展開 / 免許不要 / 移動 CO2 削減 / 国交省認可',
  jp_weakness = '短距離移動特化 / 個人財務・AI・習慣管理なし'
WHERE id = 'luup-micromobility';

UPDATE competitors SET
  jp_strength = '行政デジタル化 / マイナンバー申請・免許更新・各種届出オンライン化 / 総務省・地方自治体との連携',
  jp_weakness = '行政手続き特化 / 個人 AI・財務・習慣・ライフ OS 機能なし'
WHERE id = 'digi-smac';

UPDATE competitors SET
  jp_strength = '国内最大手暗号資産取引所 / 450 万口座 / ビットコイン・イーサリアム等 30 種 / 金融庁登録・信頼性高 / Monex グループ',
  jp_weakness = '暗号資産取引特化 / 個人 AI・習慣・タスク・健康管理なし'
WHERE id = 'coincheck';

UPDATE competitors SET
  jp_strength = 'ライフネット生命 / 定期死亡 + 就業不能保険 / ネット完結で安価 / 透明な保険料開示 / SBI 傘下',
  jp_weakness = '生命保険特化 / 個人 AI・タスク・習慣・財務 OS 機能なし / 保険以外の金融管理なし'
WHERE id = 'lifenet-insurance';

UPDATE competitors SET
  jp_strength = 'freee 損害保険 / 法人向けビジネス保険 / freee 会計との連携でワンストップ / 小規模事業者向け',
  jp_weakness = 'ビジネス保険特化 / 個人ライフ OS・AI・健康・習慣管理なし'
WHERE id = 'freee-insurance';

UPDATE competitors SET
  jp_strength = '日本最大の動画投稿サービス / 独自コメント文化 / ニコ生ライブ / アニメ・同人文化の核心 / ドワンゴ運営',
  jp_weakness = '動画・エンタメ特化 / AI 機能なし / 個人財務・習慣・ライフ OS 管理なし'
WHERE id = 'niconico';

UPDATE competitors SET
  jp_strength = 'トヨタ系コネクティッドカー / カーナビ・OTA 更新・AI 音声 / T-Connect / 2300 万台以上の接続実績',
  jp_weakness = '車載コネクテッド特化 / 個人財務・AI・習慣・ライフ OS 機能なし'
WHERE id = 'toyota-connected';

UPDATE competitors SET
  jp_strength = 'DeFi・Web3 のデファクト仮想通貨ウォレット / 3000 万+ ユーザー / ETH・ERC20 全対応 / MetaMask Snaps で拡張可',
  jp_weakness = 'Web3・仮想通貨ウォレット特化 / 個人財務 OS・AI・健康・習慣管理なし'
WHERE id = 'metamask';

UPDATE competitors SET
  jp_strength = 'AI 医療画像解析 / 脳卒中・肺塞栓 CT 自動診断 / ICU・ER 向け 即時アラート / 医師の診断支援',
  jp_weakness = '医療 AI 画像診断専用 / 個人ライフ OS・財務・タスク管理なし / 一般消費者向けでない'
WHERE id = 'viz-ai';
