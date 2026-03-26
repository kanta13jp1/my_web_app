-- Add vs Amazon to growth_plans table
INSERT INTO growth_plans (label, deadline, target, features_done, features_total)
VALUES ('vs Amazon', '2038年12月31日', 310000000, 5, 30)
ON CONFLICT DO NOTHING;
