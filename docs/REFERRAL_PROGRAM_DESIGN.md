# リファラル / 紹介プログラム 設計 v1

> **作成**: 2026-06-10 (Win版#132 part 257 / Claude Code #1) — WBS `c9a3e346`「リファラル / 紹介プログラム」(business-marketing / paying-100) の成果物。
> **完了範囲 = 本設計の正本化のみ**。実装の残作業は WBS `f0fd0b22`「紹介プログラム実装」(impl / beta / owner: codex) で継続する。報酬の数値・規約の発効・公開開始はすべて【CEO確定】(料金プラン `dd9f690b` 連動)。**本書の存在 ≠ プログラム運用開始**。

## 0. 位置づけ (3 層 + 関連正本)

| 層 | 担当 | 正本 |
|---|---|---|
| Offer / 規約 / 不正対策 / KPI の設計 | 本書 (c9a3e346) | docs/REFERRAL_PROGRAM_DESIGN.md |
| 招待リンク・報酬付与の実装 | WBS f0fd0b22 (codex) | lib/ + supabase/functions/growth-hub/ |
| 報酬原資 (料金プラン・課金) | WBS dd9f690b +【CEO確定】 | docs/PRD_V1.md §料金 (確定後) |

関連: `docs/PRD_V1.md` (原則: 雇用主閲覧なし等) / `docs/MVP_SCOPE.md` / `docs/B2B_PROPOSAL_V1.md` (B2B2C 一括導入は本プログラム対象外 — §2-4) / `docs/RELEASE_CYCLE_POLICY.md` (公開時は隔週 note で告知)。

## 1. 実在する実装 (2026-06-10 verify 済み)

設計の前提となる「すでに動いているもの」。出典 file 付き — 本節の主張はすべて当日 read で確認済み。

| 領域 | 実在物 | 出典 |
|---|---|---|
| DB | `referral_codes` (user_id UNIQUE / total_referrals / successful_referrals / bonus_points_earned) | `supabase/migrations/20251106120000_growth_features.sql` |
| DB | `referrals` (referred_user_id UNIQUE / bonus_points / **status: pending・completed・expired** / completed_at) | 同上 |
| DB | `referral_tracking` (UTM 流入計測) | `supabase/migrations/20260402000010_viral_ad_tables.sql` |
| EF | growth-hub に referral action 群 (`ensureReferralCode` 8-retry 一意生成 / `applyPendingReferral`) | `supabase/functions/growth-hub/index.ts` |
| ガード | self-referral は no-op / referred_user 1 回のみ (UNIQUE + 既存チェックで冪等) | 同上 `applyPendingReferral` |
| 現行報酬 | **500 bonus_points 固定 / sign-up 時に即 status='completed'** | 同上 |
| UI | `/referral` (URL の紹介コード capture → ログイン後 apply / 招待リンク + share) | `lib/pages/referral_page.dart` / `referral_program_page.dart` / `widgets/referral_share_card.dart` |
| 計測 | funnel signal `touch_referral` / `signup_submit_referral` | `supabase/functions/growth-hub/index.ts` |

f0fd0b22 の codex 自記録 (migration `20260421070000`): Done = referral.list 実テーブル接続 + /referral 統一 + UTM 招待リンク。**Next = 報酬 redemption UI / leaderboard / 紹介経由 sign-up attribution の本番 smoke test** (進捗 25% はこの残作業を指す)。

## 2. Offer 設計 (Refer-a-friend)

### 2-1. 基本形 = give-get 双方向

| 対象 | 報酬 (案 — 全数値【CEO確定】) | 付与タイミング |
|---|---|---|
| 紹介者 | Pro 1 ヶ月無料クレジット ×1 / 成立紹介 | 被紹介者の activation 成立時 (§3) |
| 被紹介者 | Pro 1 ヶ月無料 (初回登録特典に上乗せ) | 自身の activation 成立時 |

give-get にする理由: 紹介リンクは受け手にも明示的な得がないと踏まれない (片側報酬は転換率が出にくい)。被紹介者側報酬は「招待された人だけの特典」として LP/共有カード文言に載せる。

### 2-2. 課金前フェーズの fulfillment (現状の最大ギャップ)

「1 ヶ月無料」は課金が存在して初めて意味を持つが、現時点で料金プラン (`dd9f690b`) もStripe 接続 (`ca38e2d2`) も未確定・未稼働。よって**即時付与は不可能**であり、次のクレジット累積 (accrual) 方式を採る:

- 現行の `bonus_points` (500pt = 紹介 1 件) を**内部台帳としてそのまま維持**する (schema・既存付与実績を壊さない)。
- 課金開始時に「500pt = Pro 1 ヶ月無料クーポン 1 枚」の交換レートで清算する【CEO確定 / レート変更権は規約 §5-6 で留保】。
- ユーザー向け文言は課金開始まで「紹介ポイント (課金開始時に Pro 無料期間と交換)」と表記し、「今すぐ 1 ヶ月無料」とは**書かない** (履行できない約束をしない)。

不採用案と理由: (a) 即時 Pro 機能解放 — Pro/Free の機能差自体が未確定で解放対象を定義できない。(b) 現金・ギフト券等価 — 景表法/資金決済法の検討が必要になり MVP 段階の管理コストに合わない (将来再評価は §9)。

### 2-3. 上限 (cap)

紹介者 1 人あたりの報酬上限: 年 12 ヶ月分【CEO確定 / 案】。超過分の紹介はカウントのみ (leaderboard 用) で報酬なし。cap はインセンティブ設計と不正対策 (§4) を兼ねる。

### 2-4. 対象外

B2B2C ライセンス一括導入 (`docs/B2B_PROPOSAL_V1.md`) の従業員招待は本プログラムの報酬対象外 (法人契約側で精算されるため二重インセンティブになる)。実装上は法人ライセンス経由 sign-up に紹介コードを併用させない (f0fd0b22 残作業へ — §7)。

## 3. activation 条件 (即時 completed の是正)

現状は sign-up と同時に `status='completed'` + 500pt 付与 — 捨てアカウント量産で報酬を乱獲できる。次の 2 段階に変える:

1. **signed_up**: 紹介コード付き sign-up 成立 → `referrals.status='pending'` で記録 (報酬は未付与)。
2. **activated**: 被紹介者が登録後 7 日以内に 3 日以上利用【CEO確定 / 案】→ `status='completed'` + 双方に報酬。7 日経過で未達なら `status='expired'`。

設計上の好材料 (verify 済み): `referrals.status` は **DEFAULT 'pending' で pending/completed/expired を最初から想定した schema** になっており、現行 EF が即 'completed' を insert しているだけ。つまり **schema 変更ゼロ**で、(a) insert を pending 開始に変更 (b) activation 判定 job (daily cron or growth-hub action) の 2 点で実装できる (f0fd0b22 残作業へ — §7)。

「利用」の定義は既存の利用 signal (touch 系) から選定し、判定 job 実装時に固定する (新規イベント計測を作らないこと — 既存 signal 優先)。

## 4. 不正対策

| # | 対策 | 状態 |
|---|---|---|
| 1 | self-referral 拒否 (referrer == referred は no-op) | ✅ 実装済 (growth-hub) |
| 2 | 被紹介者 1 人 1 回 (referred_user_id UNIQUE + 冪等チェック) | ✅ 実装済 (schema + EF) |
| 3 | activation 条件 (§3) — 捨てアカウントに報酬を出さない | 設計 → f0fd0b22 |
| 4 | 紹介者あたり報酬 cap (§2-3) | 設計 → f0fd0b22 |
| 5 | 異常検知 threshold: 同一紹介者への activated が 24h に N 件超【CEO確定 / 案 5】で自動保留 + 手動 review (admin_analytics に件数出すだけで開始可) | 設計 → f0fd0b22 |
| 6 | 不正認定時の報酬没収 + アカウント停止権の規約明記 | 規約 §5 |

multi-account (同一人物の別メール) の機械的検出 (device fingerprint / IP) は**今は作らない** — 顧客 0 の段階では過剰で、誤検知の害の方が大きい。#3-5 の組合せで採算を悪化させ、観測されたら #5 の手動 review で対処する (再評価条件: 月間 activated 100 件超)。

## 5. 規約骨子 (公開前に法務観点【CEO確定】)

1. 適用範囲: 本プログラムは個人プラン利用者向け。法人一括導入は対象外 (§2-4)。
2. 報酬付与条件: activation (§3) 成立時。条件未達・期限切れは付与なし。
3. 報酬の性質: 内部ポイント (課金開始後に無料期間と交換 / §2-2)。換金・譲渡不可。
4. 上限: §2-3 の cap。
5. 不正行為 (self-referral 偽装・複数アカウント・spam 送付) 認定時は報酬没収 + 利用停止ができる。
6. プログラムの変更・中断・終了の権利を運営が留保 (交換レート含む)。
7. 個人情報: 紹介者には被紹介者の登録有無・activation 状態のみ表示し、利用内容は表示しない (PRD 原則「本人以外への内容開示なし」と整合)。
8. 準拠法・問合せ窓口。

## 6. KPI / 計測

- **K-factor = (招待送信数 / アクティブユーザー) × (招待 → activated 転換率)**。1.0 超 = 自己増殖だが、初期目標は補助チャネルとして 0.15-0.3【CEO確定 / 案】。
- funnel 対応 (既存 signal をそのまま使う / 新規計測は作らない):

| 段階 | 計測 |
|---|---|
| 招待リンク表示/共有 | `touch_referral` |
| リンク経由流入 | `referral_tracking` (UTM) |
| sign-up 成立 | `signup_submit_referral` + `referrals` (pending) |
| activation 成立 | `referrals.status='completed'` (§3 実装後) |

- 観測場所: 既存 admin_analytics / growth dashboard に referral funnel 行を追加 (f0fd0b22 残作業へ)。

## 7. 実装残作業 (→ f0fd0b22 / owner: codex)

f0fd0b22 自記録の Next 3 件 + 本設計で追加 4 件:

1. (既記録) 報酬 redemption UI — §2-2 の「ポイント → 無料期間交換」前提で。
2. (既記録) leaderboard / ranking view。
3. (既記録) 紹介経由 sign-up attribution の本番 smoke test。
4. (本設計) `applyPendingReferral` の insert を `status='pending'` 開始に変更 + activation 判定 job (§3 / schema 変更ゼロ)。
5. (本設計) 紹介者 cap (§2-3) + 異常検知 threshold (§4-5)。
6. (本設計) 法人ライセンス経由 sign-up の紹介コード無効化 (§2-4)。
7. (本設計) admin_analytics へ referral funnel 表示 (§6)。

着手順は 4 → 5 → 1 を推奨 (報酬ロジックの正しさが UI より先)。

## 8. 発効条件

以下が揃った時点で公開 (それまで本プログラムは**非公開・設計のみ**):

1. 報酬数値・cap・activation 閾値の【CEO確定】(本書の案数値の承認 or 修正)。
2. 規約 (§5 骨子の条文化) の CEO 承認 + LP/共有カードへの文言反映。
3. §7-4 (activation 2 段階化) の実装完了 — 即時 completed のまま公開すると §4 が機能しない。
4. 公開告知は隔週リリース note (`docs/RELEASE_CYCLE_POLICY.md`) に載せる。

## 9. Deferred (今やらない)

- 現金・ギフト券報酬 / アフィリエイト型 (景表法・資金決済法検討が前提)。
- device fingerprint 等の機械的 multi-account 検出 (§4 — 月間 activated 100 件超で再評価)。
- 紹介経由の B2B リード報酬 (B2B は `f3cd4740` Lead 管理と別設計)。
- 多言語展開 (EN) — LP 多言語化と同時に。

## 改訂履歴

| 日付 | 版 | 変更 |
|---|---|---|
| 2026-06-10 | v1 | 初版 (part 257 / WBS c9a3e346 完了成果物 / 実装は f0fd0b22 継続) |
