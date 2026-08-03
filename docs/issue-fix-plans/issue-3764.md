# Issue Fix Plan #3764

- Issue: [[追加要望] 🎥 X-A/B: メディア種別(動画/画像/テキスト)を第1級のA/B次元に昇格](https://github.com/kanta13jp1/my_web_app/issues/3764)
- Labels: priority:high,追加要望,growth,launch
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28841749377
- R13 added: 2026-07-07, after R12 thread-coherence shipped and live post improved from 2 views to 13 views.

## Goal

[追加要望] 🎥 X-A/B: メディア種別(動画/画像/テキスト)を第1級のA/B次元に昇格

## Current Context

```text
## 背景（検証で確定）
X投稿のインプレA/Bループ(x-post-metrics-optimizer + growth-hub + universal_x_share_service)は**稼働中**だが、A/Bは6テキストバリアント(dailyBriefing/pinnedPost/problemPost/featurePost/questionPost/usefulReply)のみ。**インプレの最大レバー=メディア種別が変数化されていない**。今日AI動画投稿が開通したのに、ループは動画の存在を知らない。

## やること
1. `x_post_log` metadata に `media_type`(video/image/text)を必ず記録（**AI動画シェア経路=viral-video-ad-generator→投稿 も含める**。現状この経路はvariantタグ無し）
2. `x.performance_context` に media_type 別の平均インプレ/エンゲージを集計させ、prompt へ「動画>画像>テキストなら動画を優先」を注入
3. `UniversalXGrowthShareVariant` に直交する `mediaVariant` 軸を追加し、1回1変数A/B（文言固定でmedia差, or media固定で文言差）
## 受け入れ条件
- x_post_metric_snapshot に media_type 列/フィールドが入る
- x.performance_context 応答に by_media_type 集計が出る
- 次のAI生成が「動画が勝っている」データで動画付き投稿を優先
統括 #3663 / 親 #3744

```

## R13 10-Hypothesis Adversarial Verification

| # | Hypothesis | Evidence / falsification check | Verdict | Implementation consequence |
| --- | --- | --- | --- | --- |
| H1 | R12でコピー品質は改善したため、次の最大レバーはメディア種別(video/image/text)である | 実投稿は2 views→13 viewsへ改善。残課題は文言よりdistribution/dwellの可能性が高い。Issue本文も「最大レバー=メディア種別が変数化されていない」と明記 | Survives | #3764をR13の主軸にする |
| H2 | 6種類のtext variantだけでは、動画・画像・テキストの勝ち負けを学習できない | `UniversalXGrowthShareVariant` は dailyBriefing/pinnedPost/problemPost/featurePost/questionPost/usefulReply の6軸。media軸が直交していない | Survives | `UniversalXMediaVariant` または metadata `media_type` を追加 |
| H3 | AI動画投稿経路がvariant/media metadataを残さないため、勝ちパターンがperformance_contextに戻らない | Issue本文が「AI動画シェア経路=viral-video-ad-generator→投稿も含める。現状この経路はvariantタグ無し」と明記 | Survives | video/image/text を `x_post_log.metadata` に必ず保存 |
| H4 | R12のプロンプト改善だけではfallback経路の低品質pollを止められない | fallback poll は `今日の注目「$topic」、あなたは？` + 汎用選択肢。LLMプロンプト制約を通らない | Survives but separate PR | R13bでfallback pollも主題ロック/現在状態型へ寄せる |
| H5 | 動画が勝っている時は、promptへ「動画優先」を注入しないと生成器は毎回同じmediaを選べない | `x.performance_context` の受け入れ条件に by_media_type が未実装 | Survives | growth-hubの集計に `by_media_type` を追加 |
| H6 | 1回1変数A/Bを守らないと、文言差なのかmedia差なのか分からない | Issue本文が「1回1変数A/B」を明記。R12でもA/B変数の混線が問題化 | Survives | copy variant固定×media差、またはmedia固定×copy差のみ |
| H7 | link-in-replyやthread lengthを同時に変えるとmedia効果が汚染される | R12/R11でlink位置・thread構造・pollが同時に効いているため混線しやすい | Survives | R13はmedia metadata/集計に限定し、投稿文プロンプトは最小変更 |
| H8 | media_typeは投稿後ログだけでなくmetric snapshotにも必要 | 受け入れ条件が `x_post_metric_snapshot` への media_type を要求 | Survives | snapshot集計で欠損時は `unknown` として保持 |
| H9 | media_type不明行を捨てると過去データが薄くなりすぎる | 既存ログはmedia未記録なので、完全除外すると初期の学習量が落ちる | Survives | `unknown` bucketを作り、既知mediaとは分けて表示 |
| H10 | まずDB/metadata/集計を通し、UIは後回しが安全 | 今回の目的はインプレ改善ループ。UI変更はE2Eコストが高い | Survives | Edge/Dart service + tests中心。UI変更なし |

### Result

All 10 hypotheses survive enough to justify R13 as a **media-axis instrumentation PR**, not another prompt-only copy polish PR.

## R13 Implementation Slices

### Slice 1 — write media_type at post time

- Add a stable media classifier:
  - `video`: posted payload has a video media id/url or uses reusable/generated share video
  - `image`: posted payload has image media but no video
  - `text`: no attached media
  - `unknown`: legacy or ambiguous row
- Write `media_type` into `x_post_log.metadata` for every share path.
- Include AI動画シェア経路 (`viral-video-ad-generator` → post) explicitly.

### Slice 2 — surface media_type in metric snapshots

- Ensure `x_post_metric_snapshot` carries `media_type` from metadata or joins back to `x_post_log`.
- Do not discard old rows; bucket missing values as `unknown`.

### Slice 3 — aggregate by media in `x.performance_context`

Return a compact section such as:

```text
Media lift:
- video: avg impressions 123 / n=4 / engagement 2.1%
- image: avg impressions 48 / n=8 / engagement 0.9%
- text: avg impressions 21 / n=6 / engagement 0.4%
Recommendation: hold copy variant constant; test video vs image next.
```

### Slice 4 — prompt injection with guardrails

- If video clearly wins: instruct UniversalXShareService to prefer video media for the next comparable post.
- If sample size is too small: say `media data insufficient` and do not force a media decision.
- Preserve R12 prompt rules unchanged unless directly needed.

### Slice 5 — implementation-independent tests

- Unit test that post metadata includes `media_type` for video/image/text cases.
- Edge/Deno test that `x.performance_context` includes `by_media_type` or `Media lift` with `unknown` bucket handling.
- Dart test that prompt receives the media recommendation line when performance context contains it.

## Minimal E2E Gate

- Implementation-detail independent: tests assert public input/output and persisted metadata, not private helper names.
- Minimal scope: video/image/text metadata classification + performance_context aggregate + prompt injection.
- E2E-Exception likely acceptable if UI routes do not change: Edge/Deno + Dart unit tests cover the external behaviors.

## High-risk Review Gate

- Risk is moderate because it touches analytics metadata, not auth/billing/private data.
- No migration should delete existing data.
- Legacy unknown bucket must preserve past rows.
- Rollback: revert one metadata/aggregation PR; posting still works because media_type is additive.

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue: create/inspect a post log row without media_type and show `x.performance_context` lacks by_media_type.
2. Apply Slice 1-3 first; stop before prompt if aggregation is not reliable.
3. Add Slice 4 only after the aggregate has sample-size guardrails.
4. Run targeted Dart/Deno tests.
5. Let normal CI run.
6. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
7. Merge only after CI is green and issue scope is satisfied.

## Checklist

- [x] Reproduction is clear: media_type is absent from the current A/B loop and #3764 specifies it as missing.
- [x] R13 hypothesis matrix is written.
- [ ] Smallest safe fix is implemented.
- [ ] Analyze/tests/CI are checked.
- [ ] PR notes explain the change and the remaining risk.
