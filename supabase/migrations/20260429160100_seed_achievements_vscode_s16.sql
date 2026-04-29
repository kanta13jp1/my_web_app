-- VSCode S16: dart:js_interop VM test contamination 解消
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'VSCode S16: dart:js_interop VM test fix + PR #1012',
  'ai_assistant_chat/guitar_recording_studio を conditional import で VM-safe 化。election_victory からCSVダウンロードを web_image_downloader へ抽出。js_interop_vm_stub.dart 追加。ci.yml continue-on-error: false 化。flutter test 7/7 pass。PR #1012 作成。cross-instance-pr 20260428_flutter_test_stub_fixes_vscode → done/。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
