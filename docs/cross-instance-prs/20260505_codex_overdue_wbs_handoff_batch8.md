# [Codex CLI 宛] Overdue WBS task batch 8 — 期限 +8-11 日 oldest 13 件 + 4 close

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 153)
**to**: Win Codex CLI
**priority**: medium-high (= 期限 4/25-4/27 起票 / 8-11 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` cap respect (= triage は cap 外 / part 143 確立)

## Summary

batch 1-7 累計 79 件 triage 済. 本 batch 8 で **#768-847 oldest 17 件** triage:

- **既存 spec 統合 = 4 件 CLOSE** (= #841 → #835+#1564 / #845/#846/#847 → #1577 全カバー)
- **Codex hand off = 4 件** (= #794 / #834 / #840 / #844)
- **Win Claude defer (= 次回 spec ship 候補) = 9 件** (= #768 / #772 / #773 / #832 / #833 / #835 / #839 / #842 / #843)

= 5-question matrix 累計 **96 件** (= 79 + 17).

## A. CLOSE 4 件 (= 既存 spec 統合 / part 153 で実 CLOSE 済)

| # | issue | merge target | 理由 |
|---|---|---|---|
| 1 | [#841](https://github.com/kanta13jp1/my_web_app/issues/841) AIセッション自動コンパクション + 実装オンボーディング資料生成 | **#835 + #1564** | #1564 PreCompact spec §3.1-§3.3 で session 圧縮 + 復元 + StatusLine 全カバー / 「新任エンジニア向け実装ブリーフ」 unique scope は #835 で吸収 |
| 2 | [#845](https://github.com/kanta13jp1/my_web_app/issues/845) AI役員向けMCP外部ツール連携OAuth/DCR認証ハブ | **#1577** | MCP_AUTH_HARDENING_SPEC で WorkOS AuthKit + DCR + OAuth + .well-known + PRM/AS metadata + token vault + provider 抽象化 全件包含 |
| 3 | [#846](https://github.com/kanta13jp1/my_web_app/issues/846) AI役員ツール実行の権限スコープと承認ゲート | **#1577** | read/suggest/create/update/delete/send/purchase スコープ + 高リスク CEO 承認 + RLS+EF 二重 check + 承認画面詳細 spec §3 §4 取込済 |
| 4 | [#847](https://github.com/kanta13jp1/my_web_app/issues/847) MCP連携プロンプトインジェクション検知と監査ログ | **#1577** | injection 検知 + 三層分離 + mcp_audit_log + anomaly_score + cross_server_trace 全件取込済 |

(= 4 件 全 part 153 セッション内で gh issue close 済 / merge note コメント追加済)

## B. Codex hand off 4 件 (= 全 NO / 実装 territory)

| # | issue | judge | Q1 | Q2 | Q3 | Q4 | Q5 | 理由 |
|---|---|---|---|---|---|---|---|---|
| 1 | [#794](https://github.com/kanta13jp1/my_web_app/issues/794) Claude Opus 4.7 高解像度画像・図表解析 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | model 切替 + 既存 image upload に Opus 4.7 適用 / EF 拡張のみ |
| 2 | [#834](https://github.com/kanta13jp1/my_web_app/issues/834) AI生成機能の最小E2E品質ゲート | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | GHA workflow + Hurl/Playwright 実装 (= Win Codex GHA territory) |
| 3 | [#840](https://github.com/kanta13jp1/my_web_app/issues/840) Vibe Coding実装向けE2E・ストレステスト自動検証ゲート | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | GHA workflow + k6/Locust 実装 |
| 4 | [#844](https://github.com/kanta13jp1/my_web_app/issues/844) CXOパーソナライズ学習データセットとLoRA実験基盤 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | Supabase + Python script + EF 実装 (= W&B / HuggingFace 統合 / 既存 stack) |

→ **4 件全件 Codex sprint 2 候補** (= sprint 1 同日 4 件 merged 進行中 / 累計 throughput 計測対象).

## C. Win Claude defer 9 件 (= 次回 spec ship 候補 / Q1+ YES)

| # | issue | judge | Q1 | Q2 | Q3 | Q4 | Q5 | 種別 |
|---|---|---|---|---|---|---|---|---|
| 1 | [#768](https://github.com/kanta13jp1/my_web_app/issues/768) Gemini整理術応用AI生活リセットプランナー | Win Claude | ✅ | ❌ | ✅ | ❌ | ✅ | 通常 spec / UI + AI 設計 |
| 2 | [#772](https://github.com/kanta13jp1/my_web_app/issues/772) Writer AI Studio型ナレッジグラフ/RAG検索アシスタント | Win Claude | ✅ | ❌ | ❌ | ❌ | ✅ | 通常 spec / RAG 設計 |
| 3 | [#773](https://github.com/kanta13jp1/my_web_app/issues/773) 全AI機能共通のガードレール・PII監査レイヤー | **Win Claude (sensitive 第 5 候補)** | ✅ | ❌ | ❌ | ❌ | ✅ | **sensitive (PII / AI 横断)** / 共通 4/4 NOT to do/MUST do 適用必須 |
| 4 | [#832](https://github.com/kanta13jp1/my_web_app/issues/832) 評価データ品質ゲートと自己ベンチマーク再設計 | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / 評価 + benchmark 設計 |
| 5 | [#833](https://github.com/kanta13jp1/my_web_app/issues/833) AI実装向けコア/リーフ境界マップ | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / architect 直撃 (= 既存 EF/Flutter 境界 docs 化) |
| 6 | [#835](https://github.com/kanta13jp1/my_web_app/issues/835) AIオンボーディングパックとセッション圧縮導線 | Win Claude | ❌ | ✅ | ❌ | ❌ | ✅ | 通常 spec / docs + SOP (= #1564 PreCompact 統合候補) |
| 7 | [#839](https://github.com/kanta13jp1/my_web_app/issues/839) Vibe Coding向けAI生成UIセキュアサンドボックス | **Win Claude (sensitive 第 6 候補)** | ✅ | ❌ | ✅ | ❌ | ✅ | **sensitive (security boundary / sandbox)** / VIBE-30 + AI-DEV-23 7/7 必須 |
| 8 | [#842](https://github.com/kanta13jp1/my_web_app/issues/842) AI役員へのマルチモーダル現実コンテキスト同期 | Win Claude | ✅ | ❌ | ✅ | ❌ | ✅ | 通常 spec / sensor + context routing 設計 |
| 9 | [#843](https://github.com/kanta13jp1/my_web_app/issues/843) 重大決断向けレッドチーム検証モード | **Win Claude (sensitive 第 7 候補)** | ✅ | ✅ | ❌ | ❌ | ✅ | **sensitive (high-stakes / AI safety)** / AI-CHARACTER 8/8 + COLLAB-26 + VIBE-30 必須 |

→ **sensitive 第 5-7 候補 3 件** (= #773 PII / #839 sandbox / #843 redteam) / 通常 spec 候補 6 件.
→ **part 154-160** で逐次 spec ship 候補 (= 1 session 1-2 spec / 7-15x leverage 維持).

## 5-question matrix 統計 (累計 = 96 件 / batch 1-8)

| batch | session | 件数 | Codex | Win Claude | CLOSE | 詳細 |
|---|---|---|---|---|---|---|
| 1-7 | part 143-152 | 79 | ~58 | ~17 | ~4 | 既送付 |
| **8** | **part 153** | **17** | **4** | **9** | **4** | **本 doc** |
| **累計** | **part 143-153** | **96** | **62** | **26** | **8** | (= Codex 比率 65% / Win Claude 比率 27%) |

## D. Codex sprint 2 候補化 (= sprint 1 同日 24% merged 進行中)

batch 8 Codex hand off **4 件** (= #794 / #834 / #840 / #844) を **sprint 2** 候補に追加:

- sprint 1 = batch 5-7 で hand off 済 / 同日 4 件 merged (= 24%) / 累計 throughput 計測中 (= part 154 で評価)
- sprint 2 = batch 8 hand off 4 件 / 期待 KPI = 24h 内 1+ merged (= sprint 1 ベースライン超え)

## E. PR 階層化 chain (= 第 4 段検討候補)

本 doc は PR #2024 に追加 commit (= chain depth 3 維持) or PR #2025 で第 4 段検討:

```
main
  └── #2017 (claude/amazing-hypatia-84b710)  ← part 144-151 / 9 spec
        └── #2022 (claude/crazy-jennings-93b113)  ← part 152 / 2 spec
              └── #2024 (claude/spec-patterns-part153)  ← part 153 / PATTERNS 統合 + 本 batch 8 (= 候補)
```

= depth 3 維持 (= chain depth ≤ 3 推奨 / PATTERNS Ch5.4 失敗 pattern 「depth 過深で reviewer 混乱」回避).

## Philosophy alignment (= batch 8 doc 自体)

- ✅ PHILOSOPHY-22 #4 6 部署 — Win Claude vs Codex 分担明確化
- ✅ AI-DEV-23 #7 quality-gate — 5-question matrix で誤振分防止
- ✅ INDIE-29 #1 shipping 速度 — 17 件 / 30 min triage (= 1.8 min/issue)
- ✅ SYNERGY-30 #1 cross-instance-pr — 8 batch 累計 96 件
- ✅ BRAIN-32 #5 メンテナンス — 既存 spec 統合 4 件 CLOSE で WBS hygiene

## 次回 (= part 154 候補)

1. **sprint 1 翌日 KPI 計測** (= 24h+ 後 / 5+ merge 目標)
2. **NotebookLM 14 sources 完成** (= chain merge 後)
3. **memory-search-hub 10/10 hand off 監視**
4. **#773 PII ガードレール** = sensitive 第 5 spec ship (= 1 session 1 spec)
5. **#833 コア/リーフ境界 spec** or **#832 評価データ品質ゲート spec** = 通常 spec ship 候補
6. **batch 9** = #768 等残 9 件 + 次 oldest 10 件 triage

`[DYNAMIC-CLAIM]` cap 1 件 (= PATTERNS) 遵守 / 本 doc は triage = cap 外.
