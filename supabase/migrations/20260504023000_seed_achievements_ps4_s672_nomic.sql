-- PS#4 S672: Nomic AI comparison_page追加 + #1761 close (1893→1894社)
-- Addresses Issue #1822 (PS#4 portion: comparison_page + AI大学)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S672: Nomic AI comparison_page追加 (1893→1894社)',
  'Nomic AI (nomic-ai-vector-search) comparison_page追加 — Nomic Embed 8192トークン/Apache2.0/OSS + Nomic Atlas高次元可視化 / sitemap 1URL追加 / landing+user_manual 1894社更新 / Issue #1822 PS#4部分close',
  '2026-05-04'
)
ON CONFLICT DO NOTHING;
