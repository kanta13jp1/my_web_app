# ブランドガイドライン v1 — 自分株式会社

Status: v1 (Accepted baseline / **ブランドボイス最終確定・ロゴ実アセットは CEO 確認待ち**)
Date: 2026-06-09
Owner: Win Claude (L3 設計レーン / architect / UI design lane)
WBS: `dce3f86c-7330-4aeb-bb97-891b040313b0` ブランドガイドライン v1 (milestone `mvp-launch`)
Sources: [`DESIGN.md`](DESIGN.md) (UI トークン正本) / [`PHILOSOPHY.md`](PHILOSOPHY.md) (ミッション / 9 原則) / [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) / [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) (アプリ内ボイス) / [`X_ACCOUNT_OPERATIONS_DESIGN.md`](X_ACCOUNT_OPERATIONS_DESIGN.md) (SNS ボイス)

---

## 0. このドキュメントについて

- **目的**: タスク記述「**logo / color / typography / voice**」の通り、ブランドの**アイデンティティ層**を定義する。アプリ・SNS・ブログ・LP・プレスを横断して**一貫したブランド体験**を出すための baseline。
- **DESIGN.md との境界 (重複しない)**: [`DESIGN.md`](DESIGN.md) は **UI トークンの正本** (カラー hex / フォントスタック / コンポーネントスタイル / 余白 / 角丸)。本書はその**上位のブランド意味づけ** (ブランド約束・**ボイス&トーン**・ロゴ運用・色の意味・適用ルール) を扱い、UI 値は DESIGN.md を**参照**する (hex やフォント名を再掲しない)。役割分担: DESIGN.md = 「どう実装するか」 / 本書 = 「何を伝え、どう振る舞うか」。
- **位置づけ**: [`PHILOSOPHY.md`](PHILOSOPHY.md) (理念) → **本書 (ブランド表現の規範)** → 各タッチポイント ([`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) アプリ内 / [`X_ACCOUNT_OPERATIONS_DESIGN.md`](X_ACCOUNT_OPERATIONS_DESIGN.md) SNS)。part 246 オンボーディング・part 247 X 運用が個別に触れた「声・トーン」を**ここで正本化**する。
- **v1 注記 / CEO 確認待ち**: ブランドボイスの最終確定と**ロゴの実アセット**は CEO (ユーザー) 判断。本書は理念・既存 UI から codify した叩き台 v1 (商標/法的保護は business-legal レーンであり本書の対象外)。

## 1. ブランドの核 (Brand Core)

- **ブランド約束 (Brand Promise)**: 「**AI と一緒に、人生を会社のように経営する**」。ユーザーは自分の社長 (原則 1)、6 部署 (本社/人事/R&D/財務/横断) で人生を運営し、**昨日の自分**より前進する (原則 8)。
- **ミッション駆動** (原則 2): ブランドは「ミッション・コアバリューの明確化と追跡を助ける」立場。単なる ToDo ではなく「自分の経営」を体現する。
- **パーソナリティ**: ① **穏やかな mentor** (命令でなく提案 / 原則 3-4) ② **プロフェッショナル × 生命力** ([`DESIGN.md`](DESIGN.md) コンセプト「ダーク × オレンジ」と一致) ③ **誠実** (誇張せず、検証された事実を語る)。
- **差別化**: 多社 AI (AI大学) × 6 部署の一貫体験。競合 21 社の単機能ではない。

## 2. ボイス & トーン (Voice & Tone) — 本書の中核

全タッチポイント (アプリ内コピー / SNS / ブログ / 通知 / エラー文) で共通の声。

**5 つの声の原則**:
1. **優しい mentor** — 寄り添い、命令しない。「〜しましょう」より「〜すると…が見えます」。
2. **昨日の自分基準** — 他人比較・順位煽りをしない。本人の前進を主語にする (原則 8)。
3. **短く・明快** — 専門用語を避け、1 文 1 意。日本語ファースト。
4. **誠実・検証ファースト** — 誇張・未検証主張・「最強」断定をしない。AI ツール/競合の数値は一次情報 or 自社実測のみ ([AI-TOOL-VERIFY])。
5. **煽らない** — FOMO・射幸性・中毒性を使わない (原則 9 / AI_CHARACTER)。

| 場面 | ✅ Do | ❌ Don't |
|------|------|---------|
| アプリ内 (オンボーディング) | 「睡眠を 1 行記録しましたね。明日は前日比が見られます」 | 「今すぐ全部入力しないと意味がありません」 |
| エラー/空状態 | 「まだ記録がありません。まず 1 つだけ試してみましょう」 | 「データがありません」(突き放す) |
| SNS (X) | 「今週 onboarding 設計を ship。狙いは初回 7 日の…」(build-in-public) | 「業界最強の自己管理アプリ爆誕!!」(誇張) |
| AI mentor | 提案 + 実行可否はユーザー | 断定的な指示 |

- アプリ内ボイスの具体は [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) §3/§5、SNS ボイスは [`X_ACCOUNT_OPERATIONS_DESIGN.md`](X_ACCOUNT_OPERATIONS_DESIGN.md) §5 が本書を継承する。

## 3. ロゴ運用 (Logo Usage)

- **位置づけ**: 実ロゴアセットの最終デザインは CEO 判断 (v1 では運用ルールのみ定義)。
- **基本ルール (v1)**: ① 十分な余白 (clear space = ロゴ高さの 1/2 以上) を確保 ② ダーク背景を基本 (DESIGN.md ダークテーマ) ③ アクセントオレンジは強調点のみ。
- **やってはいけない**: 縦横比を崩す / 影・効果を勝手に追加 / 低コントラスト背景に置く / 文言を改変する。
- アイコン/ファビコン/OG 画像など実装アセットは DESIGN.md「アイコンガイドライン」+ `web/` 実装に従う。

## 4. カラーの意味 (Color Meaning)

**UI の正確な値 (hex / 役割) は [`DESIGN.md`](DESIGN.md) §カラーパレットが正本**。本書はブランド上の*意味*のみ定義する (値を再掲しない)。

- **ダーク (ベース)** = 集中・プロフェッショナル・夜でも目に優しい土台。
- **オレンジ (アクセント)** = 生命力・行動喚起・前進。CTA や「今日の一歩」に限定使用し、乱用しない。
- **インディゴ等の補助** = 落ち着き・信頼。データ俯瞰 (ダッシュボード) の文脈。
- 原則: **アクセントは行動を促す箇所に絞る**。全面オレンジは避ける (エネルギーの希釈回避)。

## 5. タイポグラフィ (ブランド観点)

**フォントスタック・行間・禁則の実値は [`DESIGN.md`](DESIGN.md) §タイポグラフィが正本**。ブランド観点のみ:

- **日本語ファースト** — 可読性最優先、装飾フォントを使わない (誠実・プロフェッショナル)。
- **静かな階層** — 見出しで叫ばない。情報の階層は太さ/余白で示し、過剰な装飾をしない (原則: 中身=価値)。

## 6. 適用 (Application across Touchpoints)

| タッチポイント | ボイス | ビジュアル | 参照 |
|---------------|--------|-----------|------|
| アプリ内 | §2 mentor トーン | DESIGN.md トークン | [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) |
| X (SNS) | §2 + build-in-public | OG/スクショは本番実データ | [`X_ACCOUNT_OPERATIONS_DESIGN.md`](X_ACCOUNT_OPERATIONS_DESIGN.md) |
| ブログ | §2 誠実・解説的 | — | T-1 dispatch |
| LP / プレス | §2 + 価値訴求 | ダーク×オレンジ | LP A/B `3fe22123` / PR Times `88d0ac29` |

- **一貫性のルール**: どのタッチポイントでも §1 ブランド約束と §2 声を崩さない。媒体ごとに表現は変わってよいが、**人格 (穏やか・誠実・昨日の自分基準) は不変**。

## 7. ブランド NG (やってはいけない)

- 他人比較・順位で煽る / FOMO・射幸性 / 中毒的設計 (原則 9)。
- 誇張・未検証の性能/競合主張・「最強」断定 ([AI-TOOL-VERIFY] / part 247 でルール化済)。
- ダークパターン (解約を隠す等) / トーンの逸脱 (急に命令口調)。
- ブランド約束と無関係な便乗発信。

## 8. Deferred / 非スコープ

- **ロゴ実アセット・フルビジュアルアイデンティティ (イラスト/モーションブランド)**: デザイン実制作は別途 (CEO/デザイン判断)。
- **商標・法的保護**: business-legal レーン ([DYNAMIC-CLAIM] 禁止) のため本書外。
- **UI トークンの拡張**: [`DESIGN.md`](DESIGN.md) が正本。本書では再定義しない。

## 9. 原則整合 (Philosophy Alignment)

[`PHILOSOPHY.md`](PHILOSOPHY.md) 9 原則で **7+/9 ✅**: 原則 1 (CEO 感 / ブランド最終決定は CEO) · 原則 2 (ミッション駆動) · 原則 3-4 (mentor / 6 部署) · 原則 8 (昨日の自分基準 / 他人比較しない) · 原則 9 (ウェルビーイング / 煽らない)。[`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md) (誠実・操作回避) + [AI-TOOL-VERIFY] (検証ファースト) に整合。

## 10. 運用 (Living Document)

- ボイスは各タッチポイント (246/247) の実コピーと往復しながら薄く保つ。ロゴ実アセット確定後に §3 を更新。
- ブランドボイス最終確定後に Status を「Confirmed」へ (現状 v1 = baseline draft)。重要判断は [`adr/`](adr/README.md) に ADR 化。

## Links

- UI トークン正本: [`DESIGN.md`](DESIGN.md) / 理念: [`PHILOSOPHY.md`](PHILOSOPHY.md) / AI 人格: [`AI_CHARACTER_PRINCIPLES.md`](AI_CHARACTER_PRINCIPLES.md)
- ボイス適用先: [`CUSTOMER_ONBOARDING_DESIGN.md`](CUSTOMER_ONBOARDING_DESIGN.md) (アプリ) / [`X_ACCOUNT_OPERATIONS_DESIGN.md`](X_ACCOUNT_OPERATIONS_DESIGN.md) (SNS)
- 関連タスク: LP A/B `3fe22123` / PR Times `88d0ac29`
- 実行計画: WBS (project-gantt) / task `dce3f86c-7330-4aeb-bb97-891b040313b0`
- マイルストーン: `mvp-launch` (1,000 users / 2026-09-30)
