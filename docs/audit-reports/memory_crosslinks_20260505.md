# memory/ crosslinks audit — 2026-05-05 02:24:37

> SECOND_BRAIN 原則 #2 (Autonomous Ingest & Linking) ベースライン.
> Karpathy 流 = 1 file あたり 10-15 outbound `[[link]]` 推奨.

## summary

- total memory/ root .md files: **56**
- healthy (outbound ≥ 10): **0** (0.0%)
- moderate (outbound 1-9): **1** (1.8%)
- orphan-outbound (outbound = 0): **55** (98.2%)
- **isolated** (in = 0, out = 0): **55** (98.2%) ← 最優先 fix

## healthy (outbound ≥ 10)

| file | outbound | inbound |
| --- | ---: | ---: |

## isolated (in=0 / out=0) — Karpathy 流 priority fix

| file | (= どこからも参照されず / どこへも link 張らず) |
| --- | --- |
| `feedback_correction_20260419_wrapup_hook.md` | — |
| `feedback_correction_20260421_dart_zombie_accumulation.md` | — |
| `feedback_success_20260419_wrapup_hook.md` | — |
| `feedback_success_20260420_design_token_batch_template.md` | — |
| `feedback_success_20260420_local_metadata_merge.md` | — |
| `feedback_success_20260420_two_source_triangulation.md` | — |
| `MEMORY.md` | — |
| `project_20260417_win_opus47.md` | — |
| `project_20260417_win_web_disabled.md` | — |
| `project_20260419_ps5.md` | — |
| `project_20260419_wrapup_hook.md` | — |
| `project_20260420_ps3_s11.md` | — |
| `project_20260420_ps4_s17.md` | — |
| `project_20260420_ps4_s18.md` | — |
| `project_20260420_ps4_s19.md` | — |
| `project_20260420_ps4_s20.md` | — |
| `project_20260420_ps4_s21.md` | — |
| `project_20260420_ps4_s22.md` | — |
| `project_20260420_ps4_s23.md` | — |
| `project_20260420_ps4_s24.md` | — |
| `project_20260420_ps4_s25.md` | — |
| `project_20260420_ps4_s26.md` | — |
| `project_20260420_ps4_s27.md` | — |
| `project_20260420_ps4_s28.md` | — |
| `project_20260420_ps4_s29.md` | — |
| `project_20260420_ps4_s30.md` | — |
| `project_20260420_ps5_s15.md` | — |
| `project_20260420_ps5_s27.md` | — |
| `project_20260421_ps2_s18.md` | — |
| `project_20260421_ps4_s31.md` | — |
| `project_20260421_ps4_s32.md` | — |
| `project_20260421_vscode_s_recovery.md` | — |
| `project_20260425_win132_part29.md` | — |
| `project_20260503_win132_part115.md` | — |
| `project_20260503_win132_part116.md` | — |
| `project_20260503_win132_part117.md` | — |
| `project_20260503_win132_part118.md` | — |
| `project_20260503_win132_part119.md` | — |
| `project_20260503_win132_part120.md` | — |
| `project_20260503_win132_part121.md` | — |
| `project_20260503_win132_part122.md` | — |
| `project_20260503_win132_part123.md` | — |
| `project_20260503_win132_part124.md` | — |
| `project_20260504_win132_part126.md` | — |
| `project_20260504_win132_part127.md` | — |
| `project_20260504_win132_part128.md` | — |
| `project_20260504_win132_part129.md` | — |
| `project_20260504_win132_part130.md` | — |
| `project_20260504_win132_part131.md` | — |
| `project_20260504_win132_part132.md` | — |
| `project_20260505_win132_part133.md` | — |
| `project_20260505_win132_part134.md` | — |
| `project_20260505_win132_part135.md` | — |
| `project_20260505_win132_part136.md` | — |
| `project_20260505_win132_part137.md` | — |

## moderate (outbound 1-9) — augment 候補

| file | outbound | inbound |
| --- | ---: | ---: |
| `project_20260505_win132_part138.md` | 1 | 0 |

## orphan-outbound (outbound = 0 / inbound > 0) — 「読まれているが繋いでいない」

| file | inbound |
| --- | ---: |

## 推奨 next action

1. **isolated 55 件**: 関連 atomic notes 10+ を追加 → SECOND_BRAIN #2 違反解消
2. **orphan-outbound 98.2%**: `[[link]]` 慣習が未定着 / 全 file に最低 1 link 追加
3. **healthy 0.0% を 50%+ へ**: baseline 改善目標

## audit script

`PYTHONUTF8=1 python scripts/audit_memory_crosslinks.py`

*Win版#132 part 138 / 2026-05-05 / SECOND_BRAIN baseline 5.0/7 → audit 第 1 例*
