# [Codex CLI 宛] Overdue WBS task batch 9 — 期限 +6-7 日 next 30 件 + 3 close

**date**: 2026-05-05
**from**: Win Claude (= Win版#132 part 153 拡張)
**to**: Win Codex CLI
**priority**: medium-high (= 期限 4/28-4/29 起票 / 6-7 日 overdue)
**rule basis**: `[INSTANCE-ROLES]` 5-question matrix + `[WBS-SYNC]` + `[DYNAMIC-CLAIM]` cap respect (= triage は cap 外)

## Summary

batch 1-8 累計 96 件 triage 済. 本 batch 9 で **#916-1193 next 30 件** triage:

- **既存 spec/script 統合 = 3 件 CLOSE** (= #976/#1173 → wiki-lint skill / #1180 → #1124 dup)
- **Codex hand off = 12 件** (= #925 / #1125 / #1172 / #1174 / #1175 / #1182 / #1183 / #1184 / #1186 / #1187 / #1189 / #1190)
- **Win Claude defer = 14 件 (+1 統合候補)** (= 14 件 spec ship 候補 / #1188 effort_router 既存実装拡張で半分カバー)

= 5-question matrix 累計 **126 件** (= batch 1-8 96 + batch 9 30).

## A. CLOSE 3 件 (= 既存 spec/script 統合 / part 153 で実 CLOSE 済)

| # | issue | merge target | 理由 |
|---|---|---|---|
| 1 | [#976](https://github.com/kanta13jp1/my_web_app/issues/976) Knowledge Vault Lint と index.md/log.md 自動メンテ | **`scripts/knowledge_vault_lint.py` + `/wiki-lint` skill** | part 105 + part 140 で orphan / broken / dup / missing index 全件実装済 |
| 2 | [#1173](https://github.com/kanta13jp1/my_web_app/issues/1173) ナレッジベース自動健康診断 (Lint) と孤立ページ検出 | **同 + #976 dup** | 同 wiki-lint カバー |
| 3 | [#1180](https://github.com/kanta13jp1/my_web_app/issues/1180) GPA フレームワーク細粒度評価ダッシュボード | **#1124 dup** | GPA framework + dashboard 同主題 / canonical = #1124 |

(= 3 件全 part 153 セッション内で gh issue close 済 / merge note コメント追加済)

## B. Codex hand off 12 件 (= 全 NO / 実装 territory)

| # | issue | judge | Q1 | Q2 | Q3 | Q4 | Q5 | 理由 |
|---|---|---|---|---|---|---|---|---|
| 1 | [#925](https://github.com/kanta13jp1/my_web_app/issues/925) サブスク支出+AI APIコスト統合最適化 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | 既存 BudgetFinancialPlannerPage 拡張 + EF |
| 2 | [#1125](https://github.com/kanta13jp1/my_web_app/issues/1125) Build in Public成果化パイプライン | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | T-1 dispatch + dev.to 既存 stack |
| 3 | [#1172](https://github.com/kanta13jp1/my_web_app/issues/1172) 新規アップロード資料 自動要約+関連ノート統合 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | NotebookLM CLI 既存 |
| 4 | [#1174](https://github.com/kanta13jp1/my_web_app/issues/1174) 回答結果マルチフォーマット永続保存 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | NotebookLM CLI download 拡張 |
| 5 | [#1175](https://github.com/kanta13jp1/my_web_app/issues/1175) ユーザープラン別AIリクエスト上限管理 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | EF + RLS + Flutter widget |
| 6 | [#1182](https://github.com/kanta13jp1/my_web_app/issues/1182) 動画バリエーション一括生成 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | Hedra/D-ID API batch processing |
| 7 | [#1183](https://github.com/kanta13jp1/my_web_app/issues/1183) 動画 音声開始 ms 調整 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | ffmpeg + UI input 拡張 |
| 8 | [#1184](https://github.com/kanta13jp1/my_web_app/issues/1184) テキスト→音声合成+動画生成 ワンステップ | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | Hedra/ElevenLabs API 統合 |
| 9 | [#1186](https://github.com/kanta13jp1/my_web_app/issues/1186) WBS ガント外部審査ステータス | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | 既存 WBS UI + status enum 追加 |
| 10 | [#1187](https://github.com/kanta13jp1/my_web_app/issues/1187) 法人設立 WBS テンプレ自動展開 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | WBS template SQL + EF |
| 11 | [#1189](https://github.com/kanta13jp1/my_web_app/issues/1189) 長文プロンプトキャッシュ対応 | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | Anthropic API cache_control 実装 |
| 12 | [#1190](https://github.com/kanta13jp1/my_web_app/issues/1190) GHA APIコスト自動監視+アラート | **Codex** | ❌ | ❌ | ❌ | ❌ | ❌ | GHA workflow + Slack notify |

→ **12 件全件 Codex sprint 3 候補** (= sprint 1 同日 4 件 merged 24% / sprint 2 = batch 8 4 件 / sprint 3 = batch 9 12 件 / 累計 throughput 計測対象).

## C. Win Claude defer 14 件 (+1 既存実装拡張統合候補)

| # | issue | judge | Q1 | Q2 | Q3 | Q4 | Q5 | 種別 |
|---|---|---|---|---|---|---|---|---|
| 1 | [#916](https://github.com/kanta13jp1/my_web_app/issues/916) D-ID 連携 AI アバター動画スタジオ | Win Claude | ✅ | ❌ | ✅ | ✅ | ❌ | 通常 spec / AI-VIDEO-29 / Q4 動画 |
| 2 | [#917](https://github.com/kanta13jp1/my_web_app/issues/917) WBS/学習向け対話型 AI アバターコーチ | Win Claude | ✅ | ❌ | ✅ | ✅ | ✅ | 通常 spec / AI-CHARACTER-24 + AI-VIDEO-29 |
| 3 | [#918](https://github.com/kanta13jp1/my_web_app/issues/918) 合成メディア 同意・透かし・商用ライセンス監査 | **Win Claude (sensitive 第 8 候補)** | ✅ | ❌ | ❌ | ✅ | ✅ | **sensitive (合成メディア倫理)** / AI-VIDEO-29 6/6 必須 + consent screen + watermark |
| 4 | [#924](https://github.com/kanta13jp1/my_web_app/issues/924) パーソナル AI モーニング・ポッドキャスト自動生成 | Win Claude | ✅ | ❌ | ✅ | ❌ | ✅ | 通常 spec / NotebookLM + audio 設計 |
| 5 | [#975](https://github.com/kanta13jp1/my_web_app/issues/975) Query to Wiki: AI 回答永続ナレッジ化 | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / docs + 既存 wiki-* skill 拡張 |
| 6 | [#1123](https://github.com/kanta13jp1/my_web_app/issues/1123) LRM 自己修正プランナー Goal-Plan-Action | Win Claude | ✅ | ❌ | ❌ | ❌ | ✅ | 通常 spec / AI design / persona |
| 7 | [#1124](https://github.com/kanta13jp1/my_web_app/issues/1124) AI 役員 GPA 評価ダッシュボード+トレースデバッグ | Win Claude | ✅ | ❌ | ✅ | ❌ | ✅ | 通常 spec / Q1 schema + Q3 UI + Q5 9 原則 |
| 8 | [#1176](https://github.com/kanta13jp1/my_web_app/issues/1176) GitHub PR 自動レビュー+実行回数制限 | Win Claude | ❌ | ✅ | ❌ | ❌ | ✅ | 通常 spec / 既存 ultrareview + bc58b50b 拡張 + rate limit |
| 9 | [#1177](https://github.com/kanta13jp1/my_web_app/issues/1177) 大規模コンテキスト 1M トークン カスタムリポ管理 | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / architect / context 設計 |
| 10 | [#1178](https://github.com/kanta13jp1/my_web_app/issues/1178) エージェント向けプロジェクトコンテキスト提供 | Win Claude | ✅ | ❌ | ❌ | ❌ | ✅ | **#842 と類似 / 統合候補** = AI役員マルチモーダル現実コンテキスト同期 |
| 11 | [#1179](https://github.com/kanta13jp1/my_web_app/issues/1179) 7 層メモリアーキテクチャ | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / architect / memory 設計 / Karpathy 4 サイクル拡張 |
| 12 | [#1185](https://github.com/kanta13jp1/my_web_app/issues/1185) AI 役員 法人口座開設向け事業計画書自動生成 | Win Claude | ✅ | ❌ | ❌ | ❌ | ✅ | 通常 spec / AI 機能設計 / 法務系 sensitive 軽 |
| 13 | [#1192](https://github.com/kanta13jp1/my_web_app/issues/1192) 異常リクエスト検知+ガードレール | **Win Claude (sensitive 第 5 と隣接)** | ✅ | ❌ | ❌ | ❌ | ✅ | **sensitive (security boundary)** / **#773 PII と統合 or sub-spec** |
| 14 | [#1193](https://github.com/kanta13jp1/my_web_app/issues/1193) 権限と役割分離 マルチモジュールアーキテクチャ | Win Claude | ✅ | ✅ | ❌ | ❌ | ✅ | 通常 spec / architect 直撃 |

(= 14 件 Win Claude territory) + 統合候補:

| # | issue | judge | 統合先 |
|---|---|---|---|
| (15) | [#1188](https://github.com/kanta13jp1/my_web_app/issues/1188) Claude API タスク別自動モデル ルーティング | Win Claude / **既存実装拡張** | **`memory-search-hub` + effort_router (= part 145 PS#5 S115)** で半分カバー / Win Claude が gap 評価 spec 化 |

→ **sensitive 第 8 候補 1 件** (= #918 合成メディア倫理) / 通常 spec 候補 13 件.
→ **#1178 → #842 統合提案** (= 同領域 / context routing).
→ **#1188 → effort_router 拡張提案** (= Win Claude が現状 gap 評価 spec 化).

## 5-question matrix 統計 (累計 = 126 件 / batch 1-9)

| batch | session | 件数 | Codex | Win Claude | CLOSE | 詳細 |
|---|---|---|---|---|---|---|
| 1-7 | part 143-152 | 79 | ~58 | ~17 | ~4 | 既送付 |
| 8 | part 153 | 17 | 4 | 9 | 4 | batch 8 doc |
| **9** | **part 153** | **30** | **12** | **15** | **3** | **本 doc (= 1 既存実装拡張統合候補含)** |
| **累計** | **part 143-153** | **126** | **74** | **41** | **11** | (= Codex 比率 59% / Win Claude 比率 33% / CLOSE 比率 9%) |

## D. Pattern observed (= part 153 同 session 2 batch triage)

1. **既存 script 横展開 CLOSE** (= wiki-lint skill が #976+#1173 二重 cover): **leverage 2x dup-close** 第 1 例
2. **dup pair 検出**: #1124 と #1180 が同主題 = canonical 残し他 close (= #1124 残)
3. **既存実装拡張 hint** (= #1188 effort_router): 「Win Claude が gap 評価 → 拡張 spec」pattern 第 1 例
4. **領域類似 → 統合提案** (= #1178 → #842): 同領域 spec 統合候補化

## E. PR 階層化 chain depth 3 維持

本 doc は PR #2024 に追加 commit (= 3 commit 目 / chain depth 3 維持):

```
main
  └── #2017 (claude/amazing-hypatia-84b710)  ← part 144-151 / 9 spec
        └── #2022 (claude/crazy-jennings-93b113)  ← part 152 / 2 spec
              └── #2024 (claude/spec-patterns-part153)  ← part 153 / PATTERNS + batch 8 + batch 9
```

## Philosophy alignment (= batch 9 doc)

- ✅ PHILOSOPHY-22 #4 6 部署 — Win Claude vs Codex 分担明確化
- ✅ AI-DEV-23 #7 quality-gate — 5-question matrix で誤振分防止
- ✅ INDIE-29 #1 shipping 速度 — 30 件 / ~30 min triage (= 1.0 min/issue / **batch 8 比 -33% 高速化**)
- ✅ SYNERGY-30 #1 cross-instance-pr — 9 batch 累計 126 件
- ✅ BRAIN-32 #5 メンテナンス — 既存 script/spec 統合 3 件 CLOSE で WBS hygiene
- ✅ AI-VIDEO-29 — #918 sensitive 第 8 候補 surface (= 合成メディア倫理 6/6 必須)

## 次回 (= part 154 候補 update)

1. **sprint 1 翌日 KPI 計測** (= 24h+ 後 / 5+ merge 目標)
2. **NotebookLM 14 sources 完成** (= chain merge 後)
3. **memory-search-hub 10/10 hand off 監視**
4. **#773 PII ガードレール sensitive 第 5 spec ship** (+ 第 6-8 候補 backlog: #839 / #843 / #918)
5. **#833 コア/リーフ境界 spec** or **#832 評価データ品質ゲート spec** = 通常 spec ship 候補
6. **#1178 → #842 統合 + #1188 → effort_router 拡張** spec ship (= 統合 spec 第 1 例)
7. **batch 10** = #1194+ next oldest 20-30 件 triage

`[DYNAMIC-CLAIM]` cap 1 件 (= PATTERNS) 遵守 / 本 doc は triage = cap 外.
