-- RPC: edge_function_ui_status の call_count をインクリメント
CREATE OR REPLACE FUNCTION increment_edge_function_call_count(fn_name text)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE edge_function_ui_status
  SET call_count = call_count + 1,
      last_called_at = now(),
      updated_at = now()
  WHERE function_name = fn_name;

  -- 行が存在しない場合は挿入
  IF NOT FOUND THEN
    INSERT INTO edge_function_ui_status (function_name, has_ui, call_count, last_called_at, updated_at)
    VALUES (fn_name, true, 1, now(), now())
    ON CONFLICT (function_name) DO UPDATE
    SET call_count = edge_function_ui_status.call_count + 1,
        last_called_at = now(),
        updated_at = now();
  END IF;
END;
$$;

-- Session 423: Web版 Edge Function 3本追加 (50 Functions 体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Schedule Health Check Edge Function 追加', 'Schedule タスク実行状況の監視・失敗検知・改善提案・自動修正タスク登録 API。管理者ダッシュボードから全タスクのヘルススコアを確認可能', '2026-03-31'),
  ('Code Review & Issue Manager Edge Function 追加', 'コードレビュー結果の記録・Issue (agent_task) 自動作成・解決管理 API。セキュリティ/パフォーマンス/Lint等8カテゴリのレビュー対応', '2026-03-31'),
  ('Development Stats Edge Function 追加', '開発進捗グラフデータ API。短期/中期/長期計画 + 競合21社 vs 進捗率 + 期間別実績集計。ホーム画面のプログレスバー表示用', '2026-03-31'),
  ('Edge Function Coverage 呼び出し記録機能追加', 'edge-function-coverage に POST エンドポイント追加。UI からの呼び出しを edge_function_ui_status テーブルに自動記録。call_count インクリメント RPC 関数も追加', '2026-03-31')
ON CONFLICT DO NOTHING;
