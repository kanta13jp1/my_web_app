-- Session 432h: プラットフォーム拡張Edge Functions (イベント/ペット/語学/IoT/ニュース)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('イベント・チケット管理 Edge Function', 'Facebook Events/LINE競合: イベント作成(8カテゴリ)、QRチケット発行、チェックイン、参加者管理、収益統計', '2026-03-31'),
  ('ペットケア管理 Edge Function', 'ライフスタイル統合: ペット登録(8種類)、健康記録(ワクチン/通院/投薬)、食事・体重記録、散歩ログ・距離統計', '2026-03-31'),
  ('語学学習 Edge Function', 'Duolingo競合: 単語帳・フラッシュカード(SM-2間隔反復アルゴリズム)、12言語対応、学習ストリーク、正答率統計', '2026-03-31'),
  ('スマートホームIoT管理 Edge Function', 'Google Home/Alexa競合: デバイス管理(10種類)、センサーデータ記録、IFTTT風自動化ルール、シーン管理', '2026-03-31'),
  ('ニュースRSSアグリゲーター Edge Function', 'Google News/Feedly競合: RSSフィード登録、記事管理(9カテゴリ)、ブックマーク、既読管理、読書統計', '2026-03-31')
ON CONFLICT DO NOTHING;
