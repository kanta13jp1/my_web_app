-- Add vs Google and vs Microsoft to growth_plans table
-- Google: ~4.3 billion users (Google Workspace + Search + Android ecosystem)
-- Microsoft: ~1.5 billion users (Microsoft 365 + Windows + Azure ecosystem)
-- target column is INTEGER (max 2,147,483,647) → ALTER to BIGINT first

ALTER TABLE growth_plans ALTER COLUMN target TYPE bigint;

INSERT INTO growth_plans (label, deadline, target, features_done, features_total)
VALUES
  ('vs Google', '2040年12月31日', 4300000000, 3, 40),
  ('vs Microsoft', '2040年12月31日', 1500000000, 3, 35)
ON CONFLICT DO NOTHING;
