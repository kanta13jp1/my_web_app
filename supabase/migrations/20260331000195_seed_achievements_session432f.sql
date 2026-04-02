-- Session 432f: ドメイン特化Edge Functions (競馬予想/採用管理/法務/eラーニング/CRM)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('競馬予想・分析 Edge Function', 'netkeiba競合: レース登録、AIスコアリング (form*3+jockey*2+trainer+track)、予想記録、結果記録、ROI統計', '2026-03-31'),
  ('採用・求人管理 Edge Function', 'ジョブカン競合: 求人CRUD、応募管理ATS (9ステータス)、選考パイプライン、面接スケジュール', '2026-03-31'),
  ('法務・コンプライアンス管理 Edge Function', 'エンタープライズ競合: 8契約テンプレート、4コンプライアンスチェックリスト (GDPR/個人情報保護法/セキュリティ/SOX)、同意管理', '2026-03-31'),
  ('eラーニング・コース管理 Edge Function', 'Google Classroom/Udemy競合: コース作成、レッスン進捗追跡、自動修了証発行、8カテゴリスキルギャップ分析', '2026-03-31'),
  ('CRM営業パイプライン Edge Function', 'Salesforce競合: リード管理 (AIスコアリング)、6段階商談ステージ、活動ログ、勝率・売上統計', '2026-03-31')
ON CONFLICT DO NOTHING;
