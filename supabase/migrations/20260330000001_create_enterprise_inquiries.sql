-- Session: B2B エンタープライズ問い合わせテーブル
-- enterprise_page.dart の問い合わせフォームが書き込む

CREATE TABLE IF NOT EXISTS enterprise_inquiries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  company_name text NOT NULL,
  message text,
  status text NOT NULL DEFAULT 'new',  -- new / contacted / closed
  created_at timestamptz NOT NULL DEFAULT now()
);

-- anon ユーザーが挿入できる（RLS）
ALTER TABLE enterprise_inquiries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon can insert enterprise_inquiries"
  ON enterprise_inquiries FOR INSERT
  WITH CHECK (true);

CREATE POLICY "admin can select enterprise_inquiries"
  ON enterprise_inquiries FOR SELECT
  USING (auth.role() = 'service_role' OR auth.jwt() ->> 'email' = 'kanta@example.com');
