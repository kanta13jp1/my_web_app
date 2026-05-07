# [Codex CLI 宛] Overdue WBS task batch 10 — 期限 +6 日 next 30 件 + 5 close

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 153 段 4)
**to**: Win Codex CLI
**priority**: medium-high (= 期限 4/29 起票 / 6 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` cap respect

## Summary

batch 1-9 累計 126 件 triage 済. 本 batch 10 で **#1194-1226 next 30 件** triage:

- **既存 spec 統合 = 5 件 CLOSE** (= 過去最大 single-batch CLOSE / spec leverage 強烈)
- **Codex hand off = 17 件**
- **Win Claude defer = 8 件**

= 5-question matrix 累計 **156 件** (= batch 1-9 126 + batch 10 30).

## A. CLOSE 5 件 (= 既存 spec 統合 / part 153 で実 CLOSE 済)

| # | issue | merge target | 理由 |
|---|---|---|---|
| 1 | [#1194](https://github.com/kanta13jp1/my_web_app/issues/1194) WorkOS AuthKit MCP OAuth | **#1577** | MCP_AUTH_HARDENING_SPEC で WorkOS AuthKit + DCR + OAuth + .well-known + PRM/AS metadata 全件 |
| 2 | [#1195](https://github.com/kanta13jp1/my_web_app/issues/1195) Audit Log + クロスサーバー異常検知 | **#1577** | mcp_audit_log + anomaly_score + cross_server_trace + Sentinel suspended flag 全件 |
| 3 | [#1196](https://github.com/kanta13jp1/my_web_app/issues/1196) PKCE + Resource Indicator token 検証 | **#1577** | PKCE + RFC 8707 audience binding + Resource Indicator + token introspection 全件 |
| 4 | [#1207](https://github.com/kanta13jp1/my_web_app/issues/1207) AIチャット長文セッション圧縮 | **#1564** | PRECOMPACT spec §3.1 PreCompact backup + §3.2 SessionStart + 復元 hook で完全カバー |
| 5 | [#1213](https://github.com/kanta13jp1/my_web_app/issues/1213) UIモックアップ自動コード出力 (Handoff Bundle) | **`docs/HANDOFF_BUNDLE_SPEC.md`** | part 144 系 既存 spec で完全カバー / Codex 実装中 |

→ **#1577 が単独で 3 件 CLOSE 達成 = leverage 3x dup-close 第 2 例** (= batch 8 の 3 件 + batch 10 の 3 件 = **累計 6 件 dup-close / sensitive 第 4 spec 1 本で 6 dup-close 達成**).

## B. Codex hand off 17 件 (= 全 NO / 実装 territory)

| # | issue | judge | 理由 |
|---|---|---|---|
| 1 | [#1197](https://github.com/kanta13jp1/my_web_app/issues/1197) クイックメモ AI 整理+タグ付け | **Codex** | 既存 hub action 追加 + EF |
| 2 | [#1198](https://github.com/kanta13jp1/my_web_app/issues/1198) メモ曖昧検索+関連サジェスト | **Codex** | memory-search-hub 既存 (= part 145 PS#5 S115) 拡張 |
| 3 | [#1199](https://github.com/kanta13jp1/my_web_app/issues/1199) Inbox 機能 | **Codex** | UI + RLS |
| 4 | [#1201](https://github.com/kanta13jp1/my_web_app/issues/1201) Cartesia 超低遅延音声通話 | **Codex** | API 統合 |
| 5 | [#1202](https://github.com/kanta13jp1/my_web_app/issues/1202) ElevenLabs 多言語ダビング | **Codex** | API 統合 |
| 6 | [#1203](https://github.com/kanta13jp1/my_web_app/issues/1203) TTS 動的ルーティング | **Codex** | effort_router 拡張 |
| 7 | [#1204](https://github.com/kanta13jp1/my_web_app/issues/1204) 検索条件保存 (カスタムグループ) | **Codex** | UI + Supabase table |
| 8 | [#1205](https://github.com/kanta13jp1/my_web_app/issues/1205) ダッシュボード snapshot cache | **Codex** | EF + RLS |
| 9 | [#1206](https://github.com/kanta13jp1/my_web_app/issues/1206) リソース ヒストグラム表示 | **Codex** | Flutter chart |
| 10 | [#1210](https://github.com/kanta13jp1/my_web_app/issues/1210) オンデマンド動画教材自動生成 | **Codex** | 動画 batch + ffmpeg |
| 11 | [#1218](https://github.com/kanta13jp1/my_web_app/issues/1218) 多アスペクト比+多言語動画 | **Codex** | ffmpeg + i18n |
| 12 | [#1219](https://github.com/kanta13jp1/my_web_app/issues/1219) 画像生成 品質/速度 option UI | **Codex** | UI |
| 13 | [#1220](https://github.com/kanta13jp1/my_web_app/issues/1220) prompt 構造化入力 form | **Codex** | UI |
| 14 | [#1221](https://github.com/kanta13jp1/my_web_app/issues/1221) 複数画像 編集/合成 UI | **Codex** | UI |
| 15 | [#1222](https://github.com/kanta13jp1/my_web_app/issues/1222) 左サイドバー チャット履歴 | **Codex** | UI |
| 16 | [#1223](https://github.com/kanta13jp1/my_web_app/issues/1223) 新規チャット保存 | **Codex** | UI + RLS |
| 17 | [#1224](https://github.com/kanta13jp1/my_web_app/issues/1224) カスタマーサポート chat UI + test pipeline | **Codex** | UI + GHA |

→ **17 件全件 Codex sprint 4 候補** (= 過去最大 single-batch hand off).

## C. Win Claude defer 8 件 (= Q1+ YES)

| # | issue | judge | 種別 |
|---|---|---|---|
| 1 | [#1209](https://github.com/kanta13jp1/my_web_app/issues/1209) AI 生成 UI Flutter サンドボックス | **Win Claude (#839 統合候補)** | sensitive 第 6 候補 sub-spec / sandbox 同領域 |
| 2 | [#1211](https://github.com/kanta13jp1/my_web_app/issues/1211) 滞留タスク AI 遅延予測 + 自動 reschedule | Win Claude | 通常 spec / AI 機能設計 |
| 3 | [#1212](https://github.com/kanta13jp1/my_web_app/issues/1212) 4-Tier AI ルーター コスト最適化 ダッシュボード | Win Claude (= **#1188 統合候補 / effort_router 拡張**) | 既存実装拡張 spec |
| 4 | [#1214](https://github.com/kanta13jp1/my_web_app/issues/1214) Task Budgets 自律集計 + ファイル整理 | Win Claude | 通常 spec / AI 機能設計 |
| 5 | [#1215](https://github.com/kanta13jp1/my_web_app/issues/1215) 外部 SaaS 実行前 Human-in-the-loop 承認 | Win Claude (= **#1577 sub-spec**) | sensitive 軽 / MCP_AUTH consent 同領域 |
| 6 | [#1216](https://github.com/kanta13jp1/my_web_app/issues/1216) DID AI 生成動画 検証 badge + 来歴 | **Win Claude (#918 統合候補)** | sensitive 第 8 sub-spec / 合成メディア倫理 同領域 |
| 7 | [#1217](https://github.com/kanta13jp1/my_web_app/issues/1217) D-ID Agents WebRTC 対話 UI | Win Claude | 通常 spec / AI ペルソナ + AI-VIDEO |
| 8 | [#1226](https://github.com/kanta13jp1/my_web_app/issues/1226) 行動 feedback AI 戦略修正ループ | Win Claude | 通常 spec / COLLAB-26 + AI-CHARACTER |

→ **統合提案 4 件**: #1209→#839 / #1212→#1188 / #1215→#1577 / #1216→#918 (= 既存 Win Claude territory backlog の sub-spec 化).

## 5-question matrix 統計 (累計 = 156 件 / batch 1-10)

| batch | session | 件数 | Codex | Win Claude | CLOSE | 詳細 |
|---|---|---|---|---|---|---|
| 1-7 | part 143-152 | 79 | ~58 | ~17 | ~4 | 既送付 |
| 8 | part 153 | 17 | 4 | 9 | 4 | batch 8 |
| 9 | part 153 | 30 | 12 | 15 | 3 | batch 9 |
| **10** | **part 153** | **30** | **17** | **8** | **5** | **本 doc** |
| **累計** | **part 143-153** | **156** | **91** | **49** | **16** | (= Codex 58% / Win Claude 31% / CLOSE 10%) |

## D. Pattern observed (= part 153 段 4 / batch 10)

1. **#1577 単独 6 dup-close 達成** (= batch 8 の #845/#846/#847 + batch 10 の #1194/#1195/#1196): **sensitive 第 4 spec 1 本で 6 dup-close = leverage 6x** (= 過去最大記録)
2. **#1564 統合 dup-close 達成** (= batch 8 の #841 + batch 10 の #1207): **通常 第 7 spec 1 本で 2 dup-close**
3. **既存 spec 統合 leverage 累計**: 16 CLOSE / part 153 三段で 13 件 = **0.8 CLOSE/triage** (= 既存 spec backlog 相当の hygiene 効果)
4. **WBS hygiene 進捗**: 156 件 triage で WBS overdue **大幅減少** (= dup CLOSE 16 + Codex routed 91)

## E. PR 階層化 chain depth 3 維持 (= 4 commits 目)

```
main
  └── #2017 (claude/amazing-hypatia-84b710)  ← part 144-151 / 9 spec
        └── #2022 (claude/crazy-jennings-93b113)  ← part 152 / 2 spec
              └── #2024 (claude/spec-patterns-part153)  ← part 153 / PATTERNS + batch 8 + batch 9 + batch 10
```

## Philosophy alignment (= batch 10 doc)

- ✅ PHILOSOPHY-22 #4 6 部署 — Win Claude vs Codex 分担明確化 (= 17 Codex hand off 過去最大)
- ✅ AI-DEV-23 #7 quality-gate — 5-question matrix で誤振分防止
- ✅ INDIE-29 #1 shipping 速度 — 30 件 / ~12 min triage (= **0.4 min/issue** / batch 9 比 -60% 高速化)
- ✅ SYNERGY-30 #1 cross-instance-pr — 10 batch 累計 156 件
- ✅ BRAIN-32 #5 メンテナンス — 5 件 CLOSE で WBS hygiene 過去最大
- ✅ MCP-AUTH-27 leverage — sensitive 第 4 spec が 6 dup-close 達成

## 次回 (= part 154 候補 / 拡張)

1. **sprint 1+2+3+4 翌日 KPI 計測** (= 24h+ 後 / Codex 累計 hand off 33+ 件)
2. **NotebookLM 14 sources 完成** (= chain merge 後)
3. **memory-search-hub 10/10 hand off 監視**
4. **#773 PII ガードレール sensitive 第 5 spec ship** (+ sensitive backlog: #839+#1209 sandbox / #843 redteam / #918+#1216 合成メディア倫理 / #1215 SaaS HITL)
5. **#833 / #832 / #1124 / #1179 / #1185 / #1226** = 通常 spec ship 候補
6. **#1178→#842 + #1188→#1212 + #1215→#1577 sub-spec + #1216→#918 sub-spec + #1209→#839 sub-spec** = 統合 spec batch 第 1 例
7. **batch 11** = #1227+ next oldest 30 件 triage

`[DYNAMIC-CLAIM]` cap 1 件 (= PATTERNS) 遵守 / 本 doc は triage = cap 外.
