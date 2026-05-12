-- PS#4 S435: 競合3社追加 1129→1132社 (fusion-360/sketchup/gotowebinar)
-- SEO: "Fusion 360代替"/"SketchUp代替"/"GoToWebinar代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S435: 競合3社追加 1129→1132社 (fusion-360/sketchup/gotowebinar)',
  'comparison_page.dartにfusion-360(Autodesk 3D CAD/CAM/CAEクラウド製品設計/3d-cad/0696D7)/sketchup(Trimble建築インテリア3Dモデリング3D Warehouse/3d-modeling/19B2C6)/gotowebinar(LogMeIn大規模ウェビナー3000参加者/webinar/7B4FA8)の3社追加(1129→1132社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
