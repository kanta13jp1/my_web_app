-- Add vs Discord to growth_plans table
-- Discord: ~200,000,000 monthly active users (gaming + community platform)
INSERT INTO growth_plans (label, deadline, target, features_done, features_total)
VALUES ('vs Discord', '2036年12月31日', 200000000, 3, 25)
ON CONFLICT DO NOTHING;
