-- Session 424: Web版 team-task-manager修正 + agent-personality + agent-department-manager (52 Functions)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('team-task-manager スキーマ修正', 'ai_agents → agents テーブル参照修正、assignee_agent_id/supervisor_agent_id 対応、部署移動・メッセージ送信・seed_agents アクション追加、agent_messages/agent_relationships ビュー対応', '2026-03-31'),
  ('Agent Personality Edge Function 追加', 'エージェント性格管理 API。identity_prompt 解析、personality_traits 記録、会話からの性格学習 (learn_from_conversation)、agent_memories レイヤー別管理', '2026-03-31'),
  ('Agent Department Manager Edge Function 追加', '企画責任者による部署管理 API。部署作成・エージェントアサイン・部長設定・部署別ゴール進捗。12部署のデフォルト定義とルール管理', '2026-03-31')
ON CONFLICT DO NOTHING;
