-- 音声AIアシスタント 会話履歴テーブル
-- Windows版#64 2026-04-16
-- Voice AI GMAT Tutor パターンを自分株式会社に適用
-- 長期記憶: 直近10件のメッセージをAIプロンプトに注入

-- ユーザー会話セッション
CREATE TABLE IF NOT EXISTS user_conversations (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id      uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  title        text,                          -- 任意タイトル (AIが自動生成可)
  context      text NOT NULL DEFAULT 'general_chat',
                                              -- 'general_chat' | 'ai_university_quiz' | 'habit_coach' | 'daily_journal'
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

-- 会話メッセージ (user/assistant の往復)
CREATE TABLE IF NOT EXISTS conversation_messages (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id  uuid REFERENCES user_conversations(id) ON DELETE CASCADE,
  role             text NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content          text NOT NULL,
  model            text,                      -- 応答したAIモデル (claude-sonnet-4-6 等)
  voice_used       boolean NOT NULL DEFAULT false,  -- 音声入力/出力フラグ
  tokens_used      integer,                   -- トークン数 (クォータ監視用)
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- インデックス: 会話別・時系列取得 (長期記憶注入の直近10件クエリ)
CREATE INDEX IF NOT EXISTS conv_messages_conv_id_created
  ON conversation_messages (conversation_id, created_at DESC);

-- インデックス: ユーザー別会話一覧
CREATE INDEX IF NOT EXISTS user_conversations_user_id
  ON user_conversations (user_id, updated_at DESC);

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_conversation_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE user_conversations SET updated_at = now()
  WHERE id = NEW.conversation_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER conversation_messages_after_insert
  AFTER INSERT ON conversation_messages
  FOR EACH ROW EXECUTE FUNCTION update_conversation_updated_at();

-- RLS: ユーザーは自分のデータのみアクセス可
ALTER TABLE user_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversation_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_own_user"
  ON user_conversations
  USING (auth.uid() = user_id);

CREATE POLICY "conv_messages_own_user"
  ON conversation_messages
  USING (
    EXISTS (
      SELECT 1 FROM user_conversations
      WHERE id = conversation_messages.conversation_id
        AND user_id = auth.uid()
    )
  );

-- サービスロールはすべてのデータにアクセス可 (AI assistant EF 用)
CREATE POLICY "conversations_service_role"
  ON user_conversations FOR ALL
  USING (auth.role() = 'service_role');

CREATE POLICY "conv_messages_service_role"
  ON conversation_messages FOR ALL
  USING (auth.role() = 'service_role');

-- コメント
COMMENT ON TABLE user_conversations IS 'ユーザーとAIの会話セッション。音声AIアシスタント・AI大学クイズ・習慣コーチ等で使用。';
COMMENT ON TABLE conversation_messages IS '会話メッセージ履歴。長期記憶として直近10件をAIプロンプトに注入する (Voice AI GMAT Tutor パターン)。';
COMMENT ON COLUMN user_conversations.context IS 'general_chat | ai_university_quiz | habit_coach | daily_journal';
COMMENT ON COLUMN conversation_messages.voice_used IS '音声入力 (STT) または音声出力 (TTS) を使用した場合 true';
COMMENT ON COLUMN conversation_messages.tokens_used IS 'ai_quota_usage テーブルとの連携用トークン数記録';
