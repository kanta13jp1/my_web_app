-- daily-development (scheduled) 2026-09-10: 直近の資産管理AI精度修正 + マニュアル修正を実績記録

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'ユーザーマニュアルのインポート手順を実装と整合',
  'user_manual_page.dart のインポート手順6件のうち4件が import_page.dart の許可拡張子・列名マッチングと不一致で実行不可能だった。MoneyForward はコード変更ゼロでCSV→xlsx変換の迂回路に手順を差し替え、X/GitHubは直接インポート未対応である旨を正直に明記。(#5365)',
  '2026-09-08'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'ユーザーマニュアルのインポート手順を実装と整合'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '資産管理: 支払元無効アラートの誤検知を抑制',
  'paymentSourceInvalidRows が有効なクレジットカード・債務を支払元として許可していなかったため誤検知していた問題を修正。有効な口座・債務を全て確認してから無効判定するよう変更。(#5218)',
  '2026-09-09'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '資産管理: 支払元無効アラートの誤検知を抑制'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '資産管理AI: 否定文脈の督促文言を誤検知しないよう修正',
  'grounding check (根拠確認) が「未払いではない」等の否定(negation)を含む督促文言を誤って支払催促と判定していた問題を修正。(#5369)',
  '2026-09-09'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '資産管理AI: 否定文脈の督促文言を誤検知しないよう修正'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '資産管理AI: 債務間の根拠確認をセグメント化',
  'grounding check で複数債務の文言が混在し、別債務の情報を根拠として誤って紐付ける cross-debt false positive を防止するため、債務ごとに根拠確認をセグメント化。(#5370)',
  '2026-09-09'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '資産管理AI: 債務間の根拠確認をセグメント化'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '資産管理: 給料収入計画の自動整合 + 未受領判定の誤検知防止',
  '給料収入計画を実際の入金と自動整合させ、AIが未受領の入金だと誤って警告するケースを防止するガードを追加。(#5371)',
  '2026-09-09'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '資産管理: 給料収入計画の自動整合 + 未受領判定の誤検知防止'
);
