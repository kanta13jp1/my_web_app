-- 性格診断スコアのUPDATEポリシーを追加
-- 作成日: 2025年11月11日
-- 目的: upsert操作が正常に動作するようにUPDATEポリシーを追加

-- personality_scoresテーブルにUPDATEポリシーを追加
CREATE POLICY "Users can update their own scores"
  ON personality_scores FOR UPDATE
  USING (test_id IN (SELECT id FROM personality_tests WHERE user_id = auth.uid()));
