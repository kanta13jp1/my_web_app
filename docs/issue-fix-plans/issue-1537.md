# Issue Fix Plan #1537

- Issue: [[追加要望] AI大学動画からバイラルショート・動的字幕・SNS投稿案を自動生成](https://github.com/kanta13jp1/my_web_app/issues/1537)
- Labels: enhancement,edge-function,priority:high,competitive-response,ai-university,automation,追加要望
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/25239988724

## Goal

[追加要望] AI大学動画からバイラルショート・動的字幕・SNS投稿案を自動生成

## Current Context

```text
## 背景
NotebookLMノート `Mastering Descript: AI Video Editing and Underlord Co-Editor Guide` を確認した結果、Descript Underlordの `Create Clips`, `Dynamic captions`, 縦型ソーシャル動画化の考え方は、本プロジェクトの `AI大学` / `NotebookLM動画パイプライン` / `viral-video-ad-generator` / `x-media-post` / `growth-hub` にそのまま接続しやすい。

Underlord公式ソースでは、長尺動画を60-90秒のSNS向けクリップへ分割し、縦型画角へ再フォーマットし、ブランドカラーやアクティブワード強調を含むSNS風字幕を付ける例が示されている。

参考:
- NotebookLM: https://notebooklm.google.com/notebook/2f516389-a41f-499d-bc05-ae54562a6295
- ノート内根拠ソース: `Underlord (beta): Your AI co-editor in Descript`, `Pricing & Plans - Descript`, `ULTIMATE Descript Tutorial for Beginners in 2026`
- Descript公式: https://help.descript.com/hc/en-us/articles/36803785502221-Underlord-beta-Your-AI-co-editor-in-Descript

## 追加要望
AI大学・NotebookLM動画から、ショート動画パッケージを自動生成する機能を追加する。

1本の長尺動画から以下を生成する。

- 60-90秒の見どころクリップ候補を3-5本
- YouTube Shorts / TikTok / X向けの9:16動画
- 音声同期した動的字幕、アクティブワード強調、ブランドカラー設定
- 日本語・英語字幕、必要なら字幕翻訳だけのSRT/VTT
- SNS投稿文、ハッシュタグ、固定返信、概要欄
- 元動画URL、source transcript hash、AI生成表示を含むprovenance情報

## 受け入れ条件
- 既存のNotebookLM動画パイプライン完了後に、任意でショート展開ジョブを起動できる
- クリップ候補には開始・終了タイムコード、選定理由、想定フックを付ける
- 9:16書き出し時に字幕が画面外へ出ないことをCIまたはsmoke testで検証する
- 動的字幕の色・サイズ・位置・強調ルールを構造化パラメータとして保存できる
- X投稿連携は既存の `x-media-post` / `viral-growth-engine` と重複せず、生成済み素材を渡す形にする
- 公開済み本編とショート素材をAI大学ページまたは管理画面で紐づけて確認できる

## 優先度
高。長尺AI大学動画をSNS配信用の複数素材に変換でき、配信量と検証速度に直結するため。

## 実装メモ
- 最初のMVPは動画生成そのものより、クリップ選定JSON + ffmpeg crop/scale + SRT変換 + 投稿文生成に絞る
- `scripts/video/_smoke_test.py` に縦型字幕の最低限の検証を追加する
- `growth-hub` に投稿後メトリクスを返し、どのクリップが伸びたか次回の編集ブリーフへ反映できるようにする

```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [x] Reproduction is clear
- [x] Smallest safe fix is implemented
- [x] Analyze/tests/CI are checked locally
- [x] PR notes explain the change and the remaining risk

## Implemented MVP

- Added `scripts/video/build_shorts_package.py`.
- The script reads an ElevenLabs/NotebookLM transcript and emits:
  - `shorts_package.json`
  - one `.srt` and `.vtt` per clip
  - one `.ffmpeg.txt` render command per clip
  - `social_posts.json`
  - provenance metadata with transcript SHA-256
- The render target is 9:16 (`1080x1920`) and subtitle placement is expressed as structured safe-zone parameters.
- The existing `notebooklm-video-pipeline.yml` workflow now has an optional `generate_shorts_package` dispatch input that runs this package builder after Step 3.
- `scripts/video/_smoke_test.py` now validates clip package generation, subtitle sidecars, 9:16 ffmpeg crop/scale commands, and safe-zone metadata.

## Remaining Risk

- This MVP prepares deterministic short-form packages and render commands, but does not upload short clips or feed post-performance metrics back into `growth-hub` yet.
- Actual media rendering remains an operator/workflow step because CI should avoid burning video processing quota unless the workflow input is explicitly enabled.
