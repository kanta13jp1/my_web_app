---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-07-31
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-07-28 (Win Claude part346) — 0 byte 化インシデントの訂正 + 恒久ガード + read-only 再設計
**種別**: 前回 (part342) 記録の訂正 + 再発時の被害遮断 (プロダクト機能変更なし)

### 訂正: cron は truncation については実質無罪

2026-07-21 の記録は `JibunKK-InjectRulesAutoSync` (毎日 03:30) を「第一容疑」とし、MEMORY.md では ⏰ 期限つき項目として「毎日 03:30 再発しうる」と扱っていた。**この位置づけを訂正する。**

追加調査で判明したこと:

- **3 晩 (07-22/23/24) cron は発火し、truncation はゼロ**。毎晩同じ挙動なのに被害は 1 回だけ = cron 犯人説を弱める
- **メカニズムが不在**: dirty tree では `git pull` は overwrite 拒否で abort しファイルに触れない / `post-merge`・`post-checkout`・`post-rewrite` hook は 1 つも存在しない / `sync_inject_rules.py --apply` は `write_text(HOME, ...)` のみで **repo 外にしか書かない** (repo 側へ書く `--reverse` は排他グループで cron からは呼ばれない)
- **Defender は 07-21 に修復・検疫を一切していない** (Id 1116/1117/1015 = 0 件)
- **プロセス帰属は誰も記録していなかった** (Object Access 監査 OFF・Sysmon 未導入) → **遡及的な証明は不可能**
- 「pull が abort し続けて配布ルールが stale」も**外れ**だった: worktree 版 7588B と origin/main 版 7515B の差はちょうど 73 行分の CRLF で、内容は一致

**結論**: truncation の原因は既存データでは証明できず、3 晩再発していない稀事象。原因追跡は前向き計装に一本化し、恒久防御は「拒否」側に置く方針へ転換した。

### 実装したもの

1. **CI guard** (PR #4368 / merged): `.github/workflows/` と `.claude/` の tracked ファイルが「main で非空 → PR head で 0 byte」になったら fail。この 2 つの木は**空でも無言で壊れる**唯一の領域 (0 byte の workflow は走らないだけ、0 byte の `.claude` 設定は hook が消えるだけ) で、他ツリーは build/実行が即失敗するため射程外。削除は許可 (retire は削除が正しい操作)。変更集合は three-dot・サイズ比較は base tip (merge-base だと `feature-releases-sync.yml` 型を取り逃す)
2. **cron の read-only 再設計**: `sync_inject_rules.py` に `--from-ref` を追加し、canonical を作業ツリーでなく git ref から読む。cron 側は `git pull` を廃し `git fetch` + `--from-ref origin/main` へ。これで **cron は作業ツリーに触れる能力を完全に失う**。既定は従来通り作業ツリー読み (開発者のローカル編集を無視しないため)
3. **一時的な forensic watcher** (`scripts/watch_protected_files.ps1`): 0 byte 化の瞬間に `Win32_Process` を全コマンドライン付きでダンプ。**repo には一切書かず**ログは repo 外。**捕獲 or 30 日で自己終了**。時刻非依存 (03:30 相関は n=1 で、その cron 自体が無罪になったため、時刻を鍵にするのは偶然に計器を合わせる行為)

**cron を直す理由も変わった** — truncation の fix ではなく、「worktree がクリーンな晩に `git pull origin main` が成功し、**Codex の WIP branch に main を無断マージする**」という別の実在リスクへの対処である (git の定義通りの動作)。

### 残る限界 (正直な記載)

watcher が名指しできるのはスナップショット時点で**生存しているプロセス**のみ。数ミリ秒で exit する犯人なら時刻とファイル一覧しか取れない — それ自体が 4688 プロセス生成監査へエスカレーションすべき signal となる。

### Philosophy Alignment (Win Claude part346)

- 主要実施: 未証明の原因断定を訂正 + 恒久 CI guard + cron の read-only 化 + 期限つき計装
- 該当原則: 1 (CEO 感: 射程・sunset・強制点をすべてユーザーが決定) / 6 (資本=時間: 沈黙する破壊を CI で止め将来の調査時間を回収) / 7 (資産負債: CI/CD と設定を守る資産を追加し、未証明の因果を負債として明示訂正)
- 整合性スコア: 3/9 ✅ — インシデント対応・基盤整備のため機能設計向けの判定基準は適用外
- 特記: **最大の教訓は前回と同じ形で自分に返ってきた** — 07-21 は「自動レポートが未検証の復元先を推奨していた」ことが最大の発見だったが、その記録自身が cron を「第一容疑」と書いていた。訂正しなければ同じ過ちの再生産になる

### セッション記録: Claude Schedule daily-report (2026-07-30 00:02 UTC / WEB版)

**種別**: 日次レポート + 競合モニタリング + ロードマップ推進

#### 実施内容

1. **日次メトリクス取得**: 総ユーザー 61人 / 新規リクエスト 0件 / 未対応 131件 / 直近24h コミット 55件
2. **競合新機能調査 (WebSearch)** — 主要3社:
   - **Notion v3.6**: AI エージェントがカレンダー・通話・DOCX/XLSX/PPTX に対応。Notion Mail 廃止 (2026-09-22) 発表 → 移行難民狙いの LP 準備チャンス
   - **Slack**: 2026-07-28 に 30+ AI 機能追加・Slackbot 分析 Business+ 拡張
   - **GitHub**: Code Quality GA (2026-07-20) + GitHub Models 廃止 (2026-07-30) + Copilot に Claude Opus 5 追加
3. **GitHub Issue auto-review 確認**: 0件 (アクション不要)
4. **日次レポート更新**: `docs/daily-reports/2026-07-30.md` に競合詳細・AI提案追記
5. **X 投稿**: Supabase Edge Function 直接アクセス不可 (ネットワークポリシー) → 手動投稿推奨文を daily report に記録
6. **Schedule ヘルスチェック**: curl exit 56 (ネットワークポリシーで Supabase REST 直接アクセス不可 / GHA 経路は正常稼働)

#### 競合インサイト (本日の最重要発見)

- **Notion Mail 廃止 (09-22)** が移行需要を生む可能性 → 8月中に移行 LP を準備
- **GitHub Models 廃止 (07-30)** で AI API 比較コンテンツへの検索需要が増加中 → AI大学コンテンツ強化
- **SKILL.md の業界標準化** (GitHub Copilot + OpenAI Codex 0.146.0 が採用) → 自社 skill 資産の可搬性棚卸しを推奨

#### AI アクション提案

1. Notion Mail 廃止 (09-22) に合わせた移行 LP セクション追加 (8月末目標)
2. AI大学に「GitHub Models 廃止後の代替 AI API 比較」コンテンツ追加 (SEO 流入狙い)
3. agent-board 機能を #buildinpublic で X 投稿 (Notion AI Agent との差別化訴求)

#### Philosophy Alignment

- 該当原則: 4 (商品=価値 / 競合を観測し自社の差別化を更新する) / 6 (資本=時間 / 自動化で調査時間をゼロトークンへ) / 8 (KPI / ユーザー 61人→次の milestone へ向けた施策立案)
- ネットワークポリシー制約: Supabase Edge Function / REST への直接 HTTP アクセス不可 → GHA 経路が正規パス (既知)

### セッション記録: Claude Schedule daily-report (2026-07-31 00:02 UTC / WEB版)

**種別**: 日次レポート + 競合モニタリング + ロードマップ推進

#### 実施内容

1. **日次メトリクス確認**: GHA 生成済み (総ユーザー 61人 / 新規リクエスト 0件 / 未対応 131件)
2. **競合新機能調査 (WebSearch)** — 主要3社:
   - **Notion v3.6**: HTMLブロック追加 (ボタン/フォーム埋め込み) / Async Markdown API / AIミーティング音声対応 / MCP 改善
   - **Slack**: 30+ AI 機能追加 (Slackbot AI / Today & Activity ビュー / Focus Mode / MCP連携 / Slack CRM 独自ドメインメール)
   - **GitHub**: Code Quality GA (2026-07-20) — Org展開・品質ダッシュボード・カバレッジ強制 / Actions 悪意ワークフロー事前承認機能
3. **GitHub Issue auto-review 確認**: 0件 (アクション不要)
4. **競合レポート更新**: `docs/competitor-reports/2026-07-31.md` を static-template から WebSearch 実データへ更新
5. **日次レポート更新**: `docs/daily-reports/2026-07-31.md` の競合動向セクションをインサイト付きに強化
6. **Supabase API 制約**: ネットワークポリシーで smmkxxavexumewbfaqpy.supabase.co への直接 HTTP アクセス不可 (GHA 経路は正常)

#### 競合インサイト (本日の最重要発見)

- **Notion のプラットフォーム開放加速** (HTMLブロック+MCP): Notion は「プレーンテキスト」を超えて「実行環境」になりつつある → 自社の agent-board + AI大学が「実行可能な知識ベース」として差別化できる好機
- **GitHub Code Quality GA**: コード品質管理ツール市場に GitHub が本格参入 → AI大学で「GitHub Code Quality 解説」コンテンツを追加し SEO 流入を狙う
- **Slack の AI Workspace OS 化**: 30+ 機能でチャット以上のプラットフォームへ → 自社は「個人の知的資産管理×AI」で垂直統合の強みを維持

#### AI アクション提案

1. AI大学に「GitHub Code Quality GA 解説 + 代替ツール比較」を追加 (SEO流入・技術ユーザー獲得)
2. agent-board 機能を #buildinpublic で X 投稿 (Notion AI Agent との差別化訴求)
3. Notion HTMLブロック対抗として「実行可能メモ」LP セクションを 8月末に追加

#### Philosophy Alignment

- 該当原則: 4 (商品=価値 / 競合を観測し自社の差別化を更新する) / 6 (資本=時間 / 自動化で調査時間をゼロトークンへ) / 8 (KPI / ユーザー 61人→次の milestone へ向けた施策立案)
- ネットワークポリシー制約: Supabase Edge Function / REST への直接 HTTP アクセス不可 → GHA 経路が正規パス (既知・継続)

---


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
