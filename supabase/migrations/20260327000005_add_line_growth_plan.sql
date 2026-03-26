-- Add vs LINE to growth_plans table
-- LINE: ~196,000,000 monthly active users (Japan/Taiwan/Thailand/Indonesia messaging + fintech)
INSERT INTO growth_plans (label, deadline, target, features_done, features_total)
VALUES ('vs LINE', '2036年12月31日', 196000000, 3, 25)
ON CONFLICT DO NOTHING;
