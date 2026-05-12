-- PS#4 S370: 競合3社追加 981→984社 (secureframe/signalwire/bandwidth)
-- SEO: "Secureframe代替"/"SignalWire代替"/"Bandwidth代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S370: 競合3社追加 981→984社 (secureframe/signalwire/bandwidth)',
  'comparison_page.dartにsecureframe(SOC2/ISO27001コンプライアンス自動化/compliance/3B1DDB)/signalwire(音声ビデオメッセージングAPIクラウド通信/cpaas/0080FF)/bandwidth(エンタープライズ音声メッセージング通信API/cpaas/005DA0)の3社追加(981→984社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
