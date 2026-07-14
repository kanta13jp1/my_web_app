# X トラッカー系列プレイブック — データレポート型投稿の量産基盤

> **正本** (2026-07-12 part330 確立)。実測: データレポート型(選挙集計) **17.2K imp** vs
> ニュース要約 1.2K vs 製品転換 40 (同日3連投・[R23 実測](https://github.com/kanta13jp1/my_web_app/pull/3953))。
> 勝ち型 = 「読者が既に追っている固有テーマの、独自に集計された実数」を
> ポストA構造(取得日時→主要実数→基準差分→残り→増加履歴→アラート→内訳→名簿)で出す。
> 量産 = この構造を **系列(定点観測トラッカー)** として複数持ち、
> 「自動生成 → HITL 承認 → 投稿 → Archetype lift 計測」のループで回す。

## パイプライン全体像

```
[系列別ジェネレータ (cron / 決定的合成・LLM 不使用)]
   ↓ x_post_candidate (hub_data / status=pending_approval)
[admin ダッシュボード「X投稿候補キュー」panel]  ← R26 承認面
   ↓ x.candidate.approve (approval_channel=admin_ui) → 人間が全文確認
   ↓ x.post (whitelist 済み postPayload / contentArchetype=data_report)
   ↓ x.candidate.finalize (posted / rejected_duplicate / publish_failed)
[x_post_log → x.performance_context → Archetype lift / variant ranking]
   ↓ 実測で系列の伸縮を判断(admin X成長ループ panel + 生成プロンプト両方に効く)
```

## 系列レジストリ (variant = 計測の一次キー)

| 系列 | variant | 生成 | 頻度 | 投稿経路 |
|---|---|---|---|---|
| 選挙集計(全文) | `local_election_tally` | 必達管理室ボタン ([#3966](https://github.com/kanta13jp1/my_web_app/pull/3966)) | データ更新時(手動) | 確認ダイアログ→直接投稿 |
| 選挙: 議員数増減 | `member_delta_national_progress` | `local-election-snapshot-queue.yml` (日次 05:35 JST) | 有意差分時のみ | 候補キュー(HITL) |
| 選挙: 公認・候補予定 | `scheduled_candidate_delta` | 同上 | 有意差分時のみ | 候補キュー(HITL) |
| 選挙: 選挙予定更新 | `local_election_schedule_delta` | 同上 | 有意差分時のみ | 候補キュー(HITL) |
| 選挙予定スレ | `local_election_tracker` | composer dialog ([#3965](https://github.com/kanta13jp1/my_web_app/pull/3965)) | 週末前(手動) | API投稿ボタン |
| X運用実測 | `weekly_data_report` | `x-growth-data-report-post.yml` ([#3964](https://github.com/kanta13jp1/my_web_app/pull/3964)) | 週次(土 21:00 UTC) | 直接投稿(実測3件未満/横ばい週は自動見送り) |
| 家計トラッカー | `household_tracker` | 資産管理ページ ([#3968](https://github.com/kanta13jp1/my_web_app/pull/3968)) | 週次トグル | スコアボード投稿(円金額禁止=件数/日数/方向のみ) |
| デイリーブリーフィング | `daily_briefing_v2_*` | `x-daily-briefing-post.yml` (日次 22:00 UTC) | 日次 | 候補作成→publish op |
| AIツール定点観測 | `ai_tool_tracker` | `x-ai-tool-tracker-queue.yml` (日次 21:45 UTC / R27) | 更新検知日のみ | 候補キュー(HITL) |
| 選挙: 両党地力差 | `party_gap_ranking` | `local-election-snapshot-queue.yml` 内 (ISO週キー冪等 / R28) | 週次(日次cronから週1生成) | 候補キュー(HITL) |

ラベルの表示用対応は `lib/pages/admin_x_candidate_queue.dart` の
`kXTrackerSeriesLabels`(系列追加時にここも更新)。

## 新しい系列の追加手順 (5 ステップ)

1. **データ資産を選ぶ**: 「読者コミュニティが既に追っている固有テーマ」×「自分だけが
   この形で集計している実数」。捏造不可能な一次データのみ(実測 3 件未満なら出さない)。
2. **決定的ジェネレータを書く**: LLM 不使用のテンプレ合成(ポストA構造)。
   純ロジック + テスト必須。文字数は **加重文字数(CJK=2 / 上限 24,000)** で守る
   (`LocalElectionShareService.xWeightedLength` / [#3966](https://github.com/kanta13jp1/my_web_app/pull/3966) の教訓)。
   自己整合テスト: 生成物が `classifyPostArchetype` で `data_report` に分類されること。
3. **候補キューに載せる**: `buildXPostCandidateMetadata` で
   `x_post_candidate`(pending_approval)へ insert する cron を作る
   (`local-election-snapshot-queue.yml` が雛形)。**変化が無い日は候補を作らない**
   (近似重複ガードに拒否させるのではなく生成側で見送る)。
4. **variant を一意に振る**: `contentArchetype: data_report` + 系列固有 `variant`。
   これが variant ranking / Archetype lift の計測キーになる。
   `kXTrackerSeriesLabels` にラベルを追加。
5. **2 週間計測して判断**: admin X成長ループ panel の型別実測と variant ランキングで
   伸びない系列は止める(系列の追加より撤退の規律が量産の質を保つ)。

## HITL 方針 (なぜ全自動にしないか)

- **2026-07-12 Qiita アカウント停止事件**: 自動エンゲージメント(自動フォロー+AI
  自動コメント)が ToS 違反となりアカウント凍結。X でも無審査の大量自動投稿は
  同型のリスク=**公開の最終判断は人間**(候補生成と計測だけを自動化する)。
- 例外は「決定的合成+人間が事前設計したテンプレ+頻度が低い」系列のみ直接投稿を許可
  (週次 X運用実測 / 家計トラッカー週次トグル)。新系列はまず候補キュー経由で始める。
- 承認面: admin ダッシュボード「X投稿候補キュー」panel(R26)。
  `x.candidate.approve` は X operator 権限必須+approve が返す whitelist 済み
  postPayload のみを投稿する(レビューした本文以外は送信され得ない)。

## 計測と撤退基準

- 系列の健康指標: variant ランキング平均スコア / Archetype lift / ブックマーク数。
- 🔴 撤退検討: 4 投稿連続で系列平均がアカウント中央値未満。
- 🟡 テコ入れ: 固有名詞密度を上げる(ポストA の勝因は 300+ の議員名・47 都道府県名
  = 検索面の広さ)/ 基準・残りの「追える指標」を明示する。
