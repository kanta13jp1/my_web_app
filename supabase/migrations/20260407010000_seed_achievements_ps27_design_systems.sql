-- Session PS#27: awesome-design-md-jp 日本語デザインシステム統合
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'awesome-design-md-jp 日本語デザインシステム統合 (PS#27)',
    'docs/design-systems/ 配下に5サービスのDESIGN.mdを保存: note(teal #5ac8b8/line-height 2.0/palt見出しのみ), freee(blue #2864f0/4pxグリッド/プロダクトはシステムフォント), SmartHR(blue #0077c7/Yu Gothic Medium→400マッピング), Apple JP(SF Pro JP優先/ピルボタン), WIRED.jp(純黒×黄/body全体palt/角張りデザイン)。CLAUDE.mdにUIコンポーネント生成時の参照指示と日本語タイポグラフィ4ルールを追加。',
    '2026-04-07 00:00:00+00'
  )
ON CONFLICT DO NOTHING;
