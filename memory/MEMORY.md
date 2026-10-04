# MEMORY Index — 自分株式会社

Master Brain のローカル索引。各ファイルは `memory/` 配下に置き、日付 + スコープで命名。
NotebookLM Master Brain (jibun-master-brain ノートブック) にも同内容を蓄積する。

## 2026-10-04 (WEB版 — PR #5523 地方選候補者集計 都道府県議会/市区町村議会内訳 マージ完了)

- `feedback_success_20261004_local_election_assembly_breakdown.md` — 既存 assemblyCategory 命名再利用 / 3言語パイプライン後方互換拡張 / "dirty"のみ反応するPR babysitポリシー / auto-merge イベントでの監視密度調整+trigger即時削除。
- `feedback_correction_20261004_send_later_classifier_retry.md` — send_later classifier一時エラー時はツール指示のリトライ上限を遵守し拒否と一時故障を区別して報告。
- `project_20261004_web_pr5523_babysit.md` — このリポジトリは bot commit 高頻度で behind/unknown が定常状態・dirtyのみ実コンフリクト / WEB版の役割は機能継承(GitHub MCPのみ) / SUPABASE_ANON_KEY_PROD未設定によるWBS-SYNC skip理由。

<!-- wrap-up 20261004
未完了: 0 件 (PR #5523 は 2026-09-29 17:44 UTC squash merge 完了・main 反映済み)

次回優先候補 (Step 6 参照):
- 🟡 次回 update_kokumin_local_endorsements cron 実行後、prefecturalCount/municipalCount の実データが
  正しく UI (election_victory_page) に反映されているか目視確認 (このセッションはFlutter/ブラウザ環境なし)
- 🟡 test/models/election_intelligence_test.dart の新規2件・test/ui/.../official_endorsement_view_model_test.dart を
  実際に `flutter test` で実行し green を確認 (このセッションでは未実行)
- 🟢 Design Accessibility Audit (PR本文で未完了と明記) のレビュアー/自動エージェントによる正式チェック
- 🟢 WEB版 PR babysit loop の "behind/unknown無視・dirtyのみ反応" ポリシーを docs/SUBAGENT_ORCHESTRATION_POLICY.md 等に明文化する価値があるか検討
-->

## 2026-09-21 — Skill curation

- [Agent skill curation completion](vault/decision_20260921_skill_curation_completion.md) — canonical adoption decisions, upstream integration, offline validation, and review handoff.

## 2026-07-11 (WEB版 — SEO 監査 H7 完了 + 監査 doc 化)

- `feedback_success_20260711_web_seo_h7.md` — 既存 SSR 再利用 / 高リスク path の独立ヘルパー抽出 test 化 / 実測 honest pushback (H8 Skip) / 会話監査の doc 正本化。
- `feedback_correction_20260711_web_seo_h7.md` — WEB版制約: AskUserQuestion/send_later 不通→テキスト確認 / Supabase 403→smoke cron 依存 / actions_list 巨大→file 抽出 / squash 後 branch 作り直し。
- `project_20260711_web_seo_h7.md` — blog.publish_post(blog_posts) vs blog.auto_publish(hub_data) の canonical 可否差異 / #3925/#3927/#3941 / H8 font 技術根拠 / WBS-SYNC skip 理由。

<!-- wrap-up 20260711
未完了: 0 件 (SEO H7 = #3925/#3927/#3941 全マージ済)
残タスク (自動 / 要操作なし): task#12 blog SSR 本番検証 → 日次 smoke cron (06:07 JST) が自動確認

次回優先候補 (Step 6 参照):
- 🟡 blog.public.view の live smoke に「list→実 id→view 200」チェーンを追加 (view 単体の回帰保証)
- 🟡 auto_publish 記事の blog_posts 化 (hub_data 由来記事も canonical 集約可能に / H7 残)
- 🟢 CWV 非破壊改善: 初回 JS/フォント遅延ロード (H8 Skip の代替アプローチ)
- 🟢 独自ドメイン移行の設計メモ (H6 保留分 / 影響範囲・手順・リスクの洗い出しのみ)
-->


## 2026-05-18 lint index hydration

These entries are lightweight anchors for repo-managed memory notes so
`knowledge_vault_lint.py` can distinguish intentionally retained session
memory from true orphan files.

- [[feedback_success_20260420_local_metadata_merge]]
- [[feedback_success_20260420_two_source_triangulation]]
- [[feedback_correction_20260419_wrapup_hook]]
- [[feedback_correction_20260421_dart_zombie_accumulation]]
- [[feedback_success_20260419_wrapup_hook]]
- [[feedback_success_20260420_design_token_batch_template]]
- [[feedback_success_20260711_web_seo_h7]]
- [[feedback_correction_20260711_web_seo_h7]]
- [[project_20260711_web_seo_h7]]
- [[project_20260417_win_opus47]]
- [[project_20260417_win_web_disabled]]
- [[project_20260419_ps5]]
- [[project_20260419_wrapup_hook]]
- [[project_20260421_vscode_s_recovery]]
- [[project_20260420_ps3_s11]]
- [[project_20260420_ps4_s17]]
- [[project_20260420_ps4_s18]]
- [[project_20260420_ps4_s19]]
- [[project_20260420_ps4_s20]]
- [[project_20260420_ps4_s21]]
- [[project_20260420_ps4_s22]]
- [[project_20260420_ps4_s23]]
- [[project_20260420_ps4_s24]]
- [[project_20260420_ps4_s25]]
- [[project_20260420_ps4_s26]]
- [[project_20260420_ps4_s27]]
- [[project_20260420_ps4_s28]]
- [[project_20260420_ps4_s29]]
- [[project_20260420_ps4_s30]]
- [[project_20260420_ps5_s15]]
- [[project_20260420_ps5_s27]]
- [[project_20260421_ps2_s18]]
- [[project_20260421_ps4_s31]]
- [[project_20260421_ps4_s32]]
- [[project_20260425_win132_part29]]
- [[project_20260503_win132_part115]]
- [[project_20260503_win132_part116]]
- [[project_20260503_win132_part117]]
- [[project_20260503_win132_part118]]
- [[project_20260503_win132_part119]]
- [[project_20260503_win132_part120]]
- [[project_20260503_win132_part121]]
- [[project_20260503_win132_part122]]
- [[project_20260503_win132_part123]]
- [[project_20260503_win132_part124]]
- [[project_20260504_win132_part126]]
- [[project_20260504_win132_part127]]
- [[project_20260504_win132_part128]]
- [[project_20260504_win132_part129]]
- [[project_20260504_win132_part130]]
- [[project_20260504_win132_part131]]
- [[project_20260504_win132_part132]]
- [[project_20260505_win132_part133]]
- [[project_20260505_win132_part134]]
- [[project_20260505_win132_part135]]
- [[project_20260505_win132_part136]]
- [[project_20260505_win132_part137]]
- [[project_20260505_win132_part138]]
- [[ingest_20260505_karpathy-ai-external-brain-2026-05-05]]

## 2026-04-21 (VSCode版 — S-recovery / dart zombie cleanup)

- `project_20260421_vscode_s_recovery.md` — 7h+ セッション異常 (dart zombie 11 本 + claude 暴走 2 本 + stale lock) → 15 min cleanup で復旧 / VSCode handoff PR done/ archive (0c729cc4)
- `feedback_correction_20260421_dart_zombie_accumulation.md` — dart analyze 0 bytes 無限 hang は analysis-server zombie 疑い / 4h+ dart process kill テンプレ

## 2026-04-20 (VSCode版 — DESIGN token batch template)

- `feedback_success_20260420_design_token_batch_template.md` — Python + dart fix + flutter analyze pipeline w/ full shade map (green/red/orange shade50-900) for 600+ Colors.X → hex replacements

## 2026-04-19 (PS版#5 — on-call バグ修正)

- `project_20260419_ps5.md` — CI修復(esm.sh→npm) + AI大学URL修正 + ホーム履歴recordFeatureTap統合

## 2026-04-19 (VSCode版 — wrapup hook tightening)

- `feedback_success_20260419_wrapup_hook.md` — PostToolUse 正規表現を厳格化して heredoc/echo 誤マッチを排除。`if: "Bash(git *)"` でさらに scope。ライブ検証成功。
- `feedback_correction_20260419_wrapup_hook.md` — Edit tool は Read 前提。指定ブランチと作業ブランチの乖離時はユーザー確認必須。
- `project_20260419_wrapup_hook.md` — PostToolUse hook の wiring (settings.json + shell script + jq + JSON out) 参照実装。

## 2026-04-19 (WEB版 — mobile setup)

- `feedback_success_20260419_web_mobile.md`
- `feedback_correction_20260419_web_mobile.md`
- `project_20260419_web_mobile_setup.md`

## 2026-04-17 (Windows版)

- `project_20260417_win_opus47.md`
- `project_20260417_win_web_disabled.md`

<!-- wrap-up 20260419
未完了: 0 件 (wrapup-hook タスクは完了・push 済み)

次回優先候補 (Step 6 参照):
- 🔴 指定ブランチ claude/fix-mobile-keyboard-overlap-6kjnm で実際の keyboard overlap を調査・修正
- 🟡 AI大学: 学習リマインダー通知バッチ (notification-center EF action)
- 🟡 Rule 17 WF health チェック (最近失敗した run の集計)
- 🟢 t-1 ブログ dispatch (未投稿 draft があれば)
-->
