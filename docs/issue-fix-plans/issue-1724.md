# Issue Fix Plan #1724

- Issue: [[追加要望][P1][automation] notebooklm-video-pipeline.yml 動作に必要な 5 secrets を設定する](https://github.com/kanta13jp1/my_web_app/issues/1724)
- Labels: enhancement,priority:high,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25835989795

## Goal

[追加要望][P1][automation] notebooklm-video-pipeline.yml 動作に必要な 5 secrets を設定する

## Current Context

```text
## 背景

Win版#132 part 116 で `gh workflow run notebooklm-video-pipeline.yml` を試行 → run [25271275372](https://github.com/kanta13jp1/my_web_app/actions/runs/25271275372) が `Input required and not supplied: token` で 9 秒で fail.

`gh secret list` で確認した結果、video pipeline 用の **5 secrets が全て未設定**:

- `GITHUB_PAT` — checkout に必要 (workflow_dispatch ブランチ push 用)
- `NOTEBOOKLM_STORAGE_STATE_JSON` — notebooklm CLI auth (= `~/.notebooklm/storage_state.json` の中身を base64 化せず JSON として登録)
- `ELEVENLABS_API_KEY` — Scribe ASR 字幕生成
- `YOUTUBE_CLIENT_SECRET_JSON` — YouTube OAuth client secret
- `YOUTUBE_TOKEN_JSON` — YouTube OAuth refresh token

## 現状の影響

- Win 版で local pipeline (`notebooklm download` + `ffmpeg` 圧縮) を代替実行 → MP4 を `web/assets/videos/` に self-host (= commit `ddfe640f1`)
- philosophy_page.dart `_Video` に optional `mp4Url` field 追加して暫定埋め込み (= AI大学シリーズ #4)
- ただし **YouTube Shorts package / SRT 字幕 / intro/outro card** は ElevenLabs + YouTube secret 必要なため未生成

## 受け入れ条件

1. 上記 5 secrets を `gh secret set` で repo に登録
2. `notebooklm-video-pipeline.yml` を再 dispatch (notebook=f167dcc3 / artifact=25423b84 / series=4 / slug=multi-agent-convergence) して green
3. YouTube アップロード成功後 → philosophy_page.dart の `_Video` (id='multi-agent-convergence') を update:
   - `id` を実 YouTube 動画 ID に置換
   - `mp4Url` を削除 (null 戻し)
   - `web/assets/videos/multi-agent-convergence.mp4` 削除 (= 12MB repo size 解消)

## 担当候補

User (= secrets 登録は人間操作必要) → 以後 PS版#1 / Codex#2 が dispatch + verify

## 関連

- 過去成功例: Win版#132 part 25-29 で同 pipeline 3 本完走 (`memory/feedback_success_20260418_video_editing_workflow.md`)
- 直前 commit: ddfe640f1 (NotebookLM #4 暫定 MP4 埋め込み)

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
