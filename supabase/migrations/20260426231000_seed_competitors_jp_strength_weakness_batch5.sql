-- PS#4 S67: jp_strength/jp_weakness 補完 Batch 5 (20社)
-- 対象: original 21 未補完 + ov=4 LOW 重点 + cerebras-systems

UPDATE competitors SET
  jp_strength = '日本発 AI コーディングアシスタント / GPT-4 レベルのコード生成 / ローカル実行・プライバシー重視 / 開発者コミュニティで人気',
  jp_weakness = 'コーディング特化 / 個人ライフ OS 機能なし / 知名度が国際競合に劣る'
WHERE id = 'openclaw';

UPDATE competitors SET
  jp_weakness = '法人向け勤怠・HR 特化 / AI 機能まだ限定的 / 個人ライフマネジメント・財務・習慣管理なし',
  jp_strength = '日本 No.1 勤怠管理クラウド / 導入企業 15 万社超 / 打刻・シフト・給与計算一体化 / 無料プランあり / 中小 SMB に最適'
WHERE id = 'jobcan';

UPDATE competitors SET
  jp_strength = 'Google Workspace + Search + AI (Gemini 4) の統合力 / 世界 3B+ ユーザー / 日本でもGmail・カレンダー主流 / 法人向け AI 強化',
  jp_weakness = '個人財務・確定申告なし / ライフ OS としての個人習慣化・健康管理なし / 税務は外部サービス依存'
WHERE id = 'google';

UPDATE competitors SET
  jp_strength = 'Claude API + ペアプロ機能 / チーム AI 開発の実験的ツール / Anthropic 直系のコーディング AI',
  jp_weakness = 'コーディング特化・実験的段階 / 個人ライフ OS 機能なし / 製品成熟度が他社に劣る'
WHERE id = 'claude-cowork';

UPDATE competitors SET
  jp_strength = 'Meta AI (Llama 3) 統合 / 世界 30 億 MAU / WhatsApp・Instagram 含む巨大エコシステム / 広告精度最高水準',
  jp_weakness = 'SNS 広告・コミュニティ特化 / データプライバシー問題多い / 個人財務・健康・AI 学習管理なし'
WHERE id = 'facebook';

UPDATE competitors SET
  jp_strength = '日本最大 SNS (国内 4500 万+ MAU) / リアルタイム情報 No.1 / Grok AI 搭載 / X Premium AI 機能充実',
  jp_weakness = '情報・SNS 特化 / 個人財務・健康・習慣化・タスク管理なし / 安全性・信頼性への懸念'
WHERE id = 'x';

UPDATE competitors SET
  jp_strength = 'Microsoft 365 + Copilot AI 統合 / Teams・Outlook・Excel を AI が横断 / 法人向け世界標準 / 日本大企業採用率高い',
  jp_weakness = '企業向け中心 / 個人財務・健康・習慣管理なし / 個人 CEO ライフ OS としての統合はない'
WHERE id = 'microsoft';

UPDATE competitors SET
  jp_strength = 'Anthropic 公式 CLI / agentic コーディング最先端 / MCP プロトコル作成者 / Claude Sonnet 4.6 標準搭載 / Plan Mode',
  jp_weakness = 'コーディング CLI 特化 / エンドユーザー向け UI なし / 個人ライフ OS 機能なし'
WHERE id = 'claude-code';

UPDATE competitors SET
  jp_strength = '世界最大 OSS ホスティング / GitHub Copilot + Actions AI / 開発者のデファクト基盤 / Copilot SDK で外部統合 / MS 傘下',
  jp_weakness = '開発者ツール特化 / 個人財務・健康・習慣管理なし / エンドユーザー向け製品なし'
WHERE id = 'github';

UPDATE competitors SET
  jp_strength = '3D アバター・バーチャル配信特化 / VTuber 市場 (日本発) / 無料プランで敷居低い / Live2D 競合から移行組も多い',
  jp_weakness = 'バーチャル配信特化 = 財務・タスク・AI 学習・ライフ OS 機能なし'
WHERE id = 'animaworks';

UPDATE competitors SET
  jp_strength = '世界最大 EC + AWS + Alexa AI / 日本でも配送網最強 / Amazon Business で法人向け強化 / Bedrock AI サービス',
  jp_weakness = 'EC・クラウドインフラ特化 / 個人財務確定申告・習慣化・ライフ OS 機能なし'
WHERE id = 'amazon';

UPDATE competitors SET
  jp_strength = 'ライフスタイル記録・共有特化 / 食事・運動・旅行を日記型で蓄積 / コミュニティ発見機能 / 無料',
  jp_weakness = 'ライフログ特化だが AI 機能・財務管理・目標設定なし / 競合に対する差別化薄い'
WHERE id = 'liven';

UPDATE competitors SET
  jp_strength = 'OpenAI 製 AI コーディングエージェント / GPT-4o ベース / GitHub 統合 / 複数ファイル同時編集 / ターミナル操作',
  jp_weakness = 'コーディング特化 / 個人ライフ OS 機能なし / まだクローズドβ段階'
WHERE id = 'codex';

UPDATE competitors SET
  jp_strength = '日本最大競馬情報 / レース・血統・オッズ・予想の全情報網羅 / 公式データ提供 / JRA 公認',
  jp_weakness = '競馬特化 / 個人ライフマネジメント・AI 機能なし / 競馬以外への展開なし'
WHERE id = 'netkeiba';

UPDATE competitors SET
  jp_strength = '国内最大 SNS / 月 9500 万 MAU / スタンプ・ペイ・ニュース・ショッピング統合エコシステム / 法人向け LINE WORKS',
  jp_weakness = 'エコシステム内完結で外部との連携弱い / AI 機能まだ限定的 / 個人財務・健康・WBS 管理なし'
WHERE id = 'line';

UPDATE competitors SET
  jp_strength = '推論特化チップで GPU を超える計算効率 / Wafer Scale Engine / 超高スループット / AI 研究者に注目 / $4.3B 評価',
  jp_weakness = 'AI インフラ B2B 特化 / エンドユーザー向け製品なし / 個人ライフ OS 機能なし'
WHERE id = 'cerebras-systems';

UPDATE competitors SET
  jp_strength = '日本最大グルメ評価サイト / 4 万店超のレビュー / 予約・ポイント連携 / 食文化のデファクトデータベース',
  jp_weakness = 'グルメ特化 / 個人財務・タスク・AI 機能なし / 飲食店のみでライフ OS にならない'
WHERE id = 'tabelog';

UPDATE competitors SET
  jp_strength = '国内最大ブログサービス / 1500 万ブログ / Ameba ピグ・芸能人ブログ文化を形成 / SNS との連携 / 無料',
  jp_weakness = 'ブログ・エンタメ特化 / AI 機能・財務・タスク管理なし / 若年層はなし'
WHERE id = 'ameba';

UPDATE competitors SET
  jp_strength = 'API 開発・テストの世界標準 / 1600 万開発者 / Postbot AI でテスト自動化 / チームコラボ API 管理',
  jp_weakness = '開発者・API 特化 / 個人ライフ OS・財務・健康管理なし'
WHERE id = 'postman';

UPDATE competitors SET
  jp_strength = '日本最大のプログラミング学習 / ブラウザで即実行 / 無料レッスン豊富 / HTML/CSS/Python 初心者向け / 100 万ユーザー超',
  jp_weakness = '初心者向け入門学習特化 / AI 機能なし / 個人財務・習慣・ライフ OS 機能なし'
WHERE id = 'progate';
