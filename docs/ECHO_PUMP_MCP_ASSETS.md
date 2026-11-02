# 残響ポンプ室のMCP素材制作

## Blender（クラウド実行）

交換ヒューズを実際のBlender MCPの `execute_blender_code` で制作し、固定カメラでPNGへレンダリングする。現在のFlutterへ静止画を組み込むため、Web側へ3Dエンジン・MCP・外部APIの依存を追加しない。

- workflow: `.github/workflows/echo-pump-mcp-assets.yml`
- model: `scripts/echo_pump_mcp/model.py`
- community server: `mcp-for-blender==2.1.9`、wheel SHA256を検証し付属アドオンを使う。
- `DISABLE_TELEMETRY=true`、safe mode、127.0.0.1の一時接続。外部の有料3D生成・サンプル素材は不使用。
- MCP SDKによるinitialize/list_tools/5 tool callsと出力hashをartifactへ保存。Codex Desktopのネイティブツール検出とは区別する。
- `.blend` / GLB / PNGの原本は保管し、アプリへはPNGだけ取り込む。再制作は固定SHAのworkflowで行い、成果物を目視・hash照合して別コミットにする。
- 初回画像の読込み中・取得失敗時は既存の独自ベクター図へ戻る。空の所持品は従来の輪郭表示を維持する。

## ElevenLabs（接続準備・未認証）

2026-10-18、公式hosted MCP `https://api.elevenlabs.io/v1/mcp` をCodexの独立エントリー `echo-pump-elevenlabs` として追加。既存サーバーの変更なし、資格情報を設定・ソースへ埋め込まない。

現在のCLI 0.163.0-alpha.10.2はOAuth開始時に `Dynamic client registration not supported` で終了した。現行CLIのloginにはCIMD選択オプションがなく、認証・tools/list・SE生成は未完了。設定は無効で保持し、再接続時に対応クライアントと認証方式を確認する。Claudeの別コネクターの資格情報を流用しない。

### 次に作るSE（制作仕様、未生成）

| 項目 | 候補 |
| --- | --- |
| 対象 | 金属床を踏む一歩。歩行アニメーションの各接地で既存step cueから再生 |
| プロンプト | One single work boot footstep on a damp steel grate inside a quiet underground pump room. Short low impact, subtle metallic resonance, tiny water droplets. No voices, no music, no ambient bed. Clean isolated one-shot, rapid decay. |
| 尺 | 0.35〜0.5秒。1種類、候補は最大2点 |
| 取込み | 元音を保持し、モノラルPCM WAV・22050Hz・16bitへ変換。既存音声サービスの停止/音量/同時再生制御を使う |
| 品質確認 | 音割れ・先頭末尾のクリック・長い残響を検査し聴取比較。メモ/所持品/演出/画面非表示中の足音停止を回帰確認 |
| 利用条件 | 認証後に実プラン・残量・生成費用・ゲーム配信用の権利/クレジット条件を確認してから実行。新しい契約やアップグレードは行わない |

現時点でElevenLabs製SEは同梱していない。既存の数式合成によるBGM/SEとその出典を維持する。接続完了・生成済みと記載しない。

## 一次情報

- [Blender MCP提供者](https://github.com/ahujasid/mcp-for-blender)
- [ElevenLabs hosted MCP](https://elevenlabs.io/docs/eleven-agents/operate/hosted-mcp)
- [ElevenLabs制作機能の発表](https://elevenlabs.io/blog/introducing-voice-music-image-and-video-generation-in-the-elevenlabs-mcp)
- [Codex MCP設定とOAuth](https://developers.openai.com/codex/mcp/)
