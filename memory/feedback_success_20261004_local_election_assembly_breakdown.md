---
name: 地方選候補者集計 都道府県議会/市区町村議会 内訳追加 — 成功パターン
description: 参照サイトが見られない時に既存コードの命名パターンを再利用してスコープを決め、3言語パイプラインを後方互換で拡張し、PR babysit loopでノイズなくマージまで運んだ一連の成功手順。
type: feedback
---

## 1. 参照不可サイトへの対応: 既存パターン再利用で推測を排除

`https://demo2.cheering-dpfp.net/member.html` が WebFetch/curl で到達不可 (EGRESS_BLOCKED) だった際、
機能を推測で実装せず `AskUserQuestion` でユーザーに方向性を確認した。ユーザーが選んだ
「既存の都道府県別集計を拡張」を実装する際、すでに `LocalElectionLegislatorProfile.assemblyCategory` /
`isLocalAssemblyElection` (lib/models/local_election_reality.dart) で確立されていた
「都道府県議会 / 市区町村議会」の判定基準・命名をそのまま再利用し、新規の分類ロジックを発明しなかった。

**Why:** 外部サイトが見えない制約下でも、既存コードベース内の確立済みパターンを再利用すれば
「推測」ではなく「既存設計との整合」として実装を正当化できる。
**How to apply:** 新機能のスコープが不明瞭な時は、まず同じリポジトリ内に類似の分類/命名が
既にないか grep してから設計する。なければユーザーに選択肢を提示する (AskUserQuestion)。

## 2. 3言語パイプラインの後方互換拡張

Python (`scripts/update_kokumin_local_endorsements.py`, PDFパース正本) → JSON/Dart (生成ファイル) →
TypeScript (`supabase/functions/local-election-intelligence/election_mode.ts`, raw.githubusercontent 経由で
正規化のみ) → Dart UI の3段パイプライン全てに新フィールド `prefecturalCount`/`municipalCount` を追加したが、
全て optional・デフォルト0 にしたことで、分類ロジック追加前に生成済みの既存 JSON/Dart ファイルが
即座に壊れることなく動作し続けた。

**Why:** 生成ファイルとロジックのバージョンがずれても後方互換なら本番を壊さない。
**How to apply:** 既存の生成パイプラインに新フィールドを追加する際は常に optional + 安全なデフォルト値にする。

## 3. PR babysit loop: "dirty" だけに反応し "behind"/"unknown" は無視

PR #5523 作成後、約5日間・数十回の定期チェックイン (ReadNotifications → pull_request_read get →
前回状態と比較 → 変化なければ send_later で再スケジュール) を継続。このリポジトリは bot commit が
10〜30分おきに main へ入るため `mergeable_state` が "behind"/"unknown" を頻繁に示したが、これは
実コンフリクトではないと判断し、無反応ポリシーを早期に確立・一貫して適用した。実際に "dirty" は
一度も発生せず、CI も一貫して green のままマージに至った。

**Why:** 高頻度自動コミットのリポジトリでは "behind" は定常状態であり、毎回ユーザーに報告すると
ノイズになる。"dirty" (実コンフリクト) のみが行動トリガーであるべき。
**How to apply:** 監視対象リポジトリのコミット頻度が高い場合、早い段階で
「behind/unknownは無視、dirtyのみ対応」という明示ポリシーを立てて最後まで一貫させる。

## 4. auto-merge イベントへの反応速度調整とクリーンアップ

`pull_request.auto_merge_enabled` の wake を受けた時点でチェックイン間隔を50分→15分に短縮し、
CI 完了を見越して動いた。`pull_request.closed` (merged) の wake を受けた直後に
`delete_trigger` で不要になった定期チェックイン Routine を即時削除し、監視を正しく終了した。

**Why:** イベント駆動で監視密度を動的に変えることで、無駄なポーリングを避けつつ重要な遷移を逃さない。
**How to apply:** 外部イベント (auto-merge enabled, check_suite.completed 等) が届いたら
次回チェックインの間隔を状況に応じて短縮し、マージ確定後は忘れずにスケジュール済み trigger を削除する。
