-- Session: B2B エンタープライズページ実装 2026-03-30
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'B2B エンタープライズ LP 実装',
    '/enterprise ルートにB2B向けランディングページを新設。コスト削減シミュレーション・活用シーンカード・お問い合わせフォーム（Supabase永続化）を実装。enterprise_inquiries テーブル（RLS付き）をマイグレーションで作成。sitemap.xmlに追加。',
    '2026-03-30'
  ),
  (
    'コードブロック コピーボタン追加',
    'markdown_preview.dart の CodeElementBuilder にコピーボタン（_CopyCodeButton）を追加。言語ラベルの右側にCopy/Copiedボタンを表示し、クリック後2秒間フィードバックを表示するUXを実装。',
    '2026-03-30'
  ),
  (
    'RadioListTile deprecated API 修正',
    'Flutter 3.32.0+ でgroupValue/onChangedが非推奨になったRadioListTileをgrowth_acquisition_signal_page.dartで修正。flutter analyze 0件を維持。',
    '2026-03-30'
  )
ON CONFLICT DO NOTHING;
