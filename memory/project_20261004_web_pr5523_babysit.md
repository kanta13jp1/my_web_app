---
name: WEB版 PR #5523 babysit から得た project 固有発見
description: kanta13jp1/my_web_app の自動コミット頻度・WEB版インスタンスの役割・WBS-SYNC前提条件に関する実測ベースの新知見。
type: project
---

## 1. このリポジトリの自動コミット頻度は「behind」を定常状態にする

`kanta13jp1/my_web_app` の `main` には bot commit (AI大学コンテンツ更新 / ヘルスモニター / 日次レポート /
競合レポート / wiki compile / WBS snapshot 等) が約10〜30分おきに入る。このため開いている PR の
`mergeable_state` は "behind" または "unknown" を頻繁かつ短時間で往復する。これは実コンフリクトではなく、
GitHub 側の mergeability 再計算が非同期であることに起因する。実際に PR #5523 (2026-09-24 作成 →
2026-09-29 マージ) の期間中、"dirty" (実コンフリクト) は一度も発生しなかった。

**Why:** 将来このリポジトリの PR を監視する際、"behind"/"unknown" への過剰反応 (毎回マージ/rebase を試す)
は無意味な作業とユーザーへのノイズを生む。
**How to apply:** このリポジトリの PR 監視では "dirty" のみをアクション条件とし、
"behind"/"unknown" は無視して静かに再スケジュールするポリシーを最初から適用する。

## 2. WEB版インスタンスの役割は「リモート PR/Issue 管理のみ」(docs/MULTI_INSTANCE_FLEET.md:101)

fleet table で WEB版は "(worktree なし / GitHub MCP のみ)" / "リモート PR / Issue 管理 → 機能継承" と
明記されている。つまり WEB版インスタンスは実装・ローカル worktree 作業の主体ではなく、
GitHub 経由のリモート PR/Issue 管理に特化した軽量な役割を持つ。

**Why:** WEB版セッションで `wrap-up` 等の全インスタンス共通 skill を実行する際、
Win版/Codex版向けに書かれた手順 (ローカル Windows パス、worktree 前提の作業等) をそのまま適用すると
ずれが生じる。
**How to apply:** WEB版セッションでは、リポジトリ内 (`memory/`, `docs/`) への保存は実行するが、
worktree 前提や Windows ローカルパス前提の手順は "機能継承" の範囲内で読み替える。

## 3. WBS-SYNC (Step 5.5) は `SUPABASE_ANON_KEY_PROD` 環境変数が無いとこのサンドボックスでは実行不可

`env | grep SUPABASE` で確認した結果、このクラウド WEB セッションには `SUPABASE_ANON_KEY_PROD` が
設定されていない。`wrap-up` skill の WBS-SYNC blocking curl はこの変数を前提にしているため、
WEB版セッションでは実行できず、2026-07-11 の web セッション (project_20260711_web_seo_h7.md) でも
同様に "WBS-SYNC skip 理由" を記録する前例がある。

**Why:** 環境変数が無い状態で無理に curl を実行すると認証エラーのみを積み重ねることになる。
**How to apply:** WEB版セッションで `wrap-up` を実行する際は WBS-SYNC を
`--skip-wbs-sync` 相当として扱い、「このセッションで触った WBS タスクが存在しない / 認証情報が
サンドボックスに無い」ことを memory に明記してスキップする。

## WBS-SYNC skip 理由 (このセッション)

PR #5523 はユーザーからのアドホックな機能要望 (地方選候補者集計の拡張) であり、
事前に紐づく WBS task id は存在しない (memory/docs 全文検索で該当なし)。かつ
`SUPABASE_ANON_KEY_PROD` 未設定のためこのサンドボックスから `wbs.update_progress` を安全に呼べない。
→ WBS-SYNC は skip。
