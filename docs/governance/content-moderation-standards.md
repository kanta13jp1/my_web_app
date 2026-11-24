# コンテンツモデレーション基準とチケット運用標準 (#2619)

**関連 Issue**: `#2619`
**目的**: 属人的な裁量に依存せず、客観的カテゴリ・重大度・SLA・権限分離・監査証跡に基づいた形式的合理性のあるモデレーション運用を実現する。

---

## 1. 違反カテゴリ定義と初期重大度・一次対応 SLA

すべての報告は作成時点で `ticket_status = 'open'`（未対応）として起票され、以下に定める客観基準に基づき一次重大度および SLA を割り当てる。

| カテゴリ (`violation_category`) | 判定基準（客観要件） | 標準重大度 (`severity`) | 一次確認 SLA |
| :--- | :--- | :--- | :--- |
| `spam` | 自動投稿、同一内容の反復投下、無関係な宣伝・誘導リンクの大量設置 | `low` | 72時間以内 |
| `misinformation` | 公的機関の一次情報または検証済み事実と明確に反する誤情報の流布 | `medium` | 24時間以内 |
| `harassment` | 個人・集団への威嚇、侮辱、つきまとい、攻撃的表現（殺害・暴力示唆時は `urgent` へ引き上げ） | `medium` / `high` | 12時間以内 |
| `privacy_violation` | 同意なき個人情報（住所・電話番号・口座情報・本人確認書類等）の掲載 | `high` | 4時間以内 |
| `illegal_content` | 法令違反行為の助長・違法コンテンツの共有（即時遮断対象） | `urgent` | 1時間以内 |

---

## 2. チケットステータス遷移ワークフロー

1. **`open`（未対応）**: 一般ユーザー（通報者）が起票できる唯一の初期状態。`assigned_moderator_id`、`resolution_note`、`resolved_at` は必ず `NULL` とする。
2. **`in_review`（確認中）**: 権限を持つモデレーター（`user_profiles.is_admin = true`）が担当割り当てを行い、一次情報・証跡を確認している状態。
3. **`resolved`（解決済み・措置完了）**: 対象コンテンツの非公開化・修正要請・注意喚起等の対処が完了した状態。**判断根拠となる `resolution_note` の記入を必須**とする。
4. **`dismissed`（該当なし・却下）**: 規約違反に該当しないことが確認された状態。同様に **却下理由 (`resolution_note`) の記録を必須**とする。
5. **再審査（異議申し立て）**: `resolved` または `dismissed` から `in_review` への再遷移は、追加根拠が提出された場合に管理者のみが実行し、判断履歴を上書きせず監査メモへ追記する。

---

## 3. セキュリティと権限分離ルール (Supabase RLS + DB トリガー)

- **通報者（一般ユーザー）**:
  - 自身の通報チケットの閲覧 (`SELECT`) と、`ticket_status = 'open'` かつモデレーター欄がすべて `NULL` の新規起票 (`INSERT`) のみ許可。
  - 一般ユーザーによる `UPDATE` / `DELETE`、自己解決 (`resolved`)、担当者の改ざんは RLS および `BEFORE INSERT OR UPDATE` トリガー (`guard_moderation_ticket_fields`) で禁止。
- **モデレーター / 管理者 (`user_profiles.is_admin = true`)**:
  - 全チケットの閲覧 (`SELECT`) と、対応ステータス・重大度・担当者・措置メモ・解決時刻の更新 (`UPDATE`) を許可。
  - 通報者が提出した元データ（`reporter_user_id`, `target_entity_type`, `target_entity_id`, `violation_category`, `report_reason`, `evidence_reference`）の改ざんは DB トリガーで禁止し、検証証跡の完全性を保全する。
