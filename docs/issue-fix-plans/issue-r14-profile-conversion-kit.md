# R14 Profile Conversion Kit Plan

- Round: R14
- Trigger: R13b completed; per-post quality levers are now mostly exhausted.
- Source: `docs/X_GROWTH_PLAYBOOK.md` says the remaining bottleneck is account-level discovery/conversion, especially OP-1 bio rewrite + pinned tweet.

## Goal

Turn the operator-only OP-1 action into a copy-ready, low-friction execution kit:

1. exact bio variants under X's 160-character limit,
2. exact pinned tweet variants,
3. screenshot/alt-text checklist,
4. first-30-minute manual action checklist,
5. measurement notes for profile clicks, follows, and site visits.

This must **not** automate profile editing, pinning, replies, likes, DMs, follows, or engagement. Those remain manual red lines.

## 10-hypothesis adversarial verification

| # | Hypothesis | Verdict | Consequence |
| --- | --- | --- | --- |
| H1 | Per-post copy/media/poll quality is no longer the largest immediate bottleneck | Survives | Shift to account-level conversion |
| H2 | OP-1 bio + pinned tweet is the highest-ROI remaining lever | Survives | R14 targets profile conversion |
| H3 | The current playbook is correct but not execution-ready enough | Survives | Add copy-ready assets, not just strategy |
| H4 | Automating profile writes/pinning is unsafe or unavailable | Survives | Manual-only, no API wiring |
| H5 | A too-clever bio will underperform because visitors need instant clarity | Survives | Use identity + product + cadence + URL |
| H6 | The pinned tweet must answer “what is this?” before asking for a click | Survives | Structure: identity → problem → built thing → proof → CTA |
| H7 | Pinned tweet should not look like a sales page | Survives | Build-in-public, first-user feedback CTA |
| H8 | Screenshots and alt text improve trust and accessibility | Survives | Include screenshot and alt-text recipe |
| H9 | Golden-hour actions should remain human/manual | Survives | Checklist only, no auto-like/reply/follow |
| H10 | This change should be documentation-only until profile changes are manually applied | Survives | Docs PR, no runtime code |

## Implementation scope

Update `docs/X_GROWTH_PLAYBOOK.md` with:

- a `R14 実行キット` section,
- 3 bio variants with character counts and use cases,
- 2 pinned tweet variants,
- screenshot/alt-text checklist,
- manual execution steps,
- measurement checklist.

## Non-goals / red lines

- No X profile-write automation.
- No tweet-pin automation.
- No automatic replies, DMs, likes, follows, unfollows, or engagement farming.
- No scraping new targets beyond existing allowed trend/news inputs.

## Done criteria

- [ ] Playbook has copy-paste-ready bio variants.
- [ ] Playbook has a copy-paste-ready pinned tweet.
- [ ] Manual execution checklist is clear enough to run from mobile.
- [ ] Red lines remain explicit.
- [ ] PR is docs-only.
