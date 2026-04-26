-- PS#4 S67: jp_strength/jp_weakness 補完 Batch 4 (11社)
-- 対象: ov=4 MEDIUM (ntt-docomo・datadog・groq-ai 等インフラ・テレコム・AI)

UPDATE competitors SET
  jp_strength = '国内最大モバイルキャリア / d Point・d払い・dマガジン等エコシステム / ドコモ AI エージェント開発中 / 5G 先行投資',
  jp_weakness = 'キャリアサービス中心 / 個人ライフ OS としての総合管理なし / AI 機能はまだ他社に劣る'
WHERE id = 'ntt-docomo';

UPDATE competitors SET
  jp_strength = '開発者向けモニタリング世界標準 / APM・ログ・セキュリティ一体化 / AI Ops 機能 / Fortune 500 企業の大半が採用',
  jp_weakness = '開発者・インフラ専用 / 個人ライフマネジメント・財務管理なし / 高コスト'
WHERE id = 'datadog';

UPDATE competitors SET
  jp_strength = '国内第 2 位キャリア / au PAY・じぶん銀行・auスマートパス等エコシステム / 5G 早期展開 / KDDI の AI 投資加速',
  jp_weakness = 'キャリアサービス中心 / 個人 AI ライフ OS 機能なし / 競合他社との差別化薄い'
WHERE id = 'kddi-au';

UPDATE competitors SET
  jp_strength = 'LPU チップによる推論速度世界最速 / Llama 3 等 OSS モデルを超高速実行 / 開発者 API コスト最安水準 / $640M 調達',
  jp_weakness = 'API・推論インフラ特化 = エンドユーザー向け製品なし / 個人ライフ OS 機能なし'
WHERE id = 'groq-ai';

UPDATE competitors SET
  jp_strength = '国内ライドシェア・タクシー配車 No.1 / GO アプリ 1300 万 DL / AI 配車最適化 / タクシー業界の標準インフラ化',
  jp_weakness = '移動特化 / 個人ライフマネジメント・財務管理・AI 学習機能なし'
WHERE id = 'go-taxi';

UPDATE competitors SET
  jp_strength = '行政デジタル化 SaaS / 申請書類のオンライン化 / 自治体 1000+ 導入 / マイナンバー連携対応 / VC 出資',
  jp_weakness = '行政手続き特化 / 個人 AI・財務・習慣管理機能なし / 一般消費者向けでない'
WHERE id = 'graffer';

UPDATE competitors SET
  jp_strength = 'ローカル LLM 実行の事実上標準 / GPU なし CPU のみで動作 / プライバシー完全保護 / 200+ モデル対応 / OSS',
  jp_weakness = 'ローカル開発者向け / エンドユーザー向け UI なし / クラウド統合・個人 OS 機能なし'
WHERE id = 'ollama';

UPDATE competitors SET
  jp_strength = 'AI 動画・音声編集 / テキスト→動画タイムライン / 自動文字起こし精度高い / Podcast・ウェビナー制作者に普及 / $100M 調達',
  jp_weakness = '動画・音声編集特化 / 個人財務・タスク・ライフ管理機能なし / 日本語対応まだ限定的'
WHERE id = 'descript';

UPDATE competitors SET
  jp_strength = 'AI アバター動画生成 / 60 言語対応 / テキストのみでプロ品質動画 / 企業研修・コンテンツに採用 / $90M 調達',
  jp_weakness = 'AI 動画特化 / 個人ライフ OS 機能なし / 日本語話者向けコンテンツ品質まだ改善余地'
WHERE id = 'synthesia';

UPDATE competitors SET
  jp_strength = 'データ AI プラットフォーム世界標準 / Delta Lake・MLflow・Unity Catalog OSS / 3 万社以上 / $43B 評価額',
  jp_weakness = 'エンタープライズデータ基盤特化 / 個人ライフマネジメント・エンドユーザー向け機能なし'
WHERE id = 'databricks';

UPDATE competitors SET
  jp_strength = 'クラウドデータウェアハウス市場 No.1 / Snowpark AI / Arctic LLM / $50B 評価 / 9800+ 企業採用',
  jp_weakness = 'データインフラ B2B 特化 / 個人ライフ管理・エンドユーザー向け製品なし / 高コスト'
WHERE id = 'snowflake';
