# AI 機能の投資対効果（ROI）測定仕様 (#4130)

## 1. DX 投資の 3 階層 ROI モデル

単純な API コスト比較ではなく、以下の 3 階層の便益合計と API コストから純便益・ROI 倍率を算出する。

1. `direct_cost_savings`（直接コスト削減）: `callCount * estimatedHoursSavedPerCall * hourlyRateJpy`
2. `opportunity_loss_avoidance`（機会損失回避）: `callCount * opportunityLossAvoidedPerCallJpy`
3. `added_value_creation`（付加価値創出）: `callCount * addedValuePerCallJpy`

- **ROI 倍率**: `(totalBenefitJpy - totalApiCostJpy) / totalApiCostJpy`（`totalApiCostJpy == 0` の場合は `0`）

## 2. 係数調整と外部指標に関する注記

- 時給単価・1 呼出あたりの削減時間・機会損失回避額・付加価値額は `RoiCoefficients` として外部から注入・調整可能とする。
- 外部文献由来の一般的な DX ROI 係数や業界ベンチマークは本環境で検証できていないため **未確認** とし、実運用では自社の実測コスト・工数に合わせて係数を較正すること。

## 3. UI・アクセシビリティ基準 (`AiRoiDashboardCard`)

- `Wrap` レイアウトと `maxWidth: 320` 制約により、360×800・`2.0x` textScale 環境でも横方向オーバーフローを防止する。
- 操作ボタンは `minimumSize: Size(64, 48)`・短縮ラベル（`係数調整`、4文字）を遵守する。
