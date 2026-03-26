-- Add vs Facebook to growth_plans table
-- Facebook (Meta): ~3,070,000,000 monthly active users
INSERT INTO growth_plans (label, deadline, target, features_done, features_total)
VALUES ('vs Facebook', '2040年12月31日', 3070000000, 2, 30)
ON CONFLICT DO NOTHING;
