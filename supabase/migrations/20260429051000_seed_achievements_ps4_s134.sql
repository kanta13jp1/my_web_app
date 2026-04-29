-- PS#4 S134: 競合3社追加 273→276社 (whereby/obs-studio/camtasia)
-- SEO: "Whereby代替"/"OBS Studio代替"/"Camtasia代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S134: 競合3社追加 273→276社 (whereby/obs-studio/camtasia)',
  'comparison_page.dartにwhereby(ブラウザビデオ会議/video-comm/1D2D44)/obs-studio(OSSライブ配信/video-editing/362D6E)/camtasia(画面録画チュートリアル動画/video-editing/78D14B)の3社追加(273→276社)。全ファイル276統一。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
