---
name: Internal Review Record
about: 内部レビュー実施記録と品質メトリクス（仕様・設計・セキュリティ・UIUX）
title: '[REVIEW] '
labels: review
assignees: ''
---

## 対象機能・PR 情報

- 対象機能 / PR: `<!-- 例: PR #1234 / 機能名 -->`
- 対象単位 (`scope_unit`): `<!-- kloc / screen / endpoint / component -->`
- 対象規模 (`scope_size`): `<!-- 例: 0.5 -->`
- レビュー所要時間 (`review_minutes`): `<!-- 例: 45 -->`

## レビュー観点チェックリスト

### 仕様・要件

- [ ] 関連 Issue の Acceptance Criteria と仕様の齟齬がない
- [ ] 正常系・異常系・境界値・フォールバック方針が妥当である

### 設計・構造

- [ ] 既存ヘルパー・モデルの再利用と重複排除が行われている
- [ ] モジュール責務・依存方向・エラーハンドリングが明確である

### セキュリティ・権限

- [ ] RLS・認証境界・API キーやトークン非露出が確認されている
- [ ] 外部入力のバリデーションとインジェクション対策が適切である

### UI/UX・アクセシビリティ

- [ ] ローディング・空状態・エラー状態の視覚フィードバックが明確である
- [ ] モバイル/デスクトップ表示およびコントラスト・ラベルが適切である

### テスト・自動チェック

- [ ] 自動 Lint / Test（CI ゲート・単体テスト）が通っている
- [ ] 境界値やリグレッションケースをカバーするテストが追加されている

## 指摘分類サマリー

| 指摘分類 | 件数 | 主な指摘内容・対処方針 |
| --- | --- | --- |
| 仕様 (`spec`) | 0 | `<!-- 仕様漏れ・要件不一致 -->` |
| 設計 (`design`) | 0 | `<!-- 構造・重複・責務分割 -->` |
| セキュリティ (`security`) | 0 | `<!-- 権限・秘密情報・入力検証 -->` |
| UI/UX (`uiux`) | 0 | `<!-- レイアウト・a11y・導線 -->` |
| テスト (`test`) | 0 | `<!-- カバレッジ・境界テスト -->` |

## 品質メトリクス算出

```text
python scripts/internal_review_metrics.py --scope-size 0.5 --review-minutes 45 --spec 0 --design 0 --security 0 --uiux 0 --test 0
```

- 基準閾値との比較は `lib/models/process_quality_metric.dart` の `minimumReviewDensity` / `minimumFindingDensity` 定義と整合させて管理する。
