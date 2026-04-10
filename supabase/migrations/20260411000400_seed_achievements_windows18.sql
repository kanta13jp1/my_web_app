-- Session Windows#18: docs/ リンク修正 + コア機能リスト整合性修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'docs/ リンク修正: BRANCH_PROTECTION_SETUP.md + LICENSE 作成',
  'docs/CICD_SETUP_GUIDE.md が参照していたdocs/technical/BRANCH_PROTECTION_SETUP.mdを新規作成(ブランチ保護設定手順・CI連携・Claude Schedule連携を記載)。docs/CONTRIBUTING.mdが参照していたLICENSEファイルをMIT Licenseで作成。COMPRESSED_PROMPT_V3.mdのコア機能リスト#26-30をLP済・#31を実装済に更新。markdownlint 0エラー確認。',
  '2026-04-11'
)
ON CONFLICT DO NOTHING;
