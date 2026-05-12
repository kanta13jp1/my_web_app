# Corporate Formation Runbook — 自分株式会社 法人化 evidence template

> **Win版#132 part 190 (2026-05-09)**: Win Claude self deliverable / GA Launch Readiness Gate axis C+D evidence template.
> 親 spec: [`docs/GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) §4 (Axis C+D — Corporate Formation Runbook).
> Issue: [#1662](https://github.com/kanta13jp1/my_web_app/issues/1662) (= 会社設立・法務/税務・銀行ゲートをGA準備WBSに接続する).

## 1. 本 runbook の役割

法人化に必要な **人間決定 + evidence URL** を 1 page に集約. AI (Win Claude / Win Codex) の guardrail = 本 runbook の checklist 維持 + evidence URL collation のみ. **fabricate 禁止**.

GA Launch Readiness Gate の axis C (= Legal Entity) + axis D (= Banking) の SSOT として運用.

## 2. 法人化 7 step + evidence template

### Step 1: 商号 / 本店所在地確定 (= 期限 2026-06-15)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 商号 (= 株式会社名) | _(= TBD)_ | _(= 商号調査結果 PDF / 法務局 e-Gov)_ |
| 本店所在地 | _(= TBD)_ | _(= 賃貸契約書 OR 持ち家謄本 PDF)_ |
| 印鑑 (= 代表者印 / 銀行印 / 角印) | _(= 発注済 / 未発注)_ | _(= 印鑑屋発注書 OR 受領書)_ |
| 商号類似調査 | _(= 完了 / 未)_ | _(= 法務局 商号調査結果)_ |
| 事業目的 (= 定款記載) | _(= 1 行)_ | _(= 定款 draft PDF)_ |

**WBS task_id**: `108a24dc-abee-4bec-90f4-56c8b558f616`
**判断者**: User (= CEO 決定)
**AI guardrail**: ❌ 商号 / 本店住所 fabricate / 推奨 / 提案禁止. ✅ 商号調査結果 URL 受け取り → checklist mark.

### Step 2: 司法書士 / 税理士契約 (= 期限 2026-06-30)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 司法書士事務所 | _(= TBD)_ | _(= 契約書 PDF)_ |
| 司法書士電話 / メール | _(= TBD)_ | _(= 契約書記載)_ |
| 司法書士費用 (= 設立 + 顧問) | _(= ¥XX,000)_ | _(= 見積書 PDF)_ |
| 税理士事務所 | _(= TBD)_ | _(= 契約書 PDF)_ |
| 税理士電話 / メール | _(= TBD)_ | _(= 契約書記載)_ |
| 税理士費用 (= 顧問月額) | _(= ¥XX,000/月)_ | _(= 見積書 PDF)_ |

**WBS task_id**: `0fa38c4f-0d9e-43e3-8ca0-2643c8888e28`
**判断者**: User
**選定参考**: [`docs/research/2026-04-25_professional_advisor_selection_checklist.md`](research/2026-04-25_professional_advisor_selection_checklist.md)
**AI guardrail**: ❌ 司法書士 / 税理士の specific 名前推奨禁止. ✅ 選定 checklist 維持 + 比較表 template 提供のみ.

### Step 3: 株式会社設立登記 (= 期限 2026-09-30)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 定款認証 (= 公証役場) | _(= 完了日 YYYY-MM-DD)_ | _(= 認証済定款 PDF / mask 可)_ |
| 設立登記申請 (= 法務局) | _(= 申請日)_ | _(= 申請書 PDF / mask 可)_ |
| 登記完了日 | _(= YYYY-MM-DD)_ | _(= 登記事項証明書 PDF / mask 可)_ |
| 法人番号 (= 13 桁) | _(= TBD)_ | _(= 国税庁 法人番号公表サイト URL)_ |
| 資本金 (= ¥) | _(= ¥XXX,XXX)_ | _(= 資本金払込証明書 PDF)_ |

**WBS task_id**: `5e34304e-...` (= 株式会社設立登記)
**判断者**: User + 司法書士
**AI guardrail**: ❌ 法人番号 / 資本金 fabricate. ✅ 国税庁公表サイト URL の format check のみ (= 13 桁数字 validation).

### Step 4: 法人口座開設 (= 期限 2026-10-15)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 銀行名 | _(= TBD / 例: 三井住友 / 楽天 / GMO あおぞら)_ | _(= 開設通知書 PDF)_ |
| 支店名 | _(= TBD)_ | _(= 通帳コピー / 口座番号 mask)_ |
| 口座種別 | _(= 普通 / 当座)_ | _(= 通帳コピー)_ |
| 口座番号 (= mask: 7 桁の下 4 桁のみ) | _(= ****1234)_ | _(= 通帳コピー / 全桁は暗号化保管)_ |
| 暗号化保管先 | `payments_legal_entities` table | (= Supabase RLS / columnar encryption) |

**WBS task_id**: `c1436a87-...` (= 法人口座開設)
**判断者**: User + 銀行
**AI guardrail**: ❌ 口座番号生成 / mask 解除 禁止. ✅ mask format check (例: `****\d{4}` regex) + 暗号化保管 trigger のみ.

### Step 5: 初期事業計画 3 年 PL (= 期限 2026-08-31)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 売上見込 Y1 / Y2 / Y3 | _(= ¥M, ¥M, ¥M)_ | _(= PL spreadsheet URL)_ |
| 費用見込 Y1 / Y2 / Y3 | _(= ¥M, ¥M, ¥M)_ | _(= PL spreadsheet URL)_ |
| 利益見込 Y1 / Y2 / Y3 | _(= ¥M, ¥M, ¥M)_ | _(= PL spreadsheet URL)_ |
| 主要 KPI 3 (= MAU / MRR / ARPU 等) | _(= リスト)_ | _(= KPI dashboard URL)_ |
| 競合比較 (= 21 社 vs 自分株式会社) | _(= サマリ)_ | [`docs/competitor-reports/2026-04-18.md`](competitor-reports/2026-04-18.md) |

**WBS task_id**: `282c7660-...` (= 初期事業計画 3 年 PL)
**判断者**: User + 税理士
**AI guardrail**: ❌ 売上 / 費用 数値 fabricate. ✅ template 提供 + 競合 / 業界平均 reference data 提供のみ.

### Step 6: Seed 投資家リスト (= 期限 2026-08-31 / future axis F)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| 投資家候補 list | _(= Notion DB row count)_ | _(= Notion DB URL / private)_ |
| Pitch 送付済 / 未送付 | _(= X / Y)_ | _(= Notion property)_ |
| 1st meeting 完了 | _(= count)_ | _(= Notion property)_ |
| Term Sheet 受領 | _(= count)_ | _(= Notion property)_ |
| Term Sheet 受諾 | _(= count)_ | _(= 契約書 PDF / mask 可)_ |

**WBS task_id**: `f9c7fd37-...` (= Seed 投資家リスト)
**判断者**: User
**AI guardrail**: ❌ 投資家へ直接 pitch 送信 / contact 取得禁止. ✅ Notion DB structure template 提供のみ.

### Step 7: Pitch Deck v1.0 (= 期限 2026-08-31 / future axis F)

| Field | Value | Evidence URL |
|-------|-------|--------------|
| Slide 1 (= title / vision) | _(= 完成 / draft / 未)_ | _(= Google Slides URL / 限定公開)_ |
| Slide 2-4 (= problem / solution / 競合) | _(= 完成 / draft / 未)_ | _(= 同上)_ |
| Slide 5-7 (= 商品 / プロダクト) | _(= 完成 / draft / 未)_ | _(= 同上)_ |
| Slide 8-10 (= traction / KPI) | _(= 完成 / draft / 未)_ | _(= 同上)_ |
| Slide 11-15 (= team / 財務 / ask) | _(= 完成 / draft / 未)_ | _(= 同上)_ |

**WBS task_id**: `69d5bbad-...` (= Pitch Deck v1.0)
**判断者**: User
**AI guardrail**: ❌ Pitch Deck 内容を fabricate. ✅ template skeleton + 競合 reference 提供のみ.

## 3. AI 役割 boundary

| AI / Claude / Codex がやること | やらないこと |
|--------------------------------|--------------|
| ✅ Step 1-7 checklist 維持 | ❌ 商号 / 本店住所 fabricate |
| ✅ Evidence URL collation | ❌ 司法書士 / 税理士 specific 名前推奨 |
| ✅ WBS task_id 紐付け | ❌ 銀行口座番号 生成 / mask 解除 |
| ✅ 期限 monitor + alert | ❌ 投資家へ直接 contact / pitch 送付 |
| ✅ 評価 EF (= `payments_legal_entities` 暗号化) 維持 | ❌ Pitch Deck の事業内容 fabricate |
| ✅ template 提供 (= PL / Pitch Deck skeleton) | ❌ 売上 / 費用 数値 fabricate |
| ✅ 競合 / 業界平均 reference data 提供 | ❌ Term Sheet 内容 / 契約書 fabricate |

## 4. Paddle / legal SSOT integration (= post-設立)

設立登記完了後 (= Step 3 ✅):

1. Paddle dashboard に **正式 entity name + 住所 + 法人番号** 登録 (= user 手動 / 1 step)
2. `payments_legal_entities` table に row insert (= 暗号化 / RLS)
3. `paddle-hub` から評価 EF が参照 (= [REAL-DATA] / 暫定 placeholder 削除)

```sql
-- 設立登記完了後の row insert (= user 1 step)
INSERT INTO payments_legal_entities (
  entity_name_jp,    -- = 正式商号
  entity_address,    -- = 本店所在地
  registration_no,   -- = 法人番号 13 桁
  capital_jpy,       -- = 資本金
  formation_date     -- = 登記完了日
) VALUES (
  pgp_sym_encrypt('株式会社XXX', current_setting('app.encryption_key')),
  pgp_sym_encrypt('東京都...', current_setting('app.encryption_key')),
  pgp_sym_encrypt('1234567890123', current_setting('app.encryption_key')),
  500000,
  '2026-09-30'
);
```

## 5. GA Gate 統合 (= axis C+D 進捗)

GA Launch Readiness Gate での axis C+D 進捗計算:

```
axis C (Legal Entity) % = (Step 1-3 完了数 / 3) × 100
axis D (Banking)      % = (Step 4 完了 ? 100 : 0)
```

```
Step 1: 商号確定        → axis C 33%
Step 2: 司法書士契約    → axis C 67%
Step 3: 設立登記        → axis C 100% ✅
Step 4: 口座開設        → axis D 100% ✅
Step 5: PL 3 年計画     → axis F 33% (= future)
Step 6: 投資家リスト    → axis F 67% (= future)
Step 7: Pitch Deck      → axis F 100% (= future)
```

GA Eligible = axis C + axis D = 100% (= 必須).

## 6. WBS task_id 一覧 (= [WBS-SYNC] 紐付け)

```
108a24dc-abee-4bec-90f4-56c8b558f616  Step 1 商号・本店所在地    due 2026-06-15
0fa38c4f-0d9e-43e3-8ca0-2643c8888e28  Step 2 司法書士・税理士契約 due 2026-06-30
5e34304e-...                          Step 3 株式会社設立登記     due 2026-09-30
c1436a87-...                          Step 4 法人口座開設         due 2026-10-15
282c7660-...                          Step 5 初期事業計画 3 年 PL due 2026-08-31
f9c7fd37-...                          Step 6 Seed 投資家リスト    due 2026-08-31
69d5bbad-...                          Step 7 Pitch Deck v1.0      due 2026-08-31
```

## 7. 関連 docs

- 親 spec: [`docs/GA_LAUNCH_READINESS_GATE_SPEC.md`](GA_LAUNCH_READINESS_GATE_SPEC.md) §4
- 法人形態判断: [`docs/research/2026-04-25_legal_entity_decision.md`](research/2026-04-25_legal_entity_decision.md)
- 商号 / 本店判断: [`docs/research/2026-04-25_trade_name_head_office_decision.md`](research/2026-04-25_trade_name_head_office_decision.md)
- 司法書士 / 税理士選定: [`docs/research/2026-04-25_professional_advisor_selection_checklist.md`](research/2026-04-25_professional_advisor_selection_checklist.md)
- Issue: [#1662](https://github.com/kanta13jp1/my_web_app/issues/1662) (= GA 準備 WBS 接続)

## 8. PHILOSOPHY-22 alignment (= 7+/9 ✅)

- 主要実装: 法人化 7 step を 1 runbook に集約 + AI guardrail 明示 + WBS task_id 紐付け
- 該当原則:
  - #1 (CEO 感) — 7 step を user が見て次アクション選択
  - #2 (mission) — IPO 道筋に必要な法人化体制
  - #3 (mentor) — checklist 化で user の負荷軽減
  - #4 (6 部署) — 法務 / 財務 / 商品 部署 cover
  - #6 (時間) — evidence template で audit time 削減
  - #7 (資産負債) — 法人 entity = 資産化 visualize
  - #8 (KPI) — axis %% を昨日の自分と比較
  - #9 (IPO) — 法人化 = IPO 前段
- 整合性スコア: **8/9 ✅** ([PHILOSOPHY-22] gate 通過)

---

> **Spec ship**: Win版#132 part 190 (2026-05-09 JST). GA Launch Readiness Gate axis C+D evidence template (= #1662 follow-up self deliverable).
